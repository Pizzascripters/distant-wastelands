class_name LocalSession
extends Session

var sim: Sim
var paused: bool = false
var latest: InputCommand
var pending_build_kind: int = -1
var pending_build_tile: Vector2i = Vector2i.ZERO
var acc: float = 0.0


func start(p_seed: int) -> void:
	sim = Sim.new()
	sim.setup(p_seed)
	latest = InputCommand.new()
	latest.aim = Vector2.RIGHT
	pending_build_kind = -1
	pending_build_tile = Vector2i.ZERO
	acc = 0.0
	paused = false
	print("seed=%d" % p_seed)


func submit_command(cmd: InputCommand) -> void:
	latest.move = cmd.move
	latest.aim = cmd.aim
	latest.fire = cmd.fire
	latest.interact = cmd.interact
	if cmd.build_kind >= 0:
		pending_build_kind = cmd.build_kind
		pending_build_tile = cmd.build_tile


func set_paused(p: bool) -> void:
	paused = p


# Command / tick / pause contract:
# 1. submit_command stores held state only. It does not enqueue and does not stamp tick.
#    Overwrite latest.move/aim/fire/interact. Latch build_kind >= 0; a later
#    build_kind < 0 must not clear the latch.
# 2. tick is the only enqueuer. paused or a locked outcome returns immediately
#    (no acc, no enqueue, no Sim.tick). Otherwise acc += real_delta and, while
#    acc >= SIM_DT and catch-up < MAX_CATCHUP_TICKS: subtract SIM_DT, clone
#    latest, stamp tick = sim.tick_index + 1, copy then clear the build latch,
#    enqueue exactly one command, then Sim.tick (which consumes it).
# 3. Leftover acc is kept; leftover above MAX_CATCHUP_TICKS * SIM_DT is discarded.
# 4. fire/interact are held; build_kind is one-shot via the latch.
# 5. set_paused only flips the flag this method checks.
func tick(real_delta: float) -> void:
	if paused or sim.outcome != Types.Outcome.NONE:
		return
	acc += real_delta
	var catchup := 0
	while acc >= Constants.SIM_DT and catchup < Constants.MAX_CATCHUP_TICKS:
		acc -= Constants.SIM_DT
		var cmd := latest.clone()
		cmd.tick = sim.tick_index + 1
		cmd.build_kind = pending_build_kind
		cmd.build_tile = pending_build_tile
		pending_build_kind = -1
		sim.enqueue(cmd)
		sim.tick()
		catchup += 1
	var cap := float(Constants.MAX_CATCHUP_TICKS) * Constants.SIM_DT
	if acc > cap:
		acc = cap


func get_snapshot() -> SimSnapshot:
	return sim.snapshot()


func get_outcome() -> int:
	return sim.outcome


func get_outcome_reason() -> int:
	return sim.outcome_reason
