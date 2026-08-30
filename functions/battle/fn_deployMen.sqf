/*
	Function: TACT_fnc_deployMen

	Description:
		Spawns an army's infantry roster onto the tactical grid at a given
		deployment point and bearing, mounting as much of it as the deployed
		vehicles have seats for and leaving the rest on foot.

		Every man is put on the ground first and mounted afterwards. That
		ordering is the whole of build plan 2.2: the old version created each
		unit at [0,0,0] and relied on `moveInAny` to move him somewhere real,
		so an army with no vehicles deployed nobody and a man the rotation
		could not seat was left standing at map origin. Placement is now the
		unconditional step and mounting is subtraction from a state that was
		already valid, which makes infantry-only a roster with an empty
		rotation rather than a case to branch on.

		Every man is spawned into a HOLDING GROUP on the side his class is
		configured on and joined across into the army's own group under a
		rank anchor, because createUnit does not put a man on the side of the
		group it creates him in. That is a workaround for an engine behaviour,
		not a design choice, and it is documented in full under SQF Quirks and
		Workarounds in PROJECT_MANIFEST.md. Section 5b below is the mechanism
		and the ordering constraints that make it work.

		Seats are filled front-first, so the leader takes the head vehicle and
		the tail of the roster walks. The dismounted remainder stays in the
		same group as the mounted element - one army is one group, which is
		what fn_resolveVictory, fn_syncBack and fn_dropIn all read - and
		TACT_fnc_commandEntities already resolves a mixed group into trucks
		and men on foot without knowing how it got that way.

		The foot formation is a staggered file laid out *behind* the
		deployment point, along the reverse of the deployment bearing.
		fn_deployVehicles lays its column out forward from the same point, so
		the infantry falls in behind its own transport rather than inside it.

		A group that ends up carrying both trucks and men on foot has its
		vehicles capped to foot pace with `limitSpeed`, because one group gets
		one `move` order and an uncapped truck answers it at four times the
		speed of the men walking behind it. The rule is that the column moves
		at the pace of the slowest thing in the group, which is why this is not
		a branch on deployment type: a fully mounted group's slowest thing is a
		vehicle, so it is capped by nothing and behaves exactly as before.

		The cap stands for the battle rather than being lifted on contact.
		Letting the trucks off the leash once shooting starts sounds like it
		would buy back a breakthrough, and it does not - breakthrough is
		classified off the group's centroid crossing the boundary, and in a
		mixed group the centroid is pinned by the foot element whatever the
		trucks do. An uncapped truck produces a truck outside the boundary and
		a centroid still inside it.

		Deployment point and bearing are parameters rather than derived here.
		Today fn_initiateBattle passes the army's own position and the bearing
		to the anchor, which is what `midpointConverge` means; edge deployment
		facing the destination bearing (section 10.1) changes that one call
		site and nothing in here.

	Parameters:
		0: HASHMAP - army object
		1: ARRAY   - deployment point, the head of the formation
		2: NUMBER  - deployment bearing in degrees, the direction men face

	Returns:
		GROUP - the created group. Empty of units only if the roster is empty.
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_deployPos", [0,0,0], [[]]],
	["_deployDir", 0, [0]]
];

// 1. Determine the Arma side from the "faction" attribute. The faction->side
// map is section 8's, and it lives in one place so garrison deployment and the
// test harness cannot drift from it.
private _faction = _army getOrDefault ["faction", "player"];
private _side = _faction call STRAT_fnc_factionSide;

// Create the unified group for this army
private _grp = createGroup [_side, true];

// Stamp the army this group was spawned from onto the group. A live group
// carries no route back to its record otherwise, and `faction` in particular is
// wanted by the map, which draws a group in its faction's colour and icon.
//
// Not an allegiance test, and it must not be used as one. The tactical map
// decides which groups are the player's side from `side`, because a group he
// detaches mid-battle is made by the engine and never comes through here - it
// has no stamp, and inherits its side for free. Hostility between armies is the
// question `faction` answers, through STRAT_fnc_areHostile.
_grp setVariable ["STRAT_faction", _faction];
_grp setVariable ["STRAT_armyId", _army getOrDefault ["id", ""]];

// 2. The roster. An army with no men deploys nobody, and that is the only
// condition under which this returns an empty group - having no vehicles is
// no longer one of them.
private _menArray = _army getOrDefault ["men", []];
if (count _menArray == 0) exitWith { _grp };

// 3. Vehicles that actually made it onto the ground, front of the column
// first. fn_deployVehicles leaves `obj` null for anything it did not place -
// a vehicle the roster has no driver for - so this reads what is there rather
// than what was ordered.
private _deployed = [];
{
	private _vehObj = _x getOrDefault ["obj", objNull];
	if (!isNull _vehObj && {alive _vehObj}) then {
		_deployed pushBack _vehObj;
	};
} forEach (_army getOrDefault ["vehicles", []]);

// The rotation is consumed as vehicles fill up, so the full list is kept
// separately - the speed cap below has to reach every vehicle, including the
// ones that filled and left the rotation early.
private _rotation = +_deployed;

// Spawned back-to-front along the approach, so the last placed is the head of
// the column and the first to be filled.
reverse _rotation;

// 4. Marching order: the leader heads the file and takes the head vehicle,
// then everyone else in roster order. One ordered pass replaces the separate
// leader placement the mounted-only version needed.
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

// 5. Formation geometry. Forward is the deployment bearing; men are laid out
// in files of TACT_deployFootWidth, each rank one TACT_deployFootDepth further
// back along the reverse of it.
//
// Flattened to ground level first. An army's `location` is a strategic
// position and carries whatever height it was authored with; a slot built off
// a non-zero z spawns the man in the air and drops him.
_deployPos = [_deployPos param [0, 0, [0]], _deployPos param [1, 0, [0]], 0];

private _fwd   = [sin _deployDir, cos _deployDir, 0];
private _right = [cos _deployDir, -(sin _deployDir), 0];

private _fileWidth = if (isNil "TACT_deployFootWidth") then {2} else {TACT_deployFootWidth};
if (_fileWidth < 1) then { _fileWidth = 1 };

private _lateral = if (isNil "TACT_deployFootSpacing") then {6} else {TACT_deployFootSpacing};
private _depth   = if (isNil "TACT_deployFootDepth") then {8} else {TACT_deployFootDepth};

// 5b. THE SIDE ANCHOR AND THE HOLDING GROUP.
//
// createUnit does not put a man on the side of the group it creates him in. A
// group created on INDEPENDENT and filled with B_ classes produces men who ARE
// in an INDEPENDENT group, report INDEPENDENT when asked, and behave as WEST -
// so with `independent setFriend [west, 0]` they are hostile to their own
// squad and open fire on each other with no enemy on the map. Matching every
// roster's classes to its side is the other fix and it is the expensive one:
// it costs the project every class it does not own, and there is no
// WEST-configured cartel in the game for drugLords to be built out of.
//
// So each man is spawned into a holding group on the side his class is
// configured on and joined across under an anchor that is genuinely of this
// army's side and outranks him. The join is what carries him; the anchor's
// rank is what makes the join carry him.
//
// THE ORDER IS THE TECHNIQUE and none of it commutes. The men must be created
// in the holding group - a man created in the destination has already been got
// wrong before any join could reach him. The anchor must exist before they are
// created, because _grp is built deleteWhenEmpty and a destination with nobody
// in it is a destination the engine may collect before the men arrive.
private _anchorClass = TACT_sideAnchorClass getOrDefault [str _side, ""];
private _anchor = objNull;
private _holding = grpNull;

if (_anchorClass == "") then {
	diag_log format ["TACT Deploy: no anchor class for side %1; men will deploy unconverted.", _side];
} else {
	_anchor = _grp createUnit [_anchorClass, _deployPos, [], 0, "NONE"];

	if (isNull _anchor) then {
		diag_log format ["TACT Deploy: could not create anchor '%1'; men will deploy unconverted.", _anchorClass];
	} else {
		// Above every rank a config can carry, so it outranks the roster
		// whatever the classes declare - B_T_Soldier_SL_F is a SERGEANT, and a
		// squad leader who outranked the anchor would defeat the whole thing.
		_anchor setUnitRank "COLONEL";
		_grp selectLeader _anchor;
		_anchor hideObject true;
		_anchor allowDamage false;

		// The side the men's CLASSES are configured on, read off the class
		// rather than off a unit - at this point there are no units, which is
		// the whole point of the ordering. CfgVehicles >> side: 0 EAST,
		// 1 WEST, 2 GUER, 3 CIVILIAN.
		//
		// deleteWhenEmpty false: this group is emptied on purpose at 6b, and a
		// group that deletes itself out from under 6d is a null reference
		// waiting to be tidied up.
		private _configSides = [east, west, independent, civilian];
		private _configSide = _configSides param [
			getNumber (configFile >> "CfgVehicles" >> ((_ordered select 0) get "className") >> "side"),
			_side
		];

		_holding = createGroup [_configSide, false];

		if (isNull _holding) then {
			diag_log "TACT Deploy: could not create the holding group; men will deploy unconverted.";
			deleteVehicle _anchor;
			_anchor = objNull;
		};
	};
};

// Where the men are actually created. The holding group when the anchor stood
// up, the army's own group when it did not - an unconverted deployment is
// worse than a converted one but better than no deployment at all, and the log
// above says which happened.
private _spawnGroup = if (isNull _holding) then {_grp} else {_holding};

// 6a. Place. Mounting is a separate pass now: a man has to be in his final
// group before he is put in a vehicle, or the join would be moving crewed men
// between groups for no reason.
private _physicalLeader = objNull;
private _placed = [];

{
	private _soldierData = _x;

	private _rank = floor (_forEachIndex / _fileWidth);
	private _file = _forEachIndex % _fileWidth;

	private _offsetRight = ((_file - ((_fileWidth - 1) / 2)) * _lateral);
	private _offsetBack  = -(_rank * _depth);

	private _slotPos = _deployPos
		vectorAdd (_right vectorMultiply _offsetRight)
		vectorAdd (_fwd vectorMultiply _offsetBack);

	// Placed on the ground at his slot, not at map origin. "NONE" so the man
	// stands where he is put rather than being pulled into an engine
	// formation around a leader who may not exist yet.
	private _unit = _spawnGroup createUnit [_soldierData get "className", _slotPos, [], 0, "NONE"];
	_soldierData set ["obj", _unit];

	// A class that will not resolve returns null rather than throwing, and
	// every line below would then error on nothing. Skipped and counted out.
	if (!isNull _unit) then {
		_placed pushBack _unit;

		_unit setDir _deployDir;
		_unit setDamage (1 - (_soldierData getOrDefault ["health", 1]));
		_unit setSkill (_soldierData getOrDefault ["skill", 0.5]);

		if (_soldierData getOrDefault ["isLeader", false]) then { _physicalLeader = _unit };
	} else {
		diag_log format ["TACT Deploy: '%1' would not spawn, man skipped.", _soldierData get "className"];
	};
} forEach _ordered;

// 6b. Across. This one line is the conversion.
if (!isNull _holding && {count _placed > 0}) then {
	_placed joinSilent _grp;
};

// 6c. Mount, now that everyone is in the group they will fight in.
//
// Mount forward through the rotation until a man has a seat or the rotation is
// empty. `objectParent` is the authority on whether he got one: moveInAny
// fails silently on a full vehicle, and a vehicle that refuses a man is full
// for everyone, so it leaves the rotation.
//
// The loop terminates - every pass either seats him or shortens the rotation
// by one - and once the rotation empties every man after this one walks, which
// is the infantry-only case reached by exhaustion.
private _vehicleIndex = 0;
private _mounted = 0;

{
	private _unit = _x;

	while {isNull (objectParent _unit) && {count _rotation > 0}} do {
		private _veh = _rotation select _vehicleIndex;
		_unit moveInAny _veh;

		if (isNull (objectParent _unit)) then {
			_rotation deleteAt _vehicleIndex;
			if (count _rotation > 0) then {
				_vehicleIndex = _vehicleIndex % (count _rotation);
			};
		} else {
			_mounted = _mounted + 1;
			_vehicleIndex = (_vehicleIndex + 1) % (count _rotation);
		};
	};
} forEach _placed;

// 6d. The scaffolding back out. The real leader is selected before the anchor
// is deleted, because deleting a group's leader lets the engine pick the
// replacement and it would not pick the man the roster named.
//
// Recorded before the delete: deleteVehicle nulls the reference, so asking
// afterwards whether there had been an anchor always answers no.
private _converted = !isNull _holding;

if (!isNull _physicalLeader && {_physicalLeader in (units _grp)}) then {
	_grp selectLeader _physicalLeader;
};

if (!isNull _anchor) then { deleteVehicle _anchor };
if (!isNull _holding) then { deleteGroup _holding };

// 7. Hold the column to its foot element. limitSpeed is in km/h and per
// object, which is what is wanted here - setSpeedMode is group-level and would
// slow the infantry too, and the infantry is already the pace being matched.
//
// Applied only when somebody actually walked. With nobody on foot the slowest
// thing in the group is a vehicle and there is nothing to hold the column back
// to, so a fully mounted army is left uncapped and unchanged.
private _onFoot = (count _placed) - _mounted;

if (_onFoot > 0 && {count _deployed > 0}) then {
	private _pace = if (isNil "TACT_deployFootPaceKmh") then {10} else {TACT_deployFootPaceKmh};
	{ _x limitSpeed _pace } forEach _deployed;
};

// 8. Facing. The leader was selected at 6d, before the anchor was removed.
// setFormDir gives the group a front to form on, which otherwise defaults to
// whatever bearing the engine picks off the leader.
_grp setFormDir _deployDir;

diag_log format [
	"TACT Deploy: %1 put %2 men on the ground as %3 - %4 mounted, %5 on foot%6%7.",
	_army getOrDefault ["name", "?"],
	count _placed,
	_side,
	_mounted,
	_onFoot,
	(if (_onFoot > 0 && {count _deployed > 0}) then {", column held to foot pace"} else {""}),
	(if (_converted) then {""} else {", UNCONVERTED"})
];

_grp
