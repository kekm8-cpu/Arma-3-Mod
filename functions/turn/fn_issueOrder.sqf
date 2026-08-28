/*
	Function: STRAT_fnc_issueOrder

	Description:
		Writes a movement order to an army's "pendingOrder" (section 9, stage
		1). Nothing moves here: the order is queued and only takes effect when
		the block is committed.

		The destination lives on the order, not on the army, because battle
		deployment reads it back to compute facing. The order therefore
		survives commit and resolution and is only retired once the army
		arrives.

	Parameters:
		0: HASHMAP - army record
		1: ARRAY   - destination world position

	Returns:
		BOOL - true if the order was accepted.
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_destination", [0,0,0], [[]]]
];

if (count _army == 0) exitWith { false };

if (STRAT_turnPhase != "planning") exitWith {
	hint "Orders stand for the full block. Wait for the next planning phase.";
	false
};

if (_army getOrDefault ["inBattle", false]) exitWith {
	hint format ["%1 is committed to a battle and cannot be redirected.", _army get "name"];
	false
};

private _route = [_army get "location", _destination] call STRAT_fnc_calculateRoadPath;

if (count _route == 0) exitWith {
	hint "Invalid movement command. Target area lacks accessible road connectivity.";
	false
};

// The order carries the full planned route; the army's "path" holds only what
// is left to walk, and is filled from here at commit.
private _order = createHashMapFromArray [
	["type", "move"],
	["destination", _destination],
	["path", _route],
	["issuedBlock", STRAT_blockIndex],
	["status", "pending"]
];

_army set ["pendingOrder", _order];

// Projection, shown before commit rather than discovered after it.
private _projection = [_army, _route] call STRAT_fnc_projectArrival;
_projection params ["_distance", "_travelHours", "_blocksNeeded"];

hint format [
	"%1: march ordered.\nRoute %2 km, %3 h of block time (%4 %5).\n\nPress SPACE to commit the block.",
	_army get "name",
	(_distance / 1000) toFixed 1,
	_travelHours toFixed 1,
	_blocksNeeded,
	if (_blocksNeeded == 1) then {"block"} else {"blocks"}
];

true
