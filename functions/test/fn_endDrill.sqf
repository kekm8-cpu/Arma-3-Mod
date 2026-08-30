/*
	Function: TEST_fnc_endDrill

	Description:
		Closes a drill and hands the map back to the strategic layer. The
		counterpart of TEST_fnc_spawnDrill, and the only way a drill ends -
		there is no opposition and therefore no victory condition to end it.

		It is the conclusion half of TACT_fnc_concludeBattle with the parts
		that need two sides taken out: no outcome to classify, no order to
		retire, and no pair to record as resolved this block. What is left is
		the teardown, and it runs in the same order and for the same reasons -
		control back to the campaign avatar first, position read off the
		survivors second, sync-back third - because those three are ordered by
		what deletes what, and that does not change when the fight does.

		Deliberately not shared with TACT_fnc_concludeBattle. Reaching that
		function with a one-sided record would mean teaching the campaign's
		conclusion path about a case the campaign never has, and the harness is
		meant to lift out whole.

		Safe to call when no drill is running. Every path out of command mode
		has to be able to call it - the key, the player's death, a drill being
		replaced - and a teardown that has to be guarded by its callers is a
		teardown that will eventually run twice.

		It also gives back what the drill borrowed rather than owned. The icon
		probe seeds STRAT_drawTextureCache, which the campaign layer reads too,
		so the seeded keys come back out here - by the list the drill recorded,
		not by the switch that set it.

	Parameters:
		none

	Returns:
		BOOL - true if a drill was running and has been closed.
*/

if (isNil "TEST_activeDrill" || {count TEST_activeDrill == 0}) exitWith { false };

private _record = TEST_activeDrill;

// Cleared first, so anything that reacts to the teardown finds no drill rather
// than a half-torn-down one.
TEST_activeDrill = createHashMap;

private _army  = _record get "attacker";
private _group = _record get "attackerGroup";

// ------------------------------------------------------------------------ //
// 1. THE PLAYER, BEFORE ANYTHING IS DELETED                                 //
// ------------------------------------------------------------------------ //
// Sync-back deletes the entities the records point at, and one of them is the
// body the player is looking through.
call TACT_fnc_dropOut;

// ------------------------------------------------------------------------ //
// 2. WHERE THE ARMY ENDED UP                                                //
// ------------------------------------------------------------------------ //
// Read off the survivors while they still exist. An army whose record still
// claimed its pre-drill position would snap back onto the ground it just
// walked off the moment the strategic map redrew.
private _living = (units _group) select {alive _x};

if (count _living > 0) then {
	private _sumX = 0;
	private _sumY = 0;
	{
		private _p = getPosATL _x;
		_sumX = _sumX + (_p select 0);
		_sumY = _sumY + (_p select 1);
	} forEach _living;

	_army set ["location", [_sumX / (count _living), _sumY / (count _living), 0]];
};

// ------------------------------------------------------------------------ //
// 3. SYNC-BACK AND TEARDOWN                                                 //
// ------------------------------------------------------------------------ //
private _losses = [_army] call TACT_fnc_syncBack;
_losses params ["_menLost", "_vehiclesLost"];

if (!isNull _group) then { deleteGroup _group };

_army set ["inBattle", false];

// An army with nobody left is off the map, by id rather than by subtraction:
// HashMaps compare by content and a subtraction could drop a different record
// that happened to match.
if (count (_army getOrDefault ["men", []]) == 0) then {
	private _id = _army get "id";
	activeArmies = activeArmies select {!((_x get "id") isEqualTo _id)};
	diag_log format ["TEST Harness: %1 has been removed from the map.", _army get "name"];
};

// The probes are instrumentation and belong to no roster, so sync-back never
// saw them and nothing else will remove them. The hostile takes his group with
// him - it was created deleteWhenEmpty false so that it could not vanish
// underneath the watcher.
if (!isNil "TEST_drillProbe" && {!isNull TEST_drillProbe}) then {
	deleteVehicle TEST_drillProbe;
	TEST_drillProbe = objNull;
};

if (!isNil "TEST_drillHostile" && {!isNull TEST_drillHostile}) then {
	private _hostileGroup = group TEST_drillHostile;
	deleteVehicle TEST_drillHostile;
	if (!isNull _hostileGroup && {count (units _hostileGroup) == 0}) then {
		deleteGroup _hostileGroup;
	};
	TEST_drillHostile = objNull;
};

[[0,0,0], false] call TACT_fnc_drawBoundary;

// The icon probe, which is the drill's for as long as the drill runs and the
// campaign layer's again the moment it does not. STRAT_drawTextureCache is
// shared, so the seeded keys are DELETED rather than overwritten with the real
// paths: deleting leaves STRAT_fnc_mapIconTexture to resolve them out of config
// on its next call, which is the same path a cold cache takes and therefore the
// one thing that cannot leave a wrong value behind.
//
// Driven off the list the drill recorded rather than off TEST_iconProbeEnabled.
// The switch can be flipped while a drill is running; what was seeded cannot
// change underneath us, and a teardown that reads the switch would leave white
// squares in the cache for the rest of the mission.
if (!isNil "TEST_iconProbePrimed" && {count TEST_iconProbePrimed > 0}) then {
	if (!isNil "STRAT_drawTextureCache") then {
		{ STRAT_drawTextureCache deleteAt _x } forEach TEST_iconProbePrimed;
	};

	diag_log format [
		"TEST Harness: icon probe off - %1 classes back to CfgMarkers artwork.",
		count TEST_iconProbePrimed
	];

	TEST_iconProbePrimed = [];
};

// ------------------------------------------------------------------------ //
// 4. BACK TO THE STRATEGIC MAP                                              //
// ------------------------------------------------------------------------ //
private _report = format [
	"DRILL ENDED - %1: %2 dead, %3 vehicle(s) lost, %4 left.",
	_army get "name",
	_menLost,
	_vehiclesLost,
	count (_army getOrDefault ["men", []])
];

TACT_lastBattleReport = _report;
systemChat _report;
diag_log format ["TEST Harness: drill %1 closed. %2", _record get "id", _report];

// No turn ever opened, so nothing advances the clock; planning is simply
// reopened over whatever the drill left standing.
call STRAT_fnc_beginPlanning;

true
