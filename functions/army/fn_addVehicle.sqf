/*
	Function: STRAT_fnc_addVehicle

	Description:
		Appends a vehicle record to an army's roster, reading its hitpoint
		layout straight from CfgVehicles without spawning anything.

	Parameters:
		0: HASHMAP - army object
		1: STRING  - vehicle class name

	Returns:
		BOOL - true on success, false if the army or class name was invalid.
*/

params [["_army", createHashMap, [createHashMap]], ["_vehicleClassName", "", [""]]];

// Safety check: Ensure the army object is valid and the class name exists in config
if (_army isEqualTo createHashMap || {!isClass (configFile >> "CfgVehicles" >> _vehicleClassName)}) exitWith { 
    diag_log format ["STRAT_fnc_addVehicle Error: Invalid army or class name '%1'", _vehicleClassName];
    false
};

// 1. Fetch Structural Hitboxes dynamically from CfgVehicles WITHOUT spawning anything
private _hitboxNames = [];
private _hitboxDamageStates = [];

private _hitpointsConfigPath = configFile >> "CfgVehicles" >> _vehicleClassName >> "HitPoints";
if (isClass _hitpointsConfigPath) then {	
	// Collect all sub-classes inside the vehicle's HitPoints config tree
	private _hitpointClasses = "true" configClasses _hitpointsConfigPath;
    {
        // The name of the config class corresponds to the internal hitbox name (e.g., "HitEngine", "HitLFWheel")
        _hitboxNames pushBack (configName _x);
        _hitboxDamageStates pushBack 0; // Initialize at 0 damage (immaculate condition)
    } forEach _hitpointClasses;
};

// 3. Format the structured Custom Vehicle Object
private _customVehicleObject = createHashMapFromArray [
    ["className", _vehicleClassName],
    ["generalDamage", 0], 
    // We use apply to cleanly map each hitbox string to its corresponding 0 damage value index
    ["hitboxes", createHashMapFromArray (_hitboxNames apply { [_x, 0] })],
	["obj", objNull]
];

// 4. Inject the newly constructed vehicle directly into the army's "vehicles" array key
private _armyVehicles = _army getOrDefault ["vehicles", []];
_armyVehicles pushBack _customVehicleObject;
_army set ["vehicles", _armyVehicles];

true
