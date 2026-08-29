/*
	Function: TACT_fnc_concludeBattle

	Description:
		Closes a battle out and hands the survivors back to the strategic layer
		(section 9, stages 9 to 11). Applies the classified outcome to each
		army's standing order, moves each army's strategic position to where its
		survivors actually ended up, syncs the battle back into data, deletes
		the entities and the boundary, and clears `inBattle`.

		Position is taken before sync-back, because sync-back deletes the
		entities that hold it. An army whose record still claimed its pre-battle
		position would teleport back onto the field it just left and re-engage.

		What the outcome does to the order:
		  breakthrough - the order stands and the army marches on
		  held         - the order stands
		  disengaged   - the order stands; no ground changes hands
		  repulse      - the block is lost, the order is retired where it stands
		  destroyed    - the army leaves the map

		Marching back toward origin after a repulse, and spending the block time
		a battle leaves over, are block-time accounting and are not done here.

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

// The commander comes out before anything is torn down. A group with the
// player still in it is not empty, so the deleteGroup below would leave it
// standing and holding him.
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
	private _living = [_group] call TACT_fnc_combatants;

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
