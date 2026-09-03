/*
	Function: TACT_fnc_setCommandHud

	Description:
		Hides or restores the stock interface that the map's command mode
		replaces: the squad bar, the commanding menu, and the engine's own
		friendly icons on the map itself.

		Two command surfaces, never at once: the squad bar and commanding menu
		go away for exactly as long as the map is up and the player commanding.

		The engine's friendly map icons are the same duplication drawn ON the
		map. Draw handlers render AFTER the map's own content, so a command icon
		lands on top of the stock one rather than in place of it - at a
		different size, rotating to facing, and drawn once per man rather than
		once per entity, which is precisely the stacking
		TACT_fnc_commandEntities exists to collapse.

		Only the FRIENDLY indicators go. Enemies stay on because the command
		layer draws nothing hostile, so switching them off would be a
		fog-of-war decision rather than a rendering one.

		This has to be a scripting command rather than mission config:
		`mapContent` and its siblings are CfgDifficultyPresets options, which
		description.ext's DifficultyOverride does not reach. That is also what
		makes it switchable per mode rather than per mission.

		Hidden and restored from ONE place, because every path out of command
		mode has to leave the bar switched back on and an interface element left
		off is not something the player can fix.

		showHUD takes its elements positionally: 5 is the commanding menu, 6 the
		group bar; the rest are passed true because the command takes the whole
		set at once. disableMapIndicators takes its four the same way: friendly,
		enemy, mines, pings.

		Idempotent. Called every frame the map is open.

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
