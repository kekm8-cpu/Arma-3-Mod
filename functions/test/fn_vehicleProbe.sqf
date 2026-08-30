/*
	Function: TEST_fnc_vehicleProbe

	Description:
		Puts one empty BLUFOR-classed vehicle in front of the drill's squad and
		reports what side it reads as, so the question the infantry fix left
		open can be answered: does a vehicle carry its config side the way a
		soldier did?

		It is an open question because nothing has tested it. Every drill so
		far has been dismounted by design, and TACT_fnc_deployVehicles creates
		its vehicles with a bare createVehicle - no group, no side, nothing to
		join. The anchor trick that fixed the infantry does not transfer: a
		vehicle reports grpNull, so there is no group for it to be carried into.

		Three readings, covering both states that matter:

		  EMPTY   at spawn. A vehicle with nobody in it is what deployment
		          produces for the moment between placing it and seating the
		          men, and if config side sticks to an empty hull that window
		          is a window where our own transport is a target.
		  CREWED  TEST_probeSettleDelay seconds after the first man climbs in,
		          which is the state a vehicle spends a battle in. The delay is
		          there to let anything that resolves side asynchronously
		          finish before the reading is taken.
		  HIT     whenever it is shot, naming who shot it. This is the actual
		          verdict and the other two are instrumentation: the infantry
		          bug was never visible in a side call, and the thing that made
		          it undeniable was men firing at something they should not
		          have been firing at.

		Deliberately NOT part of the army record. A vehicle in `vehicles` is a
		vehicle TACT_fnc_deployMen will try to seat men in, TACT_fnc_syncBack
		will read condition off, and TEST_fnc_clearArmies will delete on its
		own schedule. The probe is none of those things - it is a lump of
		instrumentation - so it is held in a global of its own and removed by
		TEST_fnc_endDrill.

	Parameters:
		0: ARRAY  - the squad's deployment position
		1: NUMBER - the squad's deployment bearing, degrees

	Returns:
		OBJECT - the probe vehicle, objNull if none was placed.
*/

params [
	["_position", [0,0,0], [[]]],
	["_bearing", 0, [0]]
];

// A probe left over from a previous drill is a second vehicle nobody asked
// for, and its handlers would report over the top of this one's.
if (!isNil "TEST_drillProbe" && {!isNull TEST_drillProbe}) then {
	deleteVehicle TEST_drillProbe;
};
TEST_drillProbe = objNull;

private _class = if (isNil "TEST_probeVehicleClass") then {""} else {TEST_probeVehicleClass};

if (_class == "") exitWith {
	diag_log "TEST Probe: no probe class set, none placed.";
	objNull
};

private _distance = if (isNil "TEST_probeDistance") then {45} else {TEST_probeDistance};

// In front of the squad along its own deployment bearing. The men face this
// way, so if they are going to engage it they can see it - a probe behind them
// would answer the question with "they never looked".
private _fwd = [sin _bearing, cos _bearing, 0];
private _pos = [_position param [0, 0, [0]], _position param [1, 0, [0]], 0]
	vectorAdd (_fwd vectorMultiply _distance);

private _veh = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];

if (isNull _veh) exitWith {
	diag_log format ["TEST Probe: could not create '%1'.", _class];
	objNull
};

_veh setDir (_bearing + 180);

// Damage stays on. The Hit handler below is the whole verdict, and an
// invulnerable probe would never fire it.
TEST_drillProbe = _veh;

// ------------------------------------------------------------------------ //
// 1. EMPTY - THE BASELINE                                                   //
// ------------------------------------------------------------------------ //
[_veh, "EMPTY"] call TEST_fnc_probeReport;

// ------------------------------------------------------------------------ //
// 2. HIT - THE VERDICT                                                      //
// ------------------------------------------------------------------------ //
// Once. A firefight would otherwise report every round that lands, and the
// first one already answers the question.
_veh setVariable ["TEST_probeHitReported", false];

_veh addEventHandler ["Hit", {
	params ["_hitVeh", "_causedBy", "_damage", "_instigator"];

	if (_hitVeh getVariable ["TEST_probeHitReported", false]) exitWith {};
	_hitVeh setVariable ["TEST_probeHitReported", true];

	private _shooter = if (isNull _instigator) then {_causedBy} else {_instigator};

	// The tester shooting it himself is not the AI turning on it, and reading
	// "ONE OF OURS" after firing a round into it on purpose would be a false
	// positive on the one question this probe exists to answer.
	private _byPlayer = !isNull player && {_shooter == player};
	private _ours = !_byPlayer
		&& {!isNull player}
		&& {!isNull _shooter}
		&& {_shooter in (units (group player))};

	private _verdict = format [
		"PROBE [HIT] shot by %1 (%2) - %3",
		if (isNull _shooter) then {"unknown"} else {typeOf _shooter},
		if (isNull _shooter) then {"?"} else {str (side _shooter)},
		if (_byPlayer) then {
			"that was you, not the squad. Says nothing either way."
		} else {
			if (_ours) then {
				"ONE OF OURS. Vehicles carry config side; empty transport is a target."
			} else {
				"not one of ours."
			}
		}
	];

	systemChat _verdict;
	diag_log format ["TEST %1", _verdict];

	[_hitVeh, "HIT"] call TEST_fnc_probeReport;
}];

// ------------------------------------------------------------------------ //
// 3. CREWED - AFTER THE SETTLE                                              //
// ------------------------------------------------------------------------ //
// GetIn fires per seat, so the first man in arms the reading and the rest are
// ignored; without that, a four-man mount reports four times.
_veh setVariable ["TEST_probeCrewReported", false];

_veh addEventHandler ["GetIn", {
	params ["_getInVeh", "_role", "_unit"];

	if (_getInVeh getVariable ["TEST_probeCrewReported", false]) exitWith {};
	_getInVeh setVariable ["TEST_probeCrewReported", true];

	// Spawned because an event handler runs unscheduled and cannot sleep, and
	// the whole point of this reading is that it is taken late.
	_getInVeh spawn {
		private _v = _this;
		private _delay = if (isNil "TEST_probeSettleDelay") then {5} else {TEST_probeSettleDelay};

		sleep _delay;

		if (isNull _v) exitWith {};
		[_v, "CREWED"] call TEST_fnc_probeReport;

		// And then the reciprocal question, which is the one that decides
		// whether a battle can happen: with the player in a BLUFOR-classed
		// vehicle, will a genuine WEST soldier engage him?
		[_v] call TEST_fnc_hostileProbe;
	};
}];

diag_log format [
	"TEST Probe: %1 placed %2 m ahead of the squad, empty. Get in to take the crewed reading.",
	_class,
	_distance
];

systemChat format [
	"PROBE - an empty %1 is %2 m ahead. Watch whether the squad shoots it; get in for the crewed reading.",
	_class,
	_distance
];

_veh
