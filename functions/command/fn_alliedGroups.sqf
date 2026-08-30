/*
	Function: TACT_fnc_alliedGroups

	Description:
		Resolves the groups on the battlefield that are fighting ALONGSIDE the
		player but are not his - CSAT, in section 8's terms - so the command
		layer can draw each of them as a single icon over its leader.

		The other half of the tactical map's visibility rule; TACT_fnc_playerGroups
		is the first. The split between them is not cosmetic and is not about
		allegiance: both are friendly, and neither is drawn man by man. It is
		about control.

		  player groups  his side. Not his to order today, but the command
		                 layer could give them orders tomorrow - a detached
		                 half of his own group is the case group-level command
		                 exists for.
		  allied groups  somebody else's army, on somebody else's side. Never
		                 his to order, at any point. CSAT is a patron, not a
		                 subordinate; the player's leverage over it is CSAT
		                 Favor spent between blocks, not a move order on a map.

		Keeping them apart means the day group-level command arrives, it widens
		to one of these lists and provably cannot reach the other.

		Allied means friendly to the engine and on a different side. Read from
		`getFriend` rather than from the faction stamp, for the reason
		TACT_fnc_playerGroups reads side: a stamp answers for a group that
		deployment created and for nothing else, and the engine relation is the
		same decision the `setFriend` block in init.sqf writes. Section 8 says
		those two are halves of one thing; this is the half that reads.

		CIVILIAN is excluded explicitly. Civilians are default-friendly to every
		side and would otherwise pass the relation test whole - the campaign
		avatar first, and eventually every civilian on Tanoa that the NATO
		Aggression meter exists to measure against. They are not allies; they
		are the terrain the war is fought in.

		The threshold is 0.6, the same figure the engine reads as friendly and
		the same one init.sqf writes its blocs around as the extremes 0 and 1.
		Nothing is expected to sit between them; the comparison is written
		against the engine's own line rather than against `== 1` so a future
		partial relation lands on the side the engine would put it.

		No spatial filter is needed to mean "in this battle", for the reason
		given in TACT_fnc_playerGroups: an army outside a battle has never
		spawned.

		Rebuilt every frame, like the rest of the command layer.

	Group keys:
		group   GROUP  - the group itself
		leader  OBJECT - what the icon is drawn over
		anchor  ARRAY  - the leader's position, read once for the frame
		men     ARRAY  - its living members
		faction STRING - allegiance, for the icon silhouette and labels. NOT the
		                 colour source: the command layer colours by role. An
		                 ally always comes from TACT_fnc_deployMen and so always
		                 carries a stamp; the empty fallback draws the unknown
		                 silhouette rather than asserting a faction that was
		                 never recorded.

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
