class_name Sim
extends RefCounted

class FactionLife extends RefCounted:
	var ice_debt_timer: float = 0.0
	var zero_ice_timer: float = 0.0

var tick_index: int = 0
var time: float = 0.0
var outcome: int = Types.Outcome.NONE
var outcome_reason: int = Types.OutcomeReason.NONE
var world: World
var player_id: int = 0
var director: Director
var path_queue: PathQueue = PathQueue.new()
var life: Dictionary = {}
var last_tick_usec: int = 0
var research_selected: int = -1
var research_progress: float = 0.0
var research_paid: bool = false
var techs_done: int = 0
var medbay_heal_acc: float = 0.0
var _interact_target_id: int = 0
var _interact_withdraw: bool = false

var _queue: Array[InputCommand] = []
var _snap_tiles: PackedByteArray = PackedByteArray()
var _snap_tiles_generation: int = -1


func setup(p_seed: int) -> void:
	world = Mapgen.generate(p_seed)
	tick_index = 0
	time = 0.0
	outcome = Types.Outcome.NONE
	outcome_reason = Types.OutcomeReason.NONE
	research_selected = -1
	research_progress = 0.0
	research_paid = false
	techs_done = 0
	medbay_heal_acc = 0.0
	_queue.clear()
	player_id = 0
	last_tick_usec = 0
	_interact_target_id = 0
	_interact_withdraw = false
	_snap_tiles = PackedByteArray()
	_snap_tiles_generation = -1
	director = Director.new()
	path_queue = PathQueue.new()
	life = {
		Types.Faction.PLAYER: FactionLife.new(),
		Types.Faction.ENEMY: FactionLife.new(),
	}
	for unit in world.units.values():
		if unit.kind == Types.UnitKind.PLAYER:
			player_id = unit.id
			unit.o2 = Constants.PLAYER_O2_MAX
			break


func enqueue(cmd: InputCommand) -> void:
	_queue.append(cmd)


func tick() -> void:
	var started := Time.get_ticks_usec()
	if outcome != Types.Outcome.NONE:
		last_tick_usec = Time.get_ticks_usec() - started
		return

	# Tick order is the design contract (Sim.tick steps 1–13).
	tick_index += 1
	time = float(tick_index) * Constants.SIM_DT

	_decrement_cooldowns()
	Rules.tick_life_support(self)

	var cmd: InputCommand = null
	if not _queue.is_empty():
		cmd = _queue[0]
	_queue.clear()
	_apply_player_command(cmd)

	if director != null:
		director.maybe_spawn(self)
	_think_ai()
	if path_queue != null:
		path_queue.service(world)
	_fire_ranged()

	for unit in world.units.values():
		if unit.alive:
			_integrate_unit(unit)
			_update_stuck(unit)
	_tick_player_oxygen()
	_tick_medbay_heal()

	_integrate_projectiles()
	_resolve_melee()
	_interact_target_id = Rules.resolve_interact(
		world, get_player(), cmd, _interact_target_id, _interact_withdraw, self
	)
	_interact_withdraw = _own_depot_withdrawing(cmd, _interact_target_id)
	_process_deaths_and_respawn()
	var result := Rules.evaluate_outcome(self)
	if result.x != Types.Outcome.NONE:
		outcome = result.x
		outcome_reason = result.y
	last_tick_usec = Time.get_ticks_usec() - started


func snapshot() -> SimSnapshot:
	var snap := SimSnapshot.new()
	snap.tick = tick_index
	snap.time = time
	snap.outcome = outcome
	snap.outcome_reason = outcome_reason
	if world.tiles_generation != _snap_tiles_generation:
		_snap_tiles = world.tiles.duplicate()
		_snap_tiles_generation = world.tiles_generation
	snap.tiles = _snap_tiles
	snap.tiles_generation = world.tiles_generation
	snap.sim_ms = float(last_tick_usec) * 0.001
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
		snap.player_o2 = player.o2
		snap.player_o2_max = Constants.PLAYER_O2_MAX
	snap.player_zero_ice_timer = _faction_zero_ice(Types.Faction.PLAYER)
	snap.enemy_zero_ice_timer = _faction_zero_ice(Types.Faction.ENEMY)
	snap.player_living_depot_ice_empty = _living_depot_ice_empty(Types.Faction.PLAYER)
	snap.enemy_living_depot_ice_empty = _living_depot_ice_empty(Types.Faction.ENEMY)
	_copy_gather_channel(snap, player)
	snap.research_selected = research_selected
	snap.research_progress = research_progress
	snap.research_paid = research_paid
	snap.techs_done = techs_done
	return snap


func get_player() -> Unit:
	if world == null:
		return null
	return world.units.get(player_id) as Unit


func tech_complete(kind: int) -> bool:
	if kind < 0:
		return false
	return (techs_done & (1 << kind)) != 0


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
		return {
			"scrap": 0,
			"ice": 0,
			"ore": 0,
			"parts": 0,
			"cap_scrap": 0,
			"cap_ice": 0,
			"cap_ore": 0,
			"cap_parts": 0,
		}
	return {
		"scrap": inv.scrap,
		"ice": inv.ice,
		"ore": inv.ore,
		"parts": inv.parts,
		"cap_scrap": inv.cap_scrap,
		"cap_ice": inv.cap_ice,
		"cap_ore": inv.cap_ore,
		"cap_parts": inv.cap_parts,
	}


func _copy_gather_channel(snap: SimSnapshot, player: Unit) -> void:
	snap.gather_deposit_id = 0
	snap.gather_progress = 0.0
	if player == null or not player.alive or player.interact_progress <= 0.0:
		return
	if _interact_target_id <= 0 or not world.deposits.has(_interact_target_id):
		return
	snap.gather_deposit_id = _interact_target_id
	snap.gather_progress = player.interact_progress


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
		Rules.try_place(world, self, cmd.build_kind, cmd.build_tile)
	if cmd.research_kind >= 0:
		Research.select(self, cmd.research_kind)
	if cmd.build_kind < 0 and cmd.fire and player.weapon_cooldown <= 0.0:
		_spawn_projectile(
			Types.Faction.PLAYER,
			player.pos,
			player.aim,
			Constants.PLAYER_PROJ_DAMAGE,
			Constants.PLAYER_PROJ_SPEED,
			Constants.PLAYER_PROJ_LIFE,
			player
		)
		player.weapon_cooldown = Constants.PLAYER_FIRE_COOLDOWN


func _integrate_unit(unit: Unit) -> void:
	var delta := unit.vel * Constants.SIM_DT
	var pos := unit.pos
	pos.x += delta.x
	pos = _resolve_circle_tiles(unit, pos, unit.radius)
	pos.y += delta.y
	pos = _resolve_circle_tiles(unit, pos, unit.radius)
	var r := unit.radius
	var limit := float(Constants.MAP_W * Constants.TILE)
	pos.x = clampf(pos.x, r, limit - r)
	pos.y = clampf(pos.y, r, limit - r)
	unit.pos = pos


func _resolve_circle_tiles(unit: Unit, pos: Vector2, radius: float) -> Vector2:
	var tile := float(Constants.TILE)
	var min_tx := int(floor((pos.x - radius) / tile))
	var max_tx := int(floor((pos.x + radius) / tile))
	var min_ty := int(floor((pos.y - radius) / tile))
	var max_ty := int(floor((pos.y + radius) / tile))
	for _pass in 2:
		for y in range(min_ty, max_ty + 1):
			for x in range(min_tx, max_tx + 1):
				if not world.blocks_movement(x, y, unit):
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


func _decrement_cooldowns() -> void:
	for unit in world.units.values():
		unit.weapon_cooldown = maxf(0.0, unit.weapon_cooldown - Constants.SIM_DT)
		unit.path_recalc_in = maxf(0.0, unit.path_recalc_in - Constants.SIM_DT)
		if not unit.alive and unit.kind == Types.UnitKind.PLAYER:
			unit.respawn_timer = maxf(0.0, unit.respawn_timer - Constants.SIM_DT)
	for building in world.buildings.values():
		building.fire_cooldown = maxf(0.0, building.fire_cooldown - Constants.SIM_DT)
	for proj in world.projectiles.values():
		proj.life = maxf(0.0, proj.life - Constants.SIM_DT)
	if director != null:
		director.banner_timer = maxf(0.0, director.banner_timer - Constants.SIM_DT)


func _think_ai() -> void:
	var ids: Array = world.units.keys()
	ids.sort()
	for id in ids:
		var unit: Unit = world.units.get(id)
		if unit == null or not unit.alive:
			continue
		match unit.kind:
			Types.UnitKind.RAIDER:
				AiRaider.think(unit, self)
			Types.UnitKind.GUARD:
				AiGuard.think(unit, self)


func _update_stuck(unit: Unit) -> void:
	if unit.kind != Types.UnitKind.RAIDER and unit.kind != Types.UnitKind.GUARD:
		return
	var moved := unit.pos.distance_to(unit.stuck_last_pos)
	if unit.vel.length() > 0.0 and moved < Constants.RAIDER_STUCK_SPEED * Constants.SIM_DT:
		unit.stuck_timer += Constants.SIM_DT
	else:
		unit.stuck_timer = 0.0
	unit.stuck_last_pos = unit.pos


func _fire_ranged() -> void:
	_fire_turrets()
	_fire_enemy_rifles()


func _fire_enemy_rifles() -> void:
	var ids: Array = world.units.keys()
	ids.sort()
	for id in ids:
		var unit: Unit = world.units.get(id)
		if unit == null or not unit.alive:
			continue
		if unit.kind != Types.UnitKind.RAIDER and unit.kind != Types.UnitKind.GUARD:
			continue
		if unit.weapon_cooldown > 0.0:
			continue
		var target := Combat.resolve_fire_target(world, unit)
		if target == null:
			continue
		var dist := Combat.range_distance(world, unit, target)
		if dist <= Constants.RAIDER_MELEE_RANGE or dist > Constants.ENEMY_RIFLE_RANGE:
			continue
		Combat.aim_at(world, unit, target)
		_spawn_projectile(
			Types.Faction.ENEMY,
			unit.pos,
			unit.aim,
			Constants.RAIDER_PROJ_DAMAGE,
			Constants.PLAYER_PROJ_SPEED,
			Constants.PLAYER_PROJ_LIFE,
			unit
		)
		if unit.kind == Types.UnitKind.GUARD:
			unit.weapon_cooldown = Constants.GUARD_FIRE_COOLDOWN
		else:
			unit.weapon_cooldown = Constants.RAIDER_FIRE_COOLDOWN


func _fire_turrets() -> void:
	var ids: Array = world.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Building = world.buildings.get(id)
		if building == null or building.kind != Types.BuildingKind.TURRET:
			continue
		if building.hp <= 0:
			continue
		var center := world.footprint_aabb(building).get_center()
		var max_range := Research.turret_range(self, building.faction)
		var target := _nearest_opposing_unit(center, building.faction, max_range)
		if target == null:
			continue
		var delta := target.pos - center
		if delta.length_squared() > 0.0001:
			building.aim = delta.normalized()
		if building.fire_cooldown > 0.0:
			continue
		_spawn_projectile(
			building.faction,
			center,
			building.aim,
			Constants.TURRET_DAMAGE,
			Constants.TURRET_PROJ_SPEED,
			Constants.TURRET_PROJ_LIFE
		)
		building.fire_cooldown = Constants.TURRET_COOLDOWN


func _nearest_opposing_unit(origin: Vector2, faction: int, max_range: float) -> Unit:
	var best: Unit = null
	var best_dist := max_range
	var best_id := 0x7fffffff
	for unit in world.units.values():
		if not unit.alive or unit.faction == faction:
			continue
		var dist := origin.distance_to(unit.pos)
		if dist > max_range:
			continue
		if best != null and (dist > best_dist or (dist == best_dist and unit.id >= best_id)):
			continue
		best = unit
		best_dist = dist
		best_id = unit.id
	return best


func _spawn_projectile(
	faction: int,
	origin: Vector2,
	aim: Vector2,
	damage: int,
	speed: float,
	life: float,
	shooter: Unit = null
) -> void:
	var dir := aim
	if dir.length_squared() <= 0.0001:
		dir = Vector2(1, 0)
	else:
		dir = dir.normalized()
	var proj := Projectile.new()
	proj.id = world.alloc_id()
	proj.faction = faction
	proj.pos = origin + dir * Constants.MUZZLE_OFFSET
	proj.vel = dir * speed
	proj.damage = damage
	proj.life = life
	if shooter != null:
		proj.ignore_gate_id = Combat.overlapping_friendly_gate_id(world, shooter)
	world.projectiles[proj.id] = proj


func _integrate_projectiles() -> void:
	Combat.bucket_units(world)
	var ids: Array = world.projectiles.keys()
	ids.sort()
	var remove: Array[int] = []
	for id in ids:
		var proj: Projectile = world.projectiles.get(id)
		if proj == null:
			continue
		if Combat.integrate_projectile(world, proj) or proj.life <= 0.0:
			remove.append(int(id))
	for id in remove:
		world.projectiles.erase(id)


func _resolve_melee() -> void:
	var ids: Array = world.units.keys()
	ids.sort()
	for id in ids:
		var unit: Unit = world.units.get(id)
		if unit == null or not unit.alive or unit.weapon_cooldown > 0.0:
			continue
		var target := _melee_intent_target(unit)
		if target != null:
			Combat.apply_melee(unit, target)


func _melee_intent_target(unit: Unit) -> Object:
	var fire := Combat.resolve_fire_target(world, unit)
	if fire != null and Combat.range_distance(world, unit, fire) <= Constants.RAIDER_MELEE_RANGE:
		return fire
	if not unit.has_meta(AiRaider.MELEE_TARGET_META):
		return null
	var tid := int(unit.get_meta(AiRaider.MELEE_TARGET_META))
	if tid <= 0:
		return null
	var other: Unit = world.units.get(tid) as Unit
	if other != null:
		return other
	return world.buildings.get(tid)


func _process_deaths_and_respawn() -> void:
	for unit in world.units.values():
		if unit.hp > 0 or not unit.alive:
			continue
		_drop_unit_carry(unit)
		if unit.kind == Types.UnitKind.PLAYER:
			unit.respawn_timer = Constants.PLAYER_RESPAWN
	Combat.process_deaths(world)
	_maybe_respawn_player()


func _drop_unit_carry(unit: Unit) -> void:
	var inv: Inventory = unit.inventory
	if inv == null or not _inventory_has_stock(inv):
		return
	var pile := Loot.new()
	pile.id = world.alloc_id()
	pile.pos = unit.pos
	_copy_stock(inv, pile.inventory)
	world.loot[pile.id] = pile
	_clear_stock(inv)


func _maybe_respawn_player() -> void:
	var player := get_player()
	if player == null or player.alive or player.respawn_timer > 0.0:
		return
	if _player_habitat() == null:
		return
	var tile := _respawn_tile()
	player.pos = world.tile_center(tile.x, tile.y)
	player.hp = player.hp_max
	player.o2 = Constants.PLAYER_O2_MAX
	player.alive = true
	player.vel = Vector2.ZERO
	player.weapon_cooldown = 0.0
	player.interact_progress = 0.0
	player.inventory = Unit.inventory_for(Types.UnitKind.PLAYER)
	_interact_target_id = 0
	_interact_withdraw = false


func _tick_player_oxygen() -> void:
	var player := get_player()
	if player == null or not player.alive:
		return
	if _adjacent_o2_refill(player):
		player.o2 = Constants.PLAYER_O2_MAX
	else:
		player.o2 = maxf(0.0, player.o2 - Constants.SIM_DT)
	if player.o2 == 0.0 and tick_index % Constants.PLAYER_O2_PULSE_TICKS == 0:
		Combat.apply_damage(player, Constants.PLAYER_O2_HP_PER_PULSE)


func _tick_medbay_heal() -> void:
	var player := get_player()
	if player == null or not player.alive or player.hp <= 0 or not _adjacent_player_medbay(player):
		medbay_heal_acc = 0.0
		return
	if player.hp >= player.hp_max:
		return
	medbay_heal_acc += Constants.SIM_DT
	while player.hp < player.hp_max and (
		medbay_heal_acc > Constants.MEDBAY_HEAL_PERIOD
		or is_equal_approx(medbay_heal_acc, Constants.MEDBAY_HEAL_PERIOD)
	):
		medbay_heal_acc = maxf(0.0, medbay_heal_acc - Constants.MEDBAY_HEAL_PERIOD)
		player.hp = mini(player.hp + 1, player.hp_max)


func _adjacent_player_medbay(player: Unit) -> bool:
	for building in world.buildings.values():
		if building.hp <= 0 or building.faction != Types.Faction.PLAYER:
			continue
		if building.kind != Types.BuildingKind.MEDBAY:
			continue
		if world.point_aabb_distance(player.pos, world.footprint_aabb(building)) <= Constants.INTERACT_BUILDING_RANGE:
			return true
	return false


func _adjacent_o2_refill(player: Unit) -> bool:
	for building in world.buildings.values():
		if building.hp <= 0 or building.faction != Types.Faction.PLAYER:
			continue
		if not _is_o2_refill_building(building):
			continue
		if world.point_aabb_distance(player.pos, world.footprint_aabb(building)) <= Constants.INTERACT_BUILDING_RANGE:
			return true
	return false


func _is_o2_refill_building(building: Building) -> bool:
	return building.kind == Types.BuildingKind.HABITAT or building.kind == Types.BuildingKind.DEPOT


func _own_depot_withdrawing(cmd: InputCommand, target_id: int) -> bool:
	if cmd == null or not cmd.withdraw or target_id <= 0:
		return false
	var depot := world.buildings.get(target_id) as Building
	return (
		depot != null
		and depot.kind == Types.BuildingKind.DEPOT
		and depot.faction == Types.Faction.PLAYER
	)


func _inventory_has_stock(inv: Inventory) -> bool:
	return inv.scrap > 0 or inv.ice > 0 or inv.ore > 0 or inv.parts > 0


func _copy_stock(src: Inventory, dest: Inventory) -> void:
	if src.scrap > 0:
		dest.add(Types.ResourceKind.SCRAP, src.scrap)
	if src.ice > 0:
		dest.add(Types.ResourceKind.ICE, src.ice)
	if src.ore > 0:
		dest.add(Types.ResourceKind.ORE, src.ore)
	if src.parts > 0:
		dest.add(Types.ResourceKind.PARTS, src.parts)


func _clear_stock(inv: Inventory) -> void:
	if inv.scrap > 0:
		inv.remove(Types.ResourceKind.SCRAP, inv.scrap)
	if inv.ice > 0:
		inv.remove(Types.ResourceKind.ICE, inv.ice)
	if inv.ore > 0:
		inv.remove(Types.ResourceKind.ORE, inv.ore)
	if inv.parts > 0:
		inv.remove(Types.ResourceKind.PARTS, inv.parts)


func _player_habitat() -> Building:
	for building in world.buildings.values():
		if building.kind != Types.BuildingKind.HABITAT:
			continue
		if building.faction != Types.Faction.PLAYER:
			continue
		if building.hp <= 0:
			continue
		return building
	return null


func _respawn_tile() -> Vector2i:
	var spawn := Constants.PLAYER_SPAWN_TILE
	if world.is_walkable(spawn.x, spawn.y):
		return spawn
	var nearby := _chebyshev_walkable(spawn, Constants.RESPAWN_SEARCH)
	if nearby.x >= 0:
		return nearby
	return _flood_respawn_from_habitat()


func _chebyshev_walkable(origin: Vector2i, radius: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 0x7fffffff
	var best_i := 0x7fffffff
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var d := maxi(absi(dx), absi(dy))
			if d == 0 or d > radius:
				continue
			var tile := Vector2i(origin.x + dx, origin.y + dy)
			if not world.is_walkable(tile.x, tile.y):
				continue
			var index := tile.y * Constants.MAP_W + tile.x
			if d < best_d or (d == best_d and index < best_i):
				best = tile
				best_d = d
				best_i = index
	return best


func _flood_respawn_from_habitat() -> Vector2i:
	var habitat := _player_habitat()
	if habitat == null:
		return Constants.PLAYER_SPAWN_TILE
	var start := world.world_to_tile(world.footprint_aabb(habitat).get_center())
	var seen := {}
	var q: Array[Vector2i] = [start]
	seen[start.y * Constants.MAP_W + start.x] = true
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var i := 0
	while i < q.size():
		var p: Vector2i = q[i]
		i += 1
		if world.is_walkable(p.x, p.y):
			return p
		for d in dirs:
			var n: Vector2i = p + d
			if not world.in_bounds(n.x, n.y):
				continue
			var key := n.y * Constants.MAP_W + n.x
			if seen.has(key):
				continue
			seen[key] = true
			q.append(n)
	return Constants.PLAYER_SPAWN_TILE
