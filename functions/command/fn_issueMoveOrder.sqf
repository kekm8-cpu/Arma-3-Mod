/*
	Function: TACT_fnc_issueMoveOrder

	Description:
		Sends a set of command entities to a world position. One destination,
		issued once, and that is the whole of it.

		NO ROUTE AND NO QUEUE. doMove takes a single destination and does not
		chain, and a subordinate inside a player-led group drifts back into
		formation rather than holding where it was sent. Chained waypoints and
		held ground belong at the GROUP level, where Arma does them natively.

		Orders go out with doMove rather than commandMove: silent, and precise.
		The map has already shown where they were sent.

	Parameters:
		0: ARRAY - command entities (see TACT_fnc_commandEntities)
		1: ARRAY - world position ordered

	Returns:
		NUMBER - how many entities took the order.
*/

params [
	["_entities", [], [[]]],
	["_position", [], [[]]]
];

if (count _position < 2) exitWith { 0 };

private _destination = [_position select 0, _position select 1, 0];
private _ordered = 0;
private _unorderable = 0;

{
	private _entity = _x;
	private _obj    = _entity get "obj";
	private _order  = _entity get "order";

	if (!isNull _obj && {alive _obj}) then {

		// A vehicle with no driver of ours is a passenger compartment, not a
		// command entity. Counted so the player is told, rather than clicking
		// at something that will never move.
		if (count _order == 0) then {
			_unorderable = _unorderable + 1;
		} else {
			{ _x doMove _destination } forEach _order;
			_ordered = _ordered + 1;
		};
	};
} forEach _entities;

if (_unorderable > 0) then {
	systemChat format ["%1 vehicle(s) have no driver of ours and cannot be ordered.", _unorderable];
};

_ordered
