onMapSingleClick { [_pos] call STRAT_fnc_onMapClick };

if (!hasInterface) exitWith {};

STRAT_PlayerArmyObj = [
	"Player_Legion_1",
	[5693.3, 9308.01, 0],
	"1st Mercenary Legion",
	30
] call STRAT_fnc_createArmy;
