/*
	Function: STRAT_fnc_drawItems

	Description:
		Renders a draw list onto a map control. The one renderer section 11
		asks for: the campaign layer and the battle command layer both come
		through here, so a strategic order arrow and a tactical route arrow
		cannot be drawn by two different laws.

		Every item is POSITIONED through one metres-per-icon-unit figure,
		resolved once for the whole pass. That is what makes an entity and its
		adornments a single object rather than several icons that agree by
		coincidence: there is only one anchor and one placement factor to pick
		up, so a label, a ring and an order arrow cannot drift off the icon
		they belong to at any zoom.

		Every item is SIZED by turning that same figure into a fraction of the
		screen and handing it to drawIcon, because drawIcon's width, height and
		text size are screen space rather than world metres. Both spaces are
		driven by the one icon-unit figure, so they agree by construction: an
		icon drawn at 0.85 units and a hit radius of 0.60 units stay in that
		proportion under every scaling mode, and the drawn and the clickable
		cannot come apart.

		Which is also why no scaling mode appears in this function. Mode 0, 1
		and 2 differ only in what STRAT_fnc_mapUnitMetres returns; the renderer
		divides by the measured span and draws, and would not behave any
		differently if a fourth mode arrived.

		Anything with a real extent on the ground - the boundary circle, where
		an order arrow points, how far a shaft stands off an icon's edge - stays
		in world metres and goes on scaling with the terrain, because those are
		distances and not symbols.

		Runs inside a Draw event handler, so it must not sleep, spawn, or
		mutate state.

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

// One icon unit as a fraction of the screen's width, right now. This is where
// the three scaling modes actually become visible: under mode 0 it is the
// constant STRAT_drawIconScreenSize, under mode 1 it falls as the player zooms
// out, and under mode 2 it is the first until the clamp bites and the second
// after. The renderer does not know which - it divides, and the mode is
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

			// SIZE is icon units -> screen fraction -> drawIcon argument.
			// POSITION went through _metresPerUnit above. That split is the
			// whole of the scaling law and it is not a compromise: the two
			// arguments live in two different spaces, and this is the one
			// place that knows it.
			//
			// drawIcon's width, height and text size are screen space. They
			// were once multiplied by _metresPerUnit on the assumption they
			// were world metres, which is what made an icon grow as the player
			// zoomed out - the factor that was supposed to cancel the zoom
			// compounded it instead.
			//
			// The two Arg scales are pure engine calibration: what number
			// drawIcon wants for a given fraction of the screen. They carry no
			// policy, which is why the scaling mode does not appear here. Two
			// of them rather than one because width/height and text size do not
			// share a base - a label is 0.30 icon units against an icon's 0.85
			// by the constants, and those two only come out in that proportion
			// on screen if each is converted through its own figure.
			_map drawIcon [
				_item get "texture",
				_colour,
				_pos,
				_w * _screenPerUnit * STRAT_drawIconArgScale,
				_h * _screenPerUnit * STRAT_drawIconArgScale,
				0,
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

				// The shaft starts at the icon's edge, not at its centre. An
				// arrow drawn from the centre spends its first stretch
				// underneath the icon it belongs to, and at low zoom that is
				// most of a short order.
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
		// unreachable case in a switch is inert - it cannot be entered, so it
		// cannot surprise anyone or drift - and routes return as soon as
		// group-level command has waypoint chains to draw. That is a different
		// case from a conditional inside a live shape, which changes how that
		// shape behaves for every caller and was removed with the held post.
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
