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

		Each tick applies a slice of block time to movement, then looks for
		contact on the positions that movement just produced.

		The two layers keep different clocks. Marching is compressed at
		STRAT_realSecondsPerBlockHour; a battle runs at 1:1 real time and the
		strategic clock holds while it does. When the battle ends, the block
		clock is charged what the fight cost, everyone who was not in it is
		advanced by that same amount, and the block carries on with whatever is
		left. A battle's cost is clamped to the block it opened in, so no block
		boundary ever holds a battle in progress.

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

// A pair fights at most once per block. Cleared here, added to as battles
// conclude.
TACT_resolvedPairsThisBlock = [];

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

	private _blockHoursLeft = (_blockSecondsTotal - _blockElapsed) / 3600;

	// ------------------------------------------------------------------ //
	// STAGE 4: CONTACT DETECTION                                          //
	// ------------------------------------------------------------------ //
	// Evaluated after movement has been applied for this slice. Detection
	// collects pairs and returns them; battles are opened out here, once
	// iteration over activeArmies has closed.
	//
	// Ambush zones and location boundaries are the other two contact sources.
	// Neither exists yet, so proximity is the only one evaluated.
	if (_blockHoursLeft > 0) then {
		private _contacts = [] call TACT_fnc_detectContact;

		// One attended battle at a time. Auto-resolving the ones the player is
		// not at is a later milestone, so the rest of this tick's contacts wait
		// and are found again on the next one.
		if (count _contacts > 0 && {TACT_maxAttendedBattles > 0}) then {
			(_contacts select 0) params ["_armyA", "_armyB"];

			private _engagement = [_armyA, _armyB, _blockHoursLeft] call TACT_fnc_buildEngagement;

			if ([_engagement] call TACT_fnc_initiateBattle) then {
				TACT_activeEngagements pushBack _engagement;

				// Ids captured before the battle: conclusion can take a
				// destroyed army off the map entirely.
				private _combatantIds = [_armyA get "id", _armyB get "id"];

				// -------------------------------------------------------- //
				// STAGES 8 AND 9: THE BATTLE, AT 1:1 REAL TIME              //
				// -------------------------------------------------------- //
				// The strategic clock holds while this runs. Marching armies
				// cannot advance in real time - forty minutes of it would be
				// twenty blocks - so they are held and then advanced by what
				// the battle cost, below.
				private _battleRealSeconds = [_engagement] call TACT_fnc_runBattle;

				TACT_activeEngagements = TACT_activeEngagements select {
					!((_x get "id") == (_engagement get "id"))
				};

				// What the fight cost the strategic clock, clamped to what was
				// left of the block when it opened. A battle always gets its
				// full length; it can never outlast the block it began in.
				private _battleBlockSeconds =
					(_battleRealSeconds * TACT_blockSecondsPerBattleSecond)
					min (_blockSecondsTotal - _blockElapsed);

				// Everyone who was not in it marches through it. Concurrent
				// resolution is preserved - the player just was not watching.
				{
					private _army = _x;
					if (!((_army get "id") in _combatantIds) && {!(_army getOrDefault ["inBattle", false])}) then {
						[_army, _battleBlockSeconds] call STRAT_fnc_moveArmyAlongPath;
					};
				} forEach activeArmies;

				_blockElapsed = _blockElapsed + _battleBlockSeconds;
				_idle = false;

				diag_log format [
					"STRAT Turn: battle ran %1 real seconds and cost %2 h of block time.",
					_battleRealSeconds,
					_battleBlockSeconds / 3600
				];
			} else {
				// Deployment failed. Record the pair as settled so the same
				// failure is not retried every tick for a whole block.
				TACT_resolvedPairsThisBlock pushBack [_armyA get "id", _armyB get "id"];
			};
		};
	};

	// Recomputed before the readout: a battle may have just consumed block time.
	_blockHoursLeft = (_blockSecondsTotal - _blockElapsed) / 3600;

	// Block clock readout. It is a mechanic, not decoration, so it is shown.
	// The battle report is composed into it rather than hinted separately: this
	// readout refreshes twice a second and would wipe anything else instantly.
	hintSilent format [
		"EXECUTING - Day %1, Block %2 of %3\n%4 h of block time remaining.%5",
		floor (STRAT_blockIndex / STRAT_blocksPerDay) + 1,
		(STRAT_blockIndex % STRAT_blocksPerDay) + 1,
		STRAT_blocksPerDay,
		_blockHoursLeft toFixed 1,
		if (TACT_lastBattleReport == "") then {""} else {format ["\n\n%1", TACT_lastBattleReport]}
	];

	// Nothing left to resolve: the rest of the block still passes on the
	// clock, but there is nothing to watch, so the watch ends here.
	if (_idle && STRAT_skipIdleResolution) exitWith {};

	sleep _tickReal;
};

// No battle can be in flight here: TACT_fnc_runBattle does not return until it
// has concluded, and its block-time cost is clamped to the block it opened in.
// A block boundary therefore never holds a battle in progress, which is what
// makes it a save point.

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
