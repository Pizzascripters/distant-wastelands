extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_wave_at_60(fails)
	_test_loot_channel(fails)
	_test_next_wave_advances(fails)
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


func _test_wave_at_60(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var before := _raider_count(sim)
	_tick(sim, _ticks_for(Constants.FIRST_WAVE_AT) - 1)
	if _raider_count(sim) != before:
		fails.append("raiders spawned before t=60: %d" % _raider_count(sim))
	_tick(sim, 1)
	if not is_equal_approx(sim.time, Constants.FIRST_WAVE_AT):
		fails.append("time after first-wave tick is %s, expected %s" % [sim.time, Constants.FIRST_WAVE_AT])
	if _raider_count(sim) != before + 2:
		fails.append("at t=60 expected 2 raiders, got %d" % _raider_count(sim))


func _test_loot_channel(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("loot test missing player depot")
		return
	var scrap0 := depot.inventory.scrap
	var ice0 := depot.inventory.ice
	var raider := _inject_raider(sim, sim.world.tile_center(8, 52))
	_tick(sim, _ticks_for(Constants.RAIDER_LOOT_CHANNEL))
	if raider.inventory.scrap <= 0 and raider.inventory.ice <= 0:
		fails.append("raider adjacent for 3s did not increase carry")
	if depot.inventory.scrap >= scrap0 and depot.inventory.ice >= ice0:
		fails.append("raider adjacent for 3s did not reduce depot stock")


func _test_next_wave_advances(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_tick(sim, _ticks_for(Constants.FIRST_WAVE_AT))
	var expected := Constants.FIRST_WAVE_AT + Constants.WAVE_PERIOD
	if not is_equal_approx(sim.director.next_wave_at, expected):
		fails.append(
			"next_wave_at is %s, expected %s"
			% [sim.director.next_wave_at, expected]
		)


func _test_blocked_siege_damages_wall(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var tile := Vector2i(20, 20)
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
	var tile := Vector2i(20, 20)
	var walls := _box_with_walls(sim, tile)
	var raider := _inject_raider(sim, sim.world.tile_center(tile.x, tile.y))
	_tick(sim, 1)
	for wall in walls:
		wall.hp = 0
	_tick(sim, 1)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("non-hauling raider left SIEGE after walls died, got %d" % raider.ai_state)
	raider.pos = sim.world.tile_center(8, 52)
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
	var tile := Vector2i(20, 20)
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
	var raider := _inject_raider(sim, sim.world.tile_center(20, 20))
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
	var raider := _inject_raider(sim, sim.world.tile_center(8, 52))
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
	var pos := sim.world.tile_center(30, 30)
	var raider := _inject_raider(sim, pos)
	raider.ai_state = Types.RaiderState.PATH_HOME
	raider.inventory.scrap = 2
	raider.inventory.ice = 1
	var home := _living(sim.world, Types.Faction.ENEMY, Types.BuildingKind.DEPOT)
	if home != null:
		home.hp = 0
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
	var home := _living(sim.world, Types.Faction.ENEMY, Types.BuildingKind.DEPOT)
	if home != null:
		sim.world.vacate(home)
		sim.world.buildings.erase(home.id)
	_tick(sim, _ticks_for(Constants.FIRST_WAVE_AT))
	if _raider_count(sim) != 0:
		fails.append("skipped spawn created %d raiders" % _raider_count(sim))
	var expected := Constants.FIRST_WAVE_AT + Constants.WAVE_PERIOD
	if not is_equal_approx(sim.director.next_wave_at, expected):
		fails.append(
			"skipped spawn next_wave_at is %s, expected %s"
			% [sim.director.next_wave_at, expected]
		)


func _test_siege_rifle_damages_from_range(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var wall_tile := Vector2i(20, 30)
	for x in range(20, 30):
		sim.world.set_terrain(x, 30, Types.TileTerrain.EMPTY)
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
	var raider := _inject_raider(sim, sim.world.tile_center(20, 20))
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
	var tile := Vector2i(20, 20)
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	var farm := _place_farm(sim, Vector2i(21, 20))
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
	var tile := Vector2i(20, 20)
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
	_banish_player(sim)
	var stand := sim.world.tile_center(depot.origin_tile.x - 1, depot.origin_tile.y)
	for _i in Constants.WAVE_BASE:
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


func _first_raider(sim: Sim) -> Unit:
	for unit in sim.world.units.values():
		if unit.kind == Types.UnitKind.RAIDER:
			return unit
	return null


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
