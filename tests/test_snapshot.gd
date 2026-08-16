extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_defaults_and_player_inventory(fails)
	_test_copies_world_entities(fails)
	_test_inventory_is_copied(fails)
	_test_living_depot_ice_empty(fails)
	_test_player_respawn_timer(fails)
	return fails


func _test_defaults_and_player_inventory(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var snap := sim.snapshot()
	if snap.next_wave_at != 0.0 or snap.wave_index != 0 or snap.banner_timer != 0.0:
		fails.append(
			"director fields were %s/%d/%s, expected 0/0/0"
			% [str(snap.next_wave_at), snap.wave_index, str(snap.banner_timer)]
		)
	if snap.player_respawn_timer != 0.0:
		fails.append("player_respawn_timer is %s, expected 0" % str(snap.player_respawn_timer))
	if snap.player_zero_ice_timer != 0.0 or snap.enemy_zero_ice_timer != 0.0:
		fails.append(
			"zero_ice timers were %s/%s, expected 0/0"
			% [str(snap.player_zero_ice_timer), str(snap.enemy_zero_ice_timer)]
		)
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
	depot.inventory = Inventory.new(Constants.DEPOT_CAP_SCRAP, Constants.DEPOT_CAP_ICE)
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
		if not binv is Dictionary or int(binv.get("scrap", 0)) != 7 or int(binv.get("ice", 0)) != 4:
			fails.append("building inventory %s, expected scrap 7 ice 4" % str(binv))
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


func _test_living_depot_ice_empty(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	_clear_depots(sim)
	var player_depot := _make_depot(sim, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 0)
	sim.world.buildings[player_depot.id] = player_depot
	var enemy_depot := _make_depot(sim, Types.Faction.ENEMY, Constants.ENEMY_DEPOT_TILE, 4)
	sim.world.buildings[enemy_depot.id] = enemy_depot
	var snap := sim.snapshot()
	if not snap.player_living_depot_ice_empty:
		fails.append("player living depot with 0 ice should set ice-empty")
	if snap.enemy_living_depot_ice_empty:
		fails.append("enemy living depot with ice 4 should not set ice-empty")
	player_depot.hp = 0
	enemy_depot.inventory.remove(Types.ResourceKind.ICE, 4)
	var dead := sim.snapshot()
	if dead.player_living_depot_ice_empty:
		fails.append("dead player depot should not set ice-empty")
	if not dead.enemy_living_depot_ice_empty:
		fails.append("living enemy depot with 0 ice should set ice-empty")


func _test_player_respawn_timer(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var player := sim.get_player()
	player.alive = false
	player.respawn_timer = 2.5
	var snap := sim.snapshot()
	if not is_equal_approx(snap.player_respawn_timer, 2.5):
		fails.append("player_respawn_timer is %s, expected 2.5" % str(snap.player_respawn_timer))


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


func _clear_depots(sim: Sim) -> void:
	var remove: Array = []
	for building in sim.world.buildings.values():
		if building.kind == Types.BuildingKind.DEPOT:
			remove.append(building.id)
	for id in remove:
		sim.world.buildings.erase(id)


func _make_depot(sim: Sim, faction: int, tile: Vector2i, ice: int) -> Building:
	var depot := Building.new()
	depot.id = sim.world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = faction
	depot.origin_tile = tile
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Inventory.new(Constants.DEPOT_CAP_SCRAP, Constants.DEPOT_CAP_ICE)
	if ice > 0:
		depot.inventory.add(Types.ResourceKind.ICE, ice)
	return depot
