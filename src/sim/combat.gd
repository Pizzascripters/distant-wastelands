class_name Combat
extends RefCounted

## Damage, hit order, melee, and death helpers.

static func bucket_units(world: World) -> void:
	if world == null:
		return
	if world.spatial == null:
		world.spatial = SpatialIndex.new()
	world.spatial.rebuild_units(world)


static func apply_damage(target: Object, amount: int) -> void:
	if target == null or amount <= 0:
		return
	target.hp = maxi(int(target.hp) - amount, 0)


static func resolve_projectile_hit(world: World, proj: Projectile) -> bool:
	var unit := _lowest_id_opposing_unit(world, proj)
	if unit != null:
		apply_damage(unit, proj.damage)
		return true
	var tile := _lowest_index_solid_tile(world, proj)
	if tile.x < 0:
		return proj.life <= 0.0
	var building := _building_at(world, tile.x, tile.y)
	if building != null and building.faction != proj.faction:
		apply_damage(building, proj.damage)
	return true


static func integrate_projectile(world: World, proj: Projectile) -> bool:
	proj.pos += proj.vel * Constants.SIM_DT
	var hit := resolve_projectile_hit(world, proj)
	proj.ignore_gate_id = 0
	return hit


static func overlapping_friendly_gate_id(world: World, unit: Unit) -> int:
	if world == null or unit == null or not unit.alive:
		return 0
	var best_id := 0
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.kind != Types.BuildingKind.GATE:
			continue
		if building.faction != unit.faction:
			continue
		if world.point_aabb_distance(unit.pos, world.footprint_aabb(building)) > unit.radius:
			continue
		if best_id == 0 or building.id < best_id:
			best_id = building.id
	return best_id


static func apply_melee(attacker: Unit, target: Object) -> bool:
	if attacker == null or target == null:
		return false
	if not attacker.alive or attacker.weapon_cooldown > 0.0:
		return false
	if not _is_valid_melee_target(attacker, target):
		return false
	if _melee_distance(attacker, target) > Constants.RAIDER_MELEE_RANGE:
		return false
	apply_damage(target, _melee_damage(target))
	attacker.weapon_cooldown = _melee_cooldown(attacker)
	return true


static func range_distance(world: World, shooter: Unit, target: Object) -> float:
	if shooter == null or target == null:
		return INF
	if target is Unit:
		return shooter.pos.distance_to((target as Unit).pos)
	if target is Building and world != null:
		return world.point_aabb_distance(shooter.pos, world.footprint_aabb(target as Building))
	return INF


static func resolve_fire_target(world: World, unit: Unit) -> Object:
	if world == null or unit == null or unit.fire_target_id <= 0:
		return null
	var other: Unit = world.units.get(unit.fire_target_id) as Unit
	if other != null:
		if other.alive and other.faction != unit.faction:
			return other
		return null
	var building: Building = world.buildings.get(unit.fire_target_id) as Building
	if building != null and building.hp > 0 and building.faction != unit.faction:
		return building
	return null


static func aim_at(world: World, unit: Unit, target: Object) -> void:
	if unit == null or target == null:
		return
	var dest := Vector2.ZERO
	if target is Unit:
		dest = (target as Unit).pos
	elif target is Building and world != null:
		dest = world.footprint_aabb(target as Building).get_center()
	else:
		return
	var delta := dest - unit.pos
	if delta.length_squared() <= 0.0001:
		return
	unit.aim = delta.normalized()


static func write_fire_intent(world: World, unit: Unit, player: Unit) -> void:
	if unit == null:
		return
	unit.fire_target_id = 0
	unit.set_meta(AiRaider.MELEE_TARGET_META, 0)
	if world == null or not unit.alive or unit.ai_state == Types.RaiderState.DEAD_DROP:
		return
	var tid := acquire_fire_target(world, unit, player)
	unit.fire_target_id = tid
	var target := resolve_fire_target(world, unit)
	if target == null:
		return
	aim_at(world, unit, target)
	if range_distance(world, unit, target) <= Constants.RAIDER_MELEE_RANGE:
		unit.set_meta(AiRaider.MELEE_TARGET_META, tid)


static func acquire_fire_target(world: World, unit: Unit, player: Unit) -> int:
	if world == null or unit == null:
		return 0
	if player != null and player.alive:
		if unit.pos.distance_to(player.pos) <= Constants.ENEMY_RIFLE_RANGE:
			return player.id
	var tasked := _tasked_building(world, unit)
	if tasked != null and _player_building_allowed(unit, tasked):
		if range_distance(world, unit, tasked) <= Constants.ENEMY_RIFLE_RANGE:
			return tasked.id
	var nearest := _nearest_player_building_in_range(world, unit)
	if nearest != null:
		return nearest.id
	return 0


static func _tasked_building(world: World, unit: Unit) -> Building:
	match unit.ai_state:
		Types.RaiderState.SIEGE, Types.RaiderState.ATTACK_HABITAT:
			var siege: Building = world.buildings.get(unit.siege_target_id) as Building
			if siege != null:
				return siege
			if unit.ai_state == Types.RaiderState.ATTACK_HABITAT:
				return _living_player_kind(world, Types.BuildingKind.HABITAT)
			return null
		Types.RaiderState.LOOT, Types.RaiderState.PATH_TO_DEPOT:
			return _living_player_kind(world, Types.BuildingKind.DEPOT)
		Types.RaiderState.PATH_TO_HABITAT:
			return _living_player_kind(world, Types.BuildingKind.HABITAT)
		_:
			return null


static func _living_player_kind(world: World, kind: int) -> Building:
	var best: Building = null
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.faction != Types.Faction.PLAYER or building.kind != kind:
			continue
		if best == null or building.id < best.id:
			best = building
	return best


static func _player_building_allowed(unit: Unit, building: Building) -> bool:
	if building == null or building.hp <= 0:
		return false
	if building.faction != Types.Faction.PLAYER:
		return false
	if unit.kind == Types.UnitKind.RAIDER and AiRaider.is_hauling(unit):
		if (
			building.kind == Types.BuildingKind.DEPOT
			or building.kind == Types.BuildingKind.HABITAT
		):
			return false
	return true


static func _nearest_player_building_in_range(world: World, unit: Unit) -> Building:
	var best: Building = null
	var best_d := Constants.ENEMY_RIFLE_RANGE
	for raw in world.buildings.values():
		var building := raw as Building
		if not _player_building_allowed(unit, building):
			continue
		var dist := range_distance(world, unit, building)
		if dist > Constants.ENEMY_RIFLE_RANGE:
			continue
		if best != null and (dist > best_d or (is_equal_approx(dist, best_d) and building.id >= best.id)):
			continue
		best = building
		best_d = dist
	return best


static func process_deaths(world: World) -> void:
	var dead_units: Array[Unit] = []
	for unit in world.units.values():
		if unit.hp <= 0:
			dead_units.append(unit)
	for unit in dead_units:
		process_unit_death(world, unit)
	var buildings = world.get("buildings")
	if buildings is Dictionary:
		var dead_buildings: Array[Building] = []
		for building in buildings.values():
			if building.hp <= 0:
				dead_buildings.append(building)
		for building in dead_buildings:
			process_building_death(world, building)


static func process_unit_death(world: World, unit: Unit) -> void:
	unit.hp = 0
	unit.alive = false
	if world != null and world.spatial != null:
		world.spatial.remove_unit(unit)
	if unit.kind != Types.UnitKind.PLAYER:
		world.units.erase(unit.id)


static func process_building_death(world: World, building: Building) -> void:
	if building.kind == Types.BuildingKind.DEPOT:
		_spill_depot(world, building)
	elif building.kind == Types.BuildingKind.HABITAT:
		_spill_habitat(world, building)
	_vacate_footprint(world, building)
	var buildings = world.get("buildings")
	if buildings is Dictionary:
		buildings.erase(building.id)


static func _lowest_id_opposing_unit(world: World, proj: Projectile) -> Unit:
	if world == null:
		return null
	if world.spatial == null:
		world.spatial = SpatialIndex.new()
	if world.spatial.indexed_unit_ids() == 0 and not world.units.is_empty():
		world.spatial.rebuild_units(world)
	var index: SpatialIndex = world.spatial
	var home := index.chunk_of_pos(proj.pos)
	var best: Unit = null
	# One-chunk halo: PROJ_RADIUS + max unit radius is 13 < 8 * 32.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for raw in index.units_in_chunk(Vector2i(home.x + dx, home.y + dy)):
				var unit := raw as Unit
				if unit == null or not unit.alive or unit.faction == proj.faction:
					continue
				if not _circles_overlap(proj.pos, Constants.PROJ_RADIUS, unit.pos, unit.radius):
					continue
				if best == null or unit.id < best.id:
					best = unit
	return best


static func _lowest_index_solid_tile(world: World, proj: Projectile) -> Vector2i:
	var radius := Constants.PROJ_RADIUS
	var tile := float(Constants.TILE)
	var min_tx := int(floor((proj.pos.x - radius) / tile))
	var max_tx := int(floor((proj.pos.x + radius) / tile))
	var min_ty := int(floor((proj.pos.y - radius) / tile))
	var max_ty := int(floor((proj.pos.y + radius) / tile))
	var best := Vector2i(-1, -1)
	var best_index := 0x7fffffff
	for y in range(min_ty, max_ty + 1):
		for x in range(min_tx, max_tx + 1):
			if not world.in_bounds(x, y):
				continue
			var occupied: int = world.occupancy[world.index_of(x, y)]
			if not World.is_solid_terrain(world.get_terrain(x, y)) and occupied == 0:
				continue
			if proj.ignore_gate_id > 0:
				var bid: int = world.occupancy[world.index_of(x, y)]
				if bid == proj.ignore_gate_id:
					continue
			if not _circle_aabb_overlaps(proj.pos, radius, world.tile_aabb(x, y)):
				continue
			var index := y * Constants.MAP_W + x
			if index < best_index:
				best_index = index
				best = Vector2i(x, y)
	return best


static func _building_at(world: World, x: int, y: int) -> Building:
	if not world.in_bounds(x, y):
		return null
	var bid: int = world.occupancy[world.index_of(x, y)]
	if bid <= 0:
		return null
	var buildings = world.get("buildings")
	if not buildings is Dictionary:
		return null
	return buildings.get(bid) as Building


static func _is_valid_melee_target(attacker: Unit, target: Object) -> bool:
	if target is Unit:
		var unit := target as Unit
		return unit.alive and unit.faction != attacker.faction
	if target is Building:
		var building := target as Building
		return building.hp > 0 and building.faction != attacker.faction
	return false


static func _melee_distance(attacker: Unit, target: Object) -> float:
	if target is Unit:
		return attacker.pos.distance_to((target as Unit).pos)
	if target is Building:
		return _point_aabb_distance(attacker.pos, _footprint_aabb(target as Building))
	return INF


static func _melee_damage(target: Object) -> int:
	if target is Building:
		return Constants.RAIDER_MELEE_BUILDING
	return Constants.RAIDER_MELEE_UNIT


static func _melee_cooldown(unit: Unit) -> float:
	if unit.kind == Types.UnitKind.GUARD:
		return Constants.GUARD_MELEE_COOLDOWN
	return Constants.RAIDER_MELEE_COOLDOWN


static func _spill_depot(world: World, depot: Building) -> void:
	var inv: Inventory = depot.inventory
	var scrap := 0
	var ore := 0
	var parts := 0
	var food := 0
	if inv != null:
		scrap = inv.scrap
		ore = inv.ore
		parts = inv.parts
		food = inv.food
	var last_player := (
		depot.faction == Types.Faction.PLAYER
		and Rules.living_player(world, Types.BuildingKind.DEPOT).is_empty()
	)
	if last_player and scrap <= 0:
		scrap = Constants.LAST_DEPOT_SCRAP
	if scrap <= 0 and ore <= 0 and parts <= 0 and food <= 0:
		return
	var pile := Loot.new()
	pile.id = world.alloc_id()
	pile.pos = _footprint_aabb(depot).get_center()
	if scrap > 0:
		pile.inventory.add(Types.ResourceKind.SCRAP, scrap)
	if ore > 0:
		pile.inventory.add(Types.ResourceKind.ORE, ore)
	if parts > 0:
		pile.inventory.add(Types.ResourceKind.PARTS, parts)
	if food > 0:
		pile.inventory.add(Types.ResourceKind.FOOD, food)
	var piles = world.get("loot")
	if piles is Dictionary:
		piles[pile.id] = pile


static func _spill_habitat(world: World, habitat: Building) -> void:
	var inv: Inventory = habitat.inventory
	if inv == null or inv.ice <= 0:
		return
	var pile := Loot.new()
	pile.id = world.alloc_id()
	pile.pos = _footprint_aabb(habitat).get_center()
	pile.inventory.add(Types.ResourceKind.ICE, inv.ice)
	var piles = world.get("loot")
	if piles is Dictionary:
		piles[pile.id] = pile
		if world.spatial != null:
			world.spatial.insert_loot(pile)


static func _vacate_footprint(world: World, building: Building) -> void:
	var span := World.footprint_span(building.kind)
	for dy in span:
		for dx in span:
			var x: int = building.origin_tile.x + dx
			var y: int = building.origin_tile.y + dy
			if not world.in_bounds(x, y):
				continue
			var i := world.index_of(x, y)
			if world.occupancy[i] == building.id:
				world.occupancy[i] = 0


static func _footprint_aabb(building: Building) -> Rect2:
	var span := float(World.footprint_span(building.kind) * Constants.TILE)
	return Rect2(
		building.origin_tile.x * Constants.TILE,
		building.origin_tile.y * Constants.TILE,
		span,
		span
	)


static func _circles_overlap(a: Vector2, ra: float, b: Vector2, rb: float) -> bool:
	var r := ra + rb
	return a.distance_squared_to(b) <= r * r


static func _circle_aabb_overlaps(center: Vector2, radius: float, aabb: Rect2) -> bool:
	return _point_aabb_distance(center, aabb) <= radius


static func _point_aabb_distance(point: Vector2, aabb: Rect2) -> float:
	var closest := Vector2(
		clampf(point.x, aabb.position.x, aabb.end.x),
		clampf(point.y, aabb.position.y, aabb.end.y)
	)
	return point.distance_to(closest)
