class_name Combat
extends RefCounted

## Damage, hit order, melee, and death helpers.


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
	return resolve_projectile_hit(world, proj)


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
	if unit.kind != Types.UnitKind.PLAYER:
		world.units.erase(unit.id)


static func process_building_death(world: World, building: Building) -> void:
	if building.kind == Types.BuildingKind.DEPOT:
		_spill_depot(world, building)
	_vacate_footprint(world, building)
	var buildings = world.get("buildings")
	if buildings is Dictionary:
		buildings.erase(building.id)


static func _lowest_id_opposing_unit(world: World, proj: Projectile) -> Unit:
	var best: Unit = null
	for unit in world.units.values():
		if not unit.alive or unit.faction == proj.faction:
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
			if not world.in_bounds(x, y) or world.is_walkable(x, y):
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
	if inv == null or (inv.scrap <= 0 and inv.ice <= 0):
		return
	var pile := Loot.new()
	pile.id = world.alloc_id()
	pile.pos = _footprint_aabb(depot).get_center()
	if inv.scrap > 0:
		pile.inventory.add(Types.ResourceKind.SCRAP, inv.scrap)
	if inv.ice > 0:
		pile.inventory.add(Types.ResourceKind.ICE, inv.ice)
	var piles = world.get("loot")
	if piles is Dictionary:
		piles[pile.id] = pile


static func _vacate_footprint(world: World, building: Building) -> void:
	var span := _footprint_span(building.kind)
	for dy in span:
		for dx in span:
			var x: int = building.origin_tile.x + dx
			var y: int = building.origin_tile.y + dy
			if not world.in_bounds(x, y):
				continue
			var i := world.index_of(x, y)
			if world.occupancy[i] == building.id:
				world.occupancy[i] = 0


static func _footprint_span(kind: int) -> int:
	if kind == Types.BuildingKind.HABITAT or kind == Types.BuildingKind.DEPOT:
		return 2
	return 1


static func _footprint_aabb(building: Building) -> Rect2:
	var span := float(_footprint_span(building.kind) * Constants.TILE)
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
