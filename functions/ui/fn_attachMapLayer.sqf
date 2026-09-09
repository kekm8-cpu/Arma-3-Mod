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

		Six handlers, here together because they share one precondition and one
		owner:

		  Draw            the campaign layer, which picks its own list by mode
		  MouseButtonDown records where a press started, and eats the CTRL press
		                  so the map does not draw on itself
		  MouseButtonUp   turns a press that did not travel into a click
		  MouseButtonDblClick
		                  eats the double click so the map does not drop a marker
		  MouseMoving     records where the cursor is, for the keys that act on
		                  what is under it
		  KeyDown         on the map's DISPLAY rather than the control, because
		                  keys are delivered to displays; routes the key to
		                  TACT_fnc_onCommandKey while commanding and to nobody
		                  otherwise - and EATS SHIFT ITSELF while commanding,
		                  see below
		  KeyUp           the other half of eating SHIFT: where the mission
		                  learns the key was let go, since the engine is no
		                  longer told it was pressed

		Keys are handled here rather than in init.sqf's handler on the main
		display for the same reason the mouse is: they belong to the map, they
		are wanted only while it is open, and the cursor position they need is
		what the map control reports. Both keys - Backspace and Delete - are
		consumed only when they acted on a route, so their stock uses survive
		everywhere else.

		Mouse handling is split across down and up because the map's own panning
		is a click and drag: acting on the press would issue an order every time
		the player grabbed the map to move it, so a click is a release that
		landed close to where its press did. These handlers are also where CTRL
		and the RIGHT button come from - `onMapSingleClick` reports neither.
		Left converts its position to the world, because an order is given at a
		place on the ground; right passes the screen position straight through,
		because a menu opens at the cursor.

		THREE STOCK MAP GESTURES ARE TAKEN AWAY HERE WHILE COMMANDING, because
		they are built out of the clicks this layer needs: CTRL+drag draws a
		freehand line and CTRL builds a selection; a double click drops a
		marker and is also two selections of the same unit; and SHIFT+click
		places the player's personal waypoint where SHIFT+click appends a
		group waypoint.

		THE PERSONAL WAYPOINT IS STOPPED BY EATING THE SHIFT KEY, which is
		cruder than the other two and is the only thing that worked. It
		survived a consumed press, a consumed release, and true returned from
		the map click callback both as the onMapSingleClick command and as the
		MapSingleClick mission event handler - the documented override for the
		click's default action, which in play it is not. So while commanding,
		SHIFT's KeyDown on the map display is consumed and the engine never
		learns the key is down: a click with SHIFT held is, to the engine, a
		plain click. The mission tracks the key itself in
		TACT_commandShiftHeld, from the same KeyDown and its KeyUp, and the
		release handler reads that alongside the SHIFT the control reports, so
		the append still works whichever of the two the engine still tells us
		about. The flag is cleared when the map closes, in case the key was
		let go with the map already gone.

		The cost: SHIFT does nothing else on the map while commanding. It
		still does everything on the campaign map. Each gesture is consumed by
		the handler that sees it first, on the narrowest condition covering
		the clash, and nowhere else does this layer consume anything but the
		two route keys above.

		The stock squad bar is checked every frame rather than switched once, so
		command mode beginning or ending underneath an open map is handled by
		the same line as the map opening.

		HANDLER IDS ARE STORED ON THE CONTROL, so a re-attach removes its own
		predecessors by id rather than clearing every handler on the map - which
		would take the battle boundary's Draw handler with it. The key handler's
		id is stored there too, though the handler is on the display: a display
		has no variable space of its own, and the control is what this scope
		already keeps its ids on.

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
			["MouseButtonDblClick", "STRAT_mapDoubleEH"],
			["MouseMoving", "STRAT_mapMoveEH"]
		];

		{
			_x params ["_type", "_key"];

			private _existing = _map getVariable [_key, -1];
			if (_existing != -1) then {
				(findDisplay 12) displayRemoveEventHandler [_type, _existing];
			};
		} forEach [
			["KeyDown", "STRAT_mapKeyEH"],
			["KeyUp", "STRAT_mapKeyUpEH"]
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
		// campaign map. SHIFT is deliberately not here: consuming the press
		// did not stop the personal waypoint, and STRAT_fnc_onMapClick does.
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
					// SHIFT from either source: the control's own report, or
					// the mission's record of a key the engine was never told
					// about.
					private _shiftHeld = _shift || {!isNil "TACT_commandShiftHeld" && {TACT_commandShiftHeld}};

					switch (_button) do {
						case 0: { [_world, _ctrl, _shiftHeld] call TACT_fnc_onCommandClick };
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

		// Only remembered, never acted on, and never consumed: the cursor is
		// where the Delete key looks, and this is the same coordinate space the
		// press and release report in, so the dot a click would have resolved
		// is the dot the key resolves.
		private _moveId = _map ctrlAddEventHandler ["MouseMoving", {
			params ["_control", "_x", "_y"];
			_control setVariable ["STRAT_mapCursorAt", [_x, _y]];
			false
		}];
		_map setVariable ["STRAT_mapMoveEH", _moveId];

		// On the display, because that is where keys arrive. Routed only while
		// commanding, so the campaign map's keys are untouched, and consumed
		// only when TACT_fnc_onCommandKey says it acted - except SHIFT, which
		// is consumed outright while commanding so the engine cannot build its
		// personal-waypoint gesture out of it. See the header. Both SHIFTs:
		// DIK 42 is the left, 54 the right.
		private _keyId = (findDisplay 12) displayAddEventHandler ["KeyDown", {
			params ["_display", "_key"];

			private _commanding = !isNil "TACT_commandActive" && {TACT_commandActive};

			if (!_commanding) exitWith { false };

			if (_key in [42, 54]) exitWith {
				TACT_commandShiftHeld = true;
				true
			};

			[_key, _display displayCtrl 51] call TACT_fnc_onCommandKey
		}];
		_map setVariable ["STRAT_mapKeyEH", _keyId];

		// The release of SHIFT, whether or not its press was eaten: the flag
		// goes down on any release, so a SHIFT pressed before commanding began
		// cannot leave it stuck up. Not consumed - nothing is built out of a
		// key going up.
		private _keyUpId = (findDisplay 12) displayAddEventHandler ["KeyUp", {
			params ["_display", "_key"];

			if (_key in [42, 54]) then {
				TACT_commandShiftHeld = false;
			};

			false
		}];
		_map setVariable ["STRAT_mapKeyUpEH", _keyUpId];

		diag_log format ["STRAT Draw: map layer attached (draw %1, press %2, release %3, double %4, move %5, key %6).", _drawId, _pressId, _releaseId, _doubleId, _moveId, _keyId];

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
		TACT_commandShiftHeld = false;
	};
};

true
