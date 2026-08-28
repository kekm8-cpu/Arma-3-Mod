/*
	Function: STRAT_fnc_onMapClick

	Description:
		Map click handler for ordering the player's army to march. Resolves the
		clicked position to a road, then spawns the pathfinding and movement.

	Parameters:
		0: ARRAY - world position that was clicked

	Returns:
		BOOL - always true, to suppress the default map click behaviour.
*/

params ["_pos"];

private _army = missionNamespace getVariable ["STRAT_PlayerArmyObj", createHashMap];
if (count _army == 0) exitWith { hint "Error: Player army object not found!"; true };
if (_army getOrDefault ["isMoving", false]) exitWith { hint "This army is already marching!"; true };

private _clickedRoad = roadAt _pos;
if (isNull _clickedRoad) then {
	private _near = _pos nearRoads 300;
	if (count _near > 0) then { _clickedRoad = _near # 0; };
};

if (isNull _clickedRoad) exitWith { hint "You must click on or near a road!"; true };

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

true
