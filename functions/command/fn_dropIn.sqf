/*
	Function: TACT_fnc_dropIn

	Description:
		Hands the player the body of the soldier his army flagged `isPlayer`,
		once the battle has deployed, and turns on the map's command mode.

		Nothing is moved and nothing is inserted. Deployment has already
		spawned the whole roster, the flagged man among them, standing where
		the deployment plan put him - in whatever vehicle the rotation gave
		him, or on foot in his formation slot if it ran out of seats before it
		reached him. All this does is change which of those bodies the player
		is looking through, with selectPlayer.

		That is why the battle layer needs no special case for the player. He
		is a soldier with a soldier record: he is counted in the army's
		strength, his position is part of its centre of mass, sync-back writes
		his condition back into his record, and he can die. No victory
		condition has to know he exists.

		He also has to lead, because the stock F-key commanding UI addresses a
		group through its leader. The flag and the leader flag are usually the
		same man; when they are not, the player takes command anyway - there is
		no version of this interface that works from inside the ranks.

		The avatar the player came from is left standing on the campaign map,
		hidden and out of harm's way, because that is the body
		TACT_fnc_dropOut gives back when the battle ends.

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
// Hidden and made invulnerable rather than deleted: it is the body control
// comes back to, and a stray soldier standing in a field for the length of a
// battle is a body that can be shot.
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

// If the body dies, control goes back to the campaign avatar rather than to
// the death screen. The battle carries on without him and concludes normally -
// his record is dropped by sync-back like any other casualty, and the army
// fights the next one with nobody flagged. Without this the first bullet that
// finds the player ends the campaign.
_unit addEventHandler ["Killed", {
	params ["_dead"];
	_dead removeAllEventHandlers "Killed";

	systemChat "You have been killed. Command reverts to the map.";
	call TACT_fnc_dropOut;
}];

// ------------------------------------------------------------------------ //
// 4. OPEN COMMAND MODE                                                      //
// ------------------------------------------------------------------------ //
TACT_commandActive    = true;
TACT_commandSelection = [];
TACT_commandArmyId    = _army get "id";


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
