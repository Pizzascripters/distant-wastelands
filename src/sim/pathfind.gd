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

	var max_nodes := Constants.PATH_MAX_EXPAND
	var g_score := {start_i: 0}
	var came_from := {}
	var closed := {}
	var heap_f: Array[int] = []
	var heap_n: Array[int] = []
	var start_h := _min_manhattan(start.x, start.y, goal_set)
	_heap_push(heap_f, heap_n, start_h, start_i)
	var expanded := 0
	var best_node := start_i
	var best_f := start_h
	var best_g := 0

	while not heap_n.is_empty():
		if expanded >= max_nodes:
			return _reconstruct(came_from, best_node, map_w)
		var current := _heap_pop(heap_f, heap_n)
		if closed.has(current):
			continue
		closed[current] = true
		expanded += 1

		if goal_set.has(current):
			return _reconstruct(came_from, current, map_w)

		var cy: int = int(current / map_w)
		var cx: int = current - cy * map_w
		var cg: int = int(g_score[current])
		var cf: int = cg + _min_manhattan(cx, cy, goal_set)
		if cf < best_f or (cf == best_f and cg > best_g):
			best_f = cf
			best_g = cg
			best_node = current
		for d in _DIRS:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if not world.is_walkable(nx, ny):
				continue
			var ni: int = ny * map_w + nx
			if closed.has(ni):
				continue
			var tentative: int = cg + 1
			if g_score.has(ni) and tentative >= int(g_score[ni]):
				continue
			came_from[ni] = current
			g_score[ni] = tentative
			_heap_push(heap_f, heap_n, tentative + _min_manhattan(nx, ny, goal_set), ni)

	return none


static func _min_manhattan(x: int, y: int, goal_set: Dictionary) -> int:
	var best := 0x7fffffff
	for gi in goal_set.keys():
		var goal: Vector2i = goal_set[gi]
		var d: int = absi(x - goal.x) + absi(y - goal.y)
		if d < best:
			best = d
	return best


static func _heap_push(heap_f: Array[int], heap_n: Array[int], f: int, n: int) -> void:
	heap_f.append(f)
	heap_n.append(n)
	var i := heap_f.size() - 1
	while i > 0:
		var p := int((i - 1) / 2)
		if heap_f[p] <= heap_f[i]:
			break
		var tf: int = heap_f[p]
		heap_f[p] = heap_f[i]
		heap_f[i] = tf
		var tn: int = heap_n[p]
		heap_n[p] = heap_n[i]
		heap_n[i] = tn
		i = p


static func _heap_pop(heap_f: Array[int], heap_n: Array[int]) -> int:
	var n: int = heap_n[0]
	var last := heap_n.size() - 1
	heap_f[0] = heap_f[last]
	heap_n[0] = heap_n[last]
	heap_f.remove_at(last)
	heap_n.remove_at(last)
	var i := 0
	var count := heap_n.size()
	while true:
		var l := i * 2 + 1
		if l >= count:
			break
		var r := l + 1
		var best := l
		if r < count and heap_f[r] < heap_f[l]:
			best = r
		if heap_f[i] <= heap_f[best]:
			break
		var tf: int = heap_f[i]
		heap_f[i] = heap_f[best]
		heap_f[best] = tf
		var tn: int = heap_n[i]
		heap_n[i] = heap_n[best]
		heap_n[best] = tn
		i = best
	return n


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
