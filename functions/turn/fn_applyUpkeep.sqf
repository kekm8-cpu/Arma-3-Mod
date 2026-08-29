/*
	Function: STRAT_fnc_applyUpkeep

	Description:
		Applies the per-block and per-day ticks that close out a resolved block
		(section 9, stage 12).

		Systems tick at different multiples of the block, so this dispatches by
		rate rather than assuming one. The rates are wired here now so that
		later milestones attach to an existing hook instead of retrofitting the
		turn loop.

	Parameters:
		0: NUMBER - index of the block that just resolved

	Returns:
		nothing
*/

params [["_blockIndex", 0, [0]]];

// ---------------------------------------------------------------------- //
// EVERY BLOCK (4h)                                                        //
// ---------------------------------------------------------------------- //
// Fatigue accumulation belongs here: exertion and hoursSinceSleep tick on
// each soldier record, per army, for the block just marched. The keys exist
// and STRAT_fnc_armyFatigue already derives an army-level value from them,
// but nothing writes to them yet - accumulation is build plan 2.6 and is
// left absent rather than stubbed with invented numbers.

// ---------------------------------------------------------------------- //
// EVERY 6 BLOCKS (daily)                                                  //
// ---------------------------------------------------------------------- //
private _dayBoundary = ((_blockIndex + 1) % STRAT_blocksPerDay) == 0;

if (_dayBoundary) then {
	// Wages and income tick here once the economy exists (3.6).
	//
	// NATO aggression decay also belongs here rather than in
	// STRAT_fnc_addAggression, which only ever accrues: decay is a scheduled
	// tick against STRAT_natoAggression, not a negative accrual. The rate is
	// still open - section 5 has it as TBD, likely every 6 blocks - so it is
	// named here and not yet applied.
	diag_log format ["STRAT Turn: day boundary reached after block %1.", _blockIndex];
};
