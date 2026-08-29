/*
	Function: TACT_fnc_issueMoveOrder

	Description:
		Writes a move order onto command entities as a route - an ordered list
		of world positions - and, for a fresh order, tells them to go there.

		A plain order replaces whatever route the entity had and is issued as a
		real move order. A stacked one appends and issues nothing: the extra
		waypoints are a plan, drawn on the map, not a queue.

		That is deliberate rather than unfinished. doMove takes one destination
		and does not queue, so walking a stack would mean a scripted executor
		watching for arrivals and feeding out legs - a second thing driving the
		group, fighting whatever the player just told it to do with the squad
		bar. The route the player draws for his own group is a route he walks
		at the head of it, and the group follows their leader without being
		told to. Individual units get the leg that was clicked, which is the
		order that was actually given.

		Routes live on the entity's own object rather than in a registry keyed
		by it. An entity that dies takes its route with it and nothing has to
		notice.

		Orders go out with doMove rather than commandMove: silent, and precise.
		The map already shows the route, so radio chatter would be reporting
		something the player is looking at.

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

			// Only a fresh order moves anybody. A stacked waypoint is the next
			// place the player intends to be, and issuing it now would send
			// the entity straight there past everything in between.
			if (!_stack) then {
				{ _x doMove _destination } forEach _order;
			};

			_ordered = _ordered + 1;
		};
	};
} forEach _entities;

if (_unorderable > 0) then {
	systemChat format ["%1 vehicle(s) have no driver of ours and cannot be ordered.", _unorderable];
};

_ordered
