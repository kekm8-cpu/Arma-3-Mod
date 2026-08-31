/*
	Function: STRAT_fnc_attachMapLayer

	Description:
		Owns the campaign draw layer's attachment lifecycle (section 11).

		Display 12 does not exist while the map is closed, and a Draw handler
		attached to a null control fails silently and renders nothing. Since
		armies are drawn rather than marked, that failure is not cosmetic - it
		is an empty strategic map - so attachment is driven by the map opening
		and never by anything in campaign state changing.

		Called once at boot. It installs a single scope that then owns the
		lifecycle for the rest of the mission: wait for the map to be open and
		its control built, attach, hold while it is open, and go round again on
		the next opening. Map open is observed directly rather than taken from
		a mission event handler, because the thing that actually has to be true
		before attaching is that control 51 exists, and that is a frame or more
		behind the event.

		Three things attach, and they are here together because they share one
		precondition - the map is open and its control exists - and one owner:

		  Draw            the campaign layer, which picks its own list by mode
		  MouseButtonDown records where a press started, and eats the CTRL press
		                  so the map does not draw on itself
		  MouseButtonUp   turns a press that did not travel into a click

		Mouse handling is split across down and up because the map's own
		panning is a click and drag. Acting on the press would fire an order
		every time the player grabbed the map to move it, so a click is a
		release that landed close to where its press did. The handlers are also
		where CTRL comes from: `onMapSingleClick` reports SHIFT and ALT and
		nothing else, and command-mode selection needs CTRL. CTRL is also the
		chord the map itself reads as "draw a freehand line", so the press
		handler consumes it while commanding - see there. That is the only
		event this layer ever consumes, and it consumes it on the narrowest
		condition that covers the clash. It is also where the
		RIGHT button comes from, which `onMapSingleClick` does not report at
		all. Both buttons go through the same press-and-travel test and then
		split: left selects or orders, right opens the context menu. The left
		button converts its position to the world, because an order is given
		at a place on the ground; the right button passes the screen position
		straight through, because a menu opens at the cursor and is made of
		controls positioned in that same space.

		While the map is open and the player is commanding, the stock squad bar
		is hidden. It is checked every frame rather than switched once, so
		command mode beginning or ending underneath an open map is handled by
		the same line as the map opening.

		Handler ids are stored on the control, so a re-attach removes its own
		predecessors by id rather than clearing every handler on the map -
		which would take the battle boundary's Draw handler with it. That
		covers both engine behaviours: if the display is destroyed on close the
		new control simply has no ids stored, and if it survives, the stale
		handlers are removed before the new ones go on.

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
			["MouseButtonUp", "STRAT_mapReleaseEH"]
		];

		private _drawId = _map ctrlAddEventHandler ["Draw", {
			_this call STRAT_fnc_drawCampaignLayer;
		}];
		_map setVariable ["STRAT_campaignLayerEH", _drawId];

		// The press is only remembered, never acted on: the map pans by click
		// and drag, and an order issued on the press would fire every time the
		// player grabbed the map to move it.
		//
		// It is also where the map's own CTRL+drag FREEHAND DRAWING is taken
		// away. CTRL is the selection modifier - it is how a selection is built
		// up one unit at a time - and the engine reads the same chord as "start
		// drawing a line", so every unit added to a selection left a scribble on
		// the map behind it. The line starts on the press, so the press is where
		// it can be stopped: returning true consumes the event and the engine
		// never begins one.
		//
		// Consumed ONLY with CTRL down and ONLY while commanding, which is the
		// whole of the overlap. A plain drag still pans, because that press is
		// not consumed; drawing still works on the campaign map, because the
		// player is not commanding there and CTRL means nothing to this layer.
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
			// pan is not an order. The travel guard covers the right button as
			// well as the left: the map does not pan on the right today, but
			// putting one button under a different law than the other is how
			// the two end up behaving differently for reasons nobody
			// remembers.
			if (_commanding && {count _press == 3} && {(_press select 0) == _button}) then {
				private _travel = sqrt (
					(((_press select 1) - _x) ^ 2) + (((_press select 2) - _y) ^ 2)
				);

				if (_travel <= STRAT_mapClickSlop) then {
					private _world = _control ctrlMapScreenToWorld [_x, _y];

					// The two buttons ask two different questions of the same
					// selection: the left one changes it or orders it, the
					// right one asks what can be done with it.
					//
					// And they take their position in two different spaces,
					// which is not an inconsistency. An order is given at a
					// place on the ground, so the left button converts to
					// world. A menu opens at the cursor, so the right button
					// hands on the screen coordinates untouched - they are
					// already in the space ctrlSetPosition takes.
					switch (_button) do {
						case 0: { [_world, _ctrl, _shift] call TACT_fnc_onCommandClick };
						case 1: { [[_x, _y]] call TACT_fnc_openContextMenu };
					};
				};
			};

			false
		}];
		_map setVariable ["STRAT_mapReleaseEH", _releaseId];

		diag_log format ["STRAT Draw: map layer attached (draw %1, press %2, release %3).", _drawId, _pressId, _releaseId];

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
		// whether or not a battle is still running. A context menu does not
		// survive that - its controls live on the map's display, so one left
		// open is a menu the player cannot see, cannot dismiss, and would find
		// waiting to eat his first click the next time he opened the map.
		call TACT_fnc_closeContextMenu;
		[false] call TACT_fnc_setCommandHud;
	};
};

true
