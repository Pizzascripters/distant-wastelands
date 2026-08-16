class_name Sim
extends RefCounted

var tick_index: int = 0
var time: float = 0.0
var outcome: int = Types.Outcome.NONE
var outcome_reason: int = Types.OutcomeReason.NONE
var world: World
var player_id: int = 0

var _queue: Array[InputCommand] = []


func setup(p_seed: int) -> void:
	world = Mapgen.generate(p_seed)
	tick_index = 0
	time = 0.0
	outcome = Types.Outcome.NONE
	outcome_reason = Types.OutcomeReason.NONE
	_queue.clear()
	player_id = 0
	for unit in world.units.values():
		if unit.kind == Types.UnitKind.PLAYER:
			player_id = unit.id
			break


func enqueue(cmd: InputCommand) -> void:
	_queue.append(cmd)


func tick() -> void:
	if outcome != Types.Outcome.NONE:
		return

	# Tick order is the design contract (Sim.tick steps 1–13).
	tick_index += 1
	time = float(tick_index) * Constants.SIM_DT

	for unit in world.units.values():
		unit.weapon_cooldown = maxf(0.0, unit.weapon_cooldown - Constants.SIM_DT)
		unit.path_recalc_in = maxf(0.0, unit.path_recalc_in - Constants.SIM_DT)
		if not unit.alive and unit.kind == Types.UnitKind.PLAYER:
			unit.respawn_timer = maxf(0.0, unit.respawn_timer - Constants.SIM_DT)

	var cmd: InputCommand = null
	if not _queue.is_empty():
		cmd = _queue[0]
	_queue.clear()
	_apply_player_command(cmd)

	for unit in world.units.values():
		if unit.alive:
			_integrate_unit(unit)


func snapshot() -> SimSnapshot:
	var snap := SimSnapshot.new()
	snap.tick = tick_index
	snap.time = time
	snap.outcome = outcome
	snap.outcome_reason = outcome_reason
	snap.tiles = world.tiles.duplicate()
	for unit in world.units.values():
		snap.units.append(_unit_record(unit))
	for building in world.buildings.values():
		snap.buildings.append(_building_record(building))
	for deposit in world.deposits.values():
		snap.deposits.append(_deposit_record(deposit))
	for pile in world.loot.values():
		snap.loot.append(_loot_record(pile))
	for proj in world.projectiles.values():
		snap.projectiles.append(_projectile_record(proj))
	_copy_director(snap)
	var player := get_player()
	if player != null:
		snap.player_respawn_timer = player.respawn_timer
	snap.player_zero_ice_timer = _faction_zero_ice(Types.Faction.PLAYER)
	snap.enemy_zero_ice_timer = _faction_zero_ice(Types.Faction.ENEMY)
	snap.player_living_depot_ice_empty = _living_depot_ice_empty(Types.Faction.PLAYER)
	snap.enemy_living_depot_ice_empty = _living_depot_ice_empty(Types.Faction.ENEMY)
	return snap


func get_player() -> Unit:
	if world == null:
		return null
	return world.units.get(player_id) as Unit


func _unit_record(unit: Unit) -> Dictionary:
	return {
		"id": unit.id,
		"kind": unit.kind,
		"faction": unit.faction,
		"pos": unit.pos,
		"hp": unit.hp,
		"hp_max": unit.hp_max,
		"aim": unit.aim,
		"alive": unit.alive,
		"radius": unit.radius,
		"inventory": _inventory_record(unit.inventory),
	}


func _building_record(building: Building) -> Dictionary:
	return {
		"id": building.id,
		"kind": building.kind,
		"faction": building.faction,
		"origin_tile": building.origin_tile,
		"pos": world.footprint_aabb(building).position,
		"hp": building.hp,
		"hp_max": building.hp_max,
		"aim": building.aim,
		"inventory": _inventory_record(building.inventory),
	}


func _deposit_record(deposit: Deposit) -> Dictionary:
	return {
		"id": deposit.id,
		"kind": deposit.kind,
		"pos": world.tile_center(deposit.tile.x, deposit.tile.y),
		"tile": deposit.tile,
		"remaining": deposit.remaining,
	}


func _loot_record(pile: Loot) -> Dictionary:
	return {
		"id": pile.id,
		"pos": pile.pos,
		"inventory": _inventory_record(pile.inventory),
	}


func _projectile_record(proj: Projectile) -> Dictionary:
	return {
		"id": proj.id,
		"faction": proj.faction,
		"pos": proj.pos,
	}


func _inventory_record(inv: Inventory) -> Dictionary:
	if inv == null:
		return {"scrap": 0, "ice": 0, "cap_scrap": 0, "cap_ice": 0}
	return {
		"scrap": inv.scrap,
		"ice": inv.ice,
		"cap_scrap": inv.cap_scrap,
		"cap_ice": inv.cap_ice,
	}


func _copy_director(snap: SimSnapshot) -> void:
	if not "director" in self:
		return
	var director: Variant = get("director")
	if director == null:
		return
	if "next_wave_at" in director:
		snap.next_wave_at = float(director.next_wave_at)
	if "wave_index" in director:
		snap.wave_index = int(director.wave_index)
	if "banner_timer" in director:
		snap.banner_timer = float(director.banner_timer)


func _faction_zero_ice(faction: int) -> float:
	var lives: Variant = get("life")
	if lives is Dictionary:
		var rec: Variant = lives.get(faction)
		if rec is Object and "zero_ice_timer" in rec:
			return float(rec.zero_ice_timer)
	return 0.0


func _living_depot_ice_empty(faction: int) -> bool:
	for building in world.buildings.values():
		if building.kind != Types.BuildingKind.DEPOT:
			continue
		if building.faction != faction:
			continue
		if building.hp <= 0:
			continue
		var inv: Inventory = building.inventory
		return inv != null and inv.ice == 0
	return false


func _apply_player_command(cmd: InputCommand) -> void:
	var player := get_player()
	var ignore := player == null or not player.alive or outcome != Types.Outcome.NONE
	if ignore:
		if player != null:
			player.vel = Vector2.ZERO
		return
	if cmd == null:
		player.vel = Vector2.ZERO
		return
	if cmd.aim.length_squared() > 0.0:
		player.aim = cmd.aim
	player.vel = cmd.move * Constants.PLAYER_SPEED
	if cmd.build_kind >= 0:
		Rules.try_place(world, cmd.build_kind, cmd.build_tile)


func _integrate_unit(unit: Unit) -> void:
	var delta := unit.vel * Constants.SIM_DT
	var pos := unit.pos
	pos.x += delta.x
	pos = _resolve_circle_tiles(pos, unit.radius)
	pos.y += delta.y
	pos = _resolve_circle_tiles(pos, unit.radius)
	var r := unit.radius
	var limit := float(Constants.MAP_W * Constants.TILE)
	pos.x = clampf(pos.x, r, limit - r)
	pos.y = clampf(pos.y, r, limit - r)
	unit.pos = pos


func _resolve_circle_tiles(pos: Vector2, radius: float) -> Vector2:
	var tile := float(Constants.TILE)
	var min_tx := int(floor((pos.x - radius) / tile))
	var max_tx := int(floor((pos.x + radius) / tile))
	var min_ty := int(floor((pos.y - radius) / tile))
	var max_ty := int(floor((pos.y + radius) / tile))
	for _pass in 2:
		for y in range(min_ty, max_ty + 1):
			for x in range(min_tx, max_tx + 1):
				if world.is_walkable(x, y):
					continue
				pos = _push_circle_out_of_aabb(pos, radius, world.tile_aabb(x, y))
	return pos


func _push_circle_out_of_aabb(center: Vector2, radius: float, aabb: Rect2) -> Vector2:
	var closest := Vector2(
		clampf(center.x, aabb.position.x, aabb.end.x),
		clampf(center.y, aabb.position.y, aabb.end.y)
	)
	var delta := center - closest
	var dist_sq := delta.length_squared()
	if dist_sq >= radius * radius:
		return center
	if dist_sq <= 0.0001:
		var left := center.x - aabb.position.x
		var right := aabb.end.x - center.x
		var top := center.y - aabb.position.y
		var bottom := aabb.end.y - center.y
		var min_pen := minf(minf(left, right), minf(top, bottom))
		if is_equal_approx(min_pen, left):
			return Vector2(aabb.position.x - radius, center.y)
		if is_equal_approx(min_pen, right):
			return Vector2(aabb.end.x + radius, center.y)
		if is_equal_approx(min_pen, top):
			return Vector2(center.x, aabb.position.y - radius)
		return Vector2(center.x, aabb.end.y + radius)
	var dist := sqrt(dist_sq)
	return closest + (delta / dist) * radius
