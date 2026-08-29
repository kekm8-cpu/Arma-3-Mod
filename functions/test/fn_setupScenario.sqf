/*
	Function: TEST_fnc_setupScenario

	Description:
		Builds a named starting state: clears the strategic map and spawns the
		armies the scenario names. Scenarios are defined in `TEST_scenarios` in
		init.sqf, which is the one place to edit to change what a session
		starts with.

		This exists because "what is on the map at boot" is a test question,
		not a campaign one. Until the campaign has an actual opening state,
		hard-coding two armies into init.sqf makes every experiment a code
		edit; naming the states makes it a one-word change.

		The scenarios that ship:

		  sandbox  - one player army and nothing hostile anywhere. The
		             strategic layer with the battle layer taken out of it, for
		             working on orders, routes and the block clock without a
		             fight interrupting. No hidden enemy is needed to hold it
		             up: TACT_fnc_detectContact pairs armies off against each
		             other and finds nothing to pair, and STRAT_fnc_resolveTurn
		             marches a single army perfectly well.
		  skirmish - the player army and a cartel patrol, out of contact at
		             the start. Battle happens if the player marches into it.
		  contact  - the same two inside TACT_contactRadius, so the first
		             committed block opens a battle immediately.

		A scenario only owns armies. Locations are campaign data and are seeded
		by init.sqf whichever scenario is running.

	Parameters:
		0: STRING - scenario name, a key of TEST_scenarios

	Returns:
		BOOL - true if the scenario was built.
*/

params [
	["_scenario", "", [""]]
];

if (isNil "TEST_scenarios" || {!(_scenario in TEST_scenarios)}) exitWith {
	diag_log format [
		"TEST Harness: unknown scenario '%1'. Known: %2.",
		_scenario,
		if (isNil "TEST_scenarios") then {"none defined"} else {(keys TEST_scenarios) joinString ", "}
	];
	false
};

if (!([] call TEST_fnc_clearArmies)) exitWith { false };

{
	[_x] call TEST_fnc_buildArmy;
} forEach (TEST_scenarios get _scenario);

// ------------------------------------------------------------------------ //
// THE AVATAR'S SIDE                                                         //
// ------------------------------------------------------------------------ //
// mission.sqm starts the player on WEST, which section 8 gives to the cartel
// and its NATO backer. Left alone, the player's own mercenaries deploy on
// INDEPENDENT and read their commander as a valid target - which turns even
// the sandbox, where nothing hostile is spawned at all, into something that
// shoots at you.
//
// Rejoining the avatar to the commanding faction's side is the smallest fix
// that holds, and it is done here rather than in mission.sqm so it travels
// with the harness and comes out with it. Set TEST_alignPlayerSide to false in
// init.sqf to leave the avatar where the editor put it.
if (!isNil "TEST_alignPlayerSide" && {TEST_alignPlayerSide} && {!isNull player}) then {
	private _commandSide = "player" call STRAT_fnc_factionSide;

	if (side (group player) != _commandSide) then {
		private _oldGroup = group player;
		[player] joinSilent (createGroup [_commandSide, true]);

		if (!isNull _oldGroup && {count (units _oldGroup) == 0}) then { deleteGroup _oldGroup };

		diag_log format ["TEST Harness: player avatar moved to %1 to match the commanding faction.", _commandSide];
	};
};

private _names = activeArmies apply {_x get "name"};

diag_log format ["TEST Harness: scenario '%1' built - %2.", _scenario, _names joinString ", "];
systemChat format ["TEST scenario '%1': %2.", _scenario, if (count _names == 0) then {"empty map"} else {_names joinString ", "}];

true
