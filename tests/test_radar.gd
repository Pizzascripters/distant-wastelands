extends RefCounted

const _ORIGIN := Vector2i(20, 20)


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_locked_before_metallurgy(fails)
	_test_place_pays_pools(fails)
	_test_short_parts_rejects(fails)
	_test_reveal_range(fails)
	_test_destroy_clears_reveal(fails)
	_test_hauling_smash_set(fails)
	_test_friendly_shot_eaten(fails)
	return fails


func _test_locked_before_metallurgy(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.RADAR_COST_SCRAP, Constants.RADAR_COST_PARTS)
	var sim := Sim.new()
	sim.world = world
	if Research.building_unlocked(sim, Types.BuildingKind.RADAR):
		fails.append("Radar should start locked")
	if Rules.can_place(world, sim, Types.BuildingKind.RADAR, _ORIGIN):
		fails.append("can_place should reject Radar before Metallurgy")
	if Rules.try_place(world, sim, Types.BuildingKind.RADAR, _ORIGIN):
		fails.append("try_place should reject Radar before Metallurgy")


func _test_place_pays_pools(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.RADAR_COST_SCRAP + 2, Constants.RADAR_COST_PARTS + 1)
	var sim := Sim.new()
	sim.world = world
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	var depot := world.building_at(2, 2)
	var scrap0 := depot.inventory.scrap
	var parts0 := depot.inventory.parts
	if not Rules.try_place(world, sim, Types.BuildingKind.RADAR, _ORIGIN):
		fails.append("try_place Radar should succeed after Metallurgy")
		return
	if depot.inventory.scrap != scrap0 - Constants.RADAR_COST_SCRAP:
		fails.append(
			"Radar scrap is %d, expected %d"
			% [depot.inventory.scrap, scrap0 - Constants.RADAR_COST_SCRAP]
		)
	if depot.inventory.parts != parts0 - Constants.RADAR_COST_PARTS:
		fails.append(
			"Radar parts is %d, expected %d"
			% [depot.inventory.parts, parts0 - Constants.RADAR_COST_PARTS]
		)
	var radar := world.building_at(_ORIGIN.x, _ORIGIN.y)
	if radar == null or radar.kind != Types.BuildingKind.RADAR:
		fails.append("placed Radar missing from occupancy")
		return
	if radar.hp != Constants.RADAR_HP or radar.hp_max != Constants.RADAR_HP:
		fails.append("Radar hp is %d/%d" % [radar.hp, radar.hp_max])
	if World.footprint_span(Types.BuildingKind.RADAR) != 2:
		fails.append("Radar footprint should be 2x2")
	for dy in 2:
		for dx in 2:
			if world.building_at(_ORIGIN.x + dx, _ORIGIN.y + dy) != radar:
				fails.append("Radar does not occupy %s" % Vector2i(_ORIGIN.x + dx, _ORIGIN.y + dy))
	if radar.inventory == null:
		fails.append("Radar should keep the default empty inventory")
	elif radar.inventory.cap_scrap != 0 or radar.inventory.cap_parts != 0:
		fails.append("Radar inventory should stay all-cap-0")


func _test_short_parts_rejects(fails: PackedStringArray) -> void:
	var world := _world_with_depot(Constants.RADAR_COST_SCRAP, Constants.RADAR_COST_PARTS - 1)
	var sim := Sim.new()
	sim.world = world
	Research.mark_complete(sim, Types.TechKind.METALLURGY)
	if Rules.can_place(world, sim, Types.BuildingKind.RADAR, _ORIGIN):
		fails.append("can_place should reject Radar when the Parts pool is short")
	if Rules.try_place(world, sim, Types.BuildingKind.RADAR, _ORIGIN):
		fails.append("try_place should reject Radar when the Parts pool is short")
	var depot := world.building_at(2, 2)
	if depot.inventory.scrap != Constants.RADAR_COST_SCRAP:
		fails.append("short-Parts try_place changed scrap")
	if depot.inventory.parts != Constants.RADAR_COST_PARTS - 1:
		fails.append("short-Parts try_place changed parts")


func _test_reveal_range(fails: PackedStringArray) -> void:
	var world := World.new()
	var radar := _inject_building(
		world, Types.BuildingKind.RADAR, Types.Faction.PLAYER, _ORIGIN, Constants.RADAR_HP
	)
	var near_depot := _inject_building(
		world,
		Types.BuildingKind.DEPOT,
		Types.Faction.ENEMY,
		_ORIGIN + Vector2i(40, 0),
		Constants.DEPOT_HP
	)
	var far_depot := _inject_building(
		world,
		Types.BuildingKind.DEPOT,
		Types.Faction.ENEMY,
		_ORIGIN + Vector2i(50, 0),
		Constants.DEPOT_HP
	)
	var near_unit := _inject_unit(world, _ORIGIN + Vector2i(40, 0))
	var far_unit := _inject_unit(world, _ORIGIN + Vector2i(50, 0))
	var revealed := Rules.radar_reveal_set(world)
	if not revealed.has(near_depot.id):
		fails.append("enemy depot at Chebyshev 40 should be in the reveal set")
	if revealed.has(far_depot.id):
		fails.append("enemy depot at Chebyshev 50 should not be in the reveal set")
	if not revealed.has(near_unit.id):
		fails.append("enemy unit at Chebyshev 40 should be in the reveal set")
	if revealed.has(far_unit.id):
		fails.append("enemy unit at Chebyshev 50 should not be in the reveal set")
	if revealed.has(radar.id):
		fails.append("player Radar should not appear in the enemy reveal set")


func _test_destroy_clears_reveal(fails: PackedStringArray) -> void:
	var world := World.new()
	var radar := _inject_building(
		world, Types.BuildingKind.RADAR, Types.Faction.PLAYER, _ORIGIN, Constants.RADAR_HP
	)
	var depot := _inject_building(
		world,
		Types.BuildingKind.DEPOT,
		Types.Faction.ENEMY,
		_ORIGIN + Vector2i(40, 0),
		Constants.DEPOT_HP
	)
	var unit := _inject_unit(world, _ORIGIN + Vector2i(40, 0))
	if Rules.radar_reveal_set(world).is_empty():
		fails.append("living Radar should reveal the nearby enemy depot and unit")
		return
	radar.hp = 0
	Combat.process_deaths(world)
	if world.buildings.has(radar.id):
		fails.append("dead Radar should be removed")
	if not world.loot.is_empty():
		fails.append("destroyed Radar should not drop loot")
	var revealed := Rules.radar_reveal_set(world)
	if not revealed.is_empty():
		fails.append("killing the Radar should empty the reveal set")
	if revealed.has(depot.id) or revealed.has(unit.id):
		fails.append("dead Radar should not keep enemies in the reveal set")


func _test_hauling_smash_set(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var tile := Vector2i(22, 176)
	var radar := _clear_and_place_radar(sim, Vector2i(tile.x + 1, tile.y))
	if radar == null:
		fails.append("could not place a Radar for smash test")
		return
	var raider := Unit.new()
	raider.id = sim.world.alloc_id()
	raider.kind = Types.UnitKind.RAIDER
	raider.faction = Types.Faction.ENEMY
	raider.pos = sim.world.tile_center(tile.x, tile.y)
	raider.hp = Constants.RAIDER_HP
	raider.hp_max = Constants.RAIDER_HP
	raider.radius = Constants.RAIDER_RADIUS
	raider.alive = true
	raider.ai_state = Types.RaiderState.SIEGE
	raider.inventory = Unit.inventory_for(Types.UnitKind.RAIDER)
	raider.inventory.scrap = 1
	raider.stuck_timer = Constants.RAIDER_STUCK_TIME
	raider.stuck_last_pos = raider.pos
	var home := _living(sim.world, Types.Faction.ENEMY, Types.BuildingKind.DEPOT)
	if home != null:
		raider.home_depot_id = home.id
	sim.world.units[raider.id] = raider
	var player := sim.get_player()
	if player != null:
		player.pos = Vector2(16, 16)
	var hp0 := radar.hp
	for _i in 8:
		sim.tick()
	if not sim.world.units.has(raider.id):
		fails.append("hauling raider next to a Radar was deleted")
		return
	if radar.hp >= hp0:
		fails.append("hauling raider did not smash the Radar")
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot != null and depot.hp < Constants.DEPOT_HP:
		fails.append("hauling smash must not hit the player Depot")
	var habitat := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if habitat != null and habitat.hp < Constants.HABITAT_HP:
		fails.append("hauling smash must not hit the player Habitat")


func _test_friendly_shot_eaten(fails: PackedStringArray) -> void:
	var world := World.new()
	var radar := _inject_building(
		world, Types.BuildingKind.RADAR, Types.Faction.PLAYER, _ORIGIN, Constants.RADAR_HP
	)
	var proj := Projectile.new()
	proj.faction = Types.Faction.PLAYER
	proj.pos = world.footprint_aabb(radar).get_center()
	proj.damage = Constants.PLAYER_PROJ_DAMAGE
	proj.life = Constants.PLAYER_PROJ_LIFE
	if not Combat.resolve_projectile_hit(world, proj):
		fails.append("projectile hitting a player Radar should be eaten")
	if radar.hp != Constants.RADAR_HP:
		fails.append("friendly Radar should eat a shot with no damage")


func _world_with_depot(scrap: int, parts: int) -> World:
	var world := World.new()
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Vector2i(2, 2)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Building.inventory_for(Types.BuildingKind.DEPOT)
	depot.inventory.add(Types.ResourceKind.SCRAP, scrap)
	depot.inventory.add(Types.ResourceKind.PARTS, parts)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	return world


func _inject_building(world: World, kind: int, faction: int, tile: Vector2i, hp: int) -> Building:
	var span := World.footprint_span(kind)
	for dy in span:
		for dx in span:
			var at := Vector2i(tile.x + dx, tile.y + dy)
			if world.in_bounds(at.x, at.y):
				world.set_terrain(at.x, at.y, Types.TileTerrain.EMPTY)
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = kind
	building.faction = faction
	building.origin_tile = tile
	building.hp = hp
	building.hp_max = hp
	building.inventory = Building.inventory_for(kind)
	world.buildings[building.id] = building
	world.occupy(building)
	return building


func _inject_unit(world: World, tile: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.id = world.alloc_id()
	unit.kind = Types.UnitKind.RAIDER
	unit.faction = Types.Faction.ENEMY
	unit.pos = world.tile_center(tile.x, tile.y)
	unit.hp = Constants.RAIDER_HP
	unit.hp_max = Constants.RAIDER_HP
	unit.radius = Constants.RAIDER_RADIUS
	unit.alive = true
	world.units[unit.id] = unit
	return unit


func _clear_and_place_radar(sim: Sim, tile: Vector2i) -> Building:
	for dy in 2:
		for dx in 2:
			var at := Vector2i(tile.x + dx, tile.y + dy)
			if not sim.world.in_bounds(at.x, at.y):
				return null
			sim.world.set_terrain(at.x, at.y, Types.TileTerrain.EMPTY)
			var occupant := sim.world.building_at(at.x, at.y)
			if occupant != null:
				sim.world.vacate(occupant)
				sim.world.buildings.erase(occupant.id)
	return _inject_building(
		sim.world, Types.BuildingKind.RADAR, Types.Faction.PLAYER, tile, Constants.RADAR_HP
	)


func _living(world: World, faction: int, kind: int) -> Building:
	for building in world.buildings.values():
		if building.kind == kind and building.faction == faction and building.hp > 0:
			return building
	return null
