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
		its figure from this call. STRAT_drawIconScaleMode picks between:

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

		  2  SPLIT. Mode 1 while the map shows less than
		     STRAT_drawIconClampScreenMetres across, mode 0 at that width and
		     beyond. Terrain-accurate at the zooms a fight is commanded at,
		     where collision is what ruins the map, and a constant legible size
		     once the player pulls back to survey, where vanishing is. Both
		     behaviours with the crossover where he puts it, and the swap is a
		     step upward rather than a blend - mode 1 is half of mode 0 there by
		     construction, so icons double as he passes it.

		The three are one expression with one term differing, which is the
		point. There is no per-mode branch anywhere else in the layer.

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

		ONE SWITCH FOR BOTH LAYERS, which is a caveat and not a feature. The
		strategic map reads this too, and its zoom range is the whole island
		rather than a battle's 1500 metres. At Tanoa's full extent a
		mode 1 army icon is a couple of pixels. If the tactical map settles on
		1 or 2 and the campaign map wants 0, this is where that split goes -
		the mode would be chosen from TACT_commandActive here rather than read
		from the global, and nothing else in the layer would change.

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

	// Split: mode 1 while zoomed in, mode 0 once pulled back. The threshold is
	// compared against the raw span rather than against a converted cap,
	// because the question it asks is about the ZOOM - how much ground is on
	// screen - and not about how big an icon came out.
	//
	// A conditional and not a min or a max, because the swap is a step. Mode 1
	// is half of mode 0 at the crossover by construction, so the two do not
	// meet there and no smallest-of expression would land on this behaviour:
	// icons double as the player passes 800 metres, which is intended. Pulling
	// back is the moment they stop describing ground and start being things to
	// find and click, and reading as a different thing is the point.
	case 2: {
		if (_metresPerScreen < STRAT_drawIconClampScreenMetres) then {
			_metresPerUnit = STRAT_drawIconWorldMetres;
		};

		// At the threshold and beyond, the base figure stands untouched and
		// mode 2 is mode 0.
	};

	// Mode 0, and anything unrecognised, falls through on the base figure. An
	// unknown mode drawing a working map is the right failure: the map is how
	// this is being tested, and a typo in the switch should not take it away.
};

_metresPerUnit
