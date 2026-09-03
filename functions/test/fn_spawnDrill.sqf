/*
	Function: TEST_fnc_spawnDrill

	Description:
		Puts ONE army on the ground with nobody to fight, hands the player a
		body in it, and opens the map's command mode. A drill: the command
		interface with the battle taken out from under it.

		A drill has no opposition and therefore no victory condition, so it does
		not conclude on its own: it runs until TEST_fnc_endDrill is called,
		which SHIFT+B does. That is why this is not TEST_fnc_spawnBattle with
		one army - the battle lifecycle is written around two sides classifying
		each other's exit, and a one-sided engagement handed to
		TACT_fnc_resolveVictory reads as an annihilation on its first tick.

		IT DOES NOT FAKE THE LAYER IT IS TESTING. Deployment is
		TACT_fnc_deployVehicles and TACT_fnc_deployMen, the body is taken by
		TACT_fnc_dropIn, the boundary is TACT_fnc_drawBoundary, and the map
		draws through TACT_fnc_buildCommandList like any battle. Only the
		conclusion is the harness's own, because there is no conclusion to
		share.

		The record it holds is engagement-shaped - `attacker`, `attackerGroup`,
		`defender`, `defenderGroup` - so TACT_fnc_dropIn takes it unchanged. The
		defender is an EMPTY record rather than a missing key: dropIn walks both
		sides, and a nil side is a different kind of absent from a side with no
		men in it.

		Section 6 is the one bounded exception. With TEST_iconProbeEnabled set
		it seeds STRAT_drawTextureCache so the command layer's silhouettes draw
		as plain squares; it substitutes the texture and nothing else, so the
		resolver, the draw list and the renderer run exactly as they ship. The
		cache is shared with the campaign layer, so TEST_fnc_endDrill hands it
		back.

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
// them, so a drill exercises what a battle runs.
//
// No road lookup: `midpointConverge` lines vehicles up along the approach road
// into a fight, and there is neither here, so the deployment bearing is what
// fn_deployVehicles falls back to anyway.
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

// The side probes, off unless TEST_probeEnabled says otherwise. They end with
// a live WEST soldier shooting at the player, which is the right answer to the
// question they ask and the wrong thing to have happening underneath a
// selection test.
//
// Placed after the posture, so the squad is already AWARE and weapons free
// when the probe appears - a probe put down in front of men not yet allowed to
// engage would answer the question with "they never tried".
if (!isNil "TEST_probeEnabled" && {TEST_probeEnabled}) then {
	[_position, _bearing] call TEST_fnc_vehicleProbe;
};

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
	"DRILL - %1\n\nM opens the map. With it closed the stock squad bar and commanding menu are the interface; with it open they go away and the command map is. Nothing is switched by hand.\n\nOn the map:\n  click a unit       select it\n  CTRL + click       add one, or take one back out\n  click the ground   move the selection\n\nYou are the yellow icon, and are never selectable. SHIFT+B ends the drill and hands the map back to the campaign layer.",
	_army get "name"
];

// ------------------------------------------------------------------------ //
// 6. THE ICON PROBE                                                         //
// ------------------------------------------------------------------------ //
// Off unless TEST_iconProbeEnabled says otherwise; init.sqf has the switch and
// how to read one off.
//
// STRAT_fnc_mapIconTexture answers out of STRAT_drawTextureCache before it
// reads config, so seeding that cache substitutes the texture without the
// resolver, the draw list or the renderer knowing anything happened - the probe
// must not change the path it is measuring.
//
// Seeded here rather than at boot because the cache is shared with the campaign
// layer, and LAST, after the drop-in has succeeded: TEST_fnc_endDrill is what
// unseeds it and the failure paths above never reach it, so an abandoned drill
// would otherwise leave white squares in a cache the campaign map goes on
// reading.
if (!isNil "TEST_iconProbeEnabled" && {TEST_iconProbeEnabled}) then {

	// Every class the command layer can ask for. The first three are named by
	// TACT_fnc_buildCommandList itself - b_hq for the commander, b_inf and
	// b_armor for a command entity on foot or mounted - and the rest are the
	// faction silhouettes a collapsed group icon reads. A drill has no allies
	// and no second group of its own, so those last ones are unused today;
	// they are seeded anyway, because a probe that covers what the layer can
	// draw rather than what this drill happens to draw does not need revisiting
	// the first time a drill grows a second group.
	private _classes = ["b_hq", "b_inf", "b_armor"];

	{
		if (!(_y in _classes)) then { _classes pushBack _y };
	} forEach STRAT_drawFactionIcon;

	// And the CfgVehicles classes actually on the ground, because individual
	// entities no longer resolve through the marker table at all - they go
	// through STRAT_fnc_mapUnitTexture, keyed by vehicle class. Those keys
	// cannot be listed in advance the way the marker classes can, so they are
	// read off the deployment: whatever is standing here is what the map is
	// about to ask for. Shared cache, so one seeding covers both resolvers.
	{
		private _class = typeOf (vehicle _x);
		if (_class != "" && {!(_class in _classes)}) then { _classes pushBack _class };
	} forEach (units _group);

	if (isNil "STRAT_drawTextureCache") then { STRAT_drawTextureCache = createHashMap };

	{
		STRAT_drawTextureCache set [_x, TEST_iconProbeTexture];
	} forEach _classes;

	// What was actually seeded, so the teardown removes this list rather than
	// a second copy of it written out by hand and free to disagree.
	TEST_iconProbePrimed = +_classes;

	diag_log format [
		"TEST Harness: icon probe on - %1 classes drawing as plain squares (%2).",
		count _classes,
		_classes
	];

	// Said on screen as well as in the log, because the probe changes what the
	// map means. A tester who sees squares and does not know why has been given
	// a second bug to chase rather than an answer to the first one.
	systemChat "DRILL - icon probe ON: command icons are plain squares, not artwork.";
};

_record
