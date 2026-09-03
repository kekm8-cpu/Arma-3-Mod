/*
	Function: TACT_fnc_onCommandClick

	Description:
		Map click handling while the player is commanding on the ground. Three
		outcomes, decided by what was under the click:

		  on an entity  - select it. CTRL toggles it into or out of the
		                  selection; a bare click replaces the selection with
		                  just that entity.
		  on a group    - the same, for one of his own collapsed groups. An
		                  ally's group is not a click target and never reaches
		                  here: it is emitted without a hit area.
		  on terrain    - with units selected, a move order to exactly those
		                  units. With nothing selected, nothing at all.

		TWO CONTAINERS, ONE SELECTION. A bare click replaces both, so clicking a
		man clears the groups and clicking a group clears the men; only CTRL can
		hold the two kinds at once.

		SELECTING A GROUP DOES NOT ORDER IT - a body of men has no map order
		until group waypoints arrive - so a terrain click with groups selected
		moves the individuals and SAYS what it did not do with the rest. That is
		the one departure from the silence rule below, because a click that
		reached a deliberate selection is not an accidental click.

		A FOURTH CASE SITS IN FRONT OF ALL THREE: a click arriving here with the
		context menu open is one that MISSED it, since a click on a row is
		consumed by that row. It dismisses the menu and stops, never falling
		through to a move order.

		A terrain click addresses whoever is selected, and an empty selection
		addresses nobody - it never falls back to the whole group, which the
		player leads himself. Silent, because open ground is the easiest thing
		on the map to click by accident.

		Hit-testing runs against the list the map is DRAWING, filtered to items
		that declared a hit radius and converted through the same
		STRAT_fnc_mapUnitMetres call, so the click target is the drawn icon
		rather than an approximation of it and what is not drawn cannot be
		clicked.

		The selection holds objects and groups rather than the records they came
		in, because the records are rebuilt every frame. Stale entries are
		pruned here, each kind against its own live list: a group tested against
		a list of objects is not stale, it is absent.

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

// ------------------------------------------------------------------------ //
// A CLICK THAT REACHED THE MAP WITH A MENU OPEN IS A DISMISS                //
// ------------------------------------------------------------------------ //
// A click ON a row is consumed by that row and never arrives here, so a click
// that does arrive MISSED the menu. It stops here and does not fall through to
// the terrain click below.
//
// Before the map is measured, so a menu can be dismissed on a frame the scale
// cannot be read on.
if (!isNil "TACT_commandMenuOpen" && {TACT_commandMenuOpen}) exitWith {
	call TACT_fnc_closeContextMenu;
	true
};

private _map = (findDisplay 12) displayCtrl 51;
private _metresPerUnit = [_map] call STRAT_fnc_mapUnitMetres;

if (_metresPerUnit <= 0) exitWith {
	diag_log "TACT Command: click could not measure the map scale, ignored.";
	false
};

// One list, built once, used for the hit-test, the prune and the order. The
// commander and every allied group are in it and are skipped by the hit-radius
// filter, because they were emitted without one - which is where "an ally is
// never his" is enforced, rather than restated here.
private _list = call TACT_fnc_buildCommandList;

private _entityItems = _list select {
	(_x get "kind") == "commandEntity" && {(_x get "hitUnits") > 0}
};

private _groupItems = _list select {
	(_x get "kind") == "playerGroup" && {(_x get "hitUnits") > 0}
};

if (count _entityItems == 0 && {count _groupItems == 0}) exitWith { false };

private _entities = _entityItems apply {_x get "record"};

// Prune first: anything that stopped being drawn since the last click - a
// dismounted rider's vehicle, a casualty, a group wiped out - must not sit in
// the selection soaking up orders. Each kind against its OWN live list.
private _liveObjects = _entities apply {_x get "obj"};
private _liveGroups  = _groupItems apply {(_x get "record") get "group"};

if (isNil "TACT_commandSelection") then { TACT_commandSelection = [] };
if (isNil "TACT_commandGroupSelection") then { TACT_commandGroupSelection = [] };

TACT_commandSelection      = TACT_commandSelection select {_x in _liveObjects};
TACT_commandGroupSelection = TACT_commandGroupSelection select {_x in _liveGroups};

// Toggle in place, the same operation for both kinds: CTRL adds and removes.
// An index rather than array subtraction, because this has to be as right about
// two group handles as it is about two objects.
private _fnc_toggle = {
	params ["_selection", "_thing"];

	private _index = _selection find _thing;
	if (_index < 0) then { _selection pushBack _thing } else { _selection deleteAt _index };
};

// What the player is holding, in one line. An empty selection addresses nobody
// and the report must say exactly that - anything suggesting a fallback to the
// whole group makes a working deselect look like a broken one.
private _fnc_report = {
	private _men    = count TACT_commandSelection;
	private _groups = count TACT_commandGroupSelection;

	switch (true) do {
		case (_men == 0 && {_groups == 0}): { "Nothing selected." };
		case (_groups == 0):                { format ["%1 selected.", _men] };
		case (_men == 0):                   { format ["%1 group(s) selected.", _groups] };
		default                             { format ["%1 selected, and %2 group(s).", _men, _groups] };
	};
};

// ------------------------------------------------------------------------ //
// WHAT WAS UNDER THE CLICK                                                  //
// ------------------------------------------------------------------------ //
// Individuals are tested BEFORE the groups and the comparison is strict, so a
// tie goes to the man: a group's icon sits over its leader, and where his own
// man is standing at that spot he is the finer thing to have meant.
private _hitItem = createHashMap;
private _hitDistance = -1;

{
	private _anchor = _x get "anchor";
	private _distance = _position distance2D _anchor;

	// Nearest wins, so a click between two icons resolves to the one actually
	// closer rather than to whichever came first in group order.
	if (_distance <= ((_x get "hitUnits") * _metresPerUnit)
		&& {_hitDistance < 0 || {_distance < _hitDistance}}) then {
		_hitDistance = _distance;
		_hitItem = _x;
	};
} forEach (_entityItems + _groupItems);

// ------------------------------------------------------------------------ //
// AN ICON: SELECTION                                                        //
// ------------------------------------------------------------------------ //
// A bare click replaces the WHOLE selection, both containers, which is what
// keeps two arrays reading as one. CTRL toggles inside the clicked thing's own
// container and leaves the other alone, so a mixed selection is built
// deliberately and never inherited.
if (count _hitItem > 0) exitWith {
	private _record = _hitItem get "record";

	switch (_hitItem get "kind") do {

		case "commandEntity": {
			private _obj = _record get "obj";

			if (_ctrl) then {
				[TACT_commandSelection, _obj] call _fnc_toggle;
			} else {
				TACT_commandSelection      = [_obj];
				TACT_commandGroupSelection = [];
			};
		};

		case "playerGroup": {
			private _group = _record get "group";

			if (_ctrl) then {
				[TACT_commandGroupSelection, _group] call _fnc_toggle;
			} else {
				TACT_commandGroupSelection = [_group];
				TACT_commandSelection      = [];
			};
		};
	};

	systemChat (call _fnc_report);

	true
};

// ------------------------------------------------------------------------ //
// TERRAIN: A MOVE ORDER FOR THE SELECTION, OR NOTHING                       //
// ------------------------------------------------------------------------ //
// Silently, when nothing at all is selected: an empty selection addresses
// nobody, and open ground is the easiest thing on the map to misclick.
if (count TACT_commandSelection == 0 && {count TACT_commandGroupSelection == 0}) exitWith { false };

private _targets = _entities select {(_x get "obj") in TACT_commandSelection};

private _ordered = [
	_targets,
	[_position select 0, _position select 1, 0]
] call TACT_fnc_issueMoveOrder;

if (_ordered > 0) then {
	systemChat format ["%1 selected ordered to move.", _ordered];

	// Said rather than swallowed: SHIFT does something elsewhere and the player
	// has every reason to expect it to stack here.
	if (_shift) then {
		systemChat "An individual unit takes one destination. Routes are a group order.";
	};
};

// A group in the selection took nothing, and is told so - the one place the
// silence rule does not apply. This is also where group orders plug in when
// waypoint chains arrive.
private _groups = count TACT_commandGroupSelection;

if (_groups > 0) then {
	systemChat format [
		"%1 group(s) selected. A body of men has no map order yet - that arrives with waypoints.",
		_groups
	];
};

_ordered > 0 || {_groups > 0}
