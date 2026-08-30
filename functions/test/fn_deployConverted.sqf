/*
	Function: TEST_fnc_deployConverted

	Description:
		Deploys an army's men dismounted, spawning them into a holding group on
		the side their CLASSES are configured on and joining them across into a
		permanent group on the side the army actually fights on, under a
		higher-ranked anchor of that side.

		This exists because createUnit does not put a man on his group's side.
		A group created on INDEPENDENT and filled with B_ classes produces men
		who are in an INDEPENDENT group and behave as WEST: with `independent
		setFriend [west, 0]` in init.sqf they are hostile to their own squad,
		and the first drill run ended with four men shooting each other. The
		roster table's "cosmetic only, since createUnit takes the group's side"
		was wrong.

		Matching every roster's classes to its side is the obvious fix and the
		expensive one - it costs the project every unit class it does not own.
		The cartel is where that bites: drugLords sits on WEST and wants
		Syndikat, which the game configures as INDEPENDENT, and there is no
		WEST-configured cartel to fall back on. This is the fix that costs
		nothing instead.

		THE ORDER IS THE TECHNIQUE. Every step is load-bearing and none of them
		commute:

		  1  permanent group   on the side the army fights on
		  2  anchor into it    a class genuinely OF that side, ranked COLONEL
		  3  holding group     on the side the men's classes are configured on
		  4  men into holding  spawned there, never into the permanent group
		  5  men join across   the join is what carries them onto the new side
		  6  scaffolding out   anchor deleted, holding group deleted

		Step 4 is the one that separates this from converting men after the
		fact. A unit is stamped when it is created, so a man created in the
		permanent group has already been got wrong by the time anything could
		join him anywhere - the join has to be his first. That is also why
		this cannot be done by calling TACT_fnc_deployMen and fixing up
		afterwards: deployment creates its men directly in the destination
		group, which is exactly the move that does not work.

		Step 2 before step 4 for a duller reason: the anchor gives the
		permanent group somebody to hold it open. A group with no units in it
		is a group the engine may collect, and the destination has to still be
		there when the men arrive.

		DISMOUNTED ONLY. There is no vehicle rotation here and no mounting
		pass. A drill roster carries no transport by design - a mounted man
		resolves to his vehicle and the map would draw fewer icons than there
		are men - so the case does not arise, and duplicating the seat logic to
		support a case nothing uses would be the wrong kind of thorough. An
		army with vehicles on its roster is deployed on foot and says so.

		Harness code, and a technique on trial. If the drill proves it, this is
		what gets folded into TACT_fnc_deployMen so every army gets it and the
		roster tables can go back to being about what a force looks like rather
		than which side the engine will let it be on.

	Parameters:
		0: HASHMAP - army record
		1: ARRAY   - deployment position
		2: NUMBER  - deployment bearing, degrees

	Returns:
		GROUP - the permanent group, on the army's own side. Empty group if the
		        army has no men.
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_deployPos", [0,0,0], [[]]],
	["_deployDir", 0, [0]]
];

private _faction = _army getOrDefault ["faction", "player"];
private _side    = _faction call STRAT_fnc_factionSide;

// ------------------------------------------------------------------------ //
// 1. THE PERMANENT GROUP                                                    //
// ------------------------------------------------------------------------ //
private _permanent = createGroup [_side, true];

if (isNull _permanent) exitWith {
	diag_log "TEST Deploy: could not create the permanent group.";
	grpNull
};

// Stamped exactly as TACT_fnc_deployMen stamps its group. The command map
// reads STRAT_faction off the player's group to colour his men, and sync-back
// and the draw layer both expect an army id to be reachable from a live group.
_permanent setVariable ["STRAT_faction", _faction];
_permanent setVariable ["STRAT_armyId", _army getOrDefault ["id", ""]];

private _menArray = _army getOrDefault ["men", []];
if (count _menArray == 0) exitWith { _permanent };

if (count (_army getOrDefault ["vehicles", []]) > 0) then {
	diag_log format [
		"TEST Deploy: %1 has vehicles on its roster; a drill deploys on foot and they are left unplaced.",
		_army getOrDefault ["name", "?"]
	];
};

// ------------------------------------------------------------------------ //
// 2. THE ANCHOR                                                             //
// ------------------------------------------------------------------------ //
private _anchorClass = TEST_sideAnchorClass getOrDefault [str _side, ""];

if (_anchorClass == "") exitWith {
	diag_log format ["TEST Deploy: no anchor class for side %1.", _side];
	_permanent
};

private _anchor = _permanent createUnit [_anchorClass, _deployPos, [], 0, "NONE"];

if (isNull _anchor) exitWith {
	diag_log format ["TEST Deploy: could not create anchor '%1'.", _anchorClass];
	_permanent
};

// Above every rank a config can carry, so it outranks the men whatever their
// classes declare - B_T_Soldier_SL_F is a SERGEANT, and a squad leader who
// outranked the anchor would defeat the whole thing.
_anchor setUnitRank "COLONEL";
_permanent selectLeader _anchor;

_anchor hideObject true;
_anchor allowDamage false;

// ------------------------------------------------------------------------ //
// 3. THE HOLDING GROUP                                                      //
// ------------------------------------------------------------------------ //
// On the side the men's classes are configured on - the side they would
// otherwise behave as - read from config rather than assumed, so this works
// for a cartel roster on WEST as readily as for mercenaries on INDEPENDENT.
// CfgVehicles >> side: 0 EAST, 1 WEST, 2 GUER, 3 CIVILIAN.
//
// Read off the class rather than off a unit, because at this point there are
// no units yet - which is the whole point of the ordering.
private _firstClass = (_menArray select 0) getOrDefault ["className", ""];
private _configSides = [east, west, independent, civilian];
private _configSide = _configSides param [
	getNumber (configFile >> "CfgVehicles" >> _firstClass >> "side"),
	_side
];

// deleteWhenEmpty false: this group is emptied on purpose at step 5, and a
// group that deletes itself out from under step 6 is a null reference waiting
// to be tidied up.
private _holding = createGroup [_configSide, false];

if (isNull _holding) exitWith {
	diag_log "TEST Deploy: could not create the holding group.";
	deleteVehicle _anchor;
	_permanent
};

// ------------------------------------------------------------------------ //
// 4. THE MEN, INTO THE HOLDING GROUP                                        //
// ------------------------------------------------------------------------ //
// Marching order and formation geometry are TACT_fnc_deployMen's, unchanged:
// the leader heads the file, then everyone else in roster order, laid out in
// files of TACT_deployFootWidth with each rank one TACT_deployFootDepth
// further back along the reverse of the bearing.
private _leaderData = createHashMap;
private _ordered = [];

{
	if (_x getOrDefault ["isLeader", false] && {count _leaderData == 0}) then {
		_leaderData = _x;
	} else {
		_ordered pushBack _x;
	};
} forEach _menArray;

if (count _leaderData > 0) then { _ordered insert [0, [_leaderData]] };

// Flattened to ground level. An army's `location` is a strategic position and
// carries whatever height it was authored with; a slot built off a non-zero z
// spawns the man in the air and drops him.
_deployPos = [_deployPos param [0, 0, [0]], _deployPos param [1, 0, [0]], 0];

private _fwd   = [sin _deployDir, cos _deployDir, 0];
private _right = [cos _deployDir, -(sin _deployDir), 0];

private _fileWidth = if (isNil "TACT_deployFootWidth") then {2} else {TACT_deployFootWidth};
if (_fileWidth < 1) then { _fileWidth = 1 };

private _lateral = if (isNil "TACT_deployFootSpacing") then {6} else {TACT_deployFootSpacing};
private _depth   = if (isNil "TACT_deployFootDepth") then {8} else {TACT_deployFootDepth};

private _physicalLeader = objNull;
private _spawned = [];

{
	private _soldierData = _x;

	private _rank = floor (_forEachIndex / _fileWidth);
	private _file = _forEachIndex % _fileWidth;

	private _offsetRight = ((_file - ((_fileWidth - 1) / 2)) * _lateral);
	private _offsetBack  = -(_rank * _depth);

	private _slotPos = _deployPos
		vectorAdd (_right vectorMultiply _offsetRight)
		vectorAdd (_fwd vectorMultiply _offsetBack);

	// Into the HOLDING group. This is the line the whole function is arranged
	// around: the man's first group is one that agrees with his class, so the
	// join at step 5 is the first thing that ever tells the engine otherwise.
	private _unit = _holding createUnit [_soldierData get "className", _slotPos, [], 0, "NONE"];

	if (!isNull _unit) then {
		_soldierData set ["obj", _unit];
		_spawned pushBack _unit;

		_unit setDir _deployDir;
		_unit setDamage (1 - (_soldierData getOrDefault ["health", 1]));
		_unit setSkill (_soldierData getOrDefault ["skill", 0.5]);

		if (_soldierData getOrDefault ["isLeader", false]) then { _physicalLeader = _unit };
	};
} forEach _ordered;

// ------------------------------------------------------------------------ //
// 5. ACROSS                                                                 //
// ------------------------------------------------------------------------ //
if (count _spawned > 0) then {
	_spawned joinSilent _permanent;
};

// ------------------------------------------------------------------------ //
// 6. THE SCAFFOLDING BACK OUT                                               //
// ------------------------------------------------------------------------ //
// The leader first, then the anchor. Deleting the leader and letting the
// engine pick a replacement would hand the group to whoever it liked rather
// than to the man the roster named.
if (!isNull _physicalLeader && {_physicalLeader in (units _permanent)}) then {
	_permanent selectLeader _physicalLeader;
};

deleteVehicle _anchor;

if (!isNull _holding) then { deleteGroup _holding };

// setFormDir gives the group a front to form on, which otherwise defaults to
// whatever bearing the engine picks off the leader.
_permanent setFormDir _deployDir;

diag_log format [
	"TEST Deploy: %1 put %2 men on the ground as %3 via a %4 anchor (classes are configured %5).",
	_army getOrDefault ["name", "?"],
	count _spawned,
	_side,
	_anchorClass,
	_configSide
];

_permanent
