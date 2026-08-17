extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_starts_at_max(fails)
	_test_habitat_refill(fails)
	_test_zero_ice_habitat_does_not_refill(fails)
	_test_depot_does_not_refill(fails)
	_test_farm_does_not_refill(fails)
	_test_drain_away_from_camp(fails)
	_test_enemy_buildings_do_not_refill(fails)
	_test_dead_player_does_not_drain(fails)
	_test_o2_empty_is_suffocation(fails)
	_test_combat_death_respawns_full_o2(fails)
	_test_combat_death_respawns_without_habitat(fails)
	_test_second_habitat_with_ice_refills(fails)
	_test_habitat_smash_is_not_a_lose(fails)
	_test_hud_bar_colors(fails)
	return fails


func _test_starts_at_max(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	if player == null:
		fails.append("setup missing player")
		return
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("o2 started at %s, expected %s" % [str(player.o2), str(Constants.PLAYER_O2_MAX)])
	var snap := sim.snapshot()
	if not is_equal_approx(snap.player_o2, Constants.PLAYER_O2_MAX):
		fails.append("snapshot o2 started at %s" % str(snap.player_o2))
	sim.tick()
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("one tick at spawn left o2 at %s, expected max" % str(player.o2))


func _test_habitat_refill(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var habitat := _player_building(sim, Types.BuildingKind.HABITAT)
	if habitat == null:
		fails.append("missing player habitat")
		return
	player.o2 = 8.0
	player.pos = _adjacent_pos(sim, habitat)
	sim.tick()
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("habitat adjacency left o2 at %s" % str(player.o2))


func _test_zero_ice_habitat_does_not_refill(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var habitat := _player_building(sim, Types.BuildingKind.HABITAT)
	if habitat == null:
		fails.append("missing player habitat")
		return
	if habitat.inventory != null:
		habitat.inventory.remove(Types.ResourceKind.ICE, habitat.inventory.ice)
	if Rules.habitat_gives_o2(habitat):
		fails.append("0-ice habitat should not give O2")
	player.o2 = 8.0
	player.pos = _adjacent_pos(sim, habitat)
	sim.tick()
	if not is_equal_approx(player.o2, 8.0 - Constants.SIM_DT):
		fails.append("0-ice habitat refilled o2 to %s" % str(player.o2))
	if habitat.inventory != null:
		habitat.inventory.add(Types.ResourceKind.ICE, 1)
	if not Rules.habitat_gives_o2(habitat):
		fails.append("stocked habitat should give O2")


func _test_depot_does_not_refill(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var depot := _player_building(sim, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("missing player depot")
		return
	player.o2 = 8.0
	player.pos = sim.world.tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	)
	sim.tick()
	if not is_equal_approx(player.o2, 8.0 - Constants.SIM_DT):
		fails.append("depot corridor tile refilled o2 to %s" % str(player.o2))
	player.o2 = 8.0
	player.pos = _adjacent_pos(sim, depot)
	sim.tick()
	if not is_equal_approx(player.o2, 8.0 - Constants.SIM_DT):
		fails.append("depot east-face adjacency refilled o2 to %s" % str(player.o2))


func _test_farm_does_not_refill(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var farm := _inject_building(sim, Types.BuildingKind.FARM, Vector2i(20, 20), Constants.FARM_HP)
	farm.food_stock = Constants.FARM_FOOD_CAP
	player.pos = _adjacent_pos(sim, farm)
	player.o2 = 8.0
	sim.tick()
	if not is_equal_approx(player.o2, 8.0 - Constants.SIM_DT):
		fails.append("farm refilled o2 to %s" % str(player.o2))


func _test_drain_away_from_camp(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	player.pos = _far_pos()
	player.o2 = 12.0
	sim.tick()
	if not is_equal_approx(player.o2, 12.0 - Constants.SIM_DT):
		fails.append("off-pad o2 is %s, expected drain" % str(player.o2))


func _test_enemy_buildings_do_not_refill(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var enemy_habitat := _faction_building(sim, Types.BuildingKind.HABITAT, Types.Faction.ENEMY)
	if enemy_habitat == null:
		fails.append("missing enemy habitat")
		return
	player.o2 = 8.0
	player.pos = _adjacent_pos(sim, enemy_habitat)
	sim.tick()
	if not is_equal_approx(player.o2, 8.0 - Constants.SIM_DT):
		fails.append("enemy habitat refilled o2 to %s" % str(player.o2))
	var enemy_depot := _faction_building(sim, Types.BuildingKind.DEPOT, Types.Faction.ENEMY)
	if enemy_depot == null:
		fails.append("missing enemy depot")
		return
	player.o2 = 8.0
	player.pos = _adjacent_pos(sim, enemy_depot)
	sim.tick()
	if not is_equal_approx(player.o2, 8.0 - Constants.SIM_DT):
		fails.append("enemy depot refilled o2 to %s" % str(player.o2))


func _test_dead_player_does_not_drain(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	player.pos = _far_pos()
	player.alive = false
	player.respawn_timer = 2.0
	player.o2 = 9.0
	sim.tick()
	if not is_equal_approx(player.o2, 9.0):
		fails.append("dead player o2 changed to %s" % str(player.o2))


func _test_o2_empty_is_suffocation(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	player.pos = _far_pos()
	player.o2 = 0.0
	player.hp = Constants.PLAYER_HP
	sim.tick()
	if not sim.oxygen_failed:
		fails.append("o2 == 0 should set oxygen_failed")
	if sim.outcome != Types.Outcome.PLAYER_LOSE or sim.outcome_reason != Types.OutcomeReason.SUFFOCATION:
		fails.append(
			"o2 == 0 outcome is %d/%d, expected PLAYER_LOSE/SUFFOCATION"
			% [sim.outcome, sim.outcome_reason]
		)
	if player.hp != Constants.PLAYER_HP:
		fails.append("suffocation should not pulse HP, hp=%d" % player.hp)
	if not player.alive:
		fails.append("suffocation should not kill/respawn the player")
	if sim.world.loot.size() != 0:
		fails.append("suffocation should not drop a corpse pile")
	var locked := sim.outcome
	sim.tick()
	if sim.outcome != locked or player.hp != Constants.PLAYER_HP:
		fails.append("locked suffocation tick mutated outcome or hp")


func _test_combat_death_respawns_full_o2(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	player.pos = _far_pos()
	player.o2 = 12.0
	player.hp = 1
	player.inventory.add(Types.ResourceKind.SCRAP, 3)
	player.inventory.add(Types.ResourceKind.ICE, 2)
	Combat.apply_damage(player, 1)
	sim.tick()
	if player.alive:
		fails.append("combat death should kill the player")
		return
	if sim.outcome != Types.Outcome.NONE:
		fails.append("combat death locked outcome %d/%d" % [sim.outcome, sim.outcome_reason])
	if player.inventory.scrap != 0 or player.inventory.ice != 0:
		fails.append("combat death should empty carry")
	if sim.world.loot.size() != 1:
		fails.append("combat death loot piles: %d, expected 1" % sim.world.loot.size())
	player.respawn_timer = Constants.SIM_DT
	sim.tick()
	if not player.alive:
		fails.append("player should respawn when timer hits 0")
		return
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("respawn o2 is %s, expected max" % str(player.o2))
	if player.hp != player.hp_max:
		fails.append("respawn hp is %d" % player.hp)
	if player.inventory.scrap != 0 or player.inventory.ice != 0:
		fails.append("respawn carry should be empty")


func _test_combat_death_respawns_without_habitat(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var habitat := _player_building(sim, Types.BuildingKind.HABITAT)
	if player == null or habitat == null:
		fails.append("no-habitat respawn missing player or habitat")
		return
	habitat.hp = 0
	player.pos = _far_pos()
	player.o2 = 12.0
	player.hp = 1
	Combat.apply_damage(player, 1)
	sim.tick()
	if player.alive:
		fails.append("combat death without Habitat should kill the player")
		return
	if sim.outcome != Types.Outcome.NONE:
		fails.append(
			"combat death without Habitat locked outcome %d/%d"
			% [sim.outcome, sim.outcome_reason]
		)
	if _player_building(sim, Types.BuildingKind.HABITAT) != null:
		fails.append("Habitat should be gone before the respawn tick")
	player.respawn_timer = Constants.SIM_DT
	sim.tick()
	if not player.alive:
		fails.append("player should respawn even if every Habitat is gone")
		return
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("no-habitat respawn o2 is %s, expected max" % str(player.o2))


func _test_second_habitat_with_ice_refills(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var starter := _player_building(sim, Types.BuildingKind.HABITAT)
	if player == null or starter == null:
		fails.append("second Habitat refill missing player or starter Habitat")
		return
	var tile := Vector2i(30, 30)
	var second := _inject_building(sim, Types.BuildingKind.HABITAT, tile, Constants.HABITAT_HP)
	second.inventory = Building.inventory_for(Types.BuildingKind.HABITAT)
	second.inventory.add(Types.ResourceKind.ICE, 1)
	sim.world.occupy(second)
	player.o2 = 8.0
	player.pos = _adjacent_pos(sim, second)
	sim.tick()
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("second Habitat with ice left o2 at %s" % str(player.o2))


func _test_habitat_smash_is_not_a_lose(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var habitat := _player_building(sim, Types.BuildingKind.HABITAT)
	if habitat == null:
		fails.append("missing player habitat")
		return
	player.pos = _far_pos()
	player.o2 = 9.0
	habitat.hp = 0
	sim.tick()
	if sim.outcome != Types.Outcome.NONE:
		fails.append("habitat smash locked outcome %d/%d" % [sim.outcome, sim.outcome_reason])
	if not is_equal_approx(player.o2, 9.0 - Constants.SIM_DT):
		fails.append("after habitat smash o2 is %s, expected drain" % str(player.o2))
	player.o2 = 0.0
	sim.tick()
	if not sim.oxygen_failed:
		fails.append("o2 == 0 after habitat smash should set oxygen_failed")
	if sim.outcome != Types.Outcome.PLAYER_LOSE or sim.outcome_reason != Types.OutcomeReason.SUFFOCATION:
		fails.append(
			"sitting after habitat smash ended %d/%d, expected SUFFOCATION"
			% [sim.outcome, sim.outcome_reason]
		)


func _test_hud_bar_colors(fails: PackedStringArray) -> void:
	var hud := Hud.new()
	var snap := SimSnapshot.new()
	snap.player_o2 = 21.0
	snap.player_o2_max = Constants.PLAYER_O2_MAX
	hud.apply_snapshot(snap)
	var fill := hud.find_child("O2Fill", true, false) as ColorRect
	var value := hud.find_child("O2Value", true, false) as Label
	if fill == null or fill.color != Color("3DDC97"):
		fails.append("o2 > 20 should be #3DDC97")
	if value == null or value.text != "21 / 60":
		fails.append("o2 text is %s" % (value.text if value != null else "missing"))
	snap.player_o2 = 20.0
	hud.apply_snapshot(snap)
	if fill.color != Color("E2C044"):
		fails.append("o2 == 20 should be #E2C044")
	snap.player_o2 = 10.0
	hud.apply_snapshot(snap)
	if fill.color != Color("E24A3B"):
		fails.append("o2 == 10 should be #E24A3B")
	snap.player_o2 = 0.0
	hud.apply_snapshot(snap)
	if fill.color != Color("E24A3B"):
		fails.append("o2 == 0 fill should be #E24A3B")
	if fill.anchor_right != 0.0:
		fails.append("o2 == 0 bar should be empty, anchor_right=%s" % str(fill.anchor_right))
	if value.text != "0 / 60":
		fails.append("empty o2 text is %s" % value.text)
	hud.free()


func _sim_quiet() -> Sim:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if sim.world != null:
		for raw in sim.world.camps:
			var camp := raw as World.Camp
			if camp != null:
				camp.next_raid_at = 1.0e9
	return sim


func _player_building(sim: Sim, kind: int) -> Building:
	return _faction_building(sim, kind, Types.Faction.PLAYER)


func _faction_building(sim: Sim, kind: int, faction: int) -> Building:
	for building in sim.world.buildings.values():
		if building.kind == kind and building.faction == faction and building.hp > 0:
			return building
	return null


func _adjacent_pos(sim: Sim, building: Building) -> Vector2:
	var aabb := sim.world.footprint_aabb(building)
	return Vector2(aabb.end.x + 16.0, aabb.get_center().y)


func _far_pos() -> Vector2:
	return Vector2(20.5 * Constants.TILE, 20.5 * Constants.TILE)


func _inject_building(sim: Sim, kind: int, tile: Vector2i, hp: int) -> Building:
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	sim.world.set_terrain(tile.x + 1, tile.y, Types.TileTerrain.EMPTY)
	var building := Building.new()
	building.id = sim.world.alloc_id()
	building.kind = kind
	building.faction = Types.Faction.PLAYER
	building.origin_tile = tile
	building.hp = hp
	building.hp_max = hp
	sim.world.buildings[building.id] = building
	return building
