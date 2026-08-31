/*
	Function: TACT_fnc_splitGroup

	Description:
		Splits the selected command entities out of the player's group into a
		group of their own. The detach that section 14 names as group-level
		command's first prerequisite, done as an explicit act on the map rather
		than implicitly on ordering - so the split has a visible result and a
		stray click cannot fragment a squad.

		Two or more entities, always. One entity is not a body of men, and a
		group of one is a thing the player would have to put back together
		before he could use the stock interface on it again.

		Everything the entities ACCOUNT FOR moves, not just what takes orders.
		An entity's `men` is the group's soldiers it stands for - for a truck
		that is every one of ours riding in it - and detaching a truck while
		leaving its passengers in the commander's group would produce two
		groups sharing a vehicle and a formation neither can hold.

		The player never moves. He is never an entity, so he cannot be
		selected, so he cannot be in the set - but it is checked rather than
		assumed, because a commander who detaches himself is a commander with
		no group, and the failure would be silent.

		The new group is created `deleteWhenEmpty`, exactly as TACT_fnc_deployMen
		creates an army's, so the engine takes it away when its last man dies
		or rejoins. Nothing has to remember to tear it down on the ordinary
		paths; TACT_fnc_concludeBattle sweeps the list only as a backstop.

		It carries the parent group's STRAT_faction stamp, so the draw layer
		reads it from the group rather than falling back. TACT_fnc_playerGroups
		would resolve an unstamped group to the player's own faction anyway -
		that fallback exists precisely for the group the engine creates here -
		but a stamp that is set is a stamp that cannot be got wrong by a fourth
		caller later.

		Behaviour, combat mode, formation and speed are copied off the parent.
		A detachment that came out of a squad moving cautiously should not
		revert to whatever the engine's defaults are the moment it becomes its
		own group; the men did not change their minds about the battle they are
		standing in.

		The men are then told to follow their new leader, which both closes them
		up as a squad and clears any `doStop` or `doMove` the map had left on
		them as individuals. A detachment forms up where it stands.

		WHAT THIS DOES NOT DO YET. The detachment stops being command entities
		the same frame - it is another group on the player's side, so
		TACT_fnc_playerGroups picks it up and it draws as one collapsed icon.
		That icon is SELECTABLE: his own collapsed groups carry a hit area and
		a ring, and this function hands the new group straight into
		TACT_commandGroupSelection so it is selected the moment it exists.
		What it is not is ORDERABLE. Selecting a group does not order it - a
		body of men has no map order until waypoints exist - and it is out of
		reach of the stock F-key interface too, which addresses one group. So a
		detachment forms up where it is split and holds there.

		That last gap is deliberately not smuggled in here; the player is told
		as much when he splits, because a unit that stops answering without
		saying so reads as a bug.

	Parameters:
		0: ARRAY - command entities (see TACT_fnc_commandEntities)

	Returns:
		GROUP - the new group, or grpNull if nothing was split.
*/

params [
	["_entities", [], [[]]]
];

if (count _entities < 2) exitWith { grpNull };

private _playerGroup = group player;
if (isNull _playerGroup) exitWith { grpNull };

// Every man the selection accounts for, once. Two entities cannot share a man
// - a rider belongs to the vehicle he is in and to nothing else - but the
// check costs one comparison and `join` on a duplicate is a silent no-op that
// would make the reported count wrong.
private _men = [];
{
	{
		if (alive _x && {_x != player} && {group _x == _playerGroup} && {!(_x in _men)}) then {
			_men pushBack _x;
		};
	} forEach (_x get "men");
} forEach _entities;

if (count _men == 0) exitWith { grpNull };

private _new = createGroup [side _playerGroup, true];
if (isNull _new) exitWith {
	// The engine's group cap. Rare, but it is a real limit and a null group
	// would take the men nowhere while reporting success.
	systemChat "No group could be created for the detachment.";
	grpNull
};

if (isNil "TACT_commandDetachCount") then { TACT_commandDetachCount = 0 };
TACT_commandDetachCount = TACT_commandDetachCount + 1;

_new setGroupId [format ["Det %1", TACT_commandDetachCount]];
_new setVariable ["STRAT_faction", _playerGroup getVariable ["STRAT_faction", "player"]];

// Read BEFORE the join, so none of it is read off a group these men have
// already left.
//
// Behaviour comes off one of the detached men rather than off the group's
// leader, because that leader is the player and a player has no meaningful
// behaviour state - he is not the one who has been moving cautiously for the
// last ten minutes. The other three are group properties the player set
// himself through the stock UI, so they come off the group.
private _behaviour = behaviour (_men select 0);
private _combat    = combatMode _playerGroup;
private _formation = formation _playerGroup;
private _speed     = speedMode _playerGroup;

_men join _new;

_new setBehaviour _behaviour;
_new setCombatMode _combat;
_new setFormation _formation;
_new setSpeedMode _speed;

// Form up on their own leader, which is also what clears whatever the map last
// told them to do as individuals.
private _leader = leader _new;
{
	if (_x != _leader) then { _x doFollow _leader };
} forEach (units _new);

if (isNil "TACT_commandDetachments") then { TACT_commandDetachments = [] };
TACT_commandDetachments pushBack _new;

// The selection FOLLOWS THE MEN across the split. They stop being entities and
// become a group, so they come out of the entity container and the group they
// became goes into the group one - which is the whole point of the selection
// being two containers and one concept. The player selected these men, split
// them, and they are still what is selected; he just cannot order them yet.
//
// Cleared here rather than left to the next click's prune, so the rings move
// the frame the split happens rather than a click later.
private _objs = _entities apply {_x get "obj"};
TACT_commandSelection = TACT_commandSelection select {!(_x in _objs)};

if (isNil "TACT_commandGroupSelection") then { TACT_commandGroupSelection = [] };
TACT_commandGroupSelection pushBack _new;

// Said, not swallowed. See the header: a detachment cannot be ordered again
// yet, and a unit that stops answering without saying why reads as a bug.
systemChat format [
	"%1 detached - %2 men. Selectable, but not orderable yet: they hold where they form up.",
	groupId _new,
	count _men
];

_new
