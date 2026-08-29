/*
	Function: TACT_fnc_runRoutes

	Description:
		Walks the routes that are meant to be walked. doMove takes one
		destination and does not queue, so a stacked route is stepped through
		here: arrival at a leg is watched for and the next one goes out when the
		entity reaches it.

		Every route is walked, whether it was given to a selection or to the
		whole group. A chained route is the same instruction in both cases -
		go here, then here - and it would be a strange interface where the
		waypoints a player stacks for one man are carried out and the ones he
		stacks for everybody are decoration.

		A leg is re-issued only when the entity is idle. That is what keeps the
		stock commanding UI usable: an order given with F1 and a click in the
		3D world is executing, so the executor leaves it alone, and the route
		resumes on the leg it was on once that order completes. Re-issuing
		every tick would make a map route impossible to countermand from the
		keyboard, which is half of what the map mode exists to leave working.

		THE POST. The last waypoint of a route is not the end of the order, it
		is the post the entity now holds. Walking a route out leaves the entity
		posted there, and the executor keeps it there by re-issuing the move
		whenever it has drifted off and has nothing better to do.

		That is a held position expressed as an order rather than as a
		restriction. Nothing is disabled and nothing is frozen: a posted unit
		takes cover, manoeuvres, and fights exactly as it otherwise would. It
		simply walks back to its post once the shooting stops, instead of
		drifting back into formation on the player.

		Two guards keep the post from becoming the freeze it is meant not to
		be. It is never re-issued while a unit is in COMBAT behaviour, because
		dragging a man out of the cover he has just taken and back onto an open
		hilltop is precisely the failure that makes scripted hold orders
		unusable. And it is never re-issued while a unit is busy, so an order
		given through the stock squad bar runs to completion first.

		Runs for as long as the player holds a body on the field, and stops
		when TACT_fnc_dropOut clears the flag. Must be spawned - this sleeps.

	Parameters:
		none

	Returns:
		nothing
*/

if (!isNil "TACT_routesRunning" && {TACT_routesRunning}) exitWith {
	diag_log "TACT Command: route executor is already running.";
};

TACT_routesRunning = true;

[] spawn {
	while {!isNil "TACT_commandActive" && {TACT_commandActive}} do {

		{
			private _entity = _x;
			private _obj    = _entity get "obj";
			private _order  = _entity get "order";
			private _route  = _obj getVariable ["TACT_route", []];
			private _post   = _obj getVariable ["TACT_post", []];

			if (count _order > 0 && {alive _obj}) then {

				// Vehicles are given more room than men: an MRAP told to stop
				// on a point stops near it, and a radius as tight as a man's
				// would leave it nudging back and forth on the same leg.
				private _arrival = if (_entity get "mounted") then {
					TACT_commandArrivalVehicle
				} else {
					TACT_commandArrivalFoot
				};

				// Nothing is currently being executed. Both branches below
				// wait on this: an order the player gave through the stock
				// squad bar runs to completion before the map's orders resume.
				private _idle = _order findIf { !(unitReady _x) } == -1;

				if (count _route > 0) then {

					// ------------------------------------------------ //
					// WALKING THE ROUTE                                 //
					// ------------------------------------------------ //
					private _leg = _route select 0;

					if ((_obj distance2D _leg) <= _arrival) then {
						// Leg walked. Drop it and start the next one.
						_route deleteAt 0;
						_obj setVariable ["TACT_route", _route];

						if (count _route > 0) then {
							{ _x doMove (_route select 0) } forEach _order;
						} else {
							// Route walked out. Where it ended is the post.
							_obj setVariable ["TACT_post", _leg];
						};
					} else {
						// Not there yet. The entity either never received the
						// leg, gave up on it, or has just finished something
						// the player ordered through the stock UI.
						if (_idle) then {
							{ _x doMove _leg } forEach _order;
						};
					};

				} else {

					// ------------------------------------------------ //
					// HOLDING THE POST                                  //
					// ------------------------------------------------ //
					if (count _post >= 2 && {(_obj distance2D _post) > _arrival}) then {

						// Never while fighting. A unit in COMBAT behaviour has
						// taken cover or is manoeuvring on something, and
						// walking it back to a post mid-contact is how a hold
						// order gets a squad killed.
						private _fighting = _order findIf { behaviour _x == "COMBAT" } > -1;

						if (_idle && {!_fighting}) then {
							{ _x doMove _post } forEach _order;
						};
					};
				};
			};
		} forEach (call TACT_fnc_commandEntities);

		sleep TACT_commandTickSeconds;
	};

	TACT_routesRunning = false;
	diag_log "TACT Command: route executor stopped.";
};
