/*
	Function: TACT_fnc_clearRoute

	Description:
		Deletes every waypoint a group has, completed ones included, and -
		when asked - halts it where it stands.

		Two callers, one clear. TACT_fnc_issueGroupRoute clears before it
		replaces, so a new route starts from nothing, and does NOT ask for the
		halt: a new destination follows in the same call and a halt in between
		is an order the group would have to notice and then discard.
		TACT_fnc_onCommandKey's Backspace clears AND halts, which is the
		group's STOP - the order a body of men had no way to take until this
		existed, since a group with no route left could not be told to hold
		except by clicking a waypoint on top of it.

		From the highest index down: deleting a waypoint renumbers the ones
		after it, and a loop walking upwards would skip every other one.

		AN EMPTY CHAIN DOES NOT HALT THE LEADER. Played: he carries on to the
		spot the deleted waypoint was at, because deleting the waypoint does
		not take back the movement it already gave him. So the halt is a move
		order to his own position - to the group, so the men in formation
		close on him rather than on the place he was going - which is complete
		the moment it is given and leaves nothing standing in front of the
		next route.

	Parameters:
		0: GROUP - the group
		1: BOOL  - true to halt the group where it stands (default true)

	Returns:
		NUMBER - how many waypoints were deleted.
*/

params [
	["_group", grpNull, [grpNull]],
	["_halt", true, [true]]
];

if (isNull _group) exitWith { 0 };

private _existing = waypoints _group;

for "_i" from (count _existing - 1) to 0 step -1 do {
	deleteWaypoint (_existing select _i);
};

if (_halt) then {
	private _leader = leader _group;

	if (!isNull _leader && {alive _leader}) then {
		_group move (getPosATL (vehicle _leader));
	};
};

count _existing
