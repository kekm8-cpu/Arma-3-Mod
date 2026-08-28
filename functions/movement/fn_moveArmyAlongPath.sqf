/*
	Function: STRAT_fnc_moveArmyAlongPath

	Description:
		Walks an army along a road path, advancing its marker every 0.5s at
		the army's own speed. Sets "isMoving" for the duration and keeps
		"currentRoad" up to date. Must be spawned, not called.

	Parameters:
		0: HASHMAP - army object (see STRAT_fnc_createArmy)
		1: ARRAY   - road segments to traverse, in order
*/

params ["_army", "_pathPoints"];
if (count _pathPoints == 0) exitWith { _army set ["isMoving", false]; };

_army set ["isMoving", true];

private _armySpeed = _army get "speed";
private _armyMarker = _army get "marker";
private _currentRoad = _army get "currentRoad";

// Every 0.5 seconds, we calculate the meter budget for this specific army
private _metersPerStep = (_armySpeed / 3.6) * 0.5; 

private _waypointPositions = _pathPoints apply { getPosVisual _x };
private _currentPos = getPosVisual _currentRoad;

while {count _waypointPositions > 0} do {
	private _budgetThisTick = _metersPerStep;
	
	while {_budgetThisTick > 0 && {count _waypointPositions > 0}} do {
		private _nextTarget = _waypointPositions # 0;
		private _distanceToNext = _currentPos distance _nextTarget;
		
		if (_distanceToNext <= _budgetThisTick) then {
			// Snap to node, update object's current road segment location
			_currentPos = _nextTarget;
			_currentRoad = _pathPoints # 0;
			_army set ["currentRoad", _currentRoad]; 
			
			_budgetThisTick = _budgetThisTick - _distanceToNext;
			_waypointPositions deleteAt 0;
			_pathPoints deleteAt 0;
		} else {
			// Advance along the vector using remaining budget
			private _directionVec = _nextTarget vectorDiff _currentPos;
			_directionVec = vectorNormalized _directionVec;
			private _stepMove = _directionVec vectorMultiply _budgetThisTick;
			_currentPos = _currentPos vectorAdd _stepMove;
			
			_budgetThisTick = 0;
		};
	};
	
	_armyMarker setMarkerPos _currentPos;
	
	uiSleep 0.5; 
};

_army set ["isMoving", false];
