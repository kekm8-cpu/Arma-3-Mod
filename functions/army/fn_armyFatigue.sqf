/*
	Function: STRAT_fnc_armyFatigue

	Description:
		Derives an army-level fatigue value from its soldier records.

		Build plan 1.4. Deployment (section 9, stage 7) applies fatigue as
		skill and morale modifiers and needs something to read; this is that
		something. Nothing accumulates into `exertion` yet - per-block
		accumulation, the effects at deployment, and the projection shown at
		planning time are all build plan 2.6 - so in the current build this
		returns 0 for every army. The interface is what is being fixed here,
		not the numbers.

		Derived, never stored. Fatigue is a property of the men, so the army
		value is recomputed on demand rather than cached; an army that merges,
		splits, or loses its most exhausted men gets the right answer with no
		invalidation step. This also means it reads a garrison roster
		unchanged, since a garrison carries the same `men` array.

		Each soldier is curved individually and the results averaged, rather
		than averaging exertion and curving once. Fatigue is the man's, and
		one spent soldier in a fresh company should register as one spent
		soldier rather than be smoothed away before the curve sees him.

		The curve is the shape section 6 asks for: free below a threshold,
		gentle for the first hour past it, steepening after. Its three
		constants live in init.sqf and are placeholders - fatigue is tuned in
		phase two against played battles, because its whole visible effect is
		on the battlefield.

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
