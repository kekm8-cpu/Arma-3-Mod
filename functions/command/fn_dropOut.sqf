/*
	Function: TACT_fnc_dropOut

	Description:
		Gives control back to the campaign avatar and closes the map's command
		mode.

		MUST RUN BEFORE TACT_fnc_syncBack, which deletes the entities the records
		point at - one of them being the body the player is looking through.

		Nothing else has to be undone: the soldier the player was goes through
		conclusion like the rest of the roster.

		Also the death path - TACT_fnc_dropIn puts a Killed handler on the body
		that calls this, so a player who is shot hands control back and watches
		the rest of the battle from the map.

	Parameters:
		none

	Returns:
		BOOL - true if the player was in a body on the field and has been
		       returned.
*/

if (isNil "TACT_commandActive" || {!TACT_commandActive}) exitWith { false };

// Closed first, so the map drops back to the campaign layer and nothing is
// still reading a group that is about to be torn down.
TACT_commandActive = false;

// ------------------------------------------------------------------------ //
// BACK TO THE CAMPAIGN AVATAR                                               //
// ------------------------------------------------------------------------ //
if (!isNull TACT_campaignAvatar && {TACT_campaignAvatar != player}) then {
	private _body = player;

	// Simulation only. The avatar stays hidden, invulnerable and captive for
	// the whole campaign (init.sqf); unhiding it here would stand an unarmed
	// civilian up in the open at the end of every battle.
	TACT_campaignAvatar enableSimulation true;

	selectPlayer TACT_campaignAvatar;

	// The body stays in the battle as an AI for whatever is left of it, and is
	// deleted by sync-back with the rest of the roster. It is still the army's
	// soldier; it is simply no longer the one being looked through.
	if (!isNull _body && {alive _body}) then {
		_body removeAllEventHandlers "Killed";
	};
};

// Both containers: a group handle outlives the battle it was selected in, so a
// selection left behind here is one the next drop-in would inherit and the
// prune would not catch until the first click.
TACT_commandSelection      = [];
TACT_commandGroupSelection = [];
TACT_commandArmyId         = "";

// The context menu goes with the selection it addressed. The detachments do
// NOT: they are the army's men and they outlive the commander - see
// TACT_fnc_dropIn, which is where that list is cleared.
call TACT_fnc_closeContextMenu;

// The squad bar was hidden for the map's command mode.
[false] call TACT_fnc_setCommandHud;

diag_log "TACT Command: control returned to the campaign avatar.";

true
