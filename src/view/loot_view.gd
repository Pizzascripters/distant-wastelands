class_name LootView
extends Node2D

const FILL := Color("E2C044")
const SIZE := 10.0
const SPRITE_PATH := "res://assets/sprites/placeholder/loot.png"

var _tex: Texture2D
var _tex_tried: bool = false


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ensure_texture()


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	_ensure_texture()
	queue_redraw()


func _draw() -> void:
	if _tex != null:
		var sz := Vector2(_tex.get_width(), _tex.get_height())
		draw_texture(_tex, -sz * 0.5)
		return
	var half := SIZE * 0.5
	draw_rect(Rect2(-half, -half, SIZE, SIZE), FILL)


func _ensure_texture() -> void:
	if _tex_tried:
		return
	_tex = WorldView.load_png(SPRITE_PATH)
	_tex_tried = true
