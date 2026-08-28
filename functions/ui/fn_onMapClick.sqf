/*
	Function: STRAT_fnc_onMapClick

	Description:
		Map click handler for the strategic layer. Two states: with an army
		selected a click issues a movement order, otherwise a click on an army
		marker selects it.

		Clicks only do anything during the planning phase. An order does not
		move anything - it is queued to the army's "pendingOrder" and takes
		effect when the block is committed.

	Parameters:
		0: ARRAY  - units selected on the map
		1: ARRAY  - world position that was clicked
		2: BOOL   - shift held
		3: BOOL   - alt held
*/

params ["_selectedUnits", "_pos", "_shift", "_alt"];

// Commitment is absolute: no order revision once the block is resolving.
if (STRAT_turnPhase != "planning") exitWith {
	hintSilent "The block is resolving. Orders stand until it ends.";
};

// 1. RESOLVE INTERACTIVE MAP CANVAS POINTERS
// Display 12 is the engine's main overworld map; Control 51 is the interactive canvas.
private _mapDisplay = findDisplay 12;
private _mapControl = _mapDisplay displayCtrl 51;

// Check exactly what engine element is resting beneath the user's cursor
private _mouseOverData = ctrlMapMouseOver _mapControl;

// --------------------------------------------------------------------- //
// STATE A: AN ARMY IS CURRENTLY SELECTED -> QUEUE MOVEMENT ORDER
// --------------------------------------------------------------------- //
if (!isNil "STRAT_selectedArmy" && {STRAT_selectedArmy isEqualType createHashMap}) then {

    // Extract the map marker belonging to the currently active selection
    private _selectedMarker = STRAT_selectedArmy get "marker";

    // Write the order to pendingOrder. Nothing marches until commit.
    private _accepted = [STRAT_selectedArmy, _pos] call STRAT_fnc_issueOrder;

    if (_accepted) then {
        // VISUAL CLEANUP & DESELECTION: Restore full opacity (1.0) and wipe selection reference
        _selectedMarker setMarkerAlpha 1.0;
        STRAT_selectedArmy = nil;
    };
    // A rejected order keeps the army selected so the player can pick another
    // destination without reselecting it.

} else {
    // ----------------------------------------------------------------- //
    // STATE B: NO ARMY IS SELECTED -> TRY TO CAPTURE AN ARMY SELECTION
    // ----------------------------------------------------------------- //
    // Check if the native UI layer validates that the player clicked a marker asset
    if (count _mouseOverData > 0 && {(_mouseOverData select 0) == "marker"}) then {
        private _clickedMarkerName = _mouseOverData select 1;

        // Search through the global registry array to find the matching data structure
        {
            private _currentArmyMarker = _x get "marker";

            if (_currentArmyMarker == _clickedMarkerName) exitWith {
                // Cache the matching HashMap address to our global pointer variable
                STRAT_selectedArmy = _x;

                // Reduce the marker's visual alpha opacity by 50% to confirm active selection
                _currentArmyMarker setMarkerAlpha 0.5;

                private _order = _x getOrDefault ["pendingOrder", createHashMap];
                private _standing = if (count _order > 0 && {(_order getOrDefault ["status", ""]) != "complete"}) then {
                    format ["\nStanding order: %1, issued block %2.", _order getOrDefault ["type", "move"], _order getOrDefault ["issuedBlock", 0]]
                } else {
                    ""
                };

                hint format ["Selected Force: %1\nAwaiting destination orders...%2", _x get "name", _standing];
            };
        } forEach activeArmies;
    };
};
