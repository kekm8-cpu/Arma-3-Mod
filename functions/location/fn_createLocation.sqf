/*
	Function: STRAT_fnc_createLocation

	Description:
		Creates a strategic location record and registers it in STRAT_locations.

		Minimal per build plan 1.2: `id`, `type`, `position`, `owner`,
		`garrison`, `flagPos`. `opinion` and per-location benefits are phase 3.8
		and are absent rather than stubbed — an empty key invites code to read
		it before the mechanic exists.

		A garrison is a static roster, not an army: it carries `men` and
		`vehicles` in the record format an army uses, so sync-back and
		deployment stay one code path, but it has no `pendingOrder`, no `path`,
		no `speed`, and never appears in activeArmies.

		Ids are authored rather than minted — locations are few, fixed, and
		referenced by name from orders and from the test harness.

	Parameters:
		0: STRING - unique id, e.g. "tanoa_plantation_north"
		1: STRING - type: "port", "town", "plantation", "refinery", "airfield", "dock"
		2: ARRAY  - centre position [x, y, z]
		3: STRING - owning faction ("player", "drugLords", "csat", "nato")
		4: ARRAY  - flag position, the capture point (default: the centre)

	Returns:
		HASHMAP - the location record, or an empty HashMap if it was rejected.
*/

params [
	["_id", "", [""]],
	["_type", "town", [""]],
	["_position", [0,0,0], [[]]],
	["_owner", "drugLords", [""]],
	["_flagPos", [], [[]]]
];

if (isNil "STRAT_locations") then { STRAT_locations = createHashMap };

if (_id == "") exitWith {
	diag_log "STRAT Location: refusing to create a location with an empty id.";
	createHashMap
};

// Ids are the identity, the same way an army's id is. A duplicate is an
// authoring mistake and silently returning the existing record would hide it.
if (_id in STRAT_locations) exitWith {
	diag_log format ["STRAT Location: duplicate id '%1', not created.", _id];
	createHashMap
};

// Type selects the deployment plan for a set-piece battle, so an unknown one
// will surface later as a missing plan rather than here. Warn and continue —
// the list is expected to grow and this should not be a gate.
private _knownTypes = ["port", "town", "plantation", "refinery", "airfield", "dock"];
if (!(_type in _knownTypes)) then {
	diag_log format ["STRAT Location: '%1' has unrecognised type '%2'.", _id, _type];
};

// The capture point is centrally located by default. Set-piece battles anchor
// on `position` and contest `flagPos`, so the two are separable from the start
// even when they coincide.
if (count _flagPos == 0) then { _flagPos = +_position };

private _location = createHashMapFromArray [
	["id", _id],
	["type", _type],
	["position", _position],
	["owner", _owner],                  // Faction string
	["garrison", createHashMapFromArray [
		["men", []],
		["vehicles", []]
	]],
	["flagPos", _flagPos]
];

STRAT_locations set [_id, _location];

_location
