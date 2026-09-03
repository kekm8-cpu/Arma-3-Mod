/**
 * STRAT_fnc_generateArmy
 *
 * Purpose: Creates a structured, data-driven "Army" HashMap object for the overworld strategic layer.
 * * Params:
 * 0: _name        - STRING: Display name of the army.
 * 1: _startPos    - ARRAY:  Initial 3D or 2D position [X, Y, Z] on the map.
 * 2: _speed       - NUMBER: The travel speed of the army in km/h (Defaults to 30 if not provided).
 * 3: _faction     - STRING: Allegiance, and the source of truth for it ("player", "drugLords", "csat", "nato").
 *
 * Returns: 
 * HASHMAP: The complete army object container.
 *
 * The record carries no presentation at all: the campaign draw layer derives
 * icon and colour from `faction` at draw time and stores neither, which is
 * what makes "colour is never read back" structural.
 */	

params [
    ["_name", "Unknown Army", [""]],
    ["_startPos", [0,0,0], [[]]],
    ["_speed", 30, [0]],
	["_faction", "player", [""]]
];

// 1. Mint a unique id. Identity is compared on this, never with isEqualTo,
// which content-compares HashMaps and would produce false positives between
// two armies holding the same roster.
if (isNil "STRAT_nextArmyId") then { STRAT_nextArmyId = 0 };
STRAT_nextArmyId = STRAT_nextArmyId + 1;
private _id = format ["ARMY_%1", STRAT_nextArmyId];

// 2. Build the structured "Army" object using Arma's native HashMap
private _army = createHashMapFromArray [
    ["id", _id],                    // Unique. Identity comparison uses this
    ["name", _name],
    ["location", _startPos],        // Authoritative position on the strategic map
    ["path", []],                   // Road nodes left to traverse this block
    ["speed", _speed],              // km/h, resolves progress within a block
    ["pendingOrder", createHashMap],// Order committed in planning; empty means none
    ["inBattle", false],            // Suppresses strategic resolution
	["faction", _faction],
	["men", []],
	["vehicles", []],
	["prisoners", []]
];

// Return the completed HashMap object
_army
