extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_aligned_cell_cap(fails)
	_test_neighbor_cell_is_open(fails)
	_test_director_will_not_spawn_seventh(fails)
	_test_straddle_counts_per_cell(fails)
	return fails


func _test_aligned_cell_cap(fails: PackedStringArray) -> void:
	var world := World.new()
	for i in Constants.ENEMY_DENSITY_CAP:
		_place_enemy(world, Vector2i(i, 1))
	if Rules.can_spawn_enemy(world, Vector2i(8, 8)):
		fails.append("can_spawn_enemy should be false in a full aligned 32×32 cell")
	if Rules.enemy_density_cell(world, Vector2i(8, 8)) != Constants.ENEMY_DENSITY_CAP:
		fails.append(
			"enemy_density_cell is %d, expected %d"
			% [Rules.enemy_density_cell(world, Vector2i(8, 8)), Constants.ENEMY_DENSITY_CAP]
		)


func _test_neighbor_cell_is_open(fails: PackedStringArray) -> void:
	var world := World.new()
	for i in Constants.ENEMY_DENSITY_CAP:
		_place_enemy(world, Vector2i(i, 1))
	if not Rules.can_spawn_enemy(world, Vector2i(32, 1)):
		fails.append("can_spawn_enemy should be true in the neighboring aligned cell")
	if Rules.enemy_density_cell(world, Vector2i(32, 1)) != 0:
		fails.append(
			"neighbor cell density is %d, expected 0"
			% Rules.enemy_density_cell(world, Vector2i(32, 1))
		)


func _test_director_will_not_spawn_seventh(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var camp := _near_camp(sim.world)
	if camp == null:
		fails.append("density director test missing a near camp")
		return
	var depot := sim.world.buildings.get(camp.depot_id) as Building
	if depot == null:
		fails.append("near camp missing depot")
		return
	var spawn := _first_active_spawn(sim, depot)
	if spawn.x < 0:
		fails.append("near camp has no active walkable spawn tile")
		return
	var cell := _cell_origin(spawn)
	var have := Rules.enemy_density_cell(sim.world, spawn)
	var slot := 0
	while have < Constants.ENEMY_DENSITY_CAP and slot < Constants.ENEMY_DENSITY_N * Constants.ENEMY_DENSITY_N:
		var tile := Vector2i(cell.x + slot % Constants.ENEMY_DENSITY_N, cell.y + int(slot / Constants.ENEMY_DENSITY_N))
		slot += 1
		if tile == spawn:
			continue
		if _enemy_at(sim.world, tile) != null:
			continue
		_place_enemy(sim.world, tile)
		have += 1
	if Rules.enemy_density_cell(sim.world, spawn) != Constants.ENEMY_DENSITY_CAP:
		fails.append(
			"setup left density %d, expected %d"
			% [Rules.enemy_density_cell(sim.world, spawn), Constants.ENEMY_DENSITY_CAP]
		)
		return
	var before := _enemy_unit_count(sim.world)
	camp.next_raid_at = 0.0
	sim.director.maybe_spawn(sim)
	if _enemy_unit_count(sim.world) != before:
		fails.append("director spawned past ENEMY_DENSITY_CAP in a full aligned cell")
	if Rules.can_spawn_enemy(sim.world, spawn):
		fails.append("full cell still reports can_spawn_enemy")


func _test_straddle_counts_per_cell(fails: PackedStringArray) -> void:
	var world := World.new()
	for i in 3:
		_place_enemy(world, Vector2i(31, i))
		_place_enemy(world, Vector2i(32, i))
	if Rules.enemy_density_cell(world, Vector2i(16, 0)) != 3:
		fails.append(
			"west cell density is %d, expected 3"
			% Rules.enemy_density_cell(world, Vector2i(16, 0))
		)
	if Rules.enemy_density_cell(world, Vector2i(40, 0)) != 3:
		fails.append(
			"east cell density is %d, expected 3"
			% Rules.enemy_density_cell(world, Vector2i(40, 0))
		)
	if not Rules.can_spawn_enemy(world, Vector2i(16, 0)):
		fails.append("3+3 straddle must not block the west cell")
	if not Rules.can_spawn_enemy(world, Vector2i(40, 0)):
		fails.append("3+3 straddle must not block the east cell")


func _place_enemy(world: World, tile: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.id = world.alloc_id()
	unit.kind = Types.UnitKind.RAIDER
	unit.faction = Types.Faction.ENEMY
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.hp = Constants.RAIDER_HP
	unit.hp_max = Constants.RAIDER_HP
	unit.radius = Constants.RAIDER_RADIUS
	unit.alive = true
	world.units[unit.id] = unit
	if world.spatial != null:
		world.spatial.insert_unit(unit)
	return unit


func _enemy_at(world: World, tile: Vector2i) -> Unit:
	for raw in world.units.values():
		var unit := raw as Unit
		if unit == null or not unit.alive:
			continue
		if unit.faction != Types.Faction.ENEMY:
			continue
		if world.world_to_tile(unit.pos) == tile:
			return unit
	return null


func _enemy_unit_count(world: World) -> int:
	var n := 0
	for raw in world.units.values():
		var unit := raw as Unit
		if unit == null or not unit.alive:
			continue
		if unit.kind == Types.UnitKind.RAIDER or unit.kind == Types.UnitKind.GUARD:
			n += 1
	return n


func _cell_origin(tile: Vector2i) -> Vector2i:
	var n := Constants.ENEMY_DENSITY_N
	return Vector2i((tile.x / n) * n, (tile.y / n) * n)


func _near_camp(world: World) -> World.Camp:
	for raw in world.camps:
		var camp := raw as World.Camp
		if camp == null:
			continue
		var d := maxi(
			absi(camp.depot_tile.x - Constants.PLAYER_SPAWN_TILE.x),
			absi(camp.depot_tile.y - Constants.PLAYER_SPAWN_TILE.y)
		)
		if d >= Constants.PLAYER_SAFE_RADIUS and d <= Constants.CAMP_AGGRO_TILES:
			return camp
	return null


func _first_active_spawn(sim: Sim, depot: Building) -> Vector2i:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var best := Vector2i(-1, -1)
	var best_key := 0x7fffffff
	for dy in 2:
		for dx in 2:
			var origin := Vector2i(depot.origin_tile.x + dx, depot.origin_tile.y + dy)
			for d in dirs:
				var tile: Vector2i = origin + d
				if not sim.world.is_walkable(tile.x, tile.y):
					continue
				if not sim.world.is_tile_active(tile):
					continue
				var key := tile.y * Constants.MAP_W + tile.x
				if key < best_key:
					best = tile
					best_key = key
	return best
