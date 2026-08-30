/*
	Function: TEST_fnc_spawnBattle

	Description:
		Build plan 1.5. Spawns a named engagement directly with fixed rosters,
		bypassing the turn entirely: no planning phase, no order, no march, no
		contact detection. Two armies exist, a battle opens between them, and
		it runs to a classified conclusion through the same lifecycle a
		detected contact does.

		It bypasses the turn but not the battle code. TACT_fnc_buildEngagement,
		TACT_fnc_initiateBattle, TACT_fnc_runBattle and TACT_fnc_concludeBattle
		are called exactly as STRAT_fnc_resolveTurn calls them, so what is
		tested here is what ships. The only thing supplied by hand is the
		block time the engagement believes it has, which the turn would
		otherwise have counted down.

		The battle runs asynchronously - TACT_fnc_runBattle sleeps - so this
		returns as soon as deployment has succeeded or failed. The strategic
		layer is returned to the planning phase once the fight ends, with
		whoever survived standing where they finished.

	Parameters:
		0: STRING or ARRAY - engagement name in TEST_engagements, or an inline
		   [_specA, _specB] pair of army specs (see TEST_fnc_buildArmy)
		1: ARRAY - optional anchor. Supplied, both armies are translated so the
		   midpoint between them lands here, keeping their separation and
		   facing. Empty (default) leaves them at the positions the spec names.
		2: BOOL - clear the map first (default true). False spawns the
		   engagement alongside whatever is already on the map.

	Returns:
		HASHMAP - the engagement record, or empty if it could not be opened.
*/

params [
	["_engagementSpec", "", ["", []]],
	["_anchor", [], [[]]],
	["_clearFirst", true, [true]]
];

// ------------------------------------------------------------------------ //
// 1. GUARDS                                                                 //
// ------------------------------------------------------------------------ //
// While a block is resolving the turn loop owns battle initiation, and it
// holds the strategic clock still for the length of whatever it opened. A
// second battle spawned underneath it would be charged to nobody's clock.
if (!isNil "STRAT_resolutionRunning" && {STRAT_resolutionRunning}) exitWith {
	systemChat "TEST: a block is resolving. Wait for the planning phase.";
	createHashMap
};

if (count TACT_activeEngagements > 0) exitWith {
	systemChat "TEST: a battle is already running.";
	createHashMap
};

// ------------------------------------------------------------------------ //
// 2. RESOLVE THE ENGAGEMENT                                                 //
// ------------------------------------------------------------------------ //
private _pair = [];

if (_engagementSpec isEqualType "") then {
	if (!isNil "TEST_engagements" && {_engagementSpec in TEST_engagements}) then {
		_pair = TEST_engagements get _engagementSpec;
	} else {
		diag_log format ["TEST Harness: unknown engagement '%1'.", _engagementSpec];
	};
} else {
	_pair = _engagementSpec;
};

if (count _pair != 2) exitWith {
	systemChat "TEST: engagement needs exactly two army specs.";
	createHashMap
};

_pair params ["_specA", "_specB"];

// Optional relocation. Translating both specs by the same vector keeps the
// separation and the bearing the engagement was written with - the fight is
// the same fight, just somewhere the player can stand and watch it.
if (count _anchor >= 2 && {count _specA > 2} && {count _specB > 2}) then {
	private _posA = _specA select 2;
	private _posB = _specB select 2;

	private _shiftX = (_anchor select 0) - (((_posA select 0) + (_posB select 0)) / 2);
	private _shiftY = (_anchor select 1) - (((_posA select 1) + (_posB select 1)) / 2);

	_specA = +_specA;
	_specB = +_specB;
	_specA set [2, [(_posA select 0) + _shiftX, (_posA select 1) + _shiftY, 0]];
	_specB set [2, [(_posB select 0) + _shiftX, (_posB select 1) + _shiftY, 0]];
};

// ------------------------------------------------------------------------ //
// 3. BUILD THE ROSTERS                                                      //
// ------------------------------------------------------------------------ //
// Written flat rather than nested: `exitWith` unwinds the scope it stands in,
// and a scope opened by `then` is not the function's.
if (_clearFirst && {!([] call TEST_fnc_clearArmies)}) exitWith {
	systemChat "TEST: the map could not be cleared. Wait for the planning phase.";
	createHashMap
};

private _armyA = [_specA] call TEST_fnc_buildArmy;
private _armyB = [_specB] call TEST_fnc_buildArmy;

if (count _armyA == 0 || {count _armyB == 0}) exitWith {
	systemChat "TEST: an army spec failed to build. See the log.";
	createHashMap
};

if (!([_armyA get "faction", _armyB get "faction"] call STRAT_fnc_areHostile)) then {
	// Not fatal - a same-bloc engagement is a legitimate thing to want to
	// watch - but it will run to the battle clock cap, so say so rather than
	// let forty minutes of nothing look like a bug.
	systemChat "TEST: these two factions are not hostile. Expect a mutual disengage at the clock cap.";
};

// ------------------------------------------------------------------------ //
// 4. OPEN THE BATTLE                                                        //
// ------------------------------------------------------------------------ //
// A spawned engagement is handed a full block. There is no turn counting
// down, and TACT_fnc_runBattle only reads this to show what the fight has
// cost - the cost is charged to a block by the caller, and here there is no
// caller with a block to charge.
private _engagement = [_armyA, _armyB, STRAT_blockLengthHours] call TACT_fnc_buildEngagement;

if (!([_engagement] call TACT_fnc_initiateBattle)) exitWith {
	systemChat "TEST: deployment failed, engagement abandoned. Both sides need at least one man on the roster.";
	createHashMap
};

TACT_activeEngagements pushBack _engagement;

// No block is resolving - there is no turn here at all - but the phase closes
// input for the duration anyway. Orders, a SPACE commit and a second SHIFT+B
// all read this flag, and any of the three landing on top of a running battle
// would put a second fight or a whole marching block underneath one that is
// already being watched. STRAT_fnc_beginPlanning reopens it below.
STRAT_turnPhase = "resolving";

diag_log format [
	"TEST Harness: engagement %1 opened directly - %2 vs %3 at %4.",
	_engagement get "id",
	_armyA get "name",
	_armyB get "name",
	_engagement get "boundaryAnchor"
];

// ------------------------------------------------------------------------ //
// 5. RUN IT                                                                 //
// ------------------------------------------------------------------------ //
// Spawned, because TACT_fnc_runBattle sleeps until the fight concludes.
_engagement spawn {
	private _engagement = _this;

	[_engagement] call TACT_fnc_runBattle;

	TACT_activeEngagements = TACT_activeEngagements select {
		!((_x get "id") == (_engagement get "id"))
	};

	// Back to the strategic map. The turn never opened, so nothing advances
	// the clock; the planning phase is simply reopened over whatever the
	// battle left standing.
	call STRAT_fnc_beginPlanning;
};

_engagement
