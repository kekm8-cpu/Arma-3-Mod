/*
	Function: STRAT_fnc_beginPlanning

	Description:
		Opens the planning phase (section 9, stage 1). Clears the orders that
		finished last block, leaves unfinished ones standing, and reports the
		block clock plus every detachment still awaiting orders.

		Orders issued during this phase are written to each army's
		"pendingOrder" and do nothing until STRAT_fnc_commitTurn runs. Nothing
		moves while the phase is "planning".

	Parameters:
		none

	Returns:
		BOOL - true if the planning phase opened, false if a block is still
		       resolving.
*/

// The guard asks whether a block is actually still in flight, not what the
// phase flag says. It used to read STRAT_turnPhase, which this function is
// itself the only thing that ever sets back to "planning" - so the first
// commit set the phase to "resolving", resolution ended, and this refused to
// reopen planning on the grounds of the flag it was about to clear. Nothing
// else writes the flag, so the campaign stopped accepting orders after one
// block.
//
// STRAT_fnc_resolveTurn clears STRAT_resolutionRunning immediately before
// calling STRAT_fnc_advanceClock, which calls this, so by the time control
// arrives here the block genuinely is over.
if (!isNil "STRAT_resolutionRunning" && {STRAT_resolutionRunning}) exitWith {
	diag_log "STRAT Turn: beginPlanning refused, a block is still resolving.";
	false
};

STRAT_turnPhase = "planning";

// Drop the selection carried over from the previous phase. Selection is drawn
// as a ring by the campaign layer rather than stamped onto the army as reduced
// marker alpha, so clearing the variable is the whole of it - there is no
// presentation state left to restore on the way out.
STRAT_selectedArmy = nil;

// Retire completed orders; a still-running order stands, so an army the player
// gives no new instruction to keeps marching its committed route.
private _awaitingOrders = [];
{
	private _army = _x;
	private _order = _army get "pendingOrder";

	if (_order isEqualType createHashMap && {count _order > 0}) then {
		if ((_order getOrDefault ["status", "pending"]) == "complete") then {
			_army set ["pendingOrder", createHashMap];
			_army set ["path", []];
			_awaitingOrders pushBack (_army get "name");
		};
	} else {
		_awaitingOrders pushBack (_army get "name");
	};
} forEach activeArmies;

// Block clock readout. Day and block-of-day are derived from the block index,
// never stored, so they cannot drift out of step with it.
private _day        = floor (STRAT_blockIndex / STRAT_blocksPerDay) + 1;
private _blockOfDay = (STRAT_blockIndex % STRAT_blocksPerDay) + 1;

private _report = format [
	"PLANNING - Day %1, Block %2 of %3\n%4%5\n\nIssue orders, then press SPACE to commit.",
	_day,
	_blockOfDay,
	STRAT_blocksPerDay,
	if (count _awaitingOrders == 0) then {
		"All detachments have standing orders."
	} else {
		format ["Awaiting orders: %1", _awaitingOrders joinString ", "]
	},
	// What the block just did, carried into the phase where it can be acted on.
	if (TACT_lastBattleReport == "") then {""} else {format ["\n\n%1", TACT_lastBattleReport]}
];

hint _report;
diag_log format ["STRAT Turn: planning opened for block %1.", STRAT_blockIndex];

true
