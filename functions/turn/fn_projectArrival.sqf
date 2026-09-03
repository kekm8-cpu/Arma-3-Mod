/*
	Function: STRAT_fnc_projectArrival

	Description:
		Projects how long a route takes an army to walk, in block time. Called
		when the order is issued, not after resolution: anything the player is
		penalised for has to be visible at planning time.

		Fatigue on arrival and route exposure belong in this projection too and
		are deliberately absent rather than guessed at.

	Parameters:
		0: HASHMAP - army record
		1: ARRAY   - route of road segments to walk (defaults to the army's
		             remaining "path")

	Returns:
		ARRAY - [_distanceMetres, _travelHours, _blocksNeeded]
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_route", [], [[]]]
];

// No explicit route given: project the walk the army has left to make.
if (count _route == 0) then {
	_route = _army getOrDefault ["path", []];
};

// Walk the route from the army's current position, summing segment lengths.
private _distance = 0;
private _cursor = _army get "location";

{
	if (!isNull _x) then {
		private _nodePos = getPosVisual _x;
		_distance = _distance + (_cursor distance2D _nodePos);
		_cursor = _nodePos;
	};
} forEach _route;

private _speedKmh = _army get "speed";
if (isNil "_speedKmh" || {_speedKmh <= 0}) then { _speedKmh = 1 };

private _travelHours = (_distance / 1000) / _speedKmh;
private _blocksNeeded = ceil (_travelHours / STRAT_blockLengthHours);

[_distance, _travelHours, _blocksNeeded]
