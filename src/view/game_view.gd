extends Node2D

const _THEME := preload("res://assets/theme/default.tres")
const _HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _session: Session
var _world_view: WorldView
var _buildings_root: Node2D
var _building_views: Dictionary = {}
var _loot_root: Node2D
var _loot_views: Dictionary = {}
var _units_root: Node2D
var _unit_views: Dictionary = {}
var _projectiles_root: Node2D
var _projectile_views: Dictionary = {}
var _ghost: BuildGhost
var _camera: CameraCtrl
var _hud: Hud
var _build_bar: BuildBar
var _build_kind: int = -1
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
	_buildings_root = Node2D.new()
	add_child(_buildings_root)
	_loot_root = Node2D.new()
	add_child(_loot_root)
	_units_root = Node2D.new()
	add_child(_units_root)
	_projectiles_root = Node2D.new()
	add_child(_projectiles_root)
	_ghost = BuildGhost.new()
	_ghost.visible = false
	_ghost.z_index = 10
	add_child(_ghost)
	_camera = CameraCtrl.new()
	add_child(_camera)
	_mount_ui()
	var snap := _session.get_snapshot()
	_world_view.rebuild(snap)
	_sync_views(snap)
	_camera.snap_to(_player_world_pos)


func _process(delta: float) -> void:
	if _session == null:
		return
	_session.submit_command(_read_command())
	_session.tick(delta)
	var snap := _session.get_snapshot()
	_sync_views(snap)
	_update_build_ghost()
	if _hud != null:
		_hud.apply_snapshot(snap)
	_camera.follow(_player_world_pos, delta)


func _mount_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = _HUD_SCENE.instantiate() as Hud
	_hud.theme = _THEME
	layer.add_child(_hud)
	_build_bar = BuildBar.new()
	_build_bar.theme = _THEME
	_build_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_build_bar.offset_left = 12.0
	_build_bar.offset_top = -64.0
	_build_bar.offset_right = 220.0
	_build_bar.offset_bottom = -12.0
	layer.add_child(_build_bar)


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
	if Input.is_action_just_pressed("build_wall"):
		_set_build_kind(Types.BuildingKind.WALL)
	elif Input.is_action_just_pressed("build_turret"):
		_set_build_kind(Types.BuildingKind.TURRET)
	if Input.is_action_just_pressed("cancel"):
		_set_build_kind(-1)
	cmd.interact = Input.is_action_pressed("interact")
	cmd.build_kind = -1
	if _build_kind >= 0:
		cmd.fire = false
		if Input.is_action_just_pressed("fire"):
			cmd.build_kind = _build_kind
			cmd.build_tile = _cursor_tile()
	else:
		cmd.fire = Input.is_action_pressed("fire")
	return cmd


func _set_build_kind(kind: int) -> void:
	_build_kind = kind
	if _build_bar != null:
		_build_bar.selected_kind = kind
	if _ghost != null:
		_ghost.visible = kind >= 0


func _cursor_tile() -> Vector2i:
	var pos := get_global_mouse_position()
	return Vector2i(
		int(floor(pos.x / float(Constants.TILE))),
		int(floor(pos.y / float(Constants.TILE)))
	)


func _update_build_ghost() -> void:
	if _ghost == null or _build_kind < 0:
		if _ghost != null:
			_ghost.visible = false
		return
	var tile := _cursor_tile()
	var world := _session_world()
	var valid := world != null and Rules.can_place(world, _build_kind, tile)
	_ghost.visible = true
	_ghost.apply(tile, valid)


func _session_world() -> World:
	if _session is LocalSession:
		var local := _session as LocalSession
		if local.sim != null:
			return local.sim.world
	return null


func _sync_views(snap: SimSnapshot) -> void:
	_world_view.apply_deposits(snap)
	_sync_records(snap.buildings, _building_views, _buildings_root, BuildingView)
	_sync_records(snap.loot, _loot_views, _loot_root, LootView)
	_sync_records(snap.units, _unit_views, _units_root, UnitView)
	_sync_records(snap.projectiles, _projectile_views, _projectiles_root, ProjectileView)
	for rec in snap.units:
		if rec["kind"] == Types.UnitKind.PLAYER:
			_player_world_pos = rec["pos"]


func _sync_records(records: Array, views: Dictionary, root: Node2D, script: GDScript) -> void:
	var seen := {}
	for rec in records:
		var id: int = rec["id"]
		seen[id] = true
		var view = views.get(id)
		if view == null:
			view = script.new()
			root.add_child(view)
			views[id] = view
		view.apply_record(rec)
	var stale: Array = []
	for id in views.keys():
		if not seen.has(id):
			stale.append(id)
	for id in stale:
		views[id].queue_free()
		views.erase(id)


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
