/*
	Function: TACT_fnc_friendlyGroups

	Description:
		Resolves the friendly groups on the battlefield that are NOT the
		player's own, so the command layer can draw each of them as a single
		icon over its leader.

		This is the other half of the tactical map's visibility rule. The
		player's group is shown man by man because it is the thing he commands
		and every icon in it is a click target. Everything else on his side is
		shown as one icon per group, because its internal composition is not his
		to arrange from where he stands, and drawing forty allied soldiers
		individually buries his own eight.

		The player's group is excluded rather than collapsed. Its members are
		already drawn individually by TACT_fnc_commandEntities, so emitting a
		group icon for it too would draw the same men twice: once as the units
		he orders and once as a body he does not.

		Friendly means the player's own side. That is what these groups have in
		common - a half of his group he detached, a second contractor army that
		arrived to reinforce him, a garrison of his faction holding the ground
		being fought over. All of them are his side's, none of them is the group
		he is standing in, and every one of them is something he is drawn into
		the battle alongside rather than against.

		Side rather than the faction stamp, deliberately, because the stamp
		cannot answer this question. A group the player detaches is created by
		the engine at the moment he splits it, not by TACT_fnc_deployMen, so it
		carries no stamp and never will - and it is the case this rule exists
		for. Side is what a detached group inherits for free, which is exactly
		the property needed. `side (group player)` rather than a literal
		`independent`, so the rule follows whoever the player is instead of
		asserting who he must be. Those are the same side today: only the
		player's faction maps to INDEPENDENT.

		This is a narrower question than the one STRAT_fnc_areHostile answers,
		and both are live. Hostility between armies decides who fights, and is
		read from `faction` because the bloc table is the source of truth for
		it. Which groups the player commands or fights beside is decided on the
		field, where a detached half of his own group has to count and has
		nothing but its side to say so with.

		No spatial filter is needed to mean "in this battle". An army outside a
		battle is a record with `obj` set to objNull - the strategic layer never
		spawns - so every friendly group standing on a map is in the fight by
		construction. The one exception is the campaign avatar, which is alive,
		hidden, and on the far side of the island, and is excluded by name.

		Rebuilt every frame, for the same reason the entity list is: groups take
		casualties and lose leaders mid-battle, and a cached list is how the
		drawn and the real start to disagree.

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

private _playerSide = side _playerGroup;

// Presentation only. A detached group has no stamp of its own and takes the
// player's, which is correct by construction - it came out of his group - and
// is the fallback rather than the rule, so a reinforcing army that carries its
// own stamp is drawn in its own colours.
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
