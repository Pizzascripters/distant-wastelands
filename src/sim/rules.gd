class_name Rules
extends RefCounted


static func cost_scrap(kind: int) -> int:
	match kind:
		Types.BuildingKind.WALL:
			return Constants.WALL_COST
		Types.BuildingKind.TURRET:
			return Constants.TURRET_COST
		_:
			return -1


static func can_place(world: World, kind: int, tile: Vector2i) -> bool:
	var cost := cost_scrap(kind)
	if cost < 0:
		return false
	var span := world.footprint_span(kind)
	for dy in span:
		for dx in span:
			var x: int = tile.x + dx
			var y: int = tile.y + dy
			if not world.in_bounds(x, y):
				return false
			if world.get_terrain(x, y) != Types.TileTerrain.EMPTY:
				return false
			if world.building_at(x, y) != null:
				return false
			if _deposit_at(world, Vector2i(x, y)):
				return false
			if Constants.ENEMY_CAMP_RECT.has_point(Vector2i(x, y)):
				return false
			if _unit_overlaps_tile(world, Vector2i(x, y)):
				return false
	var depot := _living_player_depot(world)
	if depot == null or depot.inventory == null:
		return false
	if depot.inventory.scrap < cost:
		return false
	if world.buildings.size() >= Constants.MAX_BUILDINGS:
		return false
	return true


static func try_place(world: World, kind: int, tile: Vector2i) -> bool:
	if not can_place(world, kind, tile):
		return false
	var depot := _living_player_depot(world)
	depot.inventory.remove(Types.ResourceKind.SCRAP, cost_scrap(kind))
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = kind
	building.faction = Types.Faction.PLAYER
	building.origin_tile = tile
	building.hp = _hp_for(kind)
	building.hp_max = building.hp
	building.aim = Vector2(1, 0)
	world.buildings[building.id] = building
	world.occupy(building)
	return true


static func _hp_for(kind: int) -> int:
	match kind:
		Types.BuildingKind.WALL:
			return Constants.WALL_HP
		Types.BuildingKind.TURRET:
			return Constants.TURRET_HP
		_:
			return 0


static func _living_player_depot(world: World) -> Building:
	for building in world.buildings.values():
		if building.kind != Types.BuildingKind.DEPOT:
			continue
		if building.faction != Types.Faction.PLAYER:
			continue
		if building.hp <= 0:
			continue
		return building
	return null


static func _deposit_at(world: World, tile: Vector2i) -> bool:
	for deposit in world.deposits.values():
		if deposit.tile == tile:
			return true
	return false


static func _unit_overlaps_tile(world: World, tile: Vector2i) -> bool:
	var aabb := world.tile_aabb(tile.x, tile.y)
	for unit in world.units.values():
		if world.point_aabb_distance(unit.pos, aabb) <= unit.radius:
			return true
	return false
