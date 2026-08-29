/*
	Function: TACT_fnc_runRoutes

	Description:
		The route executor. Arma's doMove takes one destination and does not
		queue, so a stacked route is walked here: each leg is issued, arrival
		is watched for, and the next leg goes out when the entity reaches the
		last one.

		Runs for as long as the player is commanding on the ground, and stops
		when TACT_fnc_dropOut clears the flag. Must be spawned - this sleeps.

		A leg is re-issued only when the entity is idle. That is what keeps the
		stock commanding UI usable: an order given with F1 and a click in the
		3D world is executing, so the executor leaves it alone, and the route
		resumes on the leg it was on once that order completes. The alternative
		- re-issuing every tick - would make a map route impossible to
		countermand from the keyboard, which is half of what the map mode
		exists to leave working.

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

			if (count _route > 0 && {count _order > 0} && {alive _obj}) then {

				// Vehicles are given more room than men: an MRAP told to stop
				// on a point stops near it, and a tight radius would leave it
				// nudging back and forth on the same leg forever.
				private _arrival = if (_entity get "mounted") then {
					TACT_commandArrivalVehicle
				} else {
					TACT_commandArrivalFoot
				};

				private _leg = _route select 0;

				if ((_obj distance2D _leg) <= _arrival) then {
					// Leg walked. Drop it and start the next one immediately.
					_route deleteAt 0;
					_obj setVariable ["TACT_route", _route];

					if (count _route > 0) then {
						private _next = _route select 0;
						{ _x doMove _next } forEach _order;
						_obj setVariable ["TACT_routeIssued", _next];
					} else {
						_obj setVariable ["TACT_routeIssued", nil];
					};
				} else {
					// Not there yet. Re-issue only if nothing is currently
					// being executed - the entity either never received the
					// leg, gave up on it, or has just finished an order the
					// player gave through the stock UI.
					private _idle = _order findIf { !(unitReady _x) } == -1;

					if (_idle) then {
						{ _x doMove _leg } forEach _order;
						_obj setVariable ["TACT_routeIssued", _leg];
					};
				};
			};
		} forEach (call TACT_fnc_commandEntities);

		sleep TACT_commandTickSeconds;
	};

	TACT_routesRunning = false;
	diag_log "TACT Command: route executor stopped.";
};
