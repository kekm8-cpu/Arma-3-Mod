/*
	Function: TACT_fnc_commandEntities

	Description:
		Resolves the player's group into the things that can be drawn on the
		map, clicked, and given a move order.

		AN ENTITY IS NOT A SOLDIER. It is either a dismounted man or a vehicle
		carrying at least one of the group's men - what the player actually has
		to move. Without that, a fully mounted group opens a battle as eight
		icons stacked on one MRAP, seven of which cannot go anywhere alone.

		A partly mounted group resolves to both kinds at once and needs no
		special case: the men who did not fit are already on foot.

		It also settles what clicking a mounted man means - he resolves to his
		vehicle, because that is the entity he is part of.

		Each entity carries the units to actually order. For a soldier that is
		himself; for a vehicle it is the DRIVER, because a passenger given a
		move order climbs out and walks. A vehicle whose driver is not ours
		cannot be ordered and says so rather than ignoring clicks.

		The player is never an entity: a commander cannot order himself, and
		including him would put a click target on top of the units he is trying
		to select.

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
				//
				// A vehicle the player is driving has no AI to order: he is
				// the driver, and where it goes is where he drives it. It is
				// still drawn, dimmed, because it is still his group's truck.
				private _driver = driver _vehicle;
				private _order = if (!isNull _driver
					&& {alive _driver}
					&& {_driver != player}
					&& {_driver in _members}) then {
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
