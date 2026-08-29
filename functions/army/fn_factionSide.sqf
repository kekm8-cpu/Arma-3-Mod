/*
	Function: STRAT_fnc_factionSide

	Description:
		Maps a story faction onto the Arma side its units are spawned on, per
		section 8.

		`faction` stays the source of truth for allegiance — hostility is
		decided by STRAT_fnc_areHostile, which reads faction strings and never
		sides. This function is only the packing of four story factions into
		Arma's four sides, so that engine-level relations, group AI and
		targeting line up with the blocs rather than fighting them.

			player    -> INDEPENDENT   friendly to EAST, hostile to WEST
			csat      -> EAST          friendly to INDEPENDENT
			drugLords -> WEST
			nato      -> WEST          shares the cartel side with drugLords

		Arma's side relations are global, so this map and the setFriend block
		in init.sqf are two halves of one decision and must be changed
		together. Putting drugLords on WEST is what buys NATO intervention for
		free: the backer shares a side with the faction it backs.

		Previously fn_deployMen put drugLords on EAST, which collided with
		CSAT and made the patron and the cartel engine-level allies.

	Parameters:
		0: STRING - faction string

	Returns:
		SIDE - the Arma side this faction's units spawn on.
*/

params [
	["_faction", "", [""]]
];

private _sides = createHashMapFromArray [
	["player",    independent],
	["csat",      east],
	["drugLords", west],
	["nato",      west]
];

// An unrecognised faction falls back to the player's side and logs. Nothing
// reaches deployment through the normal path without clearing
// STRAT_fnc_areHostile first, which rejects unknown factions already, so this
// is a backstop for direct calls and the test harness rather than a live case.
if (!(_faction in _sides)) exitWith {
	diag_log format ["STRAT SideAlloc: unknown faction '%1', defaulting to INDEPENDENT.", _faction];
	independent
};

_sides get _faction
