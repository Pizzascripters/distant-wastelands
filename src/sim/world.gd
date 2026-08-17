class_name World
extends RefCounted

var seed: int = 0
var tiles: PackedByteArray = PackedByteArray()
var tiles_generation: int = 0
var buildings: Dictionary = {}
var occupancy: Array[int] = []
var deposits: Dictionary = {}
var loot: Dictionary = {}
var units: Dictionary = {}
var projectiles: Dictionary = {}
var next_id: int = 1


func _init() -> void:
	var n := Constants.MAP_W * Constants.MAP_H
	tiles.resize(n)
	tiles.fill(Types.TileTerrain.EMPTY)
	occupancy.resize(n)
	occupancy.fill(0)


func index_of(x: int, y: int) -> int:
	return y * Constants.MAP_W + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < Constants.MAP_W and y < Constants.MAP_H


func get_terrain(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Types.TileTerrain.ROCK
	return tiles[index_of(x, y)]


func set_terrain(x: int, y: int, terrain: int) -> void:
	if not in_bounds(x, y):
		return
	var i := index_of(x, y)
	if tiles[i] == terrain:
		return
	tiles[i] = terrain
	tiles_generation += 1


func is_walkable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var i := index_of(x, y)
	return tiles[i] == Types.TileTerrain.EMPTY and occupancy[i] == 0


func is_solid(x: int, y: int) -> bool:
	return not is_walkable(x, y)


func tile_center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * Constants.TILE, (y + 0.5) * Constants.TILE)


func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / float(Constants.TILE))), int(floor(pos.y / float(Constants.TILE))))


func tile_aabb(x: int, y: int) -> Rect2:
	return Rect2(x * Constants.TILE, y * Constants.TILE, Constants.TILE, Constants.TILE)


static func footprint_span(kind: int) -> int:
	if (
		kind == Types.BuildingKind.HABITAT
		or kind == Types.BuildingKind.DEPOT
		or kind == Types.BuildingKind.LAB
	):
		return 2
	return 1


func footprint_aabb(building: Building) -> Rect2:
	var span := float(footprint_span(building.kind) * Constants.TILE)
	return Rect2(
		building.origin_tile.x * Constants.TILE,
		building.origin_tile.y * Constants.TILE,
		span,
		span
	)


func occupy(building: Building) -> void:
	if building == null:
		return
	var span := footprint_span(building.kind)
	for dy in span:
		for dx in span:
			var x: int = building.origin_tile.x + dx
			var y: int = building.origin_tile.y + dy
			if not in_bounds(x, y):
				continue
			var i := index_of(x, y)
			var current: int = occupancy[i]
			if current != 0 and current != building.id:
				push_error(
					"occupancy mismatch occupy id=%d tile=(%d,%d) had=%d"
					% [building.id, x, y, current]
				)
				assert(current == 0 or current == building.id)
			occupancy[i] = building.id


func vacate(building: Building) -> void:
	if building == null:
		return
	var span := footprint_span(building.kind)
	for dy in span:
		for dx in span:
			var x: int = building.origin_tile.x + dx
			var y: int = building.origin_tile.y + dy
			if not in_bounds(x, y):
				continue
			var i := index_of(x, y)
			if occupancy[i] == building.id:
				occupancy[i] = 0


func building_at(x: int, y: int) -> Building:
	if not in_bounds(x, y):
		return null
	var bid: int = occupancy[index_of(x, y)]
	if bid <= 0:
		return null
	return buildings.get(bid) as Building


func point_aabb_distance(point: Vector2, aabb: Rect2) -> float:
	var closest := Vector2(
		clampf(point.x, aabb.position.x, aabb.end.x),
		clampf(point.y, aabb.position.y, aabb.end.y)
	)
	return point.distance_to(closest)


func nearest_living_depot(pos: Vector2) -> Building:
	var best: Building = null
	var best_dist := INF
	for building in buildings.values():
		if building.kind != Types.BuildingKind.DEPOT or building.hp <= 0:
			continue
		var dist := point_aabb_distance(pos, footprint_aabb(building))
		if best != null and (dist > best_dist or (dist == best_dist and building.id >= best.id)):
			continue
		best = building
		best_dist = dist
	return best


func alloc_id() -> int:
	var id := next_id
	next_id += 1
	return id
