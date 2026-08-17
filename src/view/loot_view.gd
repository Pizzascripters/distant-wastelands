class_name LootView
extends Node2D

const FILL := Color("E2C044")
const SIZE := 10.0
const SPRITE_PATH := "res://assets/sprites/placeholder/loot.png"

var _tex: Texture2D
var _tex_tried: bool = false


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	queue_redraw()


func _draw() -> void:
	var tex := _texture()
	if tex != null:
		var sz := Vector2(tex.get_width(), tex.get_height())
		draw_texture(tex, -sz * 0.5)
		return
	var half := SIZE * 0.5
	draw_rect(Rect2(-half, -half, SIZE, SIZE), FILL)


func _texture() -> Texture2D:
	if not _tex_tried:
		_tex_tried = true
		_tex = WorldView.load_png(SPRITE_PATH)
	return _tex
