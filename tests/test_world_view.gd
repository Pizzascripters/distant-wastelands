extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_apply_deposits_drops_removed(fails)
	_test_terrain_cache_and_dirty_overlay(fails)
	_test_placeholder_pngs_load(fails)
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


func _test_terrain_cache_and_dirty_overlay(fails: PackedStringArray) -> void:
	var view := WorldView.new()
	var snap := SimSnapshot.new()
	snap.tiles.resize(Constants.MAP_W * Constants.MAP_H)
	snap.tiles.fill(Types.TileTerrain.EMPTY)
	snap.tiles[0] = Types.TileTerrain.ROCK
	snap.deposits = [{
		"id": 3,
		"kind": Types.ResourceKind.SCRAP,
		"pos": Vector2(16, 16),
		"tile": Vector2i(0, 0),
		"remaining": 8,
	}]
	view.rebuild(snap)
	if view._terrain_tex == null:
		fails.append("rebuild did not create a terrain cache")
	var cache := view._terrain_tex
	var rev := view._overlay_rev
	view.apply_deposits(snap)
	if view._overlay_rev != rev:
		fails.append("unchanged deposits triggered an overlay redraw")
	if view._terrain_tex != cache:
		fails.append("apply_deposits replaced the terrain cache")
	snap.deposits = [{
		"id": 3,
		"kind": Types.ResourceKind.SCRAP,
		"pos": Vector2(16, 16),
		"tile": Vector2i(0, 0),
		"remaining": 7,
	}]
	view.apply_deposits(snap)
	if view._overlay_rev == rev:
		fails.append("remaining change did not dirty the deposit overlay")
	if view._terrain_tex != cache:
		fails.append("remaining change rebuilt terrain")
	var empty := SimSnapshot.new()
	view.apply_deposits(empty)
	if not view._deposits.is_empty():
		fails.append("dirty overlay kept %d deposits after removal" % view._deposits.size())
	if view._terrain_tex != cache:
		fails.append("removing deposits rebuilt terrain")
	view.free()


func _test_placeholder_pngs_load(fails: PackedStringArray) -> void:
	if WorldView.load_png("res://assets/sprites/placeholder/scrap.png") == null:
		fails.append("placeholder scrap.png failed to load")
	if WorldView.load_png("res://assets/sprites/placeholder/ice.png") == null:
		fails.append("placeholder ice.png failed to load")
	if WorldView.load_png("res://assets/sprites/placeholder/player.png") == null:
		fails.append("placeholder player.png failed to load")
