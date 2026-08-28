/*
	Function: STRAT_fnc_moveArmyAlongPath

	Description:
		Marches an army along the route stored in its "path" key, advancing its
		marker every tick at the army's own speed. Spawns its own loop, so this
		can be called directly.

	Parameters:
		0: HASHMAP - army object (see STRAT_fnc_generateArmy)
*/

params ["_army"];

if (isNil "_army" || {!(_army isEqualType createHashMap)} || {_army get "isMoving"}) exitWith {};

private _path = {_army get "path"};
if (count call _path == 0) exitWith { hint "No route found to march along."; };

private _marker = _army get "marker";
private _speedKmh = _army get "speed"; 

private _tickDuration = 0.5; // Tick rate
// Budget = Meters allowed to travel per individual loop tick
private _stepDistanceBudget = ((_speedKmh * 1000) / 3600) * _tickDuration; // (~4.16 meters at 30km/h)

[_army, _path, _marker, _stepDistanceBudget, _tickDuration] spawn {
    params ["_army", "_path", "_marker", "_stepDistanceBudget", "_tickDuration"];
    
    //hint format ["%1 has broken camp and begun its march.", _army get "name"];
	_army set ["isMoving", true];
	
    
    // Track our location vector progressively
    private _currentVisualPos = _army get "location";
    private _distanceAccumulator = 0;
    while {count call _path > 0} do {
		
		private _nextRoadNode = call _path select 0;
        if (isNull _nextRoadNode) exitWith {};

        private _nodePos = getPosVisual _nextRoadNode;
        private _distanceToNextNode = _currentVisualPos distance _nodePos;

        // Add the distance of this map link section to our target progress tracker
        _distanceAccumulator = _distanceAccumulator + _distanceToNextNode;

        // CONSUME NODE CHAIN ACCORDING TO BUDGET
        // If the total distance to clear upcoming nodes fits inside our tick travel capacity...
        if (_distanceAccumulator <= _stepDistanceBudget) then {
            // Instantly consume the node, jump up to it, and subtract its distance from our budget
            _currentVisualPos = _nodePos;
            call _path deleteAt 0;
            _stepDistanceBudget = _stepDistanceBudget - _distanceToNextNode;
            _distanceAccumulator = 0;
        } else {
            // BUDGET EXHAUSTED: The next node is too far for this tick timeline frame.
            // Linearly interpolate (LERP) our position down the road link vector
            private _travelVector = _nodePos vectorDiff _currentVisualPos;
            private _travelDirection = vectorNormalized _travelVector;
            
            // Advance position precisely by our remaining step budget allowance
            _currentVisualPos = _currentVisualPos vectorAdd (_travelDirection vectorMultiply _stepDistanceBudget);
            
            // Clear the budget for this tick to break out to the next simulation frame
            _stepDistanceBudget = 0;
        };

        // Sync visual overworld anchors with our calculated progression vectors
        _marker setMarkerPos _currentVisualPos;
        _army set ["location", _currentVisualPos];

        // If this tick's travel budget is spent, sleep until the next turn timeline window
        if (_stepDistanceBudget <= 0) then {
            sleep _tickDuration;
            // Replenish full step budget metrics for the upcoming frame turn loop
            _stepDistanceBudget = (((_army get "speed") * 1000) / 3600) * _tickDuration;
            _distanceAccumulator = 0;
        };
    };

    //hint format ["%1 has arrived at its strategic destination.", _army get "name"];
	_army set ["isMoving", false];
};
