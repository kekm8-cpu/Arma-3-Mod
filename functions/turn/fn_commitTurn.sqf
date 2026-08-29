/*
	Function: STRAT_fnc_commitTurn

	Description:
		Closes the planning phase (section 9, stage 2) and hands the block to
		resolution. Every pending order becomes an active one and its route is
		copied onto the army as the path remaining to walk this block.

		Commitment is absolute: once this returns there is no further input
		until the block ends. Orders are not cleared here - they must survive
		into battle setup.

	Parameters:
		none

	Returns:
		BOOL - true if the block was committed.
*/

if (STRAT_turnPhase != "planning") exitWith {
	diag_log "STRAT Turn: commit refused, not in the planning phase.";
	false
};

// Drop the selection before input closes. Nothing has to be restored: the
// selection ring is emitted by the draw list only while the variable is set.
STRAT_selectedArmy = nil;

private _marching = 0;
{
	private _army = _x;
	private _order = _army get "pendingOrder";

	if (_order isEqualType createHashMap && {count _order > 0}) then {
		private _status = _order getOrDefault ["status", "pending"];

		if (_status == "pending") then {
			// Fresh order: its planned route becomes the walk remaining.
			_army set ["path", +(_order getOrDefault ["path", []])];
			_order set ["status", "active"];
		};

		if ((_order getOrDefault ["status", ""]) == "active" && {count (_army get "path") > 0}) then {
			_marching = _marching + 1;
		};
	};
} forEach activeArmies;

// Last block's battle report has been read by now; the new block writes its own.
TACT_lastBattleReport = "";

STRAT_turnPhase = "resolving";

diag_log format ["STRAT Turn: block %1 committed, %2 army(s) marching.", STRAT_blockIndex, _marching];

// Resolution runs in compressed real time with the player watching, so it
// sleeps and must be spawned rather than called.
[] spawn STRAT_fnc_resolveTurn;

true
