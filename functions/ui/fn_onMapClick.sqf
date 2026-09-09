/*
	Function: STRAT_fnc_onMapClick

	Description:
		Map click handler for the strategic layer. Two states: with an army
		selected a click issues a movement order, otherwise a click hit-tests
		the campaign draw list and selects what it landed on.

		Selection resolves against the same list STRAT_fnc_drawCampaignLayer
		renders, converted through the same STRAT_fnc_mapUnitMetres call, so
		what is clickable is what is drawn by construction. `ctrlMapMouseOver`
		resolves a marker under the cursor and armies are not marked, so the
		hit-test is written by hand here - the cost manifest section 11
		accepts.

		Clicks only do anything during the planning phase. An order does not
		move anything - it is queued to the army's "pendingOrder" and takes
		effect when the block is committed.

		THE RETURN VALUE IS AN ENGINE SWITCH. This runs from the onMapSingleClick
		COMMAND, whose return value the engine reads: true overrides the
		click's default action, and the default action is the player's
		PERSONAL WAYPOINT on SHIFT+click. So this is the one place that gesture
		is taken away, and only while commanding, where SHIFT+click appends a
		group waypoint and the engine's marker landed under every one of them.
		The campaign map keeps it.

		It has to be the command. The MapSingleClick mission event handler
		fires the same callback but cannot override the click, and the command
		is bound to the player's unit and discarded by selectPlayer - which is
		why STRAT_fnc_attachMapLayer re-issues it on every map open rather
		than init.sqf issuing it once. Manifest section 13.2 has the finding.

	Parameters (built by the binding from the command's special variables):
		0: ARRAY  - units selected on the map
		1: ARRAY  - world position that was clicked
		2: BOOL   - alt held
		3: BOOL   - shift held

	Returns:
		BOOL - true to stop the engine's own handling of the click. True while
		       commanding; otherwise nothing, which the engine reads as false.
*/

params ["_selectedUnits", "_pos", "_alt", "_shift"];

// The map has two modes. While the player is commanding a battle on the
// ground, clicks belong to TACT_fnc_onCommandClick, which is driven off the
// map control's own mouse handlers because it needs CTRL and this callback
// only reports SHIFT and ALT. Standing down silently is the point - a hint
// here would fire on every tactical click.
//
// TRUE, not nothing: this is what stops the engine dropping its personal
// waypoint under every SHIFT+click while the map is the command surface.
if (!isNil "TACT_commandActive" && {TACT_commandActive}) exitWith { true };

// Commitment is absolute: no order revision once the block is resolving.
if (STRAT_turnPhase != "planning") exitWith {
	hintSilent "The block is resolving. Orders stand until it ends.";
};

// --------------------------------------------------------------------- //
// STATE A: AN ARMY IS CURRENTLY SELECTED -> QUEUE MOVEMENT ORDER
// --------------------------------------------------------------------- //
if (!isNil "STRAT_selectedArmy" && {STRAT_selectedArmy isEqualType createHashMap}) exitWith {

    // Write the order to pendingOrder. Nothing marches until commit.
    private _accepted = [STRAT_selectedArmy, _pos] call STRAT_fnc_issueOrder;

    if (_accepted) then {
        // Dropping the variable is the whole of the deselection: the ring is
        // emitted by the draw list only while it is set, so there is no
        // presentation state for any exit path to put back.
        STRAT_selectedArmy = nil;
    };

    // A rejected order keeps the army selected so the player can pick another
    // destination without reselecting it.
};

// --------------------------------------------------------------------- //
// STATE B: NOTHING SELECTED -> HIT-TEST THE DRAW LIST
// --------------------------------------------------------------------- //
private _map = (findDisplay 12) displayCtrl 51;
private _metresPerUnit = [_map] call STRAT_fnc_mapUnitMetres;

if (_metresPerUnit <= 0) exitWith {
	diag_log "STRAT Draw: click could not measure the map scale, selection skipped.";
};

// Hit radii are in icon units like everything else, so the grab area holds a
// constant size on screen: an army stays as easy to click zoomed out, where
// its icon covers kilometres, as zoomed in, where it covers metres.
private _hitItem = createHashMap;
private _hitDistance = -1;

{
	private _hitUnits = _x getOrDefault ["hitUnits", 0];

	if (_hitUnits > 0) then {
		private _anchor = _x get "anchor";
		private _distance = _pos distance2D _anchor;

		// Nearest wins, so overlapping groups resolve to the one actually
		// clicked rather than to whichever was emitted first.
		if (_distance <= (_hitUnits * _metresPerUnit)
			&& {_hitDistance < 0 || {_distance < _hitDistance}}) then {
			_hitDistance = _distance;
			_hitItem = _x;
		};
	};
} forEach (call STRAT_fnc_buildDrawList);

if (count _hitItem == 0) exitWith {};

private _record = _hitItem get "record";

switch (_hitItem get "kind") do {

	case "army": {
		STRAT_selectedArmy = _record;

		private _order = _record getOrDefault ["pendingOrder", createHashMap];
		private _standing = if (count _order > 0 && {(_order getOrDefault ["status", ""]) != "complete"}) then {
			format ["\nStanding order: %1, issued block %2.", _order getOrDefault ["type", "move"], _order getOrDefault ["issuedBlock", 0]]
		} else {
			""
		};

		hint format [
			"Selected Force: %1 (%2 men)\nAwaiting destination orders...%3",
			_record get "name",
			count (_record getOrDefault ["men", []]),
			_standing
		];
	};

	// A location has no mechanic to click yet (phase 3.8), so this reports the
	// record and stops. It is here because a group that draws but cannot be
	// clicked at all is the same drift in the other direction.
	case "location": {
		private _garrison = _record getOrDefault ["garrison", createHashMap];

		hint format [
			"%1\nType: %2\nOwner: %3\nGarrison: %4 men, %5 vehicle(s)",
			_record get "id",
			_record getOrDefault ["type", "?"],
			_record getOrDefault ["owner", "?"],
			count (_garrison getOrDefault ["men", []]),
			count (_garrison getOrDefault ["vehicles", []])
		];
	};
};
