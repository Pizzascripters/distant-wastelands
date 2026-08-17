extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_apply_deposits_drops_removed(fails)
	_test_placeholder_pngs_load(fails)
	_test_rebuild_caches_terrain(fails)
	_test_chunk_mutation_isolated(fails)
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
	for path in [
		"res://assets/sprites/placeholder/scrap.png",
		"res://assets/sprites/placeholder/ice.png",
		"res://assets/sprites/placeholder/ore.png",
		"res://assets/sprites/placeholder/parts.png",
		"res://assets/sprites/placeholder/food.png",
		"res://assets/sprites/placeholder/player.png",
		"res://assets/sprites/placeholder/workshop_player.png",
		"res://assets/sprites/placeholder/lab_player.png",
		"res://assets/sprites/placeholder/farm_player.png",
		"res://assets/sprites/placeholder/medbay_player.png",
		"res://assets/sprites/placeholder/gate_player.png",
		"res://assets/sprites/placeholder/radar_player.png",
		"res://assets/sprites/tiles/cliff.png",
		"res://assets/sprites/tiles/crater.png",
	]:
		var tex := WorldView.load_png(path)
		if tex == null:
			fails.append("placeholder %s failed to load" % path.get_file())
			continue
		if tex.get_width() < 8 or tex.get_height() < 8:
			fails.append(
				"placeholder %s is %dx%d, expected a readable icon"
				% [path.get_file(), tex.get_width(), tex.get_height()]
			)
	_expect_tile_png(fails, "res://assets/sprites/tiles/cliff.png", 32, 32)
	_expect_tile_png(fails, "res://assets/sprites/tiles/crater.png", 32, 32)
	_expect_tile_png(fails, "res://assets/sprites/placeholder/radar_player.png", 64, 64)


func _expect_tile_png(fails: PackedStringArray, path: String, w: int, h: int) -> void:
	var tex := WorldView.load_png(path)
	if tex == null:
		return
	if tex.get_width() != w or tex.get_height() != h:
		fails.append(
			"%s is %dx%d, expected %dx%d"
			% [path.get_file(), tex.get_width(), tex.get_height(), w, h]
		)


func _blank_snap() -> SimSnapshot:
	var snap := SimSnapshot.new()
	snap.tiles.resize(Constants.MAP_W * Constants.MAP_H)
	snap.tiles.fill(Types.TileTerrain.EMPTY)
	var n := int(Constants.MAP_W / Constants.TERRAIN_CHUNK_TILES)
	snap.chunk_generation.resize(n * n)
	snap.chunk_generation.fill(0)
	snap.tiles_generation = 0
	return snap


func _test_rebuild_caches_terrain(fails: PackedStringArray) -> void:
	var view := WorldView.new()
	var snap := _blank_snap()
	snap.tiles[0] = Types.TileTerrain.ROCK
	snap.chunk_generation[0] = 1
	snap.tiles_generation = 1
	view.rebuild(snap)
	if view.get("_terrain_tex") != null:
		fails.append("chunked WorldView must not keep a full-map terrain texture")
	if view._chunk_tex.is_empty() or view._chunk_tex[0] == null:
		fails.append("rebuild did not create a terrain chunk texture")
	else:
		var want := Constants.TERRAIN_CHUNK_TILES * Constants.TILE
		var tex: ImageTexture = view._chunk_tex[0]
		if tex.get_width() != want or tex.get_height() != want:
			fails.append(
				"terrain chunk is %dx%d, expected %dx%d"
				% [tex.get_width(), tex.get_height(), want, want]
			)
		if tex.get_width() == Constants.MAP_W * Constants.TILE:
			fails.append("terrain cache is a full 8192 blit")
	view.free()


func _test_chunk_mutation_isolated(fails: PackedStringArray) -> void:
	var view := WorldView.new()
	var snap := _blank_snap()
	var other := Constants.TERRAIN_CHUNK_TILES
	snap.tiles[0] = Types.TileTerrain.ROCK
	snap.tiles[other] = Types.TileTerrain.ROCK
	snap.chunk_generation[0] = 1
	snap.chunk_generation[1] = 1
	snap.tiles_generation = 2
	view.rebuild(snap)
	if view._chunk_tex.size() < 2 or view._chunk_tex[0] == null or view._chunk_tex[1] == null:
		fails.append("rebuild did not cache both dirty chunks")
		view.free()
		return
	var rebuilds_a: int = view._chunk_rebuilds[0]
	var rebuilds_b: int = view._chunk_rebuilds[1]
	snap.tiles[0] = Types.TileTerrain.EMPTY
	snap.chunk_generation[0] = 2
	snap.tiles_generation = 3
	view.apply_tiles(snap)
	if view._chunk_rebuilds[0] != rebuilds_a + 1:
		fails.append(
			"mutating chunk A rebuilds=%d, expected %d"
			% [view._chunk_rebuilds[0], rebuilds_a + 1]
		)
	if view._chunk_rebuilds[1] != rebuilds_b:
		fails.append("mutating chunk A rebuilt chunk B")
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
