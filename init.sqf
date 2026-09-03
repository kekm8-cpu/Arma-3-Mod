// =========================================================================
// BLOCK 1: STATE INITIALIZATION & DATA SETUP
// =========================================================================
// Global variables, faction relations, and the structured "Army" HashMap
// objects that make up the overworld. The functions themselves live under
// functions\ and are compiled by CfgFunctions in description.ext.

// Wait for main displays to load
waitUntil {!isNull (findDisplay 46) && !isNull (findDisplay 12)};

// ------------------------------------------------------------------------- //
// SIDE RELATIONS (manifest section 8)                                        //
// ------------------------------------------------------------------------- //
// Relations are global, so this block and STRAT_fnc_factionSide are two halves
// of one decision and must change together. setFriend takes 0..1 and the engine
// reads anything above 0.6 as friendly, so the blocs are written as extremes.

// The contractors and their CSAT patron
independent setFriend [east, 1];
east setFriend [independent, 1];

// The contractors against the cartel and its NATO backer
independent setFriend [west, 0];
west setFriend [independent, 0];

// The patron against the cartel. WEST and EAST are permanently hostile in the
// engine and setFriend cannot change that; the pair is written anyway so the
// whole relation map reads from one block.
east setFriend [west, 0];
west setFriend [east, 0];

// Initialize the central tracker for all active forces on the map
activeArmies = [];

// ------------------------------------------------------------------------- //
// TURN MODEL STATE (manifest section 5)                                      //
// ------------------------------------------------------------------------- //

STRAT_blockLengthHours = 4;   // Block length in game hours
STRAT_blocksPerDay     = 6;   // Six blocks per day

// Compression of the watched execution phase, in real seconds per hour of
// block time. Paces marching only - battles run at 1:1 and keep their own
// clock (TACT_battleRealSecondsMax). Untuned; defined only here.
STRAT_realSecondsPerBlockHour = 30;

// End the watch early once every army is idle. The rest of the block still
// passes on the clock; there is simply nothing left to watch.
STRAT_skipIdleResolution = true;

STRAT_blockIndex        = 0;           // Blocks elapsed since campaign start
STRAT_turnPhase         = "planning";  // "planning" or "resolving"
STRAT_resolutionRunning = false;       // Guards against a double commit

// The world clock moves in block steps, not in real time, so it is pinned as
// slow as the engine allows and advanced explicitly by STRAT_fnc_advanceClock.
setTimeMultiplier 0.1;

// ------------------------------------------------------------------------- //
// FAVOR ECONOMY BALANCES (manifest section 3)                                //
// ------------------------------------------------------------------------- //
// Balances only. The two call points are STRAT_fnc_addAggression and
// STRAT_fnc_spendFavor; accrual triggers, decay, display and the spend menu
// are phase 3.7.

STRAT_natoAggression = 0;

// PLACEHOLDER stake, not an economy decision: nothing earns Favor until 3.7,
// and a zero balance leaves every phase-two support-call path untestable.
STRAT_csatFavor = 100;

// ------------------------------------------------------------------------- //
// FATIGUE CURVE (manifest section 6)                                         //
// ------------------------------------------------------------------------- //
// Read by STRAT_fnc_armyFatigue to turn per-soldier exertion into an
// army-level 0..1 value. Nothing writes exertion yet (build plan 2.6), so
// every army currently reports 0.
//
// UNTUNED placeholders. At these values a soldier reads roughly 0.02 fatigued
// after two hours on foot, 0.18 after four (one full block of marching), 0.51
// after six, and fully spent at eight.
STRAT_fatigueFreeHours  = 1;   // Exertion below this costs nothing
STRAT_fatigueSpentHours = 8;   // Exertion at or above this is fully spent
STRAT_fatigueCurvePower = 2;   // >1 steepens; 1 would be a flat ramp

// ------------------------------------------------------------------------- //
// BATTLE STATE                                                               //
// ------------------------------------------------------------------------- //

// Contact radius must stay below twice the boundary radius. Armies deploy from
// their own positions toward the midpoint, so at the moment of contact each is
// half the contact radius from the anchor; if that exceeds the boundary radius
// they start the battle already outside the boundary and it ends instantly.
TACT_contactRadius  = 1000;  // Hostile armies inside this distance engage
TACT_boundaryRadius = 750;   // Battle boundary; leaving it ends the battle

// One attended battle at a time: further contacts wait rather than opening
// battles nobody is at, until auto-resolution exists (phase 3.1).
TACT_maxAttendedBattles = 1;

// The battle clock. Battles run at 1:1 real time and break off at 40 minutes
// into mutual disengage.
TACT_battleRealSecondsMax = 2400;

// What a battle costs the strategic clock - battle time is block time, one for
// one (manifest section 5). The cost is clamped to the block time left when the
// battle opened, so a battle can never outlast the block it began in.
TACT_blockSecondsPerBattleSecond = 1;

// ------------------------------------------------------------------------- //
// DEPLOYMENT FORMATION                                                       //
// ------------------------------------------------------------------------- //
// Both deployment routines work off one point and one bearing per army
// (computed by fn_initiateBattle): vehicles run forward from it as a column,
// dismounted men fall in behind it as a staggered file, so infantry is never
// spawned on top of its own transport.
//
// Metres, march-order spacings rather than combat ones. Untuned - they get a
// pass with boundary radius and the battle clock in phase 2.
TACT_deployColumnSpacing = 15;  // Between vehicles, along the column
TACT_deployFootWidth     = 2;   // Men abreast in the dismounted file
TACT_deployFootSpacing   = 6;   // Between files, across the bearing
TACT_deployFootDepth     = 8;   // Between ranks, back along the bearing

// What a partly mounted column is held to, in km/h, so its trucks do not
// answer the group's move order at four times the pace of the men walking
// behind them. Applied per vehicle with limitSpeed, and only when somebody is
// on foot - a fully mounted army is capped by nothing.
//
// A jog rather than a walk: the BIKI's limitSpeed example uses 5 km/h for
// "walking speed", but AI infantry given a move order in AWARE jog, and 5 would
// leave the trucks crawling behind their own escort. Untuned.
TACT_deployFootPaceKmh   = 10;

// ------------------------------------------------------------------------- //
// THE SIDE ANCHOR                                                            //
// ------------------------------------------------------------------------- //
// createUnit does NOT put a man on the side of the group it creates him in.
// TACT_fnc_deployMen works around it on every deployment by joining men across
// from a holding group under a COLONEL-ranked anchor of the destination side.
// The finding and the technique are manifest section 13.1.
//
// One class per Arma side. Each MUST be genuinely configured on the side it is
// keyed under - a class that shares the problem cannot be the cure for it.
// Base-game classes only: the anchor lives inside one frame and is never seen.
//
// Keyed by `str side` because a HashMap key is a string or a number and SIDE is
// neither. fn_deployMen builds its key the same way, so the two cannot drift.
TACT_sideAnchorClass = createHashMapFromArray [
    [str independent, "I_Soldier_SL_F"],
    [str west,        "B_Soldier_SL_F"],
    [str east,        "O_Soldier_SL_F"],
    [str civilian,    "C_man_1"]
];

// ------------------------------------------------------------------------- //
// BATTLE COMMAND MODE (manifest section 14)                                  //
// ------------------------------------------------------------------------- //
// Two command surfaces, never at once: map closed, Arma's stock squad bar
// commands untouched; map open, the bar is hidden and the map commands - left
// click an icon to select, CTRL to add or remove, click terrain to move the
// selection.
//
// A terrain click addresses whoever is selected and an empty selection
// addresses nobody; it never falls back to the whole group, which the player
// leads himself. A selected unit gets one destination and no more - chained
// waypoints and held ground are engine features at the GROUP level and arrive
// with group-level command.

TACT_commandActive    = false;  // True only while the player holds a body on the field
TACT_commandArmyId    = "";     // Which army record the player is currently leading

// TWO CONTAINERS, ONE CONCEPT. An OBJECT and a GROUP are different engine
// types taking different orders, and TACT_fnc_onCommandClick prunes each
// against its own live list - a group checked against a list of objects is not
// stale, it is absent. To the player it is one selection: a bare click replaces
// both, CTRL toggles within one and leaves the other. Empty on both counts
// means a terrain click orders nobody.
TACT_commandSelection      = [];  // Selected entity objects - men and vehicles
TACT_commandGroupSelection = [];  // Selected GROUPS, each drawn collapsed to one icon

// The right-click menu's whole state. The menu is real controls on the map's
// display, so the controls ARE the state: the array is what
// TACT_fnc_closeContextMenu deletes, the flag is what everything else asks.
// Nothing here records which row is which - each row carries its own option id
// on the control, so there is no second description of the menu to drift.
//
// The menu addresses the ENTITY container only; see TACT_fnc_openContextMenu.
TACT_commandMenuOpen     = false; // True while the context menu exists
TACT_commandMenuControls = [];    // The controls to delete when it closes

// Groups the player has split off with "New Group", swept by
// TACT_fnc_concludeBattle at teardown. They are created deleteWhenEmpty, so
// this is the backstop, not the mechanism. The counter never resets within a
// battle - two detachments called "Det 1" would be indistinguishable icons.
TACT_commandDetachments = [];
TACT_commandDetachCount = 0;

// Click radius around a command icon, in the same icon units the draw layer
// uses, so a unit is as easy to click zoomed out as zoomed in.
TACT_commandHitUnits  = 0.60;
TACT_commandIconUnits = 0.85;   // Command icons sit slightly under an army icon

// SEMANTIC size of a collapsed group, in icon units: 1.00 against an
// individual's 0.85. Offsets and radii are chosen against figures like this
// one, so this is NOT the knob for "group icons read too small" - that is
// STRAT_drawGroupArtScale, which grows the drawn box and leaves the geometry
// where the rest of the layer expects it. Move this only when what a group
// MEANS relative to a man has changed.
TACT_commandGroupIconUnits = 1.00;

// The group's own click radius and selection ring, chosen against its own icon
// size the way the individuals' are: a 1.00 box reaches 0.50 units to its edge
// and 0.71 to its corner, so a hit radius at the corner takes in the whole icon
// and no more.
//
// The ring is a separate constant because it is the RULER for
// STRAT_drawGroupArtScale: at art scale 1.00 the box's corners fall at 0.71 and
// sit inside it; the box reaches it at about 1.20.
TACT_commandGroupHitUnits  = 0.70;  // Click radius around a collapsed group
TACT_commandGroupRingUnits = 0.85;  // Selection ring radius for a collapsed group

// Yellow: the commander is not another unit to be ordered and should not read
// as one. The one role colour on either map (manifest section 11.1).
TACT_commandPlayerColour = [1, 0.85, 0.2, 1];

// FALLBACK only, for a body whose config carries no icon - the commander draws
// as the stock unit silhouette like his men. For a flag instead, set this to
// "b_hq" and give TACT_fnc_buildCommandList's commander block the marker
// resolver.
TACT_commandPlayerIcon = "b_inf";

// ---------------------------------------------------------------------- //
// THE CONTEXT MENU                                                        //
// ---------------------------------------------------------------------- //
// The menu is REAL CONTROLS on the map's own display, ctrlCreated from the
// classes in description.ext, not drawn into the map layer - see manifest
// section 14 for why. So this is the only geometry it has, and it is in
// FRACTIONS OF THE SAFE ZONE rather than icon units: a screen-space menu keeps
// its size on a 1080p monitor and a 4K one. Everything else about how it looks
// is config.
//
// Width is set against the longest label ("New Group") by eye - rendered text
// cannot be measured from script, so a label that outgrows the panel just looks
// too wide.
TACT_commandMenuWidthFrac = 0.085;  // Panel width, of safezoneW
TACT_commandMenuRowFrac   = 0.040;  // One row's height, of safezoneH
TACT_commandMenuEdgeFrac  = 0.004;  // Backing plate's margin, of safezoneH

// Everything else the battle map draws is coloured from STRAT_drawFactionColour
// below; there is no battle-only palette. A group with no STRAT_faction stamp -
// the half the player detaches, made by the engine - takes the stamp of the
// group it came out of, resolved in TACT_fnc_playerGroups before the draw sees
// it.

// ------------------------------------------------------------------------- //
// THE CAMPAIGN AVATAR (manifest section 8)                                   //
// ------------------------------------------------------------------------- //
// The body the player holds outside a battle. A placeholder: it never deploys,
// never joins an army and never fights. It sits on CIVILIAN in mission.sqm,
// deliberately outside the faction->side map.
//
// Claimed hidden, invulnerable and captive once, for the whole campaign. The
// two protections are what matter; the hiding may not take on a unit that is
// currently the player, which is why fn_dropIn hides it again on the way past.
// fn_dropOut restores its simulation and nothing else.
TACT_campaignAvatar = objNull;

[] spawn {
	waitUntil {!isNull player};

	TACT_campaignAvatar = player;

	TACT_campaignAvatar hideObject true;
	TACT_campaignAvatar allowDamage false;
	TACT_campaignAvatar setCaptive true;

	diag_log format [
		"STRAT Avatar: campaign avatar claimed, side %1.",
		side (group TACT_campaignAvatar)
	];
};

TACT_activeEngagements       = [];  // Engagement records currently being fought
TACT_resolvedPairsThisBlock  = [];  // Army id pairs that have already fought this block
TACT_lastBattleReport        = "";  // Shown by the block readout and the planning phase

// ------------------------------------------------------------------------- //
// CAMPAIGN DRAW LAYER (manifest section 11)                                  //
// ------------------------------------------------------------------------- //
// Armies and locations are drawn rather than marked, in full by one pass -
// see STRAT_fnc_buildDrawList.
//
// Everything the layer draws is sized and placed in ICON UNITS, resolved to
// world metres once per draw pass by STRAT_fnc_mapUnitMetres, so every element
// of every group reads one figure and they cannot drift apart at any zoom. The
// numbers below are in those units unless they say otherwise.

// One icon unit as a fraction of the screen's width: an icon holds a constant
// size on screen while the player zooms. A fraction of the SCREEN rather than a
// number of metres because an icon is a click target and a piece of symbology,
// and neither has a footprint on the ground.
STRAT_drawIconScreenSize = 0.030;

// ------------------------------------------------------------------------- //
// THE SCALING MODE (manifest section 11)                                     //
// ------------------------------------------------------------------------- //
// How icons behave as the player zooms. Read only by STRAT_fnc_mapUnitMetres,
// which is the one place that branches on it, so every element of every group
// takes its figure from that one call.
//
//   0  SCREEN-FIXED. One icon unit is STRAT_drawIconScreenSize of screen width
//      at every zoom. Fails by COLLISION when zoomed out.
//   1  WORLD-FIXED. One icon unit is STRAT_drawIconWorldMetres. Fails by
//      VANISHING when zoomed out.
//   2  CLAMPED. Mode 0 until the map shows more than
//      STRAT_drawIconClampScreenMetres across, mode 1 past it.
//
// SETTLED ON 2, by playing all three. 0 and 1 are kept because they are one
// integer away and cost nothing.
STRAT_drawIconScaleMode = 2;

// Mode 1's figure: metres per icon unit, fixed. Hand-tuned, and it has to be
// comparable to the spacing between men or icons self-overlap at EVERY zoom -
// a column sits five to ten metres apart, and 4 here is 3.4 metres at 0.85
// units. Mode 2 does not read this.
STRAT_drawIconWorldMetres = 4;

// Mode 2's crossover, and the number to tune in game. In metres across the
// SCREEN rather than as a cap on icon size, because that is the figure a player
// can read off the map; STRAT_fnc_mapUnitMetres converts it. 800 sits between
// the zoom a squad is commanded at and the 1500 m that shows a whole boundary.
STRAT_drawIconClampScreenMetres = 800;

// ------------------------------------------------------------------------- //
// DRAWICON CALIBRATION                                                       //
// ------------------------------------------------------------------------- //
// drawIcon's SIZE arguments - width, height and text size - are in SCREEN
// space, not world metres. Handing them a metres-per-screen figure compounds
// the zoom instead of cancelling it: icons grow as the map zooms out.
//
// So STRAT_fnc_drawItems turns a size in icon units into a fraction of the
// screen and these two convert that fraction into the number drawIcon wants.
// Pure engine calibration, carrying no policy - the scaling mode changes the
// fraction handed to them, never these, which is why the mode appears nowhere
// in the renderer.
//
// Two constants and not one because width/height and text size are separate
// arguments with separate base scales; one factor cannot serve both.
//
// HAND-TUNED in game. The selection ring is the ruler if they need touching up:
// drawEllipse in true world coordinates at STRAT_drawRingUnits (0.85, the same
// as TACT_commandIconUnits), so a selected unit's ring and its icon should very
// nearly coincide in every mode. Check at two zoom levels.
STRAT_drawIconArgScale = 300;

// The same, for text. Set against the icon by eye - STRAT_drawLabelUnits is
// 0.30 against the icon's 0.85, so a label should read at roughly a third of
// the icon's height.
STRAT_drawTextArgScale = 6;

// ------------------------------------------------------------------------- //
// ARTWORK FILL (manifest section 11)                                         //
// ------------------------------------------------------------------------- //
// drawIcon stretches a texture to fill the box it is given, and the two artwork
// families do not fill alike: a CfgMarkers NATO box is drawn edge to edge, a
// CfgVehicleIcons silhouette is a small glyph in a mostly transparent square.
// These compensate, ONE PER FAMILY.
//
// Applied to the drawn box of icon artwork only - never to text, the hit radius
// or the ring. Separate from STRAT_drawIconArgScale, which is shared, and never
// folded into the item's `size`, which stays semantic: STRAT_drawRingUnits and
// TACT_commandHitUnits are chosen against `size`, so inflating it would drag
// the glyph away from both.

// Unit silhouettes. 4.00 from eyeballing how much of iconMan's texture the
// glyph covers; tune against the selection ring - the silhouette should sit
// comfortably inside it. If a vehicle class turns out padded differently enough
// to matter, this becomes a table keyed the way STRAT_drawFactionIcon is, and
// the item field it feeds already supports that.
STRAT_drawUnitArtScale = 4.00;

// The collapsed groups' NATO boxes. Nominally 1 - a box needs no correction -
// so anything else this becomes is a deliberate statement about how heavy a
// body of men reads against one of its own men. Tune against
// TACT_commandGroupRingUnits: at 1.00 the box's corners fall at 0.71 and sit
// inside the ring; at about 1.20 they reach it.
//
// Ceiling: the drawn box reaches half its size below the anchor and the label
// sits at STRAT_drawLabelOffsetUnits (1.10), so past about 2.2 the box grows
// onto its own label and the offset is what moves, not this.
//
// The campaign layer's army boxes are left at 1 deliberately rather than
// coupled to this figure, which is tuned on the battle map.
STRAT_drawGroupArtScale = 1.00;

// These four are a set and are chosen against each other. A 1x1 icon reaches
// 0.5 units to its edge and 0.71 to its corner, so the hit radius sits just
// outside the edge, the ring just outside the corner, and the label far enough
// below to clear the ring's bottom rather than being struck through by it.
STRAT_drawHitUnits         = 0.70;  // Click radius around a group's anchor
STRAT_drawRingUnits        = 0.85;  // Selection ring radius
STRAT_drawLabelOffsetUnits = 1.10;  // Label drop below the icon
STRAT_drawLabelUnits       = 0.30;  // Label text size
STRAT_drawLocationUnits    = 1.10;  // Location icon, slightly over an army's
STRAT_drawArrowOriginUnits = 0.55;  // Order arrow starts just off the icon edge
STRAT_drawArrowHeadUnits   = 0.45;  // Length of each barb of the arrowhead
STRAT_drawArrowHeadDegrees = 25;    // Sweep of each barb off the shaft
STRAT_drawWaypointPipUnits = 0.18;  // Ring on each stacked waypoint but the last

// How far a mouse press may travel before its release stops being a click and
// starts being a map pan. Screen units, so it is a fraction of screen width.
STRAT_mapClickSlop = 0.01;

// White, so selection reads as a highlight rather than as another faction.
STRAT_drawSelectionColour = [1, 1, 1, 0.9];

// A label is a drawIcon call with no icon. Fully transparent rather than an
// empty string: a procedural colour is the one texture that cannot fail to
// resolve, whatever the engine does with a blank path.
STRAT_drawBlankTexture = "#(argb,8,8,3)color(0,0,0,0)";

// ONE PALETTE, BOTH LAYERS (manifest section 11.1). The campaign map and the
// battle command map read these same two tables; there is no battle-only
// palette. Hue family carries the bloc, hue within it carries the faction.
//
// Presentation only, derived from `faction` at draw time and stored nowhere.
// Colour is never read back - hostility comes from STRAT_fnc_areHostile.
//
// `civilian` is a presentation-only key. It is in neither
// STRAT_fnc_areHostile's bloc table nor STRAT_fnc_factionSide's map, so the
// three tables must not be assumed to share a key set.
STRAT_drawFactionColour = createHashMapFromArray [
    ["player",    [0.25, 0.45, 0.95, 1]],   // Blue
    ["csat",      [0.20, 0.70, 0.35, 1]],   // Green
    ["drugLords", [0.90, 0.20, 0.20, 1]],   // Red
    ["nato",      [0.95, 0.55, 0.15, 1]],   // Orange
    ["civilian",  [0.65, 0.35, 0.85, 1]]    // Purple
];

// CfgMarkers classes, used for their artwork only, so a drawn army and an
// authoring marker read as one system.
//
// Silhouette carries the BLOC, redundantly with colour's hue family - CSAT
// takes b_ despite being EAST. The rule for anything added later: a faction's
// silhouette is its bloc, its colour is itself.
STRAT_drawFactionIcon = createHashMapFromArray [
    ["player",    "b_inf"],
    ["csat",      "b_inf"],
    ["drugLords", "o_inf"],
    ["nato",      "o_inf"],
    ["civilian",  "n_inf"]
];

// One silhouette for every location type, with ownership carried by colour and
// the type spelled out in the label. Per-type artwork is presentation work for
// 3.8, when a location first has a mechanic worth distinguishing at a glance.
STRAT_drawLocationIcon = "b_installation";

// ------------------------------------------------------------------------- //
// TEST HARNESS (build plan 1.5)                                              //
// ------------------------------------------------------------------------- //
// Everything down to the scenario call is harness data, not campaign data:
// rosters, the starting states a session can boot into, and the engagements
// that drop straight into a fight without a turn. One block, one prefix and one
// function domain, so it lifts out whole.

// Which starting state this session boots into. A key of TEST_scenarios.
//
//   "sandbox"  - one player army and nothing hostile anywhere on the map.
//                Orders, routes and the block clock with the battle layer
//                taken out from under them.
//   "skirmish" - the player army and a cartel patrol, out of contact at the
//                start. A battle happens if the player marches into one.
//   "contact"  - the same two inside TACT_contactRadius, so the first
//                committed block opens a battle immediately.
TEST_scenario = "sandbox";

// Named rosters: [_menSpec, _vehicleSpec]. Each entry is "className" or
// ["className", count]. The first man listed leads.
//
// CLASS/SIDE MISMATCHES ARE DELIBERATE. The cartel rosters use O_ classes on
// WEST and the merc rosters B_T_ classes on INDEPENDENT, which createUnit gets
// wrong (manifest section 13.1). TACT_fnc_deployMen converts on every
// deployment, and these rosters are the only thing exercising that conversion
// in a real battle. Matching classes to sides is tidiness, not a requirement.
TEST_rosters = createHashMapFromArray [
    ["mercVanguard", [
        ["B_T_Soldier_SL_F", "B_T_Soldier_F", "B_T_Soldier_AR_F"],
        ["B_T_MRAP_01_gmg_F"]
    ]],
    ["cartelPatrol", [
        ["O_T_Soldier_SL_F", "O_T_Soldier_F", "O_T_Soldier_AR_F"],
        ["O_MBT_02_cannon_F"]
    ]],

    // Dismounted rosters. Build plan 2.2: an army with no transport at all is
    // the case fn_deployMen used to refuse, and it is the shape a location
    // garrison takes, so it is worth being able to put two of them in a field
    // and watch them fight.
    ["mercRifleSquad", [
        ["B_T_Soldier_SL_F", "B_T_Soldier_F", ["B_T_Soldier_AR_F", 2], ["B_T_Soldier_LAT_F", 2], ["B_T_Medic_F", 1]],
        []
    ]],
    ["cartelRifleSquad", [
        ["O_T_Soldier_SL_F", "O_T_Soldier_F", ["O_T_Soldier_AR_F", 2], ["O_T_Soldier_LAT_F", 2], ["O_T_Medic_F", 1]],
        []
    ]],

    // Partly mounted: more men than the Hunter has seats for, so the roster
    // splits at deployment into a mounted element and a foot element inside
    // one group. The interesting case for combined arms, and the one that
    // exercises seat exhaustion rather than the absence of vehicles.
    ["mercMotorised", [
        ["B_T_Soldier_SL_F", ["B_T_Soldier_F", 4], ["B_T_Soldier_AR_F", 2], ["B_T_Soldier_LAT_F", 2]],
        ["B_T_MRAP_01_gmg_F"]
    ]],

    // The interface roster, for drills. Four men is the smallest force where
    // every case the selection rule has is present at once: one to select, a
    // second to add, a third to take back out, and the commander.
    //
    // No vehicle: a mounted man resolves to his vehicle
    // (TACT_fnc_commandEntities), so a truck here would draw fewer icons than
    // there are men and make the mounting rule the first thing a selection
    // test tested.
    //
    // AAF classes, so this is the one roster that agrees with its own side -
    // the interface drill is not the place to exercise the side conversion.
    // The other rosters keep their mismatches and cover it.
    ["mercFireteam", [
        ["I_Soldier_SL_F", "I_Soldier_F", "I_Soldier_AR_F", "I_Soldier_LAT_F"],
        []
    ]],

    // One man, who is the player: the side probes' roster. No friendly AI to
    // shoot at the hostile probe before it has decided whether to shoot back.
    ["mercSolo", [
        ["B_T_Soldier_SL_F"],
        []
    ]]
];

// Placeholder siting, carried over unchanged from the armies these replace.
TEST_playerSpawn = [7774.82, 8842.66, 0];
TEST_cartelSpawn = [8464.34, 9907.8, 0];

// The close variant: same bearing off the player spawn, pulled in to 800 m -
// inside TACT_contactRadius, so the pair engages, and 400 m from the midpoint,
// inside TACT_boundaryRadius. A battle opening with either side already outside
// its boundary ends instantly.
TEST_cartelSpawnClose = TEST_playerSpawn vectorAdd
    ((TEST_playerSpawn vectorFromTo TEST_cartelSpawn) vectorMultiply 800);

// Starting states, built by TEST_fnc_setupScenario. Each is a list of army
// specs, an army spec being [name, faction, position, roster]. A scenario owns
// armies and nothing else - locations are campaign data, seeded below.
TEST_scenarios = createHashMapFromArray [
    ["sandbox", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"]
    ]],
    ["skirmish", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"],
        ["O_Cartel_Patrol",   "drugLords", TEST_cartelSpawn, "cartelPatrol"]
    ]],
    ["contact", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"],
        ["O_Cartel_Patrol",   "drugLords", TEST_cartelSpawnClose, "cartelPatrol"]
    ]]
];

// Named engagements for TEST_fnc_spawnBattle: a pair of army specs spawned
// straight into a battle, bypassing the turn entirely.
TEST_engagements = createHashMapFromArray [
    ["openField", [
        ["BLU_Merc_Vanguard", "player", TEST_playerSpawn, "mercVanguard"],
        ["O_Cartel_Patrol",   "drugLords", TEST_cartelSpawnClose, "cartelPatrol"]
    ]],

    // No transport on either side: every man is placed on foot in his
    // deployment file.
    ["infantryOnly", [
        ["BLU_Merc_Rifles",   "player", TEST_playerSpawn, "mercRifleSquad"],
        ["O_Cartel_Rifles",   "drugLords", TEST_cartelSpawnClose, "cartelRifleSquad"]
    ]],

    // Nine men and one Hunter against a fully mounted patrol: the player's side
    // arrives split into a mounted element and the men who did not fit.
    ["combinedArms", [
        ["BLU_Merc_Motorised", "player", TEST_playerSpawn, "mercMotorised"],
        ["O_Cartel_Patrol",    "drugLords", TEST_cartelSpawnClose, "cartelPatrol"]
    ]]
];

// Which engagement SHIFT+B spawns. See the key handler in block 2. Any key of
// TEST_engagements: "openField" (both sides mounted), "infantryOnly" (neither
// side has transport), "combinedArms" (one side splits into a mounted element
// and a foot element).
TEST_defaultEngagement = "openField";

// ------------------------------------------------------------------------- //
// DRILLS                                                                     //
// ------------------------------------------------------------------------- //
// One army on the ground with nobody to fight it, run by TEST_fnc_spawnDrill,
// for testing the COMMAND INTERFACE rather than the battle.
//
// A drill has no opposition and therefore no victory condition, so it never
// ends on its own: SHIFT+B ends it, SHIFT+N opens it again, and SHIFT+G splits
// a group off the player's inside it.
//
// Each entry is a single army spec, the shape TEST_scenarios uses:
// [name, faction, position, roster]. The position is a placeholder - the boot
// drill below overrides it with wherever the player is standing.
TEST_drills = createHashMapFromArray [
    ["squadFour", ["IND_Merc_Fireteam", "player", TEST_playerSpawn, "mercFireteam"]],

    // The side probes' drill: one man, so there is exactly one friendly body
    // and one friendly vehicle the hostile could be reacting to.
    ["solo", ["BLU_Merc_Solo", "player", TEST_playerSpawn, "mercSolo"]]
];

// Which drill, if any, the mission opens into. A key of TEST_drills, or "" to
// boot onto the strategic map as normal. The scenario above is still built and
// then immediately cleared.
//
// "squadFour" for interface work; "solo" is the side probes' rig and wants
// TEST_probeEnabled set with it.
TEST_bootDrill = "squadFour";

// How far a detached group walks before it stops - see TEST_fnc_splitGroup.
// 50 metres is far enough that the group icon clears his own men at the zoom a
// squad is commanded at, and close enough to hold both in view, which is the
// comparison the group icon is sized by.
TEST_splitStandoffMetres = 50;

// ------------------------------------------------------------------------- //
// THE ICON PROBE                                                             //
// ------------------------------------------------------------------------- //
// OFF. Draws plain white squares in place of the icon artwork. Kept because a
// square is a better ruler than a silhouette when the draw constants need
// touching up: hard edges, fills its box exactly, no artwork padding.
//
// To read one off: open the map on a drill, click a unit, and compare the
// square against the selection ring, which is drawn by drawEllipse in true
// world coordinates at STRAT_drawRingUnits. Spilling past it means
// STRAT_drawIconArgScale is too big, rattling inside it too small; then set
// STRAT_drawTextArgScale against the icon by eye. Check at two zoom levels.
//
// It works by priming STRAT_drawTextureCache rather than by editing the
// resolver - STRAT_fnc_mapIconTexture answers out of that cache before it reads
// config. TEST_fnc_spawnDrill seeds the CfgVehicles classes on the ground as
// well as the marker classes, so unit icons square off too; TEST_fnc_endDrill
// removes exactly the keys the drill seeded.
TEST_iconProbeEnabled = false;

// Fully opaque white, so the item's own colour comes through it and the probe
// stays a texture test rather than a colour test as well.
TEST_iconProbeTexture = "#(argb,8,8,3)color(1,1,1,1)";

// Which classes the drill seeded, written by TEST_fnc_spawnDrill and read back
// by TEST_fnc_endDrill, so the teardown removes what was actually put in.
TEST_iconProbePrimed = [];

// ------------------------------------------------------------------------- //
// THE VEHICLE PROBE                                                          //
// ------------------------------------------------------------------------- //
// OFF by default, and settled. The instruments the side investigation ran on
// (manifest section 13.1), kept because that finding regresses silently.
//
// Turned on, a drill places one empty BLUFOR-classed vehicle in front of the
// squad, reads it empty, reads it again after the settle below once somebody
// climbs in, then puts a live WEST soldier down to shoot at whoever is in it.
// That last part will kill the player, which is why it is not something to
// leave on underneath interface work. Pair it with TEST_bootDrill = "solo".
TEST_probeEnabled = false;
//
// A base-game class on purpose: only the config side is under test, so the
// probe costs no DLC to resolve.
TEST_probeVehicleClass = "B_MRAP_01_F";

// Far enough to be a separate thing on the ground, near enough that the squad
// can see it and would engage it if it read as hostile. Placed along the
// squad's own deployment bearing, which is the way the men are facing.
TEST_probeDistance = 45;

// Seconds between the first man climbing in and the crewed reading, so that
// anything resolving side asynchronously has finished before it is read.
TEST_probeSettleDelay = 5;

// THE RECIPROCAL QUESTION, and the one that decides whether a battle happens
// at all: will a WEST unit engage the player when he is sitting in a
// BLUFOR-classed vehicle? If not, nothing shoots and the battle layer quietly
// does nothing - a failure that looks like peace.
//
// TEST_fnc_hostileProbe puts one genuine WEST soldier down at the distance
// below and watches whether he fires within the window. AT launcher, because
// what he is being asked to shoot at is a vehicle.
TEST_probeHostileClass    = "B_Soldier_LAT_F";
TEST_probeHostileDistance = 100;   // Metres from the probe vehicle
TEST_probeHostileWindow   = 30;    // Seconds to wait for him to open fire

// The probe currently on the ground, and the hostile spawned to shoot at it.
// Held outside every army record on purpose, so nothing that manages a roster
// manages these.
TEST_drillProbe   = objNull;
TEST_drillHostile = objNull;

// The drill currently running, empty when none is. Declared here rather than
// left to the function that first writes it, because the key handler in block 2
// reads it and would otherwise see nil until something had run.
TEST_activeDrill = createHashMap;

// Build the starting state. Everything above is data; this is the only line
// here that does anything.
[TEST_scenario] call TEST_fnc_setupScenario;

// ------------------------------------------------------------------------- //
// STRATEGIC LOCATIONS (build plan 1.2)                                       //
// ------------------------------------------------------------------------- //
// Minimal: enough of a record for set-piece battles to be built against.
// Per-location benefits, ownership transfer and local opinion are phase 3.8.
//
// Garrisons are static rosters. They never join activeArmies and the turn model
// never sees them; only a set-piece battle reads them.
STRAT_locations = createHashMap;

// Placeholder siting, picked off the harness spawns above so the seed location
// sits on ground the test armies already traverse.
private _plantation = [
    "tanoa_plantation_north",
    "plantation",
    [8600, 9950, 0],
    "drugLords"
] call STRAT_fnc_createLocation;

// A dismounted garrison, the normal set-piece case. Nothing deploys a garrison
// yet: the record carries `men` and `vehicles` but no `faction` or `id` of its
// own - those live on the location as `owner` and `id` - so the set-piece
// deployment plan (2.3) has to supply them.
[_plantation, "O_T_Soldier_SL_F", true] call STRAT_fnc_addGarrisonMan;
[_plantation, "O_T_Soldier_F", false] call STRAT_fnc_addGarrisonMan;
[_plantation, "O_T_Soldier_AR_F", false] call STRAT_fnc_addGarrisonMan;

// Keep old tracking reference for backwards compatibility with your click hooks
STRAT_selectedArmy = nil;

// =========================================================================
// BLOCK 2: INTERFACE HOOKS & EVENT HANDLERS
// =========================================================================
// Wiring the functions to engine hooks to capture mouse input and drive the
// simulated overworld loops.

onMapSingleClick { _this call STRAT_fnc_onMapClick };

// ------------------------------------------------------------------------- //
// CAMPAIGN DRAW LAYER ATTACHMENT                                             //
// ------------------------------------------------------------------------- //
// Display 12 is destroyed when the map closes and rebuilt when it opens, so the
// Draw handler attaches on map open and never on state change: attached while
// the map is closed it lands on a null control and silently renders nothing -
// which, with armies drawn rather than marked, is an empty strategic map.
//
// One call; the function owns the lifecycle from here.
call STRAT_fnc_attachMapLayer;

// SPACE commits the block; there is no input again until resolution ends.
//
// The rest are harness keys and go when the harness does. SHIFT+B spawns
// TEST_defaultEngagement straight into a battle, or ends a running drill;
// SHIFT+N re-opens the boot drill; SHIFT+G splits a group off the player's
// inside one. All take SHIFT so a mis-press cannot put an engagement on the
// ground.
(findDisplay 46) displayAddEventHandler ["KeyDown", {
    params ["_display", "_key", "_shift"];

    // DIK 57 = Space
    if (_key == 57 && {STRAT_turnPhase == "planning"}) exitWith {
        call STRAT_fnc_commitTurn;
        true    // Consume the key so it does not also reach the player unit
    };

    // DIK 48 = B, with a drill running: end it. Checked before the spawn
    // branch and without a phase guard, because a drill holds the phase at
    // "resolving" for its whole length.
    //
    // Spawned rather than called: closing a drill runs selectPlayer, and a key
    // handler is not a scope to change the player from.
    if (_key == 48 && {_shift} && {!isNil "TEST_activeDrill"} && {count TEST_activeDrill > 0}) exitWith {
        [] spawn { call TEST_fnc_endDrill };
        true
    };

    // DIK 49 = N. Re-opens the boot drill. Its own key because SHIFT+B is
    // spoken for: once a drill ends, SHIFT+B goes back to spawning a battle.
    if (_key == 49 && {_shift} && {STRAT_turnPhase == "planning"} && {!isNil "TEST_bootDrill"} && {TEST_bootDrill != ""}) exitWith {
        [] spawn { [TEST_bootDrill, getPosATL player] call TEST_fnc_spawnDrill };
        true
    };

    // DIK 34 = G, inside a drill: split half the player's men off into a group
    // of their own, so the collapsed-group layer has something to draw.
    //
    // Guarded on a DRILL and not merely on command mode: TACT_fnc_resolveVictory
    // counts an army's survivors as `units` of the group deployment made, so a
    // split in a real battle would read as men annihilated while still
    // standing. Confined to the scenario that has no victory condition.
    //
    // Called rather than spawned: it changes groups and issues one order,
    // neither of which changes who the player is.
    if (_key == 34 && {_shift} && {!isNil "TEST_activeDrill"} && {count TEST_activeDrill > 0}) exitWith {
        [] call TEST_fnc_splitGroup;
        true
    };

    // DIK 48 = B
    if (_key == 48 && {_shift} && {STRAT_turnPhase == "planning"}) exitWith {
        // Anchored on the player so the fight opens where they are standing.
        // Pass no anchor to fight it at the engagement's own coordinates.
        [TEST_defaultEngagement, getPosATL player] call TEST_fnc_spawnBattle;
        true
    };

    false
}];

// Contact detection is not a background thread: TACT_fnc_detectContact runs as
// a step inside STRAT_fnc_resolveTurn, after movement has been applied for the
// slice.

// ------------------------------------------------------------------------- //
// OPEN THE FIRST PLANNING PHASE                                              //
// ------------------------------------------------------------------------- //
call STRAT_fnc_beginPlanning;

// ------------------------------------------------------------------------- //
// BOOT DRILL                                                                 //
// ------------------------------------------------------------------------- //
// Last line of setup, and last on purpose: a drill takes the player's body and
// turns the map into the command surface, so the draw handlers, the click
// handlers and the planning phase it hands back to must already be up.
//
// Anchored on the player rather than TEST_playerSpawn, so the fireteam deploys
// where the mission put him.
//
// Spawned rather than called: TACT_fnc_dropIn runs selectPlayer, which cannot
// be done from inside init.sqf's own scope while it is still initialising him.
if (!isNil "TEST_bootDrill" && {TEST_bootDrill != ""}) then {
    [] spawn {
        // The avatar is already up - init.sqf waited on display 46 - so this
        // yields a scheduler tick rather than waiting. That tick is the point:
        // it puts the drill after init.sqf's scope has finished, not inside it.
        waitUntil {!isNull player && {alive player}};

        [TEST_bootDrill, getPosATL player] call TEST_fnc_spawnDrill;
    };
};
