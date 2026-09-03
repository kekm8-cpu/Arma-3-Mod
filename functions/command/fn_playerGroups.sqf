/*
	Function: TACT_fnc_playerGroups

	Description:
		Resolves the groups on the battlefield that are the PLAYER'S OWN SIDE
		but are NOT the group he is standing in, so the command layer can draw
		each of them as a single icon over its leader.

		One half of the tactical map's visibility rule; TACT_fnc_alliedGroups is
		the other. The split between them is about CONTROL, not allegiance:
		these are groups the command layer could one day order - a detached half
		of his own group is the case group-level command exists for - and an
		ally's never will be. Keeping the lists apart means that widening
		reaches one and provably cannot reach the other.

		The player's own group is EXCLUDED rather than collapsed: its members
		are already drawn individually by TACT_fnc_commandEntities, so a group
		icon would draw the same men twice.

		SIDE, NOT THE FACTION STAMP, because the stamp cannot answer this
		question: a group the player detaches is created by the engine, not by
		TACT_fnc_deployMen, so it carries no stamp and never will - and it is
		the case this rule exists for. `side (group player)` rather than a
		literal `independent`, so the rule follows whoever the player is.

		A narrower question than STRAT_fnc_areHostile's, and both are live:
		hostility between armies is read from `faction`, and which groups are
		the player's own on the field is read from `side`.

		No spatial filter is needed to mean "in this battle" - the strategic
		layer never spawns, so every group standing on a map is in the fight by
		construction. The campaign avatar is excluded by name as a backstop; it
		fails the side test already.

		Rebuilt every frame: groups take casualties and lose leaders mid-battle,
		and a cached list is how the drawn and the real start to disagree.

	Group keys:
		group   GROUP  - the group itself
		leader  OBJECT - what the icon is drawn over
		anchor  ARRAY  - the leader's position, read once for the frame
		men     ARRAY  - its living members
		faction STRING - the key both draw tables are read with. Resolved HERE
		                 rather than at draw time, so the detached group - which
		                 the engine creates without a stamp - reaches the draw
		                 already wearing the faction it came out of.

	Parameters:
		none

	Returns:
		ARRAY of HASHMAP - one per group on the player's side, excluding his own.
*/

private _groups = [];

if (isNull player) exitWith { _groups };

private _playerGroup = group player;
if (isNull _playerGroup) exitWith { _groups };

private _playerSide = side _playerGroup;

// A detached group has no stamp of its own and takes the player's, which is
// correct by construction - it came out of his group - and is the fallback
// rather than the rule, so a reinforcing army that carries its own stamp keeps
// its own colour and silhouette.
private _playerFaction = _playerGroup getVariable ["STRAT_faction", "player"];

{
	private _group = _x;

	if (_group != _playerGroup && {side _group == _playerSide}) then {

		// The campaign avatar is alive, in a group, and standing where the
		// player left the strategic map with its simulation switched off. It is
		// the body he came from, not a unit in this battle, and an icon for it
		// would sit hundreds of kilometres off the fight.
		private _men = (units _group) select {
			alive _x
			&& {_x != player}
			&& {isNull TACT_campaignAvatar || {_x != TACT_campaignAvatar}}
		};

		if (count _men > 0) then {

			// Over the leader, which is where a group is by convention. A group
			// that has lost its leader this frame - killed, and the engine has
			// not promoted a replacement yet - falls back to any living member
			// rather than dropping off the map.
			private _leader = leader _group;
			if (isNull _leader || {!alive _leader} || {!(_leader in _men)}) then {
				_leader = _men select 0;
			};

			// getPosATL returns a fresh array per call, so this is read once and
			// shared by every item in the group - the same guarantee the command
			// entities get.
			//
			// The vehicle rather than the man: a mounted leader is at his
			// vehicle's position, and that is the thing visible on the ground.
			_groups pushBack (createHashMapFromArray [
				["group", _group],
				["leader", _leader],
				["anchor", getPosATL (vehicle _leader)],
				["men", _men],
				["faction", _group getVariable ["STRAT_faction", _playerFaction]]
			]);
		};
	};
} forEach allGroups;

_groups
