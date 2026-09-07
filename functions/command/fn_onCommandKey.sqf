/*
	Function: TACT_fnc_onCommandKey

	Description:
		Keyboard handling for the map while the player is commanding on the
		ground. Two keys, both edits to a group's route:

		  Backspace  removes the LAST remaining waypoint from every selected
		             group - the route shortens from the end, one press at a
		             time.
		  Delete     removes the ONE waypoint under the cursor, whichever
		             group's it is, and leaves the rest of that route intact.

		Backspace addresses the SELECTION, because it names no waypoint of its
		own and the selection is what the player has said he is talking about.
		Delete addresses the CURSOR, because the dot under it is the whole of
		what he meant; requiring the group to be selected as well would make
		a working key look like a broken one. Selection is pruned against the
		live group list first, the way TACT_fnc_onCommandClick prunes it.

		The dot under the cursor is found the way a click finds an icon:
		hit-tested against the list the map is DRAWING, filtered to waypoint
		items, converted through the same STRAT_fnc_mapUnitMetres call, nearest
		wins. What is not drawn cannot be deleted, and a completed waypoint is
		not drawn.

		The cursor is where the map control last saw it, recorded by the
		MouseMoving handler STRAT_fnc_attachMapLayer installs, in the same
		coordinate space the click handlers use - so a dot the click handlers
		would have resolved is the dot this resolves.

		CONSUMED ONLY WHEN THE KEY ACTED, or was aimed at something: Backspace
		with groups selected is consumed whether or not any of them had a
		waypoint to lose, because a key that reached a deliberate selection
		is not a stray key; with none selected it is left to the engine.
		Delete is consumed only over a dot, so its stock use on the map -
		deleting a marker under the cursor - survives everywhere else. Both
		keys are the engine's elsewhere and nothing here reaches the campaign
		map: the caller passes keys through only while commanding.

		Reported rather than silent, in both directions: a key is a deliberate
		act, and a route that did not shorten needs to say why.

	Parameters:
		0: NUMBER  - DIK key code
		1: CONTROL - the map control

	Returns:
		BOOL - true if the key was consumed.
*/

params [
	["_key", -1, [0]],
	["_map", controlNull, [controlNull]]
];

if (isNull _map) exitWith { false };

if (isNil "TACT_commandGroupSelection") then { TACT_commandGroupSelection = [] };

switch (_key) do {

	// ------------------------------------------------------------------ //
	// BACKSPACE: THE LAST WAYPOINT OFF EVERY SELECTED GROUP                //
	// ------------------------------------------------------------------ //
	// DIK 14 = Backspace
	case 14: {
		private _liveGroups = (call TACT_fnc_playerGroups) apply {_x get "group"};
		TACT_commandGroupSelection = TACT_commandGroupSelection select {_x in _liveGroups};

		if (count TACT_commandGroupSelection == 0) exitWith { false };

		private _shortened = 0;

		{
			private _route = [_x] call TACT_fnc_groupRoute;

			if (count _route > 0) then {
				private _last = (_route select (count _route - 1)) select 0;

				if ([_x, _last] call TACT_fnc_removeWaypoint) then {
					_shortened = _shortened + 1;
				};
			};
		} forEach TACT_commandGroupSelection;

		if (_shortened > 0) then {
			systemChat format ["Last waypoint removed from %1 group(s).", _shortened];
		} else {
			systemChat "The selected group(s) have no waypoints to remove.";
		};

		true
	};

	// ------------------------------------------------------------------ //
	// DELETE: THE ONE WAYPOINT UNDER THE CURSOR                            //
	// ------------------------------------------------------------------ //
	// DIK 211 = Delete
	case 211: {
		private _cursor = _map getVariable ["STRAT_mapCursorAt", []];
		if (count _cursor < 2) exitWith { false };

		private _metresPerUnit = [_map] call STRAT_fnc_mapUnitMetres;
		if (_metresPerUnit <= 0) exitWith { false };

		private _position = _map ctrlMapScreenToWorld _cursor;

		private _dots = (call TACT_fnc_buildCommandList) select {
			(_x get "kind") == "groupWaypoint" && {(_x get "hitUnits") > 0}
		};

		private _hitItem = createHashMap;
		private _hitDistance = -1;

		{
			private _distance = _position distance2D (_x get "anchor");

			// Nearest wins, so two routes crossing resolve to the dot actually
			// under the cursor rather than to whichever group was emitted first.
			if (_distance <= ((_x get "hitUnits") * _metresPerUnit)
				&& {_hitDistance < 0 || {_distance < _hitDistance}}) then {
				_hitDistance = _distance;
				_hitItem = _x;
			};
		} forEach _dots;

		if (count _hitItem == 0) exitWith { false };

		private _record = _hitItem get "record";
		private _group  = _record get "group";

		if ([_group, _record get "index"] call TACT_fnc_removeWaypoint) then {
			systemChat format ["Waypoint removed from %1.", groupId _group];
		};

		true
	};

	default { false };
};
