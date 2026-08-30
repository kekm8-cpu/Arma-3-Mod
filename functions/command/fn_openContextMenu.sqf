/*
	Function: TACT_fnc_openContextMenu

	Description:
		Opens the command layer's context menu on a right-click, against
		whatever is currently selected.

		The menu addresses the SELECTION and never changes it. Right-clicking
		is not a way to pick a unit, anywhere on the map, on or off an icon:
		the selection is built with the left button and CTRL, and the right
		button asks what can be done with it. A right-click landing on an
		unselected man does not quietly discard the four the player spent four
		clicks assembling.

		Which is also why an empty selection opens nothing. There is no
		general "map menu" here - every option acts on units, so with no units
		there is no menu to draw, and the click is silent rather than showing
		a panel of dead entries.

		Two options are always present and one is conditional:

		  Stop      hold where you are, out of formation
		  Regroup   resume your place in the commander's formation
		  New Group split the selection off as a group of its own - only with
		            two or more entities selected, because one entity is not a
		            body of men and splitting it produces a group the player
		            cannot yet address

		The option list is built HERE and stored, rather than derived at draw
		time, so the rows cannot renumber underneath a click. A man dying while
		the menu is open would otherwise take "New Group" off the bottom of a
		list the player is already reaching for, and the row he presses would
		run the option that slid into it. The list is fixed at open; every
		option re-checks its own preconditions when it runs.

		The anchor is the world position clicked, and the panel hangs down and
		to the right of it, the way a cursor menu does. It is a world anchor
		rather than a screen one because the map pans and zooms under it: a
		menu opened over a truck stays over that truck.

		The selection is pruned first, against the live entity list, for the
		same reason TACT_fnc_onCommandClick prunes - a casualty still sitting
		in the selection would count toward the two entities "New Group" needs.

	Parameters:
		0: ARRAY - world position right-clicked

	Returns:
		BOOL - true if a menu was opened.
*/

params [
	["_position", [], [[]]]
];

if (count _position < 2) exitWith { false };

if (isNil "TACT_commandSelection") then { TACT_commandSelection = [] };

// The authoritative list of what can be commanded this frame. Anything in the
// selection that is not in it stopped being an entity since the last click - a
// casualty, a rider whose vehicle was destroyed - and is not a unit to build a
// menu around.
private _live = (call TACT_fnc_commandEntities) apply {_x get "obj"};
TACT_commandSelection = TACT_commandSelection select {_x in _live};

if (count TACT_commandSelection == 0) exitWith {
	TACT_commandMenuOpen = false;
	false
};

private _options = [
	createHashMapFromArray [["id", "stop"],    ["label", "Stop"]],
	createHashMapFromArray [["id", "regroup"], ["label", "Regroup"]]
];

// The transient one. Two or more ENTITIES, not two or more men: a truck with
// five of ours in it is one thing on the map and one thing to split, and the
// option asks the player to have chosen more than one thing.
if (count TACT_commandSelection >= 2) then {
	_options pushBack (createHashMapFromArray [["id", "newGroup"], ["label", "New Group"]]);
};

TACT_commandMenuAnchor  = [_position select 0, _position select 1, 0];
TACT_commandMenuOptions = _options;

// Seeded with the click, because that is where the pointer is. The cursor
// handler only runs on movement, so without this the first frames of a menu
// would be highlighted from wherever the last one was dismissed.
TACT_commandMenuCursor  = [_position select 0, _position select 1, 0];

TACT_commandMenuOpen    = true;

true
