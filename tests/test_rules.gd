extends RefCounted

const _TILE := Vector2i(10, 10)


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_reject_rock(fails)
	_test_reject_cliff(fails)
	_test_reject_crater(fails)
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
	_test_ice_pull_decrements_habitat(fails)
	_test_never_aggro_enemy_ice_frozen(fails)
	_test_zero_ice_does_not_lose(fails)
	_test_destroying_depot_is_not_a_lose(fails)
	_test_missing_depot_never_starts_timer(fails)
	_test_habitat_ice_transfer(fails)
	_test_pools_pay_from_habitats(fails)
	_test_enemy_habitat_zero_is_not_win(fails)
	_test_habitat_smash_is_not_a_lose(fails)
	_test_oxygen_failed_is_suffocation(fails)
	_test_same_tick_oxygen_and_habitat_death_is_suffocation(fails)
	_test_same_tick_hunger_lethal_and_o2_is_suffocation(fails)
	_test_place_workshop_and_lab(fails)
	_test_lab_occupies_2x2(fails)
	_test_workshop_closer_wins_when_craftable(fails)
	_test_workshop_overlap_crafts_not_deposit(fails)
	_test_lab_closer_wins_when_research_selected(fails)
	_test_locked_buildings_not_placeable(fails)
	_test_player_slides_onto_gate_raider_blocked(fails)
	_test_place_farm_after_hydroponics(fails)
	_test_farm_harvest_transfer(fails)
	_test_hunger_is_not_a_lose(fails)
	_test_depot_skips_food(fails)
	_test_two_depots_share_scrap(fails)
	_test_place_habitat_and_depot(fails)
	_test_last_pad_recovery(fails)
	_test_last_depot_zero_scrap_spills_floor(fails)
	return fails


func _test_reject_rock(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	world.set_terrain(_TILE.x, _TILE.y, Types.TileTerrain.ROCK)
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject a rock tile")
	if Rules.try_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("try_place should reject a rock tile")


func _test_reject_cliff(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	world.set_terrain(_TILE.x, _TILE.y, Types.TileTerrain.CLIFF)
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject a cliff tile")
	if Rules.try_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("try_place should reject a cliff tile")


func _test_reject_crater(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	world.set_terrain(_TILE.x, _TILE.y, Types.TileTerrain.CRATER)
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject a crater tile")
	if Rules.try_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("try_place should reject a crater tile")


func _test_reject_overlap(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	if Rules.can_place(world, null, Types.BuildingKind.WALL, Vector2i(2, 2)):
		fails.append("can_place should reject a building footprint")

	var deposit := Deposit.new()
	deposit.id = world.alloc_id()
	deposit.kind = Types.ResourceKind.SCRAP
	deposit.tile = _TILE
	deposit.remaining = Constants.SCRAP_DEPOSIT_AMOUNT
	world.deposits[deposit.id] = deposit
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
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
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject a unit overlap")


func _test_reject_enemy_rect(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST)
	var camp := World.Camp.new()
	camp.reserved = Rect2i(40, 40, Constants.ENEMY_CAMP_RECT_SIZE, Constants.ENEMY_CAMP_RECT_SIZE)
	world.camps.append(camp)
	var tile := camp.reserved.position
	if Rules.can_place(world, null, Types.BuildingKind.WALL, tile):
		fails.append("can_place should reject an enemy camp rect")


func _test_reject_unaffordable(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WALL_COST - 1)
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject when the depot cannot afford the wall")
	if Rules.try_place(world, null, Types.BuildingKind.WALL, _TILE):
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
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject at MAX_BUILDINGS")


func _test_reject_missing_depot(fails: PackedStringArray) -> void:
	var world := World.new()
	if Rules.can_place(world, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject when the player depot is missing")
	var with_dead := _world_with_depot(Constants.WALL_COST)
	var depot := with_dead.building_at(2, 2)
	depot.hp = 0
	if Rules.can_place(with_dead, null, Types.BuildingKind.WALL, _TILE):
		fails.append("can_place should reject when the player depot is dead")


func _test_build_deducts_scrap(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.START_PLAYER_SCRAP)
	if not Rules.try_place(world, null, Types.BuildingKind.WALL, _TILE):
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
	if player.inventory.ice != 8:
		fails.append(
			"player ice after first depot transfer is %d, expected 8 (depots reject Ice)"
			% player.inventory.ice
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
	if depot.inventory.ice != depot_ice:
		fails.append(
			"depot ice after first transfer is %d, expected %d (depots reject Ice)"
			% [depot.inventory.ice, depot_ice]
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
	depot.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
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
	if player.inventory.ice != 0:
		fails.append("steal took ice from a depot: %d" % player.inventory.ice)
	if depot.inventory.scrap != 9 - Constants.TRANSFER_BATCH:
		fails.append("enemy depot scrap is %d, expected %d" % [depot.inventory.scrap, 9 - Constants.TRANSFER_BATCH])
	if depot.inventory.ice != 0:
		fails.append("enemy depot ice is %d, expected 0" % depot.inventory.ice)


func _test_ice_pull_decrements_habitat(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var habitat := _faction_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	var depot := _player_depot(sim.world)
	if habitat == null or habitat.inventory == null:
		fails.append("generated map missing player habitat")
		return
	var before := habitat.inventory.ice
	if before < 1:
		fails.append("player habitat ice is %d, expected starting stock" % before)
		return
	var depot_ice := 0
	if depot != null and depot.inventory != null:
		depot_ice = depot.inventory.ice
	_tick_idle(sim, _ticks_for(Constants.ICE_PULL_PLAYER) - 1)
	if habitat.inventory.ice != before:
		fails.append("ice pull ran before one ICE_PULL_PLAYER (%d -> %d)" % [before, habitat.inventory.ice])
	_tick_idle(sim, 1)
	if habitat.inventory.ice != before - 1:
		fails.append("ice pull left habitat ice %d, expected %d" % [habitat.inventory.ice, before - 1])
	if depot != null and depot.inventory != null and depot.inventory.ice != depot_ice:
		fails.append("ice pull mutated depot ice %d -> %d" % [depot_ice, depot.inventory.ice])


func _test_never_aggro_enemy_ice_frozen(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var camp := _never_aggro_camp(sim)
	if camp == null:
		fails.append("never-aggro ice test missing a far camp")
		return
	var habitat := sim.world.buildings.get(camp.habitat_id) as Building
	if habitat == null or habitat.inventory == null:
		fails.append("far camp missing habitat")
		return
	if habitat.inventory.ice != Constants.START_ENEMY_ICE:
		fails.append(
			"far camp ice started at %d, expected %d"
			% [habitat.inventory.ice, Constants.START_ENEMY_ICE]
		)
	for _i in 5:
		sim.tick()
	if camp.ever_aggro:
		fails.append("far camp should stay unaggro'd from the starter pad")
		return
	var ticks := _ticks_for(600.0)
	for _i in ticks:
		Rules.tick_life_support(sim)
	sim.time = 600.0
	if habitat.inventory.ice != Constants.START_ENEMY_ICE:
		fails.append(
			"never-aggro'd enemy Habitat at t=600s has ice %d, expected %d"
			% [habitat.inventory.ice, Constants.START_ENEMY_ICE]
		)
	if habitat.ice_debt_timer != 0.0:
		fails.append(
			"never-aggro'd enemy Habitat ice_debt_timer is %s, expected 0"
			% str(habitat.ice_debt_timer)
		)


func _test_zero_ice_does_not_lose(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var habitat := _faction_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if habitat == null or habitat.inventory == null:
		fails.append("generated map missing player habitat")
		return
	_empty_ice(habitat)
	_tick_idle(sim, _ticks_for(30.0))
	if sim.outcome != Types.Outcome.NONE:
		fails.append(
			"zero habitat ice locked outcome %d/%d, expected NONE"
			% [sim.outcome, sim.outcome_reason]
		)
	if "life" in sim:
		fails.append("Sim.life should be removed")


func _test_destroying_depot_is_not_a_lose(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _player_depot(sim.world)
	if depot == null or depot.inventory == null:
		fails.append("generated map missing player depot")
		return
	Combat.process_building_death(sim.world, depot)
	_tick_idle(sim, _ticks_for(30.0))
	if sim.outcome != Types.Outcome.NONE:
		fails.append("destroying the depot set outcome %d/%d" % [sim.outcome, sim.outcome_reason])


func _test_missing_depot_never_starts_timer(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := _player_depot(sim.world)
	if depot == null:
		fails.append("generated map missing player depot")
		return
	Combat.process_building_death(sim.world, depot)
	_tick_idle(sim, _ticks_for(30.0))
	if sim.outcome != Types.Outcome.NONE:
		fails.append("missing depot from t=0 set outcome %d/%d" % [sim.outcome, sim.outcome_reason])


func _test_habitat_ice_transfer(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		_silence_raids(sim)
	var player := sim.get_player()
	var habitat := _faction_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if player == null or habitat == null or habitat.inventory == null:
		fails.append("habitat transfer missing player or habitat")
		return
	_stand_beside(player, sim.world, habitat)
	player.inventory.add(Types.ResourceKind.ICE, 8)
	player.inventory.add(Types.ResourceKind.SCRAP, 5)
	var hab_ice := habitat.inventory.ice
	_hold_interact(sim, 3)
	if player.inventory.ice != 8:
		fails.append("habitat ice transfer ran before one TRANSFER_PERIOD")
	_hold_interact(sim, 1)
	if player.inventory.ice != 8 - Constants.TRANSFER_BATCH:
		fails.append("player ice after habitat dump is %d" % player.inventory.ice)
	if habitat.inventory.ice != hab_ice + Constants.TRANSFER_BATCH:
		fails.append("habitat ice after dump is %d" % habitat.inventory.ice)
	if player.inventory.scrap != 5:
		fails.append("habitat dump moved scrap")
	_hold_withdraw(sim, 4)
	if player.inventory.ice != 8:
		fails.append("player ice after habitat withdraw is %d" % player.inventory.ice)
	if habitat.inventory.ice != hab_ice:
		fails.append("habitat ice after withdraw is %d" % habitat.inventory.ice)

	var world := World.new()
	var enemy := Building.new()
	enemy.id = world.alloc_id()
	enemy.kind = Types.BuildingKind.HABITAT
	enemy.faction = Types.Faction.ENEMY
	enemy.origin_tile = Vector2i(2, 2)
	enemy.hp = Constants.HABITAT_HP
	enemy.hp_max = Constants.HABITAT_HP
	enemy.inventory = Building.inventory_for(Types.BuildingKind.HABITAT)
	enemy.inventory.add(Types.ResourceKind.ICE, 7)
	world.buildings[enemy.id] = enemy
	world.occupy(enemy)
	var thief := _player_at(world, world.tile_center(1, 2))
	var cmd := _interact_cmd()
	var last := 0
	var ticks := int(Constants.TRANSFER_PERIOD / Constants.SIM_DT)
	for _i in ticks:
		last = Rules.resolve_interact(world, thief, cmd, last)
	if thief.inventory.ice != Constants.TRANSFER_BATCH:
		fails.append("steal habitat ice is %d, expected %d" % [thief.inventory.ice, Constants.TRANSFER_BATCH])
	if enemy.inventory.ice != 7 - Constants.TRANSFER_BATCH:
		fails.append("enemy habitat ice after steal is %d" % enemy.inventory.ice)


func _test_pools_pay_from_habitats(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.FARM_COST_SCRAP)
	var habitat_a := Building.new()
	habitat_a.id = world.alloc_id()
	habitat_a.kind = Types.BuildingKind.HABITAT
	habitat_a.faction = Types.Faction.PLAYER
	habitat_a.origin_tile = Vector2i(4, 2)
	habitat_a.hp = Constants.HABITAT_HP
	habitat_a.hp_max = Constants.HABITAT_HP
	habitat_a.inventory = Building.inventory_for(Types.BuildingKind.HABITAT)
	habitat_a.inventory.add(Types.ResourceKind.ICE, 2)
	world.buildings[habitat_a.id] = habitat_a
	world.occupy(habitat_a)
	var habitat_b := Building.new()
	habitat_b.id = world.alloc_id()
	habitat_b.kind = Types.BuildingKind.HABITAT
	habitat_b.faction = Types.Faction.PLAYER
	habitat_b.origin_tile = Vector2i(6, 2)
	habitat_b.hp = Constants.HABITAT_HP
	habitat_b.hp_max = Constants.HABITAT_HP
	habitat_b.inventory = Building.inventory_for(Types.BuildingKind.HABITAT)
	habitat_b.inventory.add(Types.ResourceKind.ICE, 3)
	world.buildings[habitat_b.id] = habitat_b
	world.occupy(habitat_b)
	if Rules.player_pool_amount(world, Types.ResourceKind.ICE) != 5:
		fails.append("ice pool is %d, expected 5" % Rules.player_pool_amount(world, Types.ResourceKind.ICE))
	if not Rules.pay_player(world, {Types.ResourceKind.ICE: 4}):
		fails.append("pay_player ice 4 should succeed")
		return
	if habitat_a.inventory.ice != 0:
		fails.append("lowest-id habitat ice is %d, expected 0" % habitat_a.inventory.ice)
	if habitat_b.inventory.ice != 1:
		fails.append("second habitat ice is %d, expected 1" % habitat_b.inventory.ice)


func _test_enemy_habitat_zero_is_not_win(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var habitat := _faction_building(sim.world, Types.Faction.ENEMY, Types.BuildingKind.HABITAT)
	if habitat == null:
		fails.append("generated map missing enemy habitat")
		return
	habitat.hp = 0
	_tick_idle(sim, 1)
	if sim.outcome != Types.Outcome.NONE:
		fails.append(
			"enemy habitat 0 gave %d/%d, expected NONE"
			% [sim.outcome, sim.outcome_reason]
		)


func _test_habitat_smash_is_not_a_lose(fails: PackedStringArray) -> void:
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
	if sim.outcome != Types.Outcome.NONE:
		fails.append(
			"both habitats dead gave %d/%d, expected NONE"
			% [sim.outcome, sim.outcome_reason]
		)


func _test_oxygen_failed_is_suffocation(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	sim.oxygen_failed = true
	var result := Rules.evaluate_outcome(sim)
	if result.x != Types.Outcome.PLAYER_LOSE or result.y != Types.OutcomeReason.SUFFOCATION:
		fails.append(
			"evaluate_outcome(oxygen_failed) is %d/%d, expected PLAYER_LOSE/SUFFOCATION"
			% [result.x, result.y]
		)


func _test_same_tick_oxygen_and_habitat_death_is_suffocation(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		_silence_raids(sim)
	var player := sim.get_player()
	var habitat := _faction_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if player == null or habitat == null:
		fails.append("oxygen+habitat test missing player or habitat")
		return
	player.pos = Vector2(20.5 * Constants.TILE, 20.5 * Constants.TILE)
	player.o2 = 0.0
	habitat.hp = 0
	_tick_idle(sim, 1)
	if not sim.oxygen_failed:
		fails.append("same-tick o2 == 0 + habitat death should set oxygen_failed")
	if sim.outcome != Types.Outcome.PLAYER_LOSE or sim.outcome_reason != Types.OutcomeReason.SUFFOCATION:
		fails.append(
			"same-tick o2 == 0 + habitat death gave %d/%d"
			% [sim.outcome, sim.outcome_reason]
		)


func _test_same_tick_hunger_lethal_and_o2_is_suffocation(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		_silence_raids(sim)
	var player := sim.get_player()
	if player == null:
		fails.append("same-tick hunger+o2 missing player")
		return
	player.pos = Vector2(20.5 * Constants.TILE, 20.5 * Constants.TILE)
	player.o2 = 0.0
	player.hp = 1
	player.inventory.remove(Types.ResourceKind.FOOD, player.inventory.food)
	sim.hunger_starving = true
	sim.tick_index = Constants.PLAYER_HUNGER_PULSE_TICKS - 1
	_tick_idle(sim, 1)
	if not sim.oxygen_failed:
		fails.append("same-tick hunger-lethal + o2 == 0 should set oxygen_failed")
	if sim.outcome != Types.Outcome.PLAYER_LOSE or sim.outcome_reason != Types.OutcomeReason.SUFFOCATION:
		fails.append(
			"same-tick hunger-lethal + o2 == 0 gave %d/%d"
			% [sim.outcome, sim.outcome_reason]
		)


func _test_place_workshop_and_lab(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WORKSHOP_COST + Constants.LAB_COST)
	if not Rules.try_place(world, null, Types.BuildingKind.WORKSHOP, _TILE):
		fails.append("try_place workshop should succeed on an empty tile")
		return
	var depot := world.building_at(2, 2)
	var after_shop := Constants.LAB_COST
	if depot.inventory.scrap != after_shop:
		fails.append("workshop left scrap %d, expected %d" % [depot.inventory.scrap, after_shop])
	var shop := world.building_at(_TILE.x, _TILE.y)
	if shop == null or shop.kind != Types.BuildingKind.WORKSHOP:
		fails.append("placed workshop missing from occupancy")
		return
	if shop.hp != Constants.WORKSHOP_HP or shop.hp_max != Constants.WORKSHOP_HP:
		fails.append("workshop hp is %d/%d" % [shop.hp, shop.hp_max])
	if shop.faction != Types.Faction.PLAYER:
		fails.append("workshop faction is %d" % shop.faction)
	if world.footprint_span(Types.BuildingKind.WORKSHOP) != 1:
		fails.append("workshop footprint should be 1x1")
	if not world.is_solid(_TILE.x, _TILE.y):
		fails.append("workshop tile should be solid")

	var lab_tile := Vector2i(12, 10)
	if not Rules.try_place(world, null, Types.BuildingKind.LAB, lab_tile):
		fails.append("try_place lab should succeed on an empty 2x2")
		return
	var after_lab := after_shop - Constants.LAB_COST
	if depot.inventory.scrap != after_lab:
		fails.append("lab left scrap %d, expected %d" % [depot.inventory.scrap, after_lab])
	var lab := world.building_at(lab_tile.x, lab_tile.y)
	if lab == null or lab.kind != Types.BuildingKind.LAB:
		fails.append("placed lab missing from occupancy")
		return
	if lab.hp != Constants.LAB_HP or lab.hp_max != Constants.LAB_HP:
		fails.append("lab hp is %d/%d" % [lab.hp, lab.hp_max])
	if World.footprint_span(Types.BuildingKind.LAB) != 2:
		fails.append("lab footprint should be 2x2")


func _test_lab_occupies_2x2(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.LAB_COST)
	var tile := Vector2i(14, 14)
	if not Rules.try_place(world, null, Types.BuildingKind.LAB, tile):
		fails.append("lab 2x2 place should succeed")
		return
	var lab := world.building_at(tile.x, tile.y)
	for dy in 2:
		for dx in 2:
			var at := Vector2i(tile.x + dx, tile.y + dy)
			if world.building_at(at.x, at.y) != lab:
				fails.append("lab does not occupy %s" % at)
			if world.is_walkable(at.x, at.y):
				fails.append("lab tile %s should not be walkable" % at)
	var blocked := Vector2i(20, 20)
	world.set_terrain(blocked.x + 1, blocked.y + 1, Types.TileTerrain.ROCK)
	if Rules.can_place(world, null, Types.BuildingKind.LAB, blocked):
		fails.append("lab should reject when one footprint tile is rock")


func _test_workshop_closer_wins_when_craftable(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WORKSHOP_COST)
	var depot := world.building_at(2, 2)
	var shop_tile := Vector2i(0, 2)
	if not Rules.try_place(world, null, Types.BuildingKind.WORKSHOP, shop_tile):
		fails.append("craftable test could not place a workshop")
		return
	var shop := world.building_at(shop_tile.x, shop_tile.y)
	var player := _player_at(world, Vector2(42, 80))
	player.inventory.add(Types.ResourceKind.SCRAP, Constants.WORKSHOP_SCRAP_COST)
	player.inventory.add(Types.ResourceKind.ORE, Constants.WORKSHOP_ORE_COST)
	var cmd := _interact_cmd()
	var sim := Sim.new()
	sim.world = world
	var locked := Rules.resolve_interact(world, player, cmd, 0, false, sim)
	if locked != depot.id:
		fails.append("locked recipe should keep the closer depot, got %d" % locked)
	if not Rules.workshop_can_craft(player, true):
		fails.append("full recipe + parts space should be craftable when unlocked")
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	var chosen := Rules.resolve_interact(world, player, cmd, 0, false, sim)
	if chosen != shop.id:
		fails.append("craftable closer workshop should win, got %d expected %d" % [chosen, shop.id])
	player.inventory.remove(Types.ResourceKind.ORE, Constants.WORKSHOP_ORE_COST)
	var missing := Rules.resolve_interact(world, player, cmd, 0, false, sim)
	if missing != depot.id:
		fails.append("workshop without the recipe should lose to the depot, got %d" % missing)
	player.inventory.add(Types.ResourceKind.ORE, Constants.WORKSHOP_ORE_COST)
	player.pos = Vector2(56, 80)
	var depot_closer := Rules.resolve_interact(world, player, cmd, 0, false, sim)
	if depot_closer != depot.id:
		fails.append("strictly closer depot should still win, got %d" % depot_closer)


func _test_workshop_overlap_crafts_not_deposit(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.WORKSHOP_COST)
	var depot := world.building_at(2, 2)
	var shop_tile := Vector2i(0, 2)
	if not Rules.try_place(world, null, Types.BuildingKind.WORKSHOP, shop_tile):
		fails.append("overlap craft test could not place a workshop")
		return
	var shop := world.building_at(shop_tile.x, shop_tile.y)
	var player := _player_at(world, Vector2(42, 80))
	player.inventory.add(Types.ResourceKind.SCRAP, Constants.WORKSHOP_SCRAP_COST)
	player.inventory.add(Types.ResourceKind.ORE, Constants.WORKSHOP_ORE_COST)
	var cmd := _interact_cmd()
	var sim := Sim.new()
	sim.world = world
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	var depot_scrap := depot.inventory.scrap
	var depot_ore := depot.inventory.ore
	var depot_parts := depot.inventory.parts
	var last := 0
	var ticks := int(Constants.WORKSHOP_CRAFT_CHANNEL / Constants.SIM_DT) - 1
	for _i in ticks:
		last = Rules.resolve_interact(world, player, cmd, last, false, sim)
		if last != shop.id:
			fails.append("overlap channel targeted %d, expected workshop %d" % [last, shop.id])
			return
	if player.inventory.scrap != Constants.WORKSHOP_SCRAP_COST or player.inventory.ore != Constants.WORKSHOP_ORE_COST:
		fails.append("overlap deposited before the craft channel finished")
	if player.inventory.parts != 0:
		fails.append("overlap crafted before one WORKSHOP_CRAFT_CHANNEL")
	if depot.inventory.scrap != depot_scrap or depot.inventory.ore != depot_ore or depot.inventory.parts != depot_parts:
		fails.append("overlap changed depot stock during the craft channel")
	last = Rules.resolve_interact(world, player, cmd, last, false, sim)
	if last != shop.id:
		fails.append("overlap complete tick targeted %d, expected workshop %d" % [last, shop.id])
	if player.inventory.scrap != 0 or player.inventory.ore != 0:
		fails.append(
			"overlap craft left carry scrap/ore %d/%d, expected 0/0"
			% [player.inventory.scrap, player.inventory.ore]
		)
	if player.inventory.parts != Constants.WORKSHOP_PARTS_OUT:
		fails.append("overlap craft parts is %d, expected %d" % [player.inventory.parts, Constants.WORKSHOP_PARTS_OUT])
	if depot.inventory.scrap != depot_scrap or depot.inventory.ore != depot_ore or depot.inventory.parts != depot_parts:
		fails.append("overlap craft deposited into the depot")


func _test_lab_closer_wins_when_research_selected(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.LAB_COST)
	var depot := world.building_at(2, 2)
	if not Rules.try_place(world, null, Types.BuildingKind.LAB, Vector2i(0, 0)):
		fails.append("lab closer test could not place a lab")
		return
	var lab := world.building_at(0, 0)
	var player := _player_at(world, Vector2(40, 80))
	var cmd := _interact_cmd()
	var sim := Sim.new()
	sim.world = world
	var no_sel := Rules.resolve_interact(world, player, cmd, 0, false, sim)
	if no_sel != depot.id:
		fails.append("lab without a selected tech should lose to the depot, got %d" % no_sel)
	Research.select(sim, Types.TechKind.HYDROPONICS)
	var chosen := Rules.resolve_interact(world, player, cmd, 0, false, sim)
	if chosen != lab.id:
		fails.append("selected research should let a closer lab win, got %d expected %d" % [chosen, lab.id])
	player.pos = Vector2(80, 136)
	var depot_closer := Rules.resolve_interact(world, player, cmd, 0, false, sim)
	if depot_closer != depot.id:
		fails.append("strictly closer depot should still beat the lab, got %d" % depot_closer)


func _test_locked_buildings_not_placeable(fails: PackedStringArray) -> void:
	var world := _world_with_depot(50)
	var sim := Sim.new()
	sim.world = world
	if Research.building_unlocked(sim, Types.BuildingKind.FARM):
		fails.append("Farm should start locked")
	if Research.building_unlocked(sim, Types.BuildingKind.GATE):
		fails.append("Gate should start locked")
	if Research.building_unlocked(sim, Types.BuildingKind.MEDBAY):
		fails.append("Medbay should start locked")
	if Rules.can_place(world, sim, Types.BuildingKind.FARM, _TILE):
		fails.append("locked Farm should not be placeable")
	if not Research.building_unlocked(sim, Types.BuildingKind.WALL):
		fails.append("Wall should start unlocked")
	if not Research.building_unlocked(sim, Types.BuildingKind.LAB):
		fails.append("Lab should start unlocked")
	if not Research.building_unlocked(sim, Types.BuildingKind.HABITAT):
		fails.append("Habitat should start unlocked")
	if not Research.building_unlocked(sim, Types.BuildingKind.DEPOT):
		fails.append("Depot should start unlocked")
	Research.mark_complete(sim, Types.TechKind.HYDROPONICS)
	if not Research.building_unlocked(sim, Types.BuildingKind.FARM):
		fails.append("Hydroponics should unlock Farm")
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	if not Research.building_unlocked(sim, Types.BuildingKind.GATE):
		fails.append("Metallurgy should unlock Gate")
	if not Research.workshop_unlocked(sim):
		fails.append("Metallurgy should unlock the workshop recipe flag")
	Research.mark_complete(sim, Types.TechKind.FIELD_MEDICINE)
	if not Research.building_unlocked(sim, Types.BuildingKind.MEDBAY):
		fails.append("Field Medicine should unlock Medbay")


func _test_player_slides_onto_gate_raider_blocked(fails: PackedStringArray) -> void:
	var world := World.new()
	var tile := Vector2i(10, 10)
	var gate := _place_gate(world, tile)
	var sim := Sim.new()
	sim.world = world
	var start := Vector2(float(tile.x * Constants.TILE) - Constants.PLAYER_RADIUS, world.tile_center(tile.x, tile.y).y)
	var vel := Vector2(Constants.PLAYER_SPEED, 0.0)
	var player := _player_at(world, start)
	player.vel = vel
	var raider := Unit.new()
	raider.id = world.alloc_id()
	raider.kind = Types.UnitKind.RAIDER
	raider.faction = Types.Faction.ENEMY
	raider.pos = start
	raider.radius = Constants.RAIDER_RADIUS
	raider.alive = true
	raider.vel = vel
	world.units[raider.id] = raider
	if world.blocks_movement(tile.x, tile.y, player):
		fails.append("blocks_movement should let the player occupy a Gate")
	if not world.blocks_movement(tile.x, tile.y, raider):
		fails.append("blocks_movement should keep a raider out of a Gate")
	sim._integrate_unit(player)
	sim._integrate_unit(raider)
	sim._integrate_unit(player)
	sim._integrate_unit(raider)
	var aabb := world.footprint_aabb(gate)
	if world.world_to_tile(player.pos) != tile:
		fails.append("player should slide onto the Gate tile, pos=%s" % player.pos)
	if world.point_aabb_distance(player.pos, aabb) > player.radius:
		fails.append("player should overlap the Gate after sliding")
	if world.world_to_tile(raider.pos) == tile:
		fails.append("raider with the same velocity entered the Gate tile")
	if world.point_aabb_distance(raider.pos, aabb) < raider.radius:
		fails.append("raider should be blocked by the Gate")


func _place_gate(world: World, tile: Vector2i) -> Building:
	var gate := Building.new()
	gate.id = world.alloc_id()
	gate.kind = Types.BuildingKind.GATE
	gate.faction = Types.Faction.PLAYER
	gate.origin_tile = tile
	gate.hp = Constants.GATE_HP
	gate.hp_max = Constants.GATE_HP
	world.buildings[gate.id] = gate
	world.occupy(gate)
	return gate


func _test_place_farm_after_hydroponics(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var world := sim.world
	var depot := _player_depot(world)
	if depot == null:
		fails.append("farm place missing depot")
		return
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.FARM_COST_SCRAP)
	var tile := _first_placeable(world, Types.BuildingKind.FARM, sim)
	if tile.x >= 0:
		fails.append("Farm should not be placeable before Hydroponics")
	Research.mark_complete(sim, Types.TechKind.HYDROPONICS)
	tile = _first_placeable(world, Types.BuildingKind.FARM, sim)
	if tile.x < 0:
		fails.append("no placeable farm tile after Hydroponics")
		return
	if not Rules.try_place(world, sim, Types.BuildingKind.FARM, tile):
		fails.append("try_place farm should succeed after Hydroponics")
		return
	var farm := world.building_at(tile.x, tile.y)
	if farm == null or farm.kind != Types.BuildingKind.FARM:
		fails.append("placed farm missing from occupancy")
		return
	if farm.hp != Constants.FARM_HP or farm.food_stock != 0:
		fails.append("farm hp/stock is %d/%d" % [farm.hp, farm.food_stock])
	if world.footprint_span(Types.BuildingKind.FARM) != 2:
		fails.append("farm footprint should be 2x2")
	if world.building_at(tile.x + 1, tile.y + 1) != farm:
		fails.append("farm should occupy 2x2")


func _test_farm_harvest_transfer(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		_silence_raids(sim)
	var player := sim.get_player()
	var depot := _player_depot(sim.world)
	if player == null or depot == null:
		fails.append("farm harvest missing player or depot")
		return
	Research.mark_complete(sim, Types.TechKind.HYDROPONICS)
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.FARM_COST_SCRAP)
	var tile := _first_placeable(sim.world, Types.BuildingKind.FARM, sim)
	if tile.x < 0 or not Rules.try_place(sim.world, sim, Types.BuildingKind.FARM, tile):
		fails.append("farm harvest could not place a farm")
		return
	var farm := sim.world.building_at(tile.x, tile.y)
	player.inventory.remove(Types.ResourceKind.FOOD, player.inventory.food)
	farm.food_stock = 8
	_stand_beside(player, sim.world, farm)
	_hold_interact(sim, 4)
	if player.inventory.food != Constants.TRANSFER_BATCH:
		fails.append("farm harvest food is %d, expected %d" % [player.inventory.food, Constants.TRANSFER_BATCH])
	if farm.food_stock != 8 - Constants.TRANSFER_BATCH:
		fails.append("farm stock after harvest is %d" % farm.food_stock)


func _test_hunger_is_not_a_lose(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		_silence_raids(sim)
	var player := sim.get_player()
	if player == null:
		fails.append("hunger latch missing player")
		return
	player.inventory.remove(Types.ResourceKind.FOOD, player.inventory.food)
	_tick_idle(sim, _ticks_for(Constants.FOOD_EAT_PERIOD))
	if not sim.hunger_starving:
		fails.append("missed meal should set hunger_starving")
	if sim.outcome != Types.Outcome.NONE:
		fails.append("missed meal outcome is %d/%d, expected NONE" % [sim.outcome, sim.outcome_reason])


func _test_depot_skips_food(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		_silence_raids(sim)
	var player := sim.get_player()
	var depot := _player_depot(sim.world)
	if player == null or depot == null:
		fails.append("food-skip setup missing player or depot")
		return
	var carry_food := player.inventory.food
	player.inventory.add(Types.ResourceKind.SCRAP, 5)
	_stand_beside(player, sim.world, depot)
	_hold_interact(sim, 4)
	if player.inventory.food != carry_food:
		fails.append("own-depot dump moved food %d -> %d" % [carry_food, player.inventory.food])
	if depot.inventory.food != 0:
		fails.append("own-depot dump stored food %d" % depot.inventory.food)
	depot.inventory.food = 8
	_hold_withdraw(sim, 4)
	if player.inventory.food != carry_food:
		fails.append("own-depot withdraw moved food to carry %d" % player.inventory.food)
	if depot.inventory.food != 8:
		fails.append("own-depot withdraw pulled food from depot")

	var world := World.new()
	var enemy := Building.new()
	enemy.id = world.alloc_id()
	enemy.kind = Types.BuildingKind.DEPOT
	enemy.faction = Types.Faction.ENEMY
	enemy.origin_tile = Vector2i(2, 2)
	enemy.hp = Constants.DEPOT_HP
	enemy.hp_max = Constants.DEPOT_HP
	enemy.inventory = Inventory.new(
		Constants.DEPOT_CAP_SCRAP,
		Constants.DEPOT_CAP_ICE,
		Constants.DEPOT_CAP_ORE,
		Constants.DEPOT_CAP_PARTS,
		Constants.DEPOT_CAP_FOOD
	)
	enemy.inventory.add(Types.ResourceKind.SCRAP, 9)
	enemy.inventory.food = 6
	world.buildings[enemy.id] = enemy
	world.occupy(enemy)
	var thief := _player_at(world, world.tile_center(1, 2))
	thief.inventory.add(Types.ResourceKind.FOOD, 3)
	var cmd := _interact_cmd()
	var last := 0
	var ticks := int(Constants.TRANSFER_PERIOD / Constants.SIM_DT)
	for _i in ticks:
		last = Rules.resolve_interact(world, thief, cmd, last)
	if thief.inventory.food != 3:
		fails.append("steal moved food to carry %d" % thief.inventory.food)
	if enemy.inventory.food != 6:
		fails.append("steal took food from enemy depot")
	if thief.inventory.scrap != Constants.TRANSFER_BATCH:
		fails.append("steal should still move scrap, got %d" % thief.inventory.scrap)


func _test_two_depots_share_scrap(fails: PackedStringArray) -> void:
	var world := _world_with_depot(8)
	var depot_a := world.building_at(2, 2)
	var depot_b := Building.new()
	depot_b.id = world.alloc_id()
	depot_b.kind = Types.BuildingKind.DEPOT
	depot_b.faction = Types.Faction.PLAYER
	depot_b.origin_tile = Vector2i(6, 2)
	depot_b.hp = Constants.DEPOT_HP
	depot_b.hp_max = Constants.DEPOT_HP
	depot_b.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
	depot_b.inventory.add(Types.ResourceKind.SCRAP, 7)
	world.buildings[depot_b.id] = depot_b
	world.occupy(depot_b)
	if depot_a.id >= depot_b.id:
		fails.append("two-depot test expected first depot to have the lower id")
		return
	if Rules.player_pool_amount(world, Types.ResourceKind.SCRAP) != 15:
		fails.append(
			"scrap pool is %d, expected 15"
			% Rules.player_pool_amount(world, Types.ResourceKind.SCRAP)
		)
	if not Rules.pay_player(world, {Types.ResourceKind.SCRAP: 10}):
		fails.append("pay_player scrap 10 across two depots should succeed")
		return
	if depot_a.inventory.scrap != 0:
		fails.append("lowest-id depot scrap is %d, expected 0" % depot_a.inventory.scrap)
	if depot_b.inventory.scrap != 5:
		fails.append("second depot scrap is %d, expected 5" % depot_b.inventory.scrap)


func _test_place_habitat_and_depot(fails: PackedStringArray) -> void:
	var habitat_cost := Rules.cost(Types.BuildingKind.HABITAT)
	if (
		habitat_cost.size() != 1
		or int(habitat_cost.get(Types.ResourceKind.SCRAP, -1)) != Constants.HABITAT_COST_SCRAP
	):
		fails.append("Habitat cost should be scrap only at HABITAT_COST_SCRAP")
	var depot_cost := Rules.cost(Types.BuildingKind.DEPOT)
	if (
		depot_cost.size() != 1
		or int(depot_cost.get(Types.ResourceKind.SCRAP, -1)) != Constants.DEPOT_COST_SCRAP
	):
		fails.append("Depot cost should be scrap only at DEPOT_COST_SCRAP")

	var world := _world_with_depot(Constants.HABITAT_COST_SCRAP + Constants.DEPOT_COST_SCRAP)
	var depot := world.building_at(2, 2)
	var habitat_tile := Vector2i(10, 10)
	if not Rules.try_place(world, null, Types.BuildingKind.HABITAT, habitat_tile):
		fails.append("try_place Habitat should succeed from the depot pool")
		return
	if depot.inventory.scrap != Constants.DEPOT_COST_SCRAP:
		fails.append(
			"pool Habitat left scrap %d, expected %d"
			% [depot.inventory.scrap, Constants.DEPOT_COST_SCRAP]
		)
	var habitat := world.building_at(habitat_tile.x, habitat_tile.y)
	if habitat == null or habitat.kind != Types.BuildingKind.HABITAT:
		fails.append("placed Habitat missing from occupancy")
		return
	if habitat.hp != Constants.HABITAT_HP or habitat.hp_max != Constants.HABITAT_HP:
		fails.append("Habitat hp is %d/%d" % [habitat.hp, habitat.hp_max])
	if habitat.inventory == null or habitat.inventory.cap_ice != Constants.HABITAT_CAP_ICE:
		fails.append("try_place Habitat should set HABITAT_CAP_ICE")
	if habitat.inventory.ice != Constants.LAST_HABITAT_ICE:
		fails.append(
			"only living Habitat ice is %d, expected LAST_HABITAT_ICE"
			% habitat.inventory.ice
		)
	for dy in 2:
		for dx in 2:
			var at := Vector2i(habitat_tile.x + dx, habitat_tile.y + dy)
			if world.building_at(at.x, at.y) != habitat:
				fails.append("Habitat does not occupy %s" % at)

	var extra := Constants.HABITAT_COST_SCRAP
	depot.inventory.add(Types.ResourceKind.SCRAP, extra)
	var second_tile := Vector2i(14, 10)
	if not Rules.try_place(world, null, Types.BuildingKind.HABITAT, second_tile):
		fails.append("try_place second Habitat should succeed from the depot pool")
		return
	var second := world.building_at(second_tile.x, second_tile.y)
	if second == null or second.inventory == null or second.inventory.ice != 0:
		fails.append("second Habitat ice should be 0 when another Habitat lives")

	var depot_tile := Vector2i(18, 10)
	var scrap_before := depot.inventory.scrap
	if not Rules.try_place(world, null, Types.BuildingKind.DEPOT, depot_tile):
		fails.append("try_place Depot should succeed from the depot pool")
		return
	if depot.inventory.scrap != scrap_before - Constants.DEPOT_COST_SCRAP:
		fails.append(
			"pool Depot left scrap %d, expected %d"
			% [depot.inventory.scrap, scrap_before - Constants.DEPOT_COST_SCRAP]
		)
	var placed_depot := world.building_at(depot_tile.x, depot_tile.y)
	if placed_depot == null or placed_depot.kind != Types.BuildingKind.DEPOT:
		fails.append("placed Depot missing from occupancy")
		return
	if placed_depot.inventory == null or placed_depot.inventory.cap_ice != 0:
		fails.append("try_place Depot should set cap_ice == 0")
	if (
		placed_depot.inventory.scrap != 0
		or placed_depot.inventory.ore != 0
		or placed_depot.inventory.parts != 0
	):
		fails.append("new Depot should start empty")
	for dy in 2:
		for dx in 2:
			var dep_at := Vector2i(depot_tile.x + dx, depot_tile.y + dy)
			if world.building_at(dep_at.x, dep_at.y) != placed_depot:
				fails.append("Depot does not occupy %s" % dep_at)

	var blocked := Vector2i(22, 10)
	world.set_terrain(blocked.x + 1, blocked.y + 1, Types.TileTerrain.ROCK)
	if Rules.can_place(world, null, Types.BuildingKind.HABITAT, blocked):
		fails.append("Habitat should reject when one footprint tile is rock")
	if Rules.can_place(world, null, Types.BuildingKind.DEPOT, blocked):
		fails.append("Depot should reject when one footprint tile is rock")


func _test_last_pad_recovery(fails: PackedStringArray) -> void:
	var world := World.new()
	var player := _player_at(world, world.tile_center(0, 0))
	player.inventory.add(Types.ResourceKind.SCRAP, Constants.LAST_PAD_HABITAT_SCRAP)
	var habitat_tile := Vector2i(4, 4)
	if not Rules.can_place(world, null, Types.BuildingKind.HABITAT, habitat_tile):
		fails.append("0 Habitat 0 Depot + 10 carry should allow last-pad Habitat")
	if not Rules.try_place(world, null, Types.BuildingKind.HABITAT, habitat_tile):
		fails.append("last-pad Habitat place should succeed")
		return
	if player.inventory.scrap != 0:
		fails.append("last-pad Habitat should charge carry, leftover %d" % player.inventory.scrap)
	var habitat := world.building_at(habitat_tile.x, habitat_tile.y)
	if habitat == null:
		fails.append("last-pad Habitat missing")
		return
	if habitat.inventory == null or habitat.inventory.ice != Constants.LAST_HABITAT_ICE:
		fails.append("last-pad Habitat ice is not LAST_HABITAT_ICE")
	if not Rules.habitat_gives_o2(habitat):
		fails.append("last-pad Habitat should give O2 the same tick")

	player.inventory.add(Types.ResourceKind.SCRAP, Constants.LAST_PAD_DEPOT_SCRAP)
	var depot_tile := Vector2i(8, 4)
	if not Rules.try_place(world, null, Types.BuildingKind.DEPOT, depot_tile):
		fails.append("last-pad Depot place should succeed")
		return
	if player.inventory.scrap != 0:
		fails.append("last-pad Depot should charge carry, leftover %d" % player.inventory.scrap)
	var depot := world.building_at(depot_tile.x, depot_tile.y)
	if depot == null or depot.inventory == null or depot.inventory.cap_ice != 0:
		fails.append("last-pad Depot should have cap_ice == 0")

	player.inventory.add(Types.ResourceKind.SCRAP, Constants.PLAYER_CARRY_SCRAP)
	if Rules.can_place(world, null, Types.BuildingKind.HABITAT, Vector2i(12, 4)):
		fails.append("a full pack cannot pay the pool Habitat cost 20")
	if Rules.try_place(world, null, Types.BuildingKind.HABITAT, Vector2i(12, 4)):
		fails.append("pool Habitat must not charge carry")
	if player.inventory.scrap != Constants.PLAYER_CARRY_SCRAP:
		fails.append("failed pool Habitat place changed carry")

	if Rules.can_place(world, null, Types.BuildingKind.WALL, Vector2i(16, 4)):
		fails.append("walls must not last-pad from carry")


func _test_last_depot_zero_scrap_spills_floor(fails: PackedStringArray) -> void:
	var world := World.new()
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Vector2i(10, 10)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	Combat.apply_damage(depot, Constants.DEPOT_HP)
	Combat.process_deaths(world)
	if world.loot.size() != 1:
		fails.append("last Depot 0-scrap spill piles: %d, expected 1" % world.loot.size())
		return
	var pile: Loot = world.loot.values()[0]
	if pile.inventory.scrap != Constants.LAST_DEPOT_SCRAP:
		fails.append(
			"last Depot 0-scrap spill is %d, expected LAST_DEPOT_SCRAP"
			% pile.inventory.scrap
		)

	var extra := Building.new()
	extra.id = world.alloc_id()
	extra.kind = Types.BuildingKind.DEPOT
	extra.faction = Types.Faction.PLAYER
	extra.origin_tile = Vector2i(14, 10)
	extra.hp = Constants.DEPOT_HP
	extra.hp_max = Constants.DEPOT_HP
	extra.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
	world.buildings[extra.id] = extra
	world.occupy(extra)
	var other := Building.new()
	other.id = world.alloc_id()
	other.kind = Types.BuildingKind.DEPOT
	other.faction = Types.Faction.PLAYER
	other.origin_tile = Vector2i(18, 10)
	other.hp = Constants.DEPOT_HP
	other.hp_max = Constants.DEPOT_HP
	other.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
	world.buildings[other.id] = other
	world.occupy(other)
	var before := world.loot.size()
	Combat.apply_damage(extra, Constants.DEPOT_HP)
	Combat.process_deaths(world)
	if world.loot.size() != before:
		fails.append("non-last 0-scrap Depot should not spill LAST_DEPOT_SCRAP")


func _never_aggro_camp(sim: Sim) -> World.Camp:
	var habitat := _faction_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	var habitat_tile := habitat.origin_tile if habitat != null else Constants.PLAYER_HABITAT_TILE
	var player_tile := Constants.PLAYER_SPAWN_TILE
	var player := sim.get_player()
	if player != null:
		player_tile = sim.world.world_to_tile(player.pos)
	for raw in sim.world.camps:
		var camp := raw as World.Camp
		if camp == null:
			continue
		var d_player := maxi(
			absi(camp.depot_tile.x - player_tile.x),
			absi(camp.depot_tile.y - player_tile.y)
		)
		var d_hab := maxi(
			absi(camp.depot_tile.x - habitat_tile.x),
			absi(camp.depot_tile.y - habitat_tile.y)
		)
		if d_player > Constants.CAMP_AGGRO_TILES and d_hab > Constants.CAMP_AGGRO_TILES:
			return camp
	return null


func _silence_raids(sim: Sim) -> void:
	if sim == null or sim.world == null:
		return
	for raw in sim.world.camps:
		var camp := raw as World.Camp
		if camp != null:
			camp.next_raid_at = 1.0e9


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
	var tile := _adjacent_walkable(world, building)
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.vel = Vector2.ZERO


func _adjacent_walkable(world: World, building: Building) -> Vector2i:
	var span := world.footprint_span(building.kind)
	var o := building.origin_tile
	var candidates: Array[Vector2i] = [
		Vector2i(o.x + span, o.y),
		Vector2i(o.x + span, o.y + span - 1),
		Vector2i(o.x, o.y + span),
		Vector2i(o.x + span - 1, o.y + span),
		Vector2i(o.x - 1, o.y),
		Vector2i(o.x, o.y - 1),
	]
	for tile in candidates:
		if world.is_walkable(tile.x, tile.y):
			return tile
	return Vector2i(o.x + span, o.y)


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
	depot.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
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
			if world.in_enemy_camp_rect(Vector2i(x, y)):
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


func _first_placeable(world: World, kind: int, sim: Sim = null) -> Vector2i:
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var tile := Vector2i(x, y)
			if Rules.can_place(world, sim, kind, tile):
				return tile
	return Vector2i(-1, -1)
