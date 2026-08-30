/*
	Function: TACT_fnc_resolveVictory

	Description:
		Conclusion detection and outcome classification (section 9, stage 9).
		Evaluates the engagement's live victory conditions once and reports
		whether the battle is over and what happened.

		Classification is per army, not per battle, because the same act means
		opposite things depending on direction: an army that leaves the boundary
		toward its destination has broken through, and one that leaves away from
		it has been repulsed. That is what makes withdrawal legible without a
		separate "flee" mechanic.

		Strength is read from each army's own `men` records rather than from
		the group it deployed as, because those two are not the same set once
		the player can detach men into a group of their own. See the counting
		loop.

		Conditions evaluated here: annihilation, breakthrough, repulse. The
		battle clock is not read here - TACT_fnc_runBattle owns it and forces
		the conclusion when a fight reaches its cap without either side
		breaking, which is what `_forceDisengage` reports.

		Rout and surrender are listed in section 10.1 but need a morale model
		and a surrender model. Neither exists, so neither is claimed here.

	Parameters:
		0: HASHMAP - engagement record
		1: BOOL    - force a mutual disengage: the battle clock has run out
		             (default false)

	Returns:
		HASHMAP - empty while the battle continues. Otherwise:
		  "outcome" STRING  - "annihilation", "breakthrough", "repulse",
		                      "mutualDisengage"
		  "byArmy"  HASHMAP - army id → "held", "breakthrough", "repulse",
		                      "destroyed", "disengaged"
		  "summary" STRING  - one line for the player
*/

params [
	["_engagement", createHashMap, [createHashMap]],
	["_forceDisengage", false, [true]]
];

private _attacker = _engagement get "attacker";
private _defender = _engagement get "defender";
private _anchor   = _engagement get "boundaryAnchor";
private _radius   = _engagement get "boundaryRadius";

// The ARMIES, not their groups. Strength is counted off the record below and
// the groups are not read here at all - see the loop for why.
private _sides = [_attacker, _defender];

// ------------------------------------------------------------------------ //
// BATTLE CLOCK EXPIRY - MUTUAL DISENGAGE                                    //
// ------------------------------------------------------------------------ //
// Both armies separate, no ground changes hands, standing orders survive.
if (_forceDisengage) exitWith {
	private _byArmy = createHashMap;
	_byArmy set [_attacker get "id", "disengaged"];
	_byArmy set [_defender get "id", "disengaged"];

	createHashMapFromArray [
		["outcome", "mutualDisengage"],
		["byArmy", _byArmy],
		["summary", format [
			"MUTUAL DISENGAGE - neither side broke the other. %1 and %2 separate; no ground changes hands.",
			_attacker get "name",
			_defender get "name"
		]]
	]
};

// ------------------------------------------------------------------------ //
// SURVIVING STRENGTH AND POSITION                                           //
// ------------------------------------------------------------------------ //
private _alive = [];
private _centroids = [];

{
	private _army = _x;

	// LIVING STRENGTH IS COUNTED OFF THE ARMY RECORD, not off the group it was
	// deployed as. The two were the same set for as long as an army was one
	// group; they stop being the same set the moment the player splits a
	// detachment off on the map, and `units _group` would then miss every man
	// in it. An army with half its men detached and fighting would read as half
	// destroyed, and an army that detached everything would read as annihilated
	// while it was winning.
	//
	// The record does not have that failure mode, because detaching does not
	// touch it: a soldier record belongs to the army, and which group its body
	// happens to be standing in is a fact about the battlefield rather than
	// about the army. This is the "data records own the truth" invariant of
	// section 12, and it is the same rule TACT_fnc_syncBack already reads by.
	//
	// A record with a null `obj` was never deployed - an infantry-only army
	// that could not be placed, a man left behind - and is not on this field to
	// be killed on it. Absent is not dead, which is exactly the distinction
	// syncBack makes when it leaves those records untouched.
	private _living = [];
	{
		private _obj = _x getOrDefault ["obj", objNull];
		if (!isNull _obj && {alive _obj}) then { _living pushBack _obj };
	} forEach (_army getOrDefault ["men", []]);

	_alive pushBack (count _living);

	// Centre of mass of what is still standing. An army with nobody left has
	// no position, and the annihilation branch below catches it first.
	private _centroid = [0, 0, 0];
	if (count _living > 0) then {
		private _sumX = 0;
		private _sumY = 0;
		{
			private _p = getPosATL _x;
			_sumX = _sumX + (_p select 0);
			_sumY = _sumY + (_p select 1);
		} forEach _living;
		_centroid = [_sumX / (count _living), _sumY / (count _living), 0];
	};
	_centroids pushBack _centroid;
} forEach _sides;

_alive params ["_attackerAlive", "_defenderAlive"];

// ------------------------------------------------------------------------ //
// ANNIHILATION                                                              //
// ------------------------------------------------------------------------ //
if (_attackerAlive == 0 || {_defenderAlive == 0}) exitWith {
	private _byArmy = createHashMap;

	_byArmy set [_attacker get "id", if (_attackerAlive == 0) then {"destroyed"} else {"held"}];
	_byArmy set [_defender get "id", if (_defenderAlive == 0) then {"destroyed"} else {"held"}];

	private _summary = if (_attackerAlive == 0 && _defenderAlive == 0) then {
		format ["ANNIHILATION - %1 and %2 have destroyed each other.", _attacker get "name", _defender get "name"]
	} else {
		private _lost = if (_attackerAlive == 0) then {_attacker} else {_defender};
		private _won  = if (_attackerAlive == 0) then {_defender} else {_attacker};
		format ["ANNIHILATION - %1 has been wiped out by %2.", _lost get "name", _won get "name"]
	};

	createHashMapFromArray [
		["outcome", "annihilation"],
		["byArmy", _byArmy],
		["summary", _summary]
	]
};

// ------------------------------------------------------------------------ //
// BOUNDARY CROSSING - BREAKTHROUGH OR REPULSE                               //
// ------------------------------------------------------------------------ //
// The boundary is the withdrawal mechanic. Which side of the field an army
// leaves by is what separates a breakthrough from being driven off.
private _result = createHashMap;

{
	private _army = _x;
	private _centroid = _centroids select _forEachIndex;

	if (_centroid distance2D _anchor > _radius) exitWith {
		private _other = if ((_army get "id") == (_attacker get "id")) then {_defender} else {_attacker};

		// Destination bearing, read from the standing order.
		private _order = _army getOrDefault ["pendingOrder", createHashMap];
		private _destination = if (count _order > 0) then {
			_order getOrDefault ["destination", []]
		} else {
			[]
		};

		private _exitedForward = false;

		if (count _destination >= 2) then {
			private _toDestination = [(_destination select 0) - (_anchor select 0), (_destination select 1) - (_anchor select 1)];
			private _toExit        = [(_centroid select 0) - (_anchor select 0), (_centroid select 1) - (_anchor select 1)];

			// Sign of the dot product is all that matters: same half-plane as
			// the destination means the army left going where it meant to go.
			private _dot = ((_toDestination select 0) * (_toExit select 0)) + ((_toDestination select 1) * (_toExit select 1));
			_exitedForward = _dot > 0;
		};
		// An army with no standing order has no bearing to be measured
		// against, so leaving the field can only read as breaking off. This is
		// the interim rule for the ambiguous case; the fallback for a
		// destination lying behind an army's own edge is still an open
		// decision.

		private _byArmy = createHashMap;
		_byArmy set [_army get "id", if (_exitedForward) then {"breakthrough"} else {"repulse"}];
		_byArmy set [_other get "id", "held"];

		_result = createHashMapFromArray [
			["outcome", if (_exitedForward) then {"breakthrough"} else {"repulse"}],
			["byArmy", _byArmy],
			["summary", if (_exitedForward) then {
				format ["BREAKTHROUGH - %1 has broken through and is clear of the battle.", _army get "name"]
			} else {
				format ["REPULSE - %1 has been driven off the field by %2.", _army get "name", _other get "name"]
			}]
		];
	};
} forEach _sides;

_result
