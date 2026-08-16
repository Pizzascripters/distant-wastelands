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


static func resolve_interact(world: World, unit: Unit, cmd: InputCommand, last_target_id: int) -> int:
	if unit == null:
		return 0
	if not unit.alive or unit.inventory == null or world == null:
		unit.interact_progress = 0.0
		return 0
	if cmd == null or not cmd.interact or cmd.move.length() > 0.0:
		unit.interact_progress = 0.0
		return 0

	var depot := _interact_depot(world, unit.pos)
	if depot != null:
		_begin_channel(unit, last_target_id, depot.id)
		_tick_depot_transfer(unit, depot)
		return depot.id
	var pile := _interact_loot(world, unit.pos)
	if pile != null:
		_begin_channel(unit, last_target_id, pile.id)
		_tick_loot(world, unit, pile)
		return pile.id
	var deposit := _interact_deposit(world, unit)
	if deposit != null:
		_begin_channel(unit, last_target_id, deposit.id)
		_tick_gather(world, unit, deposit)
		return deposit.id
	unit.interact_progress = 0.0
	return 0


static func _begin_channel(unit: Unit, last_target_id: int, target_id: int) -> void:
	if target_id != last_target_id:
		unit.interact_progress = 0.0


static func _tick_depot_transfer(unit: Unit, depot: Building) -> void:
	unit.interact_progress += Constants.SIM_DT
	if depot.inventory == null:
		return
	var src: Inventory = unit.inventory
	var dest: Inventory = depot.inventory
	if depot.faction != unit.faction:
		src = depot.inventory
		dest = unit.inventory
	while unit.interact_progress >= Constants.TRANSFER_PERIOD:
		unit.interact_progress -= Constants.TRANSFER_PERIOD
		_move_up_to(src, dest, Types.ResourceKind.SCRAP, Constants.TRANSFER_BATCH)
		_move_up_to(src, dest, Types.ResourceKind.ICE, Constants.TRANSFER_BATCH)


static func _tick_loot(world: World, unit: Unit, pile: Loot) -> void:
	unit.interact_progress += Constants.SIM_DT
	if unit.interact_progress < Constants.LOOT_CHANNEL:
		return
	unit.interact_progress = 0.0
	if pile.inventory != null:
		_move_up_to(pile.inventory, unit.inventory, Types.ResourceKind.SCRAP, pile.inventory.scrap)
		_move_up_to(pile.inventory, unit.inventory, Types.ResourceKind.ICE, pile.inventory.ice)
		if pile.inventory.scrap > 0 or pile.inventory.ice > 0:
			return
	world.loot.erase(pile.id)


static func _tick_gather(world: World, unit: Unit, deposit: Deposit) -> void:
	unit.interact_progress += Constants.SIM_DT
	if unit.interact_progress < Constants.GATHER_CHANNEL:
		return
	unit.interact_progress = 0.0
	if deposit.remaining <= 0 or unit.inventory.free_space(deposit.kind) <= 0:
		return
	unit.inventory.add(deposit.kind, 1)
	deposit.remaining -= 1
	if deposit.remaining <= 0:
		world.deposits.erase(deposit.id)


static func _move_up_to(src: Inventory, dest: Inventory, kind: int, n: int) -> void:
	if src == null or dest == null or n <= 0:
		return
	var have := src.scrap if kind == Types.ResourceKind.SCRAP else src.ice
	var amt := mini(n, mini(have, dest.free_space(kind)))
	if amt <= 0:
		return
	src.remove(kind, amt)
	dest.add(kind, amt)


static func _interact_depot(world: World, pos: Vector2) -> Building:
	var depot := world.nearest_living_depot(pos)
	if depot == null:
		return null
	if world.point_aabb_distance(pos, world.footprint_aabb(depot)) > Constants.INTERACT_BUILDING_RANGE:
		return null
	return depot


static func _interact_loot(world: World, pos: Vector2) -> Loot:
	var best: Loot = null
	var best_dist := INF
	for pile in world.loot.values():
		var dist := pos.distance_to(pile.pos)
		if dist > Constants.GATHER_RANGE:
			continue
		if best != null and (dist > best_dist or (dist == best_dist and pile.id >= best.id)):
			continue
		best = pile
		best_dist = dist
	return best


static func _interact_deposit(world: World, unit: Unit) -> Deposit:
	var best: Deposit = null
	var best_dist := INF
	for deposit in world.deposits.values():
		if deposit.remaining <= 0:
			continue
		if unit.inventory.free_space(deposit.kind) <= 0:
			continue
		var dist := unit.pos.distance_to(world.tile_center(deposit.tile.x, deposit.tile.y))
		if dist > Constants.GATHER_RANGE:
			continue
		if best != null and (dist > best_dist or (dist == best_dist and deposit.id >= best.id)):
			continue
		best = deposit
		best_dist = dist
	return best


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
