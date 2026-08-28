/*
	Function: STRAT_fnc_areHostile

	Description:
		Answers whether two factions are hostile to each other. `faction` is the
		source of truth for allegiance, so this reads the faction strings and
		never marker colour or the Arma side the units happen to be spawned on.

		Two blocs, per section 8: the player's contractors and their CSAT patron
		against the druglords and their NATO backer. Same bloc is a rendezvous,
		not a battle.

		Note: the faction→Arma-side map used at deployment is a separate
		concern and still needs correcting (`fn_deployMen` puts drugLords on
		OPFOR, which collides with CSAT).

	Parameters:
		0: STRING - first faction
		1: STRING - second faction

	Returns:
		BOOL - true if the two factions are hostile.
*/

params [
	["_factionA", "", [""]],
	["_factionB", "", [""]]
];

private _blocs = createHashMapFromArray [
	["player",    "contractors"],
	["csat",      "contractors"],
	["drugLords", "cartel"],
	["nato",      "cartel"]
];

private _blocA = _blocs getOrDefault [_factionA, ""];
private _blocB = _blocs getOrDefault [_factionB, ""];

// An unrecognised faction is treated as non-hostile. Initiating a battle on a
// typo is worse than missing one, and the log makes it findable.
if (_blocA == "" || {_blocB == ""}) exitWith {
	diag_log format ["STRAT Hostility: unknown faction in pair ['%1','%2'], treating as non-hostile.", _factionA, _factionB];
	false
};

_blocA != _blocB
