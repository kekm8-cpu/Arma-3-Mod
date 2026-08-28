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

// What a battle costs the strategic clock. One real second of fighting buys
// 14400 / 2400 = 6 seconds of block time, so a battle that runs its full length
// consumes exactly one whole block and a short one leaves time over to march
// with. The cost is clamped to whatever block time was left when the battle
// opened: a battle that starts late still gets its full 40 minutes, but from
// the strategic layer's side it can never outlast the block it began in.
TACT_blockSecondsPerBattleSecond = (STRAT_blockLengthHours * 3600) / TACT_battleRealSecondsMax;

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

// Contact detection is no longer a background thread. TACT_fnc_detectContact
// runs as a step inside STRAT_fnc_resolveTurn, after movement has been applied
// for the slice, and battles open and close inside the block they belong to.

// ------------------------------------------------------------------------- //
// OPEN THE FIRST PLANNING PHASE                                              //
// ------------------------------------------------------------------------- //
call STRAT_fnc_beginPlanning;
