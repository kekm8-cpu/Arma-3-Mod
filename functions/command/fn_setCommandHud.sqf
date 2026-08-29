/*
	Function: TACT_fnc_setCommandHud

	Description:
		Hides or restores the stock interface that the map's command mode
		replaces: the squad bar, the commanding menu, and the engine's own
		friendly icons on the map itself.

		The squad bar and the commanding menu are how the player orders units
		with the map closed. With the map open they are the wrong interface for
		the same job - the orders are being given on the map now - and two
		command surfaces on screen at once is two places to look for the same
		answer. So they go away for exactly as long as the map is up and the
		player is commanding.

		The engine's friendly icons are the same duplication drawn on the map
		rather than beside it. Draw handlers render after the map's own
		content, so a command icon does not replace the stock one under it - it
		sits on top of a smaller icon that is still there, still rotating to
		the unit's facing, and still drawing every man in a vehicle separately.
		That last one defeats the point of TACT_fnc_commandEntities: the
		command layer emits one icon for a truck carrying eight men and the
		engine draws the other eight underneath it.

		Only the friendly indicators go. Enemies stay on, because the command
		layer draws nothing hostile at all - turning them off would leave the
		battle map showing your own units and empty terrain, which is a
		fog-of-war decision and not a rendering one. Mines and tactical pings
		are neither drawn by this layer nor duplicated by it.

		This is not something a mission can do through difficulty settings.
		`mapContent` and friends live in CfgDifficultyPresets, which is the
		server's config or the player's profile; description.ext's
		DifficultyOverride does not reach them. disableMapIndicators is a
		command, which is also what makes it switchable per mode rather than
		per mission - the same property the squad bar needs.

		Hidden and restored from one place, because every path out of command
		mode - closing the map, the battle ending, the player being withdrawn -
		has to leave the bar switched back on, and a HUD element that stays off
		is not something the player can fix themselves.

		showHUD takes its elements positionally: 5 is the commanding menu and 6
		is the group bar. The others are passed true rather than left out
		because the command takes the whole set at once. disableMapIndicators
		takes its four the same way: friendly, enemy, mines, pings.

		Idempotent. Called every frame the map is open, so it does nothing
		unless the state it wants differs from the state it set.

	Parameters:
		0: BOOL - true to hide the commanding UI, false to restore it

	Returns:
		BOOL - true if the HUD state changed.
*/

params [
	["_hide", false, [true]]
];

if (isNil "TACT_commandHudHidden") then { TACT_commandHudHidden = false };

if (_hide isEqualTo TACT_commandHudHidden) exitWith { false };

if (_hide) then {
	showHUD [true, true, true, true, true, false, false, true];
	disableMapIndicators [true, false, false, false];
} else {
	showHUD [true, true, true, true, true, true, true, true];
	disableMapIndicators [false, false, false, false];
};

TACT_commandHudHidden = _hide;

true
