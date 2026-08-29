/*
	Function: TACT_fnc_issueMoveOrder

	Description:
		Sends a set of command entities to a world position. One destination,
		issued once, and that is the whole of it.

		There is no route here and no queue. Arma's doMove takes a single
		destination and does not chain, and a subordinate inside a player-led
		group drifts back into formation rather than holding where it was sent.
		Both of those were worked around for a while by a script that watched
		for arrivals and re-issued orders; the workaround needed guards against
		dragging men out of cover and against overriding the stock squad bar,
		and every guard was another condition under which commanding behaved
		differently.

		Chained waypoints and held ground move to the group level instead,
		where Arma does them natively - a group with no player in it executes
		an addWaypoint chain on its own, HOLD waypoints included. A player who
		wants one man to flank wide or watch a ridge detaches him into a group
		of one. Until that exists, an individual takes a destination and
		nothing more.

		Orders go out with doMove rather than commandMove: silent, and precise.
		The map has already shown where they were sent, so radio chatter would
		be reporting something the player is looking at.

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
