extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_apply_deposits_drops_removed(fails)
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


func _test_placeholder_pngs_load(fails: PackedStringArray) -> void:
	if WorldView.load_png("res://assets/sprites/placeholder/scrap.png") == null:
		fails.append("placeholder scrap.png failed to load")
	if WorldView.load_png("res://assets/sprites/placeholder/ice.png") == null:
		fails.append("placeholder ice.png failed to load")
	if WorldView.load_png("res://assets/sprites/placeholder/player.png") == null:
		fails.append("placeholder player.png failed to load")
