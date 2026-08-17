class_name PathQueue
extends RefCounted

## FIFO A* queue. At most MAX_PATHS_PER_TICK completions per service().

var completed_this_tick: int = 0
var _unit_ids: Array[int] = []
var _units: Array[Unit] = []
var _starts: Array[Vector2i] = []
var _goals: Array = []


func request(unit: Unit, start: Vector2i, goals: Array[Vector2i]) -> void:
	if unit == null:
		return
	unit.path_pending = true
	var copy: Array[Vector2i] = []
	for goal in goals:
		copy.append(goal)
	for i in _unit_ids.size():
		if _unit_ids[i] == unit.id:
			_units[i] = unit
			_starts[i] = start
			_goals[i] = copy
			return
	_unit_ids.append(unit.id)
	_units.append(unit)
	_starts.append(start)
	_goals.append(copy)


func service(world: World) -> void:
	completed_this_tick = 0
	if world == null:
		return
	var i := 0
	while i < _unit_ids.size() and completed_this_tick < Constants.MAX_PATHS_PER_TICK:
		var unit: Unit = _units[i]
		var start: Vector2i = _starts[i]
		var goals: Array[Vector2i] = []
		for goal in _goals[i]:
			goals.append(goal)
		_unit_ids.remove_at(i)
		_units.remove_at(i)
		_starts.remove_at(i)
		_goals.remove_at(i)
		if unit == null or not unit.path_pending:
			continue
		unit.path = Pathfind.find_path_any(world, start, goals)
		unit.path_pending = false
		unit.path_computed = true
		completed_this_tick += 1
