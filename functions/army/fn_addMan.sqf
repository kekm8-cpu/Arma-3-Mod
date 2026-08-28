/*
	Function: STRAT_fnc_addMan

	Description:
		Appends a soldier record to an army's roster. Leaders get a higher
		default skill.

	Parameters:
		0: HASHMAP - army object
		1: STRING  - unit class name
		2: BOOL    - true if this man leads the group (default false)

	Returns:
		BOOL - true on success.
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_unitClassName", "", [""]],
	["_isLeader", false, [true]]
];

// Safety check: Ensure the passed army HashMap is valid and has a "men" key
if (!(_army isEqualType createHashMap) || {!("men" in _army)}) exitWith {
    diag_log "STRAT_Error: Invalid army object passed to STRAT_fnc_addMan.";
};


private _defaultSkill = 0.5;
if (_isLeader) then {_defaultSkill = 0.65};

// 2. Build the structured, object-oriented custom Soldier HashMap
private _soldierObject = createHashMapFromArray [
    ["className", _unitClassName],
    ["health", 1.0],       // 1.0 = Fully healthy, matching engine's 1 - damage paradigm
    ["skill", _defaultSkill],
    ["isLeader", _isLeader],
	["obj", objNull]
];

// 3. Extract the army's structural "men" array pointer
private _menArray = _army get "men";

// 4. Push the new soldier object into the array handle natively by reference
_menArray pushBack _soldierObject;

// Return true to indicate successful initialization
true
