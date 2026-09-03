/*
	Function: TEST_fnc_buildArmy

	Description:
		Builds one army from a compact spec and registers it in
		`activeArmies`, ready for the turn model or for a directly spawned
		engagement.

		A thin front end over STRAT_fnc_generateArmy, STRAT_fnc_addMan and
		STRAT_fnc_addVehicle that adds no state of its own, so what it produces
		is indistinguishable from an army built by hand.

		Rosters are looked up by name in `TEST_rosters` so an engagement is
		reproducible - a roster fixed in one place cannot drift between the
		scenarios that share it. An inline roster is accepted for one-offs.

	Parameters:
		0: ARRAY - army spec:
		     0: STRING - army name
		     1: STRING - faction ("player", "csat", "drugLords", "nato")
		     2: ARRAY  - spawn position
		     3: STRING or ARRAY - roster name in TEST_rosters, or an inline
		        [_menSpec, _vehicleSpec]. Each spec is an array whose entries
		        are either "className" or ["className", count]. The first man
		        listed leads the group.
		     4: NUMBER - which man the player takes in battle, 1-based into the
		        expanded roster. 0 for none. Omitted, a "player" faction army
		        flags its leader and every other faction flags nobody.

	Returns:
		HASHMAP - the army, already pushed onto activeArmies. Empty on failure.
*/

params [
	["_spec", [], [[]]]
];

_spec params [
	["_name", "", [""]],
	["_faction", "player", [""]],
	["_position", [0,0,0], [[]]],
	["_roster", [], ["", []]],
	["_playerSlot", -1, [0]]
];

if (_name == "") exitWith {
	diag_log "TEST Harness: army spec carries no name, nothing built.";
	createHashMap
};

// ------------------------------------------------------------------------ //
// 1. ROSTER RESOLUTION                                                      //
// ------------------------------------------------------------------------ //
private _resolved = [];

if (_roster isEqualType "") then {
	if (!isNil "TEST_rosters" && {_roster in TEST_rosters}) then {
		_resolved = TEST_rosters get _roster;
	} else {
		diag_log format ["TEST Harness: unknown roster '%1' for army '%2'.", _roster, _name];
	};
} else {
	_resolved = _roster;
};

_resolved params [
	["_menSpec", [], [[]]],
	["_vehicleSpec", [], [[]]]
];

// Expands ["className", count] entries into one entry per unit, so a roster
// can be written at whatever density reads best.
private _fnc_expand = {
	private _out = [];
	{
		if (_x isEqualType "") then {
			_out pushBack _x;
		} else {
			_x params [["_className", "", [""]], ["_count", 1, [0]]];
			if (_className != "") then {
				for "_i" from 1 to _count do { _out pushBack _className };
			};
		};
	} forEach _this;
	_out
};

private _menClasses     = _menSpec call _fnc_expand;
private _vehicleClasses = _vehicleSpec call _fnc_expand;

// ------------------------------------------------------------------------ //
// 2. BUILD                                                                  //
// ------------------------------------------------------------------------ //
// The spec carries no presentation - the campaign layer derives icon and
// colour from `faction` at draw time - so a scenario reads as rosters and
// positions and nothing else.
//
// The position is COPIED, not handed over: the spec tables in init.sqf are
// shared between scenarios and engagements, and an army holding its table's
// array by reference would rewrite the table the first time it marched.
private _army = [_name, +_position, nil, _faction] call STRAT_fnc_generateArmy;

// Which man the player takes when this army fights. Defaulted rather than
// required: the player's own faction flags its leader and everyone else flags
// nobody. Pass a slot to put him elsewhere in the roster, or 0 to leave a
// player-faction army with no body in it.
private _slot = _playerSlot;
if (_slot < 0) then {
	_slot = if (_faction == "player") then {1} else {0};
};

// The first man listed leads. Deployment reads `isLeader` to pick the group
// leader and to seat him in the front vehicle, so exactly one man carries it.
{
	[_army, _x, _forEachIndex == 0, (_forEachIndex + 1) == _slot] call STRAT_fnc_addMan;
} forEach _menClasses;

{
	[_army, _x] call STRAT_fnc_addVehicle;
} forEach _vehicleClasses;

activeArmies pushBack _army;

diag_log format [
	"TEST Harness: built %1 (%2, %3) - %4 men, %5 vehicle(s) at %6, player in slot %7.",
	_name,
	_army get "id",
	_faction,
	count _menClasses,
	count _vehicleClasses,
	_position,
	_slot
];

_army
