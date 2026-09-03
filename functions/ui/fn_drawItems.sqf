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
		screen, because drawIcon's width, height and text size are SCREEN space
		rather than world metres. Both spaces are driven by the one icon-unit
		figure, so an icon at 0.85 units and a hit radius at 0.60 stay in
		proportion under every scaling mode.

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

// Draws a shaft between two world positions and a two-barb head at the far
// end. Shared by the single-leg "arrow" shape and the last leg of a
// "polyline", so a route's head and an order arrow's head are the same head.
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

			// SIZE is icon units -> screen fraction -> drawIcon argument, while
			// POSITION went through _metresPerUnit above. The two arguments
			// live in two different spaces and this is the one place that knows
			// it: multiplying the size by _metresPerUnit is what once made
			// icons GROW as the player zoomed out.
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
				_w * _art * _screenPerUnit * STRAT_drawIconArgScale,
				_h * _art * _screenPerUnit * STRAT_drawIconArgScale,
				_item get "direction",
				_item get "text",
				1,                                          // 1 = drop shadow
				(_item get "textSize") * _screenPerUnit * STRAT_drawTextArgScale,
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
		// A stacked route: the anchor's icon edge, then every waypoint in
		// order, with the head on the last leg. One item, because a route is
		// one adornment of one entity however many legs it happens to have.
		//
		// Currently emitted by nothing. Kept rather than deleted because an
		// unreachable case cannot be entered and so cannot drift, and routes
		// return with group waypoint chains.
		case "polyline": {
			private _points = _item get "points";

			if (count _points > 0) then {
				private _first = _points select 0;
				private _dx = (_first select 0) - (_pos select 0);
				private _dy = (_first select 1) - (_pos select 1);
				private _length = sqrt ((_dx * _dx) + (_dy * _dy));
				private _bearing = _dx atan2 _dy;
				private _edge = (_item get "fromEdge") * _metresPerUnit;

				// Start at the icon's edge when the first leg is long enough
				// to clear it, and at the anchor itself when it is not - a
				// route whose first waypoint is under the icon still has later
				// legs worth drawing.
				private _cursor = if (_length > _edge) then {
					[
						(_pos select 0) + (_edge * sin _bearing),
						(_pos select 1) + (_edge * cos _bearing),
						0
					]
				} else {
					[_pos select 0, _pos select 1, 0]
				};

				{
					private _next = [_x select 0, _x select 1, 0];
					_map drawLine [_cursor, _next, _colour];

					// Waypoint pips on every leg but the last, so a route
					// reads as a sequence of stops rather than one bent line.
					if (_forEachIndex < (count _points) - 1) then {
						private _pip = STRAT_drawWaypointPipUnits * _metresPerUnit;
						_map drawEllipse [_next, _pip, _pip, 0, _colour, ""];
					} else {
						[_map, _cursor, _next, _colour, _metresPerUnit] call _fnc_head;
					};

					_cursor = _next;
				} forEach _points;
			};
		};
	};
} forEach _list;
