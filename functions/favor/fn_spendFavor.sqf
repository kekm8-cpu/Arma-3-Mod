/*
	Function: STRAT_fnc_spendFavor

	Description:
		Debits CSAT Favor if the balance covers the cost. Returns whether the
		spend went through.

		This is the hook, not the mechanic. Build plan 1.3 asks for the
		balance and the call point only: the asset catalogue, the spend menu,
		and the accrual side of favor are phase 3.7.

		It exists this early because favor assets - rare CSAT vehicles,
		airstrikes, spec-ops backup, intel - are called in *during* battles
		(section 9, stage 8), so the support-call paths written during the
		phase two deep dive need a single place to charge.

		The debit is all-or-nothing: an unaffordable spend changes nothing and
		returns false. A partial debit would leave the caller having paid for
		an asset it did not get.

		There is deliberately no matching addFavor. Favor is gained from
		completing CSAT objectives and from restraint, which are strategic
		triggers with no battle-layer caller, so nothing would be retrofitted
		by leaving it to 3.7. The two directions built here are exactly the
		two the battle layer calls.

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
