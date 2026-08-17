extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_empty_map(fails)
	_test_boxed_in(fails)
	_test_no_diagonal_cut(fails)
	_test_any_picks_nearer_goal(fails)
	_test_any_empty_when_all_boxed(fails)
	return fails


func _test_empty_map(fails: PackedStringArray) -> void:
	var world := World.new()
	var path := Pathfind.find_path(world, Vector2i(0, 0), Vector2i(10, 0))
	if path.is_empty():
		fails.append("A* found no path on an empty map")
		return
	if path[0] != Vector2i(0, 0) or path[path.size() - 1] != Vector2i(10, 0):
		fails.append("A* empty-map path does not run from start to goal")
	if path.size() != 11:
		fails.append("A* empty-map path length is %d, expected 11" % path.size())
	if _has_diagonal_step(path):
		fails.append("A* used a diagonal step on an empty map")


func _test_boxed_in(fails: PackedStringArray) -> void:
	var world := World.new()
	for x in range(4, 7):
		world.set_terrain(x, 4, Types.TileTerrain.ROCK)
		world.set_terrain(x, 6, Types.TileTerrain.ROCK)
	world.set_terrain(4, 5, Types.TileTerrain.ROCK)
	world.set_terrain(6, 5, Types.TileTerrain.ROCK)
	var path := Pathfind.find_path(world, Vector2i(5, 5), Vector2i(10, 10))
	if not path.is_empty():
		fails.append("A* should return empty when start is boxed in")


func _test_no_diagonal_cut(fails: PackedStringArray) -> void:
	var world := World.new()
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			world.set_terrain(x, y, Types.TileTerrain.ROCK)
	world.set_terrain(1, 1, Types.TileTerrain.EMPTY)
	world.set_terrain(2, 2, Types.TileTerrain.EMPTY)
	var path := Pathfind.find_path(world, Vector2i(1, 1), Vector2i(2, 2))
	if not path.is_empty():
		fails.append("A* cut a diagonal through two corner rocks")


func _test_any_picks_nearer_goal(fails: PackedStringArray) -> void:
	var world := World.new()
	var start := Vector2i(0, 0)
	var near := Vector2i(2, 0)
	var far := Vector2i(10, 0)
	var goals: Array[Vector2i] = [far, near]
	var path := Pathfind.find_path_any(world, start, goals)
	if path.is_empty():
		fails.append("find_path_any found no path to either goal")
		return
	if path[path.size() - 1] != near:
		fails.append("find_path_any ended at %s, expected nearer goal %s" % [str(path[path.size() - 1]), str(near)])
	if path.size() != 3:
		fails.append("find_path_any nearer path length is %d, expected 3" % path.size())


func _test_any_empty_when_all_boxed(fails: PackedStringArray) -> void:
	var world := World.new()
	for x in range(4, 7):
		world.set_terrain(x, 4, Types.TileTerrain.ROCK)
		world.set_terrain(x, 6, Types.TileTerrain.ROCK)
	world.set_terrain(4, 5, Types.TileTerrain.ROCK)
	world.set_terrain(6, 5, Types.TileTerrain.ROCK)
	var goals: Array[Vector2i] = [Vector2i(10, 10), Vector2i(11, 11)]
	var path := Pathfind.find_path_any(world, Vector2i(5, 5), goals)
	if not path.is_empty():
		fails.append("find_path_any should return empty when start is boxed in")


func _has_diagonal_step(path: Array[Vector2i]) -> bool:
	for i in range(1, path.size()):
		var d: Vector2i = path[i] - path[i - 1]
		if absi(d.x) + absi(d.y) != 1:
			return true
	return false
