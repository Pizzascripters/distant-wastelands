extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_seed1_deterministic(fails)
	_test_connectivity_seeds(fails)
	_test_corridor_empty(fails)
	_test_camps_reserved(fails)
	_test_player_carry_caps(fails)
	_test_camp_buildings(fails)
	_test_starting_stocks(fails)
	_test_deposit_minima(fails)
	_test_cliffs_and_craters(fails)
	return fails


func _test_seed1_deterministic(fails: PackedStringArray) -> void:
	var a := Mapgen.generate(1)
	var b := Mapgen.generate(1)
	if a.tiles != b.tiles:
		fails.append("seed 1 tile hash differs across two runs (%d vs %d)" % [_tile_hash(a.tiles), _tile_hash(b.tiles)])
	if a.tiles.size() != Constants.MAP_W * Constants.MAP_H:
		fails.append("world tile count is %d, expected %d" % [a.tiles.size(), Constants.MAP_W * Constants.MAP_H])
	if _deposit_tiles(a) != _deposit_tiles(b):
		fails.append("seed 1 deposit tiles differ across two runs")


func _test_connectivity_seeds(fails: PackedStringArray) -> void:
	for s in [1, 2, 3, 4, 5]:
		var world := Mapgen.generate(s)
		if not Mapgen.validate_connectivity(world):
			fails.append("seed %d failed connectivity assert without extra carving" % s)


func _test_corridor_empty(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	if world.tiles.size() != Constants.MAP_W * Constants.MAP_H:
		fails.append("world is %d tiles, expected %d" % [world.tiles.size(), Constants.MAP_W * Constants.MAP_H])
	if not (world.occupancy is PackedInt32Array):
		fails.append("occupancy should be PackedInt32Array")
	elif world.occupancy.size() != Constants.MAP_W * Constants.MAP_H:
		fails.append("occupancy size is %d, expected %d" % [world.occupancy.size(), Constants.MAP_W * Constants.MAP_H])
	if world.chunk_generation.size() != 64:
		fails.append("chunk_generation size is %d, expected 64" % world.chunk_generation.size())
	for edge in _spanning_tree_edges(world):
		for tile in _manhattan_corridor_tiles(edge[0], edge[1]):
			if Mapgen.is_building_footprint(world, tile.x, tile.y):
				continue
			if world.get_terrain(tile.x, tile.y) != Types.TileTerrain.EMPTY:
				fails.append("Manhattan corridor tile (%d,%d) is not EMPTY" % [tile.x, tile.y])
				return


func _test_camps_reserved(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	_assert_rect_empty_of_rocks(fails, world, Constants.PLAYER_CAMP_RECT, "player camp")
	if Constants.PLAYER_SPAWN_TILE != Vector2i(23, 218):
		fails.append("PLAYER_SPAWN_TILE is %s, expected (23, 218)" % Constants.PLAYER_SPAWN_TILE)
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_SPAWN_TILE):
		fails.append("player spawn is outside PLAYER_CAMP_RECT")
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_HABITAT_TILE):
		fails.append("player habitat is outside PLAYER_CAMP_RECT")
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_DEPOT_TILE):
		fails.append("player depot is outside PLAYER_CAMP_RECT")
	if world.camps.size() < Constants.MIN_ENEMY_CAMPS or world.camps.size() > Constants.ENEMY_CAMP_COUNT:
		fails.append(
			"camps.size() is %d, expected [%d, %d]"
			% [world.camps.size(), Constants.MIN_ENEMY_CAMPS, Constants.ENEMY_CAMP_COUNT]
		)
	var near_n := 0
	var spawn := Constants.PLAYER_SPAWN_TILE
	for i in world.camps.size():
		var camp: World.Camp = world.camps[i]
		_assert_rect_empty_of_rocks(fails, world, camp.reserved, "enemy camp %d" % i)
		if not camp.reserved.has_point(camp.depot_tile):
			fails.append("camp %d depot is outside reserved" % i)
		if not camp.reserved.has_point(camp.habitat_tile):
			fails.append("camp %d habitat is outside reserved" % i)
		var cheb := maxi(absi(camp.depot_tile.x - spawn.x), absi(camp.depot_tile.y - spawn.y))
		if cheb < Constants.PLAYER_SAFE_RADIUS:
			fails.append("camp %d depot Chebyshev is %d, inside PLAYER_SAFE_RADIUS" % [i, cheb])
		if cheb >= Constants.PLAYER_SAFE_RADIUS and cheb <= Constants.CAMP_AGGRO_TILES:
			near_n += 1
	if near_n < 1:
		fails.append("expected at least one near camp in [%d, %d]" % [
			Constants.PLAYER_SAFE_RADIUS, Constants.CAMP_AGGRO_TILES
		])


func _test_player_carry_caps(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	var player: Unit = null
	for id in world.units:
		var unit: Unit = world.units[id]
		if unit.kind == Types.UnitKind.PLAYER:
			player = unit
			break
	if player == null:
		fails.append("mapgen did not spawn a player unit")
		return
	if player.inventory == null:
		fails.append("player unit has no inventory")
		return
	if player.inventory.cap_scrap != Constants.PLAYER_CARRY_SCRAP:
		fails.append(
			"player cap_scrap is %d, expected %d"
			% [player.inventory.cap_scrap, Constants.PLAYER_CARRY_SCRAP]
		)
	if player.inventory.cap_ice != Constants.PLAYER_CARRY_ICE:
		fails.append(
			"player cap_ice is %d, expected %d"
			% [player.inventory.cap_ice, Constants.PLAYER_CARRY_ICE]
		)
	if player.inventory.scrap != 0 or player.inventory.ice != 0:
		fails.append(
			"player carry started at %d/%d, expected 0/0"
			% [player.inventory.scrap, player.inventory.ice]
		)


func _test_camp_buildings(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	_expect_building(
		fails, world, Constants.PLAYER_HABITAT_TILE, Types.BuildingKind.HABITAT,
		Types.Faction.PLAYER, Constants.HABITAT_HP
	)
	_expect_building(
		fails, world, Constants.PLAYER_DEPOT_TILE, Types.BuildingKind.DEPOT,
		Types.Faction.PLAYER, Constants.DEPOT_HP
	)
	if world.camps.is_empty():
		fails.append("mapgen did not place any enemy camps")
		return
	for i in world.camps.size():
		var camp: World.Camp = world.camps[i]
		var origin: Vector2i = camp.reserved.position
		if camp.habitat_tile != Vector2i(origin.x + Constants.CAMP_HABITAT_OX, origin.y + Constants.CAMP_HABITAT_OY):
			fails.append("camp %d habitat offset is %s" % [i, camp.habitat_tile - origin])
		if camp.depot_tile != Vector2i(origin.x + Constants.CAMP_DEPOT_OX, origin.y + Constants.CAMP_DEPOT_OY):
			fails.append("camp %d depot offset is %s" % [i, camp.depot_tile - origin])
		if camp.turret_tile != Vector2i(origin.x + Constants.CAMP_TURRET_OX, origin.y + Constants.CAMP_TURRET_OY):
			fails.append("camp %d turret offset is %s" % [i, camp.turret_tile - origin])
		if camp.guard_tile != Vector2i(origin.x + Constants.CAMP_GUARD_OX, origin.y + Constants.CAMP_GUARD_OY):
			fails.append("camp %d guard offset is %s" % [i, camp.guard_tile - origin])
		_expect_building(
			fails, world, camp.habitat_tile, Types.BuildingKind.HABITAT,
			Types.Faction.ENEMY, Constants.HABITAT_HP
		)
		_expect_building(
			fails, world, camp.depot_tile, Types.BuildingKind.DEPOT,
			Types.Faction.ENEMY, Constants.DEPOT_HP
		)
		_expect_building(
			fails, world, camp.turret_tile, Types.BuildingKind.TURRET,
			Types.Faction.ENEMY, Constants.TURRET_HP
		)
		var expected := world.tile_center(camp.guard_tile.x, camp.guard_tile.y)
		var guard := _guard_at(world, expected)
		if guard == null:
			fails.append("camp %d missing guard at %s" % [i, camp.guard_tile])
			continue
		if guard.faction != Types.Faction.ENEMY:
			fails.append("camp %d guard faction is %d, expected ENEMY" % [i, guard.faction])
		if guard.hp != Constants.GUARD_HP or guard.hp_max != Constants.GUARD_HP:
			fails.append("camp %d guard hp is %d/%d, expected %d" % [i, guard.hp, guard.hp_max, Constants.GUARD_HP])


func _test_starting_stocks(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	var player_depot := world.building_at(Constants.PLAYER_DEPOT_TILE.x, Constants.PLAYER_DEPOT_TILE.y)
	if player_depot == null or player_depot.kind != Types.BuildingKind.DEPOT:
		fails.append("player depot missing at PLAYER_DEPOT_TILE")
		return
	_expect_stock(fails, player_depot, "player depot", Constants.START_PLAYER_SCRAP, 0)
	var player_habitat := world.building_at(Constants.PLAYER_HABITAT_TILE.x, Constants.PLAYER_HABITAT_TILE.y)
	if player_habitat == null or player_habitat.kind != Types.BuildingKind.HABITAT:
		fails.append("player habitat missing at PLAYER_HABITAT_TILE")
		return
	_expect_habitat_ice(fails, player_habitat, "player habitat", Constants.START_PLAYER_ICE)
	if world.camps.is_empty():
		fails.append("starting stocks missing enemy camps")
		return
	for i in world.camps.size():
		var camp: World.Camp = world.camps[i]
		var enemy_depot := world.building_at(camp.depot_tile.x, camp.depot_tile.y)
		if enemy_depot == null or enemy_depot.kind != Types.BuildingKind.DEPOT:
			fails.append("enemy depot missing at camp %d" % i)
			return
		_expect_stock(fails, enemy_depot, "enemy depot %d" % i, Constants.START_ENEMY_SCRAP, 0)
		var enemy_habitat := world.building_at(camp.habitat_tile.x, camp.habitat_tile.y)
		if enemy_habitat == null or enemy_habitat.kind != Types.BuildingKind.HABITAT:
			fails.append("enemy habitat missing at camp %d" % i)
			return
		_expect_habitat_ice(fails, enemy_habitat, "enemy habitat %d" % i, Constants.START_ENEMY_ICE)


func _test_deposit_minima(fails: PackedStringArray) -> void:
	for s in [1, 2, 3, 4, 5]:
		var world := Mapgen.generate(s)
		var scrap_n := 0
		var ice_n := 0
		var ore_n := 0
		for id in world.deposits:
			var deposit: Deposit = world.deposits[id]
			if not _deposit_placement_ok(fails, world, deposit, s):
				return
			if deposit.kind == Types.ResourceKind.SCRAP:
				scrap_n += 1
				if deposit.remaining != Constants.SCRAP_DEPOSIT_AMOUNT:
					fails.append("seed %d scrap deposit remaining is %d" % [s, deposit.remaining])
					return
			elif deposit.kind == Types.ResourceKind.ICE:
				ice_n += 1
				if deposit.remaining != Constants.ICE_DEPOSIT_AMOUNT:
					fails.append("seed %d ice deposit remaining is %d" % [s, deposit.remaining])
					return
			elif deposit.kind == Types.ResourceKind.ORE:
				ore_n += 1
				if deposit.remaining != Constants.ORE_DEPOSIT_AMOUNT:
					fails.append("seed %d ore deposit remaining is %d" % [s, deposit.remaining])
					return
			else:
				fails.append("seed %d deposit has unknown kind %d" % [s, deposit.kind])
				return
		if scrap_n < Constants.MIN_SCRAP_DEPOSITS:
			fails.append("seed %d scrap deposits %d < MIN_SCRAP_DEPOSITS" % [s, scrap_n])
		if ice_n < Constants.MIN_ICE_DEPOSITS:
			fails.append("seed %d ice deposits %d < MIN_ICE_DEPOSITS" % [s, ice_n])
		if ore_n < Constants.MIN_ORE_DEPOSITS:
			fails.append("seed %d ore deposits %d < MIN_ORE_DEPOSITS" % [s, ore_n])
		if ore_n > Constants.ORE_DEPOSIT_COUNT:
			fails.append("seed %d ore deposits %d > ORE_DEPOSIT_COUNT" % [s, ore_n])


func _test_cliffs_and_craters(fails: PackedStringArray) -> void:
	for s in [1, 2, 3, 4, 5]:
		var world := Mapgen.generate(s)
		var cliffs := 0
		var craters := 0
		for y in Constants.MAP_H:
			for x in Constants.MAP_W:
				var kind := world.get_terrain(x, y)
				if kind != Types.TileTerrain.CLIFF and kind != Types.TileTerrain.CRATER:
					continue
				if not World.is_solid_terrain(kind):
					fails.append("seed %d feature at (%d,%d) is not solid" % [s, x, y])
					return
				if world.is_walkable(x, y):
					fails.append("seed %d feature at (%d,%d) is walkable" % [s, x, y])
					return
				if Constants.PLAYER_CAMP_RECT.has_point(Vector2i(x, y)) or world.in_enemy_camp_rect(Vector2i(x, y)):
					fails.append("seed %d feature overlaps reserved rect at (%d,%d)" % [s, x, y])
					return
				if kind == Types.TileTerrain.CLIFF:
					cliffs += 1
				else:
					craters += 1
		if cliffs <= 0:
			fails.append("seed %d has no CLIFF tiles" % s)
		if craters <= 0:
			fails.append("seed %d has no CRATER tiles" % s)


func _deposit_placement_ok(fails: PackedStringArray, world: World, deposit: Deposit, seed: int) -> bool:
	var tile: Vector2i = deposit.tile
	if not world.is_walkable(tile.x, tile.y):
		fails.append("seed %d deposit %d on non-walkable tile %s" % [seed, deposit.id, tile])
		return false
	if Constants.PLAYER_CAMP_RECT.has_point(tile) or world.in_enemy_camp_rect(tile):
		fails.append("seed %d deposit %d in reserved rect at %s" % [seed, deposit.id, tile])
		return false
	for other_id in world.deposits:
		if other_id == deposit.id:
			continue
		var other: Deposit = world.deposits[other_id]
		var dist := maxi(absi(other.tile.x - tile.x), absi(other.tile.y - tile.y))
		if dist < Constants.DEPOSIT_MIN_SEP:
			fails.append("seed %d deposits %d and %d closer than DEPOSIT_MIN_SEP" % [seed, deposit.id, other.id])
			return false
	return true


func _expect_building(
	fails: PackedStringArray,
	world: World,
	origin: Vector2i,
	kind: int,
	faction: int,
	hp: int
) -> void:
	var building := world.building_at(origin.x, origin.y)
	if building == null:
		fails.append("missing building at %s" % origin)
		return
	if building.origin_tile != origin:
		fails.append("building at %s has origin %s" % [origin, building.origin_tile])
	if building.kind != kind:
		fails.append("building at %s kind is %d, expected %d" % [origin, building.kind, kind])
	if building.faction != faction:
		fails.append("building at %s faction is %d, expected %d" % [origin, building.faction, faction])
	if building.hp != hp or building.hp_max != hp:
		fails.append("building at %s hp is %d/%d, expected %d" % [origin, building.hp, building.hp_max, hp])
	var span := world.footprint_span(kind)
	for dy in span:
		for dx in span:
			var x: int = origin.x + dx
			var y: int = origin.y + dy
			if world.building_at(x, y) != building:
				fails.append("occupancy at (%d,%d) is not building %d" % [x, y, building.id])
				return
			if not world.is_solid(x, y):
				fails.append("footprint tile (%d,%d) is walkable" % [x, y])
				return


func _expect_stock(fails: PackedStringArray, depot: Building, label: String, scrap: int, ice: int) -> void:
	if depot.inventory == null:
		fails.append("%s has no inventory" % label)
		return
	if depot.inventory.cap_scrap != Constants.DEPOT_CAP_SCRAP or depot.inventory.cap_ice != Constants.DEPOT_CAP_ICE:
		fails.append(
			"%s caps are %d/%d, expected %d/%d"
			% [
				label,
				depot.inventory.cap_scrap,
				depot.inventory.cap_ice,
				Constants.DEPOT_CAP_SCRAP,
				Constants.DEPOT_CAP_ICE,
			]
		)
	if depot.inventory.scrap != scrap or depot.inventory.ice != ice:
		fails.append(
			"%s stock is %d/%d, expected %d/%d"
			% [label, depot.inventory.scrap, depot.inventory.ice, scrap, ice]
		)


func _expect_habitat_ice(fails: PackedStringArray, habitat: Building, label: String, ice: int) -> void:
	if habitat.inventory == null:
		fails.append("%s has no inventory" % label)
		return
	if habitat.inventory.cap_ice != Constants.HABITAT_CAP_ICE:
		fails.append(
			"%s cap_ice is %d, expected %d"
			% [label, habitat.inventory.cap_ice, Constants.HABITAT_CAP_ICE]
		)
	if (
		habitat.inventory.cap_scrap != 0
		or habitat.inventory.cap_ore != 0
		or habitat.inventory.cap_parts != 0
		or habitat.inventory.cap_food != 0
	):
		fails.append("%s should only accept Ice" % label)
	if habitat.inventory.ice != ice:
		fails.append("%s ice is %d, expected %d" % [label, habitat.inventory.ice, ice])


func _deposit_tiles(world: World) -> Array:
	var tiles: Array = []
	for id in world.deposits:
		var deposit: Deposit = world.deposits[id]
		tiles.append([deposit.kind, deposit.tile.x, deposit.tile.y, deposit.remaining])
	tiles.sort()
	return tiles


func _guard_at(world: World, pos: Vector2) -> Unit:
	for id in world.units:
		var unit: Unit = world.units[id]
		if unit.kind == Types.UnitKind.GUARD and unit.pos == pos:
			return unit
	return null


func _spanning_tree_edges(world: World) -> Array:
	var edges: Array = []
	var connected: Array[Vector2i] = [Constants.PLAYER_SPAWN_TILE]
	var unused: Array[Vector2i] = []
	for raw in world.camps:
		var camp: World.Camp = raw
		if camp != null:
			unused.append(camp.depot_tile)
	while not unused.is_empty():
		var best_i := 0
		var best_endpoint := connected[0]
		var best_cheb := maxi(
			absi(unused[0].x - connected[0].x), absi(unused[0].y - connected[0].y)
		)
		for i in unused.size():
			var depot: Vector2i = unused[i]
			for node in connected:
				var d := maxi(absi(depot.x - node.x), absi(depot.y - node.y))
				if d > best_cheb:
					continue
				var better := d < best_cheb
				if not better:
					better = depot.x < unused[best_i].x or (
						depot.x == unused[best_i].x and depot.y < unused[best_i].y
					)
				if not better and depot == unused[best_i]:
					better = node.x < best_endpoint.x or (
						node.x == best_endpoint.x and node.y < best_endpoint.y
					)
				if better:
					best_cheb = d
					best_i = i
					best_endpoint = node
		var next: Vector2i = unused[best_i]
		edges.append([best_endpoint, next])
		connected.append(next)
		unused.remove_at(best_i)
	return edges


func _assert_rect_empty_of_rocks(fails: PackedStringArray, world: World, rect: Rect2i, label: String) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if World.is_solid_terrain(world.get_terrain(x, y)):
				fails.append("%s reserved rect has solid terrain at (%d,%d)" % [label, x, y])
				return


func _manhattan_corridor_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var seen := {}
	var p := a
	var dir_h := Vector2i(signi(b.x - a.x), 0)
	var dir_v := Vector2i(0, signi(b.y - a.y))
	var half := int(Constants.CORRIDOR_WIDTH / 2)
	var steps: Array[Vector2i] = []
	if dir_h != Vector2i.ZERO:
		steps.append(p)
		while p.x != b.x:
			p.x += dir_h.x
			steps.append(p)
	if dir_v != Vector2i.ZERO:
		if dir_h == Vector2i.ZERO:
			steps.append(p)
		while p.y != b.y:
			p.y += dir_v.y
			steps.append(p)
	if steps.is_empty():
		steps.append(p)
	for i in steps.size():
		var along := dir_h if i == 0 or (dir_h != Vector2i.ZERO and steps[i].y == a.y) else dir_v
		if along == Vector2i.ZERO:
			along = Vector2i(1, 0)
		var perp := Vector2i(-along.y, along.x)
		for k in range(-half, half + 1):
			var t: Vector2i = steps[i] + perp * k
			var key := t.y * Constants.MAP_W + t.x
			if seen.has(key):
				continue
			seen[key] = true
			tiles.append(t)
	return tiles


func _tile_hash(tiles: PackedByteArray) -> int:
	var h := 0
	for i in tiles.size():
		h = (h * 31 + int(tiles[i])) & 0x7fffffff
	return h
