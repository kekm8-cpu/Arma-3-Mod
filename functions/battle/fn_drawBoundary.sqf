/*
	Function: TACT_fnc_drawBoundary

	Description:
		Draws (or erases) the red battle boundary circle on the main map by
		attaching a Draw event handler to the map control.

	Parameters:
		0: ARRAY - world position for the centre of the circle
		1: BOOL  - true to draw, false to erase (default true)

	Returns:
		BOOL - true.
*/

params [
	["_midpoint", [0,0,0], [[]]], // Accepts the 3D or 2D center coordinate array
	["_showCircle", true, [true]]  // Boolean flag: true to draw, false to erase
];

// 1. Grab the interactive map control canvas (Control 51 of Display 12)
private _mapCtrl = (findDisplay 12) displayCtrl 51;

// 2. Fetch any previously stored Event Handler ID on this specific control
private _existingEHID = _mapCtrl getVariable ["TACT_mapBoundaryEH_ID", -1];

// --- ERASING / CLEANUP LOGIC ---
if (_existingEHID != -1) then {
    _mapCtrl ctrlRemoveEventHandler ["Draw", _existingEHID];
    _mapCtrl setVariable ["TACT_mapBoundaryEH_ID", -1]; 
};

// Exit early if the function call was explicitly meant to wipe the UI element
if (!_showCircle) exitWith { true };

// --- SETUP VARIABLES ON THE UI CONTROL ---
// Since UI event handlers can't use _thisArgs, we stamp our variables 
// directly onto the map control object so the draw loop can read them inline.
_mapCtrl setVariable ["TACT_mapBoundary_Pos", _midpoint];

// 3. Inject the rendering loop onto the interface canvas layer
private _newEHID = _mapCtrl ctrlAddEventHandler ["Draw", {
    params ["_map"]; // UI Handlers only pass the control handle natively inside _this
    
    // Dynamically fetch our variables right out of the drawing control's namespace
    private _centerWorldPos = _map getVariable ["TACT_mapBoundary_Pos", [0,0,0]];        
    // Convert world position into 2D screen space pixels
    private _screenPos = _map ctrlMapWorldToScreen _centerWorldPos;
    
    // Safety Gate: Only draw vectors if the epicenter is within render bounds
    if (count _screenPos > 0) then {
        // Render the native vector circle on the user interface pass layer
        _map drawEllipse [
            _centerWorldPos,            // Fixed Epicenter Array [X, Y]
            750,        // Dynamic Radius X in meters
            750,        // Dynamic Radius Y in meters
            0,                          // Rotation Angle
            [1, 0, 0, 1],               // Color Array [R, G, B, A] -> Solid Red Boundary
            ""                          // Empty texture outline mode
        ];
    };
}];

// Save the new Event Handler ID so we can target it specifically for deletions later
_mapCtrl setVariable ["TACT_mapBoundaryEH_ID", _newEHID];

true
