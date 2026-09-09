/*
	Function: TACT_fnc_buildCommandList

	Description:
		Derives the battle command layer's draw list: what the map shows while
		the player is commanding on the ground. The tactical counterpart of
		STRAT_fnc_buildDrawList, emitting the same item shape into the same
		renderer, on the same terms - every item carries its group id and the
		entity's own anchor, and adornments are placed in icon units off it.

		Five things are drawn. The right-hand column is the CONTROL rule, which
		is a different question from the visibility one:

		  the player          one icon, his own            never selectable
		  his group's units   one icon each                selectable, singly
		  his other groups    one icon over each leader    selectable, whole
		  their routes        a dot per waypoint, joined   a dot is a Delete
		                                                   target, not a click
		  allied groups       one icon over each leader    never selectable

		A ROUTE IS DRAWN FOR EVERY ONE OF HIS GROUPS THAT HAS ONE, selected or
		not: it is the group's standing order, and the map's rule is that the
		cost of a plan is legible while it is being made. The route is read
		back from the engine's waypoint list through TACT_fnc_groupRoute -
		completed waypoints excluded - so what is drawn is what the group will
		walk, not a copy of what it was told. One polyline item for the legs,
		then one dot item per waypoint, all under the group's own id so the
		composition rule holds however many legs there are.

		A dot's hit radius is for the DELETE KEY. It is a hit area on the same
		terms as an icon's - the same units, the same nearest-wins test through
		the same scale - but TACT_fnc_onCommandClick does not test the kind, so
		a click on a dot is a click on the ground under it. Emitted before the
		group icons, so a route's first leg cannot draw over the icon it starts
		from.

		His own group is never ALSO collapsed: no group icon is emitted for it,
		because that would draw the same men twice. Selectability lives here in
		the draw list rather than in the click handler - a click target that
		exists and is then refused is one that will one day stop being refused.

		Selection is held as GROUPS in TACT_commandGroupSelection, never as the
		men inside one: membership changes under casualties and a leader can be
		promoted mid-frame, and neither is a change to what was selected.

		TWO ICON SOURCES, split on individual versus aggregate (manifest section
		11). Command entities and the commander take stock per-unit artwork
		through STRAT_fnc_mapUnitTexture, rotated to heading; a collapsed group
		takes the NATO box from STRAT_drawFactionIcon and passes direction 0.
		The two families do not fill their textures alike, so each carries its
		own compensation - STRAT_drawUnitArtScale and STRAT_drawGroupArtScale -
		applied to the drawn box rather than to the item's `size`, which the
		ring and the click area are calibrated against.

		Colour comes from STRAT_drawFactionColour and STRAT_drawFactionIcon, the
		campaign layer's own tables read here unchanged; there is no battle-only
		palette. The commander is the one thing coloured by role instead:
		TACT_commandPlayerColour.

		The right-click context menu is NOT in this list - it is real controls
		on the map's display, built by TACT_fnc_openContextMenu.

		Rebuilt every frame, like the campaign list: units move continuously,
		and a cached list is how the drawn and the clickable start to
		disagree.

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
		["toEdge", 0],
		["lineWidth", 1],
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
// draw behind the player's own units, and allies before his own groups, so
// where any two overlap the one he can click reads on top.
//
// HIS OWN GROUPS ARE CLICKABLE; an ally's is not - a click target he cannot use
// sitting on top of units he can is a way to lose orders. The click radius is
// the group's own, chosen against the group's own icon size, and
// TACT_fnc_onCommandClick tests individuals before groups so a man standing
// under a group icon wins the tie.
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
	// the group's own icon size and is the ruler STRAT_drawGroupArtScale is
	// tuned against. Shared colour: a selection is a selection.
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

// Read once for both passes below, so the route and the icon it starts from
// are placed off the same anchor.
private _playerGroups = call TACT_fnc_playerGroups;

// ------------------------------------------------------------------------ //
// GROUP ROUTES                                                              //
// ------------------------------------------------------------------------ //
// Before the icons, so the legs draw under them. The first leg starts off the
// group icon's edge and every leg stops short of the dot at each end, in icon
// units, so the gaps hold on screen at every zoom like everything else does.
//
// The dot is the engine's own filled dot marker, in the route's colour. A dot
// carries the group and the engine's index for the waypoint, which is all the
// Delete key needs to remove exactly that one.
{
	private _record = _x;
	private _group  = _record get "group";
	private _route  = [_group] call TACT_fnc_groupRoute;

	if (count _route > 0) then {
		private _id     = format ["GRP_%1", groupId _group];
		private _anchor = _record get "anchor";

		[_id, "groupRoute", _record, _anchor, "route", createHashMapFromArray [
			["shape", "polyline"],
			["points", _route apply {_x select 1}],
			["fromEdge", TACT_commandRouteOriginUnits],
			["toEdge", TACT_commandWaypointClearUnits],
			["lineWidth", TACT_commandRouteLinePixels],
			["colour", TACT_commandRouteColour]
		]] call _fnc_item;

		{
			_x params ["_index", "_position"];

			[_id, "groupWaypoint", createHashMapFromArray [
				["group", _group],
				["index", _index]
			], _position, "waypoint", createHashMapFromArray [
				["shape", "icon"],
				["texture", [TACT_commandWaypointIcon] call STRAT_fnc_mapIconTexture],
				["colour", TACT_commandRouteColour],
				["size", [TACT_commandWaypointDotUnits, TACT_commandWaypointDotUnits]],
				["artScale", TACT_commandWaypointArtScale],
				["hitUnits", TACT_commandWaypointHitUnits]
			]] call _fnc_item;
		} forEach _route;
	};
} forEach _playerGroups;

{
	[_x, "playerGroup"] call _fnc_groupIcons;
} forEach _playerGroups;

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

	// Stock per-unit artwork, not a NATO box: this is one man or one truck, and
	// the silhouette is asymmetric so rotating it shows heading.
	//
	// The NATO class is still named as the FALLBACK - a vehicle whose config
	// carries no icon draws as a box rather than a blank, because a wrong
	// symbol is legible and an empty one is a unit that cannot be identified.
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
// Emitted last so it draws over the units, and with NO hit area: there is no
// such thing as ordering yourself, and a click target on top of the men being
// selected is a way to lose orders.
private _playerAnchor = getPosATL (vehicle player);

// The same artwork as his men, because he is an individual and not an
// aggregate; the yellow is what tells him apart. TACT_commandPlayerIcon is the
// one line to change it back to a flag.
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
