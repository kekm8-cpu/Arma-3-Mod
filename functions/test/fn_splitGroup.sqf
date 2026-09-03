/*
	Function: TEST_fnc_splitGroup

	Description:
		Detaches part of the player's group into a group of its own and walks it
		clear of him, so a drill has a collapsed group on the map to click at.
		Without it there is nothing: a drill deploys one army as one group, and
		the second group in a battle is hostile, which this layer does not draw.

		IT DELIBERATELY LEAVES THE NEW GROUP UNSTAMPED. TACT_fnc_playerGroups
		resolves membership by SIDE rather than by the STRAT_faction stamp
		precisely because an engine-created group carries none, and colours it
		from the group it came out of. Stamping it here would walk the map's
		hardest case past the code written for it.

		How many: half the men he is not, rounded, never fewer than one nor more
		than there are. A four-man fireteam leaves two detached and one with
		him, which is one of each kind of icon on the map.

		They walk TEST_splitStandoffMetres clear before stopping - a group icon
		drawn over a leader standing among the men he just left is an icon on
		top of three others. The order is a group `move` rather than a doMove
		per man, because that is what a group with no player in it takes
		natively.

		A DRILL ONLY. TEST_fnc_endDrill averages the surviving `units` of the
		deployed group to decide where the army ended up, so a detachment must
		not vote on that position. (The count itself is safe now:
		TACT_fnc_resolveVictory and TACT_fnc_concludeBattle both count living
		soldiers off the army record's `men` array, which no split can take a
		man out of.) The player's own in-battle split is TACT_fnc_splitGroup on
		the map; this is the debug key.

	Parameters:
		0: NUMBER - how many men to detach. 0 (default) takes half.

	Returns:
		GROUP - the detached group, or grpNull if nothing could be detached.
*/

params [
	["_count", 0, [0]]
];

if (isNil "TEST_activeDrill" || {count TEST_activeDrill == 0}) exitWith {
	systemChat "TEST: split is a drill tool. In a battle, use New Group on the map.";
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
