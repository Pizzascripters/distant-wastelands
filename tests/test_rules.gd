extends RefCounted

const _TILE := Vector2i(10, 10)


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_reject_rock(fails)
	_test_reject_overlap(fails)
	_test_reject_enemy_rect(fails)
	_test_reject_unaffordable(fails)
	_test_reject_max_buildings(fails)
	_test_reject_missing_depot(fails)
	_test_build_deducts_scrap(fails)
	return fails


func _test_reject_rock(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	world.set_terrain(_TILE.x, _TILE.y, Types.TileTerrain.ROCK)
	if Rules.can_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject a rock tile")
	if Rules.try_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("try_place should reject a rock tile")


func _test_reject_overlap(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	if Rules.can_place(world, Types.BuildingKind.WALL, Vector2i(2, 2)):
		fails.append("can_place should reject a building footprint")

	var deposit := Deposit.new()
	deposit.id = world.alloc_id()
	deposit.kind = Types.ResourceKind.SCRAP
	deposit.tile = _TILE
	deposit.remaining = Constants.SCRAP_DEPOSIT_AMOUNT
	world.deposits[deposit.id] = deposit
	if Rules.can_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject a deposit tile")
	world.deposits.erase(deposit.id)

	var unit := Unit.new()
	unit.id = world.alloc_id()
	unit.kind = Types.UnitKind.PLAYER
	unit.faction = Types.Faction.PLAYER
	unit.pos = world.tile_center(_TILE.x, _TILE.y)
	unit.radius = Constants.PLAYER_RADIUS
	unit.alive = true
	world.units[unit.id] = unit
	if Rules.can_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject a unit overlap")


func _test_reject_enemy_rect(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	var tile := Constants.ENEMY_CAMP_RECT.position
	if Rules.can_place(world, Types.BuildingKind.WALL, tile):
		fails.append("can_place should reject ENEMY_CAMP_RECT")


func _test_reject_unaffordable(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST - 1)
	if Rules.can_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject when the depot cannot afford the wall")
	if Rules.try_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("try_place should reject when unaffordable")
	var depot := world.building_at(2, 2)
	if depot.inventory.scrap != Constants.WALL_COST - 1:
		fails.append("unaffordable try_place changed scrap to %d" % depot.inventory.scrap)


func _test_reject_max_buildings(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	_fill_buildings(world, Constants.MAX_BUILDINGS)
	if world.buildings.size() != Constants.MAX_BUILDINGS:
		fails.append("setup left %d buildings, expected %d" % [world.buildings.size(), Constants.MAX_BUILDINGS])
		return
	if Rules.can_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject at MAX_BUILDINGS")


func _test_reject_missing_depot(fails: PackedStringArray) -> void:
	var world := World.new()
	if Rules.can_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject when the player depot is missing")
	var with_dead := _world_with_depot(Constants.WALL_COST)
	var depot := with_dead.building_at(2, 2)
	depot.hp = 0
	if Rules.can_place(with_dead, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject when the player depot is dead")


func _test_build_deducts_scrap(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.START_PLAYER_SCRAP)
	if not Rules.try_place(world, Types.BuildingKind.WALL, _TILE):
		fails.append("try_place wall should succeed on an empty tile")
		return
	var depot := world.building_at(2, 2)
	var expected_scrap := Constants.START_PLAYER_SCRAP - Constants.WALL_COST
	if depot.inventory.scrap != expected_scrap:
		fails.append("depot scrap is %d, expected %d" % [depot.inventory.scrap, expected_scrap])
	var wall := world.building_at(_TILE.x, _TILE.y)
	if wall == null:
		fails.append("placed wall missing from occupancy")
		return
	if wall.kind != Types.BuildingKind.WALL or wall.faction != Types.Faction.PLAYER:
		fails.append("placed building is kind %d faction %d" % [wall.kind, wall.faction])
	if wall.hp != Constants.WALL_HP or wall.hp_max != Constants.WALL_HP:
		fails.append("placed wall hp is %d/%d" % [wall.hp, wall.hp_max])
	if wall.aim != Vector2(1, 0):
		fails.append("placed wall aim is %s, expected (1, 0)" % wall.aim)

	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var sim_depot := _player_depot(sim.world)
	if sim_depot == null:
		fails.append("generated map missing player depot")
		return
	var tile := _first_placeable(sim.world, Types.BuildingKind.TURRET)
	if tile.x < 0:
		fails.append("generated map has no placeable turret tile")
		return
	var before := sim_depot.inventory.scrap
	var cmd := InputCommand.new()
	cmd.build_kind = Types.BuildingKind.TURRET
	cmd.build_tile = tile
	sim.enqueue(cmd)
	sim.tick()
	if sim_depot.inventory.scrap != before - Constants.TURRET_COST:
		fails.append(
			"sim build left scrap %d, expected %d"
			% [sim_depot.inventory.scrap, before - Constants.TURRET_COST]
		)
	var turret := sim.world.building_at(tile.x, tile.y)
	if turret == null or turret.kind != Types.BuildingKind.TURRET:
		fails.append("sim tick did not place a turret at %s" % tile)


func _world_with_depot(scrap: int) -> World:
	var world := World.new()
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Vector2i(2, 2)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Inventory.new(Constants.DEPOT_CAP_SCRAP, Constants.DEPOT_CAP_ICE)
	depot.inventory.add(Types.ResourceKind.SCRAP, scrap)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	return world


func _fill_buildings(world: World, count: int) -> void:
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			if world.buildings.size() >= count:
				return
			if world.building_at(x, y) != null:
				continue
			if Vector2i(x, y) == _TILE:
				continue
			if Constants.ENEMY_CAMP_RECT.has_point(Vector2i(x, y)):
				continue
			var building := Building.new()
			building.id = world.alloc_id()
			building.kind = Types.BuildingKind.WALL
			building.faction = Types.Faction.PLAYER
			building.origin_tile = Vector2i(x, y)
			building.hp = Constants.WALL_HP
			building.hp_max = Constants.WALL_HP
			world.buildings[building.id] = building
			world.occupy(building)


func _player_depot(world: World) -> Building:
	for building in world.buildings.values():
		if building.kind == Types.BuildingKind.DEPOT and building.faction == Types.Faction.PLAYER:
			return building
	return null


func _first_placeable(world: World, kind: int) -> Vector2i:
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var tile := Vector2i(x, y)
			if Rules.can_place(world, kind, tile):
				return tile
	return Vector2i(-1, -1)
