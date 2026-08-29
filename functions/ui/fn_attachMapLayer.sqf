/*
	Function: STRAT_fnc_attachMapLayer

	Description:
		Owns the campaign draw layer's attachment lifecycle (section 11).

		Display 12 does not exist while the map is closed, and a Draw handler
		attached to a null control fails silently and renders nothing. Since
		armies are drawn rather than marked, that failure is not cosmetic - it
		is an empty strategic map - so attachment is driven by the map opening
		and never by anything in campaign state changing.

		Called once at boot. It installs a single scope that then owns the
		lifecycle for the rest of the mission: wait for the map to be open and
		its control built, attach, wait for the map to close, repeat. Map open
		is observed directly rather than taken from a mission event handler,
		because the thing that actually has to be true before attaching is that
		control 51 exists, and that is a frame or more behind the event.

		The handler id is stored on the control, so a re-attach removes its own
		predecessor by id rather than clearing every Draw handler on the map -
		which would take the battle boundary's handler with it. That covers
		both engine behaviours: if the display is destroyed on close the new
		control simply has no id stored, and if it survives, the stale handler
		is removed before the new one goes on.

		Must be called from a scope that can spawn.

	Parameters:
		none

	Returns:
		BOOL - true if the lifecycle was started, false if it was already
		       running.
*/

if (!isNil "STRAT_mapLayerRunning" && {STRAT_mapLayerRunning}) exitWith {
	diag_log "STRAT Draw: campaign layer lifecycle is already running.";
	false
};

STRAT_mapLayerRunning = true;

[] spawn {
	while {true} do {

		// Both conditions matter. `visibleMap` alone can be true a frame or
		// two before the control exists, and a control alone says nothing
		// about whether the player is looking at it.
		waitUntil {
			visibleMap && {!isNull ((findDisplay 12) displayCtrl 51)}
		};

		private _map = (findDisplay 12) displayCtrl 51;

		// Never ctrlRemoveAllEventHandlers here: TACT_fnc_drawBoundary keeps
		// its own Draw handler on this same control.
		private _existing = _map getVariable ["STRAT_campaignLayerEH", -1];
		if (_existing != -1) then {
			_map ctrlRemoveEventHandler ["Draw", _existing];
		};

		private _id = _map ctrlAddEventHandler ["Draw", {
			_this call STRAT_fnc_drawCampaignLayer;
		}];

		_map setVariable ["STRAT_campaignLayerEH", _id];

		diag_log format ["STRAT Draw: campaign layer attached to the map (handler %1).", _id];

		// Hold here until the map closes, then go round and wait for the next
		// opening. Nothing is detached on close - the control's handlers and
		// variables go wherever the control goes.
		waitUntil { !visibleMap };
	};
};

true
