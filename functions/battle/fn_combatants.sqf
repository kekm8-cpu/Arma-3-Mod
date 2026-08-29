/*
	Function: TACT_fnc_combatants

	Description:
		The living units of a deployed group that count as the army's fighting
		strength - which is every unit in it except the player.

		The commander is in the group but not in the record. He has no soldier
		record, so sync-back never reads him, he is never a casualty, and he
		never leaves the field with the survivors. Counting him would mean an
		army whose last man has fallen is not annihilated, its centre of mass
		is dragged toward wherever its commander happened to be standing, and a
		record with zero men is handed back to a strategic map the commander is
		still standing on.

		Strength is a property of the record, so the record decides it. One
		function, called everywhere `units _group` used to be, so the two
		places that measure a side cannot come to different answers.

	Parameters:
		0: GROUP - a deployed group

	Returns:
		ARRAY of OBJECT - living units, excluding the player.
*/

params [
	["_group", grpNull, [grpNull]]
];

if (isNull _group) exitWith { [] };

(units _group) select { alive _x && {_x != player} }
