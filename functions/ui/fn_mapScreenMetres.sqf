/*
	Function: STRAT_fnc_mapScreenMetres

	Description:
		Returns how many world metres the map control currently spans across
		the width of the screen. The raw measurement the whole scaling law is
		built on, and the only place it is taken (section 11).

		It lives on its own rather than inside STRAT_fnc_mapUnitMetres because
		two different questions need it and they need different answers from
		it. STRAT_fnc_mapUnitMetres asks "how many metres is one icon unit",
		which is a policy question and has three answers depending on
		STRAT_drawIconScaleMode. STRAT_fnc_drawItems additionally needs the raw
		figure, because drawIcon's size arguments are screen space: turning a
		world-metre size into a screen fraction means dividing by exactly this.

		Section 11's original problem was that a marker's rendered extent
		cannot be queried - `getMarkerSize` returns the multiplier that was
		set, not an extent, and the base dimensions sit in `CfgMarkers` behind
		an engine constant. This sidesteps it rather than fitting it: map
		screen space runs 0..1 across the control, so two points a known screen
		distance apart give metres-per-screen exactly, at whatever zoom the
		player is at right now. Nothing here depends on knowing what
		`ctrlMapScale`'s number means.

		Cheap enough to call twice a pass. It is two ctrlMapScreenToWorld calls
		and a square root, and the alternative - returning a pair and teaching
		every caller to unpack it - buys a few microseconds at the cost of the
		one clear question each function asks.

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
