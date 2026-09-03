/*
	Function: TACT_fnc_issueStopOrder

	Description:
		Stops a set of command entities where they stand. The counterpart of
		TACT_fnc_issueMoveOrder, and its opposite number in the pair
		TACT_fnc_issueRegroup completes.

		A subordinate inside a player-led group drifts back into formation on its
		own. `doStop` is the engine's way to suspend that: the unit holds where
		it is, out of formation, until something releases it - held ground for
		one man with no script watching for arrivals.

		What releases it is `doFollow`, which is TACT_fnc_issueRegroup and
		nothing else. NEITHER IS A TOGGLE: the player says stop and the unit is
		stopped, he says regroup and it is following, and there is no third
		state where the same option means different things.

		These are the same two orders the stock commanding menu issues for the
		same words, so the map and the F-keys do not mean different things by
		"stop".

		Orders go through the entity's `order` units, not its `men`: stopping a
		truck means stopping its driver, and stopping its passengers would leave
		the vehicle rolling with a stopped man in the back.

		Silent, like the move order - the map has already shown what is
		selected.

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

		// A vehicle with no driver of ours is a passenger compartment, not a
		// command entity - the same case TACT_fnc_issueMoveOrder counts, and
		// counted here for the same reason: the player is told rather than
		// left clicking at something that will never obey.
		if (count _order == 0) then {
			_unorderable = _unorderable + 1;
		} else {
			{ doStop _x } forEach _order;
			_ordered = _ordered + 1;
		};
	};
} forEach _entities;

if (_unorderable > 0) then {
	systemChat format ["%1 vehicle(s) have no driver of ours and cannot be ordered.", _unorderable];
};

_ordered
