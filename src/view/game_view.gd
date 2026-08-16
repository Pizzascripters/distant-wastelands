extends Node2D

var _session: Session
var _world_view: WorldView
var _units_root: Node2D
var _unit_views: Dictionary = {}
var _camera: CameraCtrl
var _player_world_pos: Vector2 = Vector2.ZERO
var _last_aim: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_ensure_actions()
	_session = App.current_session
	if _session == null:
		App.go_to_menu()
		return
	_world_view = WorldView.new()
	add_child(_world_view)
	_units_root = Node2D.new()
	add_child(_units_root)
	_camera = CameraCtrl.new()
	add_child(_camera)
	var snap := _session.get_snapshot()
	_world_view.rebuild(snap)
	_sync_units(snap)
	_camera.snap_to(_player_world_pos)


func _process(delta: float) -> void:
	if _session == null:
		return
	_session.submit_command(_read_command())
	_session.tick(delta)
	var snap := _session.get_snapshot()
	_sync_units(snap)
	_camera.follow(_player_world_pos, delta)


func _read_command() -> InputCommand:
	var cmd := InputCommand.new()
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		move.x -= 1.0
	if Input.is_action_pressed("move_right"):
		move.x += 1.0
	if Input.is_action_pressed("move_up"):
		move.y -= 1.0
	if Input.is_action_pressed("move_down"):
		move.y += 1.0
	if move.length() > 1.0:
		move = move.normalized()
	cmd.move = move
	var to_mouse := get_global_mouse_position() - _player_world_pos
	if to_mouse.length() < Constants.AIM_DEADZONE:
		cmd.aim = _last_aim
	else:
		cmd.aim = to_mouse.normalized()
		_last_aim = cmd.aim
	cmd.fire = Input.is_action_pressed("fire")
	cmd.interact = Input.is_action_pressed("interact")
	cmd.build_kind = -1
	return cmd


func _sync_units(snap: SimSnapshot) -> void:
	var seen := {}
	for rec in snap.units:
		var id: int = rec["id"]
		seen[id] = true
		var view: UnitView = _unit_views.get(id)
		if view == null:
			view = UnitView.new()
			_units_root.add_child(view)
			_unit_views[id] = view
		view.apply_record(rec)
		if rec["kind"] == Types.UnitKind.PLAYER:
			_player_world_pos = rec["pos"]
	var stale: Array = []
	for id in _unit_views.keys():
		if not seen.has(id):
			stale.append(id)
	for id in stale:
		(_unit_views[id] as UnitView).queue_free()
		_unit_views.erase(id)


func _ensure_actions() -> void:
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_mouse("zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_bind_mouse("zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_keys("interact", [KEY_E])
	_bind_keys("build_wall", [KEY_1])
	_bind_keys("build_turret", [KEY_2])
	_bind_keys("cancel", [KEY_Q])
	_bind_mouse("cancel", MOUSE_BUTTON_RIGHT)
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("debug_overlay", [KEY_F3])


func _bind_keys(action: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		if _action_has_key(action, keycode):
			continue
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if _action_has_mouse(action, button):
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _action_has_key(action: String, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).keycode == keycode:
			return true
	return false


func _action_has_mouse(action: String, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == button:
			return true
	return false
