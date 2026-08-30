/*
	Function: STRAT_fnc_mapUnitTexture

	Description:
		Resolves an INDIVIDUAL entity's map icon: the stock per-unit artwork
		the engine's own map draws, which is a rounded silhouette with a
		pointed end rather than a NATO box. The counterpart of
		STRAT_fnc_mapIconTexture, and the reason there are two of them is that
		the map draws two different kinds of thing (section 11).

		  an INDIVIDUAL   a man, a vehicle. Stock unit artwork, from here.
		                  It is asymmetric, so drawIcon's rotation argument
		                  turns it into a facing tick - which is how the
		                  engine's own map shows heading, and the whole reason
		                  this silhouette is shaped the way it is.
		  an AGGREGATE    a group, an army, a location. NATO box symbology,
		                  from STRAT_fnc_mapIconTexture and CfgMarkers.

		That split is not decoration. A NATO box means "a body of men of this
		type", and putting one over a single rifleman says something false
		about what he is. It also reads upright and carries no heading, so
		rotating it to show facing would be rotating a symbol that is not built
		to turn. The stock unit icon means "one of these, pointing that way",
		which is exactly what a command entity is.

		Two config steps, because the engine indirects. CfgVehicles gives a
		NAME - "iconMan", "iconTankTracked" - and CfgVehicleIcons turns that
		name into a path. Neither step is a class lookup with a fallback chain
		we can lean on, so both are checked.

		Cached, on the same terms and for the same reason as
		STRAT_fnc_mapIconTexture: the command layer calls this once per entity
		per frame and CfgVehicles does not change mid-mission. It shares that
		function's cache rather than keeping its own, so the drill's icon probe
		seeds one table and reaches both resolvers. The keys cannot collide -
		a CfgMarkers class is "b_inf" and a CfgVehicles class is "B_Soldier_F",
		and nothing is named both.

		A class that resolves to nothing falls back to the caller's NATO
		marker rather than to a procedural colour. A box over a rifleman is
		wrong but legible; a blank square is a unit the player cannot identify,
		and armies are drawn rather than marked, so the failure has to stay
		readable.

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
