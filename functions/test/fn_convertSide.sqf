/*
	Function: TEST_fnc_convertSide

	Description:
		Forces already-spawned units onto the side of the group they are in,
		by taking them out of it and joining them back in under a higher-ranked
		leader whose class is genuinely configured on that side.

		This exists because createUnit does not do it. A group created on
		INDEPENDENT and filled with B_ classes produces men who are in an
		INDEPENDENT group and behave as WEST: with `independent setFriend
		[west, 0]` in init.sqf they are hostile to their own squad, and a drill
		with no enemy on the map ends with four men shooting each other. The
		roster table's "cosmetic only, since createUnit takes the group's
		side" was wrong.

		Matching every roster's classes to its side is the obvious fix and it
		is the expensive one: it costs the project every unit class it does not
		own. The cartel is where that bites - drugLords sits on WEST and wants
		Syndikat, which the game configures as INDEPENDENT, and there is no
		WEST-configured cartel to fall back on. This is the fix that costs
		nothing instead.

		The technique is the old one: a unit joining a group led by a
		higher-ranked unit takes the group's side. Three things make it work,
		and all three are load-bearing:

		  the anchor is of the destination side  a class that shares the
		                                         problem cannot be the cure
		  the anchor outranks everyone           COLONEL, above any config rank
		  the men actually leave and return      a join only fires on a group
		                                         the unit is not already in

		ORDER MATTERS. The anchor is created BEFORE the men leave, because
		TACT_fnc_deployMen builds its group with deleteWhenEmpty set, and a
		group whose last man walks out is a deleted group - the destination
		would be gone before the men could be joined back to it.

		Everything happens inside one frame with no suspension, so the anchor
		is never rendered, never simulated and never seen. It is hidden and
		made invulnerable anyway, because "never" here rests on this function
		not growing a sleep later.

		Harness code. If the drill proves it, this is what gets promoted into
		TACT_fnc_deployMen so that every army gets it and the roster tables can
		go back to being about what a force looks like.

	Parameters:
		0: GROUP - the destination group. Its side is the side converted to.
		1: ARRAY - optional units to convert. Default: everyone in the group.

	Returns:
		BOOL - true if the conversion ran.
*/

params [
	["_group", grpNull, [grpNull]],
	["_units", [], [[]]]
];

if (isNull _group) exitWith {
	diag_log "TEST Convert: no group, nothing converted.";
	false
};

if (count _units == 0) then { _units = units _group };
_units = _units select {alive _x};

if (count _units == 0) exitWith {
	diag_log "TEST Convert: no living units, nothing converted.";
	false
};

private _side = side _group;

// The leader the group had before the anchor takes over, so it can be given
// back. Read now, because in a moment the leader is the anchor.
private _leader = leader _group;

// ------------------------------------------------------------------------ //
// 1. THE ANCHOR                                                             //
// ------------------------------------------------------------------------ //
private _anchorClass = TEST_sideAnchorClass getOrDefault [str _side, ""];

if (_anchorClass == "") exitWith {
	diag_log format ["TEST Convert: no anchor class for side %1, group left as it was.", _side];
	false
};

// Into the destination group, and first. See the header: the group is built
// with deleteWhenEmpty, so it has to hold somebody for the whole of the
// shuffle below.
private _anchor = _group createUnit [_anchorClass, getPosATL (_units select 0), [], 0, "NONE"];

if (isNull _anchor) exitWith {
	diag_log format ["TEST Convert: could not create anchor '%1', group left as it was.", _anchorClass];
	false
};

// Above every rank a config can carry, so it outranks the men whatever their
// classes declare - B_T_Soldier_SL_F is a SERGEANT, and a squad leader who
// outranks the anchor would defeat the whole thing.
_anchor setUnitRank "COLONEL";
_group selectLeader _anchor;

_anchor hideObject true;
_anchor allowDamage false;

// ------------------------------------------------------------------------ //
// 2. OUT, AND BACK IN                                                       //
// ------------------------------------------------------------------------ //
// The holding group is on the side the men's CLASSES are configured on - the
// side they are behaving as - read from config rather than assumed, so this
// works for a cartel roster on WEST as readily as for mercenaries on
// INDEPENDENT. CfgVehicles >> side: 0 EAST, 1 WEST, 2 GUER, 3 CIVILIAN.
//
// deleteWhenEmpty is false: this group is emptied on purpose one line later,
// and a group that deletes itself out from under the delete below is a null
// reference waiting to be tidied up.
private _configSides = [east, west, independent, civilian];
private _configSide = _configSides param [
	getNumber (configOf (_units select 0) >> "side"),
	_side
];

private _holding = createGroup [_configSide, false];

if (isNull _holding) exitWith {
	diag_log "TEST Convert: could not create the holding group, group left as it was.";
	deleteVehicle _anchor;
	if (!isNull _leader) then { _group selectLeader _leader };
	false
};

_units joinSilent _holding;
_units joinSilent _group;

// ------------------------------------------------------------------------ //
// 3. TAKE THE SCAFFOLDING BACK OUT                                          //
// ------------------------------------------------------------------------ //
// The leader first, then the anchor. Deleting the leader and letting the
// engine pick a replacement would hand the group to whoever it liked rather
// than to the man deployment chose.
if (!isNull _leader && {alive _leader} && {_leader in (units _group)}) then {
	_group selectLeader _leader;
};

deleteVehicle _anchor;

if (!isNull _holding) then { deleteGroup _holding };

diag_log format [
	"TEST Convert: %1 unit(s) converted to %2 via a %3 anchor (they were configured %4).",
	count _units,
	_side,
	_anchorClass,
	_configSide
];

true
