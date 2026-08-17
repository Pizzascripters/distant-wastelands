class_name Rules
extends RefCounted


static func cost(kind: int) -> Dictionary:
	match kind:
		Types.BuildingKind.WALL:
			return {Types.ResourceKind.SCRAP: Constants.WALL_COST}
		Types.BuildingKind.TURRET:
			return {Types.ResourceKind.SCRAP: Constants.TURRET_COST}
		Types.BuildingKind.WORKSHOP:
			return {Types.ResourceKind.SCRAP: Constants.WORKSHOP_COST}
		Types.BuildingKind.LAB:
			return {Types.ResourceKind.SCRAP: Constants.LAB_COST}
		Types.BuildingKind.FARM:
			return {Types.ResourceKind.SCRAP: Constants.FARM_COST_SCRAP, Types.ResourceKind.ICE: Constants.FARM_COST_ICE}
		Types.BuildingKind.MEDBAY:
			return {
				Types.ResourceKind.SCRAP: Constants.MEDBAY_COST_SCRAP,
				Types.ResourceKind.ICE: Constants.MEDBAY_COST_ICE,
			}
		Types.BuildingKind.GATE:
			return {
				Types.ResourceKind.SCRAP: Constants.GATE_COST_SCRAP,
				Types.ResourceKind.PARTS: Constants.GATE_COST_PARTS,
			}
		Types.BuildingKind.HABITAT:
			return {Types.ResourceKind.SCRAP: Constants.HABITAT_COST_SCRAP}
		Types.BuildingKind.DEPOT:
			return {Types.ResourceKind.SCRAP: Constants.DEPOT_COST_SCRAP}
		_:
			return {}


static func cost_scrap(kind: int) -> int:
	var price := cost(kind)
	if price.has(Types.ResourceKind.SCRAP) and price.size() == 1:
		return int(price[Types.ResourceKind.SCRAP])
	if price.is_empty():
		return -1
	return int(price.get(Types.ResourceKind.SCRAP, 0))


static func can_place(world: World, sim: Sim, kind: int, tile: Vector2i) -> bool:
	if not Research.building_unlocked(sim, kind):
		return false
	var price := cost(kind)
	if price.is_empty():
		return false
	if _hp_for(kind) <= 0:
		return false
	var span := world.footprint_span(kind)
	for dy in span:
		for dx in span:
			var x: int = tile.x + dx
			var y: int = tile.y + dy
			if not world.in_bounds(x, y):
				return false
			if world.get_terrain(x, y) != Types.TileTerrain.EMPTY:
				return false
			if world.building_at(x, y) != null:
				return false
			if _deposit_at(world, Vector2i(x, y)):
				return false
			if world.in_enemy_camp_rect(Vector2i(x, y)):
				return false
			if _unit_overlaps_tile(world, Vector2i(x, y)):
				return false
	if not _can_afford_place(world, kind, price):
		return false
	if world.buildings.size() >= Constants.MAX_BUILDINGS:
		return false
	return true


static func try_place(world: World, sim: Sim, kind: int, tile: Vector2i) -> bool:
	if not can_place(world, sim, kind, tile):
		return false
	if not _pay_place(world, kind, cost(kind)):
		return false
	var seed_ice := (
		kind == Types.BuildingKind.HABITAT
		and living_player(world, Types.BuildingKind.HABITAT).is_empty()
	)
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = kind
	building.faction = Types.Faction.PLAYER
	building.origin_tile = tile
	building.hp = _hp_for(kind)
	building.hp_max = building.hp
	building.aim = Vector2(1, 0)
	building.inventory = Building.inventory_for(kind)
	building.ice_debt_timer = 0.0
	if seed_ice and building.inventory != null:
		building.inventory.add(Types.ResourceKind.ICE, Constants.LAST_HABITAT_ICE)
	world.buildings[building.id] = building
	world.occupy(building)
	return true


static func living_player(world: World, kind: int) -> Array:
	var out: Array = []
	if world == null:
		return out
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.faction != Types.Faction.PLAYER or building.kind != kind:
			continue
		out.append(building)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


static func player_pool_amount(world: World, kind: int) -> int:
	var holders: Array = _pool_holders(world, kind)
	var total := 0
	for raw in holders:
		var building := raw as Building
		if building == null or building.inventory == null:
			continue
		total += _kind_amount(building.inventory, kind)
	return total


static func pay_player(world: World, price: Dictionary) -> bool:
	if not _can_pay_player(world, price):
		return false
	for resource_kind in price.keys():
		var remain := int(price[resource_kind])
		if remain <= 0:
			continue
		for raw in _pool_holders(world, int(resource_kind)):
			if remain <= 0:
				break
			var building := raw as Building
			if building == null or building.inventory == null:
				continue
			remain -= building.inventory.remove(int(resource_kind), remain)
	return true


static func can_spawn_enemy(world: World, tile: Vector2i) -> bool:
	return enemy_density_cell(world, tile) + 1 <= Constants.ENEMY_DENSITY_CAP


static func enemy_density_cell(world: World, tile: Vector2i) -> int:
	if world == null:
		return 0
	if world.spatial == null:
		world.rebuild_spatial()
	var n := Constants.ENEMY_DENSITY_N
	var origin := Vector2i((tile.x / n) * n, (tile.y / n) * n)
	return world.spatial.enemy_units_in_aabb(Rect2i(origin, Vector2i(n, n)))


static func tick_life_support(sim: Sim) -> void:
	if sim == null or sim.world == null:
		return
	var habitats: Array = []
	for faction in [Types.Faction.PLAYER, Types.Faction.ENEMY]:
		var group: Array = []
		for raw in sim.world.buildings.values():
			var building := raw as Building
			if building == null or building.hp <= 0:
				continue
			if building.kind != Types.BuildingKind.HABITAT or building.faction != faction:
				continue
			group.append(building)
		group.sort_custom(func(a, b): return a.id < b.id)
		habitats.append_array(group)
	for raw in habitats:
		var building := raw as Building
		if building.faction == Types.Faction.ENEMY and not _enemy_habitat_ever_aggro(sim.world, building):
			continue
		building.ice_debt_timer += Constants.SIM_DT
		var period := _ice_pull_period(building.faction)
		if building.ice_debt_timer < period:
			continue
		building.ice_debt_timer -= period
		if building.inventory != null and building.inventory.ice >= 1:
			building.inventory.remove(Types.ResourceKind.ICE, 1)


static func habitat_gives_o2(building: Building) -> bool:
	return (
		building != null
		and building.kind == Types.BuildingKind.HABITAT
		and building.faction == Types.Faction.PLAYER
		and building.hp > 0
		and building.inventory != null
		and building.inventory.ice >= 1
	)


static func evaluate_outcome(sim: Sim) -> Vector2i:
	if sim == null or sim.world == null:
		return Vector2i(Types.Outcome.NONE, Types.OutcomeReason.NONE)
	if bool(sim.oxygen_failed):
		return Vector2i(Types.Outcome.PLAYER_LOSE, Types.OutcomeReason.SUFFOCATION)
	return Vector2i(Types.Outcome.NONE, Types.OutcomeReason.NONE)


const _HAULABLES: Array[int] = [
	Types.ResourceKind.SCRAP,
	Types.ResourceKind.ICE,
	Types.ResourceKind.ORE,
	Types.ResourceKind.PARTS,
	Types.ResourceKind.FOOD,
]

const _DEPOT_HAULABLES: Array[int] = [
	Types.ResourceKind.SCRAP,
	Types.ResourceKind.ORE,
	Types.ResourceKind.PARTS,
]

const _PRI_DEPOT := 0
const _PRI_HABITAT := 1
const _PRI_LOOT := 2
const _PRI_DEPOSIT := 3
const _PRI_WORKSHOP := 4
const _PRI_LAB := 5
const _PRI_FARM := 6


static func resolve_interact(
	world: World,
	unit: Unit,
	cmd: InputCommand,
	last_target_id: int,
	last_withdraw: bool = false,
	sim: Sim = null
) -> int:
	if unit == null:
		return 0
	if not unit.alive or unit.inventory == null or world == null:
		unit.interact_progress = 0.0
		return 0
	if cmd == null or not cmd.interact or cmd.move.length() > 0.0:
		unit.interact_progress = 0.0
		return 0

	var best_id := 0
	var best_dist := INF
	var best_pri := 99
	var best_obj: Object = null
	var depot := _interact_depot(world, unit.pos)
	if depot != null:
		var depot_dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(depot))
		if _better_interact(depot.id, depot_dist, _PRI_DEPOT, best_id, best_dist, best_pri):
			best_id = depot.id
			best_dist = depot_dist
			best_pri = _PRI_DEPOT
			best_obj = depot
	var habitat := _interact_habitat(world, unit.pos)
	if habitat != null:
		var habitat_dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(habitat))
		if _better_interact(habitat.id, habitat_dist, _PRI_HABITAT, best_id, best_dist, best_pri):
			best_id = habitat.id
			best_dist = habitat_dist
			best_pri = _PRI_HABITAT
			best_obj = habitat
	var pile := _interact_loot(world, unit.pos)
	if pile != null:
		var loot_dist := unit.pos.distance_to(pile.pos)
		if _better_interact(pile.id, loot_dist, _PRI_LOOT, best_id, best_dist, best_pri):
			best_id = pile.id
			best_dist = loot_dist
			best_pri = _PRI_LOOT
			best_obj = pile
	var deposit := _interact_deposit(world, unit)
	if deposit != null:
		var dep_dist := unit.pos.distance_to(world.tile_center(deposit.tile.x, deposit.tile.y))
		if _better_interact(deposit.id, dep_dist, _PRI_DEPOSIT, best_id, best_dist, best_pri):
			best_id = deposit.id
			best_dist = dep_dist
			best_pri = _PRI_DEPOSIT
			best_obj = deposit
	var workshop := _interact_workshop(world, unit, Research.workshop_unlocked(sim))
	if workshop != null:
		var shop_dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(workshop))
		if _better_interact(workshop.id, shop_dist, _PRI_WORKSHOP, best_id, best_dist, best_pri):
			best_id = workshop.id
			best_dist = shop_dist
			best_pri = _PRI_WORKSHOP
			best_obj = workshop
	var lab := _interact_lab(world, unit, sim)
	if lab != null:
		var lab_dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(lab))
		if _better_interact(lab.id, lab_dist, _PRI_LAB, best_id, best_dist, best_pri):
			best_id = lab.id
			best_dist = lab_dist
			best_pri = _PRI_LAB
			best_obj = lab
	var farm := _interact_farm(world, unit)
	if farm != null:
		var farm_dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(farm))
		if _better_interact(farm.id, farm_dist, _PRI_FARM, best_id, best_dist, best_pri):
			best_id = farm.id
			best_dist = farm_dist
			best_pri = _PRI_FARM
			best_obj = farm
	if best_id == 0 or best_obj == null:
		unit.interact_progress = 0.0
		return 0
	if best_obj is Building and (best_obj as Building).kind == Types.BuildingKind.DEPOT:
		var chosen := best_obj as Building
		var withdrawing := cmd.withdraw and chosen.faction == unit.faction
		if chosen.id != last_target_id or withdrawing != last_withdraw:
			unit.interact_progress = 0.0
		_tick_depot_transfer(unit, chosen, withdrawing)
		return chosen.id
	if best_obj is Building and (best_obj as Building).kind == Types.BuildingKind.HABITAT:
		var chosen_hab := best_obj as Building
		var withdrawing_ice := cmd.withdraw and chosen_hab.faction == unit.faction
		if chosen_hab.id != last_target_id or withdrawing_ice != last_withdraw:
			unit.interact_progress = 0.0
		_tick_habitat_transfer(unit, chosen_hab, withdrawing_ice)
		return chosen_hab.id
	if best_obj is Loot:
		_begin_channel(unit, last_target_id, best_id)
		_tick_loot(world, unit, best_obj as Loot, sim)
		return best_id
	if best_obj is Deposit:
		_begin_channel(unit, last_target_id, best_id)
		_tick_gather(world, unit, best_obj as Deposit)
		return best_id
	if best_obj is Building and (best_obj as Building).kind == Types.BuildingKind.WORKSHOP:
		_begin_channel(unit, last_target_id, best_id)
		_tick_workshop(unit)
		return best_id
	if best_obj is Building and (best_obj as Building).kind == Types.BuildingKind.LAB:
		_begin_channel(unit, last_target_id, best_id)
		_tick_lab(sim)
		return best_id
	if best_obj is Building and (best_obj as Building).kind == Types.BuildingKind.FARM:
		var farm_b := best_obj as Building
		if farm_b.id != last_target_id:
			unit.interact_progress = 0.0
		_tick_farm_harvest(unit, farm_b, sim)
		return farm_b.id
	unit.interact_progress = 0.0
	return 0


static func workshop_can_craft(unit: Unit, recipe_unlocked: bool = false) -> bool:
	if not recipe_unlocked or unit == null or unit.inventory == null:
		return false
	if unit.inventory.scrap < Constants.WORKSHOP_SCRAP_COST:
		return false
	if unit.inventory.ore < Constants.WORKSHOP_ORE_COST:
		return false
	return unit.inventory.free_space(Types.ResourceKind.PARTS) >= Constants.WORKSHOP_PARTS_OUT


static func _tick_workshop(unit: Unit) -> void:
	if not workshop_can_craft(unit, true):
		unit.interact_progress = 0.0
		return
	unit.interact_progress += Constants.SIM_DT
	if unit.interact_progress < Constants.WORKSHOP_CRAFT_CHANNEL:
		return
	unit.interact_progress = 0.0
	if not workshop_can_craft(unit, true):
		return
	unit.inventory.remove(Types.ResourceKind.SCRAP, Constants.WORKSHOP_SCRAP_COST)
	unit.inventory.remove(Types.ResourceKind.ORE, Constants.WORKSHOP_ORE_COST)
	unit.inventory.add(Types.ResourceKind.PARTS, Constants.WORKSHOP_PARTS_OUT)


static func _better_interact(
	id: int, dist: float, pri: int, best_id: int, best_dist: float, best_pri: int
) -> bool:
	if best_id == 0:
		return true
	if dist < best_dist and not is_equal_approx(dist, best_dist):
		return true
	if not is_equal_approx(dist, best_dist):
		return false
	if pri != best_pri:
		return pri < best_pri
	return id < best_id


static func _interact_lab(world: World, unit: Unit, sim: Sim) -> Building:
	if sim == null or sim.research_selected < 0:
		return null
	if sim.tech_complete(sim.research_selected):
		return null
	var need := Research.prereq(sim.research_selected)
	if need >= 0 and not sim.tech_complete(need):
		return null
	var best: Building = null
	var best_dist := INF
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.kind != Types.BuildingKind.LAB:
			continue
		if building.faction != Types.Faction.PLAYER:
			continue
		var dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(building))
		if dist > Constants.INTERACT_BUILDING_RANGE:
			continue
		if best != null and (dist > best_dist or (is_equal_approx(dist, best_dist) and building.id >= best.id)):
			continue
		best = building
		best_dist = dist
	return best


static func _tick_lab(sim: Sim) -> void:
	if sim == null:
		return
	var kind := sim.research_selected
	if kind < 0 or sim.tech_complete(kind):
		return
	var need := Research.prereq(kind)
	if need >= 0 and not sim.tech_complete(need):
		return
	if not sim.research_paid:
		if not _pay_research(sim, kind):
			return
		sim.research_paid = true
	sim.research_progress += Constants.SIM_DT
	if sim.research_progress >= Research.duration(kind):
		Research.mark_complete(sim, kind)
		sim.research_selected = -1
		sim.research_progress = 0.0
		sim.research_paid = false


static func _pay_research(sim: Sim, kind: int) -> bool:
	return Research.try_pay(sim, kind)


static func _can_pay_player(world: World, price: Dictionary) -> bool:
	if world == null:
		return false
	for resource_kind in price.keys():
		if player_pool_amount(world, int(resource_kind)) < int(price[resource_kind]):
			return false
	return true


static func _can_afford_place(world: World, kind: int, price: Dictionary) -> bool:
	if _uses_last_pad_carry(world, kind):
		var player := _player_unit(world)
		if player == null or player.inventory == null:
			return false
		return player.inventory.scrap >= _last_pad_scrap(kind)
	return _can_pay_player(world, price)


static func _pay_place(world: World, kind: int, price: Dictionary) -> bool:
	if _uses_last_pad_carry(world, kind):
		var player := _player_unit(world)
		var need := _last_pad_scrap(kind)
		if player == null or player.inventory == null or player.inventory.scrap < need:
			return false
		player.inventory.remove(Types.ResourceKind.SCRAP, need)
		return true
	return pay_player(world, price)


static func _uses_last_pad_carry(world: World, kind: int) -> bool:
	if kind == Types.BuildingKind.DEPOT:
		return living_player(world, Types.BuildingKind.DEPOT).is_empty()
	if kind == Types.BuildingKind.HABITAT:
		if not living_player(world, Types.BuildingKind.HABITAT).is_empty():
			return false
		return not _can_pay_player(world, cost(kind))
	return false


static func _last_pad_scrap(kind: int) -> int:
	if kind == Types.BuildingKind.HABITAT:
		return Constants.LAST_PAD_HABITAT_SCRAP
	if kind == Types.BuildingKind.DEPOT:
		return Constants.LAST_PAD_DEPOT_SCRAP
	return 0


static func _player_unit(world: World) -> Unit:
	if world == null:
		return null
	for raw in world.units.values():
		var unit := raw as Unit
		if unit == null or not unit.alive:
			continue
		if unit.kind == Types.UnitKind.PLAYER:
			return unit
	return null


static func _pool_holders(world: World, resource_kind: int) -> Array:
	if resource_kind == Types.ResourceKind.ICE:
		return living_player(world, Types.BuildingKind.HABITAT)
	if (
		resource_kind == Types.ResourceKind.SCRAP
		or resource_kind == Types.ResourceKind.ORE
		or resource_kind == Types.ResourceKind.PARTS
	):
		return living_player(world, Types.BuildingKind.DEPOT)
	return []


static func _interact_workshop(world: World, unit: Unit, recipe_unlocked: bool) -> Building:
	if not workshop_can_craft(unit, recipe_unlocked):
		return null
	var best: Building = null
	var best_dist := INF
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.kind != Types.BuildingKind.WORKSHOP:
			continue
		if building.faction != Types.Faction.PLAYER:
			continue
		var dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(building))
		if dist > Constants.INTERACT_BUILDING_RANGE:
			continue
		if best != null and (dist > best_dist or (is_equal_approx(dist, best_dist) and building.id >= best.id)):
			continue
		best = building
		best_dist = dist
	return best


static func _begin_channel(unit: Unit, last_target_id: int, target_id: int) -> void:
	if target_id != last_target_id:
		unit.interact_progress = 0.0


static func _tick_depot_transfer(unit: Unit, depot: Building, withdrawing: bool) -> void:
	unit.interact_progress += Constants.SIM_DT
	if depot.inventory == null:
		return
	var src: Inventory = unit.inventory
	var dest: Inventory = depot.inventory
	if depot.faction != unit.faction or withdrawing:
		src = depot.inventory
		dest = unit.inventory
	while unit.interact_progress >= Constants.TRANSFER_PERIOD:
		unit.interact_progress -= Constants.TRANSFER_PERIOD
		for kind in _DEPOT_HAULABLES:
			_move_up_to(src, dest, kind, Constants.TRANSFER_BATCH)


static func _tick_habitat_transfer(unit: Unit, habitat: Building, withdrawing: bool) -> void:
	unit.interact_progress += Constants.SIM_DT
	if habitat.inventory == null:
		return
	var src: Inventory = unit.inventory
	var dest: Inventory = habitat.inventory
	if habitat.faction != unit.faction or withdrawing:
		src = habitat.inventory
		dest = unit.inventory
	while unit.interact_progress >= Constants.TRANSFER_PERIOD:
		unit.interact_progress -= Constants.TRANSFER_PERIOD
		_move_up_to(src, dest, Types.ResourceKind.ICE, Constants.TRANSFER_BATCH)


static func _tick_loot(world: World, unit: Unit, pile: Loot, sim: Sim = null) -> void:
	unit.interact_progress += Constants.SIM_DT
	if unit.interact_progress < Constants.LOOT_CHANNEL:
		return
	unit.interact_progress = 0.0
	if pile.inventory != null:
		var food_before := 0
		if unit.inventory != null:
			food_before = _kind_amount(unit.inventory, Types.ResourceKind.FOOD)
		for kind in _HAULABLES:
			_move_up_to(pile.inventory, unit.inventory, kind, _kind_amount(pile.inventory, kind))
		if (
			sim != null
			and unit.inventory != null
			and _kind_amount(unit.inventory, Types.ResourceKind.FOOD) > food_before
		):
			sim.hunger_starving = false
		if _has_stock(pile.inventory):
			return
	world.loot.erase(pile.id)


static func _tick_gather(world: World, unit: Unit, deposit: Deposit) -> void:
	unit.interact_progress += Constants.SIM_DT
	if unit.interact_progress < Constants.GATHER_CHANNEL:
		return
	unit.interact_progress = 0.0
	if deposit.remaining <= 0 or unit.inventory.free_space(deposit.kind) <= 0:
		return
	unit.inventory.add(deposit.kind, 1)
	deposit.remaining -= 1
	if deposit.remaining <= 0:
		world.deposits.erase(deposit.id)


static func _move_up_to(src: Inventory, dest: Inventory, kind: int, n: int) -> void:
	if src == null or dest == null or n <= 0:
		return
	var have := _kind_amount(src, kind)
	var amt := mini(n, mini(have, dest.free_space(kind)))
	if amt <= 0:
		return
	src.remove(kind, amt)
	dest.add(kind, amt)


static func _kind_amount(inv: Inventory, kind: int) -> int:
	match kind:
		Types.ResourceKind.SCRAP:
			return inv.scrap
		Types.ResourceKind.ICE:
			return inv.ice
		Types.ResourceKind.ORE:
			return inv.ore
		Types.ResourceKind.PARTS:
			return inv.parts
		Types.ResourceKind.FOOD:
			return inv.food
		_:
			return 0


static func _has_stock(inv: Inventory) -> bool:
	return inv.scrap > 0 or inv.ice > 0 or inv.ore > 0 or inv.parts > 0 or inv.food > 0


static func _interact_farm(world: World, unit: Unit) -> Building:
	var best: Building = null
	var best_dist := INF
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.kind != Types.BuildingKind.FARM:
			continue
		if building.faction != Types.Faction.PLAYER:
			continue
		var dist := world.point_aabb_distance(unit.pos, world.footprint_aabb(building))
		if dist > Constants.INTERACT_BUILDING_RANGE:
			continue
		if best != null and (dist > best_dist or (is_equal_approx(dist, best_dist) and building.id >= best.id)):
			continue
		best = building
		best_dist = dist
	return best


static func _tick_farm_harvest(unit: Unit, farm: Building, sim: Sim = null) -> void:
	unit.interact_progress += Constants.SIM_DT
	if unit.inventory == null:
		return
	while unit.interact_progress >= Constants.TRANSFER_PERIOD:
		unit.interact_progress -= Constants.TRANSFER_PERIOD
		var amt := mini(Constants.TRANSFER_BATCH, farm.food_stock)
		amt = mini(amt, unit.inventory.free_space(Types.ResourceKind.FOOD))
		if amt <= 0:
			continue
		farm.food_stock -= amt
		unit.inventory.add(Types.ResourceKind.FOOD, amt)
		if sim != null:
			sim.hunger_starving = false


static func _interact_depot(world: World, pos: Vector2) -> Building:
	var depot := world.nearest_living_depot(pos)
	if depot == null:
		return null
	if world.point_aabb_distance(pos, world.footprint_aabb(depot)) > Constants.INTERACT_BUILDING_RANGE:
		return null
	return depot


static func _interact_habitat(world: World, pos: Vector2) -> Building:
	var best: Building = null
	var best_dist := INF
	for raw in world.buildings.values():
		var building := raw as Building
		if building == null or building.hp <= 0:
			continue
		if building.kind != Types.BuildingKind.HABITAT:
			continue
		var dist := world.point_aabb_distance(pos, world.footprint_aabb(building))
		if dist > Constants.INTERACT_BUILDING_RANGE:
			continue
		if best != null and (dist > best_dist or (is_equal_approx(dist, best_dist) and building.id >= best.id)):
			continue
		best = building
		best_dist = dist
	return best


static func _interact_loot(world: World, pos: Vector2) -> Loot:
	var best: Loot = null
	var best_dist := INF
	for pile in world.loot.values():
		var dist := pos.distance_to(pile.pos)
		if dist > Constants.GATHER_RANGE:
			continue
		if best != null and (dist > best_dist or (dist == best_dist and pile.id >= best.id)):
			continue
		best = pile
		best_dist = dist
	return best


static func _interact_deposit(world: World, unit: Unit) -> Deposit:
	var best: Deposit = null
	var best_dist := INF
	for deposit in world.deposits.values():
		if deposit.remaining <= 0:
			continue
		if unit.inventory.free_space(deposit.kind) <= 0:
			continue
		var dist := unit.pos.distance_to(world.tile_center(deposit.tile.x, deposit.tile.y))
		if dist > Constants.GATHER_RANGE:
			continue
		if best != null and (dist > best_dist or (dist == best_dist and deposit.id >= best.id)):
			continue
		best = deposit
		best_dist = dist
	return best


static func _hp_for(kind: int) -> int:
	match kind:
		Types.BuildingKind.WALL:
			return Constants.WALL_HP
		Types.BuildingKind.TURRET:
			return Constants.TURRET_HP
		Types.BuildingKind.WORKSHOP:
			return Constants.WORKSHOP_HP
		Types.BuildingKind.LAB:
			return Constants.LAB_HP
		Types.BuildingKind.FARM:
			return Constants.FARM_HP
		Types.BuildingKind.MEDBAY:
			return Constants.MEDBAY_HP
		Types.BuildingKind.GATE:
			return Constants.GATE_HP
		Types.BuildingKind.HABITAT:
			return Constants.HABITAT_HP
		Types.BuildingKind.DEPOT:
			return Constants.DEPOT_HP
		_:
			return 0


static func _enemy_habitat_ever_aggro(world: World, habitat: Building) -> bool:
	if world == null or habitat == null:
		return false
	for raw in world.camps:
		var camp := raw as World.Camp
		if camp != null and camp.habitat_id == habitat.id:
			return camp.ever_aggro
	return false


static func _ice_pull_period(faction: int) -> float:
	if faction == Types.Faction.PLAYER:
		return Constants.ICE_PULL_PLAYER
	return Constants.ICE_PULL_ENEMY


static func _deposit_at(world: World, tile: Vector2i) -> bool:
	for deposit in world.deposits.values():
		if deposit.tile == tile:
			return true
	return false


static func _unit_overlaps_tile(world: World, tile: Vector2i) -> bool:
	var aabb := world.tile_aabb(tile.x, tile.y)
	for unit in world.units.values():
		if world.point_aabb_distance(unit.pos, aabb) <= unit.radius:
			return true
	return false
