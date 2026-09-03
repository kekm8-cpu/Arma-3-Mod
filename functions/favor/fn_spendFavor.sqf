/*
	Function: STRAT_fnc_spendFavor

	Description:
		Debits CSAT Favor if the balance covers the cost. Returns whether the
		spend went through.

		The hook, not the mechanic: the asset catalogue, the spend menu and the
		accrual side of favor are phase 3.7. It exists this early because favor
		assets are called in during battles, so the phase two support-call paths
		have a single place to charge.

		The debit is all-or-nothing - a partial debit would leave the caller
		having paid for an asset it did not get.

		Deliberately no matching addFavor: favor is gained from strategic
		triggers with no battle-layer caller, so nothing is retrofitted by
		leaving that direction to 3.7.

	Parameters:
		0: NUMBER - cost (must be positive)
		1: STRING - what it was spent on, for the log and for later display

	Returns:
		BOOL - true if the balance covered the cost and was debited.
*/

params [
	["_cost", 0, [0]],
	["_spentOn", "unspecified", [""]]
];

if (isNil "STRAT_csatFavor") then { STRAT_csatFavor = 0 };

if (_cost <= 0) exitWith {
	diag_log format ["STRAT Favor: refusing non-positive favor cost %1 ('%2').", _cost, _spentOn];
	false
};

if (_cost > STRAT_csatFavor) exitWith {
	diag_log format ["STRAT Favor: cannot afford %1 favor for '%2', balance is %3.", _cost, _spentOn, STRAT_csatFavor];
	false
};

STRAT_csatFavor = STRAT_csatFavor - _cost;

diag_log format ["STRAT Favor: -%1 CSAT Favor (%2), now %3.", _cost, _spentOn, STRAT_csatFavor];

true
