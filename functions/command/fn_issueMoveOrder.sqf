/*
	Function: TACT_fnc_issueMoveOrder

	Description:
		Writes a move order onto command entities as a route - an ordered list
		of world positions - and starts them on its first leg.

		A plain order replaces whatever route the entity had. A stacked one
		appends, which is how a series of clicks becomes a path around a hill
		rather than through it.

		The route lives on the entity's own object rather than in a registry
		keyed by it. An entity that dies takes its route with it, and nothing
		has to notice and clean up after it.

		Orders are issued with doMove rather than commandMove: silent, and
		precise. The map already shows the route, so the radio chatter would be
		reporting something the player is looking at.

	Parameters:
		0: ARRAY - command entities (see TACT_fnc_commandEntities)
		1: ARRAY - world position ordered
		2: BOOL  - stack onto the existing route instead of replacing it
		           (default false)

	Returns:
		NUMBER - how many entities took the order.
*/

params [
	["_entities", [], [[]]],
	["_position", [], [[]]],
	["_stack", false, [true]]
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
			private _route = if (_stack) then {
				+(_obj getVariable ["TACT_route", []])
			} else {
				[]
			};

			_route pushBack _destination;
			_obj setVariable ["TACT_route", _route];

			// Start the first leg now rather than waiting for the executor's
			// next tick. A command that visibly does nothing for a second
			// reads as a command that was not received.
			private _leg = _route select 0;
			{ _x doMove _leg } forEach _order;
			_obj setVariable ["TACT_routeIssued", _leg];

			_ordered = _ordered + 1;
		};
	};
} forEach _entities;

if (_unorderable > 0) then {
	systemChat format ["%1 vehicle(s) have no driver of ours and cannot be ordered.", _unorderable];
};

_ordered
