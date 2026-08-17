extends Node

## Scene router. Holds the active session for the current run.

var current_session: Session = null


func _ready() -> void:
	var win := get_window()
	if win != null:
		win.title = "Colony"
	DisplayServer.window_set_title("Colony")
	if OS.get_environment("COLONY_TEST_XVFB") == "1":
		return
	call_deferred("_boot_if_needed")


func _boot_if_needed() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == "res://scenes/boot.tscn":
		go_to_menu()


func go_to_menu() -> void:
	current_session = null
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func go_to_game() -> void:
	_start_game(Constants.DEFAULT_SEED)


func play_again() -> void:
	_start_game(_session_seed())


func _session_seed() -> int:
	if current_session is LocalSession:
		var local := current_session as LocalSession
		if local.sim != null and local.sim.world != null:
			return local.sim.world.seed
	return Constants.DEFAULT_SEED


func _start_game(p_seed: int) -> void:
	var session := LocalSession.new()
	session.start(p_seed)
	current_session = session
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func quit_app() -> void:
	get_tree().quit()
