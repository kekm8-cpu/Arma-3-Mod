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

TACT_activeEngagements       = [];  // Engagement records currently being fought
TACT_resolvedPairsThisBlock  = [];  // Army id pairs that have already fought this block
TACT_lastBattleReport        = "";  // Shown by the block readout and the planning phase

// ------------------------------------------------------------------------- //
// 1. INITIALIZE BLUE ARMY (BLUFOR / PLAYER'S MERCENARIES)                    //
// ------------------------------------------------------------------------- //
private _blueSpawnPos = [7774.82, 8842.66, 0];

// Generate the base data-driven HashMap
private _blueArmy = ["BLU_Merc_Vanguard", _blueSpawnPos, nil, nil, nil, "player"] call STRAT_fnc_generateArmy;

// Fill the roster: Add 3 men (1 Leader, 2 Riflemen) and 1 Vehicle
[_blueArmy, "B_T_Soldier_SL_F", true] call STRAT_fnc_addMan;
[_blueArmy, "B_T_Soldier_F", false] call STRAT_fnc_addMan;
[_blueArmy, "B_T_Soldier_AR_F", false] call STRAT_fnc_addMan;
[_blueArmy, "B_T_MRAP_01_gmg_F"] call STRAT_fnc_addVehicle;

// Force the marker color to Blue to distinguish it visually on the interface
(_blueArmy get "marker") setMarkerColor "ColorBLUE";

// Register to the global array activeArmies
activeArmies pushBack _blueArmy;

// ------------------------------------------------------------------------- //
// 2. INITIALIZE RED ARMY (CARTEL FORCES, WEST)                               //
// ------------------------------------------------------------------------- //
// The cartel now spawns on WEST per section 8. The roster still uses O_ unit
// classes, so these men wear CSAT kit while fighting for the cartel - cosmetic
// only, since createUnit takes the group's side, and the real fix is a
// cartel-flavoured loadout set (phase 3.11), not a different stock faction.
private _redSpawnPos = [8464.34, 9907.8, 0];

// Generate the base data-driven HashMap
private _redArmy = ["O_Cartel_Patrol", _redSpawnPos, nil, "ColorRED", nil, "drugLords"] call STRAT_fnc_generateArmy;

// Fill the roster: Add 3 men (1 Leader, 2 Sicarios) and 1 Vehicle
[_redArmy, "O_T_Soldier_SL_F", true] call STRAT_fnc_addMan;
[_redArmy, "O_T_Soldier_F", false] call STRAT_fnc_addMan;
[_redArmy, "O_T_Soldier_AR_F", false] call STRAT_fnc_addMan;
[_redArmy, "O_MBT_02_cannon_F"] call STRAT_fnc_addVehicle;

// Register to the global array activeArmies
activeArmies pushBack _redArmy;

// ------------------------------------------------------------------------- //
// 3. STRATEGIC LOCATIONS                                                     //
// ------------------------------------------------------------------------- //
// Minimal per build plan 1.2: enough of a record for set-piece battles to be
// built against. Owning a location does nothing else yet - no per-location
// benefits, no ownership transfer, no local opinion. Those are phase 3.8.
//
// Garrisons are static rosters. They never join activeArmies and the turn
// model never sees them; only a set-piece battle reads them.
STRAT_locations = createHashMap;

// Placeholder siting. The position is picked off the two test armies' spawns
// so the seed location sits on ground they already traverse; real campaign
// locations get sited on actual Tanoa settlements when set-piece work lands.
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

// SPACE commits the block. Planning closes on this key and there is no input
// again until resolution ends.
(findDisplay 46) displayAddEventHandler ["KeyDown", {
    params ["_display", "_key"];

    // DIK 57 = Space
    if (_key == 57 && {STRAT_turnPhase == "planning"}) then {
        call STRAT_fnc_commitTurn;
        true    // Consume the key so it does not also reach the player unit
    } else {
        false
    };
}];

// Contact detection is no longer a background thread. TACT_fnc_detectContact
// runs as a step inside STRAT_fnc_resolveTurn, after movement has been applied
// for the slice, and battles open and close inside the block they belong to.

// ------------------------------------------------------------------------- //
// OPEN THE FIRST PLANNING PHASE                                              //
// ------------------------------------------------------------------------- //
call STRAT_fnc_beginPlanning;
