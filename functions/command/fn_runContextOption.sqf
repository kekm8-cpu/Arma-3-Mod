/*
	Function: TACT_fnc_runContextOption

	Description:
		Runs one context menu option against the current selection, and closes
		the menu.

		THE MENU CLOSES FIRST, which deletes its controls - so this runs from
		inside the ButtonClick handler of a control it is about to destroy. That
		is safe, and it is why nothing is read off the control afterwards: the
		option id is passed in here by value.

		First, because every option either changes what the selection is or what
		it is doing, and a menu outliving its own option would describe a
		selection that had moved on. One option, one menu.

		The selection is re-resolved here rather than carried from the open. Men
		die between opening a menu and pressing it, so every option re-checks
		its own preconditions - "New Group" needs two entities at the moment it
		runs, not merely when it was offered.

		Unknown ids do nothing and are logged: an id that reaches here unhandled
		is a wiring mistake, not a player action.

	Parameters:
		0: STRING - option id: "stop", "regroup", "newGroup"

	Returns:
		BOOL - true if the option acted.
*/

params [
	["_id", "", [""]]
];

call TACT_fnc_closeContextMenu;

if (_id == "") exitWith { false };

if (isNil "TACT_commandSelection") then { TACT_commandSelection = [] };

// Live entities, this frame. Also the prune: anything selected that is no
// longer an entity is not in this list and so takes no part in the order.
private _entities = call TACT_fnc_commandEntities;
private _targets  = _entities select {(_x get "obj") in TACT_commandSelection};

if (count _targets == 0) exitWith {
	systemChat "Nothing selected.";
	false
};

switch (_id) do {

	case "stop": {
		private _ordered = [_targets] call TACT_fnc_issueStopOrder;
		if (_ordered > 0) then {
			systemChat format ["%1 selected holding position.", _ordered];
		};
		_ordered > 0
	};

	case "regroup": {
		private _ordered = [_targets] call TACT_fnc_issueRegroup;
		if (_ordered > 0) then {
			systemChat format ["%1 selected returning to formation.", _ordered];
		};
		_ordered > 0
	};

	// Re-checked, not trusted. It was offered because two entities were
	// selected when the menu opened; one of them may have been destroyed since.
	case "newGroup": {
		if (count _targets < 2) exitWith {
			systemChat "A new group needs two or more units.";
			false
		};

		!isNull ([_targets] call TACT_fnc_splitGroup)
	};

	default {
		diag_log format ["TACT Command: unknown context menu option '%1'.", _id];
		false
	};
}
