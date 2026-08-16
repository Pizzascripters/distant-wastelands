extends SceneTree

## Headless runner. Each listed script exposes `run() -> PackedStringArray`
## of failure messages. Empty list is valid (scaffold has zero cases).

const TEST_SCRIPTS: Array[String] = []


func _initialize() -> void:
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
