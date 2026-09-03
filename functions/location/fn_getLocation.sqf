/*
	Function: STRAT_fnc_getLocation

	Description:
		Looks up a location record by id, keeping the shape of the registry in
		one place so callers reference locations by id rather than holding a
		record.

	Parameters:
		0: STRING - location id

	Returns:
		HASHMAP - the location record, or an empty HashMap if there is no
		such location.
*/

params [
	["_id", "", [""]]
];

if (isNil "STRAT_locations") exitWith {
	diag_log "STRAT Location: STRAT_locations is not initialised.";
	createHashMap
};

if (!(_id in STRAT_locations)) exitWith {
	diag_log format ["STRAT Location: no location with id '%1'.", _id];
	createHashMap
};

STRAT_locations get _id
