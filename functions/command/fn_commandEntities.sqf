/*
	Function: TACT_fnc_commandEntities

	Description:
		Resolves the player's group into the things that can be drawn on the
		map, clicked, and given a move order.

		A command entity is not a soldier. Deployment mounts every man into a
		vehicle, so at the moment a battle opens the whole group is inside one
		MRAP: eight icons stacked on one point, seven of which cannot go
		anywhere on their own. An entity is therefore either a dismounted
		soldier or a vehicle carrying at least one of the group's men, which is
		what the player actually has to move.

		That also settles what clicking a mounted man means. He resolves to his
		vehicle, because his vehicle is the entity he is part of - selecting
		the man and selecting the truck he is riding in are the same act.

		Each entity carries the units to actually order. For a soldier that is
		himself; for a vehicle it is the driver, because a passenger given a
		move order climbs out and walks. A vehicle whose driver is not ours
		cannot be ordered and says so rather than silently ignoring clicks.

		The player is never an entity. A commander cannot order himself, and
		including him would make the group's own leader a click target sitting
		on top of the units he is trying to select.

	Entity keys:
		obj      OBJECT - what is drawn and hit-tested
		order    ARRAY  - units to issue doMove to; empty means unorderable
		men      ARRAY  - the group's soldiers this entity accounts for
		slot     NUMBER - the group index the stock UI knows this by (F-key)
		mounted  BOOL   - true when obj is a vehicle

	Parameters:
		none

	Returns:
		ARRAY of HASHMAP - one per entity, in group order.
*/

private _entities = [];

if (isNull player) exitWith { _entities };

private _group = group player;
if (isNull _group) exitWith { _entities };

// Group order is the order the stock commanding UI numbers by, so an entity's
// slot is the F-key that selects the same men when the map is closed.
private _members = units _group;

// Vehicles already accounted for, so a truck with four of ours inside emits
// one entity rather than four. Compared by object identity, which is what `in`
// does for objects.
private _seen = [];

{
	private _unit = _x;
	private _slot = _forEachIndex + 1;

	if (alive _unit && {_unit != player}) then {
		private _vehicle = vehicle _unit;

		if (_vehicle == _unit) then {
			// On foot: the man is the entity and orders go to him.
			_entities pushBack (createHashMapFromArray [
				["obj", _unit],
				["order", [_unit]],
				["men", [_unit]],
				["slot", _slot],
				["mounted", false]
			]);
		} else {
			if (!(_vehicle in _seen)) then {
				_seen pushBack _vehicle;

				// Every one of ours riding in it, so the label can report what
				// the entity is carrying rather than just naming the vehicle.
				private _riders = _members select {
					alive _x && {_x != player} && {vehicle _x == _vehicle}
				};

				// The driver is the only seat a move order means anything
				// from. Ours by construction - deployment creates the vehicle
				// empty and fills it from the roster - but checked, because a
				// crew can change hands mid-battle.
				private _driver = driver _vehicle;
				private _order = if (!isNull _driver && {alive _driver} && {_driver in _members}) then {
					[_driver]
				} else {
					[]
				};

				_entities pushBack (createHashMapFromArray [
					["obj", _vehicle],
					["order", _order],
					["men", _riders],
					["slot", _slot],
					["mounted", true]
				]);
			};
		};
	};
} forEach _members;

_entities
