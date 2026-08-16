class_name Sim
extends RefCounted

var tick_index: int = 0
var time: float = 0.0
var outcome: int = Types.Outcome.NONE
var outcome_reason: int = Types.OutcomeReason.NONE
var world: World
var player_id: int = 0

var _queue: Array[InputCommand] = []


func setup(p_seed: int) -> void:
	world = Mapgen.generate(p_seed)
	tick_index = 0
	time = 0.0
	outcome = Types.Outcome.NONE
	outcome_reason = Types.OutcomeReason.NONE
	_queue.clear()
	player_id = 0
	for unit in world.units.values():
		if unit.kind == Types.UnitKind.PLAYER:
			player_id = unit.id
			break


func enqueue(cmd: InputCommand) -> void:
	_queue.append(cmd)


func tick() -> void:
	if outcome != Types.Outcome.NONE:
		return

	# 1. Advance clock.
	tick_index += 1
	time = float(tick_index) * Constants.SIM_DT

	# 2. Decrement cooldowns (floored at 0).
	for unit in world.units.values():
		unit.weapon_cooldown = maxf(0.0, unit.weapon_cooldown - Constants.SIM_DT)
		unit.path_recalc_in = maxf(0.0, unit.path_recalc_in - Constants.SIM_DT)
		if not unit.alive and unit.kind == Types.UnitKind.PLAYER:
			unit.respawn_timer = maxf(0.0, unit.respawn_timer - Constants.SIM_DT)

	# 3. Ice consumption — later PR.
	# 4. Apply and consume queued commands (v1: exactly one).
	var cmd: InputCommand = null
	if not _queue.is_empty():
		cmd = _queue[0]
	_queue.clear()
	_apply_player_command(cmd)

	# 5. AI director — later PR.
	# 6. AI brains — later PR.
	# 7. Turret fire — later PR.

	# 8. Integrate unit movement with collision sliding.
	for unit in world.units.values():
		if unit.alive:
			_integrate_unit(unit)

	# 9. Projectiles — later PR.
	# 10. Melee — later PR.
	# 11. Interact channels — later PR.
	# 12. Deaths / respawn — later PR.
	# 13. Evaluate win/lose — later PR.


func snapshot() -> SimSnapshot:
	var snap := SimSnapshot.new()
	snap.tick = tick_index
	snap.time = time
	snap.outcome = outcome
	snap.outcome_reason = outcome_reason
	snap.tiles = world.tiles.duplicate()
	for unit in world.units.values():
		snap.units.append({
			"id": unit.id,
			"kind": unit.kind,
			"faction": unit.faction,
			"pos": unit.pos,
			"hp": unit.hp,
			"hp_max": unit.hp_max,
			"aim": unit.aim,
			"alive": unit.alive,
			"radius": unit.radius,
		})
	return snap


func get_player() -> Unit:
	if world == null:
		return null
	return world.units.get(player_id) as Unit


func _apply_player_command(cmd: InputCommand) -> void:
	var player := get_player()
	var ignore := player == null or not player.alive or outcome != Types.Outcome.NONE
	if ignore:
		if player != null:
			player.vel = Vector2.ZERO
		return
	if cmd == null:
		player.vel = Vector2.ZERO
		return
	if cmd.aim.length_squared() > 0.0:
		player.aim = cmd.aim
	player.vel = cmd.move * Constants.PLAYER_SPEED


func _integrate_unit(unit: Unit) -> void:
	var delta := unit.vel * Constants.SIM_DT
	var pos := unit.pos
	pos.x += delta.x
	pos = _resolve_circle_tiles(pos, unit.radius)
	pos.y += delta.y
	pos = _resolve_circle_tiles(pos, unit.radius)
	var r := unit.radius
	var limit := float(Constants.MAP_W * Constants.TILE)
	pos.x = clampf(pos.x, r, limit - r)
	pos.y = clampf(pos.y, r, limit - r)
	unit.pos = pos


func _resolve_circle_tiles(pos: Vector2, radius: float) -> Vector2:
	var tile := float(Constants.TILE)
	var min_tx := int(floor((pos.x - radius) / tile))
	var max_tx := int(floor((pos.x + radius) / tile))
	var min_ty := int(floor((pos.y - radius) / tile))
	var max_ty := int(floor((pos.y + radius) / tile))
	for _pass in 2:
		for y in range(min_ty, max_ty + 1):
			for x in range(min_tx, max_tx + 1):
				if world.is_walkable(x, y):
					continue
				pos = _push_circle_out_of_aabb(pos, radius, world.tile_aabb(x, y))
	return pos


func _push_circle_out_of_aabb(center: Vector2, radius: float, aabb: Rect2) -> Vector2:
	var closest := Vector2(
		clampf(center.x, aabb.position.x, aabb.end.x),
		clampf(center.y, aabb.position.y, aabb.end.y)
	)
	var delta := center - closest
	var dist_sq := delta.length_squared()
	if dist_sq >= radius * radius:
		return center
	if dist_sq <= 0.0001:
		var left := center.x - aabb.position.x
		var right := aabb.end.x - center.x
		var top := center.y - aabb.position.y
		var bottom := aabb.end.y - center.y
		var min_pen := minf(minf(left, right), minf(top, bottom))
		if is_equal_approx(min_pen, left):
			return Vector2(aabb.position.x - radius, center.y)
		if is_equal_approx(min_pen, right):
			return Vector2(aabb.end.x + radius, center.y)
		if is_equal_approx(min_pen, top):
			return Vector2(center.x, aabb.position.y - radius)
		return Vector2(center.x, aabb.end.y + radius)
	var dist := sqrt(dist_sq)
	return closest + (delta / dist) * radius
