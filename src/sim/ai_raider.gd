class_name AiRaider
extends RefCounted

## Raider state machine. Writes vel / melee / siege_target_id intents.
## LOOT transfers, home-depot despawn, and DEAD_DROP apply here.

const MELEE_TARGET_META := &"melee_target_id"
const _HOME_CHECK_META := &"home_check_in"

const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const _ARRIVE_PX := 8.0
const _MAX_TRANSITIONS := 6


static func think(unit: Unit, sim: Sim) -> void:
	if unit == null or sim == null or sim.world == null:
		return
	if not unit.alive or unit.kind != Types.UnitKind.RAIDER:
		return

	_set_melee_target(unit, 0)

	for _i in _MAX_TRANSITIONS:
		var before := unit.ai_state
		match unit.ai_state:
			Types.RaiderState.SPAWNED:
				_enter(unit, Types.RaiderState.PATH_TO_DEPOT)
			Types.RaiderState.PATH_TO_DEPOT:
				_think_path_to_depot(unit, sim)
			Types.RaiderState.LOOT:
				_think_loot(unit, sim)
			Types.RaiderState.PATH_HOME:
				_think_path_home(unit, sim)
			Types.RaiderState.CHASE:
				_think_chase(unit, sim)
			Types.RaiderState.PATH_TO_HABITAT:
				_think_path_to_habitat(unit, sim)
			Types.RaiderState.ATTACK_HABITAT:
				_think_attack_habitat(unit, sim)
			Types.RaiderState.SIEGE:
				_think_siege(unit, sim)
			Types.RaiderState.DEAD_DROP:
				_apply_dead_drop(unit, sim)
			_:
				unit.vel = Vector2.ZERO
		if not sim.world.units.has(unit.id):
			return
		if unit.ai_state == before:
			unit.ai_state_time += Constants.SIM_DT
			return
	unit.ai_state_time += Constants.SIM_DT


static func is_hauling(unit: Unit) -> bool:
	var inv := unit.inventory
	return inv != null and (inv.scrap > 0 or inv.ice > 0 or inv.ore > 0 or inv.parts > 0)


static func _think_path_to_depot(unit: Unit, sim: Sim) -> void:
	var depot := _living_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		_enter(unit, Types.RaiderState.PATH_TO_HABITAT)
		return
	if _adjacent(sim.world, unit, depot):
		unit.vel = Vector2.ZERO
		_enter(unit, Types.RaiderState.LOOT)
		return
	if _is_stuck(unit) or _cached_path_to(unit, sim.world, depot).is_empty():
		_enter(unit, Types.RaiderState.SIEGE)
		return
	if _player_in_chase_range(unit, sim):
		_enter(unit, Types.RaiderState.CHASE)
		return
	_steer_along_path(unit, sim.world)


static func _think_loot(unit: Unit, sim: Sim) -> void:
	unit.vel = Vector2.ZERO
	var depot := _living_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot == null:
		_enter(unit, Types.RaiderState.PATH_TO_HABITAT)
		return
	if not _can_loot_more(unit, depot):
		_enter(unit, Types.RaiderState.PATH_HOME)
		return
	if _player_in_chase_range(unit, sim):
		unit.interact_progress = 0.0
		_enter(unit, Types.RaiderState.CHASE)
		return
	unit.interact_progress += Constants.SIM_DT
	if not _timer_done(unit.interact_progress, Constants.RAIDER_LOOT_CHANNEL):
		return
	_transfer_loot(unit, depot)
	unit.interact_progress = 0.0
	if not _can_loot_more(unit, depot):
		_enter(unit, Types.RaiderState.PATH_HOME)


static func _think_path_home(unit: Unit, sim: Sim) -> void:
	var home := _living_building(sim.world, Types.Faction.ENEMY, Types.BuildingKind.DEPOT)
	if home == null:
		_enter(unit, Types.RaiderState.DEAD_DROP)
		return
	if _adjacent(sim.world, unit, home):
		_apply_home_despawn(unit, sim, home)
		return
	if _is_stuck(unit) or _cached_path_to(unit, sim.world, home).is_empty():
		_enter(unit, Types.RaiderState.SIEGE)
		return
	if _player_in_chase_range(unit, sim):
		_enter(unit, Types.RaiderState.CHASE)
		return
	_steer_along_path(unit, sim.world)


static func _think_path_to_habitat(unit: Unit, sim: Sim) -> void:
	var habitat := _living_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if habitat != null and _adjacent(sim.world, unit, habitat):
		unit.vel = Vector2.ZERO
		_enter(unit, Types.RaiderState.ATTACK_HABITAT)
		return
	if habitat == null or _is_stuck(unit) or _cached_path_to(unit, sim.world, habitat).is_empty():
		_enter(unit, Types.RaiderState.SIEGE)
		return
	if _player_in_chase_range(unit, sim):
		_enter(unit, Types.RaiderState.CHASE)
		return
	_steer_along_path(unit, sim.world)


static func _think_siege(unit: Unit, sim: Sim) -> void:
	# Chase never preempts SIEGE.
	if is_hauling(unit):
		var home := _living_building(sim.world, Types.Faction.ENEMY, Types.BuildingKind.DEPOT)
		if home == null:
			_enter(unit, Types.RaiderState.DEAD_DROP)
			return
		_tick_home_check(unit)
		if not _is_stuck(unit) and _home_check_due(unit):
			_arm_home_check(unit)
			if not _path_to_building(sim.world, unit, home).is_empty():
				_enter(unit, Types.RaiderState.PATH_HOME)
				return
		var wall := _nearest_player_wall_or_turret(sim.world, unit)
		if wall == null:
			unit.siege_target_id = 0
			unit.vel = Vector2.ZERO
			return
		if unit.siege_target_id != wall.id:
			unit.path.clear()
			unit.path_recalc_in = 0.0
		unit.siege_target_id = wall.id
		_approach_and_melee_building(unit, sim.world, wall)
		return

	# Non-hauling SIEGE does not exit when a loot path reopens.
	var target := _ensure_smash_target(unit, sim.world)
	if target == null:
		unit.siege_target_id = 0
		unit.vel = Vector2.ZERO
		return
	if unit.siege_target_id != target.id:
		unit.path.clear()
		unit.path_recalc_in = 0.0
	unit.siege_target_id = target.id
	if target.kind == Types.BuildingKind.HABITAT and _adjacent(sim.world, unit, target):
		_enter(unit, Types.RaiderState.ATTACK_HABITAT)
		return
	_approach_and_melee_building(unit, sim.world, target)


static func _think_chase(unit: Unit, sim: Sim) -> void:
	var player := _living_player(sim)
	if player == null:
		unit.chase_timer += Constants.SIM_DT
		unit.vel = Vector2.ZERO
		if _timer_done(unit.chase_timer, Constants.RAIDER_CHASE_GIVEUP):
			_give_up_chase(unit, sim)
		return
	var dist := unit.pos.distance_to(player.pos)
	if dist > Constants.RAIDER_CHASE_RADIUS:
		unit.chase_timer += Constants.SIM_DT
	else:
		unit.chase_timer = 0.0
	if _timer_done(unit.chase_timer, Constants.RAIDER_CHASE_GIVEUP):
		_give_up_chase(unit, sim)
		return
	if dist <= Constants.RAIDER_MELEE_RANGE:
		_set_melee_target(unit, player.id)
	_steer_toward(unit, player.pos)


static func _think_attack_habitat(unit: Unit, sim: Sim) -> void:
	if _player_in_chase_range(unit, sim):
		_enter(unit, Types.RaiderState.CHASE)
		return
	var habitat := _living_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)
	if habitat == null:
		unit.vel = Vector2.ZERO
		return
	unit.siege_target_id = habitat.id
	_approach_and_melee_building(unit, sim.world, habitat)


static func _give_up_chase(unit: Unit, sim: Sim) -> void:
	unit.chase_timer = 0.0
	if is_hauling(unit):
		_enter(unit, Types.RaiderState.PATH_HOME)
		return
	if _living_building(sim.world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT) != null:
		_enter(unit, Types.RaiderState.PATH_TO_DEPOT)
		return
	_enter(unit, Types.RaiderState.PATH_TO_HABITAT)


static func _enter(unit: Unit, state: int) -> void:
	if unit.ai_state == state:
		return
	unit.ai_state = state
	unit.ai_state_time = 0.0
	unit.path.clear()
	unit.path_recalc_in = 0.0
	unit.remove_meta(_HOME_CHECK_META)
	if state != Types.RaiderState.LOOT:
		unit.interact_progress = 0.0
	if state != Types.RaiderState.CHASE:
		unit.chase_timer = 0.0
	if state != Types.RaiderState.SIEGE and state != Types.RaiderState.ATTACK_HABITAT:
		unit.siege_target_id = 0


static func _approach_and_melee_building(unit: Unit, world: World, building: Building) -> void:
	var dist := _dist_to_building(world, unit, building)
	if dist <= Constants.RAIDER_MELEE_RANGE:
		_set_melee_target(unit, building.id)
		unit.vel = Vector2.ZERO
		return
	if _cached_path_to(unit, world, building).is_empty():
		_steer_toward(unit, _closest_on_aabb(unit.pos, world.footprint_aabb(building)))
		return
	_steer_along_path(unit, world)


static func _ensure_smash_target(_unit: Unit, world: World) -> Building:
	var wall := _nearest_player_wall_or_turret(world, _unit)
	if wall != null:
		return wall
	var depot := _living_building(world, Types.Faction.PLAYER, Types.BuildingKind.DEPOT)
	if depot != null:
		return depot
	return _living_building(world, Types.Faction.PLAYER, Types.BuildingKind.HABITAT)


static func _cached_path_to(unit: Unit, world: World, building: Building) -> Array[Vector2i]:
	if not _needs_recalc(unit, world):
		return unit.path
	unit.path = _path_to_building(world, unit, building)
	unit.path_recalc_in = Constants.PATH_RECALC
	return unit.path


static func _steer_along_path(unit: Unit, world: World) -> void:
	var here := world.world_to_tile(unit.pos)
	while unit.path.size() > 1 and unit.path[0] == here:
		unit.path.remove_at(0)
	while not unit.path.is_empty():
		var tile: Vector2i = unit.path[0]
		var center := world.tile_center(tile.x, tile.y)
		if unit.pos.distance_to(center) > _ARRIVE_PX:
			break
		unit.path.remove_at(0)
	if unit.path.is_empty():
		unit.vel = Vector2.ZERO
		return
	_steer_toward(unit, world.tile_center(unit.path[0].x, unit.path[0].y))


static func _steer_toward(unit: Unit, target: Vector2) -> void:
	var delta := target - unit.pos
	if delta.length_squared() <= 0.0001:
		unit.vel = Vector2.ZERO
		return
	var dir := delta.normalized()
	unit.vel = dir * Constants.RAIDER_SPEED
	unit.aim = dir


static func _needs_recalc(unit: Unit, world: World) -> bool:
	if unit.path_recalc_in <= 0.0:
		return true
	if unit.path.is_empty():
		return false
	var next: Vector2i = unit.path[0]
	return not world.is_walkable(next.x, next.y)


static func _home_check_due(unit: Unit) -> bool:
	return float(unit.get_meta(_HOME_CHECK_META, 0.0)) <= 0.0


static func _arm_home_check(unit: Unit) -> void:
	unit.set_meta(_HOME_CHECK_META, Constants.PATH_RECALC)


static func _tick_home_check(unit: Unit) -> void:
	var remaining := float(unit.get_meta(_HOME_CHECK_META, 0.0))
	if remaining > 0.0:
		unit.set_meta(_HOME_CHECK_META, maxf(0.0, remaining - Constants.SIM_DT))


static func _path_to_building(world: World, unit: Unit, building: Building) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if building == null:
		return none
	var start := world.world_to_tile(unit.pos)
	return Pathfind.find_path_any(world, start, _walkable_neighbors(world, building))


static func _walkable_neighbors(world: World, building: Building) -> Array[Vector2i]:
	var span := world.footprint_span(building.kind)
	var seen := {}
	var out: Array[Vector2i] = []
	for dy in span:
		for dx in span:
			var fx: int = building.origin_tile.x + dx
			var fy: int = building.origin_tile.y + dy
			for d in _CARDINALS:
				var n := Vector2i(fx + d.x, fy + d.y)
				var key := n.y * Constants.MAP_W + n.x
				if seen.has(key):
					continue
				seen[key] = true
				if world.is_walkable(n.x, n.y):
					out.append(n)
	return out


static func _transfer_loot(unit: Unit, depot: Building) -> void:
	var carry: Inventory = unit.inventory
	var stock: Inventory = depot.inventory
	if carry == null or stock == null:
		return
	for kind in [
		Types.ResourceKind.SCRAP,
		Types.ResourceKind.ICE,
		Types.ResourceKind.ORE,
		Types.ResourceKind.PARTS,
	]:
		var taken := stock.remove(kind, carry.free_space(kind))
		carry.add(kind, taken)


static func _apply_home_despawn(unit: Unit, sim: Sim, home: Building) -> void:
	var carry: Inventory = unit.inventory
	var leftover := Inventory.new(999, 999, 999, 999)
	if carry != null and home.inventory != null:
		leftover.add(Types.ResourceKind.SCRAP, home.inventory.add(Types.ResourceKind.SCRAP, carry.scrap))
		leftover.add(Types.ResourceKind.ICE, home.inventory.add(Types.ResourceKind.ICE, carry.ice))
		leftover.add(Types.ResourceKind.ORE, home.inventory.add(Types.ResourceKind.ORE, carry.ore))
		leftover.add(Types.ResourceKind.PARTS, home.inventory.add(Types.ResourceKind.PARTS, carry.parts))
		carry.scrap = 0
		carry.ice = 0
		carry.ore = 0
		carry.parts = 0
	elif carry != null:
		leftover.add(Types.ResourceKind.SCRAP, carry.scrap)
		leftover.add(Types.ResourceKind.ICE, carry.ice)
		leftover.add(Types.ResourceKind.ORE, carry.ore)
		leftover.add(Types.ResourceKind.PARTS, carry.parts)
		carry.scrap = 0
		carry.ice = 0
		carry.ore = 0
		carry.parts = 0
	_drop_loot(sim.world, sim.world.footprint_aabb(home).get_center(), leftover)
	_delete_raider(sim.world, unit)


static func _apply_dead_drop(unit: Unit, sim: Sim) -> void:
	var carry: Inventory = unit.inventory
	var leftover := Inventory.new(999, 999, 999, 999)
	if carry != null:
		leftover.add(Types.ResourceKind.SCRAP, carry.scrap)
		leftover.add(Types.ResourceKind.ICE, carry.ice)
		leftover.add(Types.ResourceKind.ORE, carry.ore)
		leftover.add(Types.ResourceKind.PARTS, carry.parts)
		carry.scrap = 0
		carry.ice = 0
		carry.ore = 0
		carry.parts = 0
	_drop_loot(sim.world, unit.pos, leftover)
	_delete_raider(sim.world, unit)


static func _drop_loot(world: World, pos: Vector2, leftover: Inventory) -> void:
	if leftover == null or (
		leftover.scrap <= 0 and leftover.ice <= 0 and leftover.ore <= 0 and leftover.parts <= 0
	):
		return
	var pile := Loot.new()
	pile.id = world.alloc_id()
	pile.pos = pos
	if leftover.scrap > 0:
		pile.inventory.add(Types.ResourceKind.SCRAP, leftover.scrap)
	if leftover.ice > 0:
		pile.inventory.add(Types.ResourceKind.ICE, leftover.ice)
	if leftover.ore > 0:
		pile.inventory.add(Types.ResourceKind.ORE, leftover.ore)
	if leftover.parts > 0:
		pile.inventory.add(Types.ResourceKind.PARTS, leftover.parts)
	world.loot[pile.id] = pile


static func _delete_raider(world: World, unit: Unit) -> void:
	unit.alive = false
	world.units.erase(unit.id)


static func _nearest_player_wall_or_turret(world: World, unit: Unit) -> Building:
	var best: Building = null
	var best_d := INF
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.faction != Types.Faction.PLAYER:
			continue
		if building.kind != Types.BuildingKind.WALL and building.kind != Types.BuildingKind.TURRET:
			continue
		var dist := _dist_to_building(world, unit, building)
		if dist < best_d or (is_equal_approx(dist, best_d) and (best == null or building.id < best.id)):
			best_d = dist
			best = building
	return best


static func _living_building(world: World, faction: int, kind: int) -> Building:
	var best: Building = null
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.faction != faction or building.kind != kind:
			continue
		if best == null or building.id < best.id:
			best = building
	return best


static func _living_player(sim: Sim) -> Unit:
	var player := sim.get_player()
	if player != null and player.alive:
		return player
	for raw in sim.world.units.values():
		var other := raw as Unit
		if other != null and other.kind == Types.UnitKind.PLAYER and other.alive:
			return other
	return null


static func _player_in_chase_range(unit: Unit, sim: Sim) -> bool:
	var player := _living_player(sim)
	if player == null:
		return false
	return unit.pos.distance_to(player.pos) <= Constants.RAIDER_CHASE_RADIUS


static func _can_loot_more(unit: Unit, depot: Building) -> bool:
	var carry: Inventory = unit.inventory
	var stock: Inventory = depot.inventory
	if carry == null or stock == null:
		return false
	for kind in [
		Types.ResourceKind.SCRAP,
		Types.ResourceKind.ICE,
		Types.ResourceKind.ORE,
		Types.ResourceKind.PARTS,
	]:
		if _kind_amount(stock, kind) > 0 and carry.free_space(kind) > 0:
			return true
	return false


static func _kind_amount(inv: Inventory, kind: int) -> int:
	match kind:
		Types.ResourceKind.SCRAP:
			return inv.scrap
		Types.ResourceKind.ICE:
			return inv.ice
		Types.ResourceKind.ORE:
			return inv.ore
		Types.ResourceKind.PARTS:
			return inv.parts
		_:
			return 0


static func _is_stuck(unit: Unit) -> bool:
	return unit.stuck_timer >= Constants.RAIDER_STUCK_TIME


static func _timer_done(value: float, limit: float) -> bool:
	return value + Constants.SIM_DT * 0.5 >= limit


static func _adjacent(world: World, unit: Unit, building: Building) -> bool:
	return _dist_to_building(world, unit, building) <= Constants.INTERACT_BUILDING_RANGE


static func _dist_to_building(world: World, unit: Unit, building: Building) -> float:
	return world.point_aabb_distance(unit.pos, world.footprint_aabb(building))


static func _closest_on_aabb(point: Vector2, aabb: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, aabb.position.x, aabb.end.x),
		clampf(point.y, aabb.position.y, aabb.end.y)
	)


static func _set_melee_target(unit: Unit, target_id: int) -> void:
	unit.set_meta(MELEE_TARGET_META, target_id)
