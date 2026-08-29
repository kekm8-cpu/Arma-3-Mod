/*
	Function: STRAT_fnc_addMan

	Description:
		Appends a soldier record to an army's roster. Leaders get a higher
		default skill.

		One man in an army may be flagged `isPlayer`. He is an ordinary soldier
		in every respect - he is spawned by deployment like the rest, he is
		counted in the army's strength, he can be killed, and sync-back writes
		his condition back into this record - and the flag only says which body
		the player looks through once a battle has deployed. See
		TACT_fnc_dropIn.

		That is what keeps the battle layer from needing to know about the
		player at all. There is no commander standing outside the roster to
		exclude from casualty counts and centre-of-mass sums; there is a
		soldier, and one of the soldiers happens to be you.

	Parameters:
		0: HASHMAP - army object
		1: STRING  - unit class name
		2: BOOL    - true if this man leads the group (default false)
		3: BOOL    - true if the player takes this man's body in battle
		             (default false)

	Returns:
		BOOL - true on success.
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_unitClassName", "", [""]],
	["_isLeader", false, [true]],
	["_isPlayer", false, [true]]
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
	["isPlayer", _isPlayer],  // Which body the player takes when this army fights
	["obj", objNull],
	// Fatigue lives on the soldier, not the army, so detachments can merge and
	// split without inheriting each other's condition (section 6). Nothing
	// accumulates into these yet - that is build plan 2.6 - but
	// STRAT_fnc_armyFatigue already derives an army-level value from them.
	["exertion", 0],        // Hours of foot movement carried, reset by sleep
	["hoursSinceSleep", 0]  // Unread until the 24h cycle lands (3.10)
];

// 3. Extract the army's structural "men" array pointer
private _menArray = _army get "men";

// 4. Push the new soldier object into the array handle natively by reference
_menArray pushBack _soldierObject;

// Return true to indicate successful initialization
true
