/*
	Function: TACT_fnc_onCommandClick

	Description:
		Map click handling while the player is commanding on the ground. Two
		outcomes, decided by what was under the click:

		  on an entity  - select it. CTRL toggles it into or out of the
		                  selection; a bare click replaces the selection with
		                  just that entity.
		  on terrain    - with units selected, a move order to exactly those
		                  units. With nothing selected, nothing at all.

		A terrain click addresses whoever is selected, and an empty selection
		addresses nobody. It does not fall back to the whole group: the player
		leads that group, so the only order it can be given from the map is one
		that competes with him for control of his own subordinates. Whatever
		the group does as a body it does by following him.

		Orders for a body of men will arrive as group-level command, where the
		engine carries them - a group with no player in it executes an
		addWaypoint chain natively. Until then this is silent rather than
		hinted at: a click on open ground is the easiest click to make by
		accident, and a line of chat every time is worse than nothing
		happening.

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

	// An empty selection addresses nobody - see the header. The report used to
	// say orders fell back to the whole group, which is what this function did
	// before the fallback was taken out, and reading it while deselecting the
	// last unit is how a working deselect looks like a broken one.
	private _selected = count TACT_commandSelection;
	private _report = if (_selected == 0) then {
		"Nothing selected."
	} else {
		format ["%1 selected.", _selected]
	};
	systemChat _report;

	true
};

// ------------------------------------------------------------------------ //
// TERRAIN: A MOVE ORDER FOR THE SELECTION, OR NOTHING                       //
// ------------------------------------------------------------------------ //
// Silently. See the header: an empty selection addresses nobody, and open
// ground is the easiest thing on the map to click by accident.
if (count TACT_commandSelection == 0) exitWith { false };

private _targets = _entities select {(_x get "obj") in TACT_commandSelection};

private _ordered = [
	_targets,
	[_position select 0, _position select 1, 0]
] call TACT_fnc_issueMoveOrder;

if (_ordered > 0) then {
	systemChat format ["%1 selected ordered to move.", _ordered];

	// Said rather than swallowed, because SHIFT does something here and the
	// player has every reason to expect it to stack.
	if (_shift) then {
		systemChat "An individual unit takes one destination. Routes are a group order.";
	};
};

_ordered > 0
