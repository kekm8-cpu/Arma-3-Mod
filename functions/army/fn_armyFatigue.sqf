/*
	Function: STRAT_fnc_armyFatigue

	Description:
		Derives an army-level fatigue value from its soldier records. Nothing
		writes `exertion` yet (build plan 2.6), so this currently returns 0 for
		every army; the interface is what exists, not the numbers.

		Derived, never stored, so an army that merges, splits or loses its most
		exhausted men needs no invalidation step. It also reads a garrison
		roster unchanged, since a garrison carries the same `men` array.

		Each soldier is curved individually and the results averaged, rather
		than averaging exertion and curving once: one spent soldier in a fresh
		company should register rather than be smoothed away before the curve
		sees him.

		Curve shape and constants are manifest section 6; the constants live in
		init.sqf and are untuned placeholders.

	Parameters:
		0: HASHMAP - army record, or any roster carrying `men` (a garrison
		   qualifies)

	Returns:
		NUMBER - 0 (fresh) to 1 (spent).
*/

params [
	["_roster", createHashMap, [createHashMap]]
];

private _men = _roster getOrDefault ["men", []];

// An empty roster is not an error. An annihilated army holds no records and
// is legitimately asked for its fatigue on the way out of a battle.
if (count _men == 0) exitWith { 0 };

private _free  = STRAT_fatigueFreeHours;
private _spent = STRAT_fatigueSpentHours;

// A misconfigured span would divide by zero and silently poison every
// downstream modifier, so it is caught here rather than at the sharp end.
if (_spent <= _free) exitWith {
	diag_log format ["STRAT Fatigue: STRAT_fatigueSpentHours (%1) must exceed STRAT_fatigueFreeHours (%2); reporting fresh.", _spent, _free];
	0
};

private _total = 0;

{
	private _exertion = _x getOrDefault ["exertion", 0];

	// Normalise into 0..1 across the span, then bend it. The clamp is what
	// makes exertion below the threshold free and caps a man at fully spent
	// however far past the far end he has marched.
	private _t = (((_exertion - _free) / (_spent - _free)) max 0) min 1;

	_total = _total + (_t ^ STRAT_fatigueCurvePower);
} forEach _men;

_total / (count _men)
