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

		TWO CONTAINERS, ONE SELECTION. A man is an object and a group is a
		GROUP, so they are held in TACT_commandSelection and
		TACT_commandGroupSelection separately - see init.sqf for why one array
		would not do. The player is not asked to know that: a bare click
		replaces both, so clicking a man clears the groups and clicking a group
		clears the men, and only CTRL - which is how a selection is built up
		deliberately - can hold the two kinds at once.

		SELECTING A GROUP DOES NOT ORDER IT. A body of men has no map order
		until group waypoints arrive, so a terrain click with groups selected
		moves whatever individuals are selected and says what it did not do
		with the rest. That last part is a departure from the silence below and
		is deliberate: silence is for a click that addressed nobody, and a
		player who selected a group and then clicked ground addressed
		something. Telling him nothing there is how a feature that is not
		finished looks like one that is broken.

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

		The selection holds objects and groups rather than the records they
		came in, because the records are rebuilt every frame - a man who
		dismounts stops being part of a vehicle entity and becomes one of his
		own, and a group's membership and leader both change under fire. Stale
		entries are pruned here against the live lists rather than left to
		accumulate, and each kind is pruned against its own: a group tested for
		membership of a list of objects is not stale, it is absent.

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
// filter, because he was emitted without one - and so is every allied group,
// which is how "an ally is never his" is enforced here rather than restated.
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
// dismounted rider's vehicle, a casualty, a group wiped out or emptied into
// another - is no longer selectable and must not sit in the selection soaking
// up orders. Each kind against its own live list, because a group is not
// missing from a list of objects, it was never eligible for one.
private _liveObjects = _entities apply {_x get "obj"};
private _liveGroups  = _groupItems apply {(_x get "record") get "group"};

if (isNil "TACT_commandSelection") then { TACT_commandSelection = [] };
if (isNil "TACT_commandGroupSelection") then { TACT_commandGroupSelection = [] };

TACT_commandSelection      = TACT_commandSelection select {_x in _liveObjects};
TACT_commandGroupSelection = TACT_commandGroupSelection select {_x in _liveGroups};

// Toggle in place, and the same operation for both kinds. CTRL is how a
// selection is built up one thing at a time and also how a thing is taken back
// out of one, so the same modifier has to do both directions. An index rather
// than array subtraction because this has to be as right about two group
// handles as it is about two objects.
private _fnc_toggle = {
	params ["_selection", "_thing"];

	private _index = _selection find _thing;
	if (_index < 0) then { _selection pushBack _thing } else { _selection deleteAt _index };
};

// What the player is holding, said in one line. An empty selection addresses
// nobody - see the header - and the report used to claim orders fell back to
// the whole group, which is what this function did before the fallback came
// out; reading that while deselecting the last unit is how a working deselect
// looks like a broken one.
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
// The individuals are tested BEFORE the groups and the comparison below is
// strict, so a tie goes to the man. That is the case that decides whether
// groups having an area at all costs anything: a group's icon sits over its
// leader, and where the player's own man is standing at the same spot he is
// the finer thing to have meant and stays as clickable as he was.
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
// keeps two arrays reading as one selection. CTRL toggles inside the container
// the clicked thing belongs to and leaves the other alone, so a mixed
// selection is something the player builds rather than something he inherits
// from the last click.
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
// Silently, when nothing at all is selected. See the header: an empty selection
// addresses nobody, and open ground is the easiest thing on the map to click by
// accident.
if (count TACT_commandSelection == 0 && {count TACT_commandGroupSelection == 0}) exitWith { false };

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

// A group in the selection took nothing, and is told so. This is the one place
// the silence rule does not apply - a click that reached a deliberate selection
// is not an accidental click - and it is where group orders plug in: the
// engine executes an addWaypoint chain for a group with no player in it, which
// is the whole reason orders for a body of men were held back to this level
// rather than scripted at the individual's.
private _groups = count TACT_commandGroupSelection;

if (_groups > 0) then {
	systemChat format [
		"%1 group(s) selected. A body of men has no map order yet - that arrives with waypoints.",
		_groups
	];
};

_ordered > 0 || {_groups > 0}
