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
// each soldier record, per army, for the block just marched. Not modelled
// yet - fatigue is a later milestone and is left absent rather than stubbed
// with invented numbers.

// ---------------------------------------------------------------------- //
// EVERY 6 BLOCKS (daily)                                                  //
// ---------------------------------------------------------------------- //
private _dayBoundary = ((_blockIndex + 1) % STRAT_blocksPerDay) == 0;

if (_dayBoundary) then {
	// Wages, income, and NATO aggression decay tick here once the economy
	// and the aggression tracker exist.
	diag_log format ["STRAT Turn: day boundary reached after block %1.", _blockIndex];
};
