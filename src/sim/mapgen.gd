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

	_place_player_camp(world)
	_place_enemy_camp(world)
	_carve_corridor(world)
	_place_deposits(world, rng)

	var connected := validate_connectivity(world)
	if not connected:
		push_error("mapgen connectivity failed seed=%d" % p_seed)
	assert(connected, "mapgen connectivity failed seed=%d" % p_seed)

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


static func _place_player_camp(world: World) -> void:
	_spawn_building(
		world,
		Types.BuildingKind.HABITAT,
		Types.Faction.PLAYER,
		Constants.PLAYER_HABITAT_TILE,
		Constants.HABITAT_HP
	)
	var depot := _spawn_building(
		world,
		Types.BuildingKind.DEPOT,
		Types.Faction.PLAYER,
		Constants.PLAYER_DEPOT_TILE,
		Constants.DEPOT_HP
	)
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.START_PLAYER_SCRAP)
	depot.inventory.add(Types.ResourceKind.ICE, Constants.START_PLAYER_ICE)
	_spawn_unit(
		world,
		Types.UnitKind.PLAYER,
		Types.Faction.PLAYER,
		Constants.PLAYER_SPAWN_TILE,
		Constants.PLAYER_HP,
		Constants.PLAYER_RADIUS
	)


static func _place_enemy_camp(world: World) -> void:
	_spawn_building(
		world,
		Types.BuildingKind.HABITAT,
		Types.Faction.ENEMY,
		Constants.ENEMY_HABITAT_TILE,
		Constants.HABITAT_HP
	)
	var depot := _spawn_building(
		world,
		Types.BuildingKind.DEPOT,
		Types.Faction.ENEMY,
		Constants.ENEMY_DEPOT_TILE,
		Constants.DEPOT_HP
	)
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.START_ENEMY_SCRAP)
	depot.inventory.add(Types.ResourceKind.ICE, Constants.START_ENEMY_ICE)
	_spawn_building(
		world,
		Types.BuildingKind.TURRET,
		Types.Faction.ENEMY,
		Constants.ENEMY_TURRET_TILE,
		Constants.TURRET_HP
	)
	_spawn_unit(
		world,
		Types.UnitKind.GUARD,
		Types.Faction.ENEMY,
		Constants.ENEMY_GUARD_TILE,
		Constants.GUARD_HP,
		Constants.GUARD_RADIUS
	)


static func _spawn_building(
	world: World, kind: int, faction: int, origin: Vector2i, hp: int
) -> Building:
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = kind
	building.faction = faction
	building.origin_tile = origin
	building.hp = hp
	building.hp_max = hp
	building.aim = Vector2(1, 0)
	if kind == Types.BuildingKind.DEPOT:
		building.inventory = Inventory.new(Constants.DEPOT_CAP_SCRAP, Constants.DEPOT_CAP_ICE)
	world.buildings[building.id] = building
	world.occupy(building)
	return building


static func _spawn_unit(
	world: World, kind: int, faction: int, tile: Vector2i, hp: int, radius: float
) -> Unit:
	var unit := Unit.new()
	unit.id = world.alloc_id()
	unit.kind = kind
	unit.faction = faction
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.hp = hp
	unit.hp_max = hp
	unit.radius = radius
	unit.aim = Vector2.RIGHT
	unit.alive = true
	unit.inventory = Unit.inventory_for(kind)
	world.units[unit.id] = unit
	return unit


static func _place_deposits(world: World, rng: RandomNumberGenerator) -> void:
	var scrap_n := _place_deposits_of_kind(
		world, rng, Types.ResourceKind.SCRAP, Constants.SCRAP_DEPOSIT_COUNT, Constants.SCRAP_DEPOSIT_AMOUNT
	)
	var ice_n := _place_deposits_of_kind(
		world, rng, Types.ResourceKind.ICE, Constants.ICE_DEPOSIT_COUNT, Constants.ICE_DEPOSIT_AMOUNT
	)
	if scrap_n >= Constants.MIN_SCRAP_DEPOSITS and ice_n >= Constants.MIN_ICE_DEPOSITS:
		return
	_clear_random_non_reserved_rocks(world, rng)
	if scrap_n < Constants.MIN_SCRAP_DEPOSITS:
		scrap_n += _place_deposits_of_kind(
			world,
			rng,
			Types.ResourceKind.SCRAP,
			Constants.SCRAP_DEPOSIT_COUNT - scrap_n,
			Constants.SCRAP_DEPOSIT_AMOUNT
		)
	if ice_n < Constants.MIN_ICE_DEPOSITS:
		ice_n += _place_deposits_of_kind(
			world,
			rng,
			Types.ResourceKind.ICE,
			Constants.ICE_DEPOSIT_COUNT - ice_n,
			Constants.ICE_DEPOSIT_AMOUNT
		)
	var ok := scrap_n >= Constants.MIN_SCRAP_DEPOSITS and ice_n >= Constants.MIN_ICE_DEPOSITS
	if not ok:
		push_error("mapgen deposit minima failed seed=%d scrap=%d ice=%d" % [world.seed, scrap_n, ice_n])
	assert(ok, "mapgen deposit minima failed seed=%d scrap=%d ice=%d" % [world.seed, scrap_n, ice_n])


static func _place_deposits_of_kind(
	world: World, rng: RandomNumberGenerator, kind: int, count: int, amount: int
) -> int:
	var placed := 0
	for _i in count:
		if not _try_place_deposit(world, rng, kind, amount):
			break
		placed += 1
	return placed


static func _try_place_deposit(
	world: World, rng: RandomNumberGenerator, kind: int, amount: int
) -> bool:
	for _attempt in Constants.DEPOSIT_PLACE_ATTEMPTS:
		var x := rng.randi_range(0, Constants.MAP_W - 1)
		var y := rng.randi_range(0, Constants.MAP_H - 1)
		if not _can_place_deposit(world, x, y):
			continue
		var deposit := Deposit.new()
		deposit.id = world.alloc_id()
		deposit.kind = kind
		deposit.tile = Vector2i(x, y)
		deposit.remaining = amount
		world.deposits[deposit.id] = deposit
		return true
	return false


static func _can_place_deposit(world: World, x: int, y: int) -> bool:
	if not world.is_walkable(x, y):
		return false
	if _in_reserved_rect(x, y):
		return false
	if x == Constants.CORRIDOR_CENTER_X or y == Constants.CORRIDOR_CENTER_Y:
		return false
	var tile := Vector2i(x, y)
	for other in world.deposits.values():
		var d: Vector2i = other.tile
		if maxi(absi(d.x - tile.x), absi(d.y - tile.y)) < Constants.DEPOSIT_MIN_SEP:
			return false
	return true


static func _clear_random_non_reserved_rocks(world: World, rng: RandomNumberGenerator) -> void:
	var rocks: Array[Vector2i] = []
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			if _in_reserved_rect(x, y):
				continue
			if world.get_terrain(x, y) == Types.TileTerrain.ROCK:
				rocks.append(Vector2i(x, y))
	for i in range(rocks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = rocks[i]
		rocks[i] = rocks[j]
		rocks[j] = tmp
	for tile in rocks:
		world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)


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
