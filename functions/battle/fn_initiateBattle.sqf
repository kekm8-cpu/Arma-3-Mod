/*
	Function: TACT_fnc_initiateBattle

	Description:
		Transitions two colliding strategic armies into a tactical engagement:
		pulls them out of the overworld loop, finds the midpoint between them,
		deploys both rosters and orders them to converge.

	Parameters:
		0: HASHMAP - the BLUFOR side army
		1: HASHMAP - the OPFOR side army

	Returns:
		BOOL - true.
*/

params [
	["_blueArmy", createHashMap, [createHashMap]],
	["_redArmy", createHashMap, [createHashMap]]
];

// 1. Core State Management: Remove the armies from the global overworld tracking loop
activeArmies = activeArmies - [_blueArmy, _redArmy];

// 2. Geometric Calculations: Establish the conflict line of scrimmage
private _bluePos = _blueArmy get "location";
private _redPos  = _redArmy get "location";
private _midpoint = [
    ((_bluePos select 0) + (_redPos select 0)) / 2,
    ((_bluePos select 1) + (_redPos select 1)) / 2,
    0
];

// 3. Path Generation to the Conflict Point
private _blueStartRoad = [_bluePos, _midpoint] call STRAT_fnc_calculateRoadPath;
private _redStartRoad  = [_redPos, _midpoint] call STRAT_fnc_calculateRoadPath;

// 4. Physical Vehicle Deployment Phase
[_blueArmy, _blueStartRoad] call TACT_fnc_deployVehicles;
[_redArmy, _redStartRoad] call TACT_fnc_deployVehicles;

// 5. Tactical Infantry Spawning and Vehicle Mounting Phase
private _blueGroup = [_blueArmy] call TACT_fnc_deployMen;
private _redGroup  = [_redArmy] call TACT_fnc_deployMen;

// 6. Formational Layout Configuration
_blueGroup setFormation "COLUMN";
_redGroup setFormation "COLUMN";

_blueGroup move _midpoint;
_redGroup move _midpoint;

// 7. Draw battle boundaries
[_midpoint, true] call TACT_fnc_drawBoundary;

// Return true to indicate successful deployment transition handling
true
