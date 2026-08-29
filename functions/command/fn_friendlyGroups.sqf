/*
	Function: TACT_fnc_friendlyGroups

	Description:
		Resolves the friendly groups on the battlefield that are NOT the
		player's own, so the command layer can draw each of them as a single
		icon over its leader.

		This is the other half of the tactical map's visibility rule. The
		player's group is shown man by man because it is the thing he commands
		and every icon in it is a click target. Everyone else on his side is
		shown as one icon per group, because their internal composition is not
		his to arrange - it is somebody else's group - and drawing forty allied
		soldiers individually buries his own eight.

		The player's group is excluded rather than collapsed. Its members are
		already drawn individually by TACT_fnc_commandEntities, so emitting a
		group icon for it too would draw the same men twice: once as the units
		he orders and once as a body he does not.

		Allegiance comes from `faction`, never from the engine's side. Section
		12 makes `faction` the source of truth and the bloc table is why: it
		puts player and CSAT in the same bloc while STRAT_fnc_factionSide puts
		them on INDEPENDENT and EAST, so a side comparison would draw an ally
		as an enemy and never notice. A live group carries no route back to its
		army record, so TACT_fnc_deployMen stamps the faction on the group and
		this reads it back.

		A group with no faction stamp is skipped rather than guessed at. It was
		not created by deployment - an editor-placed unit, something a test
		spawned by hand - and inventing an allegiance for it would put an icon
		of unknown meaning on the map. Skipped silently, because this runs
		every frame and a log line here is a log file.

		Rebuilt every frame, for the same reason the entity list is: groups
		take casualties and lose leaders mid-battle, and a cached list is how
		the drawn and the real start to disagree.

	Group keys:
		group   GROUP  - the group itself
		leader  OBJECT - what the icon is drawn over
		anchor  ARRAY  - the leader's position, read once for the frame
		men     ARRAY  - its living members
		faction STRING - allegiance, for colour and icon

	Parameters:
		none

	Returns:
		ARRAY of HASHMAP - one per friendly group, excluding the player's.
*/

private _groups = [];

if (isNull player) exitWith { _groups };

private _playerGroup = group player;
if (isNull _playerGroup) exitWith { _groups };

// The player's own allegiance, from the same stamp every other group is read
// through. Without it there is nothing to compare against, and a friend/enemy
// test that cannot name one of its sides must not guess at the other.
private _playerFaction = _playerGroup getVariable ["STRAT_faction", ""];
if (_playerFaction == "") exitWith { _groups };

{
	private _group = _x;

	if (_group != _playerGroup) then {
		private _faction = _group getVariable ["STRAT_faction", ""];

		if (_faction != "" && {!([_faction, _playerFaction] call STRAT_fnc_areHostile)}) then {

			// The campaign avatar is alive, in a group, and standing on the
			// far side of the island with its simulation switched off. It is
			// the body the player came from, not a unit in this battle, and
			// an icon for it would sit hundreds of kilometres off the fight.
			private _men = (units _group) select {
				alive _x
				&& {_x != player}
				&& {isNull TACT_campaignAvatar || {_x != TACT_campaignAvatar}}
			};

			if (count _men > 0) then {

				// Over the leader, which is where a group is by convention.
				// A group that has lost its leader this frame - killed, and
				// the engine has not promoted a replacement yet - falls back
				// to any living member rather than dropping off the map.
				private _leader = leader _group;
				if (isNull _leader || {!alive _leader} || {!(_leader in _men)}) then {
					_leader = _men select 0;
				};

				// getPosATL returns a fresh array per call, so this is read
				// once and shared by every item in the group - the same
				// guarantee the command entities get.
				//
				// The vehicle rather than the man: a mounted leader is at his
				// vehicle's position, and that is the thing visible on the
				// ground.
				_groups pushBack (createHashMapFromArray [
					["group", _group],
					["leader", _leader],
					["anchor", getPosATL (vehicle _leader)],
					["men", _men],
					["faction", _faction]
				]);
			};
		};
	};
} forEach allGroups;

_groups
