/*
	Function: TACT_fnc_buildCommandList

	Description:
		Derives the battle command layer's draw list: what the map shows while
		the player is commanding on the ground. The tactical counterpart of
		STRAT_fnc_buildDrawList, emitting the same item shape into the same
		renderer, so a route drawn here and an order arrow drawn on the
		campaign map are the same lines by the same law.

		One group per command entity, on the same terms section 11 sets for the
		campaign layer: every item carries its group id and the entity's own
		position array, and adornments are placed in icon units off that
		anchor.

		Four things are drawn, and the split between them is the tactical
		map's visibility rule:

		  the player          one icon, his own, yellow
		  his group's units   one icon each, green - these are what he selects
		  his other groups    one icon over each leader, green, whole
		  allied groups       one icon over each leader, red, whole

		A group that is not his own collapses because its composition is not his
		to arrange, and because forty other soldiers drawn man by man bury the
		eight that are his. His own group is never collapsed - it is drawn as
		its units, and no group icon is emitted for it, because one would draw
		the same men a second time as a body he does not command.

		Colour is ROLE ON THE FIELD, from TACT_commandFriendlyColour and
		TACT_commandAlliedColour, and never the campaign layer's faction table.
		Green and red are Arma's own INDEPENDENT and EAST, which section 8 puts
		the player and CSAT on, so the map agrees with the stock squad bar and
		the engine icons the player already reads. It also draws a detached
		group correctly: that group carries no faction stamp and never will, so
		a faction lookup would fall through to unknown for the exact case this
		layer exists for.

		The player is drawn and never hit-tested. A commander is worth seeing
		on the map, and is not something to select and order.

		Nothing here draws orders yet beyond the selection ring. An individual
		unit's move order is a single destination it is already walking to, and
		a body of men has no map order to draw until group-level command
		arrives to give it one.

		Rebuilt every frame, like the campaign list, and for the same reason:
		units move continuously during a battle, and a cached list is exactly
		how the drawn and the clickable start to disagree.

	Parameters:
		none

	Returns:
		ARRAY of HASHMAP - draw items, in draw order (back to front).
*/

private _list = [];

if (isNull player) exitWith { _list };

if (isNil "TACT_commandSelection") then { TACT_commandSelection = [] };

private _fnc_item = {
	params [
		["_group", "", [""]],
		["_kind", "", [""]],
		["_record", createHashMap, [createHashMap]],
		["_anchor", [0,0,0], [[]]],
		["_role", "", [""]],
		["_fields", createHashMap, [createHashMap]]
	];

	private _item = createHashMapFromArray [
		["group", _group],
		["kind", _kind],
		["role", _role],
		["record", _record],
		["anchor", _anchor],
		["shape", "icon"],
		["offset", [0, 0]],
		["size", [1, 1]],
		["radius", 0],
		["toWorld", []],
		["points", []],
		["fromEdge", 0],
		["texture", STRAT_drawBlankTexture],
		["text", ""],
		["textSize", 0],
		["colour", [1, 1, 1, 1]],
		["hitUnits", 0]
	];

	{ _item set [_x, _y] } forEach _fields;

	_list pushBack _item;
	_item
};

private _friendly = TACT_commandFriendlyColour;

// ------------------------------------------------------------------------ //
// COLLAPSED GROUPS                                                          //
// ------------------------------------------------------------------------ //
// One icon per group, over its leader, for both lists. Emitted first so they
// draw behind the player's own units: where one of these and one of his men
// overlap, his man is the one he needs to see and click.
//
// No hit area on either, for the reason the commander has none. Neither list is
// his to order - one is somebody else's group, the other is somebody else's
// army - and a click target he cannot use, sitting on top of units he can, is a
// way to lose orders. That changes the day group-level command arrives, and it
// changes for TACT_fnc_playerGroups only: an ally is never his to move.
//
// Allies are emitted before his own groups so that where the two overlap, his
// reads on top.
private _fnc_groupIcons = {
	params ["_record", "_kind", "_colour"];

	private _group   = _record get "group";
	private _faction = _record get "faction";
	private _men     = _record get "men";
	private _anchor  = _record get "anchor";

	private _id = format ["GRP_%1", groupId _group];

	// Colour is the role passed in, not a faction lookup - see the header. The
	// silhouette still comes from the campaign table, because that is a
	// statement about what kind of force this is rather than about whose side
	// it is on, and an ally with no stamp draws as unknown rather than as a
	// faction nobody recorded.
	private _icon = STRAT_drawFactionIcon getOrDefault [_faction, "b_unknown"];

	[_id, _kind, _record, _anchor, "icon", createHashMapFromArray [
		["shape", "icon"],
		["texture", [_icon] call STRAT_fnc_mapIconTexture],
		["colour", _colour],
		["size", [TACT_commandGroupIconUnits, TACT_commandGroupIconUnits]]
	]] call _fnc_item;

	[_id, _kind, _record, _anchor, "label", createHashMapFromArray [
		["shape", "icon"],
		["size", [0, 0]],
		["offset", [0, -STRAT_drawLabelOffsetUnits]],
		["colour", _colour],
		["text", format ["%1 (%2)", groupId _group, count _men]],
		["textSize", STRAT_drawLabelUnits]
	]] call _fnc_item;
};

{
	[_x, "alliedGroup", TACT_commandAlliedColour] call _fnc_groupIcons;
} forEach (call TACT_fnc_alliedGroups);

{
	[_x, "playerGroup", _friendly] call _fnc_groupIcons;
} forEach (call TACT_fnc_playerGroups);

// ------------------------------------------------------------------------ //
// COMMAND ENTITIES                                                          //
// ------------------------------------------------------------------------ //
{
	private _entity  = _x;
	private _obj     = _entity get "obj";
	private _slot    = _entity get "slot";
	private _mounted = _entity get "mounted";
	private _men     = _entity get "men";

	private _id = format ["CMD_%1", _slot];

	// getPosATL returns a fresh array each call, so unlike an army's stored
	// `location` this cannot be shared by reference. It is read once and
	// handed to every item in the group instead, which gives the same
	// guarantee for the frame: one anchor, one group.
	private _anchor = getPosATL _obj;

	private _selected = _obj in TACT_commandSelection;

	// An entity with nothing to issue orders through is drawn dimmed. It is
	// still on the map - it is a vehicle full of our men - but it will not
	// take a move order and should not look like it will.
	private _colour = if (count (_entity get "order") == 0) then {
		[_friendly select 0, _friendly select 1, _friendly select 2, 0.45]
	} else {
		_friendly
	};

	[_id, "commandEntity", _entity, _anchor, "icon", createHashMapFromArray [
		["shape", "icon"],
		["texture", [if (_mounted) then {"b_armor"} else {"b_inf"}] call STRAT_fnc_mapIconTexture],
		["colour", _colour],
		["size", [TACT_commandIconUnits, TACT_commandIconUnits]],
		["hitUnits", TACT_commandHitUnits]
	]] call _fnc_item;

	// The number the stock squad bar knows this unit by, so the map and the
	// keyboard are talking about the same man. A vehicle also reports how many
	// of ours are riding in it, because that is what the one icon stands for.
	private _label = if (_mounted && {count _men > 1}) then {
		format ["%1 (%2)", _slot, count _men]
	} else {
		str _slot
	};

	[_id, "commandEntity", _entity, _anchor, "label", createHashMapFromArray [
		["shape", "icon"],
		["size", [0, 0]],
		["offset", [0, -STRAT_drawLabelOffsetUnits]],
		["colour", _colour],
		["text", _label],
		["textSize", STRAT_drawLabelUnits]
	]] call _fnc_item;

	if (_selected) then {
		[_id, "commandEntity", _entity, _anchor, "selectionRing", createHashMapFromArray [
			["shape", "ellipse"],
			["radius", STRAT_drawRingUnits],
			["colour", STRAT_drawSelectionColour]
		]] call _fnc_item;
	};

} forEach (call TACT_fnc_commandEntities);

// ------------------------------------------------------------------------ //
// THE COMMANDER                                                             //
// ------------------------------------------------------------------------ //
// Emitted last so it draws over the units, and with no hit area: there is no
// such thing as ordering yourself, and a click target sitting on top of the
// men you are trying to select is a way to lose orders.
private _playerAnchor = getPosATL (vehicle player);

["CMD_PLAYER", "commander", createHashMap, _playerAnchor, "icon", createHashMapFromArray [
	["shape", "icon"],
	["texture", ["b_hq"] call STRAT_fnc_mapIconTexture],
	["colour", TACT_commandPlayerColour],
	["size", [TACT_commandIconUnits, TACT_commandIconUnits]]
]] call _fnc_item;

["CMD_PLAYER", "commander", createHashMap, _playerAnchor, "label", createHashMapFromArray [
	["shape", "icon"],
	["size", [0, 0]],
	["offset", [0, -STRAT_drawLabelOffsetUnits]],
	["colour", TACT_commandPlayerColour],
	["text", "YOU"],
	["textSize", STRAT_drawLabelUnits]
]] call _fnc_item;

_list
