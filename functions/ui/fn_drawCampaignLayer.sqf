/*
	Function: STRAT_fnc_drawCampaignLayer

	Description:
		The map control's Draw event handler. Picks which list the map is
		showing and hands it to STRAT_fnc_drawItems, which is the only thing
		that actually draws (section 11).

		The map has two modes and they do not overlap. Outside a battle it
		shows the campaign: armies and locations across the whole island.
		Inside one, with the player commanding on the ground, it shows the
		fight: the player's own units, what is selected, and the routes they
		have been given. The strategic icons stand down for the duration -
		there are exactly two of them, they sit on top of the battle they
		represent, and they would compete for the same clicks.

		The mode switch lives here rather than in the attachment, so there is
		one Draw handler on the control for the whole mission and the layers
		cannot both think they own the canvas.

		Runs every frame the map is open, so it must not sleep or spawn.

	Parameters:
		0: CONTROL - the map control, passed by the Draw event handler

	Returns:
		nothing
*/

// A UI event handler passes the control in `_this`, and whether that arrives
// bare or wrapped in a one-element array is not worth betting an empty
// strategic map on. Both shapes are accepted.
private _map = controlNull;

if (_this isEqualType controlNull) then {
	_map = _this;
} else {
	if (_this isEqualType [] && {count _this > 0} && {(_this select 0) isEqualType controlNull}) then {
		_map = _this select 0;
	};
};

if (isNull _map) exitWith {};

private _commanding = !isNil "TACT_commandActive" && {TACT_commandActive};

private _list = if (_commanding) then {
	call TACT_fnc_buildCommandList
} else {
	call STRAT_fnc_buildDrawList
};

[_map, _list] call STRAT_fnc_drawItems;
