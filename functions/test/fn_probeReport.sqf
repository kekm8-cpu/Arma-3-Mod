/*
	Function: TEST_fnc_probeReport

	Description:
		Prints what side the drill's probe vehicle is currently reading as, and
		whether any of the player's own men are pointed at it.

		Split out from TEST_fnc_vehicleProbe because three moments need the same
		readout and two of them happen inside event handlers, which cannot see a
		function local to the scope that added them.

		SIDE IS THE PROXY, NOT THE VERDICT: the men in the infantry bug reported
		INDEPENDENT the entire time they were shooting each other. So this
		prints the relation the engine actually reads - getFriend, hostile below
		0.6 - and who is currently aiming at the probe, leaving `side` in as
		context.

		systemChat and diag_log rather than hintSilent: a hint is overwritten by
		the planning readout and leaves nothing behind to paste afterwards.

	Parameters:
		0: OBJECT - the probe vehicle
		1: STRING - which moment this is: "EMPTY", "CREWED", "HIT"

	Returns:
		STRING - the line reported, empty if there was nothing to report on.
*/

params [
	["_veh", objNull, [objNull]],
	["_phase", "", [""]]
];

if (isNull _veh) exitWith { "" };

private _crewSides = (crew _veh) apply {str (side _x)};

private _driver = driver _veh;
private _driverSide = if (isNull _driver) then {"none"} else {str (side _driver)};

// The number the engine decides hostility on. Below 0.6 is hostile, which is
// the same threshold the setFriend block in init.sqf is written against.
private _friendliness = if (isNull player) then {-1} else {
	(side player) getFriend (side _veh)
};

// Behaviour, not configuration: who among our own is actually pointed at it.
private _aiming = [];
if (!isNull player) then {
	_aiming = ((units (group player)) select {
		alive _x && {assignedTarget _x == _veh}
	}) apply {typeOf _x};
};

private _line = format [
	"PROBE [%1] %2 - side=%3, crew=%4, driver=%5, friendlinessToPlayerSide=%6, oursAimingAtIt=%7",
	_phase,
	typeOf _veh,
	side _veh,
	_crewSides,
	_driverSide,
	_friendliness,
	if (count _aiming == 0) then {"none"} else {_aiming joinString ", "}
];

systemChat _line;
diag_log format ["TEST %1", _line];

_line
