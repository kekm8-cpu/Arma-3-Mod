/*
	Function: TACT_fnc_closeContextMenu

	Description:
		Takes the context menu off the map.

		The controls ARE the menu, so closing it is deleting them; the flag
		exists only so the rest of the layer can ask without walking the array.

		THE SINGLE TEARDOWN every path uses: a chosen row, a click away, the map
		closing, fn_dropOut. A menu left behind by any of them would be a panel
		the player cannot see, cannot dismiss, and would find waiting to eat his
		first click the next time he opened the map.

		Null-tolerant on purpose: the map closing is entitled to take its
		controls with it, and deleting a null control is a no-op. Idempotent,
		and called from paths that have no idea whether a menu was opened.

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
