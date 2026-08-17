extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_raider_fires_first_tick_without_chase(fails)
	_test_raider_fires_at_building_without_player(fails)
	_test_guard_fires_at_building(fails)
	_test_guard_idle_fires_outside_aggro(fails)
	_test_habitat_aabb_in_range(fails)
	_test_melee_fallback_inside_18(fails)
	_test_friendly_fire_off(fails)
	return fails


func _test_raider_fires_first_tick_without_chase(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_guard(sim)
	var raider := _inject_raider(sim, Vector2(400, 400))
	var player := sim.get_player()
	player.pos = raider.pos + Vector2(200, 0)
	raider.weapon_cooldown = 0.0
	var before := sim.world.projectiles.size()
	sim.tick()
	if raider.ai_state != Types.RaiderState.PATH_TO_DEPOT:
		fails.append(
			"raider with player outside chase should stay PATH_TO_DEPOT, got %d" % raider.ai_state
		)
	if raider.ai_state == Types.RaiderState.CHASE:
		fails.append("rifle range must not force CHASE")
	if _enemy_proj_count(sim) <= before:
		fails.append("raider should spawn an enemy projectile on the first eligible tick")
	var proj := _first_enemy_proj(sim)
	if proj != null and proj.damage != Constants.RAIDER_PROJ_DAMAGE:
		fails.append("raider projectile damage is %d, expected %d" % [proj.damage, Constants.RAIDER_PROJ_DAMAGE])
	if proj != null and not is_equal_approx(proj.vel.length(), Constants.PLAYER_PROJ_SPEED):
		fails.append("raider projectile speed is %s, expected %s" % [proj.vel.length(), Constants.PLAYER_PROJ_SPEED])
	if raider.fire_target_id != player.id:
		fails.append("fire_target_id is %d, expected player %d" % [raider.fire_target_id, player.id])


func _test_raider_fires_at_building_without_player(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	_banish_guard(sim)
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		fails.append("building-fire test missing player depot")
		return
	var aabb := sim.world.footprint_aabb(depot)
	var raider := _inject_raider(sim, Vector2(aabb.end.x + 200.0, aabb.get_center().y))
	sim.tick()
	if raider.ai_state == Types.RaiderState.CHASE:
		fails.append("raider fired at a building only after entering CHASE")
	if _enemy_proj_count(sim) < 1:
		fails.append("raider should fire at a player building with no player in range")
	if raider.fire_target_id != depot.id:
		fails.append("raider fire_target_id is %d, expected depot %d" % [raider.fire_target_id, depot.id])


func _test_guard_fires_at_building(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	var guard := _find_guard(sim)
	if guard == null:
		fails.append("guard building-fire test missing guard")
		return
	var wall := _place_wall(sim, Constants.ENEMY_GUARD_TILE + Vector2i(3, 0))
	sim.tick()
	if _enemy_proj_count(sim) < 1:
		fails.append("guard should fire at a player building with no player in range")
	if guard.fire_target_id != wall.id:
		fails.append("guard fire_target_id is %d, expected wall %d" % [guard.fire_target_id, wall.id])


func _test_guard_idle_fires_outside_aggro(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	var guard := _find_guard(sim)
	if guard == null:
		fails.append("guard idle-fire test missing guard")
		return
	var home := sim.world.tile_center(Constants.ENEMY_GUARD_TILE.x, Constants.ENEMY_GUARD_TILE.y)
	var player := sim.get_player()
	player.pos = home + Vector2(250, 0)
	sim.tick()
	if guard.vel != Vector2.ZERO:
		fails.append("guard outside GUARD_AGGRO should stay idle, vel=%s" % guard.vel)
	if _enemy_proj_count(sim) < 1:
		fails.append("idle guard should fire at a player inside rifle range but outside aggro")
	if guard.fire_target_id != player.id:
		fails.append("idle guard fire_target_id is %d, expected player %d" % [guard.fire_target_id, player.id])


func _test_habitat_aabb_in_range(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	_banish_guard(sim)
	var depot := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot != null:
		sim.world.vacate(depot)
		sim.world.buildings.erase(depot.id)
	var habitat := _living(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if habitat == null:
		fails.append("habitat range test missing player habitat")
		return
	var aabb := sim.world.footprint_aabb(habitat)
	var pos := Vector2(aabb.end.x + 300.0, aabb.get_center().y)
	var aabb_d := sim.world.point_aabb_distance(pos, aabb)
	var center_d := pos.distance_to(aabb.get_center())
	if aabb_d > Constants.ENEMY_RIFLE_RANGE or center_d <= Constants.ENEMY_RIFLE_RANGE:
		fails.append(
			"habitat fixture aabb=%s center=%s, need aabb<=range<center"
			% [aabb_d, center_d]
		)
		return
	var raider := _inject_raider(sim, pos)
	sim.tick()
	if _enemy_proj_count(sim) < 1:
		fails.append("2x2 habitat with AABB in range and center out of range should be a rifle target")
	if raider.fire_target_id != habitat.id:
		fails.append("habitat fire_target_id is %d, expected %d" % [raider.fire_target_id, habitat.id])


func _test_melee_fallback_inside_18(fails: PackedStringArray) -> void:
	var sim := _ready_sim()
	_banish_player(sim)
	_banish_guard(sim)
	var tile := Vector2i(20, 20)
	var walls := _box_with_walls(sim, tile)
	if walls.is_empty():
		fails.append("melee fallback could not box raider")
		return
	var raider := _inject_raider(sim, sim.world.tile_center(tile.x, tile.y))
	var hp0 := _wall_hp_sum(walls)
	var proj0 := sim.world.projectiles.size()
	sim.tick()
	if _enemy_proj_count(sim) > proj0:
		fails.append("raider inside melee range should not fire a rifle")
	if _wall_hp_sum(walls) != hp0 - Constants.RAIDER_MELEE_BUILDING:
		fails.append(
			"melee fallback wall hp sum is %d, expected %d"
			% [_wall_hp_sum(walls), hp0 - Constants.RAIDER_MELEE_BUILDING]
		)
	if raider.weapon_cooldown <= 0.0:
		fails.append("melee fallback should consume weapon_cooldown")


func _test_friendly_fire_off(fails: PackedStringArray) -> void:
	var world := World.new()
	var pos := Vector2(100, 100)
	var raider := _make_unit(world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, pos, Constants.RAIDER_HP)
	var player := _make_unit(world, Types.UnitKind.PLAYER, Types.Faction.PLAYER, pos, Constants.PLAYER_HP)
	Combat.bucket_units(world)
	var proj := _make_proj(Types.Faction.ENEMY, pos, Constants.RAIDER_PROJ_DAMAGE)
	Combat.resolve_projectile_hit(world, proj)
	if raider.hp != Constants.RAIDER_HP:
		fails.append("enemy projectile damaged a same-faction raider")
	if player.hp != Constants.PLAYER_HP - Constants.RAIDER_PROJ_DAMAGE:
		fails.append("enemy projectile player hp is %d" % player.hp)


func _ready_sim() -> Sim:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	return sim


func _banish_player(sim: Sim) -> void:
	var player := sim.get_player()
	if player != null:
		player.pos = Vector2(16, 16)


func _banish_guard(sim: Sim) -> void:
	var guard := _find_guard(sim)
	if guard != null:
		guard.pos = Vector2(16, 16)


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


func _find_guard(sim: Sim) -> Unit:
	for unit in sim.world.units.values():
		if unit.kind == Types.UnitKind.GUARD:
			return unit
	return null


func _place_wall(sim: Sim, tile: Vector2i) -> Building:
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	var occupant := sim.world.building_at(tile.x, tile.y)
	if occupant != null:
		sim.world.vacate(occupant)
		sim.world.buildings.erase(occupant.id)
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


func _box_with_walls(sim: Sim, tile: Vector2i) -> Array[Building]:
	sim.world.set_terrain(tile.x, tile.y, Types.TileTerrain.EMPTY)
	var walls: Array[Building] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for d in offsets:
		walls.append(_place_wall(sim, tile + d))
	return walls


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


func _enemy_proj_count(sim: Sim) -> int:
	var n := 0
	for proj in sim.world.projectiles.values():
		if proj.faction == Types.Faction.ENEMY:
			n += 1
	return n


func _first_enemy_proj(sim: Sim) -> Projectile:
	for proj in sim.world.projectiles.values():
		if proj.faction == Types.Faction.ENEMY:
			return proj
	return null


func _make_unit(world: World, kind: int, faction: int, pos: Vector2, hp: int) -> Unit:
	var unit := Unit.new()
	unit.id = world.alloc_id()
	unit.kind = kind
	unit.faction = faction
	unit.pos = pos
	unit.hp = hp
	unit.hp_max = hp
	unit.radius = Constants.RAIDER_RADIUS
	if kind == Types.UnitKind.PLAYER:
		unit.radius = Constants.PLAYER_RADIUS
	unit.alive = true
	unit.inventory = Unit.inventory_for(kind)
	world.units[unit.id] = unit
	return unit


func _make_proj(faction: int, pos: Vector2, damage: int) -> Projectile:
	var proj := Projectile.new()
	proj.faction = faction
	proj.pos = pos
	proj.damage = damage
	proj.life = Constants.PLAYER_PROJ_LIFE
	return proj
