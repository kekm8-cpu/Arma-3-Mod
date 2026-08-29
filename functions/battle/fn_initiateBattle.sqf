/*
	Function: TACT_fnc_initiateBattle

	Description:
		Opens a battle from an engagement record (section 9, stage 7): places
		both rosters, gives each group its marching orders, and draws the
		boundary.

		The armies stay in `activeArmies` and are flagged `inBattle` instead of
		being pulled out of it. Strategic resolution skips them while the flag
		is up, and the return to the strategic map is then just clearing it -
		nothing has to remember to put them back.

		Deployment still converges both groups on the anchor. Placing each army
		at its own boundary edge facing its destination bearing is part of the
		deployment split and is not done here yet.

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

// 2. Approach roads into the anchor, used to line the vehicles up.
private _attackerRoad = [_attacker get "location", _anchor] call STRAT_fnc_calculateRoadPath;
private _defenderRoad = [_defender get "location", _anchor] call STRAT_fnc_calculateRoadPath;

// 3. Physical deployment: vehicles first, then infantry mounted into them.
[_attacker, _attackerRoad] call TACT_fnc_deployVehicles;
[_defender, _defenderRoad] call TACT_fnc_deployVehicles;

private _attackerGroup = [_attacker] call TACT_fnc_deployMen;
private _defenderGroup = [_defender] call TACT_fnc_deployMen;

_engagement set ["attackerGroup", _attackerGroup];
_engagement set ["defenderGroup", _defenderGroup];

// 4. Deployment can legitimately produce nothing - fn_deployMen needs at least
// one vehicle, so an infantry-only army lands no units. A side that cannot
// field anybody must not be counted as annihilated, so the engagement is
// abandoned and both rosters are put back untouched.
if (count ([_attackerGroup] call TACT_fnc_combatants) == 0
	|| {count ([_defenderGroup] call TACT_fnc_combatants) == 0}) exitWith {
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

// 5. Marching orders. Each group is sent toward its own strategic destination,
// not at the enemy: the reason to advance is that there is somewhere to be, and
// the block clock is what makes standing still expensive. An army with no
// standing order has nowhere to be and holds at the anchor.
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

// 6. Draw the boundary the engagement actually enforces.
[_anchor, true, _radius] call TACT_fnc_drawBoundary;

// 7. If one of these armies is the player's, he leads it. Done after the
// marching orders so the group already has somewhere to be when its new leader
// arrives, and after the deployment check so a failed engagement never drops
// him into a group that is about to be abandoned.
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
