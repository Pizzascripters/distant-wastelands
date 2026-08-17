class_name Director
extends RefCounted

## Per-camp local dispatch + aligned density.

const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

var wave_index: int = 0
var banner_timer: float = 0.0


func maybe_spawn(sim: Sim) -> void:
	if sim == null or sim.world == null:
		return
	for raw in sim.world.camps:
		var camp := raw as World.Camp
		if camp == null:
			continue
		var depot := _living_camp_depot(sim.world, camp)
		if depot == null:
			continue
		var aggroed := _camp_aggroed(sim, depot)
		if aggroed and not camp.ever_aggro:
			camp.ever_aggro = true
		if sim.time < camp.next_raid_at:
			continue
		var spawned := 0
		if aggroed:
			spawned = _try_spawn_raid(sim, camp, depot)
		if spawned > 0:
			banner_timer = Constants.RAID_BANNER_TIME
		camp.next_raid_at += Constants.CAMP_RAID_PERIOD
		wave_index += 1


func _try_spawn_raid(sim: Sim, camp: World.Camp, depot: Building) -> int:
	var tiles := _adjacent_walkable(sim.world, depot)
	var active: Array[Vector2i] = []
	for tile in tiles:
		if sim.world.is_tile_active(tile):
			active.append(tile)
	if active.is_empty():
		return 0
	var spawned := 0
	for _attempt in Constants.CAMP_RAID_SIZE:
		var placed := false
		for tile in active:
			if not Rules.can_spawn_enemy(sim.world, tile):
				continue
			_spawn_raider(sim.world, camp, tile, spawned)
			spawned += 1
			placed = true
			break
		if not placed:
			break
	return spawned


func _camp_aggroed(sim: Sim, depot: Building) -> bool:
	var depot_tile := depot.origin_tile
	var player := sim.get_player()
	if player != null:
		var player_tile := sim.world.world_to_tile(player.pos)
		if _chebyshev(depot_tile, player_tile) <= Constants.CAMP_AGGRO_TILES:
			return true
	for raw in Rules.living_player(sim.world, Types.BuildingKind.HABITAT):
		var habitat := raw as Building
		if habitat == null:
			continue
		if _chebyshev(depot_tile, habitat.origin_tile) <= Constants.CAMP_AGGRO_TILES:
			return true
	return false


func _living_camp_depot(world: World, camp: World.Camp) -> Building:
	if camp.depot_id <= 0:
		return null
	var depot := world.buildings.get(camp.depot_id) as Building
	if depot == null or depot.hp <= 0:
		return null
	if depot.kind != Types.BuildingKind.DEPOT or depot.faction != Types.Faction.ENEMY:
		return null
	return depot


func _adjacent_walkable(world: World, depot: Building) -> Array[Vector2i]:
	var footprint := {}
	for dy in 2:
		for dx in 2:
			footprint[Vector2i(depot.origin_tile.x + dx, depot.origin_tile.y + dy)] = true
	var seen := {}
	for origin in footprint.keys():
		for d in _CARDINALS:
			var n: Vector2i = origin + d
			if footprint.has(n) or not world.is_walkable(n.x, n.y):
				continue
			seen[n.y * Constants.MAP_W + n.x] = n
	var keys: Array = seen.keys()
	keys.sort()
	var tiles: Array[Vector2i] = []
	for key in keys:
		tiles.append(seen[key])
	return tiles


func _spawn_raider(world: World, camp: World.Camp, tile: Vector2i, index: int) -> void:
	var raider := Unit.new()
	raider.id = world.alloc_id()
	raider.kind = Types.UnitKind.RAIDER
	raider.faction = Types.Faction.ENEMY
	raider.pos = world.tile_center(tile.x, tile.y)
	raider.hp = Constants.RAIDER_HP
	raider.hp_max = Constants.RAIDER_HP
	raider.radius = Constants.RAIDER_RADIUS
	raider.aim = Vector2(1, 0)
	raider.alive = true
	raider.inventory = Unit.inventory_for(Types.UnitKind.RAIDER)
	raider.stuck_last_pos = raider.pos
	raider.path_recalc_in = float(index) * Constants.PATH_STAGGER
	raider.home_depot_id = camp.depot_id
	raider.home_pos = raider.pos
	world.units[raider.id] = raider
	if world.spatial != null:
		world.spatial.insert_unit(raider)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
