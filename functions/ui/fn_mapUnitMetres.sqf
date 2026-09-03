/*
	Function: STRAT_fnc_mapUnitMetres

	Description:
		Returns how many world metres one *icon unit* currently covers on the
		given map control. Everything the campaign layer draws is sized and
		placed in icon units, and this is the single conversion between that
		space and the world coordinates the draw commands take.

		THIS IS THE SCALING MODE SWITCH, and the only place that branches on
		STRAT_drawIconScaleMode - every element of every group reads its figure
		from this one call. The three modes and why 2 is the default are
		manifest section 11; each is one expression with one term differing.

		WHAT THIS IS FOR: the WORLD-SPACE conversion, distances and positions on
		the ground. It is NOT what sizes an icon - drawIcon's width, height and
		text size are screen space, and STRAT_fnc_drawItems converts a world
		size into a screen fraction by dividing this by
		STRAT_fnc_mapScreenMetres. Handing this figure straight to drawIcon is
		what once made icons grow as the player zoomed out.

		That split does not risk the drawn and the clickable coming apart, which
		is what this function exists to protect: both sides read this one
		figure, so a hit radius of 0.60 units and an icon of 0.85 stay in
		proportion at every zoom under every mode.

		ONE SWITCH FOR BOTH LAYERS, which is a caveat rather than a decision:
		the strategic map's zoom range is the island, so under mode 2 an army
		icon at Tanoa's full extent sits at the cap. Left alone deliberately
		rather than fixed blind - when that map is looked at, the split goes
		here, with the mode chosen from TACT_commandActive rather than read from
		the global, and nothing else in the layer changes.

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
