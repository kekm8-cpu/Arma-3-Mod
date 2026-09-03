/*
	Function: TACT_fnc_alliedGroups

	Description:
		Resolves the groups on the battlefield that are fighting ALONGSIDE the
		player but are not his - CSAT - so the command layer can draw each of
		them as a single icon over its leader.

		The other half of the tactical map's visibility rule;
		TACT_fnc_playerGroups is the first and carries the split. These are the
		groups the command layer will NEVER order: CSAT is a patron, not a
		subordinate, and the player's leverage over it is Favor spent between
		blocks rather than a move order on a map.

		Allied means friendly to the engine and on a different side. Read from
		`getFriend` rather than from the faction stamp, for the reason
		TACT_fnc_playerGroups reads side - and because the engine relation is
		the reading half of the `setFriend` decision init.sqf writes.

		CIVILIAN IS EXCLUDED EXPLICITLY. Civilians are default-friendly to every
		side and would otherwise pass the relation test whole: the campaign
		avatar first, and eventually every civilian the NATO Aggression meter
		exists to measure against.

		The threshold is 0.6, the figure the engine itself reads as friendly.
		Written against the engine's line rather than `== 1`, so a future
		partial relation lands where the engine would put it.

		No spatial filter is needed to mean "in this battle" - an army outside
		one has never spawned. Rebuilt every frame, like the rest of the layer.

	Group keys:
		group   GROUP  - the group itself
		leader  OBJECT - what the icon is drawn over
		anchor  ARRAY  - the leader's position, read once for the frame
		men     ARRAY  - its living members
		faction STRING - the key both draw tables are read with. An ally always
		                 comes from TACT_fnc_deployMen and so always carries a
		                 stamp; the empty fallback draws the unknown grey rather
		                 than asserting a faction never recorded.

	Parameters:
		none

	Returns:
		ARRAY of HASHMAP - one per allied group on the field.
*/

private _groups = [];

if (isNull player) exitWith { _groups };

private _playerGroup = group player;
if (isNull _playerGroup) exitWith { _groups };

private _playerSide = side _playerGroup;

{
	private _group = _x;
	private _side  = side _group;

	if (
		_side != _playerSide
		&& {_side != civilian}
		&& {(_side getFriend _playerSide) > 0.6}
	) then {

		// Excluded by name as well as by side. The avatar is CIVILIAN and is
		// already out on the line above; this is the backstop for the day it
		// is moved onto a combatant side again.
		private _men = (units _group) select {
			alive _x
			&& {_x != player}
			&& {isNull TACT_campaignAvatar || {_x != TACT_campaignAvatar}}
		};

		if (count _men > 0) then {

			// Over the leader, falling back to any living member for the frame
			// in which a leader has been killed and the engine has not promoted
			// a replacement yet.
			private _leader = leader _group;
			if (isNull _leader || {!alive _leader} || {!(_leader in _men)}) then {
				_leader = _men select 0;
			};

			// Read once and shared by every item in the group, as everywhere
			// else in the draw layers: getPosATL returns a fresh array per call
			// and two reads is two anchors. The vehicle rather than the man,
			// because a mounted leader is at his vehicle's position.
			_groups pushBack (createHashMapFromArray [
				["group", _group],
				["leader", _leader],
				["anchor", getPosATL (vehicle _leader)],
				["men", _men],
				["faction", _group getVariable ["STRAT_faction", ""]]
			]);
		};
	};
} forEach allGroups;

_groups
