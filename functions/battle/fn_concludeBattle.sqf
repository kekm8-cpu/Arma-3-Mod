/*
	Function: TACT_fnc_concludeBattle

	Description:
		Closes a battle out and hands the survivors back to the strategic layer
		(lifecycle stages 9 to 11). Applies the classified outcome to each army's
		standing order, moves each army's strategic position to where its
		survivors ended up, syncs the battle back into data, deletes the entities
		and the boundary, and clears `inBattle`.

		Position is taken BEFORE sync-back, which deletes the entities that hold
		it, and off each army's `men` records rather than off its group, so a
		detachment the player split out still counts. An army whose record kept
		its pre-battle position would teleport back onto the field it just left
		and re-engage.

		What the outcome does to the order:
		  breakthrough - the order stands and the army marches on
		  held         - the order stands
		  disengaged   - the order stands; no ground changes hands
		  repulse      - the block is lost, the order is retired where it stands
		  destroyed    - the army leaves the map

		Marching back toward origin after a repulse is post-battle march work
		and is not done here.

	Parameters:
		0: HASHMAP - engagement record
		1: HASHMAP - outcome record from TACT_fnc_resolveVictory

	Returns:
		BOOL - true.
*/

params [
	["_engagement", createHashMap, [createHashMap]],
	["_outcome", createHashMap, [createHashMap]]
];

private _attacker = _engagement get "attacker";
private _defender = _engagement get "defender";
private _byArmy   = _outcome getOrDefault ["byArmy", createHashMap];

// Control returns to the campaign avatar before anything is torn down.
// TACT_fnc_syncBack is about to delete the entities, and one of them is the
// unit the player is currently looking through.
call TACT_fnc_dropOut;

private _sides = [
	[_attacker, _engagement get "attackerGroup"],
	[_defender, _engagement get "defenderGroup"]
];

private _casualtyReport = [];
private _armiesRemoved = [];

{
	_x params ["_army", "_group"];

	private _armyId = _army get "id";
	private _result = _byArmy getOrDefault [_armyId, "held"];

	// ------------------------------------------------------------------ //
	// 1. STRATEGIC POSITION, READ OFF THE SURVIVORS BEFORE THEY ARE GONE  //
	// ------------------------------------------------------------------ //
	// Off the ARMY RECORD, not off the group: a detachment is a different group
	// and the same army, so counting the group would leave its men out of the
	// centre of mass. Same rule as TACT_fnc_resolveVictory.
	//
	// Runs BEFORE sync-back, which is what makes it possible - sync-back nulls
	// every `obj` on its way through.
	private _living = [];
	{
		private _obj = _x getOrDefault ["obj", objNull];
		if (!isNull _obj && {alive _obj}) then { _living pushBack _obj };
	} forEach (_army getOrDefault ["men", []]);

	if (count _living > 0) then {
		private _sumX = 0;
		private _sumY = 0;
		{
			private _p = getPosATL _x;
			_sumX = _sumX + (_p select 0);
			_sumY = _sumY + (_p select 1);
		} forEach _living;

		private _endPos = [_sumX / (count _living), _sumY / (count _living), 0];
		_army set ["location", _endPos];
	};

	// ------------------------------------------------------------------ //
	// 2. SYNC-BACK AND ENTITY TEARDOWN                                    //
	// ------------------------------------------------------------------ //
	private _losses = [_army] call TACT_fnc_syncBack;
	_losses params ["_menLost", "_vehiclesLost"];

	if (!isNull _group) then { deleteGroup _group };

	_casualtyReport pushBack format [
		"%1: %2 dead, %3 vehicle(s) lost, %4 left",
		_army get "name",
		_menLost,
		_vehiclesLost,
		count (_army getOrDefault ["men", []])
	];

	// ------------------------------------------------------------------ //
	// 3. THE ORDER, PER OUTCOME                                           //
	// ------------------------------------------------------------------ //
	private _order = _army getOrDefault ["pendingOrder", createHashMap];

	if (_result == "repulse" && {count _order > 0}) then {
		// The block is lost. The route is abandoned where the army stands and
		// the order retires at the next planning phase.
		_army set ["path", []];
		_order set ["status", "complete"];
	};

	// ------------------------------------------------------------------ //
	// 4. BACK TO THE STRATEGIC MAP                                        //
	// ------------------------------------------------------------------ //
	_army set ["inBattle", false];

	// An army with no men left is off the map. Its record is kept out of
	// activeArmies rather than mutated during this pass.
	if (count (_army getOrDefault ["men", []]) == 0) then {
		_armiesRemoved pushBack _army;
	};
} forEach _sides;

// ------------------------------------------------------------------------ //
// DETACHMENTS                                                               //
// ------------------------------------------------------------------------ //
// The groups the player split off with "New Group" are not either army's
// deployed group, so the deleteGroup above does not reach them. They are
// deleteWhenEmpty, so the engine takes them on its own; this is the backstop,
// and the one place the list is emptied.
//
// AFTER sync-back, deliberately: deleteGroup on a group that still has men in
// it is refused, and until sync-back runs these groups still have men.
if (isNil "TACT_commandDetachments") then { TACT_commandDetachments = [] };

{
	if (!isNull _x) then { deleteGroup _x };
} forEach TACT_commandDetachments;

TACT_commandDetachments = [];

// Removal happens after the pass over the engagement's sides, never inside it,
// and is done by id: array subtraction would compare the army HashMaps by
// content and could drop a different army that happened to match.
if (count _armiesRemoved > 0) then {
	private _removedIds = _armiesRemoved apply {_x get "id"};

	{
		diag_log format ["TACT Battle: %1 has been removed from the map.", _x get "name"];
	} forEach _armiesRemoved;

	activeArmies = activeArmies select {!((_x get "id") in _removedIds)};
};

// The pair does not re-engage this block. Two armies left standing inside
// contact range of each other would otherwise fight again on the next tick.
TACT_resolvedPairsThisBlock pushBack [_attacker get "id", _defender get "id"];

// Clear the boundary drawing.
[[0,0,0], false] call TACT_fnc_drawBoundary;

private _summary = _outcome getOrDefault ["summary", "The battle has ended."];

// Handed to the turn loop's readout, which owns the hint while a block is
// resolving, and carried into the next planning phase.
TACT_lastBattleReport = format ["%1\n%2", _summary, _casualtyReport joinString "\n"];
systemChat _summary;
diag_log format ["TACT Battle: %1 | %2", _summary, _casualtyReport joinString " | "];

true
