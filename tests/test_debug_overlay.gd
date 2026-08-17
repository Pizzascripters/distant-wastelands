extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	var overlay := DebugOverlay.new()
	if overlay.visible:
		fails.append("overlay should be hidden by default")

	var snap := SimSnapshot.new()
	snap.tick = 7
	snap.outcome = Types.Outcome.PLAYER_WIN
	var units: Array[Dictionary] = []
	units.append({
		"id": 1,
		"kind": Types.UnitKind.PLAYER,
	})
	snap.units = units
	overlay.apply_snapshot(snap)
	if overlay.visible:
		fails.append("apply_snapshot must not show the overlay")

	var text := _label_text(overlay)
	_expect_contains(fails, text, "tick  7", "tick")
	_expect_contains(fails, text, "fps  ", "fps")
	_expect_contains(fails, text, "sim_ms  ", "sim_ms")
	_expect_contains(fails, text, "view_ms  ", "view_ms")
	_expect_contains(fails, text, "units  1", "units")
	_expect_contains(fails, text, "buildings  0", "buildings")
	_expect_contains(fails, text, "deposits  0", "deposits")
	_expect_contains(fails, text, "loot  0", "loot")
	_expect_contains(fails, text, "projectiles  0", "projectiles")
	_expect_contains(fails, text, "outcome  PLAYER_WIN", "outcome")
	_expect_contains(fails, text, "player depot  —", "player depot")
	_expect_contains(fails, text, "enemy depot  —", "enemy depot")
	_expect_contains(fails, text, "next wave  0", "next wave")
	_expect_color(fails, overlay, "sim_ms", DebugOverlay.TEXT)
	_expect_color(fails, overlay, "view_ms", DebugOverlay.TEXT)

	snap.sim_ms = Constants.TICK_BUDGET_MSEC
	snap.view_ms = Constants.VIEW_BUDGET_MSEC
	overlay.apply_snapshot(snap)
	_expect_color(fails, overlay, "sim_ms", DebugOverlay.AMBER)
	_expect_color(fails, overlay, "view_ms", DebugOverlay.AMBER)

	overlay.free()
	return fails


func _label_text(overlay: DebugOverlay) -> String:
	var labels := overlay.find_children("*", "Label", true, false)
	if labels.is_empty():
		return ""
	return (labels[0] as Label).text


func _expect_contains(fails: PackedStringArray, text: String, needle: String, field: String) -> void:
	if text.find(needle) < 0:
		fails.append("%s missing %s in: %s" % [field, needle, text])


func _expect_color(fails: PackedStringArray, overlay: DebugOverlay, prefix: String, want: Color) -> void:
	for node in overlay.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or not label.visible or not label.text.begins_with(prefix):
			continue
		var got: Color = label.get_theme_color("font_color")
		if got != want:
			fails.append("%s color is %s, expected %s" % [prefix, str(got), str(want)])
		return
	fails.append("%s row missing for color check" % prefix)
