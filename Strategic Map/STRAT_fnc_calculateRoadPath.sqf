params ["_startNode", "_endNode"];
    
private _openSet = [_startNode];
private _distances = createHashMap;
private _cameFrom = createHashMap;

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
		private _path = [_current];
		while {netId _current in _cameFrom} do {
			_current = _cameFrom get (netId _current);
			_path pushBack _current;
		};
		reverse _path;
		_openSet = []; // Break loop
		_path
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