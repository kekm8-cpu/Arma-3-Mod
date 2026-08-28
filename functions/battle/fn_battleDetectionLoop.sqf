/*
	Function: TACT_fnc_battleDetectionLoop

	Description:
		Background thread that watches every pair of active armies and hands
		them to TACT_fnc_initiateBattle once they close within 1000m. Must be
		spawned, not called.
*/

while {true} do {
	// Only run detection math if there are at least two armies on the overworld
	if (count activeArmies >= 2) then {
		private _checkedPairs = []; // Track pairs we've already evaluated this tick

        {
            private _armyA = _x;
            
            {
                private _armyB = _x;
                
                // Ensure we aren't comparing an army against itself
                if (!(_armyA isEqualTo _armyB)) then {
                    
                    // Create a unique identifier pair signature to prevent duplicate passes
                    private _pairID = [_armyA get "marker",_armyB get "marker"];
                    private _invertedPairID = [_pairID select 1, _pairID select 0];
                    
                    if (!(_pairID in _checkedPairs) && !(_invertedPairID in _checkedPairs)) then {
                        // Register the pair to enforce our protective boundary gate
                        _checkedPairs pushBack _pairID;
                        
                        private _posA = _armyA get "location";
                        private _posB = _armyB get "location";
                        
                        // Check the flat 2D distance between the two armies
                        if (_posA distance2D _posB < 1000) then {
                            
                            // 1. Halt both armies by clearing their path variables and stopping movement loops safely
                            _armyA set ["path", []];
                            _armyB set ["path", []];
                            
                            // 2. Dynamic Faction Resolution: Ensure _blueArmy goes first and _redArmy goes second
                            private _blueArmy = createHashMap;
                            private _redArmy = createHashMap;
                            
                            if (getMarkerColor (_armyA get "marker") == "ColorBLUE") then {
                                _blueArmy = _armyA;
                                _redArmy = _armyB;
                            } else {
                                _blueArmy = _armyB;
                                _redArmy = _armyA;
                            };
                            
                            // 3. Fire the TACT_fnc_initiateBattle function passing the HashMaps as parameters
                            [_blueArmy, _redArmy] call TACT_fnc_initiateBattle;
                        };
                    };
                };
            } forEach activeArmies;
        } forEach activeArmies;
    };
    sleep 0.5; // Safely isolated background pacing delay
};
