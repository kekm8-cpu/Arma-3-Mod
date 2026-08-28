/*
	Function: TACT_fnc_deployVehicles

	Description:
		Spawns an army's vehicle roster onto the tactical grid along the given
		path, restoring each vehicle's stored damage and hitbox state.

	Parameters:
		0: HASHMAP - army object
		1: ARRAY   - road nodes to deploy along
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_path", [], [[]]]
];

private _vehiclesData = _army getOrDefault ["vehicles", []];

{
    private _vData = _x; // The custom vehicle HashMap object
    private _className = _vData getOrDefault ["className", ""];
    private _spawnNodeIndex = _forEachIndex;

    // Length Safety Guard: Prevent out-of-bounds deployment if the path is too short
    if (_spawnNodeIndex < (count _path - 1)) then {
        private _startNode = _path select _spawnNodeIndex;
        private _nextNode = _path select (_spawnNodeIndex + 1);
        
        private _startPos = getPos _startNode;
        private _nextPos = getPos _nextNode;

        // Compute precise spawning orientation vector pointing to the next node
        private _dirVector = _startPos vectorFromTo _nextPos;
        private _azimuth = (_dirVector select 0) atan2 (_dirVector select 1);

        // Instantiate the physical asset onto the tactical grid
        private _vehObj = createVehicle [_className, _startPos, [], 0, "CAN_COLLIDE"];
        _vehObj setDir _azimuth;
		_vData set ["obj", _vehObj];

        // Inject velocity matrix (30 km/h = 8.33 m/s) oriented along the path
        private _velocityVector = _dirVector vectorMultiply 8.33333;
        _vehObj setVelocity _velocityVector;

        // --- DEGRADED STATE RESTORATION (DAMAGE & HITBOXES) ---
        // 1. Restore component-level hitbox damage
        private _hitboxesMap = _vData getOrDefault ["hitboxes", createHashMap];
        {
            // _x = Hitpoint Name (String), _y = Damage State (Number 0-1)
            _vehObj setHitPointDamage [_x, _y];
        } forEach _hitboxesMap;

        // 2. Restore overall structural vehicle health
        private _overallHealth = _vData getOrDefault ["health", 1];
        private _overallDamage = 1 - _overallHealth; // Invert health coefficient to find damage
        _vehObj setDamage [_overallDamage, false]; // False bypasses default structural explosion effects during initial rendering

        // --- STRATEGIC ENGINE RUNTIME IDENTIFIER STAMPING ---
        _vehObj setVariable ["TACT_armyRef", _army];
        _vehObj setVariable ["TACT_vehicleIndex", _forEachIndex];
        _vehObj setVariable ["TACT_vehicleDataRef", _vData];
    };
} forEach _vehiclesData;
