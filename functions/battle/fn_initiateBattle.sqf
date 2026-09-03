/*
	Function: TACT_fnc_initiateBattle

	Description:
		Opens a battle from an engagement record (lifecycle stage 7): places both
		rosters, gives each group its marching orders, and draws the boundary.

		The armies stay in `activeArmies` and are flagged `inBattle` rather than
		being pulled out of it, so the return to the strategic map is just
		clearing the flag - nothing has to remember to put them back.

		Deployment is still `midpointConverge`: each army placed where it
		already stands, facing the anchor. Edge deployment facing the
		destination bearing (2.1) changes the two positions and two bearings
		computed below and nothing inside the deployment routines.

	Parameters:
		0: HASHMAP - engagement record (see TACT_fnc_buildEngagement)

	Returns:
		BOOL - true if both sides put units on the ground, false if deployment
		       failed and the engagement must be abandoned.
*/

params [
	["_engagement", createHashMap, [createHashMap]]
];

private _attacker = _engagement get "attacker";
private _defender = _engagement get "defender";
private _anchor   = _engagement get "boundaryAnchor";
private _radius   = _engagement get "boundaryRadius";

// 1. Suppress strategic resolution for both armies for the duration.
_attacker set ["inBattle", true];
_defender set ["inBattle", true];

// 2. Deployment point and bearing per army. Both deployment routines take
// these rather than deriving them, which is what keeps the geometry one thing
// that changes in one place.
private _fnc_bearingTo = {
	params ["_from", "_to"];
	private _v = [(_to select 0) - (_from select 0), (_to select 1) - (_from select 1), 0];
	// atan2 returns -180..180 and SQF's % keeps the sign of the dividend, so
	// the wrap is +360 first. Degenerate only if an army is standing exactly
	// on the anchor, which atan2 answers with 0 rather than an error.
	((((_v select 0) atan2 (_v select 1)) + 360) % 360)
};

private _attackerPos = _attacker get "location";
private _defenderPos = _defender get "location";

private _attackerDir = [_attackerPos, _anchor] call _fnc_bearingTo;
private _defenderDir = [_defenderPos, _anchor] call _fnc_bearingTo;

// 3. Approach roads into the anchor, used to line the vehicles up. An army too
// far from a road gets an empty path back; fn_deployVehicles falls back to the
// deployment bearing rather than failing to place anything.
private _attackerRoad = [_attackerPos, _anchor] call STRAT_fnc_calculateRoadPath;
private _defenderRoad = [_defenderPos, _anchor] call STRAT_fnc_calculateRoadPath;

// 4. Physical deployment: vehicles first, then infantry, which mounts into
// whatever seats those vehicles turned out to have and walks otherwise. Order
// matters - fn_deployMen reads the vehicles that actually landed, not the ones
// the roster lists.
[_attacker, _attackerRoad, _attackerPos, _attackerDir] call TACT_fnc_deployVehicles;
[_defender, _defenderRoad, _defenderPos, _defenderDir] call TACT_fnc_deployVehicles;

private _attackerGroup = [_attacker, _attackerPos, _attackerDir] call TACT_fnc_deployMen;
private _defenderGroup = [_defender, _defenderPos, _defenderDir] call TACT_fnc_deployMen;

_engagement set ["attackerGroup", _attackerGroup];
_engagement set ["defenderGroup", _defenderGroup];

// 5. Deployment legitimately produces nothing for an army whose roster is
// empty of men. A side that cannot field anybody must NOT be counted as
// annihilated, so the engagement is abandoned and both rosters put back
// untouched: the failure costs a battle, never a roster.
if (count (units _attackerGroup) == 0 || {count (units _defenderGroup) == 0}) exitWith {
	diag_log format [
		"TACT Battle: deployment failed (%1: %2 units, %3: %4 units), engagement abandoned.",
		_attacker get "name", count (units _attackerGroup),
		_defender get "name", count (units _defenderGroup)
	];

	[_attacker] call TACT_fnc_syncBack;
	[_defender] call TACT_fnc_syncBack;

	if (!isNull _attackerGroup) then { deleteGroup _attackerGroup };
	if (!isNull _defenderGroup) then { deleteGroup _defenderGroup };

	_attacker set ["inBattle", false];
	_defender set ["inBattle", false];

	false
};

// 6. Marching orders. Each group is sent toward its own strategic destination
// rather than at the enemy - the block clock, not a tactical rule, is what
// makes standing still expensive. An army with no standing order holds at the
// anchor.
{
	_x params ["_army", "_group"];

	private _order = _army getOrDefault ["pendingOrder", createHashMap];
	private _destination = if (count _order > 0) then {
		_order getOrDefault ["destination", _anchor]
	} else {
		_anchor
	};

	_group setFormation "COLUMN";
	_group setBehaviour "AWARE";
	_group setCombatMode "RED";
	_group move _destination;
} forEach [[_attacker, _attackerGroup], [_defender, _defenderGroup]];

// 7. Draw the boundary the engagement actually enforces.
[_anchor, true, _radius] call TACT_fnc_drawBoundary;

// 8. If one of these armies is the player's, he leads it. After the marching
// orders, so the group already has somewhere to be when its new leader
// arrives, and after the deployment check, so a failed engagement never drops
// him into a group about to be abandoned.
[_engagement] call TACT_fnc_dropIn;

// The turn loop owns the hint during resolution and refreshes it twice a
// second, so the report is handed to it rather than hinted over the top of it.
TACT_lastBattleReport = format [
	"CONTACT - %1 has engaged %2.",
	_attacker get "name",
	_defender get "name"
];
systemChat TACT_lastBattleReport;

true
