extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_spawned_paths_to_depot(fails)
	_test_missing_depot_goes_to_habitat(fails)
	_test_adjacent_depot_loots(fails)
	_test_blocked_path_enters_siege(fails)
	_test_chase_from_open_road(fails)
	_test_chase_does_not_leave_siege(fails)
	_test_non_hauling_siege_commits_to_depot(fails)
	_test_hauling_definition(fails)
	_test_hauling_siege_goes_home(fails)
	_test_hauling_siege_rechecks_home(fails)
	_test_hauling_stuck_stays_siege(fails)
	_test_dead_drop_on_missing_home(fails)
	_test_home_despawn_deposits_and_leftover(fails)
	_test_loot_channel_transfers(fails)
	_test_loot_one_resource_goes_home(fails)
	_test_loot_depot_died(fails)
	_test_stuck_enters_siege(fails)
	_test_stagger_does_not_siege(fails)
	return fails


func _test_spawned_paths_to_depot(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	raider.pos = _world(ctx).tile_center(20, 52)
	_pump(ctx)
	if raider.ai_state != Types.RaiderState.PATH_TO_DEPOT:
		fails.append("SPAWNED should enter PATH_TO_DEPOT, got %d" % raider.ai_state)
	if raider.path.is_empty():
		fails.append("PATH_TO_DEPOT should cache an A* path")
	if not is_equal_approx(raider.path_recalc_in, Constants.PATH_RECALC):
		fails.append("path_recalc_in is %s, expected %s" % [str(raider.path_recalc_in), str(Constants.PATH_RECALC)])
	_pump(ctx)
	if raider.vel == Vector2.ZERO:
		fails.append("PATH_TO_DEPOT should seek along A*")
	var cached: Array[Vector2i] = raider.path.duplicate()
	var recalc := raider.path_recalc_in
	_pump(ctx)
	if raider.path_recalc_in != recalc:
		fails.append("cached path think should not reset path_recalc_in")
	if raider.path != cached:
		fails.append("second think should reuse the cached path")


func _test_missing_depot_goes_to_habitat(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_habitat(ctx, Types.Faction.PLAYER, Constants.PLAYER_HABITAT_TILE)
	raider.pos = _world(ctx).tile_center(20, 52)
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.PATH_TO_HABITAT:
		fails.append("missing player depot should go PATH_TO_HABITAT, got %d" % raider.ai_state)


func _test_adjacent_depot_loots(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	raider.pos = _world(ctx).tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	)
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.LOOT:
		fails.append("adjacent depot should enter LOOT, got %d" % raider.ai_state)


func _test_blocked_path_enters_siege(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	_box_in(_world(ctx), 20, 20)
	raider.pos = _world(ctx).tile_center(20, 20)
	_pump(ctx)
	_pump(ctx)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("boxed-in raider should enter SIEGE, got %d" % raider.ai_state)


func _test_chase_from_open_road(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	var player := _player(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	raider.pos = _world(ctx).tile_center(20, 52)
	player.pos = raider.pos + Vector2(32, 0)
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.CHASE:
		fails.append("open-road player in range should CHASE, got %d" % raider.ai_state)


func _test_chase_does_not_leave_siege(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	var player := _player(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	var wall := _place_wall(ctx, Vector2i(12, 52))
	raider.ai_state = Types.RaiderState.SIEGE
	raider.pos = _world(ctx).tile_center(12, 51)
	player.pos = raider.pos + Vector2(8, 0)
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("player in range must not pull raider out of SIEGE, got %d" % raider.ai_state)
	if raider.siege_target_id != wall.id:
		fails.append("SIEGE should target the wall, got %d" % raider.siege_target_id)


func _test_non_hauling_siege_commits_to_depot(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	var depot := _place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	raider.ai_state = Types.RaiderState.SIEGE
	raider.pos = _world(ctx).tile_center(20, 52)
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("non-hauling SIEGE should stay after path opens, got %d" % raider.ai_state)
	if raider.siege_target_id != depot.id:
		fails.append("after walls die, SIEGE target should be depot %d, got %d" % [depot.id, raider.siege_target_id])


func _test_hauling_definition(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	if AiRaider.is_hauling(raider):
		fails.append("empty carry should not be hauling")
	raider.inventory.scrap = 1
	if not AiRaider.is_hauling(raider):
		fails.append("scrap > 0 should be hauling")
	raider.inventory.scrap = 0
	raider.inventory.ice = 2
	if not AiRaider.is_hauling(raider):
		fails.append("ice > 0 should be hauling")


func _test_hauling_siege_goes_home(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	_place_depot(ctx, Types.Faction.ENEMY, Constants.ENEMY_DEPOT_TILE, 20, 20)
	raider.ai_state = Types.RaiderState.SIEGE
	raider.inventory.scrap = 2
	raider.pos = _world(ctx).tile_center(20, 52)
	_pump(ctx)
	_pump(ctx)
	if raider.ai_state != Types.RaiderState.PATH_HOME:
		fails.append("hauling SIEGE with open home A* should PATH_HOME, got %d" % raider.ai_state)
	var player_depot := _living_player_depot(ctx)
	if raider.siege_target_id == player_depot.id:
		fails.append("hauling raider should not melee the player depot")


func _test_hauling_siege_rechecks_home(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	var world := _world(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	_place_depot(ctx, Types.Faction.ENEMY, Constants.ENEMY_DEPOT_TILE, 20, 20)
	var wall := _place_wall(ctx, Vector2i(5, 5))
	_box_in(world, 5, 5)
	_seal_building(world, Constants.ENEMY_DEPOT_TILE, 2)
	raider.ai_state = Types.RaiderState.SIEGE
	raider.inventory.scrap = 2
	raider.pos = world.tile_center(20, 52)
	_pump(ctx)
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("hauling SIEGE should stay while home A* is empty, got %d" % raider.ai_state)
	_unseal_building(world, Constants.ENEMY_DEPOT_TILE, 2)
	var wait := int(Constants.PATH_RECALC / Constants.SIM_DT) + 2
	for _i in wait:
		_pump(ctx)
	if raider.ai_state != Types.RaiderState.PATH_HOME:
		fails.append("hauling SIEGE should PATH_HOME after home A* reopens, got %d" % raider.ai_state)
	if raider.siege_target_id == wall.id and raider.ai_state == Types.RaiderState.SIEGE:
		fails.append("empty smash path must not block the home A* recheck")


func _test_hauling_stuck_stays_siege(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	_place_depot(ctx, Types.Faction.ENEMY, Constants.ENEMY_DEPOT_TILE, 20, 20)
	var wall := _place_wall(ctx, Vector2i(12, 52))
	raider.ai_state = Types.RaiderState.PATH_HOME
	raider.inventory.scrap = 2
	raider.stuck_timer = Constants.RAIDER_STUCK_TIME
	raider.pos = _world(ctx).tile_center(12, 51)
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("hauling PATH_HOME while stuck should settle in SIEGE, got %d" % raider.ai_state)
	if raider.siege_target_id != wall.id:
		fails.append("stuck hauling SIEGE should melee the wall, got %d" % raider.siege_target_id)
	if raider.path.is_empty() and raider.vel == Vector2.ZERO and raider.get_meta(AiRaider.MELEE_TARGET_META, 0) == 0:
		fails.append("stuck hauling SIEGE should write movement or melee intent")


func _test_dead_drop_on_missing_home(fails: PackedStringArray) -> void:
	var ctx := _context()
	var world := _world(ctx)
	var raider := _raider(ctx)
	raider.ai_state = Types.RaiderState.PATH_HOME
	raider.inventory.scrap = 3
	raider.inventory.ice = 1
	var pos: Vector2 = world.tile_center(30, 30)
	raider.pos = pos
	var rid: int = raider.id
	AiRaider.think(raider, _sim(ctx))
	if world.units.has(rid):
		fails.append("DEAD_DROP should delete the raider")
	if world.loot.is_empty():
		fails.append("DEAD_DROP should drop loot at feet")
		return
	var pile: Loot = world.loot.values()[0]
	if pile.pos != pos:
		fails.append("DEAD_DROP loot pos %s != last pos %s" % [pile.pos, pos])
	if pile.inventory.scrap != 3 or pile.inventory.ice != 1:
		fails.append("DEAD_DROP loot was %d/%d, expected 3/1" % [pile.inventory.scrap, pile.inventory.ice])


func _test_home_despawn_deposits_and_leftover(fails: PackedStringArray) -> void:
	var ctx := _context()
	var world := _world(ctx)
	var raider := _raider(ctx)
	var home := _place_depot(ctx, Types.Faction.ENEMY, Constants.ENEMY_DEPOT_TILE, 48, 50)
	raider.ai_state = Types.RaiderState.PATH_HOME
	raider.inventory.scrap = 5
	raider.pos = world.tile_center(Constants.ENEMY_DEPOT_TILE.x - 1, Constants.ENEMY_DEPOT_TILE.y)
	var rid: int = raider.id
	AiRaider.think(raider, _sim(ctx))
	if world.units.has(rid):
		fails.append("home despawn should delete the raider")
	if home.inventory.scrap != 50:
		fails.append("home depot scrap is %d, expected 50" % home.inventory.scrap)
	if world.loot.is_empty():
		fails.append("leftover carry should become loot at depot center")
		return
	var pile: Loot = world.loot.values()[0]
	if pile.inventory.scrap != 3:
		fails.append("leftover loot scrap is %d, expected 3" % pile.inventory.scrap)
	var center := Rect2(
		Constants.ENEMY_DEPOT_TILE.x * Constants.TILE,
		Constants.ENEMY_DEPOT_TILE.y * Constants.TILE,
		float(2 * Constants.TILE),
		float(2 * Constants.TILE)
	).get_center()
	if pile.pos != center:
		fails.append("leftover loot pos %s != depot center %s" % [pile.pos, center])


func _test_loot_channel_transfers(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	var depot := _place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 8)
	_place_depot(ctx, Types.Faction.ENEMY, Constants.ENEMY_DEPOT_TILE, 20, 20)
	raider.ai_state = Types.RaiderState.LOOT
	raider.pos = _world(ctx).tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	)
	var ticks := int(Constants.RAIDER_LOOT_CHANNEL / Constants.SIM_DT)
	for _i in ticks:
		AiRaider.think(raider, _sim(ctx))
	if raider.inventory.scrap != Constants.RAIDER_CARRY_SCRAP:
		fails.append("loot carry scrap is %d, expected %d" % [raider.inventory.scrap, Constants.RAIDER_CARRY_SCRAP])
	if raider.inventory.ice != 0:
		fails.append("loot carry ice is %d, expected 0" % raider.inventory.ice)
	if depot.inventory.scrap != 5 or depot.inventory.ice != 0:
		fails.append("depot after loot is %d/%d, expected 5/0" % [depot.inventory.scrap, depot.inventory.ice])
	if raider.ai_state != Types.RaiderState.PATH_HOME:
		fails.append("full carry after loot should PATH_HOME, got %d" % raider.ai_state)


func _test_loot_one_resource_goes_home(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	var depot := _place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 0)
	_place_depot(ctx, Types.Faction.ENEMY, Constants.ENEMY_DEPOT_TILE, 20, 20)
	raider.ai_state = Types.RaiderState.LOOT
	raider.pos = _world(ctx).tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	)
	var ticks := int(Constants.RAIDER_LOOT_CHANNEL / Constants.SIM_DT)
	for _i in ticks:
		AiRaider.think(raider, _sim(ctx))
	if raider.inventory.scrap != Constants.RAIDER_CARRY_SCRAP or raider.inventory.ice != 0:
		fails.append(
			"one-resource loot carry is %d/%d, expected %d/0"
			% [raider.inventory.scrap, raider.inventory.ice, Constants.RAIDER_CARRY_SCRAP]
		)
	if depot.inventory.scrap != 5 or depot.inventory.ice != 0:
		fails.append("one-resource depot after loot is %d/%d, expected 5/0" % [depot.inventory.scrap, depot.inventory.ice])
	if raider.ai_state != Types.RaiderState.PATH_HOME:
		fails.append("scrap-full ice-empty loot should PATH_HOME, got %d" % raider.ai_state)


func _test_loot_depot_died(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	var depot := _place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	_place_habitat(ctx, Types.Faction.PLAYER, Constants.PLAYER_HABITAT_TILE)
	raider.ai_state = Types.RaiderState.LOOT
	raider.pos = _world(ctx).tile_center(
		Constants.PLAYER_DEPOT_TILE.x + 2, Constants.PLAYER_DEPOT_TILE.y
	)
	depot.hp = 0
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.PATH_TO_HABITAT:
		fails.append("loot with dead depot should PATH_TO_HABITAT, got %d" % raider.ai_state)


func _test_stagger_does_not_siege(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	raider.pos = _world(ctx).tile_center(20, 52)
	raider.path_recalc_in = Constants.PATH_STAGGER
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state == Types.RaiderState.SIEGE:
		fails.append("staggered raider must not SIEGE before a path request completes")
	if raider.path_pending:
		fails.append("staggered raider should not enqueue until path_recalc_in hits 0")
	if raider.ai_state != Types.RaiderState.PATH_TO_DEPOT:
		fails.append("staggered raider should stay PATH_TO_DEPOT, got %d" % raider.ai_state)


func _test_stuck_enters_siege(fails: PackedStringArray) -> void:
	var ctx := _context()
	var raider := _raider(ctx)
	_place_depot(ctx, Types.Faction.PLAYER, Constants.PLAYER_DEPOT_TILE, 10, 10)
	raider.pos = _world(ctx).tile_center(20, 52)
	raider.stuck_timer = Constants.RAIDER_STUCK_TIME
	AiRaider.think(raider, _sim(ctx))
	if raider.ai_state != Types.RaiderState.SIEGE:
		fails.append("stuck detector should enter SIEGE, got %d" % raider.ai_state)


func _pump(ctx: Dictionary) -> void:
	var sim := _sim(ctx)
	AiRaider.think(_raider(ctx), sim)
	if sim.path_queue != null:
		sim.path_queue.service(_world(ctx))


func _context() -> Dictionary:
	var world := World.new()
	var sim := Sim.new()
	sim.world = world
	var player := Unit.new()
	player.id = world.alloc_id()
	player.kind = Types.UnitKind.PLAYER
	player.faction = Types.Faction.PLAYER
	player.alive = true
	player.pos = Vector2(2000, 2000)
	player.hp = Constants.PLAYER_HP
	player.inventory = Unit.inventory_for(Types.UnitKind.PLAYER)
	world.units[player.id] = player
	sim.player_id = player.id
	var raider := Unit.new()
	raider.id = world.alloc_id()
	raider.kind = Types.UnitKind.RAIDER
	raider.faction = Types.Faction.ENEMY
	raider.alive = true
	raider.hp = Constants.RAIDER_HP
	raider.radius = Constants.RAIDER_RADIUS
	raider.ai_state = Types.RaiderState.SPAWNED
	raider.inventory = Unit.inventory_for(Types.UnitKind.RAIDER)
	world.units[raider.id] = raider
	return {"world": world, "sim": sim, "player": player, "raider": raider}


func _world(ctx: Dictionary) -> World:
	return ctx.world as World


func _sim(ctx: Dictionary) -> Sim:
	return ctx.sim as Sim


func _raider(ctx: Dictionary) -> Unit:
	return ctx.raider as Unit


func _player(ctx: Dictionary) -> Unit:
	return ctx.player as Unit


func _place_depot(ctx: Dictionary, faction: int, origin: Vector2i, scrap: int, ice: int) -> Building:
	var world := _world(ctx)
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = Types.BuildingKind.DEPOT
	building.faction = faction
	building.origin_tile = origin
	building.hp = Constants.DEPOT_HP
	building.hp_max = Constants.DEPOT_HP
	building.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
	building.inventory.add(Types.ResourceKind.SCRAP, scrap)
	building.inventory.add(Types.ResourceKind.ICE, ice)
	world.occupy(building)
	world.buildings[building.id] = building
	return building


func _place_habitat(ctx: Dictionary, faction: int, origin: Vector2i) -> Building:
	var world := _world(ctx)
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = Types.BuildingKind.HABITAT
	building.faction = faction
	building.origin_tile = origin
	building.hp = Constants.HABITAT_HP
	building.hp_max = Constants.HABITAT_HP
	world.occupy(building)
	world.buildings[building.id] = building
	return building


func _place_wall(ctx: Dictionary, origin: Vector2i) -> Building:
	var world := _world(ctx)
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = Types.BuildingKind.WALL
	building.faction = Types.Faction.PLAYER
	building.origin_tile = origin
	building.hp = Constants.WALL_HP
	building.hp_max = Constants.WALL_HP
	world.occupy(building)
	world.buildings[building.id] = building
	return building


func _box_in(world: World, x: int, y: int) -> void:
	world.set_terrain(x + 1, y, Types.TileTerrain.ROCK)
	world.set_terrain(x - 1, y, Types.TileTerrain.ROCK)
	world.set_terrain(x, y + 1, Types.TileTerrain.ROCK)
	world.set_terrain(x, y - 1, Types.TileTerrain.ROCK)


func _seal_building(world: World, origin: Vector2i, span: int) -> void:
	for dy in span:
		for dx in span:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(origin.x + dx + d.x, origin.y + dy + d.y)
				if n.x < origin.x or n.y < origin.y or n.x >= origin.x + span or n.y >= origin.y + span:
					if world.in_bounds(n.x, n.y) and world.is_walkable(n.x, n.y):
						world.set_terrain(n.x, n.y, Types.TileTerrain.ROCK)


func _unseal_building(world: World, origin: Vector2i, span: int) -> void:
	for dy in range(-1, span + 1):
		for dx in range(-1, span + 1):
			var n := Vector2i(origin.x + dx, origin.y + dy)
			if n.x < origin.x or n.y < origin.y or n.x >= origin.x + span or n.y >= origin.y + span:
				if world.in_bounds(n.x, n.y) and world.get_terrain(n.x, n.y) == Types.TileTerrain.ROCK:
					world.set_terrain(n.x, n.y, Types.TileTerrain.EMPTY)


func _living_player_depot(ctx: Dictionary) -> Building:
	for raw in _world(ctx).buildings.values():
		var building := raw as Building
		if building != null and building.faction == Types.Faction.PLAYER and building.kind == Types.BuildingKind.DEPOT:
			return building
	return null
