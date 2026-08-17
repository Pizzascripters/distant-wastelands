class_name Pathfind
extends RefCounted

const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]


static func find_path(world: World, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var goals: Array[Vector2i] = [goal]
	return find_path_any(world, start, goals)


static func find_path_any(world: World, start: Vector2i, goals: Array[Vector2i]) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if goals.is_empty() or not world.is_walkable(start.x, start.y):
		return none
	var map_w := Constants.MAP_W
	var goal_set := {}
	for goal in goals:
		if not world.is_walkable(goal.x, goal.y):
			continue
		var gi := goal.y * map_w + goal.x
		goal_set[gi] = goal
	if goal_set.is_empty():
		return none
	var start_i := start.y * map_w + start.x
	if goal_set.has(start_i):
		var same: Array[Vector2i] = [start]
		return same

	var max_nodes := Constants.MAP_W * Constants.MAP_H
	var g_score := {start_i: 0}
	var came_from := {}
	var in_open := {start_i: true}
	var open: Array[int] = [start_i]
	var expanded := 0

	while not open.is_empty() and expanded < max_nodes:
		var best_idx := 0
		var best_f := 0x7fffffff
		for oi in open.size():
			var ni: int = open[oi]
			var ny: int = int(ni / map_w)
			var nx: int = ni - ny * map_w
			var f: int = int(g_score[ni]) + _min_manhattan(nx, ny, goal_set)
			if f < best_f:
				best_f = f
				best_idx = oi
		var current: int = open[best_idx]
		open.remove_at(best_idx)
		in_open.erase(current)
		expanded += 1

		if goal_set.has(current):
			return _reconstruct(came_from, current, map_w)

		var cy: int = int(current / map_w)
		var cx: int = current - cy * map_w
		var cg: int = int(g_score[current])
		for d in _DIRS:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if not world.is_walkable(nx, ny):
				continue
			var ni: int = ny * map_w + nx
			var tentative: int = cg + 1
			if g_score.has(ni) and tentative >= int(g_score[ni]):
				continue
			came_from[ni] = current
			g_score[ni] = tentative
			if not in_open.has(ni):
				open.append(ni)
				in_open[ni] = true

	return none


static func _min_manhattan(x: int, y: int, goal_set: Dictionary) -> int:
	var best := 0x7fffffff
	for gi in goal_set.keys():
		var goal: Vector2i = goal_set[gi]
		var d: int = absi(x - goal.x) + absi(y - goal.y)
		if d < best:
			best = d
	return best


static func _reconstruct(came_from: Dictionary, current: int, map_w: int) -> Array[Vector2i]:
	var rev: Array[Vector2i] = []
	while true:
		var y: int = int(current / map_w)
		var x: int = current - y * map_w
		rev.append(Vector2i(x, y))
		if not came_from.has(current):
			break
		current = int(came_from[current])
	rev.reverse()
	return rev
