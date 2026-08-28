/*
	Function: STRAT_fnc_onMapClick

	Description:
		Map click handler for the strategic layer. Two states: with an army
		selected a click issues a movement order, otherwise a click on an army
		marker selects it.

	Parameters:
		0: ARRAY  - units selected on the map
		1: ARRAY  - world position that was clicked
		2: BOOL   - shift held
		3: BOOL   - alt held
*/

params ["_selectedUnits", "_pos", "_shift", "_alt"];

// 1. RESOLVE INTERACTIVE MAP CANVAS POINTERS
// Display 12 is the engine's main overworld map; Control 51 is the interactive canvas.
private _mapDisplay = findDisplay 12;
private _mapControl = _mapDisplay displayCtrl 51;

// Check exactly what engine element is resting beneath the user's cursor
private _mouseOverData = ctrlMapMouseOver _mapControl;

// --------------------------------------------------------------------- //
// STATE A: AN ARMY IS CURRENTLY SELECTED -> REGISTER MOVEMENT ORDER
// --------------------------------------------------------------------- //
if (!isNil "STRAT_selectedArmy" && {STRAT_selectedArmy isEqualType createHashMap}) then {
    
    // Extract the map marker belonging to the currently active selection
    private _selectedMarker = STRAT_selectedArmy get "marker";

    // Calculate the optimal path from current army coordinates to the clicked destination vector
    // STRAT_fnc_calculateRoadPath intelligently handles type conversion internally now
    private _calculatedPath = [STRAT_selectedArmy get "location", _pos] call STRAT_fnc_calculateRoadPath;

    if (count _calculatedPath > 0) then {
        // Assign the calculated route directly to the army's internal data keys
        STRAT_selectedArmy set ["path", _calculatedPath];

        // Fire the movement loop handler over to the background scheduler
        [STRAT_selectedArmy] spawn STRAT_fnc_moveArmyAlongPath;

        // VISUAL CLEANUP & DESELECTION: Restore full opacity (1.0) and wipe selection reference
        _selectedMarker setMarkerAlpha 1.0;
        STRAT_selectedArmy = nil;
        
        //hint "Strategic movement orders issued. Column is on the march.";
    } else {
        hint "Invalid movement command. Target area lacks accessible road connectivity.";
    };

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

                hint format ["Selected Force: %1\nAwaiting destination orders...", _x get "name"];
            };
        } forEach activeArmies;
    };
};
