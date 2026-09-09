/*
	Function: TACT_fnc_clearRoute

	Description:
		Deletes every waypoint a group has, completed ones included, and
		leaves it with nothing to walk to - which is to say, halts it where it
		stands.

		Two callers, one order. TACT_fnc_issueGroupRoute clears before it
		replaces, so a new route starts from nothing; TACT_fnc_onCommandKey's
		Backspace clears and stops there, which is the group's STOP - the
		order a body of men had no way to take until this existed, since a
		group with no route left could not be told to hold except by clicking
		a waypoint on top of it.

		From the highest index down: deleting a waypoint renumbers the ones
		after it, and a loop walking upwards would skip every other one.

		WHETHER AN EMPTY CHAIN HALTS THE LEADER AT ONCE, rather than at the end
		of the leg he is on, is the engine's to answer and is being watched in
		play. If a group goes on to a destination that no longer exists, the
		line to add is a move order to the leader's own position, here, after
		the loop - one line, in the one place both callers share.

	Parameters:
		0: GROUP - the group

	Returns:
		NUMBER - how many waypoints were deleted.
*/

params [
	["_group", grpNull, [grpNull]]
];

if (isNull _group) exitWith { 0 };

private _existing = waypoints _group;

for "_i" from (count _existing - 1) to 0 step -1 do {
	deleteWaypoint (_existing select _i);
};

count _existing
