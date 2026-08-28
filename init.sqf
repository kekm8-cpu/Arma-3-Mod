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

// Asynchronous Battle Detection Thread
[] spawn TACT_fnc_battleDetectionLoop;
