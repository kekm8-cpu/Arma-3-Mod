/*
	Function: TACT_fnc_runContextOption

	Description:
		Runs one context menu option against the current selection, and closes
		the menu.

		The menu closes FIRST, before anything is ordered - and closing it
		deletes its controls, so this runs from inside the ButtonClick handler
		of a control it is about to destroy. That is safe and it is the reason
		nothing is read off the control afterwards: the option id is taken out
		of it by the handler and passed in here by value.

		First, because every option either changes what the selection is or
		changes what it is doing, and a menu that outlived its own option would
		be describing a selection that had moved on - "New Group" still offered
		over units that are no longer in the player's group, a row sitting over
		men who are gone. One option, one menu.

		The selection is re-resolved here rather than carried from the open.
		Which option a row runs is fixed - it is written on the control and
		nowhere else, so a row cannot come to mean something it did not mean
		when it was drawn - but WHICH UNITS it runs against deliberately is
		not. Men die between opening a menu and pressing it, and an order
		issued to a casualty is an order issued to nothing. Every option
		therefore re-checks its own preconditions, "New Group" included: it
		needs two entities at the moment it runs and not merely at the moment
		it was offered.

		Unknown ids do nothing. The list is built one function away and read one
		function away, so an id that reaches here and is not handled is a wiring
		mistake rather than a player action, and it is logged as one.

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
