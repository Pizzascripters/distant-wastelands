extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_select_and_ignore_rules(fails)
	_test_lab_advances_only_while_still(fails)
	_test_walk_pauses_without_reset(fails)
	_test_payment_on_first_progress_tick(fails)
	_test_cannot_pay_blocks_progress(fails)
	_test_switch_discards_without_refund(fails)
	_test_completion_unlocks(fails)
	_test_ballistics_range(fails)
	_test_command_and_latch(fails)
	_test_dead_player_ignores_research(fails)
	_test_snapshot_research_fields(fails)
	return fails


func _test_select_and_ignore_rules(fails: PackedStringArray) -> void:
	var sim := _fresh()
	Research.select(sim, Types.TechKind.BALLISTICS)
	if sim.research_selected != -1:
		fails.append("Ballistics select before Metallurgy should be ignored")
	Research.select(sim, Types.TechKind.HYDROPONICS)
	if sim.research_selected != Types.TechKind.HYDROPONICS:
		fails.append("Hydroponics should become the selected tech")
	sim.research_progress = 1.5
	sim.research_paid = true
	Research.select(sim, Types.TechKind.HYDROPONICS)
	if sim.research_progress != 1.5 or not sim.research_paid:
		fails.append("re-selecting the same tech must not reset progress")
	Research.mark_complete(sim, Types.TechKind.HYDROPONICS)
	Research.select(sim, Types.TechKind.HYDROPONICS)
	if sim.research_selected != Types.TechKind.HYDROPONICS:
		fails.append("selecting a completed tech should leave the prior selection")
	Research.select(sim, -3)
	if sim.research_selected != Types.TechKind.HYDROPONICS:
		fails.append("invalid research_kind should be ignored")
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	Research.select(sim, Types.TechKind.BALLISTICS)
	if sim.research_selected != Types.TechKind.BALLISTICS:
		fails.append("Ballistics should select after Metallurgy")
	if sim.research_progress != 0.0 or sim.research_paid:
		fails.append("switching to Ballistics should clear unpaid progress")


func _test_lab_advances_only_while_still(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var habitat := _player_habitat(sim)
	var lab := _place_lab(sim)
	var player := sim.get_player()
	if habitat == null or lab == null or player == null:
		fails.append("lab channel setup missing habitat/lab/player")
		return
	_stand_beside(player, sim.world, lab)
	Research.select(sim, Types.TechKind.HYDROPONICS)
	var ice_before := habitat.inventory.ice
	_hold_interact(sim, 5)
	if not sim.research_paid:
		fails.append("standing still at the lab should pay on first progress")
	if habitat.inventory.ice != ice_before - Constants.TECH_HYDROPONICS_ICE:
		fails.append(
			"hydroponics paid ice %d, expected %d"
			% [habitat.inventory.ice, ice_before - Constants.TECH_HYDROPONICS_ICE]
		)
	var expected := 5.0 * Constants.SIM_DT
	if not is_equal_approx(sim.research_progress, expected):
		fails.append("still channel left progress %s, expected %s" % [str(sim.research_progress), str(expected)])


func _test_walk_pauses_without_reset(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var lab := _place_lab(sim)
	var player := sim.get_player()
	if lab == null or player == null:
		fails.append("pause test missing lab/player")
		return
	_stand_beside(player, sim.world, lab)
	Research.select(sim, Types.TechKind.HYDROPONICS)
	_hold_interact(sim, 4)
	var paused := sim.research_progress
	if paused <= 0.0:
		fails.append("expected some research progress before walking")
		return
	for _i in 6:
		var walk := InputCommand.new()
		walk.interact = true
		walk.move = Vector2.RIGHT
		sim.enqueue(walk)
		sim.tick()
	if not is_equal_approx(sim.research_progress, paused):
		fails.append("walking reset research_progress %s -> %s" % [str(paused), str(sim.research_progress)])
	if player.interact_progress != 0.0:
		fails.append("walking should still reset interact_progress")
	_stand_beside(player, sim.world, lab)
	_hold_interact(sim, 2)
	if sim.research_progress <= paused:
		fails.append("resuming at the lab should continue paused progress")


func _test_payment_on_first_progress_tick(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var habitat := _player_habitat(sim)
	var lab := _place_lab(sim)
	var player := sim.get_player()
	if habitat == null or lab == null or player == null:
		fails.append("payment test missing habitat/lab/player")
		return
	_stand_beside(player, sim.world, lab)
	var ice_before := habitat.inventory.ice
	Research.select(sim, Types.TechKind.HYDROPONICS)
	sim.tick()
	if habitat.inventory.ice != ice_before or sim.research_paid or sim.research_progress != 0.0:
		fails.append("select without channeling should not pay")
	_hold_interact(sim, 1)
	if not sim.research_paid:
		fails.append("first lab channel tick should set research_paid")
	if habitat.inventory.ice != ice_before - Constants.TECH_HYDROPONICS_ICE:
		fails.append("first progress tick should deduct the full tech cost")
	if not is_equal_approx(sim.research_progress, Constants.SIM_DT):
		fails.append("first paid tick should increment progress by SIM_DT")
	var ice_after := habitat.inventory.ice
	_hold_interact(sim, 3)
	if habitat.inventory.ice != ice_after:
		fails.append("later lab ticks should not charge again")


func _test_cannot_pay_blocks_progress(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var habitat := _player_habitat(sim)
	var lab := _place_lab(sim)
	var player := sim.get_player()
	if habitat == null or lab == null or player == null:
		fails.append("unaffordable research setup failed")
		return
	if habitat.inventory.ice > 0:
		habitat.inventory.remove(Types.ResourceKind.ICE, habitat.inventory.ice)
	_stand_beside(player, sim.world, lab)
	Research.select(sim, Types.TechKind.HYDROPONICS)
	_hold_interact(sim, 8)
	if sim.research_paid or sim.research_progress != 0.0:
		fails.append("unaffordable research should not increment")
	if habitat.inventory.ice != 0:
		fails.append("unaffordable research should not change habitat ice")


func _test_switch_discards_without_refund(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var habitat := _player_habitat(sim)
	var lab := _place_lab(sim)
	var player := sim.get_player()
	if habitat == null or lab == null or player == null:
		fails.append("switch test missing habitat/lab/player")
		return
	_stand_beside(player, sim.world, lab)
	var ice_before := habitat.inventory.ice
	Research.select(sim, Types.TechKind.HYDROPONICS)
	_hold_interact(sim, 4)
	var after_pay := habitat.inventory.ice
	if after_pay != ice_before - Constants.TECH_HYDROPONICS_ICE:
		fails.append("expected hydroponics payment before switch")
		return
	Research.select(sim, Types.TechKind.FIELD_MEDICINE)
	if sim.research_selected != Types.TechKind.FIELD_MEDICINE:
		fails.append("switch should select Field Medicine")
	if sim.research_progress != 0.0 or sim.research_paid:
		fails.append("switch should discard paid incomplete progress")
	if habitat.inventory.ice != after_pay:
		fails.append("switch refunded ice %d -> %d" % [after_pay, habitat.inventory.ice])


func _test_completion_unlocks(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var lab := _place_lab(sim)
	var player := sim.get_player()
	if lab == null or player == null:
		fails.append("completion test missing lab/player")
		return
	_stand_beside(player, sim.world, lab)
	Research.select(sim, Types.TechKind.HYDROPONICS)
	_hold_interact(sim, 1)
	sim.research_progress = Constants.TECH_HYDROPONICS_TIME - Constants.SIM_DT
	_hold_interact(sim, 1)
	if not sim.tech_complete(Types.TechKind.HYDROPONICS):
		fails.append("finishing Hydroponics should set the bitmask")
	if sim.research_selected != -1 or sim.research_progress != 0.0 or sim.research_paid:
		fails.append("completion should clear the current research")
	if not Research.building_unlocked(sim, Types.BuildingKind.FARM):
		fails.append("Hydroponics should unlock Farm")
	if Research.workshop_unlocked(sim):
		fails.append("workshop recipe must stay locked until Metallurgy")
	var depot := _player_depot(sim)
	if depot != null:
		depot.inventory.add(Types.ResourceKind.ORE, Constants.TECH_METALLURGY_ORE)
	Research.select(sim, Types.TechKind.METALLURGY)
	_hold_interact(sim, 1)
	sim.research_progress = Constants.TECH_METALLURGY_TIME - Constants.SIM_DT
	_hold_interact(sim, 1)
	if not sim.tech_complete(Types.TechKind.METALLURGY):
		fails.append("finishing Metallurgy should set the bitmask")
	if not Research.workshop_unlocked(sim):
		fails.append("Metallurgy should unlock the workshop recipe flag")
	if not Research.building_unlocked(sim, Types.BuildingKind.GATE):
		fails.append("Metallurgy should unlock Gate")
	if depot != null:
		depot.inventory.add(Types.ResourceKind.SCRAP, Constants.TECH_FIELD_MED_SCRAP)
	var habitat := _player_habitat(sim)
	if habitat != null:
		habitat.inventory.add(Types.ResourceKind.ICE, Constants.TECH_FIELD_MED_ICE)
	Research.select(sim, Types.TechKind.FIELD_MEDICINE)
	_hold_interact(sim, 1)
	sim.research_progress = Constants.TECH_FIELD_MED_TIME - Constants.SIM_DT
	_hold_interact(sim, 1)
	if not Research.building_unlocked(sim, Types.BuildingKind.MEDBAY):
		fails.append("Field Medicine should unlock Medbay")


func _test_ballistics_range(fails: PackedStringArray) -> void:
	var sim := _fresh()
	if Research.turret_range(sim, Types.Faction.PLAYER) != Constants.TURRET_RANGE:
		fails.append("player turret range should start at TURRET_RANGE")
	if Research.turret_range(sim, Types.Faction.ENEMY) != Constants.TURRET_RANGE:
		fails.append("enemy turret range should stay TURRET_RANGE")
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	Research.mark_complete(sim, Types.TechKind.BALLISTICS)
	if Research.turret_range(sim, Types.Faction.PLAYER) != Constants.TURRET_RANGE_UPGRADED:
		fails.append("Ballistics should raise player turret range")
	if Research.turret_range(sim, Types.Faction.ENEMY) != Constants.TURRET_RANGE:
		fails.append("Ballistics must not upgrade the enemy turret")
	var player_turret := _inject_turret(sim, Types.Faction.PLAYER, Vector2i(20, 20))
	var raider := Unit.new()
	raider.id = sim.world.alloc_id()
	raider.kind = Types.UnitKind.RAIDER
	raider.faction = Types.Faction.ENEMY
	raider.alive = true
	raider.hp = Constants.RAIDER_HP
	raider.hp_max = Constants.RAIDER_HP
	var center := sim.world.footprint_aabb(player_turret).get_center()
	raider.pos = center + Vector2(Constants.TURRET_RANGE + 20.0, 0)
	sim.world.units[raider.id] = raider
	var before := sim.world.projectiles.size()
	sim.tick()
	if sim.world.projectiles.size() <= before:
		fails.append("upgraded player turret should fire past TURRET_RANGE")


func _test_command_and_latch(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var cmd := InputCommand.new()
	cmd.research_kind = Types.TechKind.HYDROPONICS
	sim.enqueue(cmd)
	sim.tick()
	if sim.research_selected != Types.TechKind.HYDROPONICS:
		fails.append("research_kind command should select the tech")
	var session := LocalSession.new()
	session.start(Constants.DEFAULT_SEED)
	var first := InputCommand.new()
	first.research_kind = Types.TechKind.FIELD_MEDICINE
	session.submit_command(first)
	var later := InputCommand.new()
	later.research_kind = -1
	session.submit_command(later)
	session.tick(Constants.SIM_DT)
	if session.sim.research_selected != Types.TechKind.FIELD_MEDICINE:
		fails.append("research latch must survive a later research_kind < 0")


func _test_dead_player_ignores_research(fails: PackedStringArray) -> void:
	var sim := _fresh()
	var player := sim.get_player()
	player.alive = false
	player.hp = 0
	var cmd := InputCommand.new()
	cmd.research_kind = Types.TechKind.HYDROPONICS
	sim.enqueue(cmd)
	sim.tick()
	if sim.research_selected != -1:
		fails.append("dead player must not apply research_kind")


func _test_snapshot_research_fields(fails: PackedStringArray) -> void:
	var sim := _fresh()
	sim.research_selected = Types.TechKind.METALLURGY
	sim.research_progress = 3.25
	sim.research_paid = true
	sim.techs_done = 1 << Types.TechKind.HYDROPONICS
	var snap := sim.snapshot()
	if snap.research_selected != Types.TechKind.METALLURGY:
		fails.append("snapshot research_selected is %d" % snap.research_selected)
	if not is_equal_approx(snap.research_progress, 3.25):
		fails.append("snapshot research_progress is %s" % str(snap.research_progress))
	if not snap.research_paid:
		fails.append("snapshot research_paid should be true")
	if snap.techs_done != (1 << Types.TechKind.HYDROPONICS):
		fails.append("snapshot techs_done is %d" % snap.techs_done)


func _fresh() -> Sim:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	return sim


func _place_lab(sim: Sim) -> Building:
	var depot := _player_depot(sim)
	if depot != null and depot.inventory != null and depot.inventory.scrap < Constants.LAB_COST:
		depot.inventory.add(Types.ResourceKind.SCRAP, Constants.LAB_COST)
	var tile := _first_placeable(sim, Types.BuildingKind.LAB)
	if tile.x < 0:
		return null
	if not Rules.try_place(sim.world, sim, Types.BuildingKind.LAB, tile):
		return null
	return sim.world.building_at(tile.x, tile.y)


func _first_placeable(sim: Sim, kind: int) -> Vector2i:
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var tile := Vector2i(x, y)
			if Rules.can_place(sim.world, sim, kind, tile):
				return tile
	return Vector2i(-1, -1)


func _inject_turret(sim: Sim, faction: int, tile: Vector2i) -> Building:
	var turret := Building.new()
	turret.id = sim.world.alloc_id()
	turret.kind = Types.BuildingKind.TURRET
	turret.faction = faction
	turret.origin_tile = tile
	turret.hp = Constants.TURRET_HP
	turret.hp_max = Constants.TURRET_HP
	turret.aim = Vector2(1, 0)
	sim.world.buildings[turret.id] = turret
	sim.world.occupy(turret)
	return turret


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


func _stand_beside(unit: Unit, world: World, building: Building) -> void:
	var span := world.footprint_span(building.kind)
	var o := building.origin_tile
	var candidates: Array[Vector2i] = [
		Vector2i(o.x + span, o.y),
		Vector2i(o.x, o.y + span),
		Vector2i(o.x - 1, o.y),
		Vector2i(o.x, o.y - 1),
	]
	var tile := Vector2i(o.x + span, o.y)
	for cand in candidates:
		if world.is_walkable(cand.x, cand.y):
			tile = cand
			break
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.vel = Vector2.ZERO


func _hold_interact(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		var cmd := InputCommand.new()
		cmd.interact = true
		sim.enqueue(cmd)
		sim.tick()
