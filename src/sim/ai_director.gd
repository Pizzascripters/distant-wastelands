class_name Director
extends RefCounted

## Wave schedule.

const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

var wave_index: int = 0
var next_wave_at: float = Constants.FIRST_WAVE_AT
var banner_timer: float = 0.0


func maybe_spawn(sim: Sim) -> void:
	if sim == null or sim.time < next_wave_at:
		return
	var spawned := _try_spawn_wave(sim)
	next_wave_at += Constants.WAVE_PERIOD
	wave_index += 1
	if spawned:
		banner_timer = Constants.RAID_BANNER_TIME


func _try_spawn_wave(sim: Sim) -> bool:
	var depot := _living_enemy_depot(sim)
	if depot == null:
		return false
	var tiles := _adjacent_walkable(sim.world, depot)
	if tiles.is_empty():
		return false
	var n := wave_index + 1
	var count := mini(Constants.WAVE_CAP, Constants.WAVE_BASE + int((n - 1) / 2))
	for i in count:
		_spawn_raider(sim.world, tiles[i % tiles.size()])
	return count > 0


func _living_enemy_depot(sim: Sim) -> Building:
	if sim.world == null:
		return null
	var buildings = sim.world.get("buildings")
	if not buildings is Dictionary:
		return null
	var best: Building = null
	for building in buildings.values():
		if building.kind != Types.BuildingKind.DEPOT:
			continue
		if building.faction != Types.Faction.ENEMY:
			continue
		if building.hp <= 0:
			continue
		if best == null or building.id < best.id:
			best = building
	return best


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


func _spawn_raider(world: World, tile: Vector2i) -> void:
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
	world.units[raider.id] = raider
