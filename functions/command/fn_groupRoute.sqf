/*
	Function: TACT_fnc_groupRoute

	Description:
		Reads a group's REMAINING route: every waypoint from the one it is
		currently walking to onward, in order, with the index the engine knows
		each by.

		The one definition of what a group's route is. The draw list reads it
		to draw the dots, the Backspace key reads it to find the last one, and
		TACT_fnc_issueGroupRoute reads it to know whether a chain had run out
		before appending to it. Three readers of the engine's waypoint list
		agreeing by construction rather than by care.

		COMPLETED WAYPOINTS ARE NOT IN IT. The engine keeps a waypoint after
		the group has reached it and only advances `currentWaypoint` past it,
		so a group's full list is its history as well as its orders. Drawn
		whole, a moving group would trail its old route behind it and the first
		leg would run backwards to somewhere it has already been. The remaining
		route is the standing order, and the standing order is what the map
		shows and what the keys edit - which is also what makes a completed
		waypoint unreachable by Delete: it is not drawn, so it has no dot.

		Indices are the engine's own, read back rather than counted, because
		deleting a waypoint renumbers the ones after it and a count kept here
		would be wrong from that moment.

	Parameters:
		0: GROUP - the group

	Returns:
		ARRAY - one [index, position] per remaining waypoint, in route order.
		        Empty for a null group, a group with no waypoints, or one that
		        has finished its chain.
*/

params [
	["_group", grpNull, [grpNull]]
];

private _route = [];

if (isNull _group) exitWith { _route };

private _current = currentWaypoint _group;

{
	private _index = _x select 1;

	if (_index >= _current) then {
		private _position = waypointPosition _x;
		_route pushBack [_index, [_position select 0, _position select 1, 0]];
	};
} forEach (waypoints _group);

_route
