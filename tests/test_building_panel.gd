extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_panel_icon_hp_and_depot(fails)
	_test_depot_toggle_defaults_and_withdraw(fails)
	_test_close_on_dead_or_missing_building(fails)
	_test_nearest_and_rmb_targets(fails)
	_test_inspect_cancels_build_and_close_rules(fails)
	_test_withdraw_or_and_hud_blocks_fire(fails)
	return fails


func _test_panel_icon_hp_and_depot(fails: PackedStringArray) -> void:
	var panel := BuildingPanel.new()
	if panel.visible:
		fails.append("panel should start closed")
	panel.open_building({
		"id": 4,
		"kind": Types.BuildingKind.HABITAT,
		"faction": Types.Faction.PLAYER,
		"hp": 160,
		"hp_max": Constants.HABITAT_HP,
		"origin_tile": Constants.PLAYER_HABITAT_TILE,
	})
	if not panel.visible:
		fails.append("opening habitat should show the panel")
	var icon := panel.find_child("Icon", true, false) as TextureRect
	if icon == null or icon.texture == null:
		fails.append("panel should show a building icon")
	var hp := panel.find_child("HpValue", true, false) as Label
	if hp == null or hp.text != "160 / %d" % Constants.HABITAT_HP:
		fails.append("habitat HP text is %s" % (hp.text if hp != null else "missing"))
	var fill := panel.find_child("HpFill", true, false) as ColorRect
	if fill == null or not is_equal_approx(fill.anchor_right, 160.0 / float(Constants.HABITAT_HP)):
		fails.append("HP fill ratio is %s" % (str(fill.anchor_right) if fill != null else "missing"))
	var depot_box := panel.find_child("DepotBox", true, false) as Control
	if depot_box == null or depot_box.visible:
		fails.append("habitat panel should hide depot stocks")
	panel.free()


func _test_depot_toggle_defaults_and_withdraw(fails: PackedStringArray) -> void:
	var panel := BuildingPanel.new()
	var depot := _depot_rec(7, 15, 4, 2, 1)
	panel.open_building(depot)
	var stocks := {
		"Scrap": panel.find_child("ScrapCount", true, false) as Label,
		"Ice": panel.find_child("IceCount", true, false) as Label,
		"Ore": panel.find_child("OreCount", true, false) as Label,
		"Parts": panel.find_child("PartsCount", true, false) as Label,
	}
	var want := {
		"Scrap": "15 / %d" % Constants.DEPOT_CAP_SCRAP,
		"Ice": "4 / %d" % Constants.DEPOT_CAP_ICE,
		"Ore": "2 / %d" % Constants.DEPOT_CAP_ORE,
		"Parts": "1 / %d" % Constants.DEPOT_CAP_PARTS,
	}
	for key in want.keys():
		var lab: Label = stocks[key]
		if lab == null or lab.text != want[key]:
			fails.append("%s stock is %s, expected %s" % [key, lab.text if lab != null else "missing", want[key]])
	if panel.withdraw or panel.withdraw_active():
		fails.append("depot toggle should default to Deposit")
	panel.withdraw = true
	if not panel.withdraw_active():
		fails.append("Withdraw toggle should arm withdraw_active")
	panel.open_building(depot)
	if not panel.withdraw:
		fails.append("re-opening the same open depot should keep the toggle")
	panel.close()
	panel.open_building(depot)
	if panel.withdraw or panel.withdraw_active():
		fails.append("opening a closed depot panel should reset to Deposit")
	var habitat := {
		"id": 1,
		"kind": Types.BuildingKind.HABITAT,
		"faction": Types.Faction.PLAYER,
		"hp": 10,
		"hp_max": Constants.HABITAT_HP,
	}
	panel.withdraw = true
	panel.open_building(habitat)
	if panel.withdraw:
		fails.append("opening a different building should reset the toggle")
	if panel.withdraw_active():
		fails.append("non-depot panel should not arm withdraw")
	panel.free()


func _test_close_on_dead_or_missing_building(fails: PackedStringArray) -> void:
	var panel := BuildingPanel.new()
	var depot := _depot_rec(7, 8, 0, 0, 0)
	panel.open_building(depot)
	var snap := SimSnapshot.new()
	snap.buildings = [depot.duplicate()]
	panel.apply_snapshot(snap)
	if not panel.is_open():
		fails.append("living building should stay inspected")
	var dead := depot.duplicate()
	dead["hp"] = 0
	snap.buildings = [dead]
	panel.apply_snapshot(snap)
	if panel.is_open():
		fails.append("dead building should close the panel")
	panel.open_building(depot)
	snap.buildings = []
	panel.apply_snapshot(snap)
	if panel.is_open():
		fails.append("missing building should close the panel")
	panel.free()


func _test_nearest_and_rmb_targets(fails: PackedStringArray) -> void:
	var habitat := {
		"id": 1,
		"kind": Types.BuildingKind.HABITAT,
		"faction": Types.Faction.PLAYER,
		"hp": 200,
		"hp_max": Constants.HABITAT_HP,
		"origin_tile": Vector2i(6, 52),
	}
	var depot := _depot_rec(2, 1, 1, 1, 1)
	depot["origin_tile"] = Vector2i(9, 52)
	var enemy := {
		"id": 3,
		"kind": Types.BuildingKind.HABITAT,
		"faction": Types.Faction.ENEMY,
		"hp": 200,
		"hp_max": Constants.HABITAT_HP,
		"origin_tile": Vector2i(54, 6),
	}
	var snap := SimSnapshot.new()
	snap.buildings = [habitat, depot, enemy]
	var near_habitat := Vector2(5.5 * Constants.TILE, 53 * Constants.TILE)
	var rec := BuildingPanel.nearest_in_range(snap, near_habitat)
	if int(rec.get("id", -1)) != 1:
		fails.append("F nearest should pick the habitat, got %s" % str(rec.get("id")))
	var far := Vector2(0, 0)
	if not BuildingPanel.nearest_in_range(snap, far).is_empty():
		fails.append("F with nothing in range should return empty")
	var hit := BuildingPanel.at_world_point(snap, Vector2(9.5 * Constants.TILE, 52.5 * Constants.TILE))
	if int(hit.get("id", -1)) != 2:
		fails.append("RMB on depot footprint should hit the depot")
	var enemy_hit := BuildingPanel.at_world_point(snap, Vector2(54.5 * Constants.TILE, 6.5 * Constants.TILE))
	if not enemy_hit.is_empty():
		fails.append("RMB must not inspect an enemy building")
	var dirt := BuildingPanel.at_world_point(snap, Vector2(16, 16))
	if not dirt.is_empty():
		fails.append("RMB on dirt should miss")


func _test_inspect_cancels_build_and_close_rules(fails: PackedStringArray) -> void:
	var view := _make_game_view(fails)
	if view == null:
		return
	var panel := BuildingPanel.new()
	view._building_panel = panel
	var habitat := {
		"id": 1,
		"kind": Types.BuildingKind.HABITAT,
		"faction": Types.Faction.PLAYER,
		"hp": 200,
		"hp_max": Constants.HABITAT_HP,
		"origin_tile": Vector2i(6, 52),
		"pos": Vector2(6 * Constants.TILE, 52 * Constants.TILE),
	}
	var depot := _depot_rec(2, 3, 3, 0, 0)
	depot["origin_tile"] = Vector2i(9, 52)
	depot["pos"] = Vector2(9 * Constants.TILE, 52 * Constants.TILE)
	var snap := SimSnapshot.new()
	snap.buildings = [habitat, depot]
	snap.units = [{
		"kind": Types.UnitKind.PLAYER,
		"alive": true,
		"hp": 50,
		"pos": Vector2(5.5 * Constants.TILE, 53 * Constants.TILE),
	}]
	view._build_kind = Types.BuildingKind.WALL
	view._on_inspect_pressed(snap)
	if view._build_kind != -1:
		fails.append("opening inspect must cancel build mode")
	if not panel.is_open() or panel.inspected_id != 1:
		fails.append("F next to the habitat should open that panel")
	view._on_inspect_pressed(snap)
	if panel.is_open():
		fails.append("F on the same building should toggle the panel closed")
	view._build_kind = Types.BuildingKind.TURRET
	view._on_inspect_pressed(snap)
	if view._build_kind != -1:
		fails.append("F while a ghost is up should still cancel build")
	if not panel.is_open():
		fails.append("F while a ghost is up should still open the panel")
	view._build_kind = Types.BuildingKind.WALL
	view._on_cancel_pressed(snap, true, depot["pos"] + Vector2(8, 8), false)
	if view._build_kind != -1:
		fails.append("RMB in build mode should cancel build")
	if panel.inspected_id != 1:
		fails.append("RMB in build mode must not inspect")
	view._on_cancel_pressed(snap, true, depot["pos"] + Vector2(8, 8), false)
	if panel.inspected_id != 2:
		fails.append("RMB on a player depot should open that panel")
	view._on_cancel_pressed(snap, true, Vector2(16, 16), false)
	if panel.is_open():
		fails.append("RMB on dirt should close the panel")
	view._open_inspect(habitat)
	view._on_cancel_pressed(snap, false, Vector2.ZERO, false)
	if panel.is_open():
		fails.append("Q should close the panel when not building")
	view._open_inspect(habitat)
	view._on_cancel_pressed(snap, true, depot["pos"] + Vector2(8, 8), true)
	if panel.inspected_id != 1:
		fails.append("RMB over the panel must not inspect through it")
	var far := SimSnapshot.new()
	far.buildings = snap.buildings
	far.units = [{
		"kind": Types.UnitKind.PLAYER,
		"alive": true,
		"hp": 50,
		"pos": Vector2(0, 0),
	}]
	view._open_inspect(habitat)
	view._on_inspect_pressed(far)
	if panel.is_open():
		fails.append("F with no building in range should close the panel")
	view._open_inspect(habitat)
	var dead_player := SimSnapshot.new()
	dead_player.buildings = snap.buildings
	dead_player.units = [{
		"kind": Types.UnitKind.PLAYER,
		"alive": false,
		"hp": 0,
		"pos": snap.units[0]["pos"],
	}]
	view._update_inspect(dead_player)
	if panel.is_open():
		fails.append("player death should close the panel")
	view._open_inspect(habitat)
	view._ended = true
	view._update_inspect(snap)
	if panel.is_open():
		fails.append("end screen should close the panel")
	view._ended = false
	view._open_inspect(habitat)
	var pause := PauseMenu.new()
	pause.visible = true
	view._pause_menu = pause
	view._update_inspect(snap)
	if panel.is_open():
		fails.append("pause should close the panel")
	pause.free()
	panel.free()
	view.free()


func _test_withdraw_or_and_hud_blocks_fire(fails: PackedStringArray) -> void:
	var view := _make_game_view(fails)
	if view == null:
		return
	var panel := BuildingPanel.new()
	view._building_panel = panel
	var depot := _depot_rec(2, 4, 4, 0, 0)
	if view._command_withdraw(false):
		fails.append("closed panel should not force withdraw")
	if not view._command_withdraw(true):
		fails.append("Shift should set withdraw with the panel closed")
	panel.open_building(depot)
	if view._command_withdraw(false):
		fails.append("Deposit toggle should not set withdraw")
	if not view._command_withdraw(true):
		fails.append("Shift OR Deposit should still withdraw")
	panel.withdraw = true
	if not view._command_withdraw(false) or not view._command_withdraw(true):
		fails.append("Withdraw toggle should OR into cmd.withdraw")
	panel.position = Vector2(100, 80)
	panel.size = Vector2(220, 100)
	if not view._hud_blocks_pointer(Vector2(150, 120)):
		fails.append("pointer over the panel should block world clicks")
	if view._hud_blocks_pointer(Vector2(8, 8)):
		fails.append("pointer off the panel should not block world clicks")
	var cmd := InputCommand.new()
	view._build_kind = -1
	view._apply_world_click(cmd, true, false, true)
	if cmd.fire:
		fails.append("LMB over the panel must not set cmd.fire")
	cmd = InputCommand.new()
	view._build_kind = Types.BuildingKind.WALL
	view._apply_world_click(cmd, true, true, true)
	if cmd.fire or cmd.build_kind >= 0:
		fails.append("confirm-place must not run while the pointer is over the panel")
	cmd = InputCommand.new()
	view._build_kind = -1
	view._apply_world_click(cmd, true, false, false)
	if not cmd.fire:
		fails.append("world LMB should still fire")
	cmd = InputCommand.new()
	view._build_kind = Types.BuildingKind.WALL
	view._apply_world_click(cmd, true, true, false)
	if cmd.fire or cmd.build_kind != Types.BuildingKind.WALL:
		fails.append("world LMB in build mode should confirm-place")
	panel.free()
	view.free()


func _make_game_view(fails: PackedStringArray) -> Node:
	var script: GDScript = load("res://src/view/game_view.gd")
	if script == null:
		fails.append("failed to load game_view.gd")
		return null
	var view: Node = script.new()
	if view == null:
		fails.append("failed to instantiate GameView")
		return null
	return view


func _depot_rec(id: int, scrap: int, ice: int, ore: int, parts: int) -> Dictionary:
	return {
		"id": id,
		"kind": Types.BuildingKind.DEPOT,
		"faction": Types.Faction.PLAYER,
		"hp": 80,
		"hp_max": Constants.DEPOT_HP,
		"origin_tile": Constants.PLAYER_DEPOT_TILE,
		"inventory": {
			"scrap": scrap,
			"ice": ice,
			"ore": ore,
			"parts": parts,
			"cap_scrap": Constants.DEPOT_CAP_SCRAP,
			"cap_ice": Constants.DEPOT_CAP_ICE,
			"cap_ore": Constants.DEPOT_CAP_ORE,
			"cap_parts": Constants.DEPOT_CAP_PARTS,
		},
	}
