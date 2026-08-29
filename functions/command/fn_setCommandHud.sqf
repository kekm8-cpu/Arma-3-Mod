/*
	Function: TACT_fnc_setCommandHud

	Description:
		Hides or restores the stock HUD elements that the map's command mode
		replaces.

		The squad bar and the commanding menu are how the player orders units
		with the map closed. With the map open they are the wrong interface for
		the same job - the orders are being given on the map now - and two
		command surfaces on screen at once is two places to look for the same
		answer. So they go away for exactly as long as the map is up and the
		player is commanding.

		Hidden and restored from one place, because every path out of command
		mode - closing the map, the battle ending, the player being withdrawn -
		has to leave the bar switched back on, and a HUD element that stays off
		is not something the player can fix themselves.

		showHUD takes its elements positionally: 5 is the commanding menu and 6
		is the group bar. The others are passed true rather than left out
		because the command takes the whole set at once.

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
} else {
	showHUD [true, true, true, true, true, true, true, true];
};

TACT_commandHudHidden = _hide;

true
