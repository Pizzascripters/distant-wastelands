extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_apply_deposits_drops_removed(fails)
	_test_placeholder_pngs_load(fails)
	_test_rebuild_caches_terrain(fails)
	_test_apply_deposits_redraws_only_on_change(fails)
	_test_unit_view_redraws_on_visual_change(fails)
	_test_building_view_aim_only_for_turret(fails)
	_test_projectile_view_first_or_faction(fails)
	return fails


func _test_apply_deposits_drops_removed(fails: PackedStringArray) -> void:
	var view := WorldView.new()
	var snap := SimSnapshot.new()
	snap.deposits = [{
		"id": 3,
		"kind": Types.ResourceKind.SCRAP,
		"pos": Vector2(16, 16),
		"tile": Vector2i(0, 0),
		"remaining": 8,
	}]
	view.rebuild(snap)
	if view._deposits.size() != 1:
		fails.append("rebuild left %d deposits, expected 1" % view._deposits.size())

	var empty := SimSnapshot.new()
	view.apply_deposits(empty)
	if not view._deposits.is_empty():
		fails.append("apply_deposits kept %d deposits after the pile was removed" % view._deposits.size())
	view.free()


func _test_placeholder_pngs_load(fails: PackedStringArray) -> void:
	if WorldView.load_png("res://assets/sprites/placeholder/scrap.png") == null:
		fails.append("placeholder scrap.png failed to load")
	if WorldView.load_png("res://assets/sprites/placeholder/ice.png") == null:
		fails.append("placeholder ice.png failed to load")
	if WorldView.load_png("res://assets/sprites/placeholder/player.png") == null:
		fails.append("placeholder player.png failed to load")


func _test_rebuild_caches_terrain(fails: PackedStringArray) -> void:
	var view := WorldView.new()
	var snap := SimSnapshot.new()
	snap.tiles.resize(Constants.MAP_W * Constants.MAP_H)
	snap.tiles.fill(Types.TileTerrain.EMPTY)
	snap.tiles[0] = Types.TileTerrain.ROCK
	view.rebuild(snap)
	if view._terrain_tex == null:
		fails.append("rebuild did not create a terrain cache texture")
	else:
		var want_w := Constants.MAP_W * Constants.TILE
		var want_h := Constants.MAP_H * Constants.TILE
		if view._terrain_tex.get_width() != want_w or view._terrain_tex.get_height() != want_h:
			fails.append(
				"terrain cache is %dx%d, expected %dx%d"
				% [view._terrain_tex.get_width(), view._terrain_tex.get_height(), want_w, want_h]
			)
	view.free()


func _test_apply_deposits_redraws_only_on_change(fails: PackedStringArray) -> void:
	var view := WorldView.new()
	var snap := SimSnapshot.new()
	snap.deposits = [{
		"id": 3,
		"kind": Types.ResourceKind.SCRAP,
		"pos": Vector2(16, 16),
		"tile": Vector2i(0, 0),
		"remaining": 8,
	}]
	view.rebuild(snap)
	var after_rebuild := view._overlay_redraws
	if after_rebuild < 1:
		fails.append("rebuild should draw the deposit overlay")

	var same := SimSnapshot.new()
	same.deposits = [{
		"id": 3,
		"kind": Types.ResourceKind.SCRAP,
		"pos": Vector2(16, 16),
		"tile": Vector2i(0, 0),
		"remaining": 8,
	}]
	view.apply_deposits(same)
	if view._overlay_redraws != after_rebuild:
		fails.append("unchanged deposits queued an overlay redraw")

	var less := SimSnapshot.new()
	less.deposits = [{
		"id": 3,
		"kind": Types.ResourceKind.SCRAP,
		"pos": Vector2(16, 16),
		"tile": Vector2i(0, 0),
		"remaining": 7,
	}]
	view.apply_deposits(less)
	if view._overlay_redraws != after_rebuild + 1:
		fails.append("remaining change did not redraw the overlay")
	if view._deposits.size() != 1 or int(view._deposits[0].get("remaining", 0)) != 7:
		fails.append("remaining change did not update cached deposits")

	var swapped := SimSnapshot.new()
	swapped.deposits = [{
		"id": 9,
		"kind": Types.ResourceKind.ICE,
		"pos": Vector2(48, 48),
		"tile": Vector2i(1, 1),
		"remaining": 7,
	}]
	view.apply_deposits(swapped)
	if view._overlay_redraws != after_rebuild + 2:
		fails.append("deposit id-set change did not redraw the overlay")
	view.free()


func _test_unit_view_redraws_on_visual_change(fails: PackedStringArray) -> void:
	var view := UnitView.new()
	var rec := {
		"pos": Vector2(10, 20),
		"aim": Vector2.RIGHT,
		"kind": Types.UnitKind.PLAYER,
		"alive": true,
		"hp": 5,
	}
	view.apply_record(rec)
	var after_first := view._redraws
	if after_first < 1:
		fails.append("first unit apply should queue a redraw")
	view.apply_record(rec.duplicate())
	if view._redraws != after_first:
		fails.append("identical unit record queued a redraw")
	var moved := rec.duplicate()
	moved["pos"] = Vector2(11, 20)
	view.apply_record(moved)
	if view._redraws != after_first + 1:
		fails.append("unit pos change did not queue a redraw")
	var aimed := moved.duplicate()
	aimed["aim"] = Vector2.UP
	view.apply_record(aimed)
	if view._redraws != after_first + 2:
		fails.append("unit aim change did not queue a redraw")
	view.free()


func _test_building_view_aim_only_for_turret(fails: PackedStringArray) -> void:
	var wall := BuildingView.new()
	var wall_rec := {
		"kind": Types.BuildingKind.WALL,
		"faction": Types.Faction.PLAYER,
		"aim": Vector2.RIGHT,
		"origin_tile": Vector2i(2, 3),
		"hp": 4,
	}
	wall.apply_record(wall_rec)
	var wall_first := wall._redraws
	var wall_aimed := wall_rec.duplicate()
	wall_aimed["aim"] = Vector2.UP
	wall.apply_record(wall_aimed)
	if wall._redraws != wall_first:
		fails.append("non-turret aim change queued a redraw")
	wall.free()

	var turret := BuildingView.new()
	var turret_rec := {
		"kind": Types.BuildingKind.TURRET,
		"faction": Types.Faction.PLAYER,
		"aim": Vector2.RIGHT,
		"origin_tile": Vector2i(4, 5),
		"hp": 4,
	}
	turret.apply_record(turret_rec)
	var turret_first := turret._redraws
	turret.apply_record(turret_rec.duplicate())
	if turret._redraws != turret_first:
		fails.append("identical turret record queued a redraw")
	var turret_aimed := turret_rec.duplicate()
	turret_aimed["aim"] = Vector2.UP
	turret.apply_record(turret_aimed)
	if turret._redraws != turret_first + 1:
		fails.append("turret aim change did not queue a redraw")
	turret.free()


func _test_projectile_view_first_or_faction(fails: PackedStringArray) -> void:
	var view := ProjectileView.new()
	var rec := {
		"pos": Vector2(8, 8),
		"faction": Types.Faction.PLAYER,
	}
	view.apply_record(rec)
	var after_first := view._redraws
	if after_first < 1:
		fails.append("first projectile apply should queue a redraw")
	var moved := rec.duplicate()
	moved["pos"] = Vector2(16, 8)
	view.apply_record(moved)
	if view._redraws != after_first:
		fails.append("projectile pos change queued a redraw")
	if view.position != Vector2(16, 8):
		fails.append("projectile pos did not update without a redraw")
	var flipped := moved.duplicate()
	flipped["faction"] = Types.Faction.ENEMY
	view.apply_record(flipped)
	if view._redraws != after_first + 1:
		fails.append("projectile faction change did not queue a redraw")
	view.free()
