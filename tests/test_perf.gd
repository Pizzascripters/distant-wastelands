extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_one_completion_per_tick(fails)
	_test_pending_is_not_siege(fails)
	return fails


func _test_one_completion_per_tick(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("perf setup missing player depot")
		return
	var spawn := sim.world.tile_center(20, 20)
	for _i in Constants.WAVE_CAP:
		_inject_raider(sim, spawn)
	for _t in Constants.WAVE_CAP + 2:
		sim.tick()
		if sim.path_queue.completed_this_tick > Constants.MAX_PATHS_PER_TICK:
			fails.append(
				"tick completed %d paths, expected <= %d"
				% [sim.path_queue.completed_this_tick, Constants.MAX_PATHS_PER_TICK]
			)
			return


func _test_pending_is_not_siege(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	_box_in(sim.world, 20, 20)
	var raider := _inject_raider(sim, sim.world.tile_center(20, 20))
	AiRaider.think(raider, sim)
	if not raider.path_pending:
		fails.append("boxed-in first think should leave a pending path request")
	if raider.ai_state == Types.RaiderState.SIEGE:
		fails.append("pending path must not enter SIEGE")
	if sim.path_queue != null:
		sim.path_queue.service(sim.world)
	AiRaider.think(raider, sim)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("computed-empty path should enter SIEGE, got %d" % raider.ai_state)


func _inject_raider(sim: Sim, pos: Vector2) -> Unit:
	var raider := Unit.new()
	raider.id = sim.world.alloc_id()
	raider.kind = Types.UnitKind.RAIDER
	raider.faction = Types.Faction.ENEMY
	raider.pos = pos
	raider.hp = Constants.RAIDER_HP
	raider.hp_max = Constants.RAIDER_HP
	raider.radius = Constants.RAIDER_RADIUS
	raider.aim = Vector2(1, 0)
	raider.alive = true
	raider.ai_state = Types.RaiderState.SPAWNED
	raider.inventory = Unit.inventory_for(Types.UnitKind.RAIDER)
	raider.stuck_last_pos = pos
	sim.world.units[raider.id] = raider
	return raider


func _box_in(world: World, x: int, y: int) -> void:
	world.set_terrain(x + 1, y, Types.TileTerrain.ROCK)
	world.set_terrain(x - 1, y, Types.TileTerrain.ROCK)
	world.set_terrain(x, y + 1, Types.TileTerrain.ROCK)
	world.set_terrain(x, y - 1, Types.TileTerrain.ROCK)


func _living(world: World, faction: int, kind: int) -> Building:
	for raw in world.buildings.values():
		var building := raw as Building
		if building != null and building.faction == faction and building.kind == kind and building.hp > 0:
			return building
	return null
