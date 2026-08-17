extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_starts_at_max(fails)
	_test_habitat_refill(fails)
	_test_depot_refill(fails)
	_test_greenhouse_hook(fails)
	_test_drain_away_from_camp(fails)
	_test_enemy_buildings_do_not_refill(fails)
	_test_dead_player_does_not_drain(fails)
	_test_suffocation_pulse(fails)
	_test_lethal_pulse_not_healed(fails)
	_test_death_drops_and_respawn_refills(fails)
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


func _test_depot_refill(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var depot := _player_building(sim, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("missing player depot")
		return
	player.o2 = 8.0
	player.pos = sim.world.tile_center(11, 52)
	sim.tick()
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("depot adjacency left o2 at %s" % str(player.o2))
	player.o2 = 8.0
	player.pos = _adjacent_pos(sim, depot)
	sim.tick()
	if not is_equal_approx(player.o2, Constants.PLAYER_O2_MAX):
		fails.append("depot east-face adjacency left o2 at %s" % str(player.o2))


func _test_greenhouse_hook(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var standin := _inject_building(sim, Types.BuildingKind.TURRET, Vector2i(20, 20), Constants.TURRET_HP)
	player.pos = _adjacent_pos(sim, standin)
	player.o2 = 8.0
	sim.tick()
	if not is_equal_approx(player.o2, 8.0 - Constants.SIM_DT):
		fails.append("non-habitat/depot building refilled o2 to %s" % str(player.o2))


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


func _test_suffocation_pulse(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	player.pos = _far_pos()
	player.o2 = 0.0
	player.hp = Constants.PLAYER_HP
	sim.tick_index = Constants.PLAYER_O2_PULSE_TICKS - 1
	sim.tick()
	var after_pulse := Constants.PLAYER_HP - Constants.PLAYER_O2_HP_PER_PULSE
	if player.hp != after_pulse:
		fails.append("pulse hp is %d, expected %d" % [player.hp, after_pulse])
	sim.tick()
	if player.hp != after_pulse:
		fails.append("non-pulse tick changed hp to %d" % player.hp)
	player.o2 = 0.0
	sim.tick_index = Constants.PLAYER_O2_PULSE_TICKS * 2 - 1
	sim.tick()
	if player.hp != after_pulse - Constants.PLAYER_O2_HP_PER_PULSE:
		fails.append("second pulse hp is %d" % player.hp)


func _test_lethal_pulse_not_healed(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	var medbay := _inject_building(sim, Types.BuildingKind.MEDBAY, Vector2i(21, 20), Constants.MEDBAY_HP)
	player.pos = _adjacent_pos(sim, medbay)
	player.o2 = 0.0
	player.hp = 1
	sim.tick_index = Constants.PLAYER_O2_PULSE_TICKS - 1
	sim.tick()
	if player.alive or player.hp > 0:
		fails.append("lethal pulse should kill this tick (alive=%s hp=%d)" % [str(player.alive), player.hp])


func _test_death_drops_and_respawn_refills(fails: PackedStringArray) -> void:
	var sim := _sim_quiet()
	var player := sim.get_player()
	player.pos = _far_pos()
	player.o2 = 0.0
	player.hp = 1
	player.inventory.add(Types.ResourceKind.SCRAP, 3)
	player.inventory.add(Types.ResourceKind.ICE, 2)
	sim.tick_index = Constants.PLAYER_O2_PULSE_TICKS - 1
	sim.tick()
	if player.alive:
		fails.append("suffocation should kill the player")
		return
	if player.inventory.scrap != 0 or player.inventory.ice != 0:
		fails.append("death should empty carry")
	if sim.world.loot.size() != 1:
		fails.append("death loot piles: %d, expected 1" % sim.world.loot.size())
	else:
		var pile: Loot = sim.world.loot.values()[0]
		if pile.inventory.scrap != 3 or pile.inventory.ice != 2:
			fails.append(
				"dropped loot is %d/%d, expected 3/2" % [pile.inventory.scrap, pile.inventory.ice]
			)
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
	if sim.director != null:
		sim.director.next_wave_at = 1.0e9
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
