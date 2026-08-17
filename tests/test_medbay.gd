extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_ten_ticks_heals_one(fails)
	_test_two_medbays_do_not_stack(fails)
	_test_walk_away_resets_acc(fails)
	_test_hp_zero_skips_heal(fails)
	_test_lethal_pulse_not_undone(fails)
	_test_place_after_field_medicine(fails)
	_test_panel_heal_hint(fails)
	return fails


func _test_ten_ticks_heals_one(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var medbay := _inject_medbay(sim, Vector2i(21, 20))
	player.pos = _adjacent_pos(sim, medbay)
	player.hp = 10
	_tick_idle(sim, 9)
	if player.hp != 10:
		fails.append("9 ticks adjacent should not heal yet, hp=%d" % player.hp)
	_tick_idle(sim, 1)
	if player.hp != 11:
		fails.append("10 ticks adjacent should heal +1, hp=%d" % player.hp)
	if not is_equal_approx(sim.medbay_heal_acc, 0.0):
		fails.append("heal should consume one MEDBAY_HEAL_PERIOD, acc=%s" % str(sim.medbay_heal_acc))


func _test_two_medbays_do_not_stack(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var a := _inject_medbay(sim, Vector2i(21, 20))
	_inject_medbay(sim, Vector2i(21, 21))
	player.pos = _adjacent_pos(sim, a)
	player.hp = 10
	_tick_idle(sim, 10)
	if player.hp != 11:
		fails.append("two Medbays should still heal +1 per period, hp=%d" % player.hp)


func _test_walk_away_resets_acc(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var medbay := _inject_medbay(sim, Vector2i(21, 20))
	player.pos = _adjacent_pos(sim, medbay)
	player.hp = 10
	_tick_idle(sim, 9)
	if sim.medbay_heal_acc <= 0.0:
		fails.append("expected heal acc to build while adjacent")
	player.pos = _far_pos()
	_tick_idle(sim, 1)
	if not is_equal_approx(sim.medbay_heal_acc, 0.0):
		fails.append("walking away should reset medbay_heal_acc, acc=%s" % str(sim.medbay_heal_acc))
	if player.hp != 10:
		fails.append("walking away should not grant the pending heal, hp=%d" % player.hp)
	player.pos = _adjacent_pos(sim, medbay)
	_tick_idle(sim, 10)
	if player.hp != 11:
		fails.append("acc should restart after walk-away, hp=%d" % player.hp)


func _test_hp_zero_skips_heal(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var medbay := _inject_medbay(sim, Vector2i(21, 20))
	player.pos = _adjacent_pos(sim, medbay)
	player.hp = 10
	_tick_idle(sim, 9)
	player.hp = 0
	sim.medbay_heal_acc = Constants.MEDBAY_HEAL_PERIOD
	_tick_idle(sim, 1)
	if player.hp != 0:
		fails.append("hp <= 0 should skip heal, hp=%d" % player.hp)
	if not is_equal_approx(sim.medbay_heal_acc, 0.0):
		fails.append("hp <= 0 should reset medbay_heal_acc, acc=%s" % str(sim.medbay_heal_acc))


func _test_lethal_pulse_not_undone(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var medbay := _inject_medbay(sim, Vector2i(21, 20))
	player.pos = _adjacent_pos(sim, medbay)
	player.o2 = 12.0
	player.hp = 1
	player.inventory.remove(Types.ResourceKind.FOOD, player.inventory.food)
	sim.hunger_starving = true
	sim.medbay_heal_acc = Constants.MEDBAY_HEAL_PERIOD
	sim.tick_index = Constants.PLAYER_HUNGER_PULSE_TICKS - 1
	sim.tick()
	if player.alive or player.hp > 0:
		fails.append(
			"lethal hunger pulse next to a Medbay should kill this tick (alive=%s hp=%d)"
			% [str(player.alive), player.hp]
		)
	if sim.outcome != Types.Outcome.NONE:
		fails.append("hunger death next to Medbay locked outcome %d/%d" % [sim.outcome, sim.outcome_reason])


func _test_place_after_field_medicine(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var depot := _player_depot(sim)
	if depot == null or depot.inventory == null:
		fails.append("place test missing player depot")
		return
	var tile := _first_placeable(sim, Types.BuildingKind.MEDBAY)
	if tile.x >= 0:
		fails.append("Medbay should stay unplaceable before Field Medicine")
	Research.mark_complete(sim, Types.TechKind.FIELD_MEDICINE)
	if depot.inventory.scrap < Constants.MEDBAY_COST_SCRAP:
		depot.inventory.add(Types.ResourceKind.SCRAP, Constants.MEDBAY_COST_SCRAP)
	var habitat := _player_habitat(sim)
	if habitat == null or habitat.inventory == null:
		fails.append("place test missing player habitat")
		return
	if habitat.inventory.ice < Constants.MEDBAY_COST_ICE:
		habitat.inventory.add(Types.ResourceKind.ICE, Constants.MEDBAY_COST_ICE)
	var scrap_before := depot.inventory.scrap
	var ice_before := habitat.inventory.ice
	tile = _first_placeable(sim, Types.BuildingKind.MEDBAY)
	if tile.x < 0:
		fails.append("Field Medicine should make Medbay placeable")
		return
	if not Rules.try_place(sim.world, sim, Types.BuildingKind.MEDBAY, tile):
		fails.append("try_place Medbay should succeed after Field Medicine")
		return
	if depot.inventory.scrap != scrap_before - Constants.MEDBAY_COST_SCRAP:
		fails.append(
			"Medbay scrap is %d, expected %d"
			% [depot.inventory.scrap, scrap_before - Constants.MEDBAY_COST_SCRAP]
		)
	if habitat.inventory.ice != ice_before - Constants.MEDBAY_COST_ICE:
		fails.append(
			"Medbay ice is %d, expected %d"
			% [habitat.inventory.ice, ice_before - Constants.MEDBAY_COST_ICE]
		)
	var building := sim.world.building_at(tile.x, tile.y)
	if building == null or building.kind != Types.BuildingKind.MEDBAY:
		fails.append("placed Medbay missing from occupancy")
		return
	if building.hp != Constants.MEDBAY_HP or building.hp_max != Constants.MEDBAY_HP:
		fails.append("placed Medbay hp is %d/%d" % [building.hp, building.hp_max])
	if World.footprint_span(Types.BuildingKind.MEDBAY) != 1:
		fails.append("Medbay footprint should be 1x1")
	if not sim.world.is_solid(tile.x, tile.y):
		fails.append("Medbay tile should be solid")


func _test_panel_heal_hint(fails: PackedStringArray) -> void:
	var panel := BuildingPanel.new()
	panel.open_building({
		"id": 4,
		"kind": Types.BuildingKind.MEDBAY,
		"faction": Types.Faction.PLAYER,
		"hp": Constants.MEDBAY_HP,
		"hp_max": Constants.MEDBAY_HP,
		"origin_tile": Vector2i(12, 12),
	})
	var hint := panel.find_child("HealHint", true, false) as Label
	if hint == null or not hint.visible:
		fails.append("Medbay panel should show the heal hint")
	elif hint.text != "+2 HP/s while adjacent":
		fails.append("Medbay heal hint is %s" % hint.text)
	panel.open_building({
		"id": 1,
		"kind": Types.BuildingKind.WALL,
		"faction": Types.Faction.PLAYER,
		"hp": Constants.WALL_HP,
		"hp_max": Constants.WALL_HP,
	})
	if hint.visible:
		fails.append("non-Medbay panel should hide the heal hint")
	panel.free()


func _sim_quiet() -> Sim:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.director != null:
		sim.director.next_wave_at = 1.0e9
	return sim


func _inject_medbay(sim: Sim, tile: Vector2i) -> Building:
	_clear_tile(sim.world, tile)
	_clear_tile(sim.world, Vector2i(tile.x + 1, tile.y))
	var building := Building.new()
	building.id = sim.world.alloc_id()
	building.kind = Types.BuildingKind.MEDBAY
	building.faction = Types.Faction.PLAYER
	building.origin_tile = tile
	building.hp = Constants.MEDBAY_HP
	building.hp_max = Constants.MEDBAY_HP
	building.aim = Vector2(1, 0)
	sim.world.buildings[building.id] = building
	sim.world.occupy(building)
	return building


func _clear_tile(world: World, tile: Vector2i) -> void:
	world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	var existing := world.building_at(tile.x, tile.y)
	if existing != null:
		world.vacate(existing)
		world.buildings.erase(existing.id)
	var drop: Array[int] = []
	for deposit in world.deposits.values():
		if deposit.tile == tile:
			drop.append(deposit.id)
	for id in drop:
		world.deposits.erase(id)


func _adjacent_pos(sim: Sim, building: Building) -> Vector2:
	var aabb := sim.world.footprint_aabb(building)
	return Vector2(aabb.end.x + 16.0, aabb.get_center().y)


func _far_pos() -> Vector2:
	return Vector2(30.5 * Constants.TILE, 30.5 * Constants.TILE)


func _tick_idle(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.tick()


func _player_depot(sim: Sim) -> Building:
	for building in sim.world.buildings.values():
		if building.kind == Types.BuildingKind.DEPOT and building.faction == Types.Faction.PLAYER:
			return building
	return null


func _player_habitat(sim: Sim) -> Building:
	for building in sim.world.buildings.values():
		if building.kind == Types.BuildingKind.HABITAT and building.faction == Types.Faction.PLAYER:
			return building
	return null


func _first_placeable(sim: Sim, kind: int) -> Vector2i:
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var tile := Vector2i(x, y)
			if Rules.can_place(sim.world, sim, kind, tile):
				return tile
	return Vector2i(-1, -1)
