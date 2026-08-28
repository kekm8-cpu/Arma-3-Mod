/*
	Function: TACT_fnc_detectContact

	Description:
		Post-movement contact detection (section 9, stage 4). Sweeps every
		unordered pair of active armies and returns the hostile pairs that have
		closed inside the contact radius.

		This is the turn-based replacement for the old realtime
		`fn_battleDetectionLoop`. It collects pairs and returns them; it never
		initiates a battle and never touches `activeArmies`, so the caller can
		act once iteration has closed.

		Pairs already fought this block are skipped. Without that, two armies
		still standing within contact range of each other after a battle would
		re-engage on the very next tick.

	Parameters:
		none

	Returns:
		ARRAY of [HASHMAP, HASHMAP] - hostile army pairs in contact.
*/

private _pairs = [];

{
	private _armyA = _x;
	private _indexA = _forEachIndex;

	if (!(_armyA getOrDefault ["inBattle", false])) then {
		{
			private _armyB = _x;

			// Only look forward through the array: each unordered pair is
			// visited exactly once, and no army is compared against itself.
			if (_forEachIndex > _indexA && {!(_armyB getOrDefault ["inBattle", false])}) then {

				private _hostile = [
					_armyA getOrDefault ["faction", ""],
					_armyB getOrDefault ["faction", ""]
				] call STRAT_fnc_areHostile;

				if (_hostile) then {
					private _posA = _armyA get "location";
					private _posB = _armyB get "location";

					if (_posA distance2D _posB < TACT_contactRadius) then {
						private _idA = _armyA get "id";
						private _idB = _armyB get "id";

						private _alreadyFought =
							([_idA, _idB] in TACT_resolvedPairsThisBlock) ||
							{[_idB, _idA] in TACT_resolvedPairsThisBlock};

						if (!_alreadyFought) then {
							_pairs pushBack [_armyA, _armyB];
						};
					};
				};
			};
		} forEach activeArmies;
	};
} forEach activeArmies;

_pairs
