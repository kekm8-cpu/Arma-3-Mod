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

		Three things are drawn, and the split between them is the tactical
		map's visibility rule:

		  the player          one icon, his own
		  his group's units   one icon each - these are what he selects
		  every other
		  friendly group      one icon over its leader, whole

		A friendly group that is not his collapses because its composition is
		not his to arrange, and because forty allied soldiers drawn man by man
		bury the eight that are his. His own group is never collapsed - it is
		drawn as its units, and no group icon is emitted for it, because one
		would draw the same men a second time as a body he does not command.

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

private _friendly = STRAT_drawFactionColour getOrDefault ["player", [0.25, 0.45, 0.95, 1]];

// ------------------------------------------------------------------------ //
// OTHER FRIENDLY GROUPS                                                     //
// ------------------------------------------------------------------------ //
// One icon per group, over its leader. Emitted first so it draws behind the
// player's own units: where an ally and one of his men overlap, his man is the
// one he needs to see and click.
//
// No hit area, for the reason the commander has none. These are not his to
// order - they are somebody else's group - and a click target he cannot use,
// sitting on top of units he can, is a way to lose orders. That changes the
// day allied groups take an order from the map, and nothing else has to.
{
	private _friendlyGroup = _x;
	private _group   = _friendlyGroup get "group";
	private _faction = _friendlyGroup get "faction";
	private _men     = _friendlyGroup get "men";
	private _anchor  = _friendlyGroup get "anchor";

	private _id = format ["GRP_%1", groupId _group];

	// The campaign layer's tables, unchanged. An allied faction draws in its
	// own colour rather than the player's, so an ally reads as an ally and not
	// as a detachment of his own men.
	private _colour = STRAT_drawFactionColour getOrDefault [_faction, _friendly];
	private _icon   = STRAT_drawFactionIcon getOrDefault [_faction, "b_unknown"];

	[_id, "friendlyGroup", _friendlyGroup, _anchor, "icon", createHashMapFromArray [
		["shape", "icon"],
		["texture", [_icon] call STRAT_fnc_mapIconTexture],
		["colour", _colour],
		["size", [TACT_commandGroupIconUnits, TACT_commandGroupIconUnits]]
	]] call _fnc_item;

	[_id, "friendlyGroup", _friendlyGroup, _anchor, "label", createHashMapFromArray [
		["shape", "icon"],
		["size", [0, 0]],
		["offset", [0, -STRAT_drawLabelOffsetUnits]],
		["colour", _colour],
		["text", format ["%1 (%2)", groupId _group, count _men]],
		["textSize", STRAT_drawLabelUnits]
	]] call _fnc_item;

} forEach (call TACT_fnc_friendlyGroups);

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
