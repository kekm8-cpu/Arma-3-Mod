/*
	Function: TACT_fnc_deployVehicles

	Description:
		Spawns an army's vehicle roster onto the tactical grid as a column
		running forward from the deployment point, restoring each vehicle's
		stored damage and hitbox state.

		The column follows the approach road while there is road to follow and
		continues along its last bearing after that. Previously the road path
		was the only source of positions, so an army whose ends were both more
		than 150 m from a road - fn_calculateRoadPath returns an empty array
		for that - deployed no vehicles at all, and a path shorter than the
		roster silently dropped the tail of it. Off-road deployment now costs
		the column its road alignment and nothing else.

		Only as many vehicles are placed as the roster can put a driver in.
		A vehicle nobody can crew is left with `obj` null, which fn_syncBack
		reads as never deployed and returns to the army untouched - a truck
		short of a driver sits out the battle rather than standing on the
		field as a target that cannot move or shoot back.

		fn_deployMen lays its foot formation out *behind* the same deployment
		point, so the two do not contest the same ground.

		Vehicles are placed stationary. They used to be injected with 30 km/h
		of velocity along the column to read as a force caught mid-march, and
		that stopped being safe: a partly mounted army's trucks pull away from
		their own foot element before the AI has an order to obey, and an
		off-road column - which is now a thing that happens - drives into the
		scrub at speed, on ground it was placed on with CAN_COLLIDE and before
		it has settled. fn_initiateBattle issues the group `move` in the same
		frame, so the AI has them rolling within a second under its own
		control; the mid-march read is carried by the column geometry and the
		facing, which are still here.

	Parameters:
		0: HASHMAP - army object
		1: ARRAY   - road nodes to deploy along; may be empty or short
		2: ARRAY   - deployment point, head of the column
		3: NUMBER  - deployment bearing in degrees, used off-road
*/

params [
	["_army", createHashMap, [createHashMap]],
	["_path", [], [[]]],
	["_deployPos", [0,0,0], [[]]],
	["_deployDir", 0, [0]]
];

private _vehiclesData = _army getOrDefault ["vehicles", []];
if (count _vehiclesData == 0) exitWith {};

// ------------------------------------------------------------------------ //
// 1. HOW MANY CAN BE CREWED                                                 //
// ------------------------------------------------------------------------ //
// One driver each is the floor. fn_deployMen fills seats front-first from the
// same roster, so anything past this count would deploy empty by construction.
private _crewAvailable = count (_army getOrDefault ["men", []]);
private _deployable = (count _vehiclesData) min _crewAvailable;

if (_deployable < count _vehiclesData) then {
	diag_log format [
		"TACT Deploy: %1 has %2 vehicle(s) and %3 men - %4 left undeployed for want of a driver.",
		_army getOrDefault ["name", "?"],
		count _vehiclesData,
		_crewAvailable,
		(count _vehiclesData) - _deployable
	];
};

// ------------------------------------------------------------------------ //
// 2. COLUMN SLOTS                                                           //
// ------------------------------------------------------------------------ //
// One [position, direction vector] per vehicle, in the order the roster lists
// them. A slot comes off the road path where the path reaches; past its end
// the column carries on along the bearing of its last segment.
private _spacing = if (isNil "TACT_deployColumnSpacing") then {15} else {TACT_deployColumnSpacing};

private _cursorPos = [_deployPos param [0, 0, [0]], _deployPos param [1, 0, [0]], 0];
private _cursorDir = [sin _deployDir, cos _deployDir, 0];

private _slots = [];

for "_i" from 0 to (_deployable - 1) do {
	if (_i < ((count _path) - 1)) then {
		private _startNode = _path select _i;
		private _nextNode  = _path select (_i + 1);

		_cursorPos = getPos _startNode;
		_cursorDir = _cursorPos vectorFromTo (getPos _nextNode);
	} else {
		// Off the end of the road, or never on one. Continue the column from
		// wherever it got to, along the bearing it was last running on.
		if (_i > 0) then {
			_cursorPos = _cursorPos vectorAdd (_cursorDir vectorMultiply _spacing);
		};
	};

	_slots pushBack [+_cursorPos, +_cursorDir];
};

// ------------------------------------------------------------------------ //
// 3. PLACE                                                                  //
// ------------------------------------------------------------------------ //
{
	private _vData = _x; // The custom vehicle HashMap object
	private _className = _vData getOrDefault ["className", ""];

	(_slots select _forEachIndex) params ["_startPos", "_dirVector"];

	// Compute precise spawning orientation vector along the column
	private _azimuth = (_dirVector select 0) atan2 (_dirVector select 1);

	// Instantiate the physical asset onto the tactical grid, stationary and
	// facing along the column. See the header: the velocity injection this
	// replaces made an off-road or partly mounted deployment worse, and the
	// group's move order supersedes it a frame later regardless.
	private _vehObj = createVehicle [_className, _startPos, [], 0, "CAN_COLLIDE"];
	_vehObj setDir _azimuth;
	_vData set ["obj", _vehObj];

	// --- DEGRADED STATE RESTORATION (DAMAGE & HITBOXES) ---
	// 1. Restore component-level hitbox damage
	private _hitboxesMap = _vData getOrDefault ["hitboxes", createHashMap];
	{
		// _x = Hitpoint Name (String), _y = Damage State (Number 0-1)
		_vehObj setHitPointDamage [_x, _y];
	} forEach _hitboxesMap;

	// 2. Restore overall structural vehicle health
	private _overallHealth = _vData getOrDefault ["health", 1];
	private _overallDamage = 1 - _overallHealth; // Invert health coefficient to find damage
	_vehObj setDamage [_overallDamage, false]; // False bypasses default structural explosion effects during initial rendering

	// --- STRATEGIC ENGINE RUNTIME IDENTIFIER STAMPING ---
	_vehObj setVariable ["TACT_armyRef", _army];
	_vehObj setVariable ["TACT_vehicleIndex", _forEachIndex];
	_vehObj setVariable ["TACT_vehicleDataRef", _vData];
} forEach (_vehiclesData select [0, _deployable]);
