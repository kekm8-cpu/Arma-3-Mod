/*
	Function: STRAT_fnc_addGarrisonVehicle

	Description:
		Appends a vehicle record to a location's garrison.

		As with STRAT_fnc_addGarrisonMan, this delegates to the army-roster
		builder so the garrison holds identical vehicle records — hitbox
		layout included — and needs no deployment path of its own.

	Parameters:
		0: HASHMAP - location record
		1: STRING  - vehicle class name

	Returns:
		BOOL - true on success.
*/

params [
	["_location", createHashMap, [createHashMap]],
	["_vehicleClassName", "", [""]]
];

private _garrison = _location getOrDefault ["garrison", createHashMap];
if (!("vehicles" in _garrison)) exitWith {
	diag_log format ["STRAT_Error: no garrison roster on location '%1'.", _location getOrDefault ["id", "<none>"]];
	false
};

[_garrison, _vehicleClassName] call STRAT_fnc_addVehicle
