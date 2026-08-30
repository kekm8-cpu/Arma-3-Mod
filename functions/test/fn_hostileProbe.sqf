/*
	Function: TEST_fnc_hostileProbe

	Description:
		Puts one genuine WEST soldier on the ground near the drill's vehicle
		probe and watches whether he opens fire on the player sitting in it.

		This is the reciprocal of the question TEST_fnc_vehicleProbe asks. That
		one asks whether our own men shoot our own transport. This asks whether
		the ENEMY will shoot it, which is the direction that decides whether a
		battle happens at all: if config side reaches the enemy's friend/foe
		test, a cartel rifleman looks at a Hunter full of mercenaries and sees a
		friendly truck. Nothing engages, nothing resolves, and the battle layer
		quietly does nothing - a worse failure than the loud one that started
		all this, because it looks like peace rather than like a bug.

		He is a B_ class in a WEST group, so config side and group side agree
		and he needs no conversion: whatever is wrong elsewhere, this man is
		unambiguously WEST, which is what makes him usable as a measuring
		instrument.

		REVEALED, NOT ORDERED. He is handed knowledge of the target with
		`reveal` and then left alone. Ordering him onto it with doTarget or
		doFire would force the shot and prove nothing - the whole question is
		whether his own friend/foe logic decides to take it. Revealing removes
		"he never spotted it" as an explanation without answering the question
		for him.

		The verdict is fire, not a side reading, for the reason the whole
		investigation now runs on behaviour: the infantry bug was never visible
		in a `side` call.

		A silent window is not automatically a failed one, and the report says
		so. With the player inside a BLUFOR-classed vehicle there are two
		friendly-looking things in front of this man - the vehicle and the
		player, who is himself a B_ class carried onto INDEPENDENT - so the
		report prints his relation to each and what he knows about each. The
		clean way to separate them is to get out and stand in the open: shot on
		foot but not in the truck is the truck.

	Parameters:
		0: OBJECT - the vehicle the player is in, and the thing to be shot at

	Returns:
		OBJECT - the hostile soldier, objNull if none was placed.
*/

params [
	["_target", objNull, [objNull]]
];

if (isNull _target) exitWith { objNull };

if (!isNil "TEST_drillHostile" && {!isNull TEST_drillHostile}) then {
	deleteVehicle TEST_drillHostile;
};
TEST_drillHostile = objNull;

private _class = if (isNil "TEST_probeHostileClass") then {""} else {TEST_probeHostileClass};

if (_class == "") exitWith {
	diag_log "TEST Hostile: no hostile class set, none placed.";
	objNull
};

// ------------------------------------------------------------------------ //
// 1. MAKE SURE THE TWO SIDES ARE ACTUALLY ENEMIES                           //
// ------------------------------------------------------------------------ //
// init.sqf sets this at boot and nothing since should have touched it, but a
// probe that depends on a relation is a probe that should assert the relation
// rather than assume it. Re-asserting is free and it means a silent window
// cannot be blamed on the setup afterwards.
west setFriend [independent, 0];
independent setFriend [west, 0];

private _relWestInd = west getFriend independent;
private _relIndWest = independent getFriend west;

// ------------------------------------------------------------------------ //
// 2. THE HOSTILE                                                            //
// ------------------------------------------------------------------------ //
private _distance = if (isNil "TEST_probeHostileDistance") then {100} else {TEST_probeHostileDistance};

private _dir = getDir _target;
private _pos = (getPosATL _target) vectorAdd [
	_distance * sin _dir,
	_distance * cos _dir,
	0
];
_pos = [_pos select 0, _pos select 1, 0];

// WEST group, B_ class: config side and group side agree, so this man needs
// none of the conversion the player's army does and is unambiguously WEST.
private _grp = createGroup [west, false];

if (isNull _grp) exitWith {
	diag_log "TEST Hostile: could not create the WEST group.";
	objNull
};

private _hostile = _grp createUnit [_class, _pos, [], 0, "NONE"];

if (isNull _hostile) exitWith {
	diag_log format ["TEST Hostile: could not create '%1'.", _class];
	deleteGroup _grp;
	objNull
};

_hostile setSkill 1;
_hostile setDir (_dir + 180);

_grp setBehaviour "COMBAT";
_grp setCombatMode "RED";

TEST_drillHostile = _hostile;

// Knowledge, not orders. See the header.
_hostile reveal [_target, 4];
if (!isNull player) then { _hostile reveal [player, 4] };

// ------------------------------------------------------------------------ //
// 3. DID HE FIRE?                                                           //
// ------------------------------------------------------------------------ //
_hostile setVariable ["TEST_hostileFired", false];

_hostile addEventHandler ["Fired", {
	params ["_shooter"];

	if (_shooter getVariable ["TEST_hostileFired", false]) exitWith {};
	_shooter setVariable ["TEST_hostileFired", true];

	private _line = "HOSTILE PROBE [PASS] - the WEST soldier opened fire. Config side does not stop an enemy engaging a BLUFOR-classed vehicle.";
	systemChat _line;
	diag_log format ["TEST %1", _line];
}];

// ------------------------------------------------------------------------ //
// 4. THE WINDOW                                                             //
// ------------------------------------------------------------------------ //
private _window = if (isNil "TEST_probeHostileWindow") then {30} else {TEST_probeHostileWindow};

[_hostile, _target, _window] spawn {
	params ["_hostile", "_target", "_window"];

	private _waited = 0;

	while {
		_waited < _window
		&& {!isNull _hostile}
		&& {alive _hostile}
		&& {!(_hostile getVariable ["TEST_hostileFired", false])}
	} do {
		sleep 1;
		_waited = _waited + 1;
	};

	if (isNull _hostile || {!alive _hostile}) exitWith {
		private _dead = "HOSTILE PROBE - the WEST soldier is gone before the window closed; no reading.";
		systemChat _dead;
		diag_log format ["TEST %1", _dead];
	};

	if (_hostile getVariable ["TEST_hostileFired", false]) exitWith {};

	// Silent. Say what he could see and how he rated it, because "never
	// spotted it" and "saw it and did not care" are different problems and
	// only the second one is this bug.
	private _knowsVehicle = _hostile knowsAbout _target;
	private _knowsPlayer  = if (isNull player) then {-1} else {_hostile knowsAbout player};

	private _relToVehicle = (side _hostile) getFriend (side _target);
	private _relToPlayer  = if (isNull player) then {-1} else {(side _hostile) getFriend (side player)};

	private _line = format [
		"HOSTILE PROBE [NO FIRE after %1s] - knowsAbout vehicle=%2 player=%3, friendliness toVehicle=%4 toPlayer=%5. If knowsAbout is near zero he never saw it; otherwise config side is reaching his friend/foe test. Get out and stand in the open - shot on foot but not in the truck means it is the truck.",
		_window,
		_knowsVehicle,
		_knowsPlayer,
		_relToVehicle,
		_relToPlayer
	];

	systemChat _line;
	diag_log format ["TEST %1", _line];
};

private _placed = format [
	"HOSTILE PROBE - a %1 (WEST) is %2 m out and revealed. west>ind=%3, ind>west=%4. Watching %5s for him to fire.",
	_class,
	_distance,
	_relWestInd,
	_relIndWest,
	_window
];

systemChat _placed;
diag_log format ["TEST %1", _placed];

_hostile
