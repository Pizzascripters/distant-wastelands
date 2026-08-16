class_name AiGuard
extends RefCounted

## Guard aggro and leash.


static func think(unit: Unit, sim: Sim) -> void:
	if unit == null or not unit.alive or unit.kind != Types.UnitKind.GUARD:
		return
	if sim == null or sim.world == null:
		return

	unit.siege_target_id = 0
	unit.interact_progress = 0.0

	var home := sim.world.tile_center(Constants.ENEMY_GUARD_TILE.x, Constants.ENEMY_GUARD_TILE.y)
	var player := sim.get_player()
	if _living_player_within_aggro(player, home):
		_chase(unit, player)
		return
	if unit.pos.distance_to(home) > Constants.GUARD_LEASH:
		_path_home(unit, sim.world, home)
		return
	_idle(unit)


static func _living_player_within_aggro(player: Unit, home: Vector2) -> bool:
	return player != null and player.alive and player.pos.distance_to(home) <= Constants.GUARD_AGGRO


static func _chase(unit: Unit, player: Unit) -> void:
	unit.path.clear()
	_seek(unit, player.pos)


static func _path_home(unit: Unit, world: World, home: Vector2) -> void:
	var start := world.world_to_tile(unit.pos)
	var goal := world.world_to_tile(home)
	var need_recalc := unit.path_recalc_in <= 0.0 or unit.path.is_empty()
	if not need_recalc:
		var nxt: Vector2i = unit.path[0]
		if not world.is_walkable(nxt.x, nxt.y):
			need_recalc = true
	if need_recalc:
		unit.path = Pathfind.find_path(world, start, goal)
		unit.path_recalc_in = Constants.PATH_RECALC
	while not unit.path.is_empty() and unit.path[0] == world.world_to_tile(unit.pos):
		unit.path.remove_at(0)
	if unit.path.is_empty():
		unit.vel = Vector2.ZERO
		return
	var nxt: Vector2i = unit.path[0]
	_seek(unit, world.tile_center(nxt.x, nxt.y))


static func _idle(unit: Unit) -> void:
	unit.path.clear()
	unit.vel = Vector2.ZERO


static func _seek(unit: Unit, target: Vector2) -> void:
	var delta := target - unit.pos
	if delta.length_squared() <= 0.0001:
		unit.vel = Vector2.ZERO
		return
	unit.aim = delta.normalized()
	unit.vel = unit.aim * Constants.GUARD_SPEED
