/*
	Function: STRAT_fnc_moveArmyAlongPath

	Description:
		Advances one army along its remaining "path" by a bounded slice of
		block time, then returns. This is a single resolution pass, not a loop:
		it does not sleep, does not spawn, and does not run to completion. The
		turn loop calls it once per tick for every army so that they advance
		concurrently.

		The distance budget maths is the same as the old realtime version - a
		per-slice metre budget consumed node by node, with a linear
		interpolation along the final partial segment.

	Parameters:
		0: HASHMAP - army record
		1: NUMBER  - slice of block time to resolve, in block seconds

	Returns:
		NUMBER - block seconds left unspent, greater than zero only when the
		         army finished its route inside this slice.
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_blockSeconds", 0, [0]]
];

if (count _army == 0 || {_blockSeconds <= 0}) exitWith { 0 };

private _path = _army get "path";
if (isNil "_path" || {count _path == 0}) exitWith { _blockSeconds };

private _speedKmh = _army get "speed";
if (isNil "_speedKmh" || {_speedKmh <= 0}) exitWith { _blockSeconds };

private _metresPerSecond = (_speedKmh * 1000) / 3600;

// Metres this army may cover in the slice of block time it was handed.
private _budget = _metresPerSecond * _blockSeconds;

private _currentPos = _army get "location";

while {_budget > 0 && {count _path > 0}} do {
	private _nextNode = _path select 0;

	// A deleted or unresolvable road object is dropped rather than allowed to
	// stall the march.
	if (isNull _nextNode) then {
		_path deleteAt 0;
	} else {
		private _nodePos = getPosVisual _nextNode;
		private _distanceToNode = _currentPos distance2D _nodePos;

		if (_distanceToNode <= _budget) then {
			// The node is inside the budget: step onto it and carry the rest.
			_currentPos = _nodePos;
			_budget = _budget - _distanceToNode;
			_path deleteAt 0;
		} else {
			// Budget exhausted mid-segment: interpolate along it and stop.
			private _direction = vectorNormalized (_nodePos vectorDiff _currentPos);
			_currentPos = _currentPos vectorAdd (_direction vectorMultiply _budget);
			_budget = 0;
		};
	};
};

// The record owns the position; the marker is a view of it.
_army set ["location", _currentPos];
(_army get "marker") setMarkerPos _currentPos;

// Unspent budget only survives when the route ran out early.
if (count _path > 0) then { 0 } else { _budget / _metresPerSecond }
