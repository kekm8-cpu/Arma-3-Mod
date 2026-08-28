// =========================================================================
// BLOCK 1: STATE INITIALIZATION & DATA SETUP
// =========================================================================
// Global variables, faction relations, and the structured "Army" HashMap
// objects that make up the overworld. The functions themselves live under
// functions\ and are compiled by CfgFunctions in description.ext.

// Wait for main displays to load
waitUntil {!isNull (findDisplay 46) && !isNull (findDisplay 12)};

// Set Independents to be hostile towards CSAT
independent setFriend [opfor, 0];
// Set CSAT to be hostile towards Independents
opfor setFriend [independent, 0];

// Initialize the central tracker for all active forces on the map
activeArmies = [];

// ------------------------------------------------------------------------- //
// TURN MODEL STATE                                                           //
// ------------------------------------------------------------------------- //
// WEGO with fixed blocks: both sides plan, both commit, the block resolves
// simultaneously and is watched in compressed time.

STRAT_blockLengthHours = 4;   // Block length in game hours
STRAT_blocksPerDay     = 6;   // Six blocks per day

// Exchange rate between the watched execution phase and block time. At 30 real
// seconds per block hour a full block is two minutes of watching. This is the
// number that also sets the length of every battle once battles run against
// the block clock, and it needs playtesting rather than deriving.
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
// 2. INITIALIZE RED ARMY (OPFOR / CARTEL FORCES)                             //
// ------------------------------------------------------------------------- //
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

// TACT_fnc_battleDetectionLoop is deliberately not spawned. A realtime
// while-loop cannot honour block commitment, and it mutates activeArmies while
// iterating it. Its proximity maths is converted into the contact-detection
// step inside STRAT_fnc_resolveTurn when the battle loop is closed.

// ------------------------------------------------------------------------- //
// OPEN THE FIRST PLANNING PHASE                                              //
// ------------------------------------------------------------------------- //
call STRAT_fnc_beginPlanning;
