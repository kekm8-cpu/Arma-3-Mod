/*
	Function: STRAT_fnc_drawCampaignLayer

	Description:
		Renders the campaign draw list onto the map control (section 11). This
		is the body of the Draw event handler that STRAT_fnc_attachMapLayer
		installs, so it runs once per frame while the map is open and must not
		sleep, spawn, or mutate campaign state.

		Every item in the pass is scaled and positioned through one
		metres-per-icon-unit figure, resolved once here. That is what makes an
		army and its adornments a single object rather than several icons that
		agree by coincidence: they cannot pick up different scale factors,
		because there is only one to pick up.

		Armies and locations are drawn here and nowhere else. `getMarkerSize`
		cannot report a marker's rendered extent, so nothing can be aligned to
		a marker at arbitrary zoom, so anything that carries adornment is drawn
		in full by this pass.

		A failure to draw here is not a cosmetic fault - it is an empty
		strategic map - so the two ways this pass can produce nothing (a null
		control, an unmeasurable scale) exit rather than draw garbage, and the
		next frame tries again.

	Parameters:
		0: CONTROL - the map control, passed by the Draw event handler

	Returns:
		nothing
*/

// A UI event handler passes the control in `_this`, and whether that arrives
// bare or wrapped in a one-element array is not worth betting an empty
// strategic map on. Both shapes are accepted.
private _map = controlNull;

if (_this isEqualType controlNull) then {
	_map = _this;
} else {
	if (_this isEqualType [] && {count _this > 0} && {(_this select 0) isEqualType controlNull}) then {
		_map = _this select 0;
	};
};

if (isNull _map) exitWith {};

// One factor for the whole pass. Section 11's point is not that this
// particular scaling law is right, but that every element of every group
// shares it by construction.
private _metresPerUnit = [_map] call STRAT_fnc_mapUnitMetres;
if (_metresPerUnit <= 0) exitWith {};

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
		case "arrow": {
			private _to = _item get "toWorld";

			if (count _to >= 2) then {
				private _dx = (_to select 0) - (_pos select 0);
				private _dy = (_to select 1) - (_pos select 1);
				private _length = sqrt ((_dx * _dx) + (_dy * _dy));

				// Bearing in the engine's convention: 0 is north, clockwise.
				private _bearing = _dx atan2 _dy;

				// The shaft starts at the icon's edge, not at its centre. An
				// arrow drawn from the centre spends its first stretch
				// underneath the icon it belongs to, and at low zoom that is
				// most of a short order.
				private _edge = (_item get "fromEdge") * _metresPerUnit;

				// A destination closer than the icon's own edge has no arrow
				// to draw. The order is still legible: the army is on it.
				if (_length > _edge) then {
					private _from = [
						(_pos select 0) + (_edge * sin _bearing),
						(_pos select 1) + (_edge * cos _bearing),
						0
					];
					private _tip = [_to select 0, _to select 1, 0];

					_map drawLine [_from, _tip, _colour];

					// Two barbs swept back off the tip. Their length is in
					// icon units like everything else, so the head keeps its
					// proportions rather than becoming a speck or a fan.
					private _barb = STRAT_drawArrowHeadUnits * _metresPerUnit;

					{
						private _b = _bearing + 180 + _x;
						_map drawLine [
							_tip,
							[
								(_tip select 0) + (_barb * sin _b),
								(_tip select 1) + (_barb * cos _b),
								0
							],
							_colour
						];
					} forEach [-STRAT_drawArrowHeadDegrees, STRAT_drawArrowHeadDegrees];
				};
			};
		};
	};
} forEach (call STRAT_fnc_buildDrawList);
