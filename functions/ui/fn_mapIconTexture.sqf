/*
	Function: STRAT_fnc_mapIconTexture

	Description:
		Resolves a CfgMarkers class to the texture path the engine would draw
		for a marker of that class, so a drawn icon and an authoring marker are
		the same artwork rather than two icon sets that drifted apart (section
		11).

		Cached. Both list builders call this once per icon per frame and
		CfgMarkers does not change mid-mission.

		A class that resolves to nothing must not take the map down with it -
		armies are drawn now, so a thrown error here is an empty strategic map
		- so the fallback is a procedural colour, which is the one texture that
		cannot fail to resolve.

	Parameters:
		0: STRING - CfgMarkers class name, e.g. "b_inf"

	Returns:
		STRING - texture path.
*/

params [
	["_markerClass", "", [""]]
];

if (isNil "STRAT_drawTextureCache") then { STRAT_drawTextureCache = createHashMap };

if (_markerClass in STRAT_drawTextureCache) exitWith {
	STRAT_drawTextureCache get _markerClass
};

private _path = getText (configFile >> "CfgMarkers" >> _markerClass >> "icon");

if (_path == "") then {
	diag_log format ["STRAT Draw: CfgMarkers >> %1 >> icon is empty, drawing a plain square.", _markerClass];
	_path = "#(argb,8,8,3)color(1,1,1,1)";
};

STRAT_drawTextureCache set [_markerClass, _path];

_path
