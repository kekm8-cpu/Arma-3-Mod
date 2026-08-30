/*
	Function: TEST_fnc_spawnDrill

	Description:
		Puts ONE army on the ground with nobody to fight, hands the player a
		body in it, and opens the map's command mode. A drill: the command
		interface with the battle taken out from under it.

		It exists because the three things being tested at the moment - the
		handover between the stock interface and the map's command mode, what
		the command layer draws, and selection - are all properties of the
		command layer alone. A real engagement is a poor place to test them:
		the fight ends while the map is being looked at, the units under
		inspection are being shot, and the battle clock takes the map away at
		TACT_battleRealSecondsMax whether or not the tester was finished.

		A drill has no opposition and therefore no victory condition, so it
		does not conclude on its own. It runs until TEST_fnc_endDrill is called,
		which SHIFT+B does. That is the whole reason this is not
		TEST_fnc_spawnBattle with one army: the battle lifecycle is written
		around two sides classifying each other's exit, and a one-sided
		engagement handed to TACT_fnc_resolveVictory reads as an annihilation
		on its first tick.

		What it does NOT do is fake the layer it is testing. Deployment is
		TACT_fnc_deployVehicles and TACT_fnc_deployMen, the body is taken by
		TACT_fnc_dropIn, the boundary is TACT_fnc_drawBoundary, and the map
		draws through TACT_fnc_buildCommandList like any battle. Only the
		conclusion is the harness's own, because there is no conclusion to
		share.

		The record it holds is engagement-shaped - `attacker`, `attackerGroup`,
		`defender`, `defenderGroup` - so TACT_fnc_dropIn takes it unchanged.
		The defender is an empty record rather than a missing key: dropIn walks
		both sides, and a side that is nil is a different kind of absent from a
		side with no men in it.

	Parameters:
		0: STRING or ARRAY - drill name in TEST_drills, or an inline army spec
		   (see TEST_fnc_buildArmy)
		1: ARRAY - optional anchor. Supplied, the army deploys here instead of
		   at the position its spec names. Empty (default) uses the spec.
		2: BOOL - clear the map first (default true).

	Returns:
		HASHMAP - the drill record, or empty if it could not be opened.
*/

params [
	["_drillSpec", "", ["", []]],
	["_anchor", [], [[]]],
	["_clearFirst", true, [true]]
];

// ------------------------------------------------------------------------ //
// 1. GUARDS                                                                 //
// ------------------------------------------------------------------------ //
if (isNil "TEST_activeDrill") then { TEST_activeDrill = createHashMap };

if (count TEST_activeDrill > 0) exitWith {
	systemChat "TEST: a drill is already running. SHIFT+B ends it.";
	createHashMap
};

if (!isNil "STRAT_resolutionRunning" && {STRAT_resolutionRunning}) exitWith {
	systemChat "TEST: a block is resolving. Wait for the planning phase.";
	createHashMap
};

if (count TACT_activeEngagements > 0) exitWith {
	systemChat "TEST: a battle is already running.";
	createHashMap
};

// ------------------------------------------------------------------------ //
// 2. RESOLVE THE SPEC                                                       //
// ------------------------------------------------------------------------ //
private _spec = [];

if (_drillSpec isEqualType "") then {
	if (!isNil "TEST_drills" && {_drillSpec in TEST_drills}) then {
		_spec = TEST_drills get _drillSpec;
	} else {
		diag_log format ["TEST Harness: unknown drill '%1'.", _drillSpec];
	};
} else {
	_spec = _drillSpec;
};

if (count _spec < 3) exitWith {
	systemChat "TEST: drill needs an army spec.";
	createHashMap
};

// Copied before the anchor is written in, for the reason TEST_fnc_buildArmy
// copies the position: the spec tables are shared and an army that rewrote its
// table's position would move the drill every time it was run.
_spec = +_spec;

if (count _anchor >= 2) then {
	_spec set [2, [_anchor select 0, _anchor select 1, 0]];
};

// ------------------------------------------------------------------------ //
// 3. BUILD                                                                  //
// ------------------------------------------------------------------------ //
if (_clearFirst && {!([] call TEST_fnc_clearArmies)}) exitWith {
	systemChat "TEST: the map could not be cleared. Wait for the planning phase.";
	createHashMap
};

private _army = [_spec] call TEST_fnc_buildArmy;

if (count _army == 0) exitWith {
	systemChat "TEST: the army spec failed to build. See the log.";
	createHashMap
};

// ------------------------------------------------------------------------ //
// 4. DEPLOY                                                                 //
// ------------------------------------------------------------------------ //
private _position = _army get "location";

// Flagged for the same reason a battle flags it: strategic resolution skips an
// army that is in one, and a drill that is not skipped would be marched about
// by the turn loop the moment a block was committed underneath it.
_army set ["inBattle", true];

// A drill has no opposition to face, so there is no midpoint to converge on
// and the deployment bearing is arbitrary. It is the army's own facing rather
// than a random one so a drill re-run twice puts the same men in the same
// places - a selection test is worth less if the icons move between runs.
private _bearing = 0;

// The shipping path, both calls, exactly as TACT_fnc_initiateBattle makes
// them. The drill briefly owned its own placement while the side-conversion
// technique was on trial; that technique now lives in TACT_fnc_deployMen, so
// the harness copy is gone and a drill tests what a battle runs.
//
// No road lookup. `midpointConverge` lines vehicles up along the approach road
// into a fight; there is no fight and no approach, so the deployment bearing
// is what fn_deployVehicles falls back to anyway.
[_army, [], _position, _bearing] call TACT_fnc_deployVehicles;

private _group = [_army, _position, _bearing] call TACT_fnc_deployMen;

if (count (units _group) == 0) exitWith {
	diag_log format ["TEST Harness: drill deployment put nobody on the ground for %1.", _army get "name"];
	systemChat "TEST: deployment failed. The roster needs at least one man.";

	[_army] call TACT_fnc_syncBack;
	if (!isNull _group) then { deleteGroup _group };
	_army set ["inBattle", false];

	createHashMap
};

// The same posture a battle deploys with, so what is being looked at on the
// map is a group in the state command mode will actually meet. No move order:
// a drill has nowhere to be, and a group order would walk the men off the
// icons being tested before the map was open.
_group setFormation "COLUMN";
_group setBehaviour "AWARE";
_group setCombatMode "RED";

// The vehicle probe, placed after the posture so the squad is already AWARE
// and weapons free when it appears - a probe put down in front of men who are
// not yet allowed to engage would answer the question with "they never tried".
[_position, _bearing] call TEST_fnc_vehicleProbe;

// ------------------------------------------------------------------------ //
// 5. OPEN COMMAND MODE                                                      //
// ------------------------------------------------------------------------ //
private _radius = TACT_boundaryRadius;

if (isNil "TEST_nextDrillId") then { TEST_nextDrillId = 0 };
TEST_nextDrillId = TEST_nextDrillId + 1;

private _record = createHashMapFromArray [
	["id", format ["DRILL_%1", TEST_nextDrillId]],
	["type", "drill"],

	// Engagement-shaped, so TACT_fnc_dropIn reads it unchanged. There is no
	// second side and the empty record says so.
	["attacker", _army],
	["attackerGroup", _group],
	["defender", createHashMap],
	["defenderGroup", grpNull],

	["boundaryAnchor", +_position],
	["boundaryRadius", _radius]
];

// Drawn even though nothing enforces it, because the boundary is part of what
// the map looks like during a fight and its absence would make the drill's map
// a different map from the one being tested.
[_position, true, _radius] call TACT_fnc_drawBoundary;

if (!([_record] call TACT_fnc_dropIn)) exitWith {
	diag_log "TEST Harness: drill built but no soldier is flagged isPlayer, nothing to command.";
	systemChat "TEST: nobody in this roster is flagged as the player. Drill abandoned.";

	[[0,0,0], false] call TACT_fnc_drawBoundary;
	[_army] call TACT_fnc_syncBack;
	if (!isNull _group) then { deleteGroup _group };
	_army set ["inBattle", false];

	createHashMap
};

TEST_activeDrill = _record;

// No block is resolving and no turn is open, but the phase closes input for
// the duration for the reason TEST_fnc_spawnBattle closes it: an order, a
// SPACE commit or a second harness key landing on top of this would put a
// marching block underneath the men being commanded.
STRAT_turnPhase = "resolving";

diag_log format [
	"TEST Harness: drill %1 opened - %2, %3 men on the ground at %4.",
	_record get "id",
	_army get "name",
	count (units _group),
	_position
];

systemChat format [
	"DRILL - %1, %2 on the ground.",
	_army get "name",
	count (units _group)
];

// Over the planning hint STRAT_fnc_beginPlanning left on screen, which is now
// describing a phase this drill has closed. Written as the controls rather
// than as a status line: a drill is opened to try the interface out, and the
// interface is what it should be telling you.
hint format [
	"DRILL - %1\n\nM opens the map. With it closed the stock squad bar and commanding menu are the interface; with it open they go away and the command map is. Nothing is switched by hand.\n\nOn the map:\n  click a unit       select it\n  CTRL + click       add one, or take one back out\n  click the ground   move the selection\n\nYou are the yellow icon, and are never selectable. SHIFT+B ends the drill and hands the map back to the campaign layer.\n\nAn empty BLUFOR truck sits ahead as a side probe. Get in: five seconds later a WEST AT soldier is placed 100 m out and revealed. He should shoot you. If he does not, config side is reaching his friend/foe test - get out and stand in the open to tell the truck apart from you. Results go to chat and the log.",
	_army get "name"
];

_record
