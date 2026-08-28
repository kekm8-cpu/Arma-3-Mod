/*
	Function: STRAT_fnc_createArmy

	Description:
		Builds an army object: snaps it to the nearest road, creates its map
		marker, and returns the hashmap the movement functions operate on.

	Parameters:
		0: STRING - unique id, also used to name the marker
		1: ARRAY  - world position to start from
		2: STRING - marker label shown on the map
		3: NUMBER - speed in km/h (default 30)
		4: STRING - marker type (default "b_inf")
		5: STRING - marker colour (default "ColorBLUFOR")

	Returns:
		HASHMAP - the army object, or an empty hashmap if no road was found.
*/

params [
	["_id", "", [""]],
	["_startPos", [0,0,0], [[]]],
	["_label", "", [""]],
	["_speed", 30, [0]],
	["_markerType", "b_inf", [""]],
	["_markerColor", "ColorBLUFOR", [""]]
];

private _startRoad = roadAt _startPos;
if (isNull _startRoad) then {
	private _near = _startPos nearRoads 500;
	if (count _near > 0) then { _startRoad = _near # 0; };
};

if (isNull _startRoad) exitWith {
	diag_log format ["[STRAT] createArmy: no road near %1 for army %2", _startPos, _id];
	createHashMap
};

private _markerName = createMarker [format ["STRAT_Army_Marker_%1", _id], getPosVisual _startRoad];
_markerName setMarkerType _markerType;
_markerName setMarkerColor _markerColor;
_markerName setMarkerText _label;

createHashMapFromArray [
	["id", _id],
	["marker", _markerName],
	["speed", _speed],
	["currentRoad", _startRoad],
	["isMoving", false]
]
