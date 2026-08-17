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
	for tile in _manhattan_corridor_tiles(Constants.PLAYER_SPAWN_TILE, Constants.ENEMY_DEPOT_TILE):
		if Mapgen.is_building_footprint(tile.x, tile.y):
			continue
		if world.get_terrain(tile.x, tile.y) != Types.TileTerrain.EMPTY:
			fails.append("Manhattan corridor tile (%d,%d) is not EMPTY" % [tile.x, tile.y])
			return


func _test_camps_reserved(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	_assert_rect_empty_of_rocks(fails, world, Constants.PLAYER_CAMP_RECT, "player camp")
	_assert_rect_empty_of_rocks(fails, world, Constants.ENEMY_CAMP_RECT, "enemy camp")
	if Constants.PLAYER_SPAWN_TILE != Vector2i(23, 218):
		fails.append("PLAYER_SPAWN_TILE is %s, expected (23, 218)" % Constants.PLAYER_SPAWN_TILE)
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_SPAWN_TILE):
		fails.append("player spawn is outside PLAYER_CAMP_RECT")
	if not Constants.ENEMY_CAMP_RECT.has_point(Constants.ENEMY_DEPOT_TILE):
		fails.append("enemy depot is outside ENEMY_CAMP_RECT")
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_HABITAT_TILE):
		fails.append("player habitat is outside PLAYER_CAMP_RECT")
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_DEPOT_TILE):
		fails.append("player depot is outside PLAYER_CAMP_RECT")
	if not Constants.ENEMY_CAMP_RECT.has_point(Constants.ENEMY_HABITAT_TILE):
		fails.append("enemy habitat is outside ENEMY_CAMP_RECT")
	var spawn := Constants.PLAYER_SPAWN_TILE
	var depot := Constants.ENEMY_DEPOT_TILE
	var cheb := maxi(absi(depot.x - spawn.x), absi(depot.y - spawn.y))
	if cheb < 40 or cheb > 48:
		fails.append("near-camp depot Chebyshev is %d, expected 40-48" % cheb)
	if depot.x <= spawn.x or depot.y > spawn.y:
		fails.append("near-camp depot %s is not east or north-east of spawn %s" % [depot, spawn])


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
	_expect_building(
		fails, world, Constants.ENEMY_HABITAT_TILE, Types.BuildingKind.HABITAT,
		Types.Faction.ENEMY, Constants.HABITAT_HP
	)
	_expect_building(
		fails, world, Constants.ENEMY_DEPOT_TILE, Types.BuildingKind.DEPOT,
		Types.Faction.ENEMY, Constants.DEPOT_HP
	)
	_expect_building(
		fails, world, Constants.ENEMY_TURRET_TILE, Types.BuildingKind.TURRET,
		Types.Faction.ENEMY, Constants.TURRET_HP
	)
	var guard: Unit = null
	for id in world.units:
		var unit: Unit = world.units[id]
		if unit.kind == Types.UnitKind.GUARD:
			guard = unit
			break
	if guard == null:
		fails.append("mapgen did not spawn an enemy guard")
		return
	var expected := world.tile_center(Constants.ENEMY_GUARD_TILE.x, Constants.ENEMY_GUARD_TILE.y)
	if guard.pos != expected:
		fails.append("guard pos is %s, expected %s" % [guard.pos, expected])
	if guard.faction != Types.Faction.ENEMY:
		fails.append("guard faction is %d, expected ENEMY" % guard.faction)
	if guard.hp != Constants.GUARD_HP or guard.hp_max != Constants.GUARD_HP:
		fails.append("guard hp is %d/%d, expected %d" % [guard.hp, guard.hp_max, Constants.GUARD_HP])


func _test_starting_stocks(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	var player_depot := world.building_at(Constants.PLAYER_DEPOT_TILE.x, Constants.PLAYER_DEPOT_TILE.y)
	var enemy_depot := world.building_at(Constants.ENEMY_DEPOT_TILE.x, Constants.ENEMY_DEPOT_TILE.y)
	if player_depot == null or player_depot.kind != Types.BuildingKind.DEPOT:
		fails.append("player depot missing at PLAYER_DEPOT_TILE")
		return
	if enemy_depot == null or enemy_depot.kind != Types.BuildingKind.DEPOT:
		fails.append("enemy depot missing at ENEMY_DEPOT_TILE")
		return
	_expect_stock(fails, player_depot, "player depot", Constants.START_PLAYER_SCRAP, Constants.START_PLAYER_ICE)
	_expect_stock(fails, enemy_depot, "enemy depot", Constants.START_ENEMY_SCRAP, Constants.START_ENEMY_ICE)


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


func _deposit_placement_ok(fails: PackedStringArray, world: World, deposit: Deposit, seed: int) -> bool:
	var tile: Vector2i = deposit.tile
	if not world.is_walkable(tile.x, tile.y):
		fails.append("seed %d deposit %d on non-walkable tile %s" % [seed, deposit.id, tile])
		return false
	if Constants.PLAYER_CAMP_RECT.has_point(tile) or Constants.ENEMY_CAMP_RECT.has_point(tile):
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


func _deposit_tiles(world: World) -> Array:
	var tiles: Array = []
	for id in world.deposits:
		var deposit: Deposit = world.deposits[id]
		tiles.append([deposit.kind, deposit.tile.x, deposit.tile.y, deposit.remaining])
	tiles.sort()
	return tiles


func _assert_rect_empty_of_rocks(fails: PackedStringArray, world: World, rect: Rect2i, label: String) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if world.get_terrain(x, y) == Types.TileTerrain.ROCK:
				fails.append("%s reserved rect has rock at (%d,%d)" % [label, x, y])
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
