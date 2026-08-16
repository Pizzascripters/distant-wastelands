extends Node

## Scene router. Holds the active session for the current run.
## Menu and game scenes are added in later PRs.

var current_session = null


func _ready() -> void:
	DisplayServer.window_set_title("Colony")


func go_to_menu() -> void:
	pass


func go_to_game() -> void:
	pass


func quit_app() -> void:
	get_tree().quit()
