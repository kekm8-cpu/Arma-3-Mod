/*
	Function: STRAT_fnc_mapUnitMetres

	Description:
		Returns how many world metres one *icon unit* currently covers on the
		given map control. Everything the campaign layer draws is sized and
		positioned in icon units, and this is the single conversion between
		that space and the world coordinates the draw commands take.

		Section 11's problem is that a marker's rendered extent cannot be
		queried - `getMarkerSize` returns the multiplier that was set, not an
		extent, and the base dimensions sit in `CfgMarkers` behind an engine
		constant. This sidesteps it rather than fitting it: map screen space
		runs 0..1 across the control, so two points a known screen distance
		apart give metres-per-screen-unit exactly, at whatever zoom the player
		is at right now. Nothing here depends on knowing what `ctrlMapScale`'s
		number means.

		One icon unit is STRAT_drawIconScreenSize of the screen's width, so an
		icon holds a constant size on screen as the player zooms. That is a
		choice, not a law: multiplying by nothing and returning a fixed metre
		figure instead would make icons scale with zoom the way markers do, and
		it is a one-line change here because every element of every group reads
		its placement from this one call.

		WHAT THIS IS FOR, since it no longer covers everything it once did.
		This is the WORLD-SPACE conversion: distances and positions on the
		ground. Hit radii, label offsets, ring radii, arrow origins and
		arrowhead barbs. It is not what sizes an icon - drawIcon's width,
		height and text size are screen space, and STRAT_fnc_drawItems converts
		those through STRAT_drawIconUiScale and STRAT_drawTextUiScale instead.
		Feeding this figure to them is what made icons grow as the player
		zoomed out; the reasoning is in init.sqf beside those two constants.

		The split does not put the drawn and the clickable at risk, which is
		the thing this function exists to protect. Both sides still start from
		the same icon-unit numbers and both still come out as a fixed fraction
		of the screen - a hit radius of 0.60 units is 0.60 x
		STRAT_drawIconScreenSize of screen width at every zoom, exactly as the
		icon drawn at 0.85 units is. What differs is only which arithmetic
		reaches the engine.

		Both the renderer and the click hit-test call this. If they computed
		the conversion separately they would drift, and the drift is invisible
		until a player clicks something that is not where it was drawn.

	Parameters:
		0: CONTROL - the map control (display 12, control 51)

	Returns:
		NUMBER - world metres per icon unit, or 0 if the control cannot be
		         measured.
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
// Returning 0 tells the caller to skip the pass rather than draw everything
// on top of itself at the origin.
if (_metresPerScreen <= 0) exitWith { 0 };

_metresPerScreen * STRAT_drawIconScreenSize
