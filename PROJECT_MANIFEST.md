# Project Manifest — Strategic Layer Mod (Arma 3 / Tanoa)

Attach this as project context. It is a **design document**: scope, structure,
the rules that must not be broken, and what is left to decide.

It is deliberately not a technical reference. Function behaviour, parameters,
and the reasoning behind any particular implementation live in the header blocks
and comments of the code itself. If a statement here can only be verified by
reading a `.sqf` file, it does not belong here.

**The one exception is Appendix A, engine quirks.** Those are facts about Arma,
not about this codebase — they outlive any function that currently works around
them, they are what several of the design rules below exist to accommodate, and
rediscovering one costs an afternoon. It is the only technical section in this
document, and nothing else may grow into one.

---

## 1. Premise

The player is a mercenary captain contracted by CSAT to dismantle druglord
networks on Tanoa. The druglords are covertly backed by NATO. The player begins
as a small outfit in one corner of the island chain and expands outward.

**Structure:** a turn-based strategic map where armies move as drawn icons and
orders resolve simultaneously. When hostile armies converge, the strategic layer
collapses into a live Arma tactical battle. When the battle ends, surviving
personnel and materiel are written back to data and the campaign advances.

The tactical layer is realtime Arma. The strategic layer is not.

---

## 2. Design Pillars

1. **Persistence over spectacle.** Soldiers are data first, entities second.
   Names, skill, health, and condition survive across battles. A named rifleman
   who takes a leg wound in battle three deploys wounded in battle four.
2. **The favor economy.** Two mirrored currencies drive escalation. **CSAT
   Favor** buys rare vehicles, airstrikes, spec-ops reinforcement and intel.
   **NATO Aggression** accrues from the player's own conduct — indirect fire,
   mines, collateral damage near civilians — and pays out the same categories of
   asset to the druglords. Every tactical shortcut has a strategic price. This
   is the central tension.
3. **Commit, then live with it.** Orders are issued during a planning phase and
   cannot be revised mid-block. The game rewards anticipation, not vigilance.
4. **The map means something.** Docks, airfields, plantations and towns confer
   distinct benefits and carry distinct garrison strength. Airports are heavily
   defended and heavily rewarded.
5. **Command, don't solo.** In battles the player attends, he issues orders
   while personally vulnerable. In battles elsewhere he may drop in as the
   army's commander or observe from above.

---

## 3. Resources

| Resource | Gained by | Spent on |
|---|---|---|
| Money | Contracts, captured assets, controlled locations | Recruitment, vehicles, wages, bribes |
| Manpower | Recruitment at friendly locations | Replacing losses |
| CSAT Favor | Completing CSAT objectives, restraint | Rare vehicles, airstrikes, spec-ops backup |
| NATO Aggression | Collateral damage, explosive ordnance near civilians | *(Adversarial — spent by the druglords)* |

Transport capacity is not a currency but functions as one (section 6).
Prisoners are a prospective resource: recorded on capture, disposition deferred
(section 9).

---

## 4. Conventions

- **`STRAT_fnc_*`** — strategic layer.
- **`TACT_fnc_*`** — tactical layer: battle lifecycle and the player's command
  of a deployed group.
- **`TEST_fnc_*`** — test harness. Neither layer, and a third prefix on purpose:
  it is scaffolding and must come out in one piece. Nothing in `STRAT_` or
  `TACT_` may call it, and nothing in it may hold state the other two read.
- Army, soldier, vehicle and location records are **HashMaps**, never
  arrays-by-index.
- Data records own the truth; spawned entities are transient views of them.
- Every function carries a header block: purpose, params, return. That header,
  not this document, is where implementation detail is recorded.

---

## 5. The Turn Model

**WEGO with fixed blocks.** Both sides plan, both sides commit, the block
resolves simultaneously. Not IGOUGO — coordinated multi-asset operations need
concurrent resolution.

- **Block length: 4 hours.** Six blocks per day.
- **No mid-block interruption.** Orders stand for the full block, without
  exception.
- **Planning phase** — orders issued for every detachment, with projected
  outcomes (arrival, fatigue on arrival, exposure) shown before commit.
- **Execution phase** — movement, contact detection and battle initiation. The
  player watches; he does not act.

### Execution is watched, always

The block always resolves in compressed time with the player watching. Instant
resolution with a report was cheaper and is rejected: it sells the simultaneity
that justifies WEGO, and it preserves the ambush. If resolution were normally
instant, any transition into the tactical layer would itself be information.

### Battle time is block time

The two layers keep different clocks. Marching is compressed — a block is a
couple of minutes of watching. The tactical layer runs at 1:1; a firefight is
what the game is about and there is nothing in it worth compressing.

Battle time and block time run **one for one**. The battle clock caps a fight,
so a full-length battle spends a fixed share of the block and a shorter one
costs proportionally less. A battle always gets its full length whenever it
starts, but its cost is clamped to the block time left when it opened — so
fighting late in a block is cheaper than fighting early. That is accepted;
truncating a real battle at a bookkeeping line is the worse trade.

Consequences that are load-bearing:

- The battle clock is a mechanic, not decoration. It is displayed.
- A battle cannot span a block boundary. Clock expiry with neither side broken
  is **mutual disengage** — both separate, no ground changes hands.
- The strategic clock holds while a battle runs; armies elsewhere are advanced
  by the battle's block-time cost once it ends, unwatched.

### Clock decoupling

Systems tick at different multiples of the block. Do not assume one rate.

| System | Rate |
|---|---|
| Movement, contact, battle | Every block (4h) |
| Fatigue accumulation | Every block |
| Wages, upkeep, income | Every 6 blocks (daily) |
| NATO aggression decay | TBD, likely daily |
| Recruitment availability | TBD |

### Save points

Block boundaries are natural save points with no in-flight state. Since no
battle spans a boundary, no save ever contains a battle in progress.

---

## 6. Movement, Gating, and Fatigue

**Distance is not the limiter.** Tanoa's longest road route is roughly 12–14 km;
any vehicle crosses the island inside one block. Accepted rather than fought —
taxing movement inside owned ground is the least interesting friction.

**Gating is by control.** Movement is free within controlled territory.
Expansion is gated by **strongholds**: cartel positions that must be cleared
before the player can push further without triggering an engagement. The
frontier is the constraint.

**Route choice matters, route length does not.** Pathfinding earns its keep by
shaping **exposure** — contested routes risk interception, safe routes are
longer. Surfaced at planning time as visible information, never a hidden roll.
Route choice also determines ambush exposure.

**Fatigue is the cost of foot movement.** The intended model is a 24-hour cycle
tracked per soldier: exertion builds across blocks and is reset by 8 hours of
sleep. Marching all day costs a night, not a block, so rest is a real decision.

- **Transport clears it.** Riding arrives fresh. This is what makes vehicle
  availability the genuine scarcity in the game.
- **It must carry a strategic cost, not only a combat modifier.** Otherwise it
  only penalises attacking, which is backwards for a campaign about pushing out.
- **It must be visible before commit.**
- **Curve:** free below a threshold, gentle for the first hour past it,
  steepening after. If four hours isn't bad enough to make arriving a block
  later look attractive, the system is doing no work.

Fatigue lives on the soldier from the start so detachments can merge and split
without inheriting each other's condition. An army-level value derived from the
soldier records is the interim stand-in for the full sleep cycle.

**Aircraft** are deliberately unconstrained by range — limited by availability,
favor cost and NATO detection. Do not fight the fantasy of having a helicopter.

**Fuel** is deferred, and only worth building if *sourcing* is the interesting
part. A meter that refills at friendly bases is bookkeeping. Fuel drawn from
captured locations, carried by convoys and vulnerable to raiding is a supply
game, and aviation fuel gated behind captured airfields is the strongest form.

---

## 7. Data Model

Field lists only. Semantics of individual keys are documented where they are
read.

**Army:** `id`, `name`, `location`, `path`, `speed`, `faction`, `men`,
`vehicles`, `pendingOrder`, `inBattle`, `prisoners`.
*Planned:* `supplies`, `morale`, `homeLocation`, `transportCapacity`.

The army's **destination** lives on `pendingOrder`, not on the army. Battle
deployment reads it to compute facing, so `pendingOrder` must survive into
battle setup and must not be cleared at commit. The record carries no
presentation at all — icon and colour are derived from `faction` at draw time.

**Soldier:** `className`, `health`, `skill`, `isLeader`, `isPlayer`, `obj`,
`exertion`, `hoursSinceSleep`.
*Planned:* `name`, `xp`/`rank`, `loadout`, `woundState`, `captureInfo`.

`isPlayer` marks the one man whose body the player takes when his army fights.
It changes nothing else about the record.

**Vehicle:** `className`, `health`, `hitboxes`, `obj`.
*Planned:* `fuel`, `ammoState`, `crewAssignments`, `seats`.

**Engagement:** `id`, `type`, `attacker`, `defender`, `boundaryAnchor`,
`boundaryRadius`, `deployment`, `victoryConditions`, `blockTimeRemaining`, plus
`capturePoint` (set-piece) and `sprung` (ambush). Built before deployment; the
lifecycle reads it rather than branching on battle type.

**Location:** `id`, `type`, `position`, `owner`, `garrison`, `flagPos`. Ids are
authored, not minted. A garrison is a static roster, not an army: it shares the
soldier and vehicle record formats so sync-back is one code path, but it has no
`pendingOrder`, does not move, and never enters `activeArmies`.
*Planned:* `opinion` and per-location benefits (phase 3.8) — deliberately absent
rather than stubbed, since an empty key invites code to read it early.

**Health convention.** Data stores **health**, 1.0 pristine. Arma stores
**damage**, 0 pristine. Convert at every boundary crossing; never mix the two
conventions inside one function.

---

## 8. Side Allocation

Arma has four sides with globally shared relations, so the story factions are
packed into them carefully.

| Story faction | Arma side |
|---|---|
| Player mercenaries | INDEPENDENT — friendly to EAST, hostile to WEST |
| CSAT (patron) | EAST |
| Druglords | WEST |
| NATO (druglord backer) | WEST — shares a side, which gets intervention for free |

Sides are only how the engine is told about the blocs. **Hostility itself is
decided from `faction` and never read off a side.**

CIVILIAN is not spent here. It is wanted as itself: NATO Aggression accrues from
ordnance near civilians, so the meter needs a populated Tanoa to measure
against. That is what leaves three combatant sides for four factions.

The packing is deliberately asymmetric, and the asymmetry carries the future.
Player and CSAT are one bloc across *two* sides joined by a relation flip; the
cartel and NATO are one bloc on *one* side. So CSAT can be peeled off the player
cheaply, and NATO can never be peeled off the cartel without respawning
everything it has — which is right, because Favor is losable and NATO's backing
only escalates. A CSAT turn is therefore a between-block event, never a
mid-battle one: side relations are global and take every unit in the same frame.

**The campaign avatar** sits on CIVILIAN and is outside this table on purpose.
It never deploys, never joins an army, never appears in a roster and never
fights. The player reaches a battle by taking over a soldier the deployment
actually spawned, and control returns to the avatar when the fight ends. A
combatant side would make it a body some army has to account for.

---

## 9. The Turn and Battle Lifecycle

Each stage is a distinct responsibility; do not merge them. All battle types run
this same lifecycle.

1. **Planning** — orders issued, projections shown.
2. **Commit** — planning closes. No further input until the block ends.
3. **Resolution** — all armies advance concurrently against elapsed block time.
4. **Contact detection** — hostile proximity, ambush zones, location boundaries.
5. **Engagement construction** — type, roles, anchor, deployment plan, live
   victory conditions, block time remaining.
6. **Battle decision** — attended (spawn the tactical battle) or unattended
   (auto-resolve mathematically). *Auto-resolve not implemented.*
7. **Deployment** — place both sides per the engagement's plan, draw the
   boundary. Fatigue applied here as skill and morale modifiers.
8. **Battle** — realtime Arma at 1:1. Favor assets may be called in.
9. **Conclusion** — a victory condition fires, or the clock expires into mutual
   disengage. Outcome classified per army.
10. **Sync-back** — condition read off every entity into its owning record;
    surrendered survivors moved to the victor's prisoners; dead dropped; object
    references nulled; entities deleted; boundary cleared.
11. **Post-battle march** — survivors spend remaining block time continuing or
    reversing along their route, per the outcome. *Reversing not implemented.*
12. **Upkeep** — per-block ticks, and on day boundaries wages, income, decay.
13. **Advance clock** — next planning phase opens.

The remaining gaps are auto-resolution at stage 6 and the reversing half of
stage 11.

---

## 10. Battle Types

There are three battle types. **They are not three systems.** They are one
lifecycle with three parameter sets, expressed through the engagement record.
Deployment, victory conditions, boundary anchor and initial state are the only
things that vary.

**Role symmetry is mandatory.** Every type must work with the player as attacker
or defender and must auto-resolve when he is absent. The cartel attacking a
player-held plantation is the same code path with the roles swapped.

### 10.1 Open field

Two armies moving to their destinations cross paths.

**Anchor:** midpoint between them. **Deployment:** each army at the boundary
point nearest its own origin, facing its destination bearing — so the geometry
of the tactical map encodes where everyone is trying to go. Vehicles line up
along the approach road, infantry falls in behind, so transport and dismounts
never contest the same ground.

**The incentive to advance is strategic, not tactical.** Time in cover is block
time burned and distance not covered. Nothing tactical needs to force the fight;
the block clock does it. Two things must hold for that pressure to transmit:
remaining block time must carry over, and the AI must feel it too — the enemy is
ordered toward its own strategic destination, or the pressure is asymmetric.

**Exit direction is meaningful.** Leaving the boundary toward the destination is
a **breakthrough** — march on with the remaining block time. Leaving away from
it is a **repulse** — block lost, army returns toward its origin. Same act,
opposite meanings, which is what makes fleeing legible instead of a binary that
has to be detected.

**Divergent destinations are a valid outcome, not a failure.** Two armies racing
for the same town cannot disengage and it is a real battle. If their
destinations diverge, the correct play for both is to break contact and keep
marching. Destination vectors are therefore part of route planning.

**Victory conditions:** breakthrough, repulse, rout, surrender, annihilation,
block-clock expiry.

### 10.2 Fixed set-piece

An attacking army assaults a location. These are the meticulously planned
battles.

**Anchor:** the location's centre, not a midpoint — the defender is already in
position and the attacker arrives. **Deployment:** garrison at prepared
positions, attacker at the boundary edge nearest its approach road.

**The capture point** is a central flagpole flying the defender's colours,
raised.

- An attacker inside the radius lowers the flag; at the bottom it rises again in
  his colours, and at the top the defenders surrender.
- **Contest is a tug of war weighted by mass.** Net rate is a function of
  attackers minus defenders in the radius. Presence alone does not stall the
  flag — bodies do.
- **Progress persists.** Nothing resets it except the contest driving it back.
- **Reversal cannot pass the starting state.**

**Capture timing must not collapse the battle.** If capture is fast, the
defender's optimal play is to stand on the flag and an assault becomes one
firefight in a courtyard. The timer must be long enough that a defender only
needs to be able to *return* to the flag, keeping perimeter defence viable.

**Surrender is not annihilation.** A capture that leaves the roster alive is a
distinct outcome, and the reason to take the flag rather than grind the garrison
down. Survivors become prisoners, logged with capture context. Disposition —
ransom, recruitment, release, execution — is a later decision, and nothing
should be built assuming a particular answer.

**Victory conditions:** flag capture, rout, surrender, annihilation, attacker
withdrawal, block-clock expiry.

### 10.3 Ambushes

Deferred, but architecturally cheap. Under WEGO both sides have already
committed routes, so an ambush is **one order type and one deployment plan**:
conceal and hold at a node, triggering when a hostile army resolves movement
through the zone.

- **Preparation costs a block spent stationary.** Ambushing is a commitment, not
  a free option.
- **Prepared assets:** mines and roadblocks. Mines accrue NATO Aggression like
  any other explosive ordnance.
- **The victim spectates until it is sprung.** Safe specifically because watched
  execution is the default presentation — there is no tell to leak.
- **Deployment:** ambusher concealed off the road, victim in column on it.

**Victory conditions:** as open field, plus the ambusher's option to break off
after the initial exchange.

---

## 11. Map Rendering

Two renderers exist and they do not compose. Marker icons scale with map zoom;
anything drawn beside them scales by a different law, and there is no way to ask
the engine how large a marker currently renders. Hence the governing rule:

**Anything made of more than one visual element referring to one entity is drawn
wholesale by one renderer.**

### The split

**Armies and locations render entirely in the Draw layer.** They are precisely
the things that accrete adornment — vehicle badge, strength count, fatigue pip,
selection ring, opinion shading, an order arrow originating at the icon's edge.
Each is a second element beside a first, so the first cannot be a marker.

**Markers keep atomic, non-interactive, engine-owned work:** task and briefing
markers, in-battle GPS markers, debug and authoring markers. One icon, one
label, no adornment, no click behaviour.

**The map has two modes and they do not overlap.** Outside a battle it draws the
campaign. While the player is commanding on the ground it draws the fight: his
own units, what is selected, and the routes they have been given. The strategic
icons stand down for the duration — they sit on top of the battle they represent
and would compete for the same clicks. Both modes emit the same item shape, so a
tactical route arrow and a strategic order arrow are one thing drawn one way.

### One draw list

What is drawn and what is clickable derive from **one** computation. If they are
computed in two places they will drift, and the drift is invisible until a
player clicks something that is not there.

The list is also where the composition rule is enforced: an army emits a *group*
of items sharing one anchor and one scale, not several icons that happen to sit
near each other. An adornment that cannot state its group is a bug, not a loose
icon. Sizes and offsets are expressed in icon units rather than metres, so an
adornment pinned to an icon's edge stays there at every zoom.

### One palette, both layers

There is one colour table and one silhouette table in the mission, and both maps
read them. An army watched marching across the strategic map is the same colour
and shape as the men the player stands among after dropping into its fight.

| Faction | Colour | Bloc |
|---|---|---|
| `player` | Blue | contractors |
| `csat` | Green | contractors |
| `drugLords` | Red | cartel |
| `nato` | Orange | cartel |
| `civilian` | Purple | neither |

**Hue family carries the bloc; hue within it carries the faction.** Cool is with
you, warm is against you, purple is neither — so one glance answers *friend or
enemy* from the family and *which one* from the hue.

**NATO is deliberately not blue.** Blue is what a player reads as friendly
before he has finished looking.

**Silhouette repeats the bloc, and that redundancy is the accessibility floor.**
Red against orange, and blue against green, are the pairs a colour-blind player
is least able to split; the shape still says who to shoot. The rule for anything
added later: **a faction's silhouette is its bloc, its colour is itself.**

`civilian` is presentation-only. It is not a story faction and is in neither the
hostility table nor the side map; the three tables must not be assumed to share
a key set.

One collision is accepted knowingly: the engine paints INDEPENDENT green in its
own UI, so it calls the player green where this scheme calls green CSAT. The
alternative costs the blue-is-you convention and gives CSAT a thematically wrong
colour. The collision lives on a different surface.

### The rejected alternative

Keeping markers for armies and moving per-army detail into a side panel that
fills on selection sidesteps the alignment problem and costs almost nothing. It
is rejected because it is a menu. Detail would be visible for the one army the
player has clicked, when the whole point of the visibility invariant is that the
cost of a plan is legible while the plan is being made, across every force at
once.

---

## 12. Invariants

- **Data outlives entities.** A spawned unit is a temporary projection of a
  record. Anything that happens in a battle and matters afterward must be
  written back before entities are deleted.
- **Object references are null outside of battle.** Never persist a live object
  reference in saved state.
- **Commitment is absolute.** No mid-block revision, no scrubbing the clock, no
  interrupt on player whim. If the player can usefully advance in small
  increments and micromanage, the turn model has collapsed back into realtime.
- **Battle time is block time,** one minute for one minute. A battle never spans
  a block boundary. Remaining time is spent marching.
- **One lifecycle, three parameter sets.** Conclusion, sync-back and post-battle
  march are written once and shared. If a battle type needs its own copy of any
  of them, the engagement record is underspecified.
- **Every battle type is role-symmetric and auto-resolvable.** No battle type
  may assume the player attacks.
- **Never mutate the active army list while iterating it.** Collect pairs first,
  act after the loop closes.
- **Identity is compared on `id`.** HashMap equality is a content comparison and
  will produce false positives.
- **`faction` is the source of truth for allegiance,** not icon colour. Colour
  is presentation only, in either renderer, and is never read back.
- **The strategic layer must never spawn entities.** Records and drawing only.
- **Contact detection must check hostility.** Two friendly armies converging is
  a rendezvous, not a battle.
- **Fatigue lives on the soldier, never on the army.** Army-level values are
  derived, never stored.
- **A garrison is not an army.**
- **What is drawn and what is clickable derive from one list.**
- **Map draw handlers attach on map open, never on state change.** The map
  display does not exist while the map is closed and attachment fails silently.
  Because armies are drawn rather than marked, a failure to attach is not
  cosmetic — it is an empty strategic map.
- **One entity, one renderer.**
- **Anything the player is penalised for must be visible at planning time.**
- **The player is a soldier, not an exception.** He is spawned by deployment
  like the rest, counted in strength, part of the centre of mass, written back
  by sync-back, and able to die. No victory condition, casualty count or
  position sum has a special case for him, and none may acquire one.
- **The tactical map draws individuals only for the player's own group.** Every
  other group on his side is one icon over its leader, whole. A group's internal
  composition is drawn only where the player arranges it — forty friendly
  soldiers drawn man by man bury the eight that are his. His own group is never
  *also* collapsed, or the same men are drawn twice. Composition for a collapsed
  group is an adornment on its icon, never a second icon.
- **Two allegiance questions, two different answers, and they must not be
  swapped.** *Who fights whom* is decided between armies from `faction`. *Which
  groups are the player's own side on the field* is decided from side, because a
  group he detaches mid-battle is created by the engine, carries no record and
  no stamp, and inherits its side for free — a faction test cannot see it at
  all, and that is the case the tactical map exists to draw.
- **Two command surfaces, never at once.** Map closed, the stock squad bar
  commands. Map open, the squad bar is hidden and the map commands — including
  the engine's own friendly icons, which are a second drawing of the same units
  rather than a second place to click. Every path out of command mode must
  restore both; an interface element left switched off is not something the
  player can fix.

---

## 13. Status

**Phase 1 is complete.** The turn skeleton, the closed battle loop, block-time
accounting, side allocation, minimal locations and garrisons, the favor and
aggression hooks, derived army fatigue, the test harness and the campaign draw
layer are all in. Detail is in the code.

**Phase 2 is open**, and partially served ahead of schedule: infantry-only and
combined-arms deployment work from one deployment point and bearing per army,
and the player can drop into his own army and command his group from the map.
Map command currently issues one kind of order — send the selection to a point.

**Not built:**

- Auto-resolution for unattended battles.
- Set-piece battles and the capture point. The location and garrison records
  exist; what is missing is the battle type, not the data.
- Morale, rout, and surrender. Two victory conditions are named in section 10
  but not claimed anywhere, because neither model exists.
- Post-battle march for a repulsed army.
- Prisoner records and holding.
- Ambush order type and deployment.
- Fatigue accumulation and its effects. The soldier keys, the derived army value
  and the upkeep hook points exist; nothing writes exertion, and the curve
  constants are untuned placeholders.
- The rest of the planning-time adornments the visibility invariant asks for:
  projected arrival, route exposure, opinion shading, fatigue, tonnage. Each is
  one more item emitted into an existing group, not new machinery.
- Group-level battle command: detaching a squad, chained waypoints, held ground.
  Its prerequisite is that a side's strength be counted from the army record's
  roster rather than from group membership, or a detachment silently stops being
  counted and an army can be declared annihilated with a live element still
  fighting. Deliberately not done in advance — with no detaching, the roster and
  the group are the same set, so the change would be a no-op edit to the most
  consequence-heavy code in the project.
- Strongholds, frontier gating, route exposure and interception.
- Favor and aggression beyond the hooks; the economy generally.
- Location capture, ownership transfer, per-location benefits, local opinion.
- Naval and air movement — mandatory on an archipelago, since road pathfinding
  cannot leave the island it starts on.
- Save/load serialization.
- Overhead spectate, and the choice of whether to drop in at all.
- Soldier names, progression, loadout persistence.

---

## 14. Open Decisions

1. **Singleplayer or multiplayer?** Affects locality, serialization and every
   spawn call. Recommendation: SP first; do not pay MP costs until the loop is
   proven. Drop-in as built has already taken the SP side in practice, so an MP
   fork now has a concrete thing to replace rather than a general cost.
2. **Concurrent battles.** How many spawned battles per block? One attended with
   the rest auto-resolved is the safe default.
3. **Auto-resolve fidelity.** Pure math or a fast headless simulation? Math is
   cheaper and more predictable, and players tolerate it if the projection is
   legible. Must handle all three battle types. Deferred deliberately: whichever
   is chosen has to be calibrated against the outcome distribution real battles
   produce, which is not known until phase 2 has been played.
4. **Clock rates.** Compression of the watched march, and the battle clock cap.
   Both want playtesting; nothing may hardcode either. Open questions: whether
   the cap is right, whether a two-minute block reads as too fast to follow, and
   whether that much block time is enough of a price for a battle.
5. **Fatigue curve and thresholds.** Tuned in phase 2, where the effects are
   visible. The threshold must be tuned against the 4-hour block, not chosen
   independently of it.
6. **Save format.** Deferred to phase 3: phase 2's growth is mostly transient,
   and the persistent additions are additive rather than structural. Revisit if
   phase 2 introduces persistent state that is not a field on an existing
   record.
7. **Pathfinding cost ceiling.** Unbounded search over the full road graph can
   stall. Consider a distance cap with a fallback to direct movement.
8. **Prisoner disposition.** Ransom, recruitment, release, execution, or some
   combination gated by opinion and aggression. Prisoners are logged in the
   meantime so the decision can be made without a retrofit.
9. **Capture contest formula,** and flag traversal time. Both need playtesting
   against the perimeter-defence viability constraint.
10. **What counts as a defender in the capture radius.** Whether incapacitated
    units hold the point, and whether a vehicle passing through counts. "One
    crawling wounded man holds the town indefinitely" is a real failure state.
11. **Destination bearing edge case.** If a destination lies behind an army's
    own deployment edge, forward and backward coincide and exit classification
    is ambiguous. Needs a fallback rule.
12. **Ambush preparation fidelity.** Hand-placed mines and roadblocks versus an
    abstract budget placed by script. Budget preferred on scope grounds.

---

## 15. Build Plan

Three phases. Phase one brought the strategic layer to the minimum that gives
the battle layer real context. Phase two is the battle deep dive. Phase three
returns to the strategic layer and story progression.

The ordering principle: anything **expensive to retrofit into battle code** goes
in phase one, even if its full implementation does not. Anything that only needs
battles to *exist* goes in phase three. Everything else follows the dependency
chain.

### Phase 1 — Strategic minimum · complete

### Phase 2 — Battle deep dive

2.1 **Engagement record and deployment split.** Restructure battle initiation
before adding a second battle type, not after. Includes edge-deployment geometry
and destination bearing.

2.3 **Set-piece battles.** Capture point, tug-of-war contest, surrender,
prisoner logging. Both role directions.

2.4 **Morale and rout.** The missing victory condition. Army-level morale,
derived where possible.

2.5 **Post-battle march for a repulsed army.** The only remaining hole in
lifecycle stage 11.

2.6 **Fatigue.** Per-block accumulation, effects at deployment, projection at
planning time. In phase two because its whole visible effect is on the
battlefield, and the visibility invariant means tuning it requires seeing what
it does to a fight.

2.7 **Ambushes.** One order type and one deployment plan. Cheap once 2.1 lands,
and optional at the end of the phase — the order type is strategic-side work and
may fall more naturally into phase three. Decide once set-piece is done.

Boundary radius, the battle clock cap and the capture contest formula are all
tuned here, against played battles rather than in the abstract.

### Phase 3 — Strategic layer and story

3.1 **Auto-resolve.** Not a finishing touch and not battle work — it is the gate
on everything else in this phase. Nothing that makes the cartel a live opponent
functions until unattended battles resolve.

3.2 **Save/load.** Lock the serialization schema.

3.3 **Strongholds and frontier gating.** The primary movement constraint.

3.4 **Water and air movement.** Unlocks the rest of Tanoa.

3.5 **Route exposure and interception,** surfaced at planning time as a route
coloured by exposure.

3.6 **Economy.** Money, manpower, recruitment, wages.

3.7 **Favor and aggression, in full.** Accrual triggers, decay, display, spend
menu, one spendable asset end to end.

3.8 **Locations, in full.** Per-location benefits, ownership transfer, local
opinion and its diffusion. Opinion is shaded per location on the draw layer; a
number in a menu does not satisfy the visibility invariant.

3.9 **Prisoner disposition.**

3.10 **Sleep cycles.** Full 24-hour model replacing interim fatigue.

3.11 **Progression.** Soldier names, ranks, loadouts.

3.12 **Spectate, and the choice of whether to drop in.** Drop-in itself shipped
early because the map command interface needs a player in the deployed group.
What remains is making it optional and building overhead spectate.

3.13 **Story progression.** Contract structure and the fixed campaign arc.

**Battle-layer work during phase 3** is tuning and finishing — numbers, not
structure. If phase three turns up a need to restructure the battle lifecycle,
that is a signal phase two ended early. Auto-resolve is the one exception, and
it is listed first precisely because it is not a tweak.

---

## Appendix A — Engine Quirks

Properties of Arma, not of this codebase. Several sections above are shaped by
these rather than by preference, and the design rule they produce is noted where
one exists.

### Markers and the Draw layer

- **Marker extent cannot be queried.** `getMarkerSize` returns the multiplier
  that was set, not a rendered extent, and the base dimensions sit in
  `CfgMarkers` behind an engine constant. Nothing drawn beside a marker can be
  aligned to it or scaled with it except by fitting a constant by eye and
  trusting that no patch and no per-user map text scale moves it. → *One entity,
  one renderer* (section 11).
- **Marker icons scale with map zoom; drawn elements scale by whatever law the
  Draw handler applies.** The two do not compose at any zoom, for any pair of
  elements.
- **Marker artwork is reusable.** Reading the icon path out of `CfgMarkers`
  returns the same texture the engine draws, so a drawn icon and a marker read
  as one visual system.
- **`drawIcon`'s text size is in world metres,** like its width and height, so
  labels scale with icons rather than staying a fixed size on screen.
- **`drawEllipse` takes world coordinates and clips itself.** Guarding a drawn
  shape on `ctrlMapWorldToScreen` returning non-empty is wrong: that call fails
  whenever the *centre* leaves the screen, so panning away drops the entire
  shape instead of clipping it.
- **Draw handlers render over the map's content, never instead of it.** Anything
  the engine already draws must be switched off explicitly or it shows through
  underneath. → *Two command surfaces, never at once* (section 12).
- **`disableMapIndicators` only takes effect while commanding.** Outside command
  mode the engine draws its own unit icons regardless.

### Map display and input

- **Display 12 does not exist until the player opens the map.** A Draw handler
  attached while it is closed attaches to a null control and silently renders
  nothing — and the control is a frame or more behind the open, so waiting on
  the display alone is not enough. → *Attach on map open* (section 12).
- **Remove handlers by stored id, never by clearing all handlers on the
  control.** More than one system attaches to the map control and clearing takes
  the others out with it.
- **`ctrlMapMouseOver` resolves markers and engine icons only.** It cannot see
  drawn items, so hit-testing anything in the Draw layer is written by hand.
- **`onMapSingleClick` reports SHIFT and ALT and nothing else.** Selection needs
  CTRL, so command mode reads the map control's own `MouseButtonDown` and
  `MouseButtonUp` instead.
- **The map's own scrolling is a click and drag,** so a press cannot be treated
  as a click. A release close to its press is a click; anything further is a
  pan.

### Sides and relations

- **`setFriend` takes 0..1 and the engine reads anything above 0.6 as
  friendly.** Write blocs as the extremes.
- **Side relations are global and take effect in the same frame for every unit
  on the map,** including any already in a fight. → A CSAT turn is a
  between-block event, never a mid-battle one (section 8).
- **EAST and WEST are permanently hostile** and `setFriend` cannot change it.
- **CIVILIAN is default-friendly to every side,** so a naive "is this group
  allied" test passes every civilian on Tanoa whole. Exclude it explicitly.
- **The engine paints INDEPENDENT green in its own UI** — squad bar and map unit
  icons — regardless of the mission's palette (section 11).

### Data

- **`isEqualTo` on a HashMap is a content comparison.** Two structurally
  identical records are indistinguishable, which is why armies and engagements
  carry explicit ids and identity is never compared any other way.
- **Hitpoint layout can be read from `CfgVehicles` without spawning the
  vehicle,** so damage state can be modelled for a vehicle that is not on the
  map.

### Units, groups, and AI

- **AI follow their leader,** so a group whose leader is the player does not
  execute a group `move` order. A player-led army holds at deployment until
  ordered while an AI side advances on its standing order — the two sides of a
  battle are driven differently.
- **A group with no player in it executes a waypoint chain natively** —
  sequencing, completion radii, and a real hold type — with no script watching
  it. Chained and held orders for the player's own group therefore belong to
  detach-and-command, not to a loop that watches for arrivals and re-issues
  `doMove`. That workaround was built once and removed: every guard it needed
  was another condition under which commanding behaved differently.
- **`setSpeedMode` is group-level.** Holding vehicles to foot pace in a mixed
  group has to be done per object, or the infantry being matched to is slowed
  as well.
- **`objectParent` is what decides whether a man actually got a seat.** Seat
  availability queried in advance does not survive the attempt.
- **Hiding does not reliably take on a unit that is currently the player.** Hide
  it after control has moved elsewhere, when it is an ordinary object again.
- **`selectPlayer` is a singleplayer mechanism** with no multiplayer
  equivalent. → Open decision 1.

### Terrain and pathfinding

- **Road pathfinding returns nothing at all** for a position more than roughly
  150 m from a road — not a short path, an empty one. Anything downstream needs
  a fallback rather than a guard.
- **Unbounded Dijkstra over Tanoa's full road graph can stall.** → Open
  decision 7.
