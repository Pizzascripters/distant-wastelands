extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_empty_map(fails)
	_test_boxed_in(fails)
	_test_no_diagonal_cut(fails)
	_test_no_diagonal_cut_cliffs(fails)
	_test_any_picks_nearer_goal(fails)
	_test_any_empty_when_all_boxed(fails)
	_test_gate_blocks_astar(fails)
	_test_expand_cap_partial_and_inside(fails)
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


func _test_no_diagonal_cut_cliffs(fails: PackedStringArray) -> void:
	var world := World.new()
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			world.set_terrain(x, y, Types.TileTerrain.CLIFF)
	world.set_terrain(1, 1, Types.TileTerrain.EMPTY)
	world.set_terrain(2, 2, Types.TileTerrain.EMPTY)
	var path := Pathfind.find_path(world, Vector2i(1, 1), Vector2i(2, 2))
	if not path.is_empty():
		fails.append("A* cut a diagonal through two corner cliffs")


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


func _test_gate_blocks_astar(fails: PackedStringArray) -> void:
	var world := World.new()
	var gate := Building.new()
	gate.id = world.alloc_id()
	gate.kind = Types.BuildingKind.GATE
	gate.faction = Types.Faction.PLAYER
	gate.origin_tile = Vector2i(5, 0)
	gate.hp = Constants.GATE_HP
	gate.hp_max = Constants.GATE_HP
	world.buildings[gate.id] = gate
	world.occupy(gate)
	if world.is_walkable(5, 0):
		fails.append("Gate tile should not be walkable")
	var path := Pathfind.find_path(world, Vector2i(0, 0), Vector2i(10, 0))
	if path.is_empty():
		fails.append("A* should path around a single Gate")
	elif Vector2i(5, 0) in path:
		fails.append("A* treated a Gate as walkable")
	for x in range(4, 7):
		_place_gate(world, Vector2i(x, 4))
		_place_gate(world, Vector2i(x, 6))
	_place_gate(world, Vector2i(4, 5))
	_place_gate(world, Vector2i(6, 5))
	var boxed := Pathfind.find_path(world, Vector2i(5, 5), Vector2i(10, 10))
	if not boxed.is_empty():
		fails.append("A* should return empty when start is boxed in by Gates")


func _test_expand_cap_partial_and_inside(fails: PackedStringArray) -> void:
	var short_world := World.new()
	var short_goal := Vector2i(40, 0)
	var short := Pathfind.find_path(short_world, Vector2i(0, 0), short_goal)
	if short.is_empty() or short[short.size() - 1] != short_goal:
		fails.append("hallway shorter than PATH_MAX_EXPAND should reach the goal")
	var world := World.new()
	var start := Vector2i(0, 0)
	var goal := Vector2i(Constants.MAP_W - 1, Constants.MAP_H - 1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = goal + d
		if world.in_bounds(n.x, n.y):
			world.set_terrain(n.x, n.y, Types.TileTerrain.ROCK)
	var path := Pathfind.find_path(world, start, goal)
	if path.is_empty():
		fails.append("expand-cap search should return a non-empty prefix")
		return
	if path[0] != start:
		fails.append("partial path should start at the start tile")
	if path[path.size() - 1] == goal:
		fails.append("goal beyond PATH_MAX_EXPAND should not be reached")
	if path.size() < 2:
		fails.append("partial path should advance past the start")


func _place_gate(world: World, tile: Vector2i) -> void:
	var gate := Building.new()
	gate.id = world.alloc_id()
	gate.kind = Types.BuildingKind.GATE
	gate.faction = Types.Faction.PLAYER
	gate.origin_tile = tile
	gate.hp = Constants.GATE_HP
	gate.hp_max = Constants.GATE_HP
	world.buildings[gate.id] = gate
	world.occupy(gate)


func _has_diagonal_step(path: Array[Vector2i]) -> bool:
	for i in range(1, path.size()):
		var d: Vector2i = path[i] - path[i - 1]
		if absi(d.x) + absi(d.y) != 1:
			return true
	return false
