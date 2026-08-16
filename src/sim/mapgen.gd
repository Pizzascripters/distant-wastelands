class_name Mapgen
extends RefCounted

const _FOOTPRINT_DIRS_2X2: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)
]
const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]


static func generate(p_seed: int) -> World:
	var world := World.new()
	world.seed = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed

	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			if _in_reserved_rect(x, y):
				continue
			if rng.randi_range(0, 99) < Constants.ROCK_PERCENT:
				world.set_terrain(x, y, Types.TileTerrain.ROCK)

	_carve_corridor(world)

	var connected := validate_connectivity(world)
	if not connected:
		push_error("mapgen connectivity failed seed=%d" % p_seed)
	assert(connected, "mapgen connectivity failed seed=%d" % p_seed)

	var player := Unit.new()
	player.id = world.alloc_id()
	player.kind = Types.UnitKind.PLAYER
	player.faction = Types.Faction.PLAYER
	player.pos = world.tile_center(Constants.PLAYER_SPAWN_TILE.x, Constants.PLAYER_SPAWN_TILE.y)
	player.hp = Constants.PLAYER_HP
	player.hp_max = Constants.PLAYER_HP
	player.radius = Constants.PLAYER_RADIUS
	player.aim = Vector2.RIGHT
	player.alive = true
	world.units[player.id] = player

	print("seed=%d" % p_seed)
	return world


static func validate_connectivity(world: World) -> bool:
	var start := Constants.PLAYER_SPAWN_TILE
	if not world.is_walkable(start.x, start.y):
		return false
	var reached := _flood_fill(world, start)
	var footprint := _depot_footprint_tiles()
	var saw_adjacent := false
	for tile in footprint:
		for d in _CARDINALS:
			var n: Vector2i = tile + d
			if not world.is_walkable(n.x, n.y):
				continue
			if n in footprint:
				continue
			saw_adjacent = true
			var key := n.y * Constants.MAP_W + n.x
			if not reached.has(key):
				return false
	return saw_adjacent


static func is_building_footprint(x: int, y: int) -> bool:
	var t := Vector2i(x, y)
	if _in_2x2(t, Constants.PLAYER_HABITAT_TILE):
		return true
	if _in_2x2(t, Constants.PLAYER_DEPOT_TILE):
		return true
	if _in_2x2(t, Constants.ENEMY_HABITAT_TILE):
		return true
	if _in_2x2(t, Constants.ENEMY_DEPOT_TILE):
		return true
	return t == Constants.ENEMY_TURRET_TILE


static func _carve_corridor(world: World) -> void:
	for y in range(Constants.CORRIDOR_H_Y0, Constants.CORRIDOR_H_Y1 + 1):
		for x in range(Constants.CORRIDOR_H_X0, Constants.CORRIDOR_H_X1 + 1):
			if world.in_bounds(x, y) and not is_building_footprint(x, y):
				world.set_terrain(x, y, Types.TileTerrain.EMPTY)
	for y in range(Constants.CORRIDOR_V_Y0, Constants.CORRIDOR_V_Y1 + 1):
		for x in range(Constants.CORRIDOR_V_X0, Constants.CORRIDOR_V_X1 + 1):
			if world.in_bounds(x, y) and not is_building_footprint(x, y):
				world.set_terrain(x, y, Types.TileTerrain.EMPTY)


static func _in_reserved_rect(x: int, y: int) -> bool:
	var p := Vector2i(x, y)
	return Constants.PLAYER_CAMP_RECT.has_point(p) or Constants.ENEMY_CAMP_RECT.has_point(p)


static func _in_2x2(tile: Vector2i, origin: Vector2i) -> bool:
	for d in _FOOTPRINT_DIRS_2X2:
		if tile == origin + d:
			return true
	return false


static func _depot_footprint_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for d in _FOOTPRINT_DIRS_2X2:
		tiles.append(Constants.ENEMY_DEPOT_TILE + d)
	return tiles


static func _flood_fill(world: World, start: Vector2i) -> Dictionary:
	var seen := {}
	var q: Array[Vector2i] = [start]
	seen[start.y * Constants.MAP_W + start.x] = true
	var i := 0
	while i < q.size():
		var p: Vector2i = q[i]
		i += 1
		for d in _CARDINALS:
			var n: Vector2i = p + d
			if not world.is_walkable(n.x, n.y):
				continue
			var key := n.y * Constants.MAP_W + n.x
			if seen.has(key):
				continue
			seen[key] = true
			q.append(n)
	return seen
