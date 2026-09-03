/*
	Function: STRAT_fnc_attachMapLayer

	Description:
		Owns the campaign draw layer's attachment lifecycle.

		DISPLAY 12 DOES NOT EXIST WHILE THE MAP IS CLOSED, and a Draw handler
		attached to a null control fails silently and renders nothing - which,
		with armies drawn rather than marked, is an empty strategic map. So
		attachment is driven by the map opening and never by state changing.

		Called once at boot. It installs a single scope that owns the lifecycle
		for the rest of the mission: wait for the map to be open and its control
		built, attach, hold while it is open, go round again. Map open is
		observed directly rather than taken from a mission event handler,
		because what has to be true before attaching is that control 51 exists,
		and that is a frame or more behind the event.

		Four handlers, here together because they share one precondition and one
		owner:

		  Draw            the campaign layer, which picks its own list by mode
		  MouseButtonDown records where a press started, and eats the CTRL press
		                  so the map does not draw on itself
		  MouseButtonUp   turns a press that did not travel into a click
		  MouseButtonDblClick
		                  eats the double click so the map does not drop a marker

		Mouse handling is split across down and up because the map's own panning
		is a click and drag: acting on the press would issue an order every time
		the player grabbed the map to move it, so a click is a release that
		landed close to where its press did. These handlers are also where CTRL
		and the RIGHT button come from - `onMapSingleClick` reports neither.
		Left converts its position to the world, because an order is given at a
		place on the ground; right passes the screen position straight through,
		because a menu opens at the cursor.

		TWO STOCK MAP GESTURES ARE TAKEN AWAY WHILE COMMANDING, because they are
		built out of the clicks this layer needs: CTRL+drag draws a freehand
		line and CTRL builds a selection; a double click drops a marker and is
		also two selections of the same unit. Each is consumed by the handler
		that sees it first, on the narrowest condition covering the clash, and
		nowhere else does this layer consume anything. Both still work on the
		campaign map.

		The stock squad bar is checked every frame rather than switched once, so
		command mode beginning or ending underneath an open map is handled by
		the same line as the map opening.

		HANDLER IDS ARE STORED ON THE CONTROL, so a re-attach removes its own
		predecessors by id rather than clearing every handler on the map - which
		would take the battle boundary's Draw handler with it.

		Must be called from a scope that can spawn.

	Parameters:
		none

	Returns:
		BOOL - true if the lifecycle was started, false if it was already
		       running.
*/

if (!isNil "STRAT_mapLayerRunning" && {STRAT_mapLayerRunning}) exitWith {
	diag_log "STRAT Draw: campaign layer lifecycle is already running.";
	false
};

STRAT_mapLayerRunning = true;

[] spawn {
	while {true} do {

		// Both conditions matter. `visibleMap` alone can be true a frame or
		// two before the control exists, and a control alone says nothing
		// about whether the player is looking at it.
		waitUntil {
			visibleMap && {!isNull ((findDisplay 12) displayCtrl 51)}
		};

		private _map = (findDisplay 12) displayCtrl 51;

		// Never ctrlRemoveAllEventHandlers here: TACT_fnc_drawBoundary keeps
		// its own Draw handler on this same control.
		{
			_x params ["_type", "_key"];

			private _existing = _map getVariable [_key, -1];
			if (_existing != -1) then {
				_map ctrlRemoveEventHandler [_type, _existing];
			};
		} forEach [
			["Draw", "STRAT_campaignLayerEH"],
			["MouseButtonDown", "STRAT_mapPressEH"],
			["MouseButtonUp", "STRAT_mapReleaseEH"],
			["MouseButtonDblClick", "STRAT_mapDoubleEH"]
		];

		private _drawId = _map ctrlAddEventHandler ["Draw", {
			_this call STRAT_fnc_drawCampaignLayer;
		}];
		_map setVariable ["STRAT_campaignLayerEH", _drawId];

		// The press is only remembered, never acted on: the map pans by click
		// and drag.
		//
		// It is also where the map's own CTRL+drag FREEHAND DRAWING is taken
		// away - the engine reads the selection modifier as "start drawing a
		// line", so every unit added to a selection left a scribble behind it.
		// The line starts on the press, so returning true here means the engine
		// never begins one.
		//
		// ONLY with CTRL down and ONLY while commanding, which is the whole of
		// the overlap: a plain drag still pans, and drawing still works on the
		// campaign map.
		private _pressId = _map ctrlAddEventHandler ["MouseButtonDown", {
			params ["_control", "_button", "_x", "_y", "_shift", "_ctrl"];
			_control setVariable ["STRAT_mapPressAt", [_button, _x, _y]];

			private _commanding = !isNil "TACT_commandActive" && {TACT_commandActive};

			// Never unconditionally: consuming every press stops the map panning.
			_commanding && {_ctrl}
		}];
		_map setVariable ["STRAT_mapPressEH", _pressId];

		private _releaseId = _map ctrlAddEventHandler ["MouseButtonUp", {
			params ["_control", "_button", "_x", "_y", "_shift", "_ctrl"];

			private _press = _control getVariable ["STRAT_mapPressAt", []];
			_control setVariable ["STRAT_mapPressAt", nil];

			private _commanding = !isNil "TACT_commandActive" && {TACT_commandActive};

			// Command mode only, the button it started on, and only a release
			// that landed on its own press - anything further is a pan, and a
			// pan is not an order. The travel guard covers the right button
			// too, so the two buttons stay under one law.
			if (_commanding && {count _press == 3} && {(_press select 0) == _button}) then {
				private _travel = sqrt (
					(((_press select 1) - _x) ^ 2) + (((_press select 2) - _y) ^ 2)
				);

				if (_travel <= STRAT_mapClickSlop) then {
					private _world = _control ctrlMapScreenToWorld [_x, _y];

					// Two questions of the same selection: left changes or
					// orders it, right asks what can be done with it.
					//
					// Two coordinate spaces, deliberately: an order is given at
					// a place on the ground, so left converts to world; a menu
					// opens at the cursor, so right hands on the screen
					// coordinates ctrlSetPosition already takes.
					switch (_button) do {
						case 0: { [_world, _ctrl, _shift] call TACT_fnc_onCommandClick };
						case 1: { [[_x, _y]] call TACT_fnc_openContextMenu };
					};
				};
			};

			false
		}];
		_map setVariable ["STRAT_mapReleaseEH", _releaseId];

		// The other colliding stock gesture: a double left click opens the
		// insert-marker dialog, and on this map a double click is two
		// selections of the same unit.
		//
		// Consumed rather than answered - the two clicks underneath still
		// arrive as their own presses and releases and still select, so the
		// gesture degrades into what it should have been.
		//
		// Left button and commanding only, on the same terms as the CTRL press
		// above: markers still work on the campaign map.
		private _doubleId = _map ctrlAddEventHandler ["MouseButtonDblClick", {
			params ["_control", "_button"];

			private _commanding = !isNil "TACT_commandActive" && {TACT_commandActive};

			_commanding && {_button == 0}
		}];
		_map setVariable ["STRAT_mapDoubleEH", _doubleId];

		diag_log format ["STRAT Draw: map layer attached (draw %1, press %2, release %3, double %4).", _drawId, _pressId, _releaseId, _doubleId];

		// Hold here until the map closes, then go round and wait for the next
		// opening. Nothing is detached on close - the control's handlers and
		// variables go wherever the control goes.
		//
		// The squad bar is driven from inside the wait rather than switched
		// once on either side of it, so a battle starting or ending while the
		// map is already open is the same case as the map opening.
		waitUntil {
			private _commanding = !isNil "TACT_commandActive" && {TACT_commandActive};
			[_commanding] call TACT_fnc_setCommandHud;

			!visibleMap
		};

		// The map is closed: the stock commanding UI is the interface again,
		// whether or not a battle is still running. A context menu cannot
		// survive that - its controls live on the map's display.
		call TACT_fnc_closeContextMenu;
		[false] call TACT_fnc_setCommandHud;
	};
};

true
