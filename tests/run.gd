extends SceneTree

## Test runner. Official entry is ./tools/test.sh (private Xvfb).
## Discovers res://tests/**/test_*.gd (one extra directory level) and
## no-arg test_* methods. Filters after -- select a subset.


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


func _is_path_filter(token: String) -> bool:
	return token.begins_with("res://") or token.contains("/") or token.ends_with(".gd")


func _strip_test_prefix(name: String) -> String:
	if name.begins_with("test_"):
		return name.substr(5)
	return name


func _file_match(token: String, path: String, stem: String, short: String) -> bool:
	if token.is_empty():
		return true
	if _is_path_filter(token):
		return path == token or path.ends_with(token)
	return stem == token or short == token or short.contains(token)


func _case_match(token: String, case_name: String, case_short: String) -> bool:
	if token.is_empty():
		return true
	return case_name == token or case_short == token or case_short.contains(token)


func _split_file_case(token: String) -> PackedStringArray:
	var sep := ""
	if token.contains(":"):
		sep = ":"
	elif token.contains("."):
		sep = "."
	else:
		return PackedStringArray()
	var parts := token.split(sep, true, 1)
	if parts.size() < 2:
		return PackedStringArray()
	return PackedStringArray([parts[0], parts[1]])


func _filter_matches(token: String, path: String, stem: String, short: String, case_name: String, case_short: String) -> bool:
	if _is_path_filter(token):
		return _file_match(token, path, stem, short)
	var parts := _split_file_case(token)
	if parts.size() == 2:
		return _file_match(parts[0], path, stem, short) and _case_match(parts[1], case_name, case_short)
	return _file_match(token, path, stem, short) or _case_match(token, case_name, case_short)


func _any_filter_matches(filters: PackedStringArray, path: String, case_name: String) -> bool:
	if filters.is_empty():
		return true
	var stem := path.get_file().get_basename()
	var short := _strip_test_prefix(stem)
	var case_short := _strip_test_prefix(case_name)
	for token in filters:
		if _filter_matches(token, path, stem, short, case_name, case_short):
			return true
	return false


func _any_file_filter_matches(filters: PackedStringArray, path: String) -> bool:
	if filters.is_empty():
		return true
	var stem := path.get_file().get_basename()
	var short := _strip_test_prefix(stem)
	for token in filters:
		if _is_path_filter(token):
			if _file_match(token, path, stem, short):
				return true
			continue
		var parts := _split_file_case(token)
		if parts.size() == 2:
			if _file_match(parts[0], path, stem, short):
				return true
			continue
		if _file_match(token, path, stem, short):
			return true
	return false


func _scan_dir(dir_path: String, out: PackedStringArray, depth: int) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name.begins_with("."):
			name = da.get_next()
			continue
		var path := "%s/%s" % [dir_path.rstrip("/"), name]
		if da.current_is_dir():
			if depth < 1:
				_scan_dir(path, out, depth + 1)
		elif name.begins_with("test_") and name.ends_with(".gd"):
			out.append(path)
		name = da.get_next()
	da.list_dir_end()


func _discover_scripts() -> PackedStringArray:
	var out := PackedStringArray()
	_scan_dir("res://tests", out, 0)
	out.sort()
	return out


func _case_names(script: Script) -> PackedStringArray:
	var names := PackedStringArray()
	for method in script.get_script_method_list():
		var n: String = method["name"]
		if n.begins_with("test_"):
			names.append(n)
	names.sort()
	return names


func _case_id(path: String, case_name: String) -> String:
	return "%s.%s" % [path.get_file().get_basename(), case_name]


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var list_only := false
	var filters := PackedStringArray()
	for token in raw:
		if token == "--list":
			list_only = true
			continue
		if token.begins_with("--"):
			return {"error": "unknown flag '%s' (valid flags: --list)" % token}
		if token.is_empty():
			continue
		filters.append(token)
	return {"list_only": list_only, "filters": filters}


func _print_available(scripts: PackedStringArray) -> void:
	print("available:")
	for path in scripts:
		var script: Script = load(path)
		if script == null:
			print("  %s (failed to load)" % path)
			continue
		var names := _case_names(script)
		if names.is_empty():
			print("  %s (no test_* methods)" % path)
			continue
		for case_name in names:
			print("  %s" % _case_id(path, case_name))


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

	var parsed: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if parsed.has("error"):
		print("FAIL %s" % parsed["error"])
		quit(1)
		return

	var list_only: bool = parsed["list_only"]
	var filters: PackedStringArray = parsed["filters"]
	var scripts := _discover_scripts()
	var failures := PackedStringArray()
	var files_run := 0
	var cases_run := 0
	var listed_files := {}
	var selected := 0

	for path in scripts:
		var script: Script = load(path)
		if script == null:
			if not _any_file_filter_matches(filters, path):
				continue
			failures.append("%s: failed to load" % path)
			print("FAIL %s: failed to load" % path)
			files_run += 1
			selected += 1
			continue
		var names := _case_names(script)
		if names.is_empty():
			if not _any_file_filter_matches(filters, path):
				continue
			failures.append("%s: no test_* methods" % path)
			print("FAIL %s: no test_* methods" % path)
			files_run += 1
			selected += 1
			continue
		var matched := PackedStringArray()
		for case_name in names:
			if _any_filter_matches(filters, path, case_name):
				matched.append(case_name)
		if matched.is_empty():
			continue
		selected += matched.size()
		if list_only:
			if not listed_files.has(path):
				print(path)
				listed_files[path] = true
				files_run += 1
			for case_name in matched:
				print("  %s" % case_name)
				cases_run += 1
			continue
		files_run += 1
		for case_name in matched:
			cases_run += 1
			var instance: Object = script.new()
			if instance == null:
				failures.append("%s %s: failed to instantiate" % [path, case_name])
				print("FAIL %s %s: failed to instantiate" % [path, case_name])
				continue
			if not instance.has_method(case_name):
				failures.append("%s %s: missing method" % [path, case_name])
				print("FAIL %s %s: missing method" % [path, case_name])
				if instance is Node:
					(instance as Node).free()
				continue
			var result: Variant = instance.call(case_name)
			if instance is Node:
				(instance as Node).free()
			if typeof(result) != TYPE_PACKED_STRING_ARRAY:
				failures.append("%s %s: did not return PackedStringArray" % [path, case_name])
				print("FAIL %s %s: did not return PackedStringArray" % [path, case_name])
				continue
			var msgs: PackedStringArray = result
			if msgs.is_empty():
				print("PASS %s %s" % [path, case_name])
			else:
				for msg in msgs:
					failures.append("%s %s: %s" % [path, case_name, msg])
					print("FAIL %s %s: %s" % [path, case_name, msg])

	if not filters.is_empty() and selected == 0:
		print("FAIL no cases match filter(s): %s" % ", ".join(filters))
		_print_available(scripts)
		failures.append("no cases match filter(s)")

	print("=== Test summary ===")
	print("files: %d" % files_run)
	print("cases: %d" % cases_run)
	print("failures: %d" % failures.size())
	if list_only:
		quit(0 if failures.is_empty() else 1)
		return
	if failures.is_empty():
		print("All tests passed.")
		quit(0)
	else:
		quit(1)
