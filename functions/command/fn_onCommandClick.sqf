/*
	Function: TACT_fnc_onCommandClick

	Description:
		Map click handling while the player is commanding on the ground. Two
		outcomes, decided by what was under the click:

		  on an entity  - select it. CTRL toggles it into or out of the
		                  selection; a bare click replaces the selection with
		                  just that entity.
		  on terrain    - with units selected, a move order to exactly those
		                  units. With nothing selected, a waypoint on the
		                  group's route: a bare click replaces the route, SHIFT
		                  appends a leg to it.

		The two terrain cases are different in kind, not just in who they
		address. A selection is given a destination and goes there. The group's
		route is not given to anybody - it is the player's own line of march,
		drawn on the map, and he walks it at the head of the group with the AI
		following their leader as they already do.

		That is why the group route issues no orders. Chained waypoints and
		held ground are engine features at the group level and are not
		reproducible inside a player-led group without a script fighting the
		formation AI for control of every subordinate; see
		TACT_fnc_issueMoveOrder.

		Hit-testing runs against the list the map is drawing - the same
		TACT_fnc_buildCommandList output, filtered to the items that declared a
		hit radius - converted through the same STRAT_fnc_mapUnitMetres call.
		The click target is therefore the drawn icon rather than an
		approximation of it, and an entity that is not drawn cannot be clicked.
		Hit radii are in icon units, so a unit stays as easy to click zoomed
		out as zoomed in.

		The selection holds objects rather than entity records, because the
		records are rebuilt every frame - a man who dismounts stops being part
		of a vehicle entity and becomes one of his own. Stale objects are
		pruned here against the live entity list rather than left to
		accumulate.

	Parameters:
		0: ARRAY - world position clicked
		1: BOOL  - CTRL held
		2: BOOL  - SHIFT held

	Returns:
		BOOL - true if the click was acted on.
*/

params [
	["_position", [], [[]]],
	["_ctrl", false, [true]],
	["_shift", false, [true]]
];

if (count _position < 2) exitWith { false };

private _map = (findDisplay 12) displayCtrl 51;
private _metresPerUnit = [_map] call STRAT_fnc_mapUnitMetres;

if (_metresPerUnit <= 0) exitWith {
	diag_log "TACT Command: click could not measure the map scale, ignored.";
	false
};

// One list, built once, used for the hit-test, the prune and the order. The
// commander's own items are in here too and are skipped by the hit radius
// filter, because he was emitted without one.
private _items = (call TACT_fnc_buildCommandList) select {
	(_x get "kind") == "commandEntity" && {(_x get "hitUnits") > 0}
};

if (count _items == 0) exitWith { false };

private _entities = _items apply {_x get "record"};

// Prune first: anything that stopped being an entity since the last click -
// a dismounted rider's vehicle, a casualty - is no longer drawn, so it is no
// longer selectable and must not sit in the selection soaking up orders.
private _live = _entities apply {_x get "obj"};
if (isNil "TACT_commandSelection") then { TACT_commandSelection = [] };
TACT_commandSelection = TACT_commandSelection select {_x in _live};

// ------------------------------------------------------------------------ //
// WHAT WAS UNDER THE CLICK                                                  //
// ------------------------------------------------------------------------ //
private _hit = objNull;
private _hitDistance = -1;

{
	private _anchor = _x get "anchor";
	private _distance = _position distance2D _anchor;

	// Nearest wins, so a click between two units resolves to the one actually
	// closer rather than to whichever came first in group order.
	if (_distance <= ((_x get "hitUnits") * _metresPerUnit)
		&& {_hitDistance < 0 || {_distance < _hitDistance}}) then {
		_hitDistance = _distance;
		_hit = (_x get "record") get "obj";
	};
} forEach _items;

// ------------------------------------------------------------------------ //
// AN ENTITY: SELECTION                                                      //
// ------------------------------------------------------------------------ //
if (!isNull _hit) exitWith {
	if (_ctrl) then {
		// Toggle. CTRL is how a selection is built up one unit at a time and
		// also how a unit is taken back out of one, so the same modifier has
		// to do both directions.
		if (_hit in TACT_commandSelection) then {
			TACT_commandSelection = TACT_commandSelection - [_hit];
		} else {
			TACT_commandSelection pushBack _hit;
		};
	} else {
		TACT_commandSelection = [_hit];
	};

	private _selected = count TACT_commandSelection;
	private _report = if (_selected == 0) then {
		"Selection cleared - orders go to the whole group."
	} else {
		format ["%1 selected.", _selected]
	};
	systemChat _report;

	true
};

// ------------------------------------------------------------------------ //
// TERRAIN                                                                   //
// ------------------------------------------------------------------------ //
private _waypoint = [_position select 0, _position select 1, 0];

// ------------------------------------------------------------------------ //
// NOTHING SELECTED: THE GROUP'S ROUTE                                       //
// ------------------------------------------------------------------------ //
// One route for the group, held in one place and drawn once. It used to be
// stored on every entity, which meant the same line was rendered once per man.
if (count TACT_commandSelection == 0) exitWith {
	if (_shift) then {
		TACT_groupRoute pushBack _waypoint;
	} else {
		TACT_groupRoute = [_waypoint];
	};

	systemChat format [
		"Group route: %1 leg(s). Lead them along it.",
		count TACT_groupRoute
	];

	true
};

// ------------------------------------------------------------------------ //
// UNITS SELECTED: A MOVE ORDER                                              //
// ------------------------------------------------------------------------ //
private _targets = _entities select {(_x get "obj") in TACT_commandSelection};

private _ordered = [_targets, _waypoint] call TACT_fnc_issueMoveOrder;

if (_ordered > 0) then {
	systemChat format ["%1 selected ordered to move.", _ordered];

	// Said once per order rather than swallowed silently, because SHIFT does
	// something here and the player has every reason to expect it to stack.
	if (_shift) then {
		systemChat "An individual unit takes one destination. Routes are a group order.";
	};
};

_ordered > 0
