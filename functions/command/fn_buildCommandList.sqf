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
		map's visibility rule. The right-hand column is the CONTROL rule, and
		the two are not the same question:

		  the player          one icon, his own            never selectable
		  his group's units   one icon each                selectable, singly
		  his other groups    one icon over each leader    selectable, whole
		  allied groups       one icon over each leader    never selectable

		The right-click context menu is NOT in this list. It is built from real
		controls on the map's display by TACT_fnc_openContextMenu - see there
		for why - so it is not a drawn thing at all and nothing here has to
		reserve a place for it or worry about drawing over it.

		A group that is not his own collapses because its composition is not his
		to arrange, and because forty other soldiers drawn man by man bury the
		eight that are his. His own group is never collapsed - it is drawn as
		its units, and no group icon is emitted for it, because one would draw
		the same men a second time as a body he does not command.

		A COLLAPSED GROUP OF HIS OWN IS SELECTABLE, and an ally's is not. That
		is the split TACT_fnc_playerGroups and TACT_fnc_alliedGroups were
		written to hold: one list is groups the command layer could give orders
		to, the other is groups it never will, and selection reaching only the
		first is the first thing the split buys. Selecting a group does not
		order it yet - a body of men has no map order until waypoints arrive -
		so what it currently buys the player is a ring and a count, and what it
		buys the interface is the ruler the group icon is sized against.

		Selection is held as GROUPS, in TACT_commandGroupSelection, and never as
		the men inside one. A group is the thing being selected; its membership
		changes under casualties and its leader can be promoted mid-frame, and
		neither of those is a change to what was selected.

		TWO ICON SOURCES, split on individual versus aggregate. A command
		entity and the commander are individuals and take the stock per-unit
		artwork through STRAT_fnc_mapUnitTexture - a rounded silhouette with a
		pointed end, rotated to the entity's heading, which is how the engine's
		own map draws a unit. A collapsed group is an aggregate and keeps the
		NATO box from STRAT_drawFactionIcon. A box over one rifleman says
		something false about what he is, and it reads upright so it cannot
		carry heading; a body of men has no single heading to carry. The two
		symbols mean different things and the map now says which it means.

		The two also do not fill their textures alike, so each family carries
		its own compensation: STRAT_drawUnitArtScale on the unit silhouettes,
		STRAT_drawGroupArtScale on the group boxes. A NATO box is drawn edge to
		edge; a unit silhouette is a small glyph in a mostly transparent
		square, and drawn at the same size it reads as a speck. That
		compensation scales the box the texture is stretched into and not the
		item's `size`, so the glyph grows while the ring and the click area
		stay calibrated against the figure they were chosen for.

		The group figure is nominally 1 - a box needs no rescue - and is
		carried anyway, because it is where the collapsed groups' apparent size
		is tuned. How heavy a body of men reads against the men beside it is a
		judgement made by looking at the map, and this is the one place it can
		be made without dragging a label, a ring or a click area off the icon
		it belongs to.

		Colour comes from STRAT_drawFactionColour, and a collapsed group's
		silhouette from STRAT_drawFactionIcon - the CAMPAIGN layer's tables,
		read here unchanged. There is no battle-only palette. An army the player watched
		march across the strategic map is the same colour and the same shape as
		the men he is now standing among, which is the whole reason the two
		maps can be looked at as one system. The scheme and the reasoning behind
		it are in init.sqf, beside the tables.

		The commander is the one thing on this map coloured by role rather than
		by faction: TACT_commandPlayerColour, yellow. His force is blue and he
		is yellow, and the distinction is deliberate - one is his army and the
		other is him, and confusing the two is how a commander gets ordered
		about like a rifleman.

		A group with no faction stamp still colours correctly. The half the
		player detaches is created by the engine and will never carry one, but
		TACT_fnc_playerGroups resolves it to the stamp of the group it came out
		of before the draw sees it, so the case with no identity of its own
		inherits the right one.

		The player is drawn and never hit-tested. A commander is worth seeing
		on the map, and is not something to select and order.

		Facing is drawn for individuals and for nobody else. Section 15 held
		this open on the grounds that rotating a NATO silhouette is the wrong
		way to show heading, which is still true - it is why the aggregates
		pass 0. The stock unit artwork is built to turn, so the entities can
		have it for the cost of one argument.

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
if (isNil "TACT_commandGroupSelection") then { TACT_commandGroupSelection = [] };

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
		["direction", 0],
		["artScale", 1],
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

// The player's own force colour, from the shared table by way of his group's
// stamp rather than a literal "player", so it follows whoever he is instead of
// asserting who he must be.
private _playerFaction = (group player) getVariable ["STRAT_faction", "player"];
private _friendly = STRAT_drawFactionColour getOrDefault [_playerFaction, [0.25, 0.45, 0.95, 1]];

// ------------------------------------------------------------------------ //
// COLLAPSED GROUPS                                                          //
// ------------------------------------------------------------------------ //
// One icon per group, over its leader, for both lists. Emitted first so they
// draw behind the player's own units: where one of these and one of his men
// overlap, his man is the one he needs to see and click.
//
// HIS OWN GROUPS ARE CLICKABLE; an ally's is not. That is the widening this
// block always said it would take, and it took the half it said it would: an
// ally is never his to move, so a click target on one is a target he cannot
// use sitting on top of units he can, which is a way to lose orders.
//
// The click radius is the group's own, TACT_commandGroupHitUnits, because it is
// chosen against the group's own icon size. The hit-test in
// TACT_fnc_onCommandClick tests the individuals before the groups, so a man
// standing under a group icon - his own leader, most often - wins the tie and
// stays as clickable as he was before groups had an area at all.
//
// Allies are emitted before his own groups so that where the two overlap, his
// reads on top.
private _fnc_groupIcons = {
	params ["_record", "_kind"];

	private _group   = _record get "group";
	private _faction = _record get "faction";
	private _men     = _record get "men";
	private _anchor  = _record get "anchor";

	private _id = format ["GRP_%1", groupId _group];

	// The control rule, in one line. Everything below reads it rather than the
	// kind, so a list that becomes selectable later becomes selectable here.
	private _selectable = _kind == "playerGroup";
	private _selected   = _selectable && {_group in TACT_commandGroupSelection};
	private _hitUnits   = if (_selectable) then {TACT_commandGroupHitUnits} else {0};

	// The campaign layer's tables, with the campaign layer's own fallbacks, so
	// an unstamped group draws as unknown here exactly as it would there rather
	// than as a faction nobody recorded.
	private _colour = STRAT_drawFactionColour getOrDefault [_faction, [0.8, 0.8, 0.8, 1]];
	private _icon   = STRAT_drawFactionIcon getOrDefault [_faction, "b_unknown"];

	[_id, _kind, _record, _anchor, "icon", createHashMapFromArray [
		["shape", "icon"],
		["texture", [_icon] call STRAT_fnc_mapIconTexture],
		["colour", _colour],
		["size", [TACT_commandGroupIconUnits, TACT_commandGroupIconUnits]],
		["artScale", STRAT_drawGroupArtScale],
		["hitUnits", _hitUnits]
	]] call _fnc_item;

	[_id, _kind, _record, _anchor, "label", createHashMapFromArray [
		["shape", "icon"],
		["size", [0, 0]],
		["offset", [0, -STRAT_drawLabelOffsetUnits]],
		["colour", _colour],
		["text", format ["%1 (%2)", groupId _group, count _men]],
		["textSize", STRAT_drawLabelUnits]
	]] call _fnc_item;

	// Its own radius rather than the individuals', because it is drawn around
	// the group's own icon size - and because it is the ruler the group icon is
	// tuned against, which is a job that wants to move without moving theirs.
	// The colour is the shared one: a selection is a selection, whatever kind
	// of thing is in it.
	if (_selected) then {
		[_id, _kind, _record, _anchor, "selectionRing", createHashMapFromArray [
			["shape", "ellipse"],
			["radius", TACT_commandGroupRingUnits],
			["colour", STRAT_drawSelectionColour]
		]] call _fnc_item;
	};
};

{
	[_x, "alliedGroup"] call _fnc_groupIcons;
} forEach (call TACT_fnc_alliedGroups);

{
	[_x, "playerGroup"] call _fnc_groupIcons;
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

	// The stock per-unit artwork, not a NATO box. A box means "a body of men of
	// this type" and this is one man or one truck; and the box reads upright,
	// so it has no way to show which way he is looking. The engine's own
	// silhouette is asymmetric precisely so that rotating it does, which is
	// where the facing below comes from.
	//
	// The NATO class is still named, as the fallback: a vehicle whose config
	// carries no icon draws as a box rather than as a blank, because a wrong
	// symbol is legible and an empty one is a unit the player cannot identify.
	[_id, "commandEntity", _entity, _anchor, "icon", createHashMapFromArray [
		["shape", "icon"],
		["texture", [
			typeOf _obj,
			if (_mounted) then {"b_armor"} else {"b_inf"}
		] call STRAT_fnc_mapUnitTexture],
		["colour", _colour],
		["size", [TACT_commandIconUnits, TACT_commandIconUnits]],
		["artScale", STRAT_drawUnitArtScale],
		["direction", getDir _obj],
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

// The same artwork as his men, because he is one of them - an individual on the
// ground, not an aggregate. He was a b_hq flag while every icon was a NATO box
// and that was the only way to tell him apart; the yellow does that job now,
// and a flag among unit silhouettes reads as a command post rather than as the
// man himself. TACT_commandPlayerIcon is the one line to change it back.
["CMD_PLAYER", "commander", createHashMap, _playerAnchor, "icon", createHashMapFromArray [
	["shape", "icon"],
	["texture", [
		typeOf (vehicle player),
		TACT_commandPlayerIcon
	] call STRAT_fnc_mapUnitTexture],
	["colour", TACT_commandPlayerColour],
	["size", [TACT_commandIconUnits, TACT_commandIconUnits]],
	["artScale", STRAT_drawUnitArtScale],
	["direction", getDir (vehicle player)]
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
