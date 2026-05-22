params ["_army", "_pathPoints"];
if (count _pathPoints == 0) exitWith { _army set ["isMoving", false]; };

_army set ["isMoving", true];

// Dynamically pull properties from the passed army object
private _armySpeed = _army get "speed";
private _armyMarker = _army get "marker";
private _currentRoad = _army get "currentRoad";

// Speed Calculation based on the army's unique stats
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
	
	// Update this specific army's marker position on the UI map
	_armyMarker setMarkerPos _currentPos;
	
	uiSleep 0.5; 
};

_army set ["isMoving", false];