/*
	Function: TACT_fnc_issueRegroup

	Description:
		Returns a set of command entities to their place in the commander's
		formation. The release half of the pair TACT_fnc_issueStopOrder opens.

		`doFollow` is the engine's own counterpart to `doStop`, and it clears a
		standing `doMove` as well: a man sent to a point and a man told to hold
		are in the same suspended state as far as formation is concerned, so
		one option brings both back. That is the whole of what regroup means
		here - the unit stops doing the thing the map told it to do and goes
		back to doing what the group does, which is follow the man leading it.

		`doFollow` takes the unit and nothing else: which formation it returns
		to is its own group's, which is the one it never left. The player is
		that group's leader - TACT_fnc_dropIn makes him one, because the stock
		F-key interface addresses a group through its leader - so "resume your
		place in the formation" and "resume your place on the commander" are
		the same instruction, and no leader has to be named for them to stay
		the same one.

		Orders go through the entity's `order` units, for the reason
		TACT_fnc_issueStopOrder gives: a truck rejoins the formation when its
		driver does.

	Parameters:
		0: ARRAY - command entities (see TACT_fnc_commandEntities)

	Returns:
		NUMBER - how many entities took the order.
*/

params [
	["_entities", [], [[]]]
];

private _ordered = 0;
private _unorderable = 0;

{
	private _obj   = _x get "obj";
	private _order = _x get "order";

	if (!isNull _obj && {alive _obj}) then {

		if (count _order == 0) then {
			_unorderable = _unorderable + 1;
		} else {
			{ doFollow _x } forEach _order;

			_ordered = _ordered + 1;
		};
	};
} forEach _entities;

if (_unorderable > 0) then {
	systemChat format ["%1 vehicle(s) have no driver of ours and cannot be ordered.", _unorderable];
};

_ordered
