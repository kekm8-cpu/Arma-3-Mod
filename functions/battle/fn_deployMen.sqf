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
private _rotation = [];
{
	private _vehObj = _x getOrDefault ["obj", objNull];
	if (!isNull _vehObj && {alive _vehObj}) then {
		_rotation pushBack _vehObj;
	};
} forEach (_army getOrDefault ["vehicles", []]);

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

// 6. Place, then mount.
private _physicalLeader = objNull;
private _vehicleIndex = 0;
private _mounted = 0;

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
	private _unit = _grp createUnit [_soldierData get "className", _slotPos, [], 0, "NONE"];
	_soldierData set ["obj", _unit];

	_unit setDir _deployDir;
	_unit setDamage (1 - (_soldierData getOrDefault ["health", 1]));
	_unit setSkill (_soldierData getOrDefault ["skill", 0.5]);

	if (_soldierData getOrDefault ["isLeader", false]) then { _physicalLeader = _unit };

	// Mount forward through the rotation until this man has a seat or the
	// rotation is empty. `objectParent` is the authority on whether he got
	// one: moveInAny fails silently on a full vehicle, and a vehicle that
	// refuses a man is full for everyone, so it leaves the rotation.
	//
	// The loop terminates - every pass either seats him or shortens the
	// rotation by one - and once the rotation empties every man after this
	// one walks, which is the infantry-only case reached by exhaustion.
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
} forEach _ordered;

// 7. Leader and facing. setFormDir gives the group a front to form on, which
// otherwise defaults to whatever bearing the engine picks off the leader.
if (!isNull _physicalLeader) then {
	_grp selectLeader _physicalLeader;
};

_grp setFormDir _deployDir;

diag_log format [
	"TACT Deploy: %1 put %2 men on the ground - %3 mounted, %4 on foot.",
	_army getOrDefault ["name", "?"],
	count _ordered,
	_mounted,
	(count _ordered) - _mounted
];

_grp
