extends Node2D

const _THEME := preload("res://assets/theme/default.tres")
const _HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const _PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const _END_SCENE := preload("res://scenes/ui/end_screen.tscn")

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
var _gather_bar: GatherBar
var _camera: CameraCtrl
var _hud: Hud
var _build_bar: BuildBar
var _building_panel: BuildingPanel
var _pause_menu: PauseMenu
var _end_screen: EndScreen
var _debug: DebugOverlay
var _ui_layer: CanvasLayer
var _build_kind: int = -1
var _player_world_pos: Vector2 = Vector2.ZERO
var _last_aim: Vector2 = Vector2.RIGHT
var _ended: bool = false
var _ignore_gameplay_input: bool = false
var _latest_snap: SimSnapshot


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
	_gather_bar = GatherBar.new()
	add_child(_gather_bar)
	_camera = CameraCtrl.new()
	add_child(_camera)
	_mount_ui()
	var snap := _session.get_snapshot()
	_latest_snap = snap
	_world_view.rebuild(snap)
	_sync_views(snap)
	if _gather_bar != null:
		_gather_bar.apply_snapshot(snap)
	_camera.snap_to(_player_world_pos)


func _process(delta: float) -> void:
	if _session == null:
		return
	_handle_meta_input()
	if _ended or _is_paused() or _ignore_gameplay_input:
		var idle := InputCommand.new()
		idle.aim = _last_aim
		_session.submit_command(idle)
		_ignore_gameplay_input = false
	else:
		_session.submit_command(_read_command())
	_session.tick(delta)
	var view_started := Time.get_ticks_usec()
	var snap := _session.get_snapshot()
	_latest_snap = snap
	_sync_views(snap)
	if _gather_bar != null:
		_gather_bar.apply_snapshot(snap)
	_update_build_ghost()
	if _hud != null:
		_hud.apply_snapshot(snap)
	if _build_bar != null:
		_build_bar.techs_done = snap.techs_done
	_update_end_screen(snap)
	_update_inspect(snap)
	if _debug != null and _debug.visible:
		snap.view_ms = float(Time.get_ticks_usec() - view_started) * 0.001
		_debug.apply_snapshot(snap)
	_camera.follow(_player_world_pos, delta)


func _mount_ui() -> void:
	var layer := CanvasLayer.new()
	_ui_layer = layer
	add_child(layer)
	_hud = _HUD_SCENE.instantiate() as Hud
	_hud.theme = _THEME
	layer.add_child(_hud)
	_build_bar = BuildBar.new()
	_build_bar.theme = _THEME
	_build_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_build_bar.offset_left = 12.0
	_build_bar.offset_top = -240.0
	_build_bar.offset_right = 280.0
	_build_bar.offset_bottom = -12.0
	layer.add_child(_build_bar)
	_building_panel = BuildingPanel.new()
	_building_panel.theme = _THEME
	_building_panel.visible = false
	_building_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_building_panel.offset_left = -170.0
	_building_panel.offset_right = 170.0
	_building_panel.offset_top = -200.0
	_building_panel.offset_bottom = -72.0
	layer.add_child(_building_panel)
	_pause_menu = _PAUSE_SCENE.instantiate() as PauseMenu
	_pause_menu.theme = _THEME
	_pause_menu.visible = false
	_pause_menu.resume_pressed.connect(_on_resume)
	_pause_menu.quit_to_menu_pressed.connect(_on_quit_to_menu)
	layer.add_child(_pause_menu)
	_end_screen = _END_SCENE.instantiate() as EndScreen
	_end_screen.theme = _THEME
	_end_screen.visible = false
	_end_screen.play_again.connect(_on_play_again)
	_end_screen.menu.connect(_on_quit_to_menu)
	layer.add_child(_end_screen)
	_debug = DebugOverlay.new()
	layer.add_child(_debug)


func _handle_meta_input() -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		if _debug != null:
			_debug.visible = not _debug.visible
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()


func _toggle_pause() -> void:
	if _ended or _session == null:
		return
	if _is_paused():
		_set_paused(false)
	else:
		_set_paused(true)


func _set_paused(paused: bool) -> void:
	if _pause_menu != null:
		_pause_menu.visible = paused
	_session.set_paused(paused)
	if paused:
		_set_build_kind(-1)
		_close_inspect()


func _is_paused() -> bool:
	return _pause_menu != null and _pause_menu.visible


func _update_end_screen(snap: SimSnapshot) -> void:
	if snap.outcome == Types.Outcome.NONE or _end_screen == null:
		return
	if not _ended:
		_ended = true
		_set_paused(false)
		_set_build_kind(-1)
		_close_inspect()
		_end_screen.set_outcome(snap.outcome, snap.outcome_reason)
	_end_screen.visible = true


func _on_resume() -> void:
	if _ended:
		return
	_set_paused(false)
	_ignore_gameplay_input = true


func _on_play_again() -> void:
	App.play_again()


func _on_quit_to_menu() -> void:
	if _session != null:
		_session.set_paused(false)
	App.go_to_menu()


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
	_apply_build_hotkeys(cmd)
	var snap := _latest_snap
	if snap == null and _session != null:
		snap = _session.get_snapshot()
		_latest_snap = snap
	if Input.is_action_just_pressed("inspect"):
		_on_inspect_pressed(snap)
	if Input.is_action_just_pressed("cancel"):
		_on_cancel_pressed(
			snap,
			Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
			get_global_mouse_position(),
			_hud_blocks_pointer()
		)
	cmd.interact = Input.is_action_pressed("interact")
	cmd.withdraw = _command_withdraw(Input.is_action_pressed("withdraw"))
	cmd.build_kind = -1
	_apply_world_click(
		cmd,
		Input.is_action_pressed("fire"),
		Input.is_action_just_pressed("fire"),
		_hud_blocks_pointer()
	)
	return cmd


func _apply_build_hotkeys(cmd: InputCommand) -> void:
	if _lab_panel_open():
		if _building_panel != null:
			var picked := _building_panel.take_research_kind()
			if picked >= 0:
				cmd.research_kind = picked
		if Input.is_action_just_pressed("build_wall"):
			cmd.research_kind = Types.TechKind.HYDROPONICS
		elif Input.is_action_just_pressed("build_turret"):
			cmd.research_kind = Types.TechKind.METALLURGY
		elif Input.is_action_just_pressed("build_workshop"):
			cmd.research_kind = Types.TechKind.FIELD_MEDICINE
		elif Input.is_action_just_pressed("build_lab"):
			cmd.research_kind = Types.TechKind.BALLISTICS
		return
	if _building_panel != null:
		var leftover := _building_panel.take_research_kind()
		if leftover >= 0:
			cmd.research_kind = leftover
	if Input.is_action_just_pressed("build_wall"):
		_try_build_kind(Types.BuildingKind.WALL)
	elif Input.is_action_just_pressed("build_turret"):
		_try_build_kind(Types.BuildingKind.TURRET)
	elif Input.is_action_just_pressed("build_workshop"):
		_try_build_kind(Types.BuildingKind.WORKSHOP)
	elif Input.is_action_just_pressed("build_lab"):
		_try_build_kind(Types.BuildingKind.LAB)
	elif (
		Input.is_action_just_pressed("build_greenhouse")
		or Input.is_action_just_pressed("build_farm")
	):
		_try_build_kind(Types.BuildingKind.FARM)
	elif Input.is_action_just_pressed("build_gate"):
		_try_build_kind(Types.BuildingKind.GATE)
	elif Input.is_action_just_pressed("build_medbay"):
		_try_build_kind(Types.BuildingKind.MEDBAY)


func _try_build_kind(kind: int) -> void:
	if _build_unlocked(kind):
		_set_build_kind(kind)
	elif _build_bar != null:
		_build_bar.flash_locked(kind)


func _build_unlocked(kind: int) -> bool:
	var techs := 0
	if _latest_snap != null:
		techs = _latest_snap.techs_done
	return Research.building_unlocked_bits(techs, kind)


func _lab_panel_open() -> bool:
	return (
		_building_panel != null
		and _building_panel.is_open()
		and _building_panel.inspected_kind() == Types.BuildingKind.LAB
	)


func _set_build_kind(kind: int) -> void:
	_build_kind = kind
	if _build_bar != null:
		_build_bar.selected_kind = kind
	if _ghost != null:
		_ghost.visible = kind >= 0


func _open_inspect(rec: Dictionary) -> void:
	_set_build_kind(-1)
	if _building_panel == null or rec.is_empty():
		return
	_building_panel.open_building(rec)


func _close_inspect() -> void:
	if _building_panel != null:
		_building_panel.close()


func _on_inspect_pressed(snap: SimSnapshot) -> void:
	_set_build_kind(-1)
	if snap == null or not _player_alive(snap):
		_close_inspect()
		return
	var rec := BuildingPanel.nearest_in_range(snap, _player_pos(snap))
	if rec.is_empty():
		_close_inspect()
		return
	if (
		_building_panel != null
		and _building_panel.is_open()
		and _building_panel.inspected_id == int(rec.get("id", -2))
	):
		_close_inspect()
		return
	_open_inspect(rec)


func _on_cancel_pressed(snap: SimSnapshot, is_rmb: bool, world_pos: Vector2, over_hud: bool) -> void:
	if _build_kind >= 0:
		_set_build_kind(-1)
		return
	if is_rmb and over_hud:
		return
	if is_rmb:
		var rec := BuildingPanel.at_world_point(snap, world_pos)
		if rec.is_empty():
			_close_inspect()
		else:
			_open_inspect(rec)
		return
	_close_inspect()


func _update_inspect(snap: SimSnapshot) -> void:
	if _building_panel == null:
		return
	if _ended or _is_paused() or not _player_alive(snap):
		_close_inspect()
		return
	_building_panel.apply_snapshot(snap)


func _command_withdraw(shift_held: bool) -> bool:
	return shift_held or (_building_panel != null and _building_panel.withdraw_active())


func _apply_world_click(cmd: InputCommand, fire_held: bool, fire_just: bool, blocked: bool) -> void:
	if blocked:
		cmd.fire = false
		return
	if _build_kind >= 0:
		cmd.fire = false
		if fire_just:
			cmd.build_kind = _build_kind
			cmd.build_tile = _cursor_tile()
	else:
		cmd.fire = fire_held


func _hud_blocks_pointer(screen_pos: Vector2 = Vector2.INF) -> bool:
	var pos := screen_pos
	if is_inf(pos.x) or is_inf(pos.y):
		var viewport := get_viewport()
		if viewport == null:
			return false
		pos = viewport.get_mouse_position()
	if _ui_layer != null:
		return _node_consumes_pointer(_ui_layer, pos)
	if _building_panel != null:
		return _building_panel.consumes_pointer(pos)
	return false


func _node_consumes_pointer(node: Node, pos: Vector2) -> bool:
	if node == null or not node is CanvasItem:
		return false
	var item := node as CanvasItem
	if not item.visible:
		return false
	if node is Control:
		var ctrl := node as Control
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and ctrl.get_global_rect().has_point(pos):
			return true
	for child in node.get_children():
		if _node_consumes_pointer(child, pos):
			return true
	return false


func _player_alive(snap: SimSnapshot) -> bool:
	if snap == null:
		return false
	for rec in snap.units:
		if int(rec.get("kind", -1)) != Types.UnitKind.PLAYER:
			continue
		if rec.has("alive"):
			return bool(rec["alive"])
		return int(rec.get("hp", 0)) > 0
	return false


func _player_pos(snap: SimSnapshot) -> Vector2:
	if snap != null:
		for rec in snap.units:
			if int(rec.get("kind", -1)) == Types.UnitKind.PLAYER:
				return rec.get("pos", _player_world_pos)
	return _player_world_pos


func _cursor_tile() -> Vector2i:
	var pos := Vector2.ZERO
	if get_viewport() != null:
		pos = get_global_mouse_position()
	return Vector2i(
		int(floor(pos.x / float(Constants.TILE))),
		int(floor(pos.y / float(Constants.TILE)))
	)


func _update_build_ghost() -> void:
	if _ghost == null or _build_kind < 0 or _ended or _is_paused():
		if _ghost != null:
			_ghost.visible = false
		return
	var tile := _cursor_tile()
	var world := _session_world()
	var sim := _session_sim()
	var valid := world != null and sim != null and Rules.can_place(world, sim, _build_kind, tile)
	var span := 1
	if world != null:
		span = world.footprint_span(_build_kind)
	else:
		span = World.footprint_span(_build_kind)
	_ghost.visible = true
	_ghost.apply(tile, valid, span)


func _session_world() -> World:
	var sim := _session_sim()
	if sim != null:
		return sim.world
	return null


func _session_sim() -> Sim:
	if _session is LocalSession:
		return (_session as LocalSession).sim
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
	_bind_keys("withdraw", [KEY_SHIFT])
	_bind_keys("build_wall", [KEY_1])
	_bind_keys("build_turret", [KEY_2])
	_bind_keys("build_workshop", [KEY_3])
	_bind_keys("build_lab", [KEY_4])
	_bind_keys("build_greenhouse", [KEY_5])
	_bind_keys("build_farm", [KEY_5])
	_bind_keys("build_gate", [KEY_6])
	_bind_keys("build_medbay", [KEY_7])
	_bind_keys("inspect", [KEY_F])
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
