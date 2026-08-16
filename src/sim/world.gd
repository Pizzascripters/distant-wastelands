class_name World
extends RefCounted

var seed: int = 0
var tiles: PackedByteArray = PackedByteArray()
var occupancy: Array[int] = []
var units: Dictionary = {}
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
	if in_bounds(x, y):
		tiles[index_of(x, y)] = terrain


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


func alloc_id() -> int:
	var id := next_id
	next_id += 1
	return id
