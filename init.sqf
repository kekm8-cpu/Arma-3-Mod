// --- MAP CLICK TRIGGER HOOK ---
onMapSingleClick {
    // Reference your global player army object wrapper
    private _army = missionNamespace getVariable ["STRAT_PlayerArmyObj", locationNull];
    if (isNull _army) exitWith { hint "Error: Player army object not found!"; true; };
    if (_army getOrDefault ["isMoving", false]) exitWith { hint "This army is already marching!"; true; };
    
    private _clickedRoad = roadAt _pos;
    if (isNull _clickedRoad) then {
        private _near = _pos nearRoads 300;
        if (count _near > 0) then { _clickedRoad = _near # 0; };
    };
    
    if (isNull _clickedRoad) exitWith { hint "You must click on or near a road!"; true; };
    
    // Execute pathfinding and movement targeting this specific army object
    [_army, _clickedRoad] spawn {
        params ["_army", "_targetRoad"];
        hint "Calculating route for your army...";
        
        private _startRoad = _army get "currentRoad";
        private _calculatedPath = [_startRoad, _targetRoad] call STRAT_fnc_calculateRoadPath;
        
        if (!isNil "_calculatedPath" && {count _calculatedPath > 0}) then {
            hint "Order received: Marching to destination.";
            [_army, _calculatedPath] spawn STRAT_fnc_moveArmyAlongPath;
        } else {
            hint "Pathfinding failed. Destination unreachable.";
        };
    };
    true;
};

if (!hasInterface) exitWith {};

// Find starting road setup
private _startPos = [5693.3, 9308.01, 0];
private _startRoad = roadAt _startPos;
if (isNull _startRoad) then { _startRoad = (_startPos nearRoads 500) # 0; };

// 1. Create the physical UI representation
private _markerName = createMarker ["STRAT_Army_Marker_Player", getPosVisual _startRoad];
_markerName setMarkerType "b_inf";
_markerName setMarkerColor "ColorBLUFOR";
_markerName setMarkerText "1st Mercenary Legion";

// 2. Instantiate the Data Object
STRAT_PlayerArmyObj = createHashMapFromArray [
    ["id", "Player_Legion_1"],
    ["marker", _markerName],
    ["speed", 30], // Try changing this to 60 or 15 to watch it dynamically update!
    ["currentRoad", _startRoad],
    ["isMoving", false]
];
