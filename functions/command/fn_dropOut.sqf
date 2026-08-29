/*
	Function: TACT_fnc_dropOut

	Description:
		Takes the player back out of the deployed group when a battle ends, and
		closes the map's command mode.

		Must run before TACT_fnc_concludeBattle deletes the group. A group with
		the player still in it is not empty, so deleteGroup would leave it
		behind holding a live player - and the next battle would drop him into
		a second group while the first still claimed him.

		The avatar is not deleted with the battle. TACT_fnc_syncBack deletes
		what the records point at, and the commander is in no record, so he
		stays standing where the fight left him. That is correct: the strategic
		layer moves armies, and the commander is not one.

		Routes are wiped rather than left on the corpses of the entities that
		held them. They live on the objects, so most go with sync-back anyway,
		but a survivor carrying a stale route into the next battle would start
		it already walking somewhere.

	Parameters:
		none

	Returns:
		BOOL - true if the player was commanding and has been withdrawn.
*/

if (isNil "TACT_commandActive" || {!TACT_commandActive}) exitWith { false };

// Closing the flag first stops the route executor and drops the map back to
// the campaign layer, so nothing is still issuing orders into a group that is
// about to be torn down.
TACT_commandActive = false;

if (!isNull player) then {
	private _group = group player;

	// Clear every route this group was carrying while its units still exist.
	{
		private _obj = _x get "obj";
		if (!isNull _obj) then {
			_obj setVariable ["TACT_route", nil];
			_obj setVariable ["TACT_routeIssued", nil];
		};
	} forEach (call TACT_fnc_commandEntities);

	// Back to a group of his own, on the side his faction spawns on, so the
	// avatar leaves the battle the way TEST_fnc_setupScenario left him.
	private _side = "player" call STRAT_fnc_factionSide;
	[player] joinSilent (createGroup [_side, true]);

	// The deployed group is not torn down here. TACT_fnc_concludeBattle owns
	// it and deletes it after sync-back has read the survivors off it; taking
	// it out from under that would cost the army its end position.
	if (!isNull _group) then {
		diag_log format ["TACT Command: left %1 with %2 unit(s) still in it.", _group, count (units _group)];
	};
};

TACT_commandSelection = [];
TACT_commandArmyId    = "";

// The squad bar was hidden for the map's command mode; the battle is over and
// the map is a campaign map again.
[false] call TACT_fnc_setCommandHud;

diag_log "TACT Command: player has been withdrawn from the deployed group.";

true
