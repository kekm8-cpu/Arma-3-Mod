/*
	Function: TACT_fnc_issueRegroup

	Description:
		Returns a set of command entities to their place in the commander's
		formation. The release half of the pair TACT_fnc_issueStopOrder opens.

		`doFollow` is the engine's counterpart to `doStop` and clears a standing
		`doMove` as well: a man sent to a point and a man told to hold are in
		the same suspended state as far as formation is concerned, so one option
		brings both back.

		The leader is read off the unit's own group rather than assumed to be
		the player. He is the leader today, but hardcoding that breaks silently
		the moment it is not true and reading the group costs nothing.

		Orders go through the entity's `order` units: a truck rejoins the
		formation when its driver does.

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
			{
				// BINARY. `doFollow` takes the unit to order AND the leader to
				// order it after - `doFollow _x` on its own does not parse,
				// which is what the engine said the first time this was
				// written that way. Its opposite number `doStop` is unary, and
				// the two being a pair in meaning does not make them a pair in
				// syntax.
				private _leader = leader (group _x);

				if (!isNull _leader && {_leader != _x}) then {
					_x doFollow _leader;
				};
			} forEach _order;

			_ordered = _ordered + 1;
		};
	};
} forEach _entities;

if (_unorderable > 0) then {
	systemChat format ["%1 vehicle(s) have no driver of ours and cannot be ordered.", _unorderable];
};

_ordered
