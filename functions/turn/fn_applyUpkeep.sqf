/*
	Function: STRAT_fnc_applyUpkeep

	Description:
		Applies the per-block and per-day ticks that close out a resolved block
		(lifecycle stage 12).

		Systems tick at different multiples of the block (manifest section 5),
		so this dispatches by rate rather than assuming one. The rates are wired
		here so later milestones attach to an existing hook.

	Parameters:
		0: NUMBER - index of the block that just resolved

	Returns:
		nothing
*/

params [["_blockIndex", 0, [0]]];

// ---------------------------------------------------------------------- //
// EVERY BLOCK (4h)                                                        //
// ---------------------------------------------------------------------- //
// Fatigue accumulation belongs here: exertion and hoursSinceSleep tick on each
// soldier record for the block just marched. Build plan 2.6 - left absent
// rather than stubbed with invented numbers.

// ---------------------------------------------------------------------- //
// EVERY 6 BLOCKS (daily)                                                  //
// ---------------------------------------------------------------------- //
private _dayBoundary = ((_blockIndex + 1) % STRAT_blocksPerDay) == 0;

if (_dayBoundary) then {
	// Wages and income tick here once the economy exists (3.6).
	//
	// NATO aggression decay belongs here rather than in
	// STRAT_fnc_addAggression, which only ever accrues: decay is a scheduled
	// tick against STRAT_natoAggression, not a negative accrual. Its rate is
	// still open, so the slot is named and not yet applied.
	diag_log format ["STRAT Turn: day boundary reached after block %1.", _blockIndex];
};
