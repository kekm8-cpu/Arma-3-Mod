/*
	Function: STRAT_fnc_buildDrawList

	Description:
		Derives the campaign layer's draw list from campaign state. ONE LIST,
		read by two callers: STRAT_fnc_drawCampaignLayer renders it and
		STRAT_fnc_onMapClick hit-tests against it. Computed in two places they
		would drift, and the drift is invisible until a player clicks something
		that is not there.

		An entity emits a GROUP of items, not several icons that happen to sit
		near each other. Every item carries the same `group` id and the same
		`anchor` array - the record's own position array, by reference, never
		copied - and items are built through one local constructor that demands
		the group id, so an adornment that cannot state its group is
		unconstructable rather than merely a bug.

		Positions and sizes are in ICON UNITS, resolved to metres once per draw
		pass by STRAT_fnc_mapUnitMetres, so an adornment placed at `0.5` stays
		on the icon's edge at every zoom.

		Presentation is derived here from `faction` and `owner` and stored on no
		record. Colour is never read back - hostility comes from
		STRAT_fnc_areHostile.

		Rebuilt every draw frame: armies move on every tick of a resolving
		block, and a cached list is how the drawn and the clickable start to
		disagree. At a handful of armies that costs a few HashMaps a frame; only
		the config texture lookups are cached, because those never change.

	Item keys:
		group     STRING  - id of the group this item belongs to
		kind      STRING  - "army" or "location"
		role      STRING  - "icon", "label", "selectionRing", "orderArrow"
		record    HASHMAP - the record the group is drawn from
		anchor    ARRAY   - the group's shared world position, by reference
		shape     STRING  - "icon", "ellipse", "arrow", or "polyline" (which
		                    nothing emits yet - see STRAT_fnc_drawItems)
		offset    ARRAY   - [x, y] from the anchor, in icon units
		size      ARRAY   - [w, h] in icon units ("icon" shape)
		radius    NUMBER  - in icon units ("ellipse" shape)
		toWorld   ARRAY   - far end, world position ("arrow" shape)
		points    ARRAY   - ordered world positions ("polyline" shape)
		fromEdge  NUMBER  - icon units to push the arrow's origin off the anchor
		texture   STRING  - texture path ("icon" shape)
		artScale  NUMBER  - multiplies the drawn box to compensate for artwork
		                    that does not fill its own texture; 1 for artwork
		                    that does ("icon" shape)
		direction NUMBER  - icon rotation in degrees; 0 for anything that
		                    is not an individual ("icon" shape)
		text      STRING  - label text ("icon" shape)
		textSize  NUMBER  - in icon units
		colour    ARRAY   - [r, g, b, a]
		hitUnits  NUMBER  - click radius in icon units; 0 means not clickable

	Parameters:
		none

	Returns:
		ARRAY of HASHMAP - the draw items, in draw order (back to front).
*/

private _list = [];

// ------------------------------------------------------------------------ //
// ITEM CONSTRUCTOR                                                          //
// ------------------------------------------------------------------------ //
// Group id, kind, record and anchor are positional and mandatory; everything
// else arrives as overrides on a fully-populated default, so the renderer can
// read any key off any item without checking whether it is present.
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
		["anchor", _anchor],          // by reference: one anchor for the group
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

// Identity is compared on id, never with isEqualTo, which content-compares
// HashMaps and would ring two structurally identical armies at once.
private _selectedId = "";
if (!isNil "STRAT_selectedArmy" && {STRAT_selectedArmy isEqualType createHashMap}) then {
	_selectedId = STRAT_selectedArmy getOrDefault ["id", ""];
};

// ------------------------------------------------------------------------ //
// LOCATIONS                                                                 //
// ------------------------------------------------------------------------ //
// Emitted first so armies draw over them. A location is ground; an army is
// something standing on it.
if (!isNil "STRAT_locations") then {
	{
		private _id       = _x;
		private _location = _y;
		private _anchor   = _location get "position";
		private _owner    = _location getOrDefault ["owner", ""];
		private _colour   = STRAT_drawFactionColour getOrDefault [_owner, [0.8, 0.8, 0.8, 1]];

		private _garrison = _location getOrDefault ["garrison", createHashMap];
		private _held     = count (_garrison getOrDefault ["men", []]);

		[_id, "location", _location, _anchor, "icon", createHashMapFromArray [
			["shape", "icon"],
			["texture", [STRAT_drawLocationIcon] call STRAT_fnc_mapIconTexture],
			["colour", _colour],
			["size", [STRAT_drawLocationUnits, STRAT_drawLocationUnits]],
			["hitUnits", STRAT_drawHitUnits]
		]] call _fnc_item;

		[_id, "location", _location, _anchor, "label", createHashMapFromArray [
			["shape", "icon"],
			["size", [0, 0]],
			["offset", [0, -STRAT_drawLabelOffsetUnits]],
			["colour", _colour],
			["text", format ["%1 (%2)", _id, _held]],
			["textSize", STRAT_drawLabelUnits]
		]] call _fnc_item;
	} forEach STRAT_locations;
};

// ------------------------------------------------------------------------ //
// ARMIES                                                                    //
// ------------------------------------------------------------------------ //
{
	private _army    = _x;
	private _id      = _army get "id";
	private _faction = _army getOrDefault ["faction", ""];

	// The record's own position array, not a copy. Every item below shares it,
	// so an army that moves takes its whole group with it by construction
	// rather than by four call sites remembering to agree.
	private _anchor  = _army get "location";

	private _colour  = STRAT_drawFactionColour getOrDefault [_faction, [0.8, 0.8, 0.8, 1]];
	private _icon    = STRAT_drawFactionIcon getOrDefault [_faction, "b_unknown"];

	// The icon owns the group's hit area. Adornments leave hitUnits at 0, so a
	// click resolves to one item per group and the arrow does not become a
	// second, much larger, way to select the army it belongs to.
	[_id, "army", _army, _anchor, "icon", createHashMapFromArray [
		["shape", "icon"],
		["texture", [_icon] call STRAT_fnc_mapIconTexture],
		["colour", _colour],
		["size", [1, 1]],
		["hitUnits", STRAT_drawHitUnits]
	]] call _fnc_item;

	// Strength rides on the label rather than waiting for a dedicated pip:
	// what a plan costs has to be legible while the plan is being made.
	[_id, "army", _army, _anchor, "label", createHashMapFromArray [
		["shape", "icon"],
		["size", [0, 0]],
		["offset", [0, -STRAT_drawLabelOffsetUnits]],
		["colour", _colour],
		["text", format ["%1 (%2)", _army get "name", count (_army getOrDefault ["men", []])]],
		["textSize", STRAT_drawLabelUnits]
	]] call _fnc_item;

	// Adornment 1: selection. A ring AROUND the icon rather than a change to
	// the icon, so there is no presentation state for an exit path to restore.
	if (_id != "" && {_id == _selectedId}) then {
		[_id, "army", _army, _anchor, "selectionRing", createHashMapFromArray [
			["shape", "ellipse"],
			["radius", STRAT_drawRingUnits],
			["colour", STRAT_drawSelectionColour]
		]] call _fnc_item;
	};

	// Adornment 2: the standing order, drawn from the icon's EDGE to where the
	// army has been told to be. Originating at the edge rather than the centre
	// is precisely what cannot be done across a renderer boundary, which is why
	// armies are drawn rather than marked.
	private _order = _army getOrDefault ["pendingOrder", createHashMap];

	if (count _order > 0 && {(_order getOrDefault ["status", ""]) != "complete"}) then {
		private _destination = _order getOrDefault ["destination", []];

		if (count _destination >= 2) then {
			[_id, "army", _army, _anchor, "orderArrow", createHashMapFromArray [
				["shape", "arrow"],
				["toWorld", _destination],
				["fromEdge", STRAT_drawArrowOriginUnits],
				["colour", _colour]
			]] call _fnc_item;
		};
	};
} forEach activeArmies;

_list
