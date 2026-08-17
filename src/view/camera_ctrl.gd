class_name CameraCtrl
extends Camera2D

const LERP_K := 8.0
const ZOOM_MIN := 0.75
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

var _zoom_scalar := 1.0


func _ready() -> void:
	enabled = true
	make_current()
	zoom = Vector2(_zoom_scalar, _zoom_scalar)
	_clamp_to_world()


func snap_to(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_to_world()


func follow(target: Vector2, delta: float) -> void:
	var t := 1.0 - exp(-LERP_K * delta)
	position = position.lerp(target, t)
	_clamp_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_set_zoom_scalar(_zoom_scalar + ZOOM_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_out"):
		_set_zoom_scalar(_zoom_scalar - ZOOM_STEP)
		get_viewport().set_input_as_handled()


func _set_zoom_scalar(z: float) -> void:
	_zoom_scalar = clampf(snappedf(z, ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(_zoom_scalar, _zoom_scalar)
	_clamp_to_world()


func _world_px() -> float:
	return float(Constants.MAP_W * Constants.TILE)


func _clamp_to_world() -> void:
	var world_px := _world_px()
	var half := get_viewport_rect().size / (2.0 * _zoom_scalar)
	if half.x * 2.0 >= world_px:
		position.x = world_px * 0.5
	else:
		position.x = clampf(position.x, half.x, world_px - half.x)
	if half.y * 2.0 >= world_px:
		position.y = world_px * 0.5
	else:
		position.y = clampf(position.y, half.y, world_px - half.y)
