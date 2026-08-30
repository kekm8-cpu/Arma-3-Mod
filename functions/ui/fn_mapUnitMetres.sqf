/*
	Function: STRAT_fnc_mapUnitMetres

	Description:
		Returns how many world metres one *icon unit* currently covers on the
		given map control. Everything the campaign layer draws is sized and
		placed in icon units, and this is the single conversion between that
		space and the world coordinates the draw commands take.

		THIS IS THE SCALING MODE SWITCH. It is the one place that decides how
		icons behave as the player zooms, and it is the only place that needs
		to, because every element of every group - hit radius, label offset,
		ring radius, arrow origin, arrowhead barb, and the icon itself - reads
		its figure from this call.

		STRAT_drawIconScaleMode is SETTLED AT 2, arrived at by playing all
		three. The other two are kept because they cost nothing to leave in a
		switch that has to exist anyway, and because a later change of mind
		wants the reasoning as much as the code. It picks between:

		  0  SCREEN-FIXED. One icon unit is STRAT_drawIconScreenSize of the
		     screen's width, whatever the zoom. An icon holds a constant size
		     on screen and a constant click area with it, so a unit is as easy
		     to hit zoomed out as zoomed in. Its failure is collision: the
		     world separation between two men shrinks as the player zooms out
		     while their icons do not, so a squad eventually stacks into one
		     unclickable pile.

		  1  WORLD-FIXED. One icon unit is STRAT_drawIconWorldMetres, full
		     stop. Icons are pinned to the terrain like markers, so they
		     overlap exactly as much as the men themselves do and never more,
		     at any zoom. Its failure is the opposite one: zoom out far enough
		     and an icon is a pixel.

		  2  CLAMPED. Mode 0 until the map is showing more than
		     STRAT_drawIconClampScreenMetres across, mode 1 beyond it. Constant
		     on screen through the zoom range the player works in, and capped
		     once he is far enough out that collision, rather than legibility,
		     is the thing to protect against. Both behaviours with the
		     crossover where he puts it.

		The three are one expression with one term differing, which is the
		point. There is no per-mode branch anywhere else in the layer, so
		settling on one has changed no code but this function's default.

		WHAT THIS IS FOR, since it does not cover everything it once did. This
		is the WORLD-SPACE conversion: distances and positions on the ground.
		It is not what sizes an icon - drawIcon's width, height and text size
		are screen space, and STRAT_fnc_drawItems converts a world size into a
		screen fraction by dividing this figure by STRAT_fnc_mapScreenMetres.
		Handing this figure straight to drawIcon is what once made icons grow
		as the player zoomed out; the reasoning is in init.sqf beside
		STRAT_drawIconArgScale.

		The split does not put the drawn and the clickable at risk, which is
		the thing this function exists to protect. Both sides still read this
		one figure, so they move together in every mode: a hit radius of 0.60
		units and an icon of 0.85 units are in that proportion at every zoom
		under 0, under 1 and under 2 alike, because neither one knows which
		mode is running.

		Both the renderer and the click hit-test call this. If they computed
		the conversion separately they would drift, and the drift is invisible
		until a player clicks something that is not where it was drawn.

		ONE SWITCH FOR BOTH LAYERS, which is the one caveat left standing now
		that the tactical side is closed. The strategic map reads this too, and
		its zoom range is the whole island rather than a battle's 1500 metres.
		Mode 2 caps an icon at STRAT_drawIconClampScreenMetres x
		STRAT_drawIconScreenSize metres per unit - 24 with the current figures -
		so at Tanoa's full extent an army icon is a few pixels rather than the
		constant size the campaign map probably wants.

		It is deliberately left alone rather than fixed blind: the strategic map
		has not been looked at under mode 2, and guessing that it needs mode 0
		is the same kind of guess that made drawIcon's arguments world metres for
		a build and a half. When it is looked at, this is where the split goes -
		the mode chosen from TACT_commandActive here rather than read from the
		global - and nothing else in the layer changes.

	Parameters:
		0: CONTROL - the map control (display 12, control 51)

	Returns:
		NUMBER - world metres per icon unit, or 0 if the control cannot be
		         measured.
*/

params [
	["_map", controlNull, [controlNull]]
];

private _metresPerScreen = [_map] call STRAT_fnc_mapScreenMetres;

if (_metresPerScreen <= 0) exitWith { 0 };

// Mode 0's figure, and the base every mode starts from. Mode 1 replaces it and
// mode 2 caps it, so the screen-fixed law is what the other two are stated
// against rather than three unrelated formulas.
private _metresPerUnit = _metresPerScreen * STRAT_drawIconScreenSize;

private _mode = if (isNil "STRAT_drawIconScaleMode") then { 0 } else { STRAT_drawIconScaleMode };

switch (_mode) do {

	// World-fixed: the measurement is thrown away entirely. Kept as a switch
	// rather than an early return so all three modes read side by side.
	case 1: {
		_metresPerUnit = STRAT_drawIconWorldMetres;
	};

	// Clamped. The threshold is stated in metres across the SCREEN because
	// that is the number the player can read off the map and reason about -
	// "stop growing once I can see the whole battle" - so it is converted into
	// a cap on metres per icon unit here rather than being stored as one.
	//
	// `min` and not a conditional: below the threshold the measured figure is
	// already the smaller of the two, so the same expression gives mode 0's
	// behaviour without asking which side of the crossover it is on.
	case 2: {
		_metresPerUnit = _metresPerUnit min
			(STRAT_drawIconClampScreenMetres * STRAT_drawIconScreenSize);
	};

	// Mode 0, and anything unrecognised, falls through on the base figure. An
	// unknown mode drawing a working map is the right failure: the map is how
	// this is being tested, and a typo in the switch should not take it away.
};

_metresPerUnit
