// =========================================================================
// BLOCK 1: STATE INITIALIZATION & DATA SETUP
// =========================================================================
// Global variables, faction relations, and the structured "Army" HashMap
// objects that make up the overworld. The functions themselves live under
// functions\ and are compiled by CfgFunctions in description.ext.

// Wait for main displays to load
waitUntil {!isNull (findDisplay 46) && !isNull (findDisplay 12)};

// ------------------------------------------------------------------------- //
// SIDE RELATIONS (section 8)                                                 //
// ------------------------------------------------------------------------- //
// Four story factions packed into Arma's four sides. Relations are global, so
// this block and STRAT_fnc_factionSide are two halves of one decision and are
// changed together:
//
//   player    -> INDEPENDENT   friendly to EAST, hostile to WEST
//   csat      -> EAST          friendly to INDEPENDENT
//   drugLords -> WEST
//   nato      -> WEST          shares the cartel side with drugLords
//
// setFriend takes 0..1 and the engine reads anything above 0.6 as friendly,
// so the blocs are written as the extremes.

// The contractors and their CSAT patron
independent setFriend [east, 1];
east setFriend [independent, 1];

// The contractors against the cartel and its NATO backer
independent setFriend [west, 0];
west setFriend [independent, 0];

// The patron against the cartel. WEST and EAST are permanently hostile in the
// engine and setFriend cannot change that; the pair is written anyway so the
// whole relation map reads from one block.
east setFriend [west, 0];
west setFriend [east, 0];

// Initialize the central tracker for all active forces on the map
activeArmies = [];

// ------------------------------------------------------------------------- //
// TURN MODEL STATE                                                           //
// ------------------------------------------------------------------------- //
// WEGO with fixed blocks: both sides plan, both commit, the block resolves
// simultaneously and is watched in compressed time.

STRAT_blockLengthHours = 4;   // Block length in game hours
STRAT_blocksPerDay     = 6;   // Six blocks per day

// Compression of the watched execution phase, in real seconds per hour of
// block time. This paces marching only: a full block is two minutes of
// watching, and a 14 km road march at 30 km/h is about 14 seconds of it.
//
// It does NOT pace battles. The tactical layer runs at 1:1 real time and keeps
// its own clock - see TACT_battleRealSecondsMax below.
//
// Still open, still wants playtesting; this is the only place it is defined.
STRAT_realSecondsPerBlockHour = 30;

// End the watch early once every army is idle. The rest of the block still
// passes on the clock; there is simply nothing left to watch.
STRAT_skipIdleResolution = true;

STRAT_blockIndex        = 0;           // Blocks elapsed since campaign start
STRAT_turnPhase         = "planning";  // "planning" or "resolving"
STRAT_resolutionRunning = false;       // Guards against a double commit

// The world clock moves in block steps, not in real time, so it is pinned as
// slow as the engine allows and advanced explicitly by STRAT_fnc_advanceClock.
setTimeMultiplier 0.1;

// ------------------------------------------------------------------------- //
// FAVOR ECONOMY BALANCES                                                     //
// ------------------------------------------------------------------------- //
// Two mirrored currencies (pillar 2). Only the balances and the two call
// points the battle layer needs exist yet - STRAT_fnc_addAggression and
// STRAT_fnc_spendFavor. Accrual triggers, decay, display and the spend menu
// are phase 3.7, and the asset catalogue with them.

// Accrues from the player's own tactical conduct and pays out to the
// druglords. Starts clean: nothing has been done yet.
STRAT_natoAggression = 0;

// Spent on rare CSAT vehicles, airstrikes, spec-ops backup and intel.
//
// PLACEHOLDER. Favor is earned by completing CSAT objectives and by restraint,
// neither of which exists until 3.7, so a zero balance would leave every
// support-call path built in phase two untestable. This is a starting stake to
// spend against during the deep dive, not an economy decision.
STRAT_csatFavor = 100;

// ------------------------------------------------------------------------- //
// FATIGUE CURVE                                                              //
// ------------------------------------------------------------------------- //
// Read by STRAT_fnc_armyFatigue to turn per-soldier exertion into an
// army-level 0..1 value. Nothing accumulates into exertion yet (build plan
// 2.6), so every army currently reports 0; these shape the curve for when it
// does.
//
// UNTUNED. Fatigue is tuned in phase two against played battles - its whole
// visible effect is on the battlefield, so the numbers cannot be settled in
// the abstract. The shape is section 6's: free below a threshold, gentle for
// the first hour past it, steepening after.
//
// At these values a soldier reads roughly 0.02 fatigued after two hours on
// foot, 0.18 after four (one full block of marching), 0.51 after six, and
// fully spent at eight.
STRAT_fatigueFreeHours  = 1;   // Exertion below this costs nothing
STRAT_fatigueSpentHours = 8;   // Exertion at or above this is fully spent
STRAT_fatigueCurvePower = 2;   // >1 steepens; 1 would be a flat ramp

// ------------------------------------------------------------------------- //
// BATTLE STATE                                                               //
// ------------------------------------------------------------------------- //

// Contact radius must stay below twice the boundary radius. Armies deploy from
// their own positions toward the midpoint, so at the moment of contact each is
// half the contact radius from the anchor; if that exceeds the boundary radius
// they start the battle already outside the boundary and it ends instantly.
TACT_contactRadius  = 1000;  // Hostile armies inside this distance engage
TACT_boundaryRadius = 750;   // Battle boundary; leaving it ends the battle

// One attended battle at a time. Every battle currently spawns and is watched,
// so until unattended battles can be resolved mathematically, further contacts
// wait rather than opening battles nobody is at.
TACT_maxAttendedBattles = 1;

// Battles run at 1:1 real time - the tactical layer is realtime Arma and there
// is nothing to compress. The battle clock caps a fight at 40 real minutes,
// after which neither side has broken the other and the engagement ends in
// mutual disengage.
TACT_battleRealSecondsMax = 2400;

// What a battle costs the strategic clock: battle time IS block time, one for
// one. Forty minutes of fighting is forty minutes of the block, so a
// full-length battle spends a sixth of a 4-hour block and a short one costs
// proportionally less.
//
// That is a heavier price than the fraction suggests. A 14 km road march - the
// length of Tanoa - is about 28 minutes of block time at 30 km/h, so a
// full-length battle costs more block time than crossing the island.
//
// The cost is clamped to whatever block time was left when the battle opened:
// a battle that starts late still gets its full 40 minutes, but from the
// strategic layer's side it can never outlast the block it began in.
TACT_blockSecondsPerBattleSecond = 1;

// ------------------------------------------------------------------------- //
// BATTLE COMMAND MODE                                                        //
// ------------------------------------------------------------------------- //
// When a battle deploys an army carrying a soldier flagged `isPlayer`, the
// player takes that soldier's body with selectPlayer. He is an ordinary member
// of the roster - spawned by deployment, counted in the army's strength, and
// killable - so no battle-layer code has a special case for him.
//
// Two command surfaces then exist and they never overlap:
//
//   map closed - Arma's stock squad bar. F1, F2, F3 select subordinates and
//                orders are given in the 3D world. Untouched.
//   map open   - the squad bar is hidden and the map is the command surface.
//                Left click an icon to select it, CTRL to add or remove, click
//                terrain to send the selection there.
//
// A terrain click addresses whoever is selected, and an empty selection
// addresses nobody - it does not fall back to the whole group. The player
// leads that group, so the only order the map could give it is one competing
// with him for control of his own men; whatever the group does as a body, it
// does by following him.
//
// A selected unit gets one destination and no more. Chained waypoints and held
// ground are engine features at the GROUP level - a group with no player in it
// executes an addWaypoint chain natively, HOLD waypoints included - and are
// not reproducible inside a player-led group without a script fighting the
// formation AI for every subordinate. Orders for a body of men, and the split
// that lets one man take them, both arrive with group-level command.
//
// An army with no flagged soldier drops nobody in and never leaves the campaign
// layer, exactly as before.

TACT_commandActive    = false;  // True only while the player holds a body on the field
TACT_commandSelection = [];     // Selected entity objects; empty routes clicks to the group
TACT_commandArmyId    = "";     // Which army record the player is currently leading

// Click radius around a command icon, in the same icon units the draw layer
// uses, so a unit is as easy to click zoomed out as zoomed in.
TACT_commandHitUnits  = 0.60;
TACT_commandIconUnits = 0.85;   // Command icons sit slightly under an army icon

// Yellow: the commander is not another unit to be ordered and should not read
// as one.
TACT_commandPlayerColour = [1, 0.85, 0.2, 1];

// The body the player returns to when a battle ends. Captured on the first
// drop-in rather than set here, so it is whatever the avatar actually was
// rather than whatever init.sqf assumed it would be.
TACT_campaignAvatar = objNull;

TACT_activeEngagements       = [];  // Engagement records currently being fought
TACT_resolvedPairsThisBlock  = [];  // Army id pairs that have already fought this block
TACT_lastBattleReport        = "";  // Shown by the block readout and the planning phase

// ------------------------------------------------------------------------- //
// CAMPAIGN DRAW LAYER (section 11)                                           //
// ------------------------------------------------------------------------- //
// Armies and locations are drawn, not marked. A marker's rendered extent
// cannot be queried, so nothing can be aligned to one at arbitrary zoom, so
// anything that carries adornment - a selection ring, an order arrow that has
// to start at the icon's edge, and later a vehicle badge or a fatigue pip - is
// drawn in full by one pass. See STRAT_fnc_buildDrawList.
//
// Everything the layer draws is sized and placed in ICON UNITS. One icon unit
// is resolved to world metres once per draw pass by STRAT_fnc_mapUnitMetres,
// and every element of every group reads that one figure, so they cannot drift
// apart at any zoom. The numbers below are all in those units unless they say
// otherwise.

// One icon unit as a fraction of the screen's width. This is the scaling law:
// an icon holds a constant size on screen while the player zooms. Making it a
// fixed number of metres instead would scale icons with zoom the way markers
// do - a one-line change in STRAT_fnc_mapUnitMetres, because there is only one
// place the conversion happens.
//
// UNTUNED, like the fatigue curve. It wants an eyeball pass in game against a
// real zoom range, not a decision in the abstract.
STRAT_drawIconScreenSize = 0.030;

// These four are a set and are chosen against each other. A 1x1 icon reaches
// 0.5 units to its edge and 0.71 to its corner, so the hit radius sits just
// outside the edge, the ring just outside the corner, and the label far enough
// below to clear the ring's bottom rather than being struck through by it.
STRAT_drawHitUnits         = 0.70;  // Click radius around a group's anchor
STRAT_drawRingUnits        = 0.85;  // Selection ring radius
STRAT_drawLabelOffsetUnits = 1.10;  // Label drop below the icon
STRAT_drawLabelUnits       = 0.30;  // Label text size
STRAT_drawLocationUnits    = 1.10;  // Location icon, slightly over an army's
STRAT_drawArrowOriginUnits = 0.55;  // Order arrow starts just off the icon edge
STRAT_drawArrowHeadUnits   = 0.45;  // Length of each barb of the arrowhead
STRAT_drawArrowHeadDegrees = 25;    // Sweep of each barb off the shaft
STRAT_drawWaypointPipUnits = 0.18;  // Ring on each stacked waypoint but the last

// How far a mouse press may travel before its release stops being a click and
// starts being a map pan. Screen units, so it is a fraction of screen width.
STRAT_mapClickSlop = 0.01;

// White, so selection reads as a highlight rather than as another faction.
STRAT_drawSelectionColour = [1, 1, 1, 0.9];

// A label is a drawIcon call with no icon. Fully transparent rather than an
// empty string: a procedural colour is the one texture that cannot fail to
// resolve, whatever the engine does with a blank path.
STRAT_drawBlankTexture = "#(argb,8,8,3)color(0,0,0,0)";

// Presentation, derived from `faction` at draw time and stored on nothing.
// `faction` is the source of truth for allegiance and colour is never read
// back - hostility comes from STRAT_fnc_areHostile, which reads faction
// strings. These carry over the colours the armies had as markers.
STRAT_drawFactionColour = createHashMapFromArray [
    ["player",    [0.25, 0.45, 0.95, 1]],
    ["csat",      [0.20, 0.70, 0.35, 1]],
    ["drugLords", [0.90, 0.20, 0.20, 1]],
    ["nato",      [0.95, 0.55, 0.15, 1]]
];

// CfgMarkers classes, used for their artwork only. Reading the texture out of
// the same config the engine draws markers from is what keeps a drawn army and
// an authoring marker looking like one system.
STRAT_drawFactionIcon = createHashMapFromArray [
    ["player",    "b_inf"],
    ["csat",      "b_inf"],
    ["drugLords", "o_inf"],
    ["nato",      "o_inf"]
];

// One silhouette for every location type, with ownership carried by colour and
// the type spelled out in the label. Per-type artwork is presentation work for
// 3.8, when a location first has a mechanic worth distinguishing at a glance.
STRAT_drawLocationIcon = "b_installation";

// ------------------------------------------------------------------------- //
// TEST HARNESS (build plan 1.5)                                              //
// ------------------------------------------------------------------------- //
// Everything down to the scenario call is harness data, not campaign data:
// the rosters a test uses, the starting states a session can boot into, and
// the engagements that can be dropped straight into a fight without a turn.
// It is one block, one prefix and one function domain so that it lifts out
// whole once the campaign has a real opening state of its own.
//
// It replaces two hand-built armies that used to be spawned here directly.
// Naming the states is the whole point: what is on the map at boot is a test
// question, and answering it should not be a code edit.

// Which starting state this session boots into. A key of TEST_scenarios.
//
//   "sandbox"  - one player army and nothing hostile anywhere on the map.
//                Orders, routes and the block clock with the battle layer
//                taken out from under them.
//   "skirmish" - the player army and a cartel patrol, out of contact at the
//                start. A battle happens if the player marches into one.
//   "contact"  - the same two inside TACT_contactRadius, so the first
//                committed block opens a battle immediately.
TEST_scenario = "sandbox";

// Put the mission.sqm avatar on the commanding faction's side at setup. It
// starts on WEST, which section 8 gives to the cartel and its NATO backer, so
// without this the player's own mercenaries deploy hostile to their commander.
// See TEST_fnc_setupScenario.
TEST_alignPlayerSide = true;

// Named rosters: [_menSpec, _vehicleSpec]. Each entry is "className" or
// ["className", count]. The first man listed leads.
//
// Rosters are named rather than written inline so the same force appears in
// every scenario and every engagement that uses it. A battle is only worth
// replaying if what fought it did not quietly change between runs.
//
// The cartel roster still uses O_ unit classes, so these men wear CSAT kit
// while fighting for the cartel on WEST - cosmetic only, since createUnit
// takes the group's side, and the real fix is a cartel-flavoured loadout set
// (phase 3.11), not a different stock faction.
TEST_rosters = createHashMapFromArray [
    ["mercVanguard", [
        ["B_T_Soldier_SL_F", "B_T_Soldier_F", "B_T_Soldier_AR_F"],
        ["B_T_MRAP_01_gmg_F"]
    ]],
    ["cartelPatrol", [
        ["O_T_Soldier_SL_F", "O_T_Soldier_F", "O_T_Soldier_AR_F"],
        ["O_MBT_02_cannon_F"]
    ]]
];

// Placeholder siting, carried over unchanged from the armies these replace.
TEST_playerSpawn = [7774.82, 8842.66, 0];
TEST_cartelSpawn = [8464.34, 9907.8, 0];

// The close variant: the same bearing off the player spawn, pulled in to
// 800 m. That is inside TACT_contactRadius, so the pair engages, and it leaves
// each army 400 m from the midpoint - comfortably inside TACT_boundaryRadius,
// which matters because a battle that opens with either side already outside
// its own boundary ends instantly.
TEST_cartelSpawnClose = TEST_playerSpawn vectorAdd
    ((TEST_playerSpawn vectorFromTo TEST_cartelSpawn) vectorMultiply 800);

// Starting states, built by TEST_fnc_setupScenario. Each is a list of army
// specs, and an army spec is [name, faction, position, roster].
//
// A scenario owns armies and nothing else. Locations are campaign data and are
// seeded below whichever scenario is running.
TEST_scenarios = createHashMapFromArray [
    ["sandbox", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"]
    ]],
    ["skirmish", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"],
        ["O_Cartel_Patrol",   "drugLords", TEST_cartelSpawn, "cartelPatrol"]
    ]],
    ["contact", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"],
        ["O_Cartel_Patrol",   "drugLords", TEST_cartelSpawnClose, "cartelPatrol"]
    ]]
];

// Named engagements for TEST_fnc_spawnBattle: a pair of army specs that is
// spawned straight into a battle, bypassing the turn entirely - no planning
// phase, no order, no march, no contact detection.
TEST_engagements = createHashMapFromArray [
    ["openField", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"],
        ["O_Cartel_Patrol",   "drugLords", TEST_cartelSpawnClose, "cartelPatrol"]
    ]]
];

// Which engagement SHIFT+B spawns. See the key handler in block 2.
TEST_defaultEngagement = "openField";

// Build the starting state. Everything above is data; this is the only line
// here that does anything.
[TEST_scenario] call TEST_fnc_setupScenario;

// ------------------------------------------------------------------------- //
// STRATEGIC LOCATIONS                                                        //
// ------------------------------------------------------------------------- //
// Minimal per build plan 1.2: enough of a record for set-piece battles to be
// built against. Owning a location does nothing else yet - no per-location
// benefits, no ownership transfer, no local opinion. Those are phase 3.8.
//
// Garrisons are static rosters. They never join activeArmies and the turn
// model never sees them; only a set-piece battle reads them.
STRAT_locations = createHashMap;

// Placeholder siting. The position is picked off the harness spawns above so
// the seed location sits on ground the test armies already traverse; real
// campaign locations get sited on actual Tanoa settlements when set-piece work
// lands.
private _plantation = [
    "tanoa_plantation_north",
    "plantation",
    [8600, 9950, 0],
    "drugLords"
] call STRAT_fnc_createLocation;

// A dismounted garrison, which is the normal set-piece case. Note that
// TACT_fnc_deployMen cannot place this yet - it requires at least one vehicle,
// and infantry-only deployment is build plan 2.2.
[_plantation, "O_T_Soldier_SL_F", true] call STRAT_fnc_addGarrisonMan;
[_plantation, "O_T_Soldier_F", false] call STRAT_fnc_addGarrisonMan;
[_plantation, "O_T_Soldier_AR_F", false] call STRAT_fnc_addGarrisonMan;

// Keep old tracking reference for backwards compatibility with your click hooks
STRAT_selectedArmy = nil;

// =========================================================================
// BLOCK 2: INTERFACE HOOKS & EVENT HANDLERS
// =========================================================================
// Wiring the functions to engine hooks to capture mouse input and drive the
// simulated overworld loops.

onMapSingleClick { _this call STRAT_fnc_onMapClick };

// ------------------------------------------------------------------------- //
// CAMPAIGN DRAW LAYER ATTACHMENT (section 11)                                //
// ------------------------------------------------------------------------- //
// Display 12 is destroyed when the map closes and rebuilt when it opens, so
// the Draw handler is attached on map open and never on state change - a
// handler attached while the map is closed lands on a null control and renders
// nothing. Because armies are drawn rather than marked, that failure would not
// be cosmetic: it would be an empty strategic map.
// One call, and the function owns the lifecycle from here: it waits for the
// map to be open and its control built, attaches, waits for the close, and
// goes round again.
call STRAT_fnc_attachMapLayer;

// SPACE commits the block. Planning closes on this key and there is no input
// again until resolution ends.
//
// SHIFT+B is the test harness (build plan 1.5): it clears the map and spawns
// TEST_defaultEngagement straight into a battle, no turn required. The harness
// is expected to be used several hundred times during phase two, so it is one
// key rather than a debug-console paste. It takes SHIFT because an unmodified
// key would put a whole engagement on the ground on a mis-press.
(findDisplay 46) displayAddEventHandler ["KeyDown", {
    params ["_display", "_key", "_shift"];

    // DIK 57 = Space
    if (_key == 57 && {STRAT_turnPhase == "planning"}) exitWith {
        call STRAT_fnc_commitTurn;
        true    // Consume the key so it does not also reach the player unit
    };

    // DIK 48 = B
    if (_key == 48 && {_shift} && {STRAT_turnPhase == "planning"}) exitWith {
        // Anchored on the player so the fight opens where they are standing
        // and can be watched without driving to it. Pass no anchor to fight it
        // at the coordinates the engagement names instead.
        [TEST_defaultEngagement, getPosATL player] call TEST_fnc_spawnBattle;
        true
    };

    false
}];

// Contact detection is no longer a background thread. TACT_fnc_detectContact
// runs as a step inside STRAT_fnc_resolveTurn, after movement has been applied
// for the slice, and battles open and close inside the block they belong to.

// ------------------------------------------------------------------------- //
// OPEN THE FIRST PLANNING PHASE                                              //
// ------------------------------------------------------------------------- //
call STRAT_fnc_beginPlanning;
