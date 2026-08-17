extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_start_carry_food(fails)
	_test_farm_grows_to_cap(fails)
	_test_harvest_batch(fails)
	_test_farm_death_does_not_spill(fails)
	_test_farm_not_depot(fails)
	_test_eats_one_per_period(fails)
	_test_missed_meal_loses(fails)
	_test_depot_dump_leaves_carry_food(fails)
	return fails


func _test_start_carry_food(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var player := sim.get_player()
	if player == null or player.inventory == null:
		fails.append("setup missing player inventory")
		return
	if player.inventory.food != Constants.START_PLAYER_FOOD:
		fails.append(
			"start carry food is %d, expected %d"
			% [player.inventory.food, Constants.START_PLAYER_FOOD]
		)
	if player.inventory.cap_food != Constants.PLAYER_CARRY_FOOD:
		fails.append("player food cap is %d" % player.inventory.cap_food)
	var snap := sim.snapshot()
	var rec := {}
	for unit in snap.units:
		if int(unit.get("kind", -1)) == Types.UnitKind.PLAYER:
			rec = unit
			break
	var inv: Variant = rec.get("inventory", {})
	if not inv is Dictionary or int(inv.get("food", -1)) != Constants.START_PLAYER_FOOD:
		fails.append("snapshot start food is %s" % str(inv.get("food") if inv is Dictionary else inv))


func _test_farm_grows_to_cap(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var player := sim.get_player()
	if player != null and player.inventory != null:
		player.inventory.add(Types.ResourceKind.FOOD, player.inventory.cap_food)
	var farm := _place_farm(sim)
	if farm == null:
		fails.append("could not place a farm")
		return
	if farm.food_stock != 0:
		fails.append("new farm stock is %d, expected 0" % farm.food_stock)
	farm.food_grow_timer = Constants.FARM_GROW_PERIOD - Constants.SIM_DT
	_tick(sim, 1)
	if farm.food_stock != 1:
		fails.append("farm stock after one period is %d, expected 1" % farm.food_stock)
	farm.food_stock = Constants.FARM_FOOD_CAP - 1
	farm.food_grow_timer = Constants.FARM_GROW_PERIOD - Constants.SIM_DT
	_tick(sim, 1)
	if farm.food_stock != Constants.FARM_FOOD_CAP:
		fails.append("farm stock at cap is %d, expected %d" % [farm.food_stock, Constants.FARM_FOOD_CAP])
	_tick(sim, _ticks_for(Constants.FARM_GROW_PERIOD))
	if farm.food_stock != Constants.FARM_FOOD_CAP:
		fails.append("farm grew past cap to %d" % farm.food_stock)


func _test_harvest_batch(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var player := sim.get_player()
	var farm := _place_farm(sim)
	if player == null or farm == null:
		fails.append("harvest setup missing player or farm")
		return
	player.inventory.remove(Types.ResourceKind.FOOD, player.inventory.food)
	farm.food_stock = 12
	_stand_beside(player, sim.world, farm)
	_hold_interact(sim, 3)
	if player.inventory.food != 0 or farm.food_stock != 12:
		fails.append("farm harvest ran before one TRANSFER_PERIOD")
	_hold_interact(sim, 1)
	if player.inventory.food != Constants.TRANSFER_BATCH:
		fails.append("harvested food is %d, expected %d" % [player.inventory.food, Constants.TRANSFER_BATCH])
	if farm.food_stock != 12 - Constants.TRANSFER_BATCH:
		fails.append("farm stock after harvest is %d" % farm.food_stock)


func _test_farm_death_does_not_spill(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var farm := _place_farm(sim)
	if farm == null:
		fails.append("spill test missing farm")
		return
	farm.food_stock = Constants.FARM_FOOD_CAP
	var before := sim.world.loot.size()
	Combat.apply_damage(farm, farm.hp)
	Combat.process_deaths(sim.world)
	if sim.world.buildings.has(farm.id):
		fails.append("dead farm remained in world.buildings")
	if sim.world.loot.size() != before:
		fails.append("destroying a farm spilled loot")


func _test_farm_not_depot(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var player := sim.get_player()
	var farm := _place_farm(sim)
	if player == null or farm == null:
		fails.append("depot-check missing player or farm")
		return
	player.inventory.remove(Types.ResourceKind.FOOD, player.inventory.food)
	player.inventory.add(Types.ResourceKind.SCRAP, 5)
	player.inventory.add(Types.ResourceKind.ICE, 5)
	farm.food_stock = 0
	_stand_beside(player, sim.world, farm)
	_hold_interact(sim, 4)
	if player.inventory.scrap != 5 or player.inventory.ice != 5:
		fails.append("farm accepted scrap/ice as a depot")
	if farm.inventory.scrap != 0 or farm.inventory.ice != 0:
		fails.append("farm inventory took depot stock")


func _test_eats_one_per_period(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var player := sim.get_player()
	if player == null:
		fails.append("eat test missing player")
		return
	var start := player.inventory.food
	_tick(sim, _ticks_for(Constants.FOOD_EAT_PERIOD) - 1)
	if player.inventory.food != start:
		fails.append("player ate before one FOOD_EAT_PERIOD")
	_tick(sim, 1)
	if player.inventory.food != start - 1:
		fails.append("player food after 15s is %d, expected %d" % [player.inventory.food, start - 1])
	if sim.hunger_failed or sim.outcome != Types.Outcome.NONE:
		fails.append("eating a meal should not lose")


func _test_missed_meal_loses(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var player := sim.get_player()
	if player == null:
		fails.append("hunger lose missing player")
		return
	player.inventory.remove(Types.ResourceKind.FOOD, player.inventory.food)
	_tick(sim, _ticks_for(Constants.FOOD_EAT_PERIOD))
	if not sim.hunger_failed:
		fails.append("missed meal should set hunger_failed")
	if sim.outcome != Types.Outcome.PLAYER_LOSE or sim.outcome_reason != Types.OutcomeReason.HUNGER:
		fails.append(
			"missed meal outcome is %d/%d"
			% [sim.outcome, sim.outcome_reason]
		)
	var alive := player.alive
	_tick(sim, _ticks_for(Constants.PLAYER_RESPAWN) + 2)
	if sim.outcome != Types.Outcome.PLAYER_LOSE:
		fails.append("hunger lose should stay locked")
	if player.alive != alive and player.alive:
		fails.append("hunger lose should not respawn")


func _test_depot_dump_leaves_carry_food(fails: PackedStringArray) -> void:
	var sim := _quiet()
	var player := sim.get_player()
	var depot := _player_depot(sim.world)
	if player == null or depot == null or player.inventory == null or depot.inventory == null:
		fails.append("dump test missing player or depot")
		return
	if depot.inventory.cap_food != 0 or Constants.DEPOT_CAP_FOOD != 0:
		fails.append(
			"depot cap_food is %d / DEPOT_CAP_FOOD %d, expected 0"
			% [depot.inventory.cap_food, Constants.DEPOT_CAP_FOOD]
		)
	var start := player.inventory.food
	if start <= 0:
		fails.append("start carry food is %d, expected dinner" % start)
		return
	player.inventory.add(Types.ResourceKind.SCRAP, 5)
	_stand_beside(player, sim.world, depot)
	_hold_interact(sim, 4)
	if player.inventory.food != start:
		fails.append("depot dump changed carry food %d -> %d" % [start, player.inventory.food])
	if depot.inventory.food != 0:
		fails.append("depot stored food %d" % depot.inventory.food)
	if player.inventory.scrap != 0:
		fails.append("dump should still move scrap, leftover %d" % player.inventory.scrap)


func _quiet() -> Sim:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		sim.director.next_wave_at = 1.0e9
	return sim


func _place_farm(sim: Sim) -> Building:
	Research.mark_complete(sim, Types.TechKind.HYDROPONICS)
	var depot := _player_depot(sim.world)
	if depot == null or depot.inventory == null:
		return null
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.FARM_COST_SCRAP)
	depot.inventory.add(Types.ResourceKind.ICE, Constants.FARM_COST_ICE)
	var tile := Vector2i(14, 50)
	if not Rules.try_place(sim.world, sim, Types.BuildingKind.FARM, tile):
		for y in range(46, 62):
			for x in range(2, 20):
				tile = Vector2i(x, y)
				if Rules.try_place(sim.world, sim, Types.BuildingKind.FARM, tile):
					return sim.world.building_at(tile.x, tile.y)
		return null
	return sim.world.building_at(tile.x, tile.y)


func _player_depot(world: World) -> Building:
	for building in world.buildings.values():
		if building.kind == Types.BuildingKind.DEPOT and building.faction == Types.Faction.PLAYER:
			return building
	return null


func _stand_beside(unit: Unit, world: World, building: Building) -> void:
	var tile := Vector2i(building.origin_tile.x - 1, building.origin_tile.y)
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.vel = Vector2.ZERO


func _hold_interact(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		var cmd := InputCommand.new()
		cmd.interact = true
		sim.enqueue(cmd)
		sim.tick()


func _tick(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.tick()


func _ticks_for(seconds: float) -> int:
	return int(round(seconds / Constants.SIM_DT))
