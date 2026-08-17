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
	for y in range(Constants.CORRIDOR_H_Y0, Constants.CORRIDOR_H_Y1 + 1):
		for x in range(Constants.CORRIDOR_H_X0, Constants.CORRIDOR_H_X1 + 1):
			if Mapgen.is_building_footprint(x, y):
				continue
			if world.get_terrain(x, y) != Types.TileTerrain.EMPTY:
				fails.append("L-corridor H tile (%d,%d) is not EMPTY" % [x, y])
				return
	for y in range(Constants.CORRIDOR_V_Y0, Constants.CORRIDOR_V_Y1 + 1):
		for x in range(Constants.CORRIDOR_V_X0, Constants.CORRIDOR_V_X1 + 1):
			if Mapgen.is_building_footprint(x, y):
				continue
			if world.get_terrain(x, y) != Types.TileTerrain.EMPTY:
				fails.append("L-corridor V tile (%d,%d) is not EMPTY" % [x, y])
				return


func _test_camps_reserved(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	_assert_rect_empty_of_rocks(fails, world, Constants.PLAYER_CAMP_RECT, "player camp")
	_assert_rect_empty_of_rocks(fails, world, Constants.ENEMY_CAMP_RECT, "enemy camp")
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
	if tile.x == Constants.CORRIDOR_CENTER_X or tile.y == Constants.CORRIDOR_CENTER_Y:
		fails.append("seed %d deposit %d on corridor center line at %s" % [seed, deposit.id, tile])
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


func _tile_hash(tiles: PackedByteArray) -> int:
	var h := 0
	for i in tiles.size():
		h = (h * 31 + int(tiles[i])) & 0x7fffffff
	return h
