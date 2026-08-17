extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_defaults_and_player_inventory(fails)
	_test_copies_world_entities(fails)
	_test_inventory_is_copied(fails)
	_test_habitat_ice_pool(fails)
	_test_player_respawn_timer(fails)
	_test_gather_channel_defaults(fails)
	_test_gather_channel_while_mining(fails)
	_test_player_o2_copied(fails)
	_test_oxygen_and_hunger_flags(fails)
	_test_tiles_recopy_on_generation(fails)
	_test_last_tick_usec_to_sim_ms(fails)
	return fails


func _test_defaults_and_player_inventory(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var snap := sim.snapshot()
	if snap.next_raid_at != Constants.CAMP_RAID_FIRST or snap.wave_index != 0 or snap.banner_timer != 0.0:
		fails.append(
			"director fields were %s/%d/%s, expected %s/0/0"
			% [str(snap.next_raid_at), snap.wave_index, str(snap.banner_timer), str(Constants.CAMP_RAID_FIRST)]
		)
	if "next_wave_at" in snap:
		fails.append("snapshot must not carry next_wave_at")
	if snap.player_respawn_timer != 0.0:
		fails.append("player_respawn_timer is %s, expected 0" % str(snap.player_respawn_timer))
	if not is_equal_approx(snap.player_o2, Constants.PLAYER_O2_MAX):
		fails.append("player_o2 is %s, expected %s" % [str(snap.player_o2), str(Constants.PLAYER_O2_MAX)])
	if not is_equal_approx(snap.player_o2_max, Constants.PLAYER_O2_MAX):
		fails.append(
			"player_o2_max is %s, expected %s" % [str(snap.player_o2_max), str(Constants.PLAYER_O2_MAX)]
		)
	if "player_zero_ice_timer" in snap or "enemy_zero_ice_timer" in snap:
		fails.append("snapshot must not carry zero_ice timers")
	if "player_living_depot_ice_empty" in snap or "enemy_living_depot_ice_empty" in snap:
		fails.append("snapshot must not carry depot ice-empty flags")
	if snap.habitat_ice_pool != Constants.START_PLAYER_ICE:
		fails.append("habitat_ice_pool is %d, expected %d" % [snap.habitat_ice_pool, Constants.START_PLAYER_ICE])
	if snap.oxygen_failed:
		fails.append("oxygen_failed should start false")
	if snap.hunger_starving:
		fails.append("hunger_starving should start false")
	if "hunger_failed" in snap:
		fails.append("snapshot must not carry hunger_failed")
	var player := _player_rec(snap)
	if player.is_empty():
		fails.append("snapshot missing player unit")
		return
	var inv: Variant = player.get("inventory", {})
	if not inv is Dictionary:
		fails.append("player inventory is not a Dictionary")
		return
	if int(inv.get("scrap", -1)) != 0 or int(inv.get("ice", -1)) != 0:
		fails.append("player carry started at %s/%s, expected 0/0" % [str(inv.get("scrap")), str(inv.get("ice"))])
	if int(inv.get("cap_scrap", -1)) != Constants.PLAYER_CARRY_SCRAP:
		fails.append("player cap_scrap is %s, expected %d" % [str(inv.get("cap_scrap")), Constants.PLAYER_CARRY_SCRAP])
	if int(inv.get("cap_ice", -1)) != Constants.PLAYER_CARRY_ICE:
		fails.append("player cap_ice is %s, expected %d" % [str(inv.get("cap_ice")), Constants.PLAYER_CARRY_ICE])
	if int(inv.get("cap_ore", -1)) != Constants.PLAYER_CARRY_ORE:
		fails.append("player cap_ore is %s, expected %d" % [str(inv.get("cap_ore")), Constants.PLAYER_CARRY_ORE])
	if int(inv.get("cap_parts", -1)) != Constants.PLAYER_CARRY_PARTS:
		fails.append(
			"player cap_parts is %s, expected %d" % [str(inv.get("cap_parts")), Constants.PLAYER_CARRY_PARTS]
		)
	if int(inv.get("ore", -1)) != 0 or int(inv.get("parts", -1)) != 0:
		fails.append("player ore/parts started at %s/%s" % [str(inv.get("ore")), str(inv.get("parts"))])


func _test_copies_world_entities(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var depot := Building.new()
	depot.id = sim.world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Constants.PLAYER_DEPOT_TILE
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.aim = Vector2.UP
	depot.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
	depot.inventory.add(Types.ResourceKind.SCRAP, 7)
	depot.inventory.add(Types.ResourceKind.ICE, 4)
	sim.world.buildings[depot.id] = depot
	var deposit := Deposit.new()
	deposit.id = sim.world.alloc_id()
	deposit.kind = Types.ResourceKind.SCRAP
	deposit.tile = Vector2i(10, 10)
	deposit.remaining = 8
	sim.world.deposits[deposit.id] = deposit
	var pile := Loot.new()
	pile.id = sim.world.alloc_id()
	pile.pos = Vector2(64, 96)
	pile.inventory.add(Types.ResourceKind.ICE, 2)
	sim.world.loot[pile.id] = pile
	var proj := Projectile.new()
	proj.id = sim.world.alloc_id()
	proj.faction = Types.Faction.PLAYER
	proj.pos = Vector2(20, 40)
	sim.world.projectiles[proj.id] = proj
	var snap := sim.snapshot()
	var rec := _rec_by_id(snap.buildings, depot.id)
	if rec.is_empty():
		fails.append("snapshot missing injected building id %d" % depot.id)
	else:
		if rec.get("kind", -1) != Types.BuildingKind.DEPOT:
			fails.append("building kind %s, expected DEPOT" % str(rec.get("kind")))
		if rec.get("faction", -1) != Types.Faction.PLAYER:
			fails.append("building faction %s, expected PLAYER" % str(rec.get("faction")))
		if rec.get("origin_tile", Vector2i.ZERO) != Constants.PLAYER_DEPOT_TILE:
			fails.append("building origin_tile %s" % str(rec.get("origin_tile")))
		if rec.get("pos", Vector2.ZERO) != sim.world.footprint_aabb(depot).position:
			fails.append("building pos %s, expected footprint top-left" % str(rec.get("pos")))
		if int(rec.get("hp", 0)) != Constants.DEPOT_HP or int(rec.get("hp_max", 0)) != Constants.DEPOT_HP:
			fails.append("building hp %s/%s" % [str(rec.get("hp")), str(rec.get("hp_max"))])
		if rec.get("aim", Vector2.ZERO) != Vector2.UP:
			fails.append("building aim %s, expected UP" % str(rec.get("aim")))
		var binv: Variant = rec.get("inventory", {})
		if not binv is Dictionary or int(binv.get("scrap", 0)) != 7 or int(binv.get("ice", 0)) != 0:
			fails.append("building inventory %s, expected scrap 7 ice 0" % str(binv))
		if not binv is Dictionary or int(binv.get("cap_scrap", 0)) != Constants.DEPOT_CAP_SCRAP:
			fails.append("depot cap_scrap %s" % str(binv.get("cap_scrap") if binv is Dictionary else binv))
	var drec := _rec_by_id(snap.deposits, deposit.id)
	if drec.is_empty():
		fails.append("snapshot missing injected deposit id %d" % deposit.id)
	else:
		if drec.get("kind", -1) != Types.ResourceKind.SCRAP:
			fails.append("deposit kind %s" % str(drec.get("kind")))
		if drec.get("tile", Vector2i.ZERO) != deposit.tile:
			fails.append("deposit tile %s" % str(drec.get("tile")))
		if int(drec.get("remaining", -1)) != 8:
			fails.append("deposit remaining %s, expected 8" % str(drec.get("remaining")))
		if drec.get("pos", Vector2.ZERO) != sim.world.tile_center(10, 10):
			fails.append("deposit pos %s" % str(drec.get("pos")))
	var lrec := _rec_by_id(snap.loot, pile.id)
	if lrec.is_empty():
		fails.append("snapshot missing injected loot id %d" % pile.id)
	else:
		if lrec.get("pos", Vector2.ZERO) != pile.pos:
			fails.append("loot pos %s" % str(lrec.get("pos")))
		var linv: Variant = lrec.get("inventory", {})
		if not linv is Dictionary or int(linv.get("ice", 0)) != 2:
			fails.append("loot inventory %s, expected ice 2" % str(linv))
	var prec := _rec_by_id(snap.projectiles, proj.id)
	if prec.is_empty():
		fails.append("snapshot missing injected projectile id %d" % proj.id)
	else:
		if prec.get("faction", -1) != Types.Faction.PLAYER:
			fails.append("projectile faction %s" % str(prec.get("faction")))
		if prec.get("pos", Vector2.ZERO) != proj.pos:
			fails.append("projectile pos %s" % str(prec.get("pos")))


func _test_inventory_is_copied(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	player.inventory.add(Types.ResourceKind.SCRAP, 3)
	var snap := sim.snapshot()
	player.inventory.add(Types.ResourceKind.SCRAP, 2)
	var rec := _player_rec(snap)
	var inv: Variant = rec.get("inventory", {})
	if not inv is Dictionary or int(inv.get("scrap", -1)) != 3:
		fails.append("snapshot inventory mutated with sim; scrap %s, expected 3" % str(inv.get("scrap") if inv is Dictionary else inv))


func _test_habitat_ice_pool(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var habitat := _player_habitat(sim)
	if habitat == null or habitat.inventory == null:
		fails.append("generated map missing player habitat")
		return
	var snap := sim.snapshot()
	if snap.habitat_ice_pool != habitat.inventory.ice:
		fails.append(
			"habitat_ice_pool is %d, expected %d"
			% [snap.habitat_ice_pool, habitat.inventory.ice]
		)
	habitat.inventory.remove(Types.ResourceKind.ICE, habitat.inventory.ice)
	var empty := sim.snapshot()
	if empty.habitat_ice_pool != 0:
		fails.append("empty habitat_ice_pool is %d" % empty.habitat_ice_pool)
	habitat.hp = 0
	var dead := sim.snapshot()
	if dead.habitat_ice_pool != 0:
		fails.append("dead habitat still contributed ice pool %d" % dead.habitat_ice_pool)


func _test_player_respawn_timer(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	player.alive = false
	player.respawn_timer = 2.5
	var snap := sim.snapshot()
	if not is_equal_approx(snap.player_respawn_timer, 2.5):
		fails.append("player_respawn_timer is %s, expected 2.5" % str(snap.player_respawn_timer))


func _test_gather_channel_defaults(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var snap := sim.snapshot()
	if snap.gather_deposit_id != 0 or snap.gather_progress != 0.0:
		fails.append(
			"gather fields were %d/%s, expected 0/0"
			% [snap.gather_deposit_id, str(snap.gather_progress)]
		)


func _test_gather_channel_while_mining(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	var deposit := Deposit.new()
	deposit.id = sim.world.alloc_id()
	deposit.kind = Types.ResourceKind.SCRAP
	deposit.tile = sim.world.world_to_tile(player.pos)
	deposit.remaining = 4
	sim.world.deposits[deposit.id] = deposit
	var ticks := 10
	for _i in ticks:
		var cmd := InputCommand.new()
		cmd.interact = true
		sim.enqueue(cmd)
		sim.tick()
	var snap := sim.snapshot()
	var expected := float(ticks) * Constants.SIM_DT
	if snap.gather_deposit_id != deposit.id:
		fails.append("gather_deposit_id is %d, expected %d" % [snap.gather_deposit_id, deposit.id])
	if not is_equal_approx(snap.gather_progress, expected):
		fails.append("gather_progress is %s, expected %s" % [str(snap.gather_progress), str(expected)])
	var walk := InputCommand.new()
	walk.interact = true
	walk.move = Vector2.RIGHT
	sim.enqueue(walk)
	sim.tick()
	var cleared := sim.snapshot()
	if cleared.gather_deposit_id != 0 or cleared.gather_progress != 0.0:
		fails.append(
			"walking should hide gather bar, got %d/%s"
			% [cleared.gather_deposit_id, str(cleared.gather_progress)]
		)


func _test_player_o2_copied(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	player.o2 = 17.5
	var snap := sim.snapshot()
	player.o2 = 3.0
	if not is_equal_approx(snap.player_o2, 17.5):
		fails.append("snapshot player_o2 is %s, expected 17.5" % str(snap.player_o2))
	if not is_equal_approx(snap.player_o2_max, Constants.PLAYER_O2_MAX):
		fails.append("snapshot player_o2_max is %s" % str(snap.player_o2_max))


func _test_oxygen_and_hunger_flags(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	sim.oxygen_failed = true
	sim.hunger_starving = true
	var snap := sim.snapshot()
	if not snap.oxygen_failed:
		fails.append("snapshot missed oxygen_failed")
	if not snap.hunger_starving:
		fails.append("snapshot missed hunger_starving")
	sim.oxygen_failed = false
	sim.hunger_starving = false
	if not snap.oxygen_failed or not snap.hunger_starving:
		fails.append("snapshot oxygen/hunger flags mutated with sim")


func _test_tiles_recopy_on_generation(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	if "occupancy_generation" in sim.world:
		fails.append("tiles_generation is not occupancy; do not add occupancy_generation")
	var first := sim.snapshot()
	var gen := sim.world.tiles_generation
	if first.tiles_generation != gen:
		fails.append("snapshot tiles_generation is %d, expected %d" % [first.tiles_generation, gen])
	var second := sim.snapshot()
	if second.tiles_generation != gen or second.tiles != first.tiles:
		fails.append("snapshot tiles changed without tiles_generation change")
	var wall := Building.new()
	wall.id = sim.world.alloc_id()
	wall.kind = Types.BuildingKind.WALL
	wall.faction = Types.Faction.PLAYER
	wall.origin_tile = Vector2i(2, 2)
	wall.hp = Constants.WALL_HP
	sim.world.buildings[wall.id] = wall
	sim.world.occupy(wall)
	if sim.world.tiles_generation != gen:
		fails.append("occupy must not bump tiles_generation")
	sim.world.vacate(wall)
	if sim.world.tiles_generation != gen:
		fails.append("vacate must not bump tiles_generation")
	var next_terrain := Types.TileTerrain.ROCK
	if sim.world.get_terrain(0, 0) == Types.TileTerrain.ROCK:
		next_terrain = Types.TileTerrain.EMPTY
	sim.world.set_terrain(0, 0, next_terrain)
	if sim.world.tiles_generation == gen:
		fails.append("set_terrain should bump tiles_generation")
	var third := sim.snapshot()
	if third.tiles_generation != sim.world.tiles_generation:
		fails.append("snapshot tiles_generation stale after terrain change")
	if third.tiles[0] != sim.world.tiles[0]:
		fails.append("snapshot tiles stale after tiles_generation change")


func _test_last_tick_usec_to_sim_ms(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	sim.tick()
	if sim.last_tick_usec < 0:
		fails.append("last_tick_usec is %d, expected >= 0" % sim.last_tick_usec)
	var snap := sim.snapshot()
	var expected := float(sim.last_tick_usec) * 0.001
	if not is_equal_approx(snap.sim_ms, expected):
		fails.append("sim_ms is %s, expected %s" % [str(snap.sim_ms), str(expected)])
	if snap.completed_this_tick != sim.path_queue.completed_this_tick:
		fails.append(
			"completed_this_tick is %d, expected %d"
			% [snap.completed_this_tick, sim.path_queue.completed_this_tick]
		)


func _player_rec(snap: SimSnapshot) -> Dictionary:
	for rec in snap.units:
		if rec.get("kind", -1) == Types.UnitKind.PLAYER:
			return rec
	return {}


func _rec_by_id(records: Array, id: int) -> Dictionary:
	for rec in records:
		if rec is Dictionary and int(rec.get("id", -1)) == id:
			return rec
	return {}


func _player_habitat(sim: Sim) -> Building:
	for building in sim.world.buildings.values():
		if building.kind == Types.BuildingKind.HABITAT and building.faction == Types.Faction.PLAYER:
			return building
	return null
