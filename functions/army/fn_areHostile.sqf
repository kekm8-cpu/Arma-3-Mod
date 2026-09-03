/*
	Function: STRAT_fnc_areHostile

	Description:
		Answers whether two factions are hostile to each other. This is where
		the blocs are decided (manifest section 8): it reads faction strings and
		never colour or the Arma side the units are spawned on. Same bloc is a
		rendezvous, not a battle.

		The faction->side map used at deployment is a separate concern and lives
		in STRAT_fnc_factionSide.

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
