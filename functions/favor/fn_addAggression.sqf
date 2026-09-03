/*
	Function: STRAT_fnc_addAggression

	Description:
		Accrues NATO Aggression and returns the new balance.

		The hook, not the mechanic: accrual triggers, decay, display and the
		druglords' spending of it are phase 3.7. It exists this early so the
		explosive-ordnance paths built during the phase two battle deep dive
		have somewhere to report.

		Aggression only ever rises here. Decay is a scheduled tick in
		STRAT_fnc_applyUpkeep, not a negative passed through this function, so a
		negative amount is rejected rather than quietly running the mechanic
		backwards.

	Parameters:
		0: NUMBER - aggression accrued (must be positive)
		1: STRING - short reason, for the log and for later display

	Returns:
		NUMBER - the balance after accrual.
*/

params [
	["_amount", 0, [0]],
	["_reason", "unspecified", [""]]
];

if (isNil "STRAT_natoAggression") then { STRAT_natoAggression = 0 };

if (_amount <= 0) exitWith {
	diag_log format ["STRAT Favor: refusing non-positive aggression %1 ('%2'); decay is an upkeep tick, not a negative accrual.", _amount, _reason];
	STRAT_natoAggression
};

STRAT_natoAggression = STRAT_natoAggression + _amount;

diag_log format ["STRAT Favor: +%1 NATO Aggression (%2), now %3.", _amount, _reason, STRAT_natoAggression];

STRAT_natoAggression
