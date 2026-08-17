extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_craft_locked_before_metallurgy(fails)
	_test_craft_channel_produces_parts(fails)
	_test_walk_away_resets_craft(fails)
	_test_missing_inputs_reset_craft(fails)
	_test_no_parts_space_does_not_consume(fails)
	_test_withdraw_leftover_then_craft(fails)
	_test_panel_recipe_and_lock(fails)
	return fails


func _test_craft_locked_before_metallurgy(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var shop := _place_isolated_workshop(sim)
	var player := sim.get_player()
	if shop == null or player == null:
		fails.append("locked craft setup missing workshop/player")
		return
	_stand_beside(player, sim.world, shop)
	_give_recipe(player)
	_hold_interact(sim, _craft_ticks())
	if player.inventory.parts != 0:
		fails.append("craft must not run before Metallurgy")
	if player.inventory.scrap != Constants.WORKSHOP_SCRAP_COST:
		fails.append("locked craft consumed scrap")
	if player.inventory.ore != Constants.WORKSHOP_ORE_COST:
		fails.append("locked craft consumed ore")


func _test_craft_channel_produces_parts(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var shop := _place_isolated_workshop(sim)
	var player := sim.get_player()
	if shop == null or player == null:
		fails.append("craft channel setup missing workshop/player")
		return
	_stand_beside(player, sim.world, shop)
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	_give_recipe(player)
	_hold_interact(sim, _craft_ticks() - 1)
	if player.inventory.parts != 0:
		fails.append("craft finished before one WORKSHOP_CRAFT_CHANNEL")
	if player.inventory.scrap != Constants.WORKSHOP_SCRAP_COST or player.inventory.ore != Constants.WORKSHOP_ORE_COST:
		fails.append("craft consumed inputs before the channel finished")
	_hold_interact(sim, 1)
	if player.inventory.parts != Constants.WORKSHOP_PARTS_OUT:
		fails.append("craft parts is %d, expected %d" % [player.inventory.parts, Constants.WORKSHOP_PARTS_OUT])
	if player.inventory.scrap != 0 or player.inventory.ore != 0:
		fails.append(
			"craft left carry scrap/ore %d/%d, expected 0/0"
			% [player.inventory.scrap, player.inventory.ore]
		)
	if player.interact_progress != 0.0:
		fails.append("craft should reset interact_progress")


func _test_walk_away_resets_craft(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var shop := _place_isolated_workshop(sim)
	var player := sim.get_player()
	if shop == null or player == null:
		fails.append("walk-away craft setup missing workshop/player")
		return
	_stand_beside(player, sim.world, shop)
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	_give_recipe(player)
	_hold_interact(sim, _craft_ticks() - 2)
	if player.interact_progress <= 0.0:
		fails.append("expected craft progress before walking")
		return
	for _i in 3:
		var walk := InputCommand.new()
		walk.interact = true
		walk.move = Vector2.RIGHT
		sim.enqueue(walk)
		sim.tick()
	if player.interact_progress != 0.0:
		fails.append("walking away should reset craft progress")
	if player.inventory.parts != 0:
		fails.append("walking away must not complete a craft")
	_stand_beside(player, sim.world, shop)
	_hold_interact(sim, _craft_ticks() - 1)
	if player.inventory.parts != 0:
		fails.append("resumed craft used leftover progress after a walk")
	_hold_interact(sim, 1)
	if player.inventory.parts != Constants.WORKSHOP_PARTS_OUT:
		fails.append("resumed craft should finish a full channel")


func _test_missing_inputs_reset_craft(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var shop := _place_isolated_workshop(sim)
	var player := sim.get_player()
	if shop == null or player == null:
		fails.append("missing-input craft setup failed")
		return
	_stand_beside(player, sim.world, shop)
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	_give_recipe(player)
	_hold_interact(sim, 8)
	if player.interact_progress <= 0.0:
		fails.append("expected craft progress before dropping ore")
		return
	player.inventory.remove(Types.ResourceKind.ORE, player.inventory.ore)
	_hold_interact(sim, 1)
	if player.interact_progress != 0.0:
		fails.append("missing ore should reset craft progress")
	if player.inventory.parts != 0:
		fails.append("missing ore must not produce parts")
	if player.inventory.scrap != Constants.WORKSHOP_SCRAP_COST:
		fails.append("missing ore must not consume scrap")


func _test_no_parts_space_does_not_consume(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var shop := _place_isolated_workshop(sim)
	var player := sim.get_player()
	if shop == null or player == null:
		fails.append("full-parts craft setup failed")
		return
	_stand_beside(player, sim.world, shop)
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	_give_recipe(player)
	player.inventory.add(Types.ResourceKind.PARTS, Constants.PLAYER_CARRY_PARTS)
	_hold_interact(sim, _craft_ticks())
	if player.inventory.parts != Constants.PLAYER_CARRY_PARTS:
		fails.append("full parts bag changed during a blocked craft")
	if player.inventory.scrap != Constants.WORKSHOP_SCRAP_COST:
		fails.append("no Parts space consumed scrap")
	if player.inventory.ore != Constants.WORKSHOP_ORE_COST:
		fails.append("no Parts space consumed ore")
	if player.interact_progress != 0.0:
		fails.append("no Parts space should not advance the craft channel")


func _test_withdraw_leftover_then_craft(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var depot := _player_depot(sim)
	var lab := _place_lab(sim)
	var shop := _place_isolated_workshop(sim)
	var player := sim.get_player()
	if depot == null or lab == null or shop == null or player == null:
		fails.append("leftover-ore craft setup missing depot/lab/workshop/player")
		return
	_stand_beside(player, sim.world, depot)
	player.inventory.add(Types.ResourceKind.ORE, 2)
	_hold_interact(sim, _transfer_ticks())
	if player.inventory.ore != 0 or depot.inventory.ore != 2:
		fails.append(
			"leftover dump left player/depot ore %d/%d, expected 0/2"
			% [player.inventory.ore, depot.inventory.ore]
		)
		return
	player.inventory.add(Types.ResourceKind.ORE, Constants.TECH_METALLURGY_ORE)
	_hold_interact(sim, _transfer_ticks() * 2)
	if player.inventory.ore != 0 or depot.inventory.ore != 2 + Constants.TECH_METALLURGY_ORE:
		fails.append(
			"metallurgy dump left player/depot ore %d/%d"
			% [player.inventory.ore, depot.inventory.ore]
		)
		return
	_stand_beside(player, sim.world, lab)
	Research.select(sim, Types.TechKind.METALLURGY)
	_hold_interact(sim, 1)
	if depot.inventory.ore != 2:
		fails.append("Metallurgy should consume 6 dumped ore and leave the leftover 2")
		return
	sim.research_progress = Constants.TECH_METALLURGY_TIME - Constants.SIM_DT
	_hold_interact(sim, 1)
	if not sim.tech_complete(Types.TechKind.METALLURGY):
		fails.append("expected Metallurgy complete before leftover withdraw")
		return
	if depot.inventory.ore != 2:
		fails.append("completing Metallurgy must not refund the 6 Ore payment")
	_stand_beside(player, sim.world, depot)
	_hold_withdraw(sim, _transfer_ticks())
	if player.inventory.ore != 2:
		fails.append("withdraw should pull leftover ore, got %d" % player.inventory.ore)
		return
	if depot.inventory.ore != 0:
		fails.append("depot leftover ore should be gone after withdraw")
	if player.inventory.scrap < Constants.WORKSHOP_SCRAP_COST:
		player.inventory.add(
			Types.ResourceKind.SCRAP, Constants.WORKSHOP_SCRAP_COST - player.inventory.scrap
		)
	_stand_beside(player, sim.world, shop)
	_hold_interact(sim, _craft_ticks())
	if player.inventory.parts != Constants.WORKSHOP_PARTS_OUT:
		fails.append("leftover-ore craft parts is %d" % player.inventory.parts)
	if player.inventory.ore != 0:
		fails.append("leftover-ore craft left ore %d" % player.inventory.ore)
	if depot.inventory.ore != 0:
		fails.append("leftover-ore craft must not refund Metallurgy ore into the depot")


func _test_panel_recipe_and_lock(fails: PackedStringArray) -> void:
	var panel := BuildingPanel.new()
	var rec := {
		"id": 11,
		"kind": Types.BuildingKind.WORKSHOP,
		"faction": Types.Faction.PLAYER,
		"hp": Constants.WORKSHOP_HP,
		"hp_max": Constants.WORKSHOP_HP,
		"origin_tile": Vector2i(12, 12),
	}
	panel.open_building(rec)
	var box := panel.find_child("WorkshopBox", true, false) as Control
	if box == null or not box.visible:
		fails.append("workshop panel should show the recipe box")
	var recipe := panel.find_child("WorkshopRecipe", true, false) as Control
	if recipe == null or not recipe.visible:
		fails.append("workshop panel should show the recipe row")
	var lock := panel.find_child("WorkshopLock", true, false) as Label
	if lock == null or not lock.visible:
		fails.append("workshop panel should show the lock hint before Metallurgy")
	var snap := SimSnapshot.new()
	snap.buildings = [rec]
	snap.techs_done = 1 << Types.TechKind.METALLURGY
	panel.apply_snapshot(snap)
	if lock == null or lock.visible:
		fails.append("workshop lock hint should hide after Metallurgy")
	panel.free()


func _fresh() -> Sim:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	return sim


func _place_lab(sim: Sim) -> Building:
	_ensure_depot_scrap(sim, Constants.LAB_COST)
	var tile := _first_placeable(sim, Types.BuildingKind.LAB)
	if tile.x < 0:
		return null
	if not Rules.try_place(sim.world, sim, Types.BuildingKind.LAB, tile):
		return null
	return sim.world.building_at(tile.x, tile.y)


func _place_isolated_workshop(sim: Sim) -> Building:
	_ensure_depot_scrap(sim, Constants.WORKSHOP_COST)
	var depot := _player_depot(sim)
	if depot == null:
		return null
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var tile := Vector2i(x, y)
			if not Rules.can_place(sim.world, sim, Types.BuildingKind.WORKSHOP, tile):
				continue
			var stand := _stand_tile(sim.world, tile)
			if stand.x < 0:
				continue
			if not _depot_out_of_range(sim.world, depot, stand):
				continue
			if _has_gather_or_loot(sim.world, stand):
				continue
			if not Rules.try_place(sim.world, sim, Types.BuildingKind.WORKSHOP, tile):
				continue
			return sim.world.building_at(tile.x, tile.y)
	return null


func _stand_tile(world: World, origin: Vector2i) -> Vector2i:
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var tile: Vector2i = origin + offset
		if world.in_bounds(tile.x, tile.y) and world.is_walkable(tile.x, tile.y):
			return tile
	return Vector2i(-1, -1)


func _depot_out_of_range(world: World, depot: Building, stand: Vector2i) -> bool:
	var pos := world.tile_center(stand.x, stand.y)
	return world.point_aabb_distance(pos, world.footprint_aabb(depot)) > Constants.INTERACT_BUILDING_RANGE


func _has_gather_or_loot(world: World, stand: Vector2i) -> bool:
	var pos := world.tile_center(stand.x, stand.y)
	for deposit in world.deposits.values():
		if deposit.remaining <= 0:
			continue
		var dep_pos := world.tile_center(deposit.tile.x, deposit.tile.y)
		if pos.distance_to(dep_pos) <= Constants.GATHER_RANGE:
			return true
	for pile in world.loot.values():
		if pos.distance_to(pile.pos) <= Constants.GATHER_RANGE:
			return true
	return false


func _first_placeable(sim: Sim, kind: int) -> Vector2i:
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var tile := Vector2i(x, y)
			if Rules.can_place(sim.world, sim, kind, tile):
				return tile
	return Vector2i(-1, -1)


func _ensure_depot_scrap(sim: Sim, need: int) -> void:
	var depot := _player_depot(sim)
	if depot == null or depot.inventory == null:
		return
	var missing := need - depot.inventory.scrap
	if missing > 0:
		depot.inventory.add(Types.ResourceKind.SCRAP, missing)


func _player_depot(sim: Sim) -> Building:
	for building in sim.world.buildings.values():
		if building.kind == Types.BuildingKind.DEPOT and building.faction == Types.Faction.PLAYER:
			return building
	return null


func _stand_beside(unit: Unit, world: World, building: Building) -> void:
	var tile := _stand_tile(world, building.origin_tile)
	if tile.x < 0:
		tile = Vector2i(building.origin_tile.x - 1, building.origin_tile.y)
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.vel = Vector2.ZERO


func _give_recipe(player: Unit) -> void:
	if player.inventory.scrap < Constants.WORKSHOP_SCRAP_COST:
		player.inventory.add(Types.ResourceKind.SCRAP, Constants.WORKSHOP_SCRAP_COST - player.inventory.scrap)
	if player.inventory.ore < Constants.WORKSHOP_ORE_COST:
		player.inventory.add(Types.ResourceKind.ORE, Constants.WORKSHOP_ORE_COST - player.inventory.ore)


func _hold_interact(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		var cmd := InputCommand.new()
		cmd.interact = true
		sim.enqueue(cmd)
		sim.tick()


func _hold_withdraw(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		var cmd := InputCommand.new()
		cmd.interact = true
		cmd.withdraw = true
		sim.enqueue(cmd)
		sim.tick()


func _craft_ticks() -> int:
	return int(Constants.WORKSHOP_CRAFT_CHANNEL / Constants.SIM_DT)


func _transfer_ticks() -> int:
	return int(Constants.TRANSFER_PERIOD / Constants.SIM_DT)
