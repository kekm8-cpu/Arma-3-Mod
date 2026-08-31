/*
	Function: TACT_fnc_openContextMenu

	Description:
		Opens the command layer's context menu on a right-click, against
		whatever is currently selected.

		Built from REAL CONTROLS on display 12 - the map's own display - with
		ctrlCreate, rather than drawn into the map layer or opened with
		createDialog. Both alternatives were tried against this one:

		  drawn      would put the menu under the map's scaling law, which is
		             the tidier story and buys nothing. A rectangle, a font
		             metric and a hover highlight all hand-rolled in world
		             coordinates against a renderer built for map symbols, with
		             every row's position described twice - once to draw it and
		             once to hit-test it. The engine does all of that already.
		  createDialog would open a display of its own on top of the map and
		             take focus from it. The map would stop being the thing the
		             player is interacting with for as long as the menu was up,
		             and a click that missed the menu would be a click on a
		             dialog rather than on the map underneath.

		Controls on the map's display are neither. The map keeps its input, a
		click that misses the menu is still a click on the map, and z-order
		settles itself: a control created later draws over the ones already
		there, and nothing is created later than these.

		POSITION comes straight from the mouse. Control event handlers report
		where the pointer is in the same coordinate space ctrlSetPosition takes,
		so the menu's top-left corner is exactly where the click was, with no
		conversion in between. It flips back over the cursor at the right or
		bottom edge of the screen rather than opening off it.

		THE ENTITY CONTAINER ONLY. The selection is two containers - men and
		vehicles in TACT_commandSelection, whole groups in
		TACT_commandGroupSelection - and all three of this menu's options are
		orders for individuals. So a selection of nothing but groups opens
		nothing, exactly as an empty selection does, and a mixed selection
		offers the options for the individuals in it and leaves the groups
		alone. That stops being the right answer the day a group has orders of
		its own; until then, offering "Stop" over a body of men that cannot be
		stopped would be a row that does nothing.

		The menu addresses the SELECTION and never changes it. Right-clicking
		is not a way to pick a unit, anywhere on the map, on or off an icon:
		the selection is built with the left button and CTRL, and the right
		button asks what can be done with it. A right-click landing on an
		unselected man does not quietly discard the four the player spent four
		clicks assembling.

		Which is also why an empty selection opens nothing. There is no
		general "map menu" here - every option acts on units, so with no units
		there is no menu to open, and the click is silent rather than showing
		a panel of dead entries.

		Two options are always present and one is conditional:

		  Stop      hold where you are, out of formation
		  Regroup   resume your place in the commander's formation
		  New Group split the selection off as a group of its own - only with
		            two or more entities selected, because one entity is not a
		            body of men and splitting it produces a group the player
		            cannot yet address

		Each row CARRIES ITS OWN OPTION on the control, so nothing has to keep
		a parallel list of what the rows are or what order they are in. A row
		cannot run the wrong option, because the only place the option is
		written down is the thing that was clicked.

		The selection is pruned first, against the live entity list, for the
		same reason TACT_fnc_onCommandClick prunes - a casualty still sitting
		in the selection would count toward the two entities "New Group" needs.

	Parameters:
		0: ARRAY - [x, y] screen position of the click, as the mouse event
		           handler reported it

	Returns:
		BOOL - true if a menu was opened.
*/

params [
	["_screen", [], [[]]]
];

if (count _screen < 2) exitWith { false };

// Whatever was open is gone before anything else happens. A second right-click
// moves the menu rather than stacking a second one behind it.
call TACT_fnc_closeContextMenu;

private _display = findDisplay 12;
if (isNull _display) exitWith { false };

if (isNil "TACT_commandSelection") then { TACT_commandSelection = [] };

// The authoritative list of what can be commanded this frame. Anything in the
// selection that is not in it stopped being an entity since the last click - a
// casualty, a rider whose vehicle was destroyed - and is not a unit to build a
// menu around.
private _live = (call TACT_fnc_commandEntities) apply {_x get "obj"};
TACT_commandSelection = TACT_commandSelection select {_x in _live};

if (count TACT_commandSelection == 0) exitWith { false };

private _options = [
	["stop",    "Stop"],
	["regroup", "Regroup"]
];

// The transient one. Two or more ENTITIES, not two or more men: a truck with
// five of ours in it is one thing on the map and one thing to split, and the
// option asks the player to have chosen more than one thing.
if (count TACT_commandSelection >= 2) then {
	_options pushBack ["newGroup", "New Group"];
};

// ------------------------------------------------------------------------ //
// GEOMETRY                                                                  //
// ------------------------------------------------------------------------ //
// Fractions of the safe zone, so the menu is the same size on every monitor.
private _rows = count _options;
private _w    = TACT_commandMenuWidthFrac * safezoneW;
private _rowH = TACT_commandMenuRowFrac * safezoneH;
private _edge = TACT_commandMenuEdgeFrac * safezoneH;
private _h    = _rows * _rowH;

// _px and _py rather than _x and _y: the row loop below is a forEach, and
// forEach's own _x would shadow a corner named _x for exactly the lines that
// need it.
private _px = _screen select 0;
private _py = _screen select 1;

// Flip back over the cursor at the far edges, the way a cursor menu does,
// rather than opening off the screen. The margin is counted in, so the frame
// stays on screen and not just the rows.
if (_px + _w + _edge > safezoneX + safezoneW) then { _px = _px - _w };
if (_py + _h + _edge > safezoneY + safezoneH) then { _py = _py - _h };

// ------------------------------------------------------------------------ //
// CONTROLS                                                                  //
// ------------------------------------------------------------------------ //
private _controls = [];

// The backing plate first, so every row draws over it and what is left showing
// is the margin - a border rather than a gap.
private _frame = _display ctrlCreate ["TACT_RscMenuFrame", -1];
_frame ctrlSetPosition [_px - _edge, _py - _edge, _w + (2 * _edge), _h + (2 * _edge)];
_frame ctrlCommit 0;
_controls pushBack _frame;

{
	_x params ["_id", "_label"];

	private _button = _display ctrlCreate ["TACT_RscMenuButton", -1];
	_button ctrlSetPosition [_px, _py + (_forEachIndex * _rowH), _w, _rowH];
	_button ctrlSetText _label;
	_button ctrlCommit 0;

	// The row IS the option. Nothing keeps a second list of which row means
	// what, so no row can drift onto the wrong one.
	_button setVariable ["TACT_optionId", _id];

	_button ctrlAddEventHandler ["ButtonClick", {
		params ["_control"];
		[_control getVariable ["TACT_optionId", ""]] call TACT_fnc_runContextOption;
	}];

	_controls pushBack _button;
} forEach _options;

TACT_commandMenuControls = _controls;
TACT_commandMenuOpen     = true;

true
