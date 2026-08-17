extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_one_completion_per_tick(fails)
	_test_pending_is_not_siege(fails)
	_test_sleep_skips_path_and_move(fails)
	_test_habitat_window_keeps_unit_active(fails)
	return fails


func _test_one_completion_per_tick(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("perf setup missing player depot")
		return
	var spawn := sim.world.tile_center(20, 212)
	for _i in Constants.ENEMY_DENSITY_CAP:
		_inject_raider(sim, spawn)
	for _t in Constants.ENEMY_DENSITY_CAP + 2:
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
	_box_in(sim.world, 20, 212)
	var raider := _inject_raider(sim, sim.world.tile_center(20, 212))
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


func _test_sleep_skips_path_and_move(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	var far := Vector2i(20, 20)
	sim.world.set_terrain(far.x, far.y, Types.TileTerrain.EMPTY)
	var raider := _inject_raider(sim, sim.world.tile_center(far.x, far.y))
	var pos0 := raider.pos
	for _i in 10:
		sim.tick()
	if raider.pos != pos0:
		fails.append("raider 60+ tiles from player and Habitat should not move")
	if not raider.path_pending and raider.path_computed:
		fails.append("asleep raider should not complete a path")
	if player == null:
		fails.append("sleep wake test missing player")
		return
	player.pos = sim.world.tile_center(far.x + 40, far.y)
	sim.tick()
	var woke := raider.pos != pos0 or raider.path_pending or not raider.path.is_empty()
	if not woke:
		fails.append("raider at Chebyshev 40 of the player should think or move")


func _test_habitat_window_keeps_unit_active(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var habitat := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	var player := sim.get_player()
	if habitat == null or player == null:
		fails.append("habitat window test missing player or Habitat")
		return
	var near := habitat.origin_tile + Vector2i(40, 0)
	sim.world.set_terrain(near.x, near.y, Types.TileTerrain.EMPTY)
	var raider := _inject_raider(sim, sim.world.tile_center(near.x, near.y))
	player.pos = sim.world.tile_center(habitat.origin_tile.x - 80, habitat.origin_tile.y)
	var pos0 := raider.pos
	sim.tick()
	var active := raider.pos != pos0 or raider.path_pending or not raider.path.is_empty()
	if not active:
		fails.append("raider 40 tiles from a player Habitat should stay active")
	if sim.active_unit_count < 1:
		fails.append("active_unit_count should include the Habitat-near raider or player")


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
	if sim.world.spatial != null:
		sim.world.spatial.insert_unit(raider)
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
