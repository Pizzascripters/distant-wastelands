class_name Inventory
extends RefCounted

var scrap: int = 0
var ice: int = 0
var ore: int = 0
var parts: int = 0
var food: int = 0
var cap_scrap: int = 0
var cap_ice: int = 0
var cap_ore: int = 0
var cap_parts: int = 0
var cap_food: int = 0


func _init(
	p_cap_scrap: int = 0,
	p_cap_ice: int = 0,
	p_cap_ore: int = 0,
	p_cap_parts: int = 0,
	p_cap_food: int = 0
) -> void:
	cap_scrap = maxi(p_cap_scrap, 0)
	cap_ice = maxi(p_cap_ice, 0)
	cap_ore = maxi(p_cap_ore, 0)
	cap_parts = maxi(p_cap_parts, 0)
	cap_food = maxi(p_cap_food, 0)


func free_space(kind: int) -> int:
	return maxi(_cap(kind) - _amount(kind), 0)


func can_add(kind: int, n: int) -> bool:
	return n >= 0 and n <= free_space(kind)


func add(kind: int, n: int) -> int:
	if n <= 0:
		return 0
	var space := free_space(kind)
	var taken := mini(n, space)
	_set_amount(kind, _amount(kind) + taken)
	return n - taken


func remove(kind: int, n: int) -> int:
	if n <= 0:
		return 0
	var have := _amount(kind)
	var taken := mini(n, have)
	_set_amount(kind, have - taken)
	return taken


func _amount(kind: int) -> int:
	match kind:
		Types.ResourceKind.SCRAP:
			return scrap
		Types.ResourceKind.ICE:
			return ice
		Types.ResourceKind.ORE:
			return ore
		Types.ResourceKind.PARTS:
			return parts
		Types.ResourceKind.FOOD:
			return food
		_:
			return 0


func _cap(kind: int) -> int:
	match kind:
		Types.ResourceKind.SCRAP:
			return cap_scrap
		Types.ResourceKind.ICE:
			return cap_ice
		Types.ResourceKind.ORE:
			return cap_ore
		Types.ResourceKind.PARTS:
			return cap_parts
		Types.ResourceKind.FOOD:
			return cap_food
		_:
			return 0


func _set_amount(kind: int, value: int) -> void:
	match kind:
		Types.ResourceKind.SCRAP:
			scrap = value
		Types.ResourceKind.ICE:
			ice = value
		Types.ResourceKind.ORE:
			ore = value
		Types.ResourceKind.PARTS:
			parts = value
		Types.ResourceKind.FOOD:
			food = value
