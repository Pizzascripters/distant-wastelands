extends Control


func _ready() -> void:
	$Center/VBox/NewGame.pressed.connect(_on_new_game)
	$Center/VBox/Quit.pressed.connect(_on_quit)


func _on_new_game() -> void:
	App.go_to_game()


func _on_quit() -> void:
	App.quit_app()
