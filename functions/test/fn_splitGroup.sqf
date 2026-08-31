/*
	Function: TEST_fnc_splitGroup

	Description:
		Detaches part of the player's group into a group of its own and walks
		it clear of him. The harness's answer to a simple problem: collapsed
		groups are now selectable, and until this existed there was nothing on
		the field to select.

		A drill deploys ONE army, and an army deploys as ONE group, which the
		player then takes a body in. So a drill draws his own men individually
		and nothing else - no second group of his, no ally - and the whole of
		the group layer, the icon, the click radius, the ring and the art
		scale, has no case on screen to be looked at. A battle is no better: it
		puts a second group on the map, but that one is hostile and the command
		layer draws nothing hostile at all.

		THE DETACHED GROUP IS THE CASE THE COMMAND LAYER WAS WRITTEN FOR, which
		is the other reason this and not a second army. TACT_fnc_playerGroups
		resolves membership by SIDE rather than by the STRAT_faction stamp
		precisely because a group the player splits off is created by the
		engine and carries no stamp; the colour it draws in comes from the
		group it came out of, resolved before the draw sees it. Nothing here
		stamps the new group, deliberately - a stamp would walk the map's
		hardest case straight past the code that exists for it.

		How many: half the men he is not, rounded, and never fewer than one nor
		more than there are. A four-man fireteam with the player in it leaves
		two men detached, one man with him, and one of each kind of icon on the
		map - which is exactly what looking at a group icon against a unit icon
		needs.

		They walk TEST_splitStandoffMetres clear before stopping. A group icon
		drawn over a leader standing among the men he just left is an icon on
		top of three others, which is the one arrangement in which neither the
		group nor the units can be looked at. The order is a group `move` and
		not a doMove per man, because that is what a group with no player in it
		takes natively - the same fact group waypoints will be built on.

		A DRILL ONLY, and the guard is not politeness. TACT_fnc_resolveVictory
		counts an army's survivors as the `units` of the group deployment made
		for it, so men split into a group of their own during a real battle
		leave that count and the army reads as annihilated while they are still
		standing. Answering that is group-level command's job - a battle whose
		sides are groups rather than one group each - and until it is answered
		this belongs where there is no victory condition to corrupt.

		Two smaller things it does not fix, both bounded and both here so they
		are not rediscovered. TEST_fnc_endDrill averages the surviving `units`
		of the deployed group to decide where the army ended up, so a
		detachment does not vote on that position; the error is the standoff
		distance on an island-sized map. And sync-back deletes by roster rather
		than by group, so the detached men are torn down with everyone else -
		it is the survivor COUNT that is group-shaped, not the teardown.

		Harness only, and the drill's own rather than the command layer's. When
		the player can split his group for real it will be an order on the
		command map and not a debug key.

	Parameters:
		0: NUMBER - how many men to detach. 0 (default) takes half.

	Returns:
		GROUP - the detached group, or grpNull if nothing could be detached.
*/

params [
	["_count", 0, [0]]
];

if (isNil "TEST_activeDrill" || {count TEST_activeDrill == 0}) exitWith {
	systemChat "TEST: split is a drill tool - survivor counting is group-shaped in a battle.";
	grpNull
};

if (isNull player) exitWith {
	systemChat "TEST: no player to split a group from.";
	grpNull
};

private _group = group player;

// The men he is not. The player is excluded because he is the commander and
// detaching him would hand his own icon to a body he no longer leads, and the
// avatar because it is a placeholder standing where he left the strategic map.
private _men = (units _group) select {
	alive _x
	&& {_x != player}
	&& {isNull TACT_campaignAvatar || {_x != TACT_campaignAvatar}}
};

if (count _men == 0) exitWith {
	systemChat "TEST: nobody to detach - the player is the whole group.";
	grpNull
};

private _take = if (_count > 0) then {
	_count min (count _men)
} else {
	(round ((count _men) / 2)) max 1
};

private _split = _men select [0, _take];

// deleteWhenEmpty, so the detached group goes away with its last man rather
// than leaving an empty group for TACT_fnc_playerGroups to filter out on every
// frame for the rest of the battle.
private _new = createGroup [side _group, true];

if (isNull _new) exitWith {
	systemChat "TEST: the engine would not create a group. Group limit?";
	grpNull
};

_split joinSilent _new;

// The posture the drill deploys with, so the detachment is in the same state
// as the men it left rather than a differently-behaved group that happens to
// be on the same field.
_new setFormation "COLUMN";
_new setBehaviour "AWARE";
_new setCombatMode "RED";

// Clear of him, on his own bearing, so the two icons separate. Ninety degrees
// off his facing rather than in front of him or behind: forward is where he is
// about to walk and backward is where he came from, and either one puts the
// icons back on top of each other the moment he moves.
private _bearing = (getDir player) + 90;
private _anchor = getPosATL player;

private _destination = [
	(_anchor select 0) + (TEST_splitStandoffMetres * sin _bearing),
	(_anchor select 1) + (TEST_splitStandoffMetres * cos _bearing),
	0
];

_new move _destination;

diag_log format [
	"TEST Harness: detached %1 of %2 into %3, standing off %4 m.",
	_take,
	count _men,
	groupId _new,
	TEST_splitStandoffMetres
];

systemChat format [
	"TEST: %1 man/men detached as %2. Click its icon to select it.",
	_take,
	groupId _new
];

_new
