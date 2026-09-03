/*
	Function: TACT_fnc_buildEngagement

	Description:
		Builds the engagement record (lifecycle stage 5). Every battle type
		produces one of these and the lifecycle reads it rather than branching
		on type - one lifecycle, three parameter sets.

		Open-field only: no `capturePoint`, no `sprung`, and `deployment` names
		the placement that actually runs rather than the one intended. Set-piece
		and ambush extend this, they do not replace it.

		Each side's position at the moment the battle opens is recorded, because
		exit classification needs where the army came from and where it was
		trying to go.

	Parameters:
		0: HASHMAP - first army
		1: HASHMAP - second army
		2: NUMBER  - hours of block time left when the battle opens

	Returns:
		HASHMAP - the engagement record.
*/

params [
	["_armyA", createHashMap, [createHashMap]],
	["_armyB", createHashMap, [createHashMap]],
	["_blockHoursRemaining", 0, [0]]
];

private _posA = _armyA get "location";
private _posB = _armyB get "location";

// Open field: the anchor is the midpoint between the two armies.
private _anchor = [
	((_posA select 0) + (_posB select 0)) / 2,
	((_posA select 1) + (_posB select 1)) / 2,
	0
];

// Engagements carry an id for the same reason armies do: they are compared and
// removed from arrays, and HashMaps compare by content, so two structurally
// identical records would be indistinguishable without one.
if (isNil "TACT_nextEngagementId") then { TACT_nextEngagementId = 0 };
TACT_nextEngagementId = TACT_nextEngagementId + 1;

// Roles are symmetric in a meeting engagement, so the assignment is arbitrary.
// It only matters for battle types where the defender is already in place.
createHashMapFromArray [
	["id", format ["ENG_%1", TACT_nextEngagementId]],
	["type", "openField"],
	["attacker", _armyA],
	["defender", _armyB],
	["attackerOrigin", +_posA],
	["defenderOrigin", +_posB],
	["attackerGroup", grpNull],
	["defenderGroup", grpNull],
	["boundaryAnchor", _anchor],
	["boundaryRadius", TACT_boundaryRadius],

	["deployment", "midpointConverge"],

	// Only conditions actually evaluated are listed. Rout needs a morale model
	// and surrender the set-piece capture point; listing either here would
	// claim it is live.
	["victoryConditions", ["annihilation", "breakthrough", "repulse", "blockClockExpiry"]],

	["blockTimeRemaining", _blockHoursRemaining]
]
