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

		Each tick applies a slice of block time to movement, then evaluates any
		battle running inside the block, then looks for new contact. Order
		matters: a battle that ends on this tick releases its armies before the
		next slice, and detection runs on positions that have already moved.

		No battle may span a block boundary, so anything still being fought when
		the block runs out is concluded here as a mutual disengage. That is what
		keeps a block boundary free of in-flight state.

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
	// STAGE 9: CONCLUSION AND CLASSIFICATION                              //
	// ------------------------------------------------------------------ //
	// Live battles are evaluated before new ones are opened, so an engagement
	// that ends on this tick frees its armies immediately.
	private _concluded = [];
	{
		private _engagement = _x;
		private _outcome = [_engagement] call TACT_fnc_resolveVictory;

		if (count _outcome > 0) then {
			[_engagement, _outcome] call TACT_fnc_concludeBattle;
			_concluded pushBack _engagement;
		};
	} forEach TACT_activeEngagements;

	// Removed by id. Array subtraction compares HashMaps by content, which
	// would drop the wrong record whenever two happened to match.
	if (count _concluded > 0) then {
		private _concludedIds = _concluded apply {_x get "id"};
		TACT_activeEngagements = TACT_activeEngagements select {!((_x get "id") in _concludedIds)};
	};

	// ------------------------------------------------------------------ //
	// STAGE 4: CONTACT DETECTION                                          //
	// ------------------------------------------------------------------ //
	// Evaluated after movement has been applied for this slice. Detection
	// collects pairs and returns them; battles are opened out here, once
	// iteration over activeArmies has closed.
	//
	// Ambush zones and location boundaries are the other two contact sources.
	// Neither exists yet, so proximity is the only one evaluated.
	if (count TACT_activeEngagements < TACT_maxAttendedBattles) then {
		private _contacts = [] call TACT_fnc_detectContact;

		{
			_x params ["_armyA", "_armyB"];

			// Every battle is attended and spawned. Auto-resolving the ones the
			// player is not at is a later milestone, so until it exists the
			// cap holds the rest back rather than spawning battles nobody can
			// watch.
			if (count TACT_activeEngagements < TACT_maxAttendedBattles) then {
				private _engagement = [_armyA, _armyB, _blockHoursLeft] call TACT_fnc_buildEngagement;

				if ([_engagement] call TACT_fnc_initiateBattle) then {
					TACT_activeEngagements pushBack _engagement;
				} else {
					// Deployment failed. Record the pair as settled so the
					// same failure is not retried every tick for a whole block.
					TACT_resolvedPairsThisBlock pushBack [_armyA get "id", _armyB get "id"];
				};
			};
		} forEach _contacts;
	};

	// A block with a battle running in it is never idle, whatever the marchers
	// are doing.
	if (count TACT_activeEngagements > 0) then { _idle = false };

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

// ---------------------------------------------------------------------- //
// BLOCK CLOCK EXPIRY: NO BATTLE MAY SPAN A BLOCK BOUNDARY                 //
// ---------------------------------------------------------------------- //
// Anything still fighting when the block runs out ends in mutual disengage.
// This is what keeps a save point free of a battle in progress.
{
	private _engagement = _x;
	private _outcome = [_engagement, true] call TACT_fnc_resolveVictory;
	[_engagement, _outcome] call TACT_fnc_concludeBattle;
} forEach TACT_activeEngagements;

TACT_activeEngagements = [];

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
