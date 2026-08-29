/*
	Function: STRAT_fnc_addGarrisonMan

	Description:
		Appends a soldier record to a location's garrison.

		The garrison roster is the army roster format, so this delegates to
		STRAT_fnc_addMan rather than building a second soldier record — one
		record shape is what keeps deployment and sync-back on one code path.

	Parameters:
		0: HASHMAP - location record
		1: STRING  - unit class name
		2: BOOL    - true if this man leads the garrison (default false)

	Returns:
		BOOL - true on success.
*/

params [
	["_location", createHashMap, [createHashMap]],
	["_unitClassName", "", [""]],
	["_isLeader", false, [true]]
];

private _garrison = _location getOrDefault ["garrison", createHashMap];
if (!("men" in _garrison)) exitWith {
	diag_log format ["STRAT_Error: no garrison roster on location '%1'.", _location getOrDefault ["id", "<none>"]];
	false
};

[_garrison, _unitClassName, _isLeader] call STRAT_fnc_addMan
