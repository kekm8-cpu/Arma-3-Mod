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
 * 5: _faction     - STRING: Allegiance, and the source of truth for it ("player", "drugLords", "csat", "nato").
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

// 1. Mint a unique id. Identity is compared on this, never with isEqualTo,
// which content-compares HashMaps and produces false positives between two
// armies that happen to hold the same roster.
if (isNil "STRAT_nextArmyId") then { STRAT_nextArmyId = 0 };
STRAT_nextArmyId = STRAT_nextArmyId + 1;
private _id = format ["ARMY_%1", STRAT_nextArmyId];

// 2. Create a unique, hidden 2D map marker for this specific army instance
private _markerName = format ["STRAT_Marker_%1", _id];
private _marker = createMarker [_markerName, _startPos];
_marker setMarkerType _markerType;
_marker setMarkerColor _markerColor;
_marker setMarkerText _name;

// 3. Build the structured "Army" object using Arma's native HashMap
private _army = createHashMapFromArray [
    ["id", _id],                    // Unique. Identity comparison uses this
    ["name", _name],
    ["location", _startPos],        // Authoritative position on the strategic map
    ["path", []],                   // Road nodes left to traverse this block
    ["speed", _speed],              // km/h, resolves progress within a block
    ["marker", _marker],            // Reference to the visual map tracking icon
    ["pendingOrder", createHashMap],// Order committed in planning; empty means none
    ["inBattle", false],            // Suppresses strategic resolution
	["faction", _faction],
	["men", []],
	["vehicles", []],
	["prisoners", []]
];

// Return the completed HashMap object
_army
