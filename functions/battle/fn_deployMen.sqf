/*
	Function: TACT_fnc_deployMen

	Description:
		Spawns an army's infantry roster and distributes them between its
		deployed vehicles, filling the front of the column first.

	Parameters:
		0: HASHMAP - army object

	Returns:
		GROUP - the created group.
*/

params [
	["_army", createHashMap, [createHashMap]]
];

// 1. Determine the Arma side from the "faction" attribute. The faction->side
// map is section 8's, and it lives in one place so garrison deployment and the
// test harness cannot drift from it.
private _faction = _army getOrDefault ["faction", "player"];
private _side = _faction call STRAT_fnc_factionSide;

// Create the unified group for this army
private _grp = createGroup [_side, true];

// 2. Gather vehicles and reverse the order to fill the front first
private _armyVehicles = _army getOrDefault ["vehicles", []];
private _rotationVehicles = [];

// Extract physical objects from the vehicle data array
{
    private _vehObj = _x get "obj";
    if (!isNull _vehObj && alive _vehObj) then {
        _rotationVehicles pushBack _vehObj;
    };
} forEach _armyVehicles;

// Reverse array to fill front assets first (spawned back-to-front)
reverse _rotationVehicles;

// 3. Extract the men array
private _menArray = _army getOrDefault ["men", []];
if (count _menArray == 0 || count _rotationVehicles == 0) exitWith { _grp };

private _leaderData = createHashMap;
private _regularInfantry = [];

// Isolate the leader from the regular troops
{
    if (_x getOrDefault ["isLeader", false]) then {
        _leaderData = _x;
    } else {
        _regularInfantry pushBack _x;
    };
} forEach _menArray;

private _physicalLeader = objNull;

// 4. Spawn and place the leader into the front vehicle
if (count _leaderData > 0) then {
    private _leadVehicle = _rotationVehicles select 0;
    
    // Spawn physical unit
    _physicalLeader = _grp createUnit [_leaderData get "className", [0,0,0], [], 0, "NONE"];
    _leaderData set ["obj", _physicalLeader]; // Update hashmap with physical model
    
    // Apply health and skill
    _physicalLeader setDamage (1 - (_leaderData getOrDefault ["health", 1]));
    _physicalLeader setSkill (_leaderData getOrDefault ["skill", 0.5]);
    
    // Move into first available seat of the lead vehicle
    _physicalLeader moveInAny _leadVehicle;
};

// 5. Rotate between vehicles to fill remaining infantry
private _vehicleIndex = 0;

{
    private _soldierData = _x;
    
    // Safe guard if all vehicles somehow fill up before array is exhausted
    if (count _rotationVehicles == 0) exitWith {};

    // Get the vehicle currently in rotation
    private _currentVeh = _rotationVehicles select _vehicleIndex;

    // Spawn the soldier
    private _unit = _grp createUnit [_soldierData get "className", [0,0,0], [], 0, "NONE"];
    _soldierData set ["obj", _unit]; // Update hashmap with physical model

    // Apply health and skill variables
    _unit setDamage (1 - (_soldierData getOrDefault ["health", 1]));
    _unit setSkill (_soldierData getOrDefault ["skill", 0.5]);

    // Assign to seat
    _unit moveInAny _currentVeh;

    // Check if the vehicle has filled up after mounting
    // (emptyPositions checks driver, gunner, commander, and cargo slots combined)
    if ((_currentVeh emptyPositions "Any") == 0) then {
        _rotationVehicles deleteAt _vehicleIndex; // Remove full vehicle from rotation
        
        // Re-evaluate index boundaries after pruning
        if (count _rotationVehicles > 0) then {
            _vehicleIndex = _vehicleIndex % (count _rotationVehicles);
        };
    } else {
        // Move tracker to the next vehicle in rotation smoothly via modulo
        _vehicleIndex = (_vehicleIndex + 1) % (count _rotationVehicles);
    };

} forEach _regularInfantry;

// 6. Set the group leader to the designated leader asset and return group
if (!isNull _physicalLeader) then {
    _grp selectLeader _physicalLeader;
};

_grp
