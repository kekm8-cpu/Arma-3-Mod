/*
	Function: TACT_fnc_dropIn

	Description:
		Hands the player the body of the soldier his army flagged `isPlayer`,
		once the battle has deployed, and turns on the map's command mode.

		NOTHING IS MOVED AND NOTHING IS INSERTED. Deployment already spawned the
		whole roster, the flagged man among them; all this does is change which
		of those bodies the player looks through, with selectPlayer. That is why
		no victory condition, casualty count or position sum has a special case
		for him.

		He also has to LEAD, because the stock F-key UI addresses a group
		through its leader. The isPlayer flag and the leader flag are usually
		the same man; when they are not, the player takes command anyway.

		The one thing touched beyond the body is the speed cap deployment puts
		on a partly mounted column, lifted where the player turns out to be the
		driver: the cap exists to hold an AI driver to the men on foot, and
		there is no AI driver to hold.

		The avatar the player came from is left standing with its simulation
		stopped, because that is the body TACT_fnc_dropOut gives back.

	Parameters:
		0: HASHMAP - engagement record, already deployed

	Returns:
		BOOL - true if the player took a body on the field.
*/

params [
	["_engagement", createHashMap, [createHashMap]]
];

private _sides = [
	[_engagement get "attacker", _engagement get "attackerGroup"],
	[_engagement get "defender", _engagement get "defenderGroup"]
];

// ------------------------------------------------------------------------ //
// 1. FIND THE FLAGGED MAN                                                   //
// ------------------------------------------------------------------------ //
private _army    = createHashMap;
private _group   = grpNull;
private _unit    = objNull;
private _soldier = createHashMap;

{
	_x params ["_candidateArmy", "_candidateGroup"];

	{
		if (_x getOrDefault ["isPlayer", false]) exitWith {
			private _obj = _x getOrDefault ["obj", objNull];

			// Flagged but not on the ground: deployment leaves `obj` null for
			// a man it could not place. He is still on the roster and still
			// alive - he simply is not in this battle, so there is no body to
			// take.
			if (!isNull _obj && {alive _obj}) then {
				_army    = _candidateArmy;
				_group   = _candidateGroup;
				_unit    = _obj;
				_soldier = _x;
			};
		};
	} forEach (_candidateArmy getOrDefault ["men", []]);
} forEach _sides;

if (isNull _unit) exitWith {
	diag_log "TACT Command: no deployed soldier is flagged isPlayer, battle runs watched.";
	false
};

// ------------------------------------------------------------------------ //
// 2. PUT THE CAMPAIGN AVATAR AWAY                                           //
// ------------------------------------------------------------------------ //
// Remembered before the switch, because afterwards `player` is somebody else.
// Put away rather than deleted: it is the body control comes back to.
//
// init.sqf already hid it and made it invulnerable, so those two are no-ops on
// the normal path. The hideObject is not: hiding does not reliably take on a
// unit that is currently the player, and by this line the avatar is an ordinary
// object. Simulation is the one piece that belongs here; fn_dropOut restores
// it.
private _avatar = player;

if (isNull TACT_campaignAvatar) then { TACT_campaignAvatar = _avatar };

// ------------------------------------------------------------------------ //
// 3. TAKE THE BODY                                                          //
// ------------------------------------------------------------------------ //
selectPlayer _unit;
_group selectLeader _unit;

if (!isNull _avatar && {_avatar != _unit}) then {
	_avatar hideObject true;
	_avatar allowDamage false;
	_avatar enableSimulation false;
};

// Deployment caps a partly mounted column at foot pace (TACT_fnc_deployMen),
// and that cap is meant for an AI driver. Whether limitSpeed binds a
// player-driven vehicle is not settled by the wiki, so it is lifted where he is
// the one driving rather than discovered as a truck that will not exceed
// 10 km/h for no visible reason.
//
// ONLY where he drives: a passenger leaves an AI at the wheel, and that AI
// should still be held to the foot element.
private _playerVehicle = objectParent _unit;

if (!isNull _playerVehicle && {driver _playerVehicle == _unit}) then {
	// The documented way to remove a limit: the engine default is twice the
	// vehicle's configured maxSpeed. Guarded because a config that does not
	// declare one would otherwise cap him at zero.
	private _configMax = getNumber (configOf _playerVehicle >> "maxSpeed");
	private _noLimit = if (_configMax > 0) then {2 * _configMax} else {1e10};

	_playerVehicle limitSpeed _noLimit;
};

// If the body dies, control goes back to the campaign avatar rather than the
// death screen. The battle concludes normally and his record is dropped by
// sync-back like any other casualty. Without this the first bullet that finds
// the player ends the campaign.
_unit addEventHandler ["Killed", {
	params ["_dead"];
	_dead removeAllEventHandlers "Killed";

	systemChat "You have been killed. Command reverts to the map.";
	call TACT_fnc_dropOut;
}];

// ------------------------------------------------------------------------ //
// 4. OPEN COMMAND MODE                                                      //
// ------------------------------------------------------------------------ //
TACT_commandActive         = true;
TACT_commandSelection      = [];
TACT_commandGroupSelection = [];
TACT_commandArmyId         = _army get "id";

call TACT_fnc_closeContextMenu;

// Cleared HERE rather than in TACT_fnc_dropOut: dropping out is not the end of
// a detachment. A commander who is killed leaves his detachments on the field,
// still his army's men, still counted, still fighting.
// TACT_fnc_concludeBattle is what ends them.
TACT_commandDetachments = [];
TACT_commandDetachCount = 0;


diag_log format [
	"TACT Command: player has taken %1 in %2.",
	_soldier getOrDefault ["className", "?"],
	_army get "name"
];

systemChat format [
	"You are with %1. Close the map for the squad bar; open it to give orders.",
	_army get "name"
];

true
