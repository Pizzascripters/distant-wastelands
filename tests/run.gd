extends SceneTree

## Test runner. Official entry is ./tools/test.sh (private Xvfb).
## Each listed script exposes `run() -> PackedStringArray` of failure messages.
## Empty list is valid (scaffold has zero cases).

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_inventory.gd",
	"res://tests/test_rules.gd",
	"res://tests/test_mapgen.gd",
	"res://tests/test_pathfind.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_debug_overlay.gd",
	"res://tests/test_snapshot.gd",
	"res://tests/test_ai_raider.gd",
	"res://tests/test_ai_raid.gd",
	"res://tests/test_perf.gd",
	"res://tests/test_world_view.gd",
	"res://tests/test_gather_bar.gd",
	"res://tests/test_hud.gd",
]


func _is_session_x_display(display: String) -> bool:
	var colon := display.rfind(":")
	if colon < 0:
		return false
	var rest := display.substr(colon + 1)
	var screen := rest.split(".")[0]
	return screen == "0"


func _refuse(msg: String) -> void:
	print("FAIL %s" % msg)
	print("Run ./tools/test.sh — do not use godot --headless or the host display.")
	quit(1)


func _initialize() -> void:
	if OS.get_environment("COLONY_TEST_XVFB") != "1":
		_refuse("tests must run via ./tools/test.sh (COLONY_TEST_XVFB is not set)")
		return
	var display := OS.get_environment("DISPLAY")
	if display.is_empty() or _is_session_x_display(display):
		_refuse("refusing session/host X display '%s'" % display)
		return
	if DisplayServer.get_name() == "headless":
		_refuse("refusing Godot headless display driver")
		return

	var failures: PackedStringArray = PackedStringArray()
	for path in TEST_SCRIPTS:
		var script: Script = load(path)
		if script == null:
			failures.append("%s: failed to load" % path)
			print("FAIL %s: failed to load" % path)
			continue
		var instance: Object = script.new()
		if instance == null or not instance.has_method("run"):
			failures.append("%s: missing run()" % path)
			print("FAIL %s: missing run()" % path)
			continue
		var msgs: PackedStringArray = instance.run()
		if instance is Node:
			(instance as Node).free()
		if msgs.is_empty():
			print("PASS %s" % path)
		else:
			for msg in msgs:
				failures.append("%s: %s" % [path, msg])
				print("FAIL %s: %s" % [path, msg])
	print("=== Test summary ===")
	print("scripts: %d" % TEST_SCRIPTS.size())
	print("failures: %d" % failures.size())
	if failures.is_empty():
		print("All tests passed.")
		quit(0)
	else:
		quit(1)
