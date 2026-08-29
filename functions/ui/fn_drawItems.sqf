/*
	Function: STRAT_fnc_drawItems

	Description:
		Renders a draw list onto a map control. The one renderer section 11
		asks for: the campaign layer and the battle command layer both come
		through here, so a strategic order arrow and a tactical route arrow
		cannot be drawn by two different laws.

		Every item is scaled and positioned through one metres-per-icon-unit
		figure, resolved once for the whole pass. That is what makes an entity
		and its adornments a single object rather than several icons that agree
		by coincidence: there is only one scale factor to pick up.

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

			// drawIcon takes width, height and text size in world metres, so
			// feeding it icon units times the pass factor is the whole of the
			// scaling law.
			_map drawIcon [
				_item get "texture",
				_colour,
				_pos,
				_w * _metresPerUnit,
				_h * _metresPerUnit,
				0,
				_item get "text",
				1,                                          // 1 = drop shadow
				(_item get "textSize") * _metresPerUnit,
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
