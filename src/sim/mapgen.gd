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

	_pick_enemy_camps(world, rng)

	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			if _in_reserved_rect(world, x, y):
				continue
			if rng.randi_range(0, 99) < Constants.ROCK_PERCENT:
				world.set_terrain(x, y, Types.TileTerrain.ROCK)

	_stamp_cliffs(world, rng)
	_stamp_craters(world, rng)
	_place_player_camp(world)
	_place_enemy_camps(world)
	_carve_spanning_tree(world)
	_place_deposits(world, rng)

	var connected := validate_connectivity(world)
	if not connected:
		push_error("mapgen connectivity failed seed=%d" % p_seed)
	assert(connected, "mapgen connectivity failed seed=%d" % p_seed)

	print("seed=%d" % p_seed)
	world.rebuild_spatial()
	return world


static func validate_connectivity(world: World) -> bool:
	var start := Constants.PLAYER_SPAWN_TILE
	if not world.is_walkable(start.x, start.y):
		return false
	var reached := _flood_fill(world, start)
	if world.camps.is_empty():
		return false
	for raw in world.camps:
		var camp := raw as World.Camp
		if camp == null:
			return false
		var footprint := _footprint_2x2(camp.depot_tile)
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
		if not saw_adjacent:
			return false
	return true


static func stamp_cliff(world: World, start: Vector2i, direction: Vector2i, length: int) -> void:
	if world == null or direction == Vector2i.ZERO or length <= 0:
		return
	var p := start
	for _i in length:
		if world.in_bounds(p.x, p.y) and not _in_reserved_rect(world, p.x, p.y):
			world.set_terrain(p.x, p.y, Types.TileTerrain.CLIFF)
		p += direction


static func stamp_crater(world: World, center: Vector2i, radius: int) -> void:
	if world == null or radius < 0:
		return
	var r2 := radius * radius
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy > r2:
				continue
			if not world.in_bounds(x, y) or _in_reserved_rect(world, x, y):
				continue
			world.set_terrain(x, y, Types.TileTerrain.CRATER)


static func is_building_footprint(world: World, x: int, y: int) -> bool:
	var t := Vector2i(x, y)
	if _in_2x2(t, Constants.PLAYER_HABITAT_TILE):
		return true
	if _in_2x2(t, Constants.PLAYER_DEPOT_TILE):
		return true
	if world == null:
		return false
	for raw in world.camps:
		var camp := raw as World.Camp
		if camp == null:
			continue
		if _in_2x2(t, camp.habitat_tile) or _in_2x2(t, camp.depot_tile):
			return true
		if t == camp.turret_tile:
			return true
	return false


static func _pick_enemy_camps(world: World, rng: RandomNumberGenerator) -> void:
	var near := _try_pick_camp(world, rng, true)
	if near == null:
		push_error("mapgen near-camp placement failed seed=%d" % world.seed)
		assert(false, "mapgen near-camp placement failed seed=%d" % world.seed)
		return
	world.camps.append(near)
	for _i in Constants.ENEMY_CAMP_COUNT - 1:
		var camp := _try_pick_camp(world, rng, false)
		if camp == null:
			break
		world.camps.append(camp)
	if world.camps.size() >= Constants.MIN_ENEMY_CAMPS:
		return
	_clear_random_non_reserved_rocks(world, rng)
	while world.camps.size() < Constants.ENEMY_CAMP_COUNT:
		var extra := _try_pick_camp(world, rng, false)
		if extra == null:
			break
		world.camps.append(extra)
	if world.camps.size() < Constants.MIN_ENEMY_CAMPS:
		push_error(
			"mapgen enemy camp minimum failed seed=%d camps=%d"
			% [world.seed, world.camps.size()]
		)
		assert(
			false,
			"mapgen enemy camp minimum failed seed=%d camps=%d"
			% [world.seed, world.camps.size()]
		)


static func _try_pick_camp(world: World, rng: RandomNumberGenerator, near_only: bool) -> World.Camp:
	var size := Constants.ENEMY_CAMP_RECT_SIZE
	var max_origin := Vector2i(Constants.MAP_W - size, Constants.MAP_H - size)
	for _attempt in Constants.CAMP_PLACE_ATTEMPTS:
		var ox := rng.randi_range(0, max_origin.x)
		var oy := rng.randi_range(0, max_origin.y)
		var camp := _make_camp(Vector2i(ox, oy))
		if not _camp_origin_ok(world, camp, near_only):
			continue
		return camp
	return null


static func _make_camp(origin: Vector2i) -> World.Camp:
	var camp := World.Camp.new()
	camp.reserved = Rect2i(origin, Vector2i(Constants.ENEMY_CAMP_RECT_SIZE, Constants.ENEMY_CAMP_RECT_SIZE))
	camp.habitat_tile = Vector2i(origin.x + Constants.CAMP_HABITAT_OX, origin.y + Constants.CAMP_HABITAT_OY)
	camp.depot_tile = Vector2i(origin.x + Constants.CAMP_DEPOT_OX, origin.y + Constants.CAMP_DEPOT_OY)
	camp.turret_tile = Vector2i(origin.x + Constants.CAMP_TURRET_OX, origin.y + Constants.CAMP_TURRET_OY)
	camp.guard_tile = Vector2i(origin.x + Constants.CAMP_GUARD_OX, origin.y + Constants.CAMP_GUARD_OY)
	camp.next_raid_at = Constants.CAMP_RAID_FIRST
	camp.ever_aggro = false
	return camp


static func _camp_origin_ok(world: World, camp: World.Camp, near_only: bool) -> bool:
	if camp.reserved.position.x < 0 or camp.reserved.position.y < 0:
		return false
	if camp.reserved.end.x > Constants.MAP_W or camp.reserved.end.y > Constants.MAP_H:
		return false
	if camp.reserved.intersects(Constants.PLAYER_CAMP_RECT):
		return false
	var depot_cheb := _chebyshev(camp.depot_tile, Constants.PLAYER_SPAWN_TILE)
	if depot_cheb < Constants.PLAYER_SAFE_RADIUS:
		return false
	if near_only and depot_cheb > Constants.CAMP_AGGRO_TILES:
		return false
	for raw in world.camps:
		var other := raw as World.Camp
		if other == null:
			continue
		if camp.reserved.intersects(other.reserved):
			return false
		if _chebyshev(camp.reserved.position, other.reserved.position) < Constants.ENEMY_CAMP_MIN_SEP:
			return false
	return _density_allows_guard(world, camp.guard_tile)


static func _density_allows_guard(world: World, guard_tile: Vector2i) -> bool:
	var cell := _density_cell(guard_tile)
	var n := 1
	for raw in world.camps:
		var other := raw as World.Camp
		if other == null:
			continue
		if _density_cell(other.guard_tile) == cell:
			n += 1
	return n <= Constants.ENEMY_DENSITY_CAP


static func _density_cell(tile: Vector2i) -> Vector2i:
	return Vector2i(
		int(tile.x / Constants.ENEMY_DENSITY_N),
		int(tile.y / Constants.ENEMY_DENSITY_N)
	)


static func _carve_spanning_tree(world: World) -> void:
	var connected: Array[Vector2i] = [Constants.PLAYER_SPAWN_TILE]
	var unused: Array[Vector2i] = []
	for raw in world.camps:
		var camp := raw as World.Camp
		if camp != null:
			unused.append(camp.depot_tile)
	while not unused.is_empty():
		var best_i := 0
		var best_endpoint := connected[0]
		var best_cheb := _chebyshev(unused[0], connected[0])
		for i in unused.size():
			var depot: Vector2i = unused[i]
			for node in connected:
				var d := _chebyshev(depot, node)
				if d > best_cheb:
					continue
				if d < best_cheb or _vec_less(depot, unused[best_i]) or (
					depot == unused[best_i] and _vec_less(node, best_endpoint)
				):
					best_cheb = d
					best_i = i
					best_endpoint = node
		var next: Vector2i = unused[best_i]
		_carve_manhattan(world, best_endpoint, next)
		connected.append(next)
		unused.remove_at(best_i)


static func _carve_manhattan(world: World, a: Vector2i, b: Vector2i) -> void:
	var p := a
	var dir_h := Vector2i(signi(b.x - a.x), 0)
	var dir_v := Vector2i(0, signi(b.y - a.y))
	if dir_h != Vector2i.ZERO:
		_paint_corridor_step(world, p, dir_h)
		while p.x != b.x:
			p.x += dir_h.x
			_paint_corridor_step(world, p, dir_h)
	if dir_v != Vector2i.ZERO:
		if dir_h == Vector2i.ZERO:
			_paint_corridor_step(world, p, dir_v)
		while p.y != b.y:
			p.y += dir_v.y
			_paint_corridor_step(world, p, dir_v)
	if dir_h == Vector2i.ZERO and dir_v == Vector2i.ZERO:
		_paint_corridor_step(world, p, Vector2i(1, 0))


static func _paint_corridor_step(world: World, tile: Vector2i, along: Vector2i) -> void:
	var perp := Vector2i(-along.y, along.x)
	var half := int(Constants.CORRIDOR_WIDTH / 2)
	for k in range(-half, half + 1):
		var t: Vector2i = tile + perp * k
		if not world.in_bounds(t.x, t.y):
			continue
		if is_building_footprint(world, t.x, t.y):
			continue
		world.set_terrain(t.x, t.y, Types.TileTerrain.EMPTY)


static func _stamp_cliffs(world: World, rng: RandomNumberGenerator) -> void:
	for _i in Constants.CLIFF_COUNT:
		var start := _pick_unreserved_tile(world, rng)
		if start.x < 0:
			continue
		var direction: Vector2i = _CARDINALS[rng.randi_range(0, _CARDINALS.size() - 1)]
		var length := rng.randi_range(Constants.CLIFF_MIN_LEN, Constants.CLIFF_MAX_LEN)
		stamp_cliff(world, start, direction, length)


static func _stamp_craters(world: World, rng: RandomNumberGenerator) -> void:
	for _i in Constants.CRATER_COUNT:
		var center := _pick_unreserved_tile(world, rng)
		if center.x < 0:
			continue
		var radius := rng.randi_range(Constants.CRATER_MIN_R, Constants.CRATER_MAX_R)
		stamp_crater(world, center, radius)


static func _pick_unreserved_tile(world: World, rng: RandomNumberGenerator) -> Vector2i:
	for _try in 256:
		var x := rng.randi_range(0, Constants.MAP_W - 1)
		var y := rng.randi_range(0, Constants.MAP_H - 1)
		if not _in_reserved_rect(world, x, y):
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _in_reserved_rect(world: World, x: int, y: int) -> bool:
	var p := Vector2i(x, y)
	if Constants.PLAYER_CAMP_RECT.has_point(p):
		return true
	return world != null and world.in_enemy_camp_rect(p)


static func _in_2x2(tile: Vector2i, origin: Vector2i) -> bool:
	for d in _FOOTPRINT_DIRS_2X2:
		if tile == origin + d:
			return true
	return false


static func _footprint_2x2(origin: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for d in _FOOTPRINT_DIRS_2X2:
		tiles.append(origin + d)
	return tiles


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _vec_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


static func _clear_rect(world: World, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if world.in_bounds(x, y):
				world.set_terrain(x, y, Types.TileTerrain.EMPTY)


static func _place_player_camp(world: World) -> void:
	_clear_rect(world, Constants.PLAYER_CAMP_RECT)
	var habitat := _spawn_building(
		world,
		Types.BuildingKind.HABITAT,
		Types.Faction.PLAYER,
		Constants.PLAYER_HABITAT_TILE,
		Constants.HABITAT_HP
	)
	habitat.inventory.add(Types.ResourceKind.ICE, Constants.START_PLAYER_ICE)
	var depot := _spawn_building(
		world,
		Types.BuildingKind.DEPOT,
		Types.Faction.PLAYER,
		Constants.PLAYER_DEPOT_TILE,
		Constants.DEPOT_HP
	)
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.START_PLAYER_SCRAP)
	depot.inventory.add(Types.ResourceKind.ORE, Constants.START_PLAYER_ORE)
	depot.inventory.add(Types.ResourceKind.PARTS, Constants.START_PLAYER_PARTS)
	var player := _spawn_unit(
		world,
		Types.UnitKind.PLAYER,
		Types.Faction.PLAYER,
		Constants.PLAYER_SPAWN_TILE,
		Constants.PLAYER_HP,
		Constants.PLAYER_RADIUS
	)
	player.inventory.add(Types.ResourceKind.FOOD, Constants.START_PLAYER_FOOD)


static func _place_enemy_camps(world: World) -> void:
	for raw in world.camps:
		var camp := raw as World.Camp
		if camp == null:
			continue
		_place_enemy_camp(world, camp)


static func _place_enemy_camp(world: World, camp: World.Camp) -> void:
	_clear_rect(world, camp.reserved)
	var habitat := _spawn_building(
		world,
		Types.BuildingKind.HABITAT,
		Types.Faction.ENEMY,
		camp.habitat_tile,
		Constants.HABITAT_HP
	)
	habitat.inventory.add(Types.ResourceKind.ICE, Constants.START_ENEMY_ICE)
	camp.habitat_id = habitat.id
	var depot := _spawn_building(
		world,
		Types.BuildingKind.DEPOT,
		Types.Faction.ENEMY,
		camp.depot_tile,
		Constants.DEPOT_HP
	)
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.START_ENEMY_SCRAP)
	depot.inventory.add(Types.ResourceKind.ORE, Constants.START_ENEMY_ORE)
	depot.inventory.add(Types.ResourceKind.PARTS, Constants.START_ENEMY_PARTS)
	camp.depot_id = depot.id
	_spawn_building(
		world,
		Types.BuildingKind.TURRET,
		Types.Faction.ENEMY,
		camp.turret_tile,
		Constants.TURRET_HP
	)
	_spawn_unit(
		world,
		Types.UnitKind.GUARD,
		Types.Faction.ENEMY,
		camp.guard_tile,
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
	building.inventory = Building.inventory_for(kind)
	building.ice_debt_timer = 0.0
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
	unit.home_pos = unit.pos
	world.units[unit.id] = unit
	return unit


static func _place_deposits(world: World, rng: RandomNumberGenerator) -> void:
	var scrap_n := _place_deposits_of_kind(
		world, rng, Types.ResourceKind.SCRAP, Constants.SCRAP_DEPOSIT_COUNT, Constants.SCRAP_DEPOSIT_AMOUNT
	)
	var ice_n := _place_deposits_of_kind(
		world, rng, Types.ResourceKind.ICE, Constants.ICE_DEPOSIT_COUNT, Constants.ICE_DEPOSIT_AMOUNT
	)
	var ore_n := _place_deposits_of_kind(
		world, rng, Types.ResourceKind.ORE, Constants.ORE_DEPOSIT_COUNT, Constants.ORE_DEPOSIT_AMOUNT
	)
	if (
		scrap_n >= Constants.MIN_SCRAP_DEPOSITS
		and ice_n >= Constants.MIN_ICE_DEPOSITS
		and ore_n >= Constants.MIN_ORE_DEPOSITS
	):
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
	if ore_n < Constants.MIN_ORE_DEPOSITS:
		ore_n += _place_deposits_of_kind(
			world,
			rng,
			Types.ResourceKind.ORE,
			Constants.ORE_DEPOSIT_COUNT - ore_n,
			Constants.ORE_DEPOSIT_AMOUNT
		)
	var ok := (
		scrap_n >= Constants.MIN_SCRAP_DEPOSITS
		and ice_n >= Constants.MIN_ICE_DEPOSITS
		and ore_n >= Constants.MIN_ORE_DEPOSITS
	)
	if not ok:
		push_error(
			"mapgen deposit minima failed seed=%d scrap=%d ice=%d ore=%d"
			% [world.seed, scrap_n, ice_n, ore_n]
		)
	assert(
		ok,
		"mapgen deposit minima failed seed=%d scrap=%d ice=%d ore=%d"
		% [world.seed, scrap_n, ice_n, ore_n]
	)


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
	if _in_reserved_rect(world, x, y):
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
			if _in_reserved_rect(world, x, y):
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
