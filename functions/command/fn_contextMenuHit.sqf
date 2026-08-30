/*
	Function: TACT_fnc_contextMenuHit

	Description:
		Resolves a world position to a row of the open context menu, or to no
		row at all.

		This is the menu's half of the law the rest of the layer already
		follows: the drawn and the clickable come out of ONE geometry. The
		panel's width, its row height and the direction it hangs are three
		constants, and both this function and the draw in
		TACT_fnc_buildCommandList work off exactly those three. There is no
		second description of where a row is, so there is no second
		description to fall out of step with the first.

		Everything is measured in icon units, through the same
		metres-per-icon-unit figure the icons and the hit radii use, which is
		what keeps a menu row the same size on screen at every zoom - and
		keeps it the same size to click as it looks.

		The panel hangs DOWN and to the RIGHT of its anchor, so the anchor is
		its top-left corner rather than its centre: that is where the cursor
		was when the menu opened, and a menu that opens centred on the cursor
		puts a row under the pointer before the player has chosen anything.

		Rows are indexed from the top, in the order the options were built.
		Row height is uniform, so which row a position is in is one division -
		no per-row loop, and nothing to get out of order.

		Used by the click path and by the hover highlight, which is the point:
		the row that lights up under the pointer is the row that runs when the
		button goes down, because the same function said so.

	Parameters:
		0: ARRAY  - world position to test
		1: NUMBER - metres per icon unit, from STRAT_fnc_mapUnitMetres

	Returns:
		NUMBER - row index, or -1 for no row.
*/

params [
	["_position", [], [[]]],
	["_metresPerUnit", 0, [0]]
];

if (isNil "TACT_commandMenuOpen" || {!TACT_commandMenuOpen}) exitWith { -1 };
if (count _position < 2 || {_metresPerUnit <= 0}) exitWith { -1 };
if (count TACT_commandMenuAnchor < 2) exitWith { -1 };

private _rows = count TACT_commandMenuOptions;
if (_rows == 0) exitWith { -1 };

// Into icon units, off the anchor. Both axes, because a row is a rectangle and
// a radius would make the panel a circle around its own corner.
private _dx = ((_position select 0) - (TACT_commandMenuAnchor select 0)) / _metresPerUnit;
private _dy = ((_position select 1) - (TACT_commandMenuAnchor select 1)) / _metresPerUnit;

if (_dx < 0 || {_dx > TACT_commandMenuWidthUnits}) exitWith { -1 };

// Down is negative: north is up on the map, and the panel hangs below its
// anchor. Anything at or above the anchor is off the top of the menu.
if (_dy > 0) exitWith { -1 };

private _row = floor ((0 - _dy) / TACT_commandMenuRowUnits);

if (_row < 0 || {_row >= _rows}) exitWith { -1 };

_row
