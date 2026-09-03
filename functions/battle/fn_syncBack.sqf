/*
	Function: TACT_fnc_syncBack

	Description:
		Writes a battle back into data (lifecycle stage 10). Reads condition off
		every spawned entity into its owning record, drops the dead, nulls every
		`obj`, and deletes the entities.

		ANYTHING NOT READ HERE IS LOST when the entities are deleted: after this
		runs the army is a pure record again.

		Health is stored where 1.0 is pristine; Arma stores damage where 0 is.
		Every read here inverts once, on the way in, and nowhere else.

		Records that were never deployed (`obj` is objNull) are kept untouched -
		absent from the battle is not the same as dead in it.

	Parameters:
		0: HASHMAP - army record

	Returns:
		ARRAY - [_menLost, _vehiclesLost]
*/

params [
	["_army", createHashMap, [createHashMap]]
];

if (count _army == 0) exitWith { [0, 0] };

// ------------------------------------------------------------------------ //
// SOLDIERS                                                                  //
// ------------------------------------------------------------------------ //
private _survivingMen = [];
private _menLost = 0;

{
	private _soldier = _x;
	private _obj = _soldier getOrDefault ["obj", objNull];

	if (isNull _obj) then {
		// Never deployed. Nothing happened to this man.
		_survivingMen pushBack _soldier;
	} else {
		if (alive _obj) then {
			_soldier set ["health", 1 - (damage _obj)];
			_survivingMen pushBack _soldier;
		} else {
			// Dead records are dropped, not kept at zero health.
			_menLost = _menLost + 1;
		};

		_soldier set ["obj", objNull];
		deleteVehicle _obj;
	};
} forEach (_army getOrDefault ["men", []]);

_army set ["men", _survivingMen];

// ------------------------------------------------------------------------ //
// VEHICLES                                                                  //
// ------------------------------------------------------------------------ //
private _survivingVehicles = [];
private _vehiclesLost = 0;

{
	private _vehicle = _x;
	private _obj = _vehicle getOrDefault ["obj", objNull];

	if (isNull _obj) then {
		_survivingVehicles pushBack _vehicle;
	} else {
		if (alive _obj) then {
			_vehicle set ["health", 1 - (damage _obj)];

			// Component damage, read back against the layout the record
			// already carries rather than rediscovered from config.
			private _hitboxes = _vehicle getOrDefault ["hitboxes", createHashMap];
			{
				private _hitPointDamage = _obj getHitPointDamage _x;
				if (!isNil "_hitPointDamage") then {
					_hitboxes set [_x, _hitPointDamage];
				};
			} forEach (keys _hitboxes);

			_survivingVehicles pushBack _vehicle;
		} else {
			_vehiclesLost = _vehiclesLost + 1;
		};

		_vehicle set ["obj", objNull];
		deleteVehicle _obj;
	};
} forEach (_army getOrDefault ["vehicles", []]);

_army set ["vehicles", _survivingVehicles];

[_menLost, _vehiclesLost]
