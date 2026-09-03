/*
	Function: TEST_fnc_clearArmies

	Description:
		Empties the strategic map so a scenario or a spawned engagement starts
		from a known state. Deletes any entity an army record still points at,
		then clears `activeArmies` and the selection. Nothing has to be
		unmarked - an army is drawn from `activeArmies` every frame.

		Records normally hold `objNull` (sync-back nulls every `obj` on the way
		out of a battle), but a harness reset can land mid-battle, so anything
		still on the ground is removed here rather than left orphaned.

		REFUSES WHILE A BLOCK IS RESOLVING: STRAT_fnc_resolveTurn iterates
		`activeArmies` across sleeps, and clearing it underneath that loop would
		leave it walking freed records.

	Parameters:
		none

	Returns:
		BOOL - true if the map was cleared.
*/

if (!isNil "STRAT_resolutionRunning" && {STRAT_resolutionRunning}) exitWith {
	diag_log "TEST Harness: clear refused, a block is still resolving.";
	false
};

// A drill points at armies this function is about to delete, and one of their
// men is the body the player is looking through, so control comes back BEFORE
// the deletion pass.
//
// The reset path, not the normal one: a drill is normally closed by
// TEST_fnc_endDrill, which reads the survivors back into the record first.
if (!isNil "TEST_activeDrill" && {count TEST_activeDrill > 0}) then {
	call TACT_fnc_dropOut;
	TEST_activeDrill = createHashMap;
	diag_log "TEST Harness: a running drill was cleared off the map.";
};

private _cleared = 0;

{
	private _army = _x;

	{
		private _obj = _x getOrDefault ["obj", objNull];

		if (!isNull _obj) then {
			private _grp = group _obj;
			deleteVehicle _obj;

			// Vehicles report grpNull; a soldier's group is deleted once the
			// last man in it is gone.
			if (!isNull _grp && {count (units _grp) == 0}) then { deleteGroup _grp };
		};

		_x set ["obj", objNull];
	} forEach ((_army getOrDefault ["men", []]) + (_army getOrDefault ["vehicles", []]));

	_cleared = _cleared + 1;
} forEach activeArmies;

activeArmies = [];
STRAT_selectedArmy = nil;

// Nothing is left to fight, so nothing is left in flight either. The pair
// ledger is per-block and the engagement list is per-battle; both would
// otherwise carry ids that no longer name anything.
TACT_activeEngagements      = [];
TACT_resolvedPairsThisBlock = [];


// The boundary belongs to a battle that no longer exists.
[[0,0,0], false] call TACT_fnc_drawBoundary;

diag_log format ["TEST Harness: cleared %1 army(s) off the strategic map.", _cleared];

true
