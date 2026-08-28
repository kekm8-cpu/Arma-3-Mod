/*
	Function: TACT_fnc_runBattle

	Description:
		Runs one battle to its conclusion (section 9, stages 8 and 9) and
		concludes it. The tactical layer is realtime Arma, so this runs at 1:1
		real time - nothing about a firefight wants compressing - and the
		strategic layer holds still while it does.

		The battle clock is the cap: at TACT_battleRealSecondsMax neither side
		has broken the other and the engagement ends in mutual disengage. It is
		displayed while the battle runs, because it is the mechanic that makes
		time in cover expensive rather than free.

		A battle always gets its full length, whenever in the block it starts.
		What it costs the strategic clock is the caller's business: this returns
		how long it took and the caller converts and clamps.

		Must be spawned or called from a spawned scope - this function sleeps.

	Parameters:
		0: HASHMAP - engagement record, already deployed by TACT_fnc_initiateBattle

	Returns:
		NUMBER - real seconds the battle lasted.
*/

params [
	["_engagement", createHashMap, [createHashMap]]
];

private _tickReal = 0.5;
private _realElapsed = 0;

private _outcome = createHashMap;

while {count _outcome == 0} do {
	sleep _tickReal;
	_realElapsed = _realElapsed + _tickReal;

	// The cap is reached: force the mutual disengage rather than evaluate.
	private _capReached = _realElapsed >= TACT_battleRealSecondsMax;

	_outcome = [_engagement, _capReached] call TACT_fnc_resolveVictory;

	if (count _outcome == 0) then {
		// Battle clock readout. Real minutes left before the fight breaks off,
		// and the block time the fight has burned so far.
		private _realLeft = (TACT_battleRealSecondsMax - _realElapsed) max 0;
		private _blockCost = (_realElapsed * TACT_blockSecondsPerBattleSecond)
			min ((_engagement getOrDefault ["blockTimeRemaining", 0]) * 3600);

		private _minutes = floor (_realLeft / 60);
		private _seconds = floor (_realLeft % 60);

		hintSilent format [
			"BATTLE - %1 vs %2\n%3:%4 remaining on the battle clock.\nBlock time spent: %5 h",
			(_engagement get "attacker") get "name",
			(_engagement get "defender") get "name",
			_minutes,
			if (_seconds < 10) then {format ["0%1", _seconds]} else {str _seconds},
			(_blockCost / 3600) toFixed 2
		];
	};
};

[_engagement, _outcome] call TACT_fnc_concludeBattle;

_realElapsed
