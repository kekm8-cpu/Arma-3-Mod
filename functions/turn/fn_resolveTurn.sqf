/*
	Function: STRAT_fnc_resolveTurn

	Description:
		Resolves one committed block (section 9, stage 3). Every army advances
		concurrently against the same elapsed block time: one pass per tick
		over all of them, not one army run to completion before the next
		starts.

		The block always resolves in compressed real time with the player
		watching. The exchange rate between real seconds and block hours is
		STRAT_realSecondsPerBlockHour.

		Movement only. Contact detection, engagement construction, and the
		battle lifecycle hang off the marked hook below and are not
		implemented yet.

		Must be spawned - this function sleeps.

	Parameters:
		none

	Returns:
		nothing
*/

if (STRAT_resolutionRunning) exitWith {
	diag_log "STRAT Turn: resolution already running, second call ignored.";
};
STRAT_resolutionRunning = true;

private _blockSecondsTotal = STRAT_blockLengthHours * 3600;
private _tickReal = 0.5;

// Block seconds bought by one real tick of watching.
private _blockSecondsPerTick = (_tickReal / STRAT_realSecondsPerBlockHour) * 3600;

// A non-positive exchange rate would buy no block time and hang the watch.
if (_blockSecondsPerTick <= 0) then {
	diag_log "STRAT Turn: STRAT_realSecondsPerBlockHour is not positive, resolving the block instantly.";
	_blockSecondsPerTick = _blockSecondsTotal;
};

private _blockElapsed = 0;

while {_blockElapsed < _blockSecondsTotal} do {
	private _step = _blockSecondsPerTick min (_blockSecondsTotal - _blockElapsed);

	// ------------------------------------------------------------------ //
	// STAGE 3: CONCURRENT MOVEMENT RESOLUTION                             //
	// ------------------------------------------------------------------ //
	// Every army gets the same slice of block time before any of them gets
	// the next one.
	private _idle = true;
	{
		private _army = _x;

		if (!(_army getOrDefault ["inBattle", false])) then {
			[_army, _step] call STRAT_fnc_moveArmyAlongPath;

			if (count (_army get "path") > 0) then { _idle = false };
		};
	} forEach activeArmies;

	_blockElapsed = _blockElapsed + _step;

	// ------------------------------------------------------------------ //
	// STAGE 4: CONTACT DETECTION - NOT IMPLEMENTED                        //
	// ------------------------------------------------------------------ //
	// Hostile proximity, ambush zones, and location boundaries are evaluated
	// here, after movement has been applied for this slice. Pairs are to be
	// collected during the sweep and acted on after it closes, never by
	// mutating activeArmies mid-iteration. Stages 5-11 (engagement record,
	// battle decision, deployment, conclusion, sync-back, post-battle march)
	// follow from it. TACT_fnc_battleDetectionLoop holds the proximity maths
	// that gets converted into this step; it is no longer run as a realtime
	// thread because it cannot honour block commitment.

	// Block clock readout. It is a mechanic, not decoration, so it is shown.
	private _blockHoursLeft = (_blockSecondsTotal - _blockElapsed) / 3600;
	hintSilent format [
		"EXECUTING - Day %1, Block %2 of %3\n%4 h of block time remaining.",
		floor (STRAT_blockIndex / STRAT_blocksPerDay) + 1,
		(STRAT_blockIndex % STRAT_blocksPerDay) + 1,
		STRAT_blocksPerDay,
		_blockHoursLeft toFixed 1
	];

	// Nothing left to resolve: the rest of the block still passes on the
	// clock, but there is nothing to watch, so the watch ends here.
	if (_idle && STRAT_skipIdleResolution) exitWith {};

	sleep _tickReal;
};

// Retire orders whose route has been walked out. An unfinished order stands
// and carries into the next block.
{
	private _army = _x;
	private _order = _army get "pendingOrder";

	if (_order isEqualType createHashMap && {count _order > 0}) then {
		if ((_order getOrDefault ["status", ""]) == "active" && {count (_army get "path") == 0}) then {
			_order set ["status", "complete"];
		};
	};
} forEach activeArmies;

// Stage 12, then stage 13.
[STRAT_blockIndex] call STRAT_fnc_applyUpkeep;

STRAT_resolutionRunning = false;

call STRAT_fnc_advanceClock;
