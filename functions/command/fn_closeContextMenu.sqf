/*
	Function: TACT_fnc_closeContextMenu

	Description:
		Takes the context menu off the map.

		The controls ARE the menu, so closing it is deleting them - there is no
		separate "is it open" that could be set while the rows were still on
		screen, or cleared while they were still taking clicks. The flag exists
		only so the rest of the layer can ask the question without walking the
		array.

		Every path out of command mode comes through here: choosing a row,
		clicking away from the menu, closing the map, dropping out of the body.
		A menu is drawn on the map's display, so one left behind by any of them
		would be a panel the player cannot see, cannot dismiss, and would find
		waiting to eat his first click the next time he opened the map.

		Null-tolerant on purpose. If display 12 was destroyed underneath the
		menu - the map closing is entitled to take its controls with it - the
		references left in the array are null, and deleting a null control is a
		no-op rather than an error. There is no state where this function has
		nothing to do and refuses to run.

		Idempotent, and called from paths that have no idea whether a menu was
		ever opened.

	Parameters:
		none

	Returns:
		BOOL - true if a menu was actually taken down.
*/

if (isNil "TACT_commandMenuControls") then { TACT_commandMenuControls = [] };

private _had = count TACT_commandMenuControls > 0;

{
	if (!isNull _x) then { ctrlDelete _x };
} forEach TACT_commandMenuControls;

TACT_commandMenuControls = [];
TACT_commandMenuOpen     = false;

_had
