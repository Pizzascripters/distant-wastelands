extends RefCounted

func test_empty_map() -> PackedStringArray:
	var fails := PackedStringArray()
	var world := World.new()
	var path := Pathfind.find_path(world, Vector2i(0, 0), Vector2i(10, 0))
	if path.is_empty():
		fails.append("A* found no path on an empty map")
		return fails
	if path[0] != Vector2i(0, 0) or path[path.size() - 1] != Vector2i(10, 0):
		fails.append("A* empty-map path does not run from start to goal")
	if path.size() != 11:
		fails.append("A* empty-map path length is %d, expected 11" % path.size())
	if _has_diagonal_step(path):
		fails.append("A* used a diagonal step on an empty map")
	return fails


func test_boxed_in() -> PackedStringArray:
	var fails := PackedStringArray()
	var world := World.new()
	for x in range(4, 7):
		world.set_terrain(x, 4, Types.TileTerrain.ROCK)
		world.set_terrain(x, 6, Types.TileTerrain.ROCK)
	world.set_terrain(4, 5, Types.TileTerrain.ROCK)
	world.set_terrain(6, 5, Types.TileTerrain.ROCK)
	var path := Pathfind.find_path(world, Vector2i(5, 5), Vector2i(10, 10))
	if not path.is_empty():
		fails.append("A* should return empty when start is boxed in")
	return fails


func test_no_diagonal_cut() -> PackedStringArray:
	var fails := PackedStringArray()
	var world := World.new()
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			world.set_terrain(x, y, Types.TileTerrain.ROCK)
	world.set_terrain(1, 1, Types.TileTerrain.EMPTY)
	world.set_terrain(2, 2, Types.TileTerrain.EMPTY)
	var path := Pathfind.find_path(world, Vector2i(1, 1), Vector2i(2, 2))
	if not path.is_empty():
		fails.append("A* cut a diagonal through two corner rocks")
	return fails


func _has_diagonal_step(path: Array[Vector2i]) -> bool:
	for i in range(1, path.size()):
		var d: Vector2i = path[i] - path[i - 1]
		if absi(d.x) + absi(d.y) != 1:
			return true
	return false
