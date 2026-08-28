/**
 * STRAT_fnc_generateArmy
 *
 * Purpose: Creates a structured, data-driven "Army" HashMap object for the overworld strategic layer.
 * * Params:
 * 0: _name        - STRING: Unique identifier/name of the army.
 * 1: _startPos    - ARRAY:  Initial 3D or 2D position [X, Y, Z] on the map.
 * 2: _markerType  - STRING: The marker icon type (e.g., "b_inf" for BLUFOR Infantry).
 * 3: _markerColor - STRING: The marker color (e.g., "ColorBLUFOR").
 * 4: _speed       - NUMBER: The travel speed of the army in km/h (Defaults to 30 if not provided).
 *
 * Returns: 
 * HASHMAP: The complete army object container.
 */	

params [
    ["_name", "Unknown Army", [""]],
    ["_startPos", [0,0,0], [[]]],
    ["_markerType", "b_inf", [""]],
    ["_markerColor", "ColorBLUFOR", [""]],
    ["_speed", 30, [0]],
	["_faction", "player", [""]]
];

// 1. Create a unique, hidden 2D map marker for this specific army instance
private _markerName = format ["STRAT_Marker_%1_%2", _name, round(random 100000)];
private _marker = createMarker [_markerName, _startPos];
_marker setMarkerType _markerType;
_marker setMarkerColor _markerColor;
_marker setMarkerText _name;

// 2. Build the structured "Army" object using Arma's native HashMap
private _army = createHashMapFromArray [
    ["name", _name],
    ["location", _startPos],
    ["path", []],          // Holds an array of points/road nodes to traverse
    ["speed", _speed],      // Abstract travel speed used by the momentum accumulator loop
    ["marker", _marker],    // Reference to the visual map tracking icon
    ["isMoving", false],     // State tracker to manage pathfinding loop execution
	["faction", _faction],
	["men", []],
	["vehicles", []]
];

// Return the completed HashMap object
_army
