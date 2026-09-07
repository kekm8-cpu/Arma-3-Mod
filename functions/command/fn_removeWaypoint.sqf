/*
	Function: TACT_fnc_removeWaypoint

	Description:
		Deletes one waypoint from a group's route, by the index the engine
		knows it by, and keeps the group walking the route that is left.

		Both keys come through here: Backspace with the last remaining index,
		Delete with the index of the dot under the cursor. One deletion, one
		place that knows what deleting does to the rest of the chain.

		Deleting a waypoint renumbers the ones after it, so the index of the
		one the group is walking to now names the one that used to be next.
		That is what makes a deleted CURRENT waypoint safe - the group is
		already pointed at its replacement - but the engine does not
		necessarily re-read a destination it thinks it already has. So the
		group is re-pointed at whatever is now first in its remaining route,
		which is a no-op when a later waypoint was deleted and a re-plan when
		the current one was. A group whose last waypoint was deleted is left
		with nothing to walk to, and stops.

		The index is matched against the live list rather than trusted: the
		list a dot was drawn from is a frame old, and a waypoint the group
		completed in between is not one to delete.

	Parameters:
		0: GROUP  - the group
		1: NUMBER - waypoint index

	Returns:
		BOOL - true if a waypoint was deleted.
*/

params [
	["_group", grpNull, [grpNull]],
	["_index", -1, [0]]
];

if (isNull _group || {_index < 0}) exitWith { false };

private _live = (waypoints _group) select {(_x select 1) == _index};
if (count _live == 0) exitWith { false };

deleteWaypoint (_live select 0);

private _route = [_group] call TACT_fnc_groupRoute;

if (count _route > 0) then {
	_group setCurrentWaypoint [_group, (_route select 0) select 0];
};

true
