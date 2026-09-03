/*
	Function: STRAT_fnc_advanceClock

	Description:
		Closes the resolved block and opens the next planning phase (lifecycle
		stage 13). Advances the block index and moves the world clock forward by
		one block length, so in-game time only ever moves in block steps.

		A block boundary is the natural save point - no battle spans it and no
		movement is in flight across it - so serialization will hang off this
		call.

	Parameters:
		none

	Returns:
		NUMBER - the new block index
*/

STRAT_blockIndex = STRAT_blockIndex + 1;

// The world clock is driven by the block, not by real time; init.sqf pins the
// time multiplier so it cannot drift between blocks.
skipTime STRAT_blockLengthHours;

diag_log format ["STRAT Turn: clock advanced to block %1.", STRAT_blockIndex];

call STRAT_fnc_beginPlanning;

STRAT_blockIndex
