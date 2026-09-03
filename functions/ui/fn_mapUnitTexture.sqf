/*
	Function: STRAT_fnc_mapUnitTexture

	Description:
		Resolves an INDIVIDUAL entity's map icon: the stock per-unit artwork the
		engine's own map draws. The counterpart of STRAT_fnc_mapIconTexture, and
		there are two because the map draws two kinds of thing (manifest section
		11) - an individual takes this asymmetric silhouette, which drawIcon's
		rotation argument turns into a facing tick; an aggregate takes NATO box
		symbology from CfgMarkers.

		TWO CONFIG STEPS, because the engine indirects: CfgVehicles gives a NAME
		("iconMan", "iconTankTracked") and CfgVehicleIcons turns that name into
		a path. Neither has a fallback chain to lean on, so both are checked.

		Shares STRAT_fnc_mapIconTexture's cache rather than keeping its own, so
		the drill's icon probe seeds one table and reaches both resolvers. The
		keys cannot collide - a CfgMarkers class is "b_inf" and a CfgVehicles
		class is "B_Soldier_F".

		A class that resolves to nothing falls back to the caller's NATO marker
		rather than a procedural colour: a wrong symbol is legible, and a blank
		square is a unit the player cannot identify.

	Parameters:
		0: STRING - CfgVehicles class name, e.g. "B_Soldier_F"
		1: STRING - CfgMarkers class to fall back to (default "b_inf")

	Returns:
		STRING - texture path.
*/

params [
	["_vehicleClass", "", [""]],
	["_fallbackMarker", "b_inf", [""]]
];

if (isNil "STRAT_drawTextureCache") then { STRAT_drawTextureCache = createHashMap };

if (_vehicleClass in STRAT_drawTextureCache) exitWith {
	STRAT_drawTextureCache get _vehicleClass
};

if (_vehicleClass == "") exitWith {
	[_fallbackMarker] call STRAT_fnc_mapIconTexture
};

// Step one: the icon's NAME, not its path.
private _iconName = getText (configFile >> "CfgVehicles" >> _vehicleClass >> "icon");

// Step two: the name into a path. Cached under the VEHICLE class and not the
// icon name, so a hit costs one lookup rather than one and a half.
private _path = "";

if (_iconName != "") then {
	_path = getText (configFile >> "CfgVehicleIcons" >> _iconName);
};

if (_path == "") then {
	diag_log format [
		"STRAT Draw: %1 has no usable CfgVehicles icon (name '%2'), falling back to %3.",
		_vehicleClass,
		_iconName,
		_fallbackMarker
	];

	_path = [_fallbackMarker] call STRAT_fnc_mapIconTexture;
};

STRAT_drawTextureCache set [_vehicleClass, _path];

_path
