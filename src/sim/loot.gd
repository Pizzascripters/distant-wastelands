class_name Loot
extends RefCounted

var id: int = 0
var pos: Vector2 = Vector2.ZERO
var inventory: Inventory


func _init() -> void:
	inventory = Inventory.new(999, 999, 999, 999, 999)
