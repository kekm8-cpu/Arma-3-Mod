# Project Manifest — Strategic Layer Mod (Arma 3 / Tanoa)

Attach this as project context. It describes the intended scope, the data model,
current implementation state, and the invariants that must not be broken.

**Revision note:** the strategic layer was originally prototyped as realtime.
It is now specified as turn-based (WEGO). Sections 5, 7, and 12 reflect that
decision; parts of the existing codebase still assume realtime and are flagged
in section 12.

**Previous revision** added section 10, the battle type model, and closed two
open decisions (execution presentation, boundary enforcement) that the battle
model forced.

**This revision** replaces the flat milestone list with a three-phase build
plan (section 14): a strategic minimum, a battle-layer deep dive, then a return
to the strategic layer and story progression. Sections 12 and 13 are annotated
with the phase each item belongs to.

---

## 1. Premise

The player is a mercenary captain contracted by CSAT to dismantle druglord
networks on Tanoa. The druglords are covertly backed by NATO. The player begins
as a small outfit in one corner of the island chain and expands outward.

**Structure:** a turn-based strategic map where armies move as markers and
orders resolve simultaneously. When hostile armies converge, the strategic layer
collapses into a live Arma tactical battle. When the battle ends, surviving
personnel and materiel are written back to data and the campaign advances.

The tactical layer is realtime Arma. The strategic layer is not.

---

## 2. Design Pillars

1. **Persistence over spectacle.** Soldiers are data first, entities second.
   Names, skill, health, and condition survive across battles. A named rifleman
   who takes a leg wound in battle three deploys wounded in battle four.
2. **The favor economy.** Two mirrored currencies drive escalation:
   - **CSAT Favor** — spent on rare CSAT vehicles, airstrikes, spec-ops
     reinforcement, intel.
   - **NATO Aggression** — accrues from the player's own conduct (indirect fire,
     mines, collateral damage near civilians) and pays out the same categories
     of asset to the druglords.
   Every tactical shortcut has a strategic price. This is the central tension.
3. **Commit, then live with it.** Orders are issued during a planning phase and
   cannot be revised mid-block. The game rewards anticipation rather than
   vigilance.
4. **The map means something.** Docks, airfields, plantations, and towns confer
   distinct benefits and carry distinct garrison strength. Airports are heavily
   defended and heavily rewarded.
5. **Command, don't solo.** In battles the player attends, they issue orders
   while personally vulnerable. In battles elsewhere, they may drop in as the
   army's commander or observe from above.

---

## 3. Resources

| Resource | Gained by | Spent on |
|---|---|---|
| Money | Contracts, captured assets, controlled locations | Recruitment, vehicles, wages, bribes |
| Manpower | Recruitment at friendly locations | Replacing losses |
| CSAT Favor | Completing CSAT objectives, restraint | Rare vehicles, airstrikes, spec-ops backup |
| NATO Aggression | Collateral damage, explosive ordnance near civilians | *(Adversarial — spent by the druglords)* |

Transport capacity is not a currency but functions as one. See section 6.

Prisoners are a prospective resource. They are recorded on capture; their
disposition is deferred. See section 10.

---

## 4. Conventions

- **`STRAT_fnc_*`** — strategic layer. Lives in `functions\<domain>\`.
- **`TACT_fnc_*`** — tactical layer, battle lifecycle. Lives in `functions\battle\`.
- All functions are registered in `description.ext` under `CfgFunctions`.
- File naming is `fn_<name>.sqf`, matching the class entry.
- Every function carries a header block: purpose, params, return.
- Army/soldier/vehicle records are **HashMaps**, never arrays-by-index.
- Data records own the truth; spawned entities are transient views of that data.

### File layout

```
description.ext              CfgFunctions registry
init.sqf                     World bootstrap, side relations, event hooks
mission.sqm                  Player start
functions/
  army/                      fn_generateArmy, fn_addMan, fn_addVehicle,
                             fn_areHostile, fn_factionSide
  location/                  fn_createLocation, fn_getLocation,
                             fn_addGarrisonMan, fn_addGarrisonVehicle
  movement/                  fn_calculateRoadPath, fn_moveArmyAlongPath
  turn/                      fn_beginPlanning, fn_issueOrder,
                             fn_projectArrival, fn_commitTurn, fn_resolveTurn,
                             fn_applyUpkeep, fn_advanceClock
  ui/                        fn_onMapClick
  battle/                    fn_detectContact, fn_buildEngagement,
                             fn_initiateBattle, fn_deployMen, fn_deployVehicles,
                             fn_drawBoundary, fn_resolveVictory,
                             fn_concludeBattle, fn_syncBack
                             (planned) fn_captureLoop, fn_autoResolve
```

---

## 5. The Turn Model

**WEGO with fixed blocks.** Both sides plan, both sides commit, the block
resolves simultaneously. Not IGOUGO — coordinated multi-asset operations
require concurrent resolution.

- **Block length: 4 hours.** Six blocks per day.
- **No mid-block interruption.** Orders stand for the full block. This is the
  commitment that distinguishes the model from realtime, and it must be
  enforced without exception.
- **Planning phase** — the player issues orders for every detachment and asset.
  Projected outcomes (arrival times, fatigue on arrival, exposure) are shown
  before commit.
- **Execution phase** — the block resolves. Movement, contact detection, and
  battle initiation all happen inside it. The player watches; they do not act.

### Execution is watched, always

**Decision closed.** The block always resolves in compressed time with the
player watching. Instant resolution with a report was the cheaper option and is
rejected, for two reasons:

1. It sells the simultaneity that justifies WEGO.
2. It removes the ambush tell. If resolution is normally instant, then any
   transition into the tactical layer is itself information. If watching is the
   default, an ambush is just something that happens during a watch the player
   was having anyway.

### Battle time is block time

A tactical battle is paid for out of the block it occurs in, and when it
concludes, whatever block time remains is spent continuing the strategic march.

**The two layers keep different clocks.** The strategic execution phase is
compressed — a whole block is a couple of minutes of watching markers move. The
tactical layer is realtime Arma and runs at 1:1: a firefight is the thing the
game is about and there is nothing in it worth compressing.

Battle time and block time run **one for one**: a minute of fighting is a minute
of the block. The battle clock caps a fight at 40 real minutes, so a
full-length battle spends 40 of a block's 240 minutes and a shorter one costs
proportionally less. Only marching is compressed; the fight is not.

A sixth of a block understates what that costs. Tanoa's longest road route is
roughly 12–14 km, about 28 minutes of block time at 30 km/h — so a full-length
battle burns more block time than crossing the island. Time in cover is
distance not covered, measured against the marches people actually make rather
than against the block.

**A battle always gets its full length, whenever in the block it starts.** Its
cost is clamped to the block time that was left when it opened, so a battle
beginning ten block-minutes before the boundary still plays out in full but
costs ten minutes. Fighting inside the last 40 minutes of a block is therefore
cheaper than fighting earlier in one. That is accepted: truncating a real battle
at a bookkeeping line would be the worse trade.

This is the mechanism that gives open field battles their pressure. Time spent
hunkered in cover is distance not covered, and it is felt on the strategic map
rather than enforced by a tactical rule. It follows that:

- The battle clock is a load-bearing mechanic, not UI decoration. It is
  displayed, counting down the real time left before the fight breaks off,
  alongside the block time the fight has burned.
- A battle cannot span a block boundary. If the battle clock runs out with
  neither side broken, the engagement ends in **mutual disengage** — both armies
  separate, fatigue is applied, no ground changes hands.
- The strategic clock holds while a battle runs; armies not in it are advanced
  by the battle's block-time cost once it ends. Concurrent resolution is
  preserved, but that movement is not watched — the player was fighting.

### Clock decoupling

Systems tick at different multiples of the block. Do not assume one rate.

| System | Rate |
|---|---|
| Movement, contact, battle | Every block (4h) |
| Fatigue accumulation | Every block |
| Wages, upkeep, income | Every 6 blocks (daily) |
| NATO aggression decay | TBD, likely every 6 blocks |
| Recruitment availability | TBD |

### Save points

Block boundaries are natural save points with no in-flight state. Serialization
happens between blocks only. Since no battle spans a block boundary, no save
ever contains a battle in progress.

---

## 6. Movement, Gating, and Fatigue

### Distance is not the limiter

Tanoa's longest road route is roughly 12–14 km. Any vehicle crosses the island
inside one block. This is accepted rather than fought: a contractor operating in
secured territory genuinely can reposition freely, and taxing movement inside
owned ground is the least interesting form of friction.

### Gating is by control, not by distance

Movement is unrestricted within controlled territory. Expansion is gated by
**strongholds** — cartel positions that must be cleared before the player can
push further without triggering an engagement. The frontier is the constraint.

### Route choice matters, route length does not

Since length is free, `fn_calculateRoadPath` earns its keep by shaping
**exposure**. Routes through contested ground risk interception; routes that
stay inside friendly influence are safe but longer. This trade is surfaced in
the planning phase as visible information, not resolved as a hidden roll.

Route choice also determines ambush exposure. See section 10.3.

### Fatigue is the cost of foot movement

Marching accumulates fatigue, which degrades combat effectiveness and morale.
The intended long-term model is a **24-hour cycle tracked per soldier**:
cumulative exertion builds across blocks and is reset by 8 hours of sleep (two
blocks). This makes marching all day cost a night rather than a single block,
so rest is a real decision instead of a free recovery.

Design constraints on fatigue:

- **Transport clears it.** Riding arrives fresh. This is what makes vehicle
  availability the genuine scarcity in the game.
- **It must carry a strategic cost, not only a combat modifier.** Exhausted
  formations move slower, respond poorly to interception, or shed stragglers.
  Otherwise fatigue only penalises attacking, which is backwards for a campaign
  about pushing outward.
- **It must be visible before commit.** Under a no-interruption model, a hidden
  penalty discovered after resolution reads as unfair.
- **Curve:** gentle for the first hour past threshold, steepening after. If the
  penalty at four hours isn't bad enough to make arriving a block later look
  attractive, the system isn't doing any work.

**Implementation staging:** fatigue lives on the soldier record from the start
(`exertion`, `hoursSinceSleep`) so detachments can merge and split without
inheriting each other's condition. The full sleep-cycle simulation is deferred;
an army-level fatigue value computed *from* the soldier records is an acceptable
interim stand-in.

### Aircraft

Deliberately unconstrained by range. Limited instead by availability, favor
cost, and NATO detection. Do not fight the fantasy of having a helicopter.

### Fuel

Deferred, and only worth building if **sourcing** is the interesting part. A
meter that drains and refills at friendly bases is bookkeeping. Fuel drawn from
specific captured locations, carried forward by convoys, and vulnerable to
raiding is a supply-line game and reinforces the value of docks and airfields.
Aviation fuel gated behind captured airfields is the strongest version.

---

## 7. Data Model

### Army (HashMap)

| Key | Type | Notes |
|---|---|---|
| `id` | STRING | Unique. Identity comparison uses this, never `isEqualTo` |
| `name` | STRING | Display name |
| `location` | ARRAY | World position, authoritative on the strategic map |
| `path` | ARRAY | Road objects remaining to traverse this block |
| `speed` | NUMBER | km/h, used to resolve progress within a block |
| `marker` | STRING | Map marker name |
| `faction` | STRING | `"player"`, `"drugLords"`, `"csat"`, `"nato"` |
| `men` | ARRAY of HashMap | Soldier records |
| `vehicles` | ARRAY of HashMap | Vehicle records |
| `pendingOrder` | HASHMAP | Order committed during planning, consumed on resolve |
| `inBattle` | BOOL | Suppresses strategic resolution |
| `prisoners` | ARRAY of HashMap | Captured soldier records held by this army |

`isMoving` is a realtime artifact and is replaced by `pendingOrder`.

The army's **destination** lives on `pendingOrder`, not on the army. Battle
deployment reads it from there to compute facing (section 10.1), so
`pendingOrder` must survive into battle setup and must not be cleared at commit.

*Planned additions:* `supplies`, `morale`, `homeLocation`, `transportCapacity`.

### Soldier (HashMap)

`className`, `health` (1.0 = healthy), `skill`, `isLeader`, `obj` (objNull when
not deployed), `exertion`, `hoursSinceSleep`.

*Planned additions:* `name`, `xp`/`rank`, `loadout`, `woundState`, `captureInfo`
(when, where, from which faction).

### Vehicle (HashMap)

`className`, `health` (1.0 = healthy), `hitboxes` (HashMap of hitpoint name →
damage 0–1, read from `CfgVehicles` without spawning), `obj`.

*Planned additions:* `fuel`, `ammoState`, `crewAssignments`, `seats`.

### Engagement (HashMap) — planned

Built by `TACT_fnc_buildEngagement` before deployment. Every battle type
produces one of these; the lifecycle reads it rather than branching on type.

| Key | Type | Notes |
|---|---|---|
| `type` | STRING | `"openField"`, `"setPiece"`, `"ambush"` |
| `attacker` | HASHMAP | Army record. Symmetric — may be the player or not |
| `defender` | HASHMAP | Army record, or a location garrison |
| `boundaryAnchor` | ARRAY | Midpoint (open field/ambush) or location centre (set-piece) |
| `boundaryRadius` | NUMBER | Currently hardcoded 750 |
| `deployment` | STRING | Which placement routine to run |
| `victoryConditions` | ARRAY | Which end conditions are live for this battle |
| `blockTimeRemaining` | NUMBER | Hours left in the block when the battle opened |
| `capturePoint` | HASHMAP | Set-piece only. Position, radius, progress, owner |
| `sprung` | BOOL | Ambush only. False until combat begins |

### Location (HashMap)

| Key | Type | Notes |
|---|---|---|
| `id` | STRING | Unique |
| `type` | STRING | `"port"`, `"town"`, `"plantation"`, `"refinery"`, `"airfield"`, `"dock"` |
| `position` | ARRAY | Centre |
| `owner` | STRING | Faction string |
| `garrison` | HASHMAP | Soldier and vehicle records held in place. Not an army — it has no `pendingOrder` and does not move |
| `flagPos` | ARRAY | Capture point position, centrally located |

A garrison is a static roster, not an army. It shares the soldier and vehicle
record formats so sync-back is one code path, but it never appears in
`activeArmies`.

Ids are authored, not minted — locations are few and fixed, and orders and the
test harness reference them by name.

*Planned additions:* `opinion` (local opinion, per the settlement mechanic) and
per-location benefits, both phase 3.8. Deliberately absent rather than stubbed:
an empty key invites code to read it before the mechanic exists.

### Health convention

Data stores **health** where 1.0 is pristine. Arma stores **damage** where 0 is
pristine. Every boundary crossing is `setDamage (1 - health)` outbound and
`health = 1 - damage` inbound. Do not mix the two conventions inside a function.

---

## 8. Side Allocation

Arma has four sides with globally shared relations, so the story factions must
be packed into them carefully. Intended mapping:

| Story faction | Arma side | Relations |
|---|---|---|
| Player mercenaries | INDEPENDENT | Friendly to EAST, hostile to WEST |
| CSAT (patron) | EAST | Friendly to INDEPENDENT |
| Druglords | WEST | Hostile to INDEPENDENT and EAST |
| NATO (druglord backer) | WEST | Shares a side with the druglords, which gets NATO intervention for free |

The map lives in `STRAT_fnc_factionSide`; the matching `setFriend` block is in
`init.sqf`. Arma's side relations are global, so those two are halves of one
decision and change together. `fn_deployMen` previously put `drugLords` on EAST,
which collided with CSAT and made the patron and the cartel engine-level allies.

Sides are only how the engine is told about the blocs. Hostility itself is
decided from `faction` by `STRAT_fnc_areHostile` and never read off a side.

---

## 9. The Turn and Battle Lifecycle

Each stage is a distinct responsibility; do not merge them. All three battle
types run this same lifecycle — see section 10.

1. **Planning** — player issues orders for every detachment. Projections shown:
   arrival time, fatigue on arrival, route exposure. Orders written to
   `pendingOrder`.
2. **Commit** — planning closes. No further input until the block ends.
3. **Resolution** — all armies advance concurrently against the block's elapsed
   time. Positions and fatigue update. This replaces the realtime movement loop.
4. **Contact detection** — after movement resolves, evaluate hostile army
   proximity and hostile entry into ambush zones and location boundaries.
   Collect pairs first, act after iteration closes.
5. **Engagement construction** — build the engagement record: type, roles,
   anchor, deployment plan, live victory conditions, block time remaining.
6. **Battle decision** — player present or attending?
   - **Attended:** spawn the tactical battle.
   - **Unattended:** auto-resolve mathematically. *(Not yet implemented.)*
7. **Deployment** — compute the anchor, place both sides per the engagement's
   deployment plan, spawn and mount infantry, draw the boundary. Fatigue is
   applied here as skill and morale modifiers.
8. **Battle** — realtime Arma at 1:1. Player issues orders and fights. Favor
   assets may be called in. The battle clock counts down the real time left
   before the fight breaks off; `blockTimeRemaining` is what the fight can
   charge the strategic clock, and caps that charge.
9. **Conclusion** — a victory condition fires, or the battle clock runs out into
   mutual disengage. Outcome is classified (breakthrough, repulse, rout,
   surrender, capture, annihilation, disengage). *(Rout and surrender are not
   live: they need a morale model and the set-piece capture point.)*
10. **Sync-back** — read `damage`, `hitPointDamage`, and alive/dead state off
    every spawned entity into its owning HashMap; move surrendered survivors to
    the victor's `prisoners`; drop dead records; null every `obj` reference;
    delete entities; clear the boundary. *(Prisoners wait on a surrender
    condition to move them.)*
11. **Post-battle march** — surviving armies spend any remaining block time
    continuing or reversing along their route, per the outcome classification.
    *(Continuing works; reversing after a repulse does not.)*
12. **Upkeep** — apply per-block ticks (fatigue) and, on day boundaries, wages,
    income, and aggression decay.
13. **Advance clock** — next planning phase opens.

Stages 9 and 10 are in. The remaining gaps in the lifecycle are auto-resolution
at stage 6 and the reversing half of stage 11.

---

## 10. Battle Types

There are three battle types. **They are not three systems.** They are one
lifecycle with three parameter sets, expressed through the engagement record.
Deployment, victory conditions, boundary anchor, and initial state are the only
things that vary. Conclusion, sync-back, and post-battle march are shared and
must be written once.

`TACT_fnc_initiateBattle` currently hardcodes the open-field answer to all four
parameters. It is to be split: engagement construction first, then a deployment
routine selected by the record.

**Role symmetry is mandatory.** Every type must work with the player as either
attacker or defender, and must auto-resolve when the player is absent. The
cartel attacking a player-held plantation is the same code path as the player
attacking a cartel-held one, with the roles swapped.

### 10.1 Open field battles

Two armies moving to their destinations cross paths. Partially implemented.

**Anchor:** midpoint between the two armies' positions.

**Deployment geometry.** Each army deploys at the point on the boundary circle
nearest its own origin — along the vector from the anchor toward its own
position, at the boundary radius — **facing its destination bearing**, read from
`pendingOrder`. The geometry of the tactical map therefore encodes where
everyone is trying to go. Vehicles deploy along the approach road from that
edge point; `fn_calculateRoadPath` supplies the road nodes as it does now.

**The incentive to advance is strategic, not tactical.** Both armies are trying
to reach somewhere. Time spent in cover is block time burned and distance not
covered. Nothing in the tactical layer needs to force the fight; the block clock
does it.

Two things must be true for that pressure to transmit:

- **Remaining block time carries over** (section 5). Without this the cost of
  dawdling is invisible.
- **The AI must feel it too.** The enemy group is given a `move` order toward
  its own strategic destination and behaviour biased toward pressing rather than
  holding. Otherwise the pressure is asymmetric: the player advances because
  they planned the route, the enemy sits in cover because nothing tells it to
  leave.

**Exit direction is meaningful.** Leaving the boundary is not one outcome:

| Exit | Outcome | Consequence |
|---|---|---|
| Toward destination | **Breakthrough** | Continue the march with remaining block time |
| Away from destination | **Repulse** | Block lost, army returns toward its origin |

Same act, opposite meanings. This is what makes "flee" mechanically legible
instead of a binary that has to be detected.

**Divergent destinations are a valid outcome, not a failure.** If both armies
are racing for the same town, neither can disengage and it is a real battle. If
their destinations diverge, the correct play for both sides is to break contact
and keep marching, and the encounter is a brief exchange of fire in passing.
This makes destination vectors part of route planning rather than interception
risk alone.

**Victory conditions:** breakthrough, repulse, rout, surrender, annihilation,
block-clock expiry (mutual disengage).

### 10.2 Fixed set-piece battles

An attacking army assaults a strategic location: port, town, plantation,
refinery, airfield. These are the meticulously planned battles.

**Anchor:** the location's centre, not a midpoint. The battle is asymmetric —
the defender is already in position, the attacker arrives.

**Deployment:** garrison placed at prepared positions within the location;
attacker deployed at the boundary edge nearest its approach road.

**The capture point.** A centrally located flagpole, flying the defender's
colours, raised.

- An attacker inside the capture radius lowers the flag. When it reaches bottom
  it rises again in the attacker's colours; when it reaches the top, the battle
  ends and the defenders surrender.
- **Contest is a tug of war, weighted by mass.** Net rate is a function of
  attackers minus defenders in the radius. Five attackers against one defender
  capture, but slowly. A defending majority drives progress back toward the
  defender. Presence alone does not stall the flag — bodies do.
- **Progress persists.** Nothing resets progress except the contest itself
  driving it back. Attrition accumulates toward the objective.
- **Reversal cannot pass the starting state.** The defender's flag begins fully
  raised; a driven-back contest returns to that, no further.

**Capture timing must not collapse the battle.** If capture is fast, the
defender's optimal play is to stand on the flag and the assault on a plantation
becomes one firefight in a courtyard. The timer must be long enough (order of
60–90 seconds each direction) that a defender only needs to be able to *return*
to the flag, keeping a perimeter defence viable.

**Surrender is not annihilation.** A flag capture that leaves the defending
roster alive is a distinct outcome and the reason a player would take the flag
rather than grind the garrison down. Survivors become prisoners.

**Prisoners are logged.** On surrender, surviving defender soldier records move
to the victor's `prisoners` array with capture context. Disposition — ransom,
recruitment, release, execution — is a deliberate later decision. Nothing else
should be built assuming a particular answer.

**Victory conditions:** flag capture, rout, surrender, annihilation, attacker
withdrawal, block-clock expiry (assault fails, defender holds).

**Hard dependency:** set-piece battles cannot exist before location records do.
The location and garrison model must land first, at least minimally.

### 10.3 Ambushes

Deferred, but architecturally cheap and worth reserving room for.

Under WEGO both sides have already committed routes during planning, so an
ambush is not a new system — it is **one new order type and one new deployment
plan**. "Conceal and hold at node X," triggering when a hostile army resolves
movement through the zone.

- **Preparation costs a block spent stationary.** This makes ambushing a
  commitment rather than a free option.
- **Prepared assets:** mines and roadblocks placed during the preparation block.
  Scope call between hand-placement and an abstract budget placed by script;
  the budget is the cheaper and preferred version. Mines accrue NATO Aggression
  like any other explosive ordnance.
- **The victim spectates until the ambush is sprung.** They cannot act on the
  knowledge that a battle has begun. This is safe specifically because watched
  execution is the default presentation (section 5) — there is no tell to leak.
- **Deployment:** ambusher concealed off the road; victim deployed in column on
  the road, in march order, moving.

**Victory conditions:** as open field, plus the ambusher's option to break off
after the initial exchange.

---

## 11. Invariants

- **Data outlives entities.** A spawned unit is a temporary projection of a
  HashMap record. Anything that happens in a battle and matters afterward must
  be written back to the record before entities are deleted.
- **`obj` is `objNull` outside of battle.** Never persist a live object
  reference in saved state.
- **Commitment is absolute.** No mid-block order revision, no scrubbing the
  clock backward, no interrupt on player whim. If the player can usefully
  advance in small increments and micromanage, the turn model has collapsed
  back into realtime.
- **Battle time is block time,** one minute for one minute. A battle is paid for
  out of the block it occurs in and never spans a block boundary. Remaining time
  is spent marching.
- **One lifecycle, three parameter sets.** Conclusion, sync-back, and
  post-battle march are written once and shared by every battle type. If a
  battle type needs its own copy of any of them, the engagement record is
  underspecified.
- **Every battle type is role-symmetric and auto-resolvable.** The player may be
  attacker, defender, or absent. No battle type may assume the player attacks.
- **Never mutate `activeArmies` while iterating it.** Collect pairs first, act
  after the loop closes.
- **Identity is compared on `id`, never `isEqualTo`.** `isEqualTo` performs a
  content comparison on HashMaps and will produce false positives.
- **`faction` is the source of truth for allegiance,** not marker colour. Marker
  colour is presentation only.
- **The strategic layer must never spawn entities.** Marker movement and data
  updates only; entity spawning belongs to the tactical layer.
- **Contact detection must check hostility** before initiating. Two friendly
  armies converging is a rendezvous, not a battle.
- **Fatigue lives on the soldier, never on the army.** Army-level values are
  derived, never stored.
- **A garrison is not an army.** It has no `pendingOrder`, does not move, and
  never enters `activeArmies`. It shares record formats only.
- **Anything the player is penalised for must be visible at planning time.**

---

## 12. Implementation Status

**Working**
- Army/soldier/vehicle data construction, including hitpoint layout read from
  config without spawning.
- Dijkstra road pathfinding with position→nearest-road snapping and jink-turn
  correction.
- Vehicle deployment with damage/hitbox restoration; infantry deployment with
  round-robin vehicle mounting and leader placement.
- Map battle boundary rendering.
- Turn skeleton: planning → commit → resolve → advance, movement only.
  `STRAT_fnc_beginPlanning` opens the phase and retires finished orders;
  `STRAT_fnc_issueOrder` queues to `pendingOrder` with an arrival projection;
  `STRAT_fnc_commitTurn` closes planning and hands the block to
  `STRAT_fnc_resolveTurn`, which advances every army concurrently against the
  same elapsed block time in compressed real time; `STRAT_fnc_applyUpkeep` and
  `STRAT_fnc_advanceClock` close the block and reopen planning. Unfinished
  orders stand and carry into the next block.
- Closed battle loop: contact → engagement → battle → conclusion →
  classification → sync-back → return to the strategic map.
  `TACT_fnc_detectContact` runs as a post-movement step inside the block and
  returns hostile pairs; `TACT_fnc_buildEngagement` builds the engagement
  record; `TACT_fnc_initiateBattle` deploys from it and flags both armies
  `inBattle`; `TACT_fnc_runBattle` runs the fight at 1:1 real time against the
  battle clock while the strategic clock holds; `TACT_fnc_resolveVictory`
  classifies annihilation, breakthrough and repulse each tick, with mutual
  disengage forced at the cap; `TACT_fnc_concludeBattle` moves each army's
  strategic position to
  its survivors, applies the outcome to the standing order, and calls
  `TACT_fnc_syncBack`, which writes condition into the records, drops the dead,
  nulls every `obj`, and deletes the entities. Armies rejoin movement
  resolution for whatever is left of the block.
- Hostility gating on contact (`STRAT_fnc_areHostile`): two blocs read from
  `faction`, so converging friendlies are a rendezvous rather than a battle.
- Side allocation per section 8. `STRAT_fnc_factionSide` is the single
  faction→Arma-side map and `init.sqf` sets the matching global relations;
  the druglords sit on WEST with their NATO backer instead of colliding with
  CSAT on EAST.
- Location and garrison records, minimally: `STRAT_fnc_createLocation` with
  `id`, `type`, `position`, `owner`, `garrison`, `flagPos`, registered in
  `STRAT_locations` and looked up by id with `STRAT_fnc_getLocation`.
  `STRAT_fnc_addGarrisonMan` / `addGarrisonVehicle` delegate to the army
  roster builders, so a garrison holds identical soldier and vehicle records.

**Needs conversion to turn-based**

*Converted:* `fn_moveArmyAlongPath` is now a bounded, non-sleeping resolution
pass over a slice of block time; `fn_onMapClick` queues to `pendingOrder`
instead of marching; `isMoving` is gone from the army record, which now carries
`id`, `pendingOrder`, `inBattle`, and `prisoners`. `fn_battleDetectionLoop` is
gone, replaced by `fn_detectContact` as a step inside the block — which also
retires its mutation-during-iteration bug, since detection now collects pairs
and never touches `activeArmies`.

**Needs restructuring for the battle type model**
- Deployment still converges both groups on the anchor. It should place each
  army at its own boundary edge facing its destination bearing. Engagement
  construction is split out of `fn_initiateBattle` already, but the placement
  routine is not yet selected by the record's `deployment` key, which currently
  only names what runs (`"midpointConverge"`).
- `TACT_fnc_buildEngagement` is open-field only: no `capturePoint`, no
  `sprung`, and the attacker/defender assignment is arbitrary because the roles
  are symmetric in a meeting engagement. Set-piece and ambush need it extended,
  not replaced.

*Restructured:* `fn_initiateBattle` now takes an engagement record instead of
two armies and reads the anchor, radius, and roles from it; `fn_drawBoundary`
takes the anchor and radius rather than a raw midpoint, so the drawn circle and
the enforced one cannot drift apart.

**Partial / needs work**
- `fn_deployMen` requires at least one vehicle; infantry-only armies deploy
  nothing, and a dismounted garrison is exactly that case. `fn_initiateBattle` now detects an empty deployment and abandons the
  engagement rather than letting the side be classified as annihilated, so the
  limitation costs a battle but never a roster.
- Only annihilation, breakthrough, repulse, and block-clock expiry are live
  victory conditions. Rout needs a morale model and surrender needs the
  set-piece capture point; neither is claimed in the engagement record.
- A repulsed army stops where it was driven to and its order retires. Marching
  back toward origin is post-battle march work.
- One attended battle at a time (`TACT_maxAttendedBattles`). Further contacts in
  the same block wait, because the alternative — spawning battles the player
  cannot attend — needs auto-resolution first.
- A second battle can open in the same block once the first concludes, so a
  heavily contested block can run past 40 real minutes. Different pairs only —
  the same two armies never re-fight inside one block.
- The player is not moved to an attended battle; there is no drop-in yet, so
  "attended" currently means watched from the map.
- `fn_calculateRoadPath` snaps the start point to the *nearest* road but the end
  point to an arbitrary one; the jink-correction block assumes `_startInput` is
  an array and will error if an object was passed.
- Boundary radius is hardcoded and now load-bearing — it is the withdrawal
  mechanic, so it must be enforced and its crossing direction classified.

**Not started**
- Post-battle march for a repulsed army. Survivors of every other outcome
  rejoin movement resolution for what is left of the block, but a repulsed army
  stops where it was driven to rather than reversing along its route.
- Auto-resolution for unattended battles.
- Set-piece battles and the capture point. The location and garrison records
  they depend on now exist; what is missing is the battle type, not the data.
- Prisoner records and holding.
- Ambush order type and deployment.
- Fatigue accumulation and its effects. `fn_applyUpkeep` holds the per-block
  and per-day hook points it attaches to.
- Stronghold definition and frontier gating.
- Route exposure and interception.
- CSAT Favor and NATO Aggression. The balances and the
  `STRAT_fnc_addAggression` / `STRAT_fnc_spendFavor` hooks are phase 1 work;
  accrual triggers, decay, display, and the spend menu are phase 3.
- Money, manpower, recruitment, wages.
- Battle test harness — spawn a named engagement with fixed rosters, bypassing
  the turn. Phase 1.
- Location capture, ownership transfer, per-location benefits, and local
  opinion. The record deliberately carries no `opinion` key until then.
- Naval and air movement (mandatory on an archipelago — road pathfinding cannot
  leave the island it starts on).
- Save/load serialization.
- Commander drop-in and overhead spectate.
- Soldier names, progression, and loadout persistence.

---

## 13. Open Decisions

**Closed since last revision**

- ~~Execution phase presentation.~~ The player watches every block resolve in
  compressed time. Required by the ambush model. See section 5.
- ~~Boundary enforcement.~~ The boundary *is* the withdrawal mechanic, and
  crossing direction determines whether it reads as breakthrough or repulse.
  See section 10.1.

**Open**

1. **Singleplayer or multiplayer?** This fork affects locality, HashMap
   serialization, and every spawn call. Recommendation: SP first; do not pay MP
   costs until the loop is proven.
2. **Concurrent battles.** How many spawned battles per block? A cap of one
   attended battle with all others auto-resolved is the safe default.
3. **Auto-resolve fidelity.** Pure math, or a fast headless simulation? Math is
   cheaper and more predictable; players tolerate it if the projection is
   legible. Must handle all three battle types, including the capture point.
   Deferred to phase 3 deliberately: whichever approach is chosen has to be
   calibrated against the outcome distribution real battles actually produce,
   which is not known until phase 2 has been played.
4. **Clock rates.** Two tunables in `init.sqf`, both wanting playtesting, and
   nothing else may hardcode either:
   - `STRAT_realSecondsPerBlockHour` (30) — compression of the watched march.
     A block is two minutes of watching.
   - `TACT_battleRealSecondsMax` (2400) — the battle clock. Battles run at 1:1
     real time and break off at 40 minutes.

   `TACT_blockSecondsPerBattleSecond` (1) is the third: battle time is block
   time one for one, so a full-length battle costs 40 of a block's 240 minutes.
   Raising it above 1 would make fighting cost strategic time faster than it
   costs real time. What still needs playtesting is whether 40 minutes is the
   right cap, whether a two-minute block reads as too fast to follow, and
   whether 40 minutes of block time is enough of a price for a battle.
5. **Fatigue curve and thresholds.** Needs playtesting once movement resolution
   exists. The threshold must be tuned against the 4-hour block, not chosen
   independently of it. Tuned in phase 2, where its effects are visible; only
   the derived army-level value is needed in phase 1.
6. **Save format.** HashMaps need flattening to `profileNamespace` or a
   serialized string. Block boundaries make this tractable. Previously flagged
   as urgent on the grounds that the schema should be locked before the data
   model grows; on inspection the phase 2 growth is mostly *transient* —
   engagement records are never saved, since no battle spans a block boundary —
   and the persistent additions (soldier fields, prisoners) are additive rather
   than structural. Deferred to phase 3 on that basis. Revisit if phase 2
   introduces persistent state that is not a field on an existing record.
7. **Pathfinding cost ceiling.** Unbounded Dijkstra over Tanoa's full road graph
   can stall. Consider A* with a distance cap and a fallback to direct movement.
8. **Prisoner disposition.** Ransom, recruitment, release, execution, or some
   combination gated by opinion and aggression. Deliberately deferred; prisoners
   are logged in the meantime so the decision can be made without a retrofit.
9. **Capture contest formula.** The exact function of attacker and defender
   counts, and the flag traversal time. Both need playtesting against the
   perimeter-defence viability constraint.
10. **What counts as a defender in the capture radius.** Whether incapacitated
    or unconscious units hold the point, and whether occupants of a moving
    vehicle passing through count. "One crawling wounded man holds the town
    indefinitely" is a real failure state.
11. **Destination bearing edge case.** If an army's destination lies behind its
    own deployment edge, forward and backward coincide and the exit
    classification is ambiguous. Needs a fallback rule.
12. **Ambush preparation fidelity.** Hand-placed mines and roadblocks versus an
    abstract budget placed by script. Budget preferred on scope grounds.

---

## 14. Build Plan

Three phases. Phase one brings the strategic layer to the minimum that gives the
battle layer real context. Phase two is the battle deep dive. Phase three
returns to the strategic layer and story progression.

The ordering principle: anything that would be **expensive to retrofit into
battle code** goes in phase one, even if its full implementation does not.
Anything that only needs battles to *exist* goes in phase three. Everything else
follows the dependency chain.

### Phase 1 — Strategic minimum

**Already complete.** Turn skeleton (planning → commit → resolve → advance),
closed battle loop (contact → engagement → battle → conclusion → sync-back →
return), and block time accounting. This is the bulk of what phase one was
supposed to deliver; what remains is short.

**Remaining, in order:**

~~1.1 **Fix side allocation.**~~ **Done.** The faction→side map is
`STRAT_fnc_factionSide`, called by `fn_deployMen`; the matching global
relations are set in `init.sqf`. Druglords moved off EAST, where they collided
with CSAT, onto WEST with their NATO backer.

~~1.2 **Locations and garrisons, minimally.**~~ **Done.** `id`, `type`,
`position`, `owner`, `garrison`, `flagPos`, built by `STRAT_fnc_createLocation`
into the `STRAT_locations` registry. Garrison rosters reuse the army record
builders. `opinion` and per-location benefits stay deferred to 3.8.

1.3 **Favor and aggression accrual hooks.** Balances plus
`STRAT_fnc_addAggression` and `STRAT_fnc_spendFavor`. **Not** the economy, not
the spend menu, not the accrual triggers themselves. Aggression accrues from
tactical conduct and favor assets are called in *during* battles, so a battle
layer built with nothing to report to means retrofitting every
explosive-ordnance and support-call path. Same staging pattern as fatigue:
skeleton early, implementation deferred.

1.4 **Derived army fatigue value.** One function over the soldier records,
returning an army-level number. No accumulation yet. Deployment (lifecycle
stage 7) applies fatigue as skill and morale modifiers and needs something to
read.

1.5 **Battle test harness.** Spawn a named engagement directly with fixed
rosters, no turn required. Roughly an hour of work, used several hundred times
during phase two.

**Explicitly deferred out of phase 1:**

| Deferred | Why it can wait |
|---|---|
| Auto-resolve | Better calibrated against real played outcomes. See phase 3.1 |
| Save/load | Battle-layer state is mostly transient. See open decision 6 |
| Naval and air movement | The home island is enough ground to test every battle type |
| Strongholds, route exposure | Neither is read by battle code |
| Economy, recruitment, wages | Only the accrual hooks are needed, not the economy |

### Phase 2 — Battle deep dive

2.1 **Engagement record and deployment split.** Restructure `fn_initiateBattle`
before adding a second battle type, not after. Includes edge-deployment
geometry and destination bearing.

2.2 **Infantry-only deployment.** `fn_deployMen` currently requires at least one
vehicle. Fix before set-piece, where dismounted garrisons are the normal case.

2.3 **Set-piece battles.** Capture point, tug-of-war contest, surrender,
prisoner logging. Both role directions.

2.4 **Morale and rout.** The missing victory condition. Army-level `morale`,
derived where possible, and the rout classification in `fn_resolveVictory`.

2.5 **Post-battle march for a repulsed army.** Reversing along the route. The
only remaining hole in lifecycle stage 11.

2.6 **Fatigue.** Per-block accumulation, effects at deployment, projection at
planning time. Promoted into phase two because its whole visible effect is on
the battlefield, and the visibility invariant means tuning it requires seeing
what it does to a fight.

2.7 **Ambushes.** One order type and one deployment plan. Cheap once 2.1 lands.
Optional at the end of phase two — the order type is strategic-side work, so it
may fall more naturally into phase three. Decide once set-piece is done.

Boundary radius, the battle clock cap, and the capture contest formula are all
tuned here, against played battles rather than in the abstract.

### Phase 3 — Strategic layer and story

3.1 **Auto-resolve.** Not a finishing touch and not battle work — it is the gate
on everything else in this phase. Nothing that makes the cartel a live opponent
(independent operations, multiple simultaneous fronts, the underdog-expanding-
outward shape) functions until unattended battles resolve. Placing it here
rather than in phase one is deliberate: after a phase of played battles the real
outcome distribution is known and the math can be calibrated against it instead
of guessed.

3.2 **Save/load.** Lock the serialization schema.

3.3 **Strongholds and frontier gating.** The primary movement constraint.

3.4 **Water and air movement.** Unlocks the rest of Tanoa and the island
progression.

3.5 **Route exposure and interception.** Surfaced at planning time.

3.6 **Economy.** Money, manpower, recruitment, wages.

3.7 **Favor and aggression, in full.** Accrual triggers, decay, display, spend
menu, one spendable asset end to end. The hooks already exist from 1.3.

3.8 **Locations, in full.** Per-location benefits, ownership transfer, local
opinion and its diffusion.

3.9 **Prisoner disposition.** Whatever the answer to open decision 8 turns out
to be.

3.10 **Sleep cycles.** Full 24-hour model replacing interim fatigue.

3.11 **Progression.** Soldier names, ranks, loadouts.

3.12 **Drop-in and spectate.**

3.13 **Story progression.** Contract structure and the fixed geographic
campaign arc.

**Battle-layer work during phase 3** is limited to tuning and finishing touches
— numbers, not structure. If phase three turns up a need to restructure the
battle lifecycle, that is a signal phase two ended early, not a normal phase
three activity. Auto-resolve is the one exception, and it is listed first
precisely because it is not a tweak.
