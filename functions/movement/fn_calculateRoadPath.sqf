/*
	Function: STRAT_fnc_calculateRoadPath

	Description:
		Dijkstra search across connected road segments. Accepts either a road
		object or a world position for each endpoint.

	Parameters:
		0: OBJECT or ARRAY - start road segment, or position to snap from
		1: OBJECT or ARRAY - end road segment, or position to snap to

	Returns:
		ARRAY of road segments from start to end. Empty if no road node could
		be resolved at either end.
*/

params ["_startInput", "_endInput"];

// ========================================================================= //
// INPUT RESOLUTION LAYER                                                    //
// ========================================================================= //
// Detect if input is a 3D coordinate array [X,Y,Z] or a live Road Object.
// If it's an array, look for the closest road asset within 150m.

private _startNode = if (_startInput isEqualType []) then {
    private _roads = _startInput nearRoads 150;
    
	if (count _roads > 0) then {
		private _nearest = _roads select 0;
		private _dist = (_roads select 0) distance2D _startInput;
		{
			if (_x distance2D _startInput < _dist) then {
				_dist = _x distance2D _startInput;
				_nearest = _x;
			}
		} forEach _roads;
		_nearest;
	} else { objNull };
} else {
    _startInput
};

private _endNode = if (_endInput isEqualType []) then {
    private _roads = _endInput nearRoads 150;
    if (count _roads > 0) then { _roads select 0 } else { objNull };
} else {
    _endInput
};

// Safety Fallback: Exit cleanly if no valid road nodes could be mapped
if (isNull _startNode || isNull _endNode) exitWith {
    diag_log "STRAT Pathfinding Error: Start or End point is too far from a valid road node.";
    [] // Return empty path array safely
};

// ========================================================================= //
// DIJKSTRA CORE LOGIC                                                       //
// ========================================================================= //
	
private _openSet = [_startNode];
private _distances = createHashMap;
private _cameFrom = createHashMap;
private _path = []; // Empty until a route is reconstructed, so an unreachable target returns [] cleanly

_distances set [netId _startNode, 0];

while {count _openSet > 0} do {
	// Find node in open set with the shortest recorded distance
	private _current = _openSet # 0;
	private _minDist = _distances getOrDefault [netId _current, 999999];
	
	{
		private _d = _distances getOrDefault [netId _x, 999999];
		if (_d < _minDist) then {
			_current = _x;
			_minDist = _d;
		};
	} forEach _openSet;
	
	// Target reached! Reconstruct the path array
	if (_current == _endNode) exitWith {
		_path = [_current];
		while {netId _current in _cameFrom} do {
			_current = _cameFrom get (netId _current);
			_path pushBack _current;
		};
		reverse _path;
		_openSet = []; // Break loop
	};
	
	_openSet = _openSet - [_current];
	private _currentPos = getPosVisual _current;
	
	// Evaluate connected road segments
	{
		private _neighbor = _x;
		private _neighborId = netId _neighbor;
		private _tentativeGScore = (_distances getOrDefault [netId _current, 0]) + (_currentPos distance (getPosVisual _neighbor));
		
		if (_tentativeGScore < (_distances getOrDefault [_neighborId, 999999])) then {
			_cameFrom set [_neighborId, _current];
			_distances set [_neighborId, _tentativeGScore];
			if !(_neighbor in _openSet) then { _openSet pushBack _neighbor; };
		};
	} forEach (roadsConnectedTo _current);
};

// ========================================================================= //
// JINK TURN CORRECTION GATING (USER SPECIFIED GEOMETRY)                     //
// ========================================================================= //
// Check if we have an active path containing at least two sequential road segments
if (count _path >= 2) then {
	private _p1Pos = getPos (_path select 0); // Point 1: Closest segment (Vertex)
    private _p2Pos = getPos (_path select 1); // Point 2: Next segment in path
    
    // Form vectors pointing outward from the vertex (Point 1)
    private _v1 = _startInput vectorDiff _p1Pos; // Vector from Point 1 to Army
    private _v2 = _p2Pos vectorDiff _p1Pos;    // Vector from Point 1 to Point 2
	
    // Extract 2D magnitudes to ensure safe division (bypassing Z-height coordinate discrepancies)
    private _mag1 = sqrt ((_v1 select 0)^2 + (_v1 select 1)^2);
    private _mag2 = sqrt ((_v2 select 0)^2 + (_v2 select 1)^2);
    
    if (_mag1 > 0 && _mag2 > 0) then {
		// Calculate the scalar dot product of the 2D vectors
        private _dotProduct = (_v1 select 0) * (_v2 select 0) + (_v1 select 1) * (_v2 select 1);
        
        // Calculate the cosine of the angle: cos(theta) = (v1 . v2) / (|v1| * |v2|)
        private _cosTheta = _dotProduct / (_mag1 * _mag2);
        
        // Clamp value to safe mathematical boundaries to avoid acos NaN errors
        _cosTheta = (-1) max (_cosTheta min 1);
        
        // Retrieve the absolute angle in degrees using inverse cosine
        private _angle = acos _cosTheta;
		
        // If the angle at vertex P1 is less than 90 degrees, it triggers a jink turn deletion
        if (_angle < 90) then {
			_path deleteAt 0;
        };
    };
};


//Draws path for trouble shooting path logic
/*private _loc = nil;
{
	_loc = getPos _x;
	createMarker [str _x, _loc];
	str _x setMarkerType "mil_dot";
} forEach _path;*/


_path;
