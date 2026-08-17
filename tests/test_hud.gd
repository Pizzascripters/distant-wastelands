extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	var hud := Hud.new()
	hud.apply_snapshot(SimSnapshot.new())

	var labels := _all_label_text(hud)
	if labels.find("Habitat HP") >= 0 or labels.find("Depot HP") >= 0:
		fails.append("HUD must not show Habitat/Depot HP: %s" % labels)
	if labels.find("Carry scrap") >= 0 or labels.find("Depot ice") >= 0:
		fails.append("HUD must not use name-first resource strings: %s" % labels)
	if labels.find("60 / 60") < 0:
		fails.append("placeholder O2 60 / 60 missing in: %s" % labels)
	if labels.find("HP") < 0:
		fails.append("HP label missing in: %s" % labels)
	if labels.find("50 / 50") < 0:
		fails.append("placeholder HP 50 / 50 missing in: %s" % labels)
	var o2_row := hud.find_child("O2", true, false)
	var hp_row := hud.find_child("HP", true, false)
	if o2_row == null or hp_row == null or hp_row.get_index() <= o2_row.get_index():
		fails.append("HP row should sit under the O2 row")

	var carry := _counts(hud, "Carry")
	var depot := _counts(hud, "Depot")
	for key in ["Scrap", "Ice", "Ore", "Parts", "Food"]:
		if not carry.has(key):
			fails.append("carry missing %s count" % key)
		if not depot.has(key):
			fails.append("depot missing %s count" % key)
	if carry.get("Scrap", "") != "0" or depot.get("Scrap", "") != "—":
		fails.append("empty snap carry/depot were %s / %s" % [str(carry), str(depot)])

	var snap := SimSnapshot.new()
	snap.units = [{
		"kind": Types.UnitKind.PLAYER,
		"hp": 50,
		"hp_max": 50,
		"alive": true,
		"inventory": {"scrap": 3, "ice": 1, "ore": 2, "parts": 4},
	}]
	snap.buildings = [{
		"kind": Types.BuildingKind.DEPOT,
		"faction": Types.Faction.PLAYER,
		"hp": 80,
		"inventory": {"scrap": 15, "ice": 4, "ore": 0, "parts": 1},
	}]
	snap.player_zero_ice_timer = 0.0
	snap.banner_timer = 1.5
	hud.apply_snapshot(snap)

	labels = _all_label_text(hud)
	if labels.find("Habitat HP") >= 0 or labels.find("Depot HP") >= 0 or labels.find("80") >= 0:
		fails.append("building HP leaked onto HUD: %s" % labels)
	carry = _counts(hud, "Carry")
	depot = _counts(hud, "Depot")
	if carry.get("Ore", "") != "2" or carry.get("Parts", "") != "4":
		fails.append("carry ore/parts were %s" % str(carry))
	if depot.get("Ice", "") != "4" or depot.get("Parts", "") != "1":
		fails.append("depot ice/parts were %s" % str(depot))
	var ice_lab := _count_label(hud, "Depot", "Ice")
	if ice_lab == null or ice_lab.get_theme_color("font_color") != Color("E24A3B"):
		fails.append("depot ice <= 5 should use low-ice color")
	var banner := hud.find_child("RaidBanner", true, false) as Label
	if banner == null or not banner.visible or banner.text != "Raid incoming":
		fails.append("raid banner should show while banner_timer > 0")
	var countdown := hud.find_child("IceCountdown", true, false) as Label
	if countdown != null and countdown.visible:
		fails.append("countdown should stay hidden while depot ice > 0")

	snap.buildings[0]["inventory"]["ice"] = 0
	snap.player_zero_ice_timer = 12.0
	hud.apply_snapshot(snap)
	countdown = hud.find_child("IceCountdown", true, false) as Label
	if countdown == null or not countdown.visible:
		fails.append("zero-ice countdown should show")
	elif countdown.text != "18":
		fails.append("countdown is %s, expected 18" % countdown.text)

	_assert_hp(hud, fails, 50, 50, Color("E07A5F"), 1.0)
	snap.units[0]["hp"] = 25
	hud.apply_snapshot(snap)
	_assert_hp(hud, fails, 25, 50, Color("E2C044"), 0.5)
	snap.units[0]["hp"] = 10
	hud.apply_snapshot(snap)
	_assert_hp(hud, fails, 10, 50, Color("E24A3B"), 0.2)
	snap.units[0]["hp"] = 0
	hud.apply_snapshot(snap)
	_assert_hp(hud, fails, 0, 50, Color("E24A3B"), 0.0)
	snap.units[0]["hp"] = 30
	snap.units[0]["alive"] = false
	hud.apply_snapshot(snap)
	_assert_hp(hud, fails, 0, 50, Color("E24A3B"), 0.0)

	var bar := BuildBar.new()
	bar.selected_kind = Types.BuildingKind.WALL
	var bar_text := _all_label_text(bar)
	if bar_text.find("Wall") >= 0 or bar_text.find("Turret") >= 0:
		fails.append("build bar must use sprites, not Wall/Turret words: %s" % bar_text)
	if bar_text.find(str(Constants.WALL_COST)) < 0 or bar_text.find(str(Constants.TURRET_COST)) < 0:
		fails.append("build bar should show wall/turret scrap costs: %s" % bar_text)
	var textures := bar.find_children("*", "TextureRect", true, false)
	if textures.size() < 4:
		fails.append("build bar should show building + scrap icons, got %d" % textures.size())
	bar.free()

	hud.free()
	return fails


func _assert_hp(
	hud: Hud,
	fails: PackedStringArray,
	hp: int,
	hp_max: int,
	fill_color: Color,
	ratio: float
) -> void:
	var fill := hud.find_child("HPFill", true, false) as ColorRect
	var value := hud.find_child("HPValue", true, false) as Label
	var expected := "%d / %d" % [hp, hp_max]
	if value == null or value.text != expected:
		fails.append("HP text is %s, expected %s" % [value.text if value != null else "missing", expected])
	if fill == null:
		fails.append("HP fill missing")
		return
	if fill.color != fill_color:
		fails.append("HP fill color is %s, expected %s at %s" % [str(fill.color), str(fill_color), expected])
	if not is_equal_approx(fill.anchor_right, ratio):
		fails.append("HP fill ratio is %s, expected %s" % [str(fill.anchor_right), str(ratio)])


func _count_label(hud: Hud, group: String, kind: String) -> Label:
	var row := hud.find_child(group, true, false)
	if row == null:
		return null
	return row.find_child("%sCount" % kind, true, false) as Label


func _counts(hud: Hud, group: String) -> Dictionary:
	var row := hud.find_child(group, true, false)
	if row == null:
		return {}
	var out := {}
	for kind in ["Scrap", "Ice", "Ore", "Parts", "Food"]:
		var lab := row.find_child("%sCount" % kind, true, false) as Label
		if lab != null:
			out[kind] = lab.text
	return out


func _all_label_text(root: Node) -> String:
	var parts := PackedStringArray()
	for node in root.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return " | ".join(parts)
