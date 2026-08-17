class_name PauseMenu
extends Control

signal resume_pressed
signal quit_to_menu_pressed


func _ready() -> void:
	if theme == null:
		theme = preload("res://assets/theme/default.tres")
	$Center/VBox/Resume.pressed.connect(_on_resume)
	$Center/VBox/QuitToMenu.pressed.connect(_on_quit_to_menu)


func _on_resume() -> void:
	resume_pressed.emit()


func _on_quit_to_menu() -> void:
	quit_to_menu_pressed.emit()
