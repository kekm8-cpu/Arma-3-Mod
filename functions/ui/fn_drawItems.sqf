/*
	Function: STRAT_fnc_drawItems

	Description:
		Renders a draw list onto a map control. THE one renderer: the campaign
		layer and the battle command layer both come through here, so a
		strategic order arrow and a tactical route arrow cannot be drawn by two
		different laws.

		Every item is POSITIONED through one metres-per-icon-unit figure,
		resolved once for the whole pass, so a label, a ring and an order arrow
		cannot drift off the icon they belong to at any zoom.

		Every item is SIZED by turning that same figure into a fraction of the
		screen and then into PIXELS, because drawIcon's width, height and text
		size are screen space rather than world metres - and screen space to
		the engine is pixels, not fractions. Both spaces are driven by the one
		icon-unit figure, so an icon at 0.85 units and a hit radius at 0.60
		stay in proportion under every scaling mode and on every monitor.

		Which is why NO SCALING MODE APPEARS HERE. The modes differ only in what
		STRAT_fnc_mapUnitMetres returns; this divides by the measured span and
		draws, and would not behave differently if a fourth mode arrived.

		Anything with a real extent on the ground - the boundary circle, where
		an order arrow points, how far a shaft stands off an icon's edge - stays
		in world metres and goes on scaling with the terrain.

		Runs inside a Draw event handler, so it must not sleep, spawn, or mutate
		state.

	Parameters:
		0: CONTROL - the map control
		1: ARRAY   - draw items (see STRAT_fnc_buildDrawList for the item keys)

	Returns:
		nothing
*/

params [
	["_map", controlNull, [controlNull]],
	["_list", [], [[]]]
];

if (isNull _map || {count _list == 0}) exitWith {};

private _metresPerUnit = [_map] call STRAT_fnc_mapUnitMetres;
if (_metresPerUnit <= 0) exitWith {};

// The raw measurement as well as the icon-unit figure, because drawIcon's size
// arguments are screen space and the only way to turn a world size into a
// screen fraction is to divide by this. Read once for the whole pass, like the
// figure above, so every item is sized off one number.
private _metresPerScreen = [_map] call STRAT_fnc_mapScreenMetres;
if (_metresPerScreen <= 0) exitWith {};

// One icon unit as a fraction of the screen's width, right now. The renderer
// does not know which scaling mode produced it - it divides, and the mode is
// STRAT_fnc_mapUnitMetres's business.
private _screenPerUnit = _metresPerUnit / _metresPerScreen;

// The screen's width in pixels: what turns a fraction of the screen into the
// number drawIcon wants, and a metre into the pixels drawLine draws. Read
// once, so the two conversions below cannot disagree about the monitor.
private _screenPixels = (getResolution select 0) max 1;

// One icon unit in PIXELS, right now. drawIcon's size arguments are pixels -
// a fraction of the screen handed to them draws the same handful of pixels
// on every monitor, which is a different apparent size on each - so the
// fraction is multiplied out by the width in pixels before it goes anywhere
// near the engine. The one constant left on top is engine calibration.
private _pixelsPerUnit = _screenPerUnit * _screenPixels;

// One world metre per screen pixel, right now. drawLine draws one pixel wide
// and takes no width, so a wider line is several of them a pixel apart, and a
// pixel has to be known in metres to place them. The screen is measured
// across its width because that is the span _metresPerScreen was measured
// over.
private _metresPerPixel = _metresPerScreen / _screenPixels;

// Draws a line of a given width in pixels between two world positions: the
// one-pixel drawLine, repeated side by side across the width and centred on
// the line asked for. Width 1 is exactly one drawLine, so a shape that does
// not ask for a width draws as it always did.
private _fnc_line = {
	params ["_map", "_from", "_to", "_colour", "_width", "_metresPerPixel"];

	if (_width <= 1) exitWith {
		_map drawLine [_from, _to, _colour];
	};

	private _dx = (_to select 0) - (_from select 0);
	private _dy = (_to select 1) - (_from select 1);
	private _length = sqrt ((_dx * _dx) + (_dy * _dy));

	if (_length <= 0) exitWith {};

	// The unit perpendicular, so the copies step across the line and not
	// along it.
	private _px = -_dy / _length;
	private _py =  _dx / _length;

	for "_i" from 0 to (_width - 1) do {
		private _step = (_i - ((_width - 1) / 2)) * _metresPerPixel;

		_map drawLine [
			[(_from select 0) + (_px * _step), (_from select 1) + (_py * _step), 0],
			[(_to select 0)   + (_px * _step), (_to select 1)   + (_py * _step), 0],
			_colour
		];
	};
};

// Draws a two-barb head at the far end of a shaft between two world
// positions, for the "arrow" shape. A "polyline" carries no head: a route
// reads its direction from the icon it starts at, dot by dot.
private _fnc_head = {
	params ["_map", "_from", "_to", "_colour", "_metresPerUnit"];

	private _dx = (_to select 0) - (_from select 0);
	private _dy = (_to select 1) - (_from select 1);

	// Bearing in the engine's convention: 0 is north, clockwise.
	private _bearing = _dx atan2 _dy;
	private _barb = STRAT_drawArrowHeadUnits * _metresPerUnit;

	{
		private _b = _bearing + 180 + _x;
		_map drawLine [
			_to,
			[
				(_to select 0) + (_barb * sin _b),
				(_to select 1) + (_barb * cos _b),
				0
			],
			_colour
		];
	} forEach [-STRAT_drawArrowHeadDegrees, STRAT_drawArrowHeadDegrees];
};

{
	private _item   = _x;
	private _anchor = _item get "anchor";
	private _offset = _item get "offset";
	private _colour = _item get "colour";

	// Offsets are in icon units, so an adornment pinned to the icon's edge
	// stays on the edge at every zoom instead of sliding off it.
	private _pos = [
		(_anchor select 0) + ((_offset select 0) * _metresPerUnit),
		(_anchor select 1) + ((_offset select 1) * _metresPerUnit),
		0
	];

	switch (_item get "shape") do {

		// ---------------------------------------------------------------- //
		case "icon": {
			(_item get "size") params [["_w", 1, [0]], ["_h", 1, [0]]];

			// Compensation for artwork that does not fill its own texture. It
			// scales the BOX the texture is stretched into, so a small glyph in
			// a padded square comes out the size the item asked for. Applied
			// here and to nothing else: the item's `size` stays semantic, which
			// is what keeps the ring and the click area calibrated against it.
			private _art = _item get "artScale";

			// SIZE is icon units -> screen fraction -> pixels -> drawIcon
			// argument, while POSITION went through _metresPerUnit above. The
			// two arguments live in two different spaces and this is the one
			// place that knows it: multiplying the size by _metresPerUnit is
			// what once made icons GROW as the player zoomed out, and handing
			// it a screen fraction is what once made them a fifth of their size
			// on a 4K monitor.
			//
			// Rotation is the item's own, and 0 for everything that is not an
			// individual - a NATO box reads upright and an aggregate has no
			// single facing to show.
			//
			// The two Arg scales are pure engine calibration. Two of them
			// rather than one because width/height and text size do not share a
			// base, so each needs its own conversion to come out in the
			// proportion the constants ask for.
			_map drawIcon [
				_item get "texture",
				_colour,
				_pos,
				_w * _art * _pixelsPerUnit * STRAT_drawIconArgScale,
				_h * _art * _pixelsPerUnit * STRAT_drawIconArgScale,
				_item get "direction",
				_item get "text",
				1,                                          // 1 = drop shadow
				(_item get "textSize") * _pixelsPerUnit * STRAT_drawTextArgScale,
				"PuristaMedium",
				"center"
			];
		};

		// ---------------------------------------------------------------- //
		case "ellipse": {
			private _r = (_item get "radius") * _metresPerUnit;

			// No ctrlMapWorldToScreen guard. drawEllipse takes world
			// coordinates and clips itself; gating on the centre being on
			// screen drops the whole ring the moment the player pans past it.
			_map drawEllipse [_pos, _r, _r, 0, _colour, ""];
		};

		// ---------------------------------------------------------------- //
		// A single leg: from the anchor's icon edge to one world position.
		case "arrow": {
			private _to = _item get "toWorld";

			if (count _to >= 2) then {
				private _dx = (_to select 0) - (_pos select 0);
				private _dy = (_to select 1) - (_pos select 1);
				private _length = sqrt ((_dx * _dx) + (_dy * _dy));
				private _bearing = _dx atan2 _dy;

				// The shaft starts at the icon's EDGE, not its centre: an arrow
				// from the centre spends its first stretch underneath the icon
				// it belongs to, which at low zoom is most of a short order.
				private _edge = (_item get "fromEdge") * _metresPerUnit;

				// A destination closer than the icon's own edge has no arrow
				// to draw. The order is still legible: the entity is on it.
				if (_length > _edge) then {
					private _from = [
						(_pos select 0) + (_edge * sin _bearing),
						(_pos select 1) + (_edge * cos _bearing),
						0
					];
					private _tip = [_to select 0, _to select 1, 0];

					_map drawLine [_from, _tip, _colour];
					[_map, _from, _tip, _colour, _metresPerUnit] call _fnc_head;
				};
			};
		};

		// ---------------------------------------------------------------- //
		// A route: the legs from the anchor to the first point and from each
		// point to the next. LEGS ONLY - the points themselves are drawn by
		// whoever emitted this, as icon items in the same group, so that each
		// one can carry its own hit area. One item for the legs, because a
		// route is one adornment of one entity however many legs it has.
		//
		// EVERY LEG STOPS SHORT AT BOTH ENDS. The first starts `fromEdge` off
		// the anchor, so it does not run under the icon it belongs to; every
		// leg ends `toEdge` short of the point it runs to, and every leg after
		// the first starts `toEdge` past the point it runs from, so the line
		// reaches a dot without touching it. Both figures are icon units and
		// so hold on screen at every zoom, like the dot they clear.
		//
		// A leg with nothing left after both ends are trimmed is not drawn at
		// all: two waypoints on top of one another are two dots, not a
		// smear between them, and the legs either side still draw.
		//
		// Width is in pixels and goes through _fnc_line, which is the one
		// place that knows drawLine cannot be told a width.
		case "polyline": {
			private _points = _item get "points";
			private _clear  = (_item get "toEdge") * _metresPerUnit;
			private _width  = _item get "lineWidth";

			private _cursor = [_pos select 0, _pos select 1, 0];
			private _startClear = (_item get "fromEdge") * _metresPerUnit;

			{
				private _next = [_x select 0, _x select 1, 0];

				private _dx = (_next select 0) - (_cursor select 0);
				private _dy = (_next select 1) - (_cursor select 1);
				private _length = sqrt ((_dx * _dx) + (_dy * _dy));

				if (_length > _startClear + _clear) then {
					private _bearing = _dx atan2 _dy;

					[
						_map,
						[
							(_cursor select 0) + (_startClear * sin _bearing),
							(_cursor select 1) + (_startClear * cos _bearing),
							0
						],
						[
							(_next select 0) - (_clear * sin _bearing),
							(_next select 1) - (_clear * cos _bearing),
							0
						],
						_colour,
						_width,
						_metresPerPixel
					] call _fnc_line;
				};

				_cursor = _next;
				_startClear = _clear;
			} forEach _points;
		};
	};
} forEach _list;
