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
	_test_first_depot_transfer(fails)
	_test_own_depot_withdraw(fails)
	_test_gather(fails)
	_test_steal(fails)
	_test_ice_pull_decrements_depot(fails)
	_test_zero_ice_starve_loses_at_600(fails)
	_test_destroying_depot_stops_starve_clock(fails)
	_test_missing_depot_never_starts_timer(fails)
	_test_enemy_habitat_zero_wins(fails)
	_test_same_tick_both_habitats_dead_player_loses(fails)
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


func _test_first_depot_transfer(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	var depot := _player_depot(sim.world)
	if player == null or depot == null:
		fails.append("generated map missing player or depot")
		return
	_stand_beside(player, sim.world, depot)
	player.inventory.add(Types.ResourceKind.SCRAP, 8)
	player.inventory.add(Types.ResourceKind.ICE, 8)
	player.inventory.add(Types.ResourceKind.ORE, 6)
	player.inventory.add(Types.ResourceKind.PARTS, 4)
	var depot_scrap := depot.inventory.scrap
	var depot_ice := depot.inventory.ice
	var depot_ore := depot.inventory.ore
	var depot_parts := depot.inventory.parts
	_hold_interact(sim, 3)
	if player.inventory.scrap != 8 or player.inventory.ice != 8:
		fails.append("depot transfer ran before one TRANSFER_PERIOD")
	if player.inventory.ore != 6 or player.inventory.parts != 4:
		fails.append("depot ore/parts transferred before one TRANSFER_PERIOD")
	if depot.inventory.scrap != depot_scrap or depot.inventory.ice != depot_ice:
		fails.append("depot stock changed before one TRANSFER_PERIOD")
	_hold_interact(sim, 1)
	if player.inventory.scrap != 8 - Constants.TRANSFER_BATCH:
		fails.append(
			"player scrap after first transfer is %d, expected %d"
			% [player.inventory.scrap, 8 - Constants.TRANSFER_BATCH]
		)
	if player.inventory.ice != 8 - Constants.TRANSFER_BATCH:
		fails.append(
			"player ice after first transfer is %d, expected %d"
			% [player.inventory.ice, 8 - Constants.TRANSFER_BATCH]
		)
	if player.inventory.ore != 1:
		fails.append("player ore after first transfer is %d, expected 1" % player.inventory.ore)
	if player.inventory.parts != 0:
		fails.append("player parts after first transfer is %d, expected 0" % player.inventory.parts)
	if depot.inventory.scrap != depot_scrap + Constants.TRANSFER_BATCH:
		fails.append(
			"depot scrap after first transfer is %d, expected %d"
			% [depot.inventory.scrap, depot_scrap + Constants.TRANSFER_BATCH]
		)
	if depot.inventory.ice != depot_ice + Constants.TRANSFER_BATCH:
		fails.append(
			"depot ice after first transfer is %d, expected %d"
			% [depot.inventory.ice, depot_ice + Constants.TRANSFER_BATCH]
		)
	if depot.inventory.ore != depot_ore + 5:
		fails.append("depot ore after first transfer is %d, expected %d" % [depot.inventory.ore, depot_ore + 5])
	if depot.inventory.parts != depot_parts + 4:
		fails.append(
			"depot parts after first transfer is %d, expected %d" % [depot.inventory.parts, depot_parts + 4]
		)


func _test_own_depot_withdraw(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	var depot := _player_depot(sim.world)
	if player == null or depot == null:
		fails.append("withdraw setup missing player or depot")
		return
	_stand_beside(player, sim.world, depot)
	player.inventory.add(Types.ResourceKind.ORE, 6)
	_hold_interact(sim, 4)
	if player.inventory.ore != 1 or depot.inventory.ore != Constants.START_PLAYER_ORE + 5:
		fails.append(
			"deposit-before-withdraw left player/depot ore %d/%d"
			% [player.inventory.ore, depot.inventory.ore]
		)
		return
	var depot_ore := depot.inventory.ore
	_hold_withdraw(sim, 3)
	if player.inventory.ore != 1 or depot.inventory.ore != depot_ore:
		fails.append("withdraw ran before one TRANSFER_PERIOD")
	_hold_withdraw(sim, 1)
	if player.inventory.ore != 1 + Constants.TRANSFER_BATCH:
		fails.append(
			"player ore after withdraw is %d, expected %d"
			% [player.inventory.ore, 1 + Constants.TRANSFER_BATCH]
		)
	if depot.inventory.ore != depot_ore - Constants.TRANSFER_BATCH:
		fails.append(
			"depot ore after withdraw is %d, expected %d"
			% [depot.inventory.ore, depot_ore - Constants.TRANSFER_BATCH]
		)


func _test_gather(fails: PackedStringArray) -> void:
	var world := World.new()
	var player := _player_at(world, Vector2(16, 16))
	var deposit := Deposit.new()
	deposit.id = world.alloc_id()
	deposit.kind = Types.ResourceKind.SCRAP
	deposit.tile = Vector2i(0, 0)
	deposit.remaining = 1
	world.deposits[deposit.id] = deposit
	var cmd := _interact_cmd()
	var last := 0
	var ticks := int(Constants.GATHER_CHANNEL / Constants.SIM_DT) - 1
	for _i in ticks:
		last = Rules.resolve_interact(world, player, cmd, last)
	if player.inventory.scrap != 0 or deposit.remaining != 1:
		fails.append("gather transferred before one GATHER_CHANNEL")
	last = Rules.resolve_interact(world, player, cmd, last)
	if player.inventory.scrap != 1:
		fails.append("gather scrap is %d, expected 1" % player.inventory.scrap)
	if world.deposits.has(deposit.id):
		fails.append("empty deposit was not removed")


func _test_steal(fails: PackedStringArray) -> void:
	var world := World.new()
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.ENEMY
	depot.origin_tile = Vector2i(2, 2)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Inventory.new(Constants.DEPOT_CAP_SCRAP, Constants.DEPOT_CAP_ICE)
	depot.inventory.add(Types.ResourceKind.SCRAP, 9)
	depot.inventory.add(Types.ResourceKind.ICE, 4)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	var player := _player_at(world, world.tile_center(1, 2))
	var cmd := _interact_cmd()
	var last := 0
	var ticks := int(Constants.TRANSFER_PERIOD / Constants.SIM_DT) - 1
	for _i in ticks:
		last = Rules.resolve_interact(world, player, cmd, last)
	if player.inventory.scrap != 0 or player.inventory.ice != 0:
		fails.append("steal transferred before one TRANSFER_PERIOD")
	last = Rules.resolve_interact(world, player, cmd, last)
	if player.inventory.scrap != Constants.TRANSFER_BATCH:
		fails.append("steal scrap is %d, expected %d" % [player.inventory.scrap, Constants.TRANSFER_BATCH])
	if player.inventory.ice != 4:
		fails.append("steal ice is %d, expected 4" % player.inventory.ice)
	if depot.inventory.scrap != 9 - Constants.TRANSFER_BATCH:
		fails.append("enemy depot scrap is %d, expected %d" % [depot.inventory.scrap, 9 - Constants.TRANSFER_BATCH])
	if depot.inventory.ice != 0:
		fails.append("enemy depot ice is %d, expected 0" % depot.inventory.ice)


func _test_ice_pull_decrements_depot(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _player_depot(sim.world)
	if depot == null or depot.inventory == null:
		fails.append("generated map missing player depot")
		return
	var before := depot.inventory.ice
	if before < 1:
		fails.append("player depot ice is %d, expected starting stock" % before)
		return
	_tick_idle(sim, _ticks_for(Constants.ICE_PULL_PLAYER) - 1)
	if depot.inventory.ice != before:
		fails.append("ice pull ran before one ICE_PULL_PLAYER (%d -> %d)" % [before, depot.inventory.ice])
	_tick_idle(sim, 1)
	if depot.inventory.ice != before - 1:
		fails.append("ice pull left depot ice %d, expected %d" % [depot.inventory.ice, before - 1])


func _test_zero_ice_starve_loses_at_600(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _player_depot(sim.world)
	if depot == null or depot.inventory == null:
		fails.append("generated map missing player depot")
		return
	_empty_ice(depot)
	var limit_ticks := _ticks_for(Constants.ZERO_ICE_LIMIT)
	_tick_idle(sim, limit_ticks - 1)
	if sim.outcome != Types.Outcome.NONE:
		fails.append("starve outcome locked at tick %d, expected NONE" % sim.tick_index)
	var rec: Variant = sim.life.get(Types.Faction.PLAYER)
	if rec == null or rec.zero_ice_timer < Constants.ZERO_ICE_LIMIT - Constants.SIM_DT - 0.0001:
		fails.append("zero_ice_timer before limit tick is %s" % str(rec.zero_ice_timer if rec else rec))
	_tick_idle(sim, 1)
	if sim.outcome != Types.Outcome.PLAYER_LOSE or sim.outcome_reason != Types.OutcomeReason.LIFE_SUPPORT:
		fails.append(
			"600 zero-ice ticks gave %d/%d, expected PLAYER_LOSE/LIFE_SUPPORT"
			% [sim.outcome, sim.outcome_reason]
		)
	if rec == null or rec.zero_ice_timer < Constants.ZERO_ICE_LIMIT:
		fails.append("zero_ice_timer after 600 ticks is %s" % str(rec.zero_ice_timer if rec else rec))


func _test_destroying_depot_stops_starve_clock(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _player_depot(sim.world)
	if depot == null or depot.inventory == null:
		fails.append("generated map missing player depot")
		return
	_empty_ice(depot)
	_tick_idle(sim, 10)
	var rec: Variant = sim.life.get(Types.Faction.PLAYER)
	if rec == null:
		fails.append("missing player FactionLife")
		return
	var frozen: float = rec.zero_ice_timer
	if frozen <= 0.0:
		fails.append("starve clock did not advance before depot death")
		return
	Combat.process_building_death(sim.world, depot)
	_tick_idle(sim, _ticks_for(Constants.ZERO_ICE_LIMIT))
	if not is_equal_approx(rec.zero_ice_timer, frozen):
		fails.append("zero_ice_timer grew after depot death (%s -> %s)" % [str(frozen), str(rec.zero_ice_timer)])
	if sim.outcome == Types.Outcome.PLAYER_LOSE and sim.outcome_reason == Types.OutcomeReason.LIFE_SUPPORT:
		fails.append("destroying the depot set LIFE_SUPPORT")


func _test_missing_depot_never_starts_timer(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _player_depot(sim.world)
	if depot == null:
		fails.append("generated map missing player depot")
		return
	Combat.process_building_death(sim.world, depot)
	_tick_idle(sim, _ticks_for(Constants.ZERO_ICE_LIMIT))
	var rec: Variant = sim.life.get(Types.Faction.PLAYER)
	if rec != null and rec.zero_ice_timer != 0.0:
		fails.append("missing depot from t=0 set zero_ice_timer to %s" % str(rec.zero_ice_timer))
	if sim.outcome == Types.Outcome.PLAYER_LOSE and sim.outcome_reason == Types.OutcomeReason.LIFE_SUPPORT:
		fails.append("missing depot from t=0 set LIFE_SUPPORT")


func _test_enemy_habitat_zero_wins(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var habitat := _faction_building(sim.world, Types.Faction.ENEMY, Types.BuildingKind.HABITAT)
	if habitat == null:
		fails.append("generated map missing enemy habitat")
		return
	habitat.hp = 0
	_tick_idle(sim, 1)
	if sim.outcome != Types.Outcome.PLAYER_WIN or sim.outcome_reason != Types.OutcomeReason.HABITAT_DESTROYED:
		fails.append(
			"enemy habitat 0 gave %d/%d, expected PLAYER_WIN/HABITAT_DESTROYED"
			% [sim.outcome, sim.outcome_reason]
		)


func _test_same_tick_both_habitats_dead_player_loses(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player_h := _faction_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	var enemy_h := _faction_building(sim.world, Types.Faction.ENEMY, Types.BuildingKind.HABITAT)
	if player_h == null or enemy_h == null:
		fails.append("generated map missing a habitat")
		return
	player_h.hp = 0
	enemy_h.hp = 0
	_tick_idle(sim, 1)
	if sim.outcome != Types.Outcome.PLAYER_LOSE or sim.outcome_reason != Types.OutcomeReason.HABITAT_DESTROYED:
		fails.append(
			"same-tick both habitats dead gave %d/%d, expected PLAYER_LOSE/HABITAT_DESTROYED"
			% [sim.outcome, sim.outcome_reason]
		)


func _tick_idle(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.tick()


func _ticks_for(seconds: float) -> int:
	return int(round(seconds / Constants.SIM_DT))


func _empty_ice(depot: Building) -> void:
	if depot.inventory != null and depot.inventory.ice > 0:
		depot.inventory.remove(Types.ResourceKind.ICE, depot.inventory.ice)


func _faction_building(world: World, faction: int, kind: int) -> Building:
	for building in world.buildings.values():
		if building.kind == kind and building.faction == faction:
			return building
	return null


func _hold_interact(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.enqueue(_interact_cmd())
		sim.tick()


func _hold_withdraw(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		var cmd := _interact_cmd()
		cmd.withdraw = true
		sim.enqueue(cmd)
		sim.tick()


func _interact_cmd() -> InputCommand:
	var cmd := InputCommand.new()
	cmd.interact = true
	return cmd


func _stand_beside(unit: Unit, world: World, building: Building) -> void:
	var tile := Vector2i(building.origin_tile.x - 1, building.origin_tile.y)
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.vel = Vector2.ZERO


func _player_at(world: World, pos: Vector2) -> Unit:
	var player := Unit.new()
	player.id = world.alloc_id()
	player.kind = Types.UnitKind.PLAYER
	player.faction = Types.Faction.PLAYER
	player.pos = pos
	player.radius = Constants.PLAYER_RADIUS
	player.alive = true
	player.inventory = Unit.inventory_for(Types.UnitKind.PLAYER)
	world.units[player.id] = player
	return player


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
