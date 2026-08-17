extends RefCounted

const _AWAKE := Vector2i(22, 176)


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_first_local_raid(fails)
	_test_loot_channel(fails)
	_test_next_raid_advances(fails)
	_test_out_of_aggro_does_not_spawn(fails)
	_test_habitat_only_aggro(fails)
	_test_blocked_siege_damages_wall(fails)
	_test_siege_commits_to_depot(fails)
	_test_chase_does_not_leave_siege(fails)
	_test_hauling_definition(fails)
	_test_hauling_leaves_siege_for_home(fails)
	_test_missing_home_dead_drops(fails)
	_test_skipped_spawn_advances_clock(fails)
	_test_siege_rifle_damages_from_range(fails)
	_test_boxed_in_by_workshop_while_hauling(fails)
	_test_hauling_includes_food(fails)
	_test_hauling_smashes_farm(fails)
	_test_first_raid_without_ore_survivable(fails)
	return fails


func _test_first_local_raid(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var camp := _near_camp(sim.world)
	if camp == null:
		fails.append("first raid missing a near camp in [40, 48]")
		return
	var before := _raider_count(sim)
	_tick(sim, _ticks_for(Constants.CAMP_RAID_FIRST) - 1)
	if _raider_count(sim) != before:
		fails.append("raiders spawned before t=CAMP_RAID_FIRST: %d" % _raider_count(sim))
	_tick(sim, 1)
	if not is_equal_approx(sim.time, Constants.CAMP_RAID_FIRST):
		fails.append(
			"time after first-raid tick is %s, expected %s"
			% [sim.time, Constants.CAMP_RAID_FIRST]
		)
	var spawned := _raiders_for_camp(sim, camp)
	if spawned.size() == 0 or spawned.size() > Constants.CAMP_RAID_SIZE:
		fails.append(
			"near camp at t=CAMP_RAID_FIRST spawned %d, expected 1..%d"
			% [spawned.size(), Constants.CAMP_RAID_SIZE]
		)
		return
	var pos0: Array[Vector2] = []
	for raider in spawned:
		pos0.append(raider.pos)
	_tick(sim, 8)
	var moved := false
	for i in spawned.size():
		if spawned[i].pos != pos0[i]:
			moved = true
			break
	if not moved:
		fails.append("near-camp raiders did not change pos (should be awake at Chebyshev 40–48)")


func _test_loot_channel(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("loot test missing player depot")
		return
	var scrap0 := depot.inventory.scrap
	var raider := _inject_raider(sim, sim.world.tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	))
	_tick(sim, _ticks_for(Constants.RAIDER_LOOT_CHANNEL))
	if raider.inventory.scrap <= 0:
		fails.append("raider adjacent for 3s did not increase carry")
	if depot.inventory.scrap >= scrap0:
		fails.append("raider adjacent for 3s did not reduce depot stock")
	if raider.inventory.ice != 0:
		fails.append("raider looted ice from a depot")


func _test_next_raid_advances(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var camp := _near_camp(sim.world)
	if camp == null:
		fails.append("next_raid_at test missing a near camp")
		return
	_tick(sim, _ticks_for(Constants.CAMP_RAID_FIRST))
	var expected := Constants.CAMP_RAID_FIRST + Constants.CAMP_RAID_PERIOD
	if not is_equal_approx(camp.next_raid_at, expected):
		fails.append(
			"near camp next_raid_at is %s, expected %s"
			% [camp.next_raid_at, expected]
		)
	var snap := sim.snapshot()
	if not is_equal_approx(snap.next_raid_at, expected):
		fails.append(
			"snapshot next_raid_at is %s, expected %s"
			% [snap.next_raid_at, expected]
		)


func _test_blocked_siege_damages_wall(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var tile := _AWAKE
	var walls := _box_with_walls(sim, tile)
	if walls.is_empty():
		fails.append("could not box raider with walls")
		return
	_inject_raider(sim, sim.world.tile_center(tile.x, tile.y))
	var hp0 := _wall_hp_sum(walls)
	_tick(sim, 2)
	var raider := _first_raider(sim)
	if raider == null or raider.ai_state != Types.RaiderState.SIEGE:
		fails.append(
			"blocked A* should enter SIEGE, got %s"
			% str(raider.ai_state if raider else raider)
		)
	if _wall_hp_sum(walls) >= hp0:
		fails.append("sieging raider did not damage a blocking wall")


func _test_siege_commits_to_depot(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var tile := _AWAKE
	var walls := _box_with_walls(sim, tile)
	var raider := _inject_raider(sim, sim.world.tile_center(tile.x, tile.y))
	_tick(sim, 1)
	for wall in walls:
		wall.hp = 0
	_tick(sim, 1)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("non-hauling raider left SIEGE after walls died, got %d" % raider.ai_state)
	raider.pos = sim.world.tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	)
	raider.weapon_cooldown = 0.0
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("commit test missing player depot")
		return
	if not _path_to_depot_open(sim, raider, depot):
		fails.append("A* to depot should be open after walls die")
	var hp0 := depot.hp
	_tick(sim, 2)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("non-hauling SIEGE must stay after A* reopens, got %d" % raider.ai_state)
	if depot.hp >= hp0:
		fails.append("committed siege did not damage the player Depot")


func _test_chase_does_not_leave_siege(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var tile := _AWAKE
	var walls := _box_with_walls(sim, tile)
	if walls.is_empty():
		fails.append("chase test could not box raider")
		return
	var raider := _inject_raider(sim, sim.world.tile_center(tile.x, tile.y))
	_tick(sim, 1)
	var player := sim.get_player()
	player.pos = raider.pos + Vector2(8, 0)
	_tick(sim, 2)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("player in RAIDER_CHASE_RADIUS pulled sieging raider to %d" % raider.ai_state)


func _test_hauling_definition(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var raider := _inject_raider(sim, sim.world.tile_center(_AWAKE.x, _AWAKE.y))
	if AiRaider.is_hauling(raider):
		fails.append("empty carry should not be hauling")
	raider.inventory.scrap = 1
	if not AiRaider.is_hauling(raider):
		fails.append("scrap > 0 should be hauling")
	raider.inventory.scrap = 0
	raider.inventory.ice = 1
	if not AiRaider.is_hauling(raider):
		fails.append("ice > 0 should be hauling")


func _test_hauling_leaves_siege_for_home(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	var raider := _inject_raider(sim, sim.world.tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	))
	raider.ai_state = Types.RaiderState.SIEGE
	raider.inventory.scrap = 1
	var hp0 := depot.hp if depot != null else 0
	_tick(sim, 2)
	if not sim.world.units.has(raider.id):
		fails.append("hauling raider was deleted instead of leaving SIEGE")
		return
	if raider.ai_state != Types.RaiderState.PATH_HOME:
		fails.append("hauling raider with open home A* should PATH_HOME, got %d" % raider.ai_state)
	if depot != null and depot.hp < hp0:
		fails.append("hauling raider melee'd the player Depot")


func _test_missing_home_dead_drops(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var pos := sim.world.tile_center(_AWAKE.x + 10, _AWAKE.y)
	var raider := _inject_raider(sim, pos)
	raider.ai_state = Types.RaiderState.PATH_HOME
	raider.inventory.scrap = 2
	raider.inventory.ice = 1
	_kill_enemy_depots(sim)
	_tick(sim, 1)
	if sim.world.units.has(raider.id):
		fails.append("hauling raider should be deleted when home depot is missing")
	var pile := _loot_at(sim.world, pos)
	if pile == null:
		fails.append("missing home depot did not drop loot at last position")
	elif pile.inventory.scrap != 2 or pile.inventory.ice != 1:
		fails.append("dead-drop loot is %d/%d, expected 2/1" % [pile.inventory.scrap, pile.inventory.ice])


func _test_skipped_spawn_advances_clock(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var camp := _far_camp(sim)
	if camp == null:
		fails.append("unaggro clock test missing a far camp")
		return
	var before := _raider_count(sim)
	_tick(sim, _ticks_for(Constants.CAMP_RAID_FIRST))
	if _raiders_for_camp(sim, camp).size() != 0:
		fails.append("far camp dispatched while out of aggro")
	if _raider_count(sim) < before:
		fails.append("unaggro clock test lost raiders")
	var expected := Constants.CAMP_RAID_FIRST + Constants.CAMP_RAID_PERIOD
	if not is_equal_approx(camp.next_raid_at, expected):
		fails.append(
			"unaggro'd camp next_raid_at is %s, expected %s"
			% [camp.next_raid_at, expected]
		)


func _test_out_of_aggro_does_not_spawn(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var camp := _far_camp(sim)
	if camp == null:
		fails.append("out-of-aggro test missing a far camp")
		return
	_tick(sim, _ticks_for(Constants.CAMP_RAID_FIRST))
	if _raiders_for_camp(sim, camp).size() != 0:
		fails.append("camp out of aggro spawned raiders")
	if camp.ever_aggro:
		fails.append("far camp should not be ever_aggro from the starter pad")


func _test_habitat_only_aggro(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var camp := _near_camp(sim.world)
	if camp == null:
		fails.append("habitat-only aggro missing a near camp")
		return
	var player := sim.get_player()
	if player == null:
		fails.append("habitat-only aggro missing player")
		return
	player.pos = _tile_chebyshev_away(sim.world, camp.depot_tile, 80)
	_tick(sim, _ticks_for(Constants.CAMP_RAID_FIRST))
	var spawned := _raiders_for_camp(sim, camp)
	if spawned.is_empty():
		return
	for raider in spawned:
		if sim.world.is_unit_asleep(raider):
			fails.append("habitat-window raiders should stay active")
			return


func _test_siege_rifle_damages_from_range(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var wall_tile := Vector2i(_AWAKE.x, _AWAKE.y + 2)
	for x in range(_AWAKE.x, _AWAKE.x + 10):
		sim.world.set_terrain(x, wall_tile.y, Types.TileTerrain.EMPTY)
	var wall := _place_wall(sim, wall_tile)
	var aabb := sim.world.footprint_aabb(wall)
	var raider := _inject_raider(sim, Vector2(aabb.end.x + 200.0, aabb.get_center().y))
	raider.ai_state = Types.RaiderState.SIEGE
	var hp0 := wall.hp
	_tick(sim, 1)
	if _enemy_proj_count(sim) < 1:
		fails.append("siege raider should fire at a wall inside ENEMY_RIFLE_RANGE on the first tick")
	_tick(sim, 14)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("ranged siege left SIEGE, got %d" % raider.ai_state)
	if wall.hp >= hp0:
		fails.append("siege rifle did not damage a wall inside ENEMY_RIFLE_RANGE")
	if hp0 - wall.hp >= Constants.RAIDER_MELEE_BUILDING:
		fails.append("siege wall lost %d hp, expected rifle damage" % (hp0 - wall.hp))


func _test_hauling_includes_food(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var raider := _inject_raider(sim, sim.world.tile_center(_AWAKE.x, _AWAKE.y))
	raider.inventory.scrap = 0
	raider.inventory.ice = 0
	raider.inventory.ore = 0
	raider.inventory.parts = 0
	raider.inventory.food = 1
	if not AiRaider.is_hauling(raider):
		fails.append("food > 0 should be hauling")


func _test_hauling_smashes_farm(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var tile := _AWAKE
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	var farm := _place_farm(sim, Vector2i(tile.x + 1, tile.y))
	if farm == null:
		fails.append("could not place a farm for smash test")
		return
	var raider := _inject_raider(sim, sim.world.tile_center(tile.x, tile.y))
	raider.inventory.food = 1
	raider.ai_state = Types.RaiderState.SIEGE
	var hp0 := farm.hp
	_tick(sim, 6)
	if not sim.world.units.has(raider.id):
		fails.append("hauling raider next to a farm was deleted")
		return
	if farm.hp >= hp0:
		fails.append("hauling raider did not smash the farm")
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot != null and depot.hp < Constants.DEPOT_HP:
		fails.append("hauling smash must not hit the player Depot")


func _test_boxed_in_by_workshop_while_hauling(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var tile := _AWAKE
	var shops := _box_with_workshops(sim, tile)
	if shops.is_empty():
		fails.append("could not box raider with workshops")
		return
	var raider := _inject_raider(sim, sim.world.tile_center(tile.x, tile.y))
	raider.inventory.scrap = 1
	var hp0 := _wall_hp_sum(shops)
	_tick(sim, 6)
	if not sim.world.units.has(raider.id):
		fails.append("hauling raider boxed by workshops was deleted")
		return
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append(
			"hauling raider boxed by workshops should SIEGE, got %d" % raider.ai_state
		)
	if _wall_hp_sum(shops) >= hp0:
		fails.append("hauling raider did not smash a boxing workshop")
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot != null and depot.hp < Constants.DEPOT_HP:
		fails.append("hauling smash must not hit the player Depot")


func _test_first_raid_without_ore_survivable(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	var habitat := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if depot == null or habitat == null:
		fails.append("first-raid setup missing depot/habitat")
		return
	if depot.inventory.ore != 0 or depot.inventory.parts != 0 or sim.techs_done != 0:
		fails.append("start loadout should have no ore, parts, or tech")
	if depot.inventory.scrap < Constants.TURRET_COST:
		fails.append("start scrap %d cannot buy a turret" % depot.inventory.scrap)
		return
	var turret_tile := _first_placeable(sim, Types.BuildingKind.TURRET)
	if turret_tile.x < 0 or not Rules.try_place(sim.world, sim, Types.BuildingKind.TURRET, turret_tile):
		fails.append("could not place a start-scrap turret")
		return
	if depot.inventory.ore != 0 or depot.inventory.parts != 0 or sim.techs_done != 0:
		fails.append("turret placement spent ore/parts or unlocked tech")
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.RAIDER_CARRY_SCRAP)
	_banish_player(sim)
	var stand := sim.world.tile_center(depot.origin_tile.x + 2, depot.origin_tile.y)
	for _i in Constants.CAMP_RAID_SIZE:
		_inject_raider(sim, stand)
	var habitat_hp0 := habitat.hp
	_tick(sim, _ticks_for(Constants.RAIDER_LOOT_CHANNEL))
	if habitat.hp <= 0 or not sim.world.buildings.has(habitat.id):
		fails.append("first raid without ore destroyed the habitat")
	if sim.outcome != Types.Outcome.NONE:
		fails.append("first raid without ore locked outcome %d" % sim.outcome)
	if habitat.hp < habitat_hp0 and habitat_hp0 - habitat.hp >= habitat_hp0:
		fails.append("first raid stripped the habitat")
	var hauled := false
	for unit in sim.world.units.values():
		if unit.kind == Types.UnitKind.RAIDER and AiRaider.is_hauling(unit):
			hauled = true
			break
	if not hauled:
		fails.append("open-road first raid should loot and leave")


func _ready_sim() -> Sim:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	return sim


func _tick(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.tick()


func _ticks_for(seconds: float) -> int:
	return int(round(seconds / Constants.SIM_DT))


func _banish_player(sim: Sim) -> void:
	var player := sim.get_player()
	if player != null:
		player.pos = Vector2(16, 16)


func _inject_raider(sim: Sim, pos: Vector2) -> Unit:
	var raider := Unit.new()
	raider.id = sim.world.alloc_id()
	raider.kind = Types.UnitKind.RAIDER
	raider.faction = Types.Faction.ENEMY
	raider.pos = pos
	raider.hp = Constants.RAIDER_HP
	raider.hp_max = Constants.RAIDER_HP
	raider.radius = Constants.RAIDER_RADIUS
	raider.aim = Vector2(1, 0)
	raider.alive = true
	raider.ai_state = Types.RaiderState.SPAWNED
	raider.inventory = Unit.inventory_for(Types.UnitKind.RAIDER)
	raider.stuck_last_pos = pos
	sim.world.units[raider.id] = raider
	return raider


func _box_with_walls(sim: Sim, tile: Vector2i) -> Array[Building]:
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	var walls: Array[Building] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for d in offsets:
		var at := tile + d
		if not sim.world.in_bounds(at.x, at.y):
			continue
		sim.world.set_terrain(at.x, at.y, Types.TileTerrain.EMPTY)
		var occupant := sim.world.building_at(at.x, at.y)
		if occupant != null:
			sim.world.vacate(occupant)
			sim.world.buildings.erase(occupant.id)
		walls.append(_place_wall(sim, at))
	return walls


func _box_with_workshops(sim: Sim, tile: Vector2i) -> Array[Building]:
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	var shops: Array[Building] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for d in offsets:
		var at := tile + d
		if not sim.world.in_bounds(at.x, at.y):
			continue
		sim.world.set_terrain(at.x, at.y, Types.TileTerrain.EMPTY)
		var occupant := sim.world.building_at(at.x, at.y)
		if occupant != null:
			sim.world.vacate(occupant)
			sim.world.buildings.erase(occupant.id)
		shops.append(_place_workshop(sim, at))
	return shops


func _place_farm(sim: Sim, tile: Vector2i) -> Building:
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	sim.world.set_terrain(tile.x + 1, tile.y, Types.TileTerrain.EMPTY)
	sim.world.set_terrain(tile.x, tile.y + 1, Types.TileTerrain.EMPTY)
	sim.world.set_terrain(tile.x + 1, tile.y + 1, Types.TileTerrain.EMPTY)
	for dy in 2:
		for dx in 2:
			var occupant := sim.world.building_at(tile.x + dx, tile.y + dy)
			if occupant != null:
				sim.world.vacate(occupant)
				sim.world.buildings.erase(occupant.id)
	var building := Building.new()
	building.id = sim.world.alloc_id()
	building.kind = Types.BuildingKind.FARM
	building.faction = Types.Faction.PLAYER
	building.origin_tile = tile
	building.hp = Constants.FARM_HP
	building.hp_max = Constants.FARM_HP
	sim.world.buildings[building.id] = building
	sim.world.occupy(building)
	return building


func _place_workshop(sim: Sim, tile: Vector2i) -> Building:
	var building := Building.new()
	building.id = sim.world.alloc_id()
	building.kind = Types.BuildingKind.WORKSHOP
	building.faction = Types.Faction.PLAYER
	building.origin_tile = tile
	building.hp = Constants.WORKSHOP_HP
	building.hp_max = Constants.WORKSHOP_HP
	sim.world.buildings[building.id] = building
	sim.world.occupy(building)
	return building


func _place_wall(sim: Sim, tile: Vector2i) -> Building:
	var building := Building.new()
	building.id = sim.world.alloc_id()
	building.kind = Types.BuildingKind.WALL
	building.faction = Types.Faction.PLAYER
	building.origin_tile = tile
	building.hp = Constants.WALL_HP
	building.hp_max = Constants.WALL_HP
	sim.world.buildings[building.id] = building
	sim.world.occupy(building)
	return building


func _raider_count(sim: Sim) -> int:
	var n := 0
	for unit in sim.world.units.values():
		if unit.kind == Types.UnitKind.RAIDER:
			n += 1
	return n


func _raiders_for_camp(sim: Sim, camp: World.Camp) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit in sim.world.units.values():
		if unit.kind != Types.UnitKind.RAIDER:
			continue
		if unit.home_depot_id == camp.depot_id:
			out.append(unit)
	return out


func _near_camp(world: World) -> World.Camp:
	for raw in world.camps:
		var camp := raw as World.Camp
		if camp == null:
			continue
		var d := _chebyshev(camp.depot_tile, Constants.PLAYER_SPAWN_TILE)
		if d >= Constants.PLAYER_SAFE_RADIUS and d <= Constants.CAMP_AGGRO_TILES:
			return camp
	return null


func _far_camp(sim: Sim) -> World.Camp:
	var habitat := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	var habitat_tile := habitat.origin_tile if habitat != null else Constants.PLAYER_HABITAT_TILE
	var player_tile := Constants.PLAYER_SPAWN_TILE
	var player := sim.get_player()
	if player != null:
		player_tile = sim.world.world_to_tile(player.pos)
	for raw in sim.world.camps:
		var camp := raw as World.Camp
		if camp == null:
			continue
		if _chebyshev(camp.depot_tile, player_tile) <= Constants.CAMP_AGGRO_TILES:
			continue
		if _chebyshev(camp.depot_tile, habitat_tile) <= Constants.CAMP_AGGRO_TILES:
			continue
		return camp
	return null


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _tile_chebyshev_away(world: World, origin: Vector2i, dist: int) -> Vector2:
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
	]
	for d in dirs:
		var tile := origin + d * dist
		if world.in_bounds(tile.x, tile.y):
			return world.tile_center(tile.x, tile.y)
	return world.tile_center(0, 0)


func _first_raider(sim: Sim) -> Unit:
	for unit in sim.world.units.values():
		if unit.kind == Types.UnitKind.RAIDER:
			return unit
	return null


func _kill_enemy_depots(sim: Sim) -> void:
	for building in sim.world.buildings.values():
		if building.kind == Types.BuildingKind.DEPOT and building.faction == Types.Faction.ENEMY:
			building.hp = 0


func _remove_enemy_depots(sim: Sim) -> void:
	var ids: Array[int] = []
	for building in sim.world.buildings.values():
		if building.kind == Types.BuildingKind.DEPOT and building.faction == Types.Faction.ENEMY:
			ids.append(building.id)
	for id in ids:
		var building: Building = sim.world.buildings.get(id)
		if building == null:
			continue
		sim.world.vacate(building)
		sim.world.buildings.erase(id)


func _living(world: World, faction: int, kind: int) -> Building:
	for building in world.buildings.values():
		if building.kind == kind and building.faction == faction and building.hp > 0:
			return building
	return null


func _wall_hp_sum(walls: Array[Building]) -> int:
	var total := 0
	for wall in walls:
		if wall != null:
			total += wall.hp
	return total


func _path_to_depot_open(sim: Sim, raider: Unit, depot: Building) -> bool:
	var start := sim.world.world_to_tile(raider.pos)
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for d in dirs:
		for dy in 2:
			for dx in 2:
				var n := Vector2i(depot.origin_tile.x + dx + d.x, depot.origin_tile.y + dy + d.y)
				if not sim.world.is_walkable(n.x, n.y):
					continue
				if not Pathfind.find_path(sim.world, start, n).is_empty():
					return true
	return false


func _loot_at(world: World, pos: Vector2) -> Loot:
	for pile in world.loot.values():
		if pile.pos.is_equal_approx(pos):
			return pile
	return null


func _enemy_proj_count(sim: Sim) -> int:
	var n := 0
	for proj in sim.world.projectiles.values():
		if proj.faction == Types.Faction.ENEMY:
			n += 1
	return n


func _first_placeable(sim: Sim, kind: int) -> Vector2i:
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var tile := Vector2i(x, y)
			if Rules.can_place(sim.world, sim, kind, tile):
				return tile
	return Vector2i(-1, -1)
