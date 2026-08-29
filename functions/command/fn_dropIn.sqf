/*
	Function: TACT_fnc_dropIn

	Description:
		Puts the player at the head of their own army's deployed group when a
		battle opens, and turns on the map's command mode.

		Section 5 says execution is watched, always. Watching a battle from the
		map is watching it from outside; leading the group that is fighting it
		is the same information with a hand on it. This is the working slice of
		3.12 that the map command interface needs to exist at all: the stock
		F-key commanding UI drives a real Arma group whose leader is the
		player, so unless the player actually leads the deployed group there is
		nothing for F1 to address.

		Only the player's own faction drops in. An engagement between two AI
		armies still runs watched from the map, exactly as before, and the
		command layer never comes up.

		The commander joins the group but never the roster. TACT_fnc_combatants
		is what keeps him out of the army's strength and centre of mass; see
		its header for why that matters.

	Parameters:
		0: HASHMAP - engagement record, already deployed

	Returns:
		BOOL - true if the player took command of a side.
*/

params [
	["_engagement", createHashMap, [createHashMap]]
];

if (isNull player) exitWith { false };

private _sides = [
	[_engagement get "attacker", _engagement get "attackerGroup"],
	[_engagement get "defender", _engagement get "defenderGroup"]
];

private _army = createHashMap;
private _group = grpNull;

{
	_x params ["_candidateArmy", "_candidateGroup"];

	if ((_candidateArmy getOrDefault ["faction", ""]) == "player") exitWith {
		_army = _candidateArmy;
		_group = _candidateGroup;
	};
} forEach _sides;

if (count _army == 0 || {isNull _group}) exitWith {
	diag_log "TACT Command: neither side is the player's, no drop-in.";
	false
};

private _combatants = [_group] call TACT_fnc_combatants;

if (count _combatants == 0) exitWith {
	diag_log "TACT Command: the player's army put nobody on the ground, no drop-in.";
	false
};

// ------------------------------------------------------------------------ //
// 1. GET THERE                                                              //
// ------------------------------------------------------------------------ //
// The avatar is wherever the strategic map left it, which is nowhere near the
// engagement. Placed on the first combatant rather than on the anchor: the
// anchor is the middle of the field, which is the one place a commander should
// not arrive standing up.
private _anchorUnit = _combatants select 0;
private _previousGroup = group player;

player setPosATL (getPosATL _anchorUnit);

// ------------------------------------------------------------------------ //
// 2. TAKE COMMAND                                                           //
// ------------------------------------------------------------------------ //
[player] joinSilent _group;
_group selectLeader player;

// The group the avatar came from is left empty. It was created with
// deleteWhenEmpty set, so it clears itself, but an editor-placed group would
// not - hence the explicit sweep.
if (!isNull _previousGroup && {_previousGroup != _group} && {count (units _previousGroup) == 0}) then {
	deleteGroup _previousGroup;
};

// ------------------------------------------------------------------------ //
// 3. RIDE WITH THEM                                                         //
// ------------------------------------------------------------------------ //
// Deployment mounts the whole roster, so the group is about to drive off. A
// commander left standing at the deployment point would watch his own army
// leave. Takes a seat if there is one and stays on foot if there is not.
private _ride = vehicle _anchorUnit;

if (_ride != _anchorUnit && {alive _ride} && {(_ride emptyPositions "Cargo") > 0}) then {
	player moveInCargo _ride;
};

// ------------------------------------------------------------------------ //
// 4. OPEN COMMAND MODE                                                      //
// ------------------------------------------------------------------------ //
TACT_commandActive    = true;
TACT_commandSelection = [];
TACT_commandArmyId    = _army get "id";

// Stacked routes are walked by the executor, not by the engine.
call TACT_fnc_runRoutes;

diag_log format [
	"TACT Command: player has taken command of %1 (%2 combatants).",
	_army get "name",
	count _combatants
];

systemChat format [
	"You have command of %1. Open the map to give orders; close it for the squad bar.",
	_army get "name"
];

true
