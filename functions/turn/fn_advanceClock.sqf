/*
	Function: STRAT_fnc_advanceClock

	Description:
		Closes the resolved block and opens the next planning phase (section 9,
		stage 13). Advances the block index and moves the world clock forward
		by one block length, so in-game time only ever moves in block steps.

		A block boundary is the natural save point: no battle spans it and no
		movement is in flight across it. Serialization hangs off this call.

	Parameters:
		none

	Returns:
		NUMBER - the new block index
*/

STRAT_blockIndex = STRAT_blockIndex + 1;

// The world clock is driven by the block, not by real time. See init.sqf,
// where the time multiplier is pinned so it does not drift between blocks.
skipTime STRAT_blockLengthHours;

diag_log format ["STRAT Turn: clock advanced to block %1.", STRAT_blockIndex];

// Save point: block boundary, no in-flight state. Serialization is a later
// milestone and is deliberately not attempted here.

call STRAT_fnc_beginPlanning;

STRAT_blockIndex
