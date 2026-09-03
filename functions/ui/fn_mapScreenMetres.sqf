/*
	Function: STRAT_fnc_mapScreenMetres

	Description:
		Returns how many world metres the map control currently spans across the
		width of the screen. The raw measurement the whole scaling law is built
		on, and the only place it is taken.

		Separate from STRAT_fnc_mapUnitMetres because two questions need it:
		that one asks how many metres an icon unit is, which is policy and has
		three answers; STRAT_fnc_drawItems needs the raw figure, because
		drawIcon's size arguments are screen space and converting a world size
		into a screen fraction means dividing by exactly this.

		MEASURED, not read off a config. A marker's rendered extent cannot be
		queried and `ctrlMapScale`'s number means nothing on its own, but map
		screen space runs 0..1 across the control - so two points a known screen
		distance apart give metres-per-screen exactly, at the current zoom.

		Cheap enough to call twice a pass: two ctrlMapScreenToWorld calls and a
		square root.

	Parameters:
		0: CONTROL - the map control (display 12, control 51)

	Returns:
		NUMBER - world metres across the screen's width, or 0 if the control
		         cannot be measured.
*/

params [
	["_map", controlNull, [controlNull]]
];

if (isNull _map) exitWith { 0 };

// Sampled across a fifth of the screen rather than a hair's width: a short
// baseline would put the whole scale at the mercy of float noise in the
// projection.
private _sample = 0.2;

private _a = _map ctrlMapScreenToWorld [0.4, 0.5];
private _b = _map ctrlMapScreenToWorld [0.4 + _sample, 0.5];

if (count _a < 2 || {count _b < 2}) exitWith { 0 };

private _dx = (_b select 0) - (_a select 0);
private _dy = (_b select 1) - (_a select 1);

private _metresPerScreen = (sqrt ((_dx * _dx) + (_dy * _dy))) / _sample;

// A degenerate control (zero width, not yet laid out) measures as nothing.
// Returning 0 tells the caller to skip the pass rather than draw everything on
// top of itself at the origin.
if (_metresPerScreen <= 0) exitWith { 0 };

_metresPerScreen
