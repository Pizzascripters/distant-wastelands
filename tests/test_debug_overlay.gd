extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	var overlay := DebugOverlay.new()
	if overlay.visible:
		fails.append("overlay should be hidden by default")

	var snap := SimSnapshot.new()
	snap.tick = 7
	snap.outcome = Types.Outcome.PLAYER_WIN
	snap.player_o2 = 41.5
	snap.research_selected = Types.TechKind.HYDROPONICS
	snap.research_progress = 2.5
	snap.techs_done = 1
	snap.completed_this_tick = 1
	snap.next_raid_at = 50.0
	snap.wave_index = 3
	snap.active_unit_count = 2
	snap.sleeping_unit_count = 5
	snap.habitat_ice_pool = 20
	snap.depot_scrap_pool = 15
	snap.depot_ore_pool = 3
	snap.depot_parts_pool = 1
	snap.discovered.resize(Constants.MAP_W * Constants.MAP_H)
	snap.discovered.fill(0)
	snap.discovered[0] = 1
	snap.discovered[1] = 1
	var units: Array[Dictionary] = []
	units.append({
		"id": 1,
		"kind": Types.UnitKind.PLAYER,
		"faction": Types.Faction.PLAYER,
		"pos": Vector2(23 * Constants.TILE + 16, 218 * Constants.TILE + 16),
		"inventory": {"food": 24},
	})
	units.append({
		"id": 2,
		"kind": Types.UnitKind.RAIDER,
		"faction": Types.Faction.ENEMY,
		"alive": true,
		"hp": 25,
		"pos": Vector2(10 * Constants.TILE + 16, 200 * Constants.TILE + 16),
	})
	snap.units = units
	snap.buildings = [{
		"kind": Types.BuildingKind.DEPOT,
		"faction": Types.Faction.PLAYER,
		"hp": 80,
		"inventory": {"scrap": 15, "ice": 20, "ore": 3, "parts": 1, "food": 4},
	}, {
		"kind": Types.BuildingKind.HABITAT,
		"faction": Types.Faction.PLAYER,
		"hp": 200,
		"inventory": {"ice": 20},
	}]
	overlay.apply_snapshot(snap)
	if overlay.visible:
		fails.append("apply_snapshot must not show the overlay")

	var text := _label_text(overlay)
	_expect_contains(fails, text, "tick  7", "tick")
	_expect_contains(fails, text, "fps  ", "fps")
	_expect_contains(fails, text, "sim_ms  ", "sim_ms")
	_expect_contains(fails, text, "view_ms  ", "view_ms")
	_expect_contains(fails, text, "units  2", "units")
	_expect_contains(fails, text, "buildings  2", "buildings")
	_expect_contains(fails, text, "deposits  0", "deposits")
	_expect_contains(fails, text, "loot  0", "loot")
	_expect_contains(fails, text, "projectiles  0", "projectiles")
	_expect_contains(fails, text, "outcome  PLAYER_WIN", "outcome")
	_expect_contains(fails, text, "habitat ice pool  20", "habitat ice pool")
	_expect_contains(
		fails, text, "depot pool  scrap 15  ore 3  parts 1", "depot pool"
	)
	if text.find("ice 20") >= 0 and text.find("habitat ice pool  20") < 0:
		fails.append("depot pool must not list Ice")
	if text.find("parts 1  food") >= 0:
		fails.append("depot pool must not list Food")
	_expect_contains(fails, text, "enemy depot  —", "enemy depot")
	_expect_contains(fails, text, "carry food  24", "carry food")
	_expect_contains(fails, text, "o2  41.50", "o2")
	_expect_contains(fails, text, "research  HYDROPONICS  2.50  done 1", "research")
	_expect_contains(fails, text, "next raid  50.00  wave 3", "next raid")
	if text.find("next wave") >= 0:
		fails.append("F3 must label next raid, not next wave")
	_expect_contains(fails, text, "active  2  sleep 5", "active/sleep")
	_expect_contains(fails, text, "discovered  2 / 65536", "discovered")
	_expect_contains(fails, text, "player tile  23, 218", "player tile")
	_expect_contains(fails, text, "density  1", "density")
	_expect_contains(fails, text, "completed_this_tick  1", "completed_this_tick")
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
