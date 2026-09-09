/*
	Function: TACT_fnc_issueGroupRoute

	Description:
		Gives a set of groups a waypoint at a world position - as a NEW route,
		replacing whatever chain they had, or APPENDED to the end of it.

		The group order the individuals' TACT_fnc_issueMoveOrder cannot be.
		doMove takes one destination and does not chain, and a man inside a
		player-led group drifts back into formation rather than holding where
		he was sent. A group with no player in it runs an `addWaypoint` chain
		natively - sequencing, completion, formation on the move - with no
		script watching it, which is why group command is waypoints and why
		the manifest kept the individuals to a single destination.

		REPLACE clears the group's whole chain through TACT_fnc_clearRoute -
		the same clear Backspace is - and adds the one clicked. APPEND leaves
		the chain alone and adds to it.

		THE GROUP IS POINTED AT THE NEW WAYPOINT when it had nothing left to
		walk to: a replaced chain always, and an appended one when the old
		chain had run out. A group that has completed its waypoints does not
		reliably pick up a new one on its own - `currentWaypoint` sits past the
		end of the list and stays there - so `setCurrentWaypoint` is what makes
		the order take. A group still walking a chain is left on the waypoint
		it is walking to, and the appended one is simply next.

		Orders go to groups in the selection whether or not they are moving,
		holding, or halfway through the last order: a new route is a new route.

	Parameters:
		0: ARRAY - groups to route
		1: ARRAY - world position of the waypoint
		2: BOOL  - true to append to the existing route, false to replace it

	Returns:
		NUMBER - how many groups took the waypoint.
*/

params [
	["_groups", [], [[]]],
	["_position", [], [[]]],
	["_append", false, [true]]
];

if (count _position < 2) exitWith { 0 };

private _destination = [_position select 0, _position select 1, 0];
private _ordered = 0;

{
	private _group = _x;

	if (!isNull _group && {count (units _group) > 0}) then {

		// Read BEFORE the chain is touched, so "had it run out" is answered
		// about the route the player was looking at when he clicked.
		private _remaining = count ([_group] call TACT_fnc_groupRoute);

		if (!_append) then {
			// No halt: the new destination is two lines away.
			[_group, false] call TACT_fnc_clearRoute;
			_remaining = 0;
		};

		private _waypoint = _group addWaypoint [_destination, 0];
		_waypoint setWaypointType "MOVE";

		if (_remaining == 0) then {
			_group setCurrentWaypoint _waypoint;
		};

		_ordered = _ordered + 1;
	};
} forEach _groups;

_ordered
