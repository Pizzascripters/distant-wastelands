extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_projectile_damages_opposing(fails)
	_test_projectile_skips_same_faction(fails)
	_test_projectile_hits_lowest_id(fails)
	_test_projectile_hits_adjacent_tile_halo(fails)
	_test_enemy_projectile_friendly_fire_off(fails)
	_test_enemy_projectile_hits_player_building(fails)
	_test_melee_respects_cooldown(fails)
	_test_death_at_zero(fails)
	_test_depot_death_spills_without_life_support(fails)
	_test_two_arg_spill_rejects_ore(fails)
	_test_four_arg_spill_holds_ore(fails)
	_test_player_on_gate_shot_lives(fails)
	_test_muzzle_in_friendly_wall_eaten(fails)
	_test_five_kind_spill_holds_food(fails)
	_test_solid_terrain_eats_shots(fails)
	return fails


func _test_projectile_damages_opposing(fails: PackedStringArray) -> void:
	var world := World.new()
	var pos := Vector2(100, 100)
	var raider := _make_unit(world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, pos, Constants.RAIDER_HP)
	var proj := _make_proj(Types.Faction.PLAYER, pos, Constants.PLAYER_PROJ_DAMAGE)
	if not Combat.resolve_projectile_hit(world, proj):
		fails.append("player projectile should hit an overlapping enemy")
	var expected := Constants.RAIDER_HP - Constants.PLAYER_PROJ_DAMAGE
	if raider.hp != expected:
		fails.append("opposing unit hp is %d, expected %d" % [raider.hp, expected])


func _test_projectile_skips_same_faction(fails: PackedStringArray) -> void:
	var world := World.new()
	var pos := Vector2(100, 100)
	var player := _make_unit(world, Types.UnitKind.PLAYER, Types.Faction.PLAYER, pos, Constants.PLAYER_HP)
	var proj := _make_proj(Types.Faction.PLAYER, pos, Constants.PLAYER_PROJ_DAMAGE)
	Combat.resolve_projectile_hit(world, proj)
	if player.hp != Constants.PLAYER_HP:
		fails.append("same-faction projectile changed hp to %d" % player.hp)


func _test_projectile_hits_lowest_id(fails: PackedStringArray) -> void:
	var world := World.new()
	var pos := Vector2(100, 100)
	var first := _make_unit(world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, pos, Constants.RAIDER_HP)
	var second := _make_unit(world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, pos, Constants.RAIDER_HP)
	if first.id >= second.id:
		fails.append("expected first spawned unit to have the lower id")
		return
	var proj := _make_proj(Types.Faction.PLAYER, pos, Constants.PLAYER_PROJ_DAMAGE)
	Combat.resolve_projectile_hit(world, proj)
	var expected := Constants.RAIDER_HP - Constants.PLAYER_PROJ_DAMAGE
	if first.hp != expected:
		fails.append("lowest id unit hp is %d, expected %d" % [first.hp, expected])
	if second.hp != Constants.RAIDER_HP:
		fails.append("higher id overlapping unit hp is %d, expected %d" % [second.hp, Constants.RAIDER_HP])


func _test_projectile_hits_adjacent_tile_halo(fails: PackedStringArray) -> void:
	var world := World.new()
	var tile := float(Constants.TILE)
	var proj_pos := Vector2(3.0 * tile + 30.0, 3.0 * tile + 16.0)
	var unit_pos := Vector2(4.0 * tile + 2.0, 3.0 * tile + 16.0)
	var raider := _make_unit(world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, unit_pos, Constants.RAIDER_HP)
	var proj := _make_proj(Types.Faction.PLAYER, proj_pos, Constants.PLAYER_PROJ_DAMAGE)
	if world.world_to_tile(proj_pos) == world.world_to_tile(unit_pos):
		fails.append("halo fixture should keep projectile and unit on neighboring tiles")
		return
	if not Combat.resolve_projectile_hit(world, proj):
		fails.append("projectile should hit a unit whose center is in an adjacent tile")
	var expected := Constants.RAIDER_HP - Constants.PLAYER_PROJ_DAMAGE
	if raider.hp != expected:
		fails.append("adjacent-tile unit hp is %d, expected %d" % [raider.hp, expected])


func _test_enemy_projectile_friendly_fire_off(fails: PackedStringArray) -> void:
	var world := World.new()
	var pos := Vector2(100, 100)
	var raider := _make_unit(world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, pos, Constants.RAIDER_HP)
	var player := _make_unit(world, Types.UnitKind.PLAYER, Types.Faction.PLAYER, pos, Constants.PLAYER_HP)
	Combat.bucket_units(world)
	var ally_shot := _make_proj(Types.Faction.ENEMY, pos, Constants.RAIDER_PROJ_DAMAGE)
	Combat.resolve_projectile_hit(world, ally_shot)
	if raider.hp != Constants.RAIDER_HP:
		fails.append("enemy projectile damaged a same-faction unit")
	if player.hp != Constants.PLAYER_HP - Constants.RAIDER_PROJ_DAMAGE:
		fails.append(
			"enemy projectile player hp is %d, expected %d"
			% [player.hp, Constants.PLAYER_HP - Constants.RAIDER_PROJ_DAMAGE]
		)


func _test_enemy_projectile_hits_player_building(fails: PackedStringArray) -> void:
	var world := World.new()
	var wall := Building.new()
	wall.id = world.alloc_id()
	wall.kind = Types.BuildingKind.WALL
	wall.faction = Types.Faction.PLAYER
	wall.origin_tile = Vector2i(3, 3)
	wall.hp = Constants.WALL_HP
	wall.hp_max = Constants.WALL_HP
	world.buildings[wall.id] = wall
	world.occupy(wall)
	var center := world.footprint_aabb(wall).get_center()
	var shot := _make_proj(Types.Faction.ENEMY, center, Constants.RAIDER_PROJ_DAMAGE)
	if not Combat.resolve_projectile_hit(world, shot):
		fails.append("enemy projectile should hit a player wall")
	if wall.hp != Constants.WALL_HP - Constants.RAIDER_PROJ_DAMAGE:
		fails.append("player wall hp is %d after enemy projectile" % wall.hp)
	var enemy_wall := Building.new()
	enemy_wall.id = world.alloc_id()
	enemy_wall.kind = Types.BuildingKind.WALL
	enemy_wall.faction = Types.Faction.ENEMY
	enemy_wall.origin_tile = Vector2i(6, 3)
	enemy_wall.hp = Constants.WALL_HP
	enemy_wall.hp_max = Constants.WALL_HP
	world.buildings[enemy_wall.id] = enemy_wall
	world.occupy(enemy_wall)
	var eat := _make_proj(Types.Faction.ENEMY, world.footprint_aabb(enemy_wall).get_center(), Constants.RAIDER_PROJ_DAMAGE)
	if not Combat.resolve_projectile_hit(world, eat):
		fails.append("enemy projectile hitting an enemy wall should be eaten")
	if enemy_wall.hp != Constants.WALL_HP:
		fails.append("enemy projectile damaged a same-faction building")


func _test_melee_respects_cooldown(fails: PackedStringArray) -> void:
	var world := World.new()
	var pos := Vector2(100, 100)
	var raider := _make_unit(world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, pos, Constants.RAIDER_HP)
	var player := _make_unit(world, Types.UnitKind.PLAYER, Types.Faction.PLAYER, pos, Constants.PLAYER_HP)
	if not Combat.apply_melee(raider, player):
		fails.append("first melee in range should land")
	var after_first := Constants.PLAYER_HP - Constants.RAIDER_MELEE_UNIT
	if player.hp != after_first:
		fails.append("first melee hp is %d, expected %d" % [player.hp, after_first])
	if not is_equal_approx(raider.weapon_cooldown, Constants.RAIDER_MELEE_COOLDOWN):
		fails.append("melee cooldown is %s, expected %s" % [raider.weapon_cooldown, Constants.RAIDER_MELEE_COOLDOWN])
	if Combat.apply_melee(raider, player):
		fails.append("second melee should wait for cooldown")
	if player.hp != after_first:
		fails.append("cooldown melee changed hp to %d" % player.hp)
	raider.weapon_cooldown = 0.0
	if not Combat.apply_melee(raider, player):
		fails.append("melee after waiting cooldown should land")
	var after_wait := after_first - Constants.RAIDER_MELEE_UNIT
	if player.hp != after_wait:
		fails.append("post-cooldown melee hp is %d, expected %d" % [player.hp, after_wait])


func _test_death_at_zero(fails: PackedStringArray) -> void:
	var world := World.new()
	var raider := _make_unit(
		world, Types.UnitKind.RAIDER, Types.Faction.ENEMY, Vector2(100, 100), 3
	)
	Combat.apply_damage(raider, 10)
	if raider.hp != 0:
		fails.append("overkill hp is %d, expected 0" % raider.hp)
	Combat.process_deaths(world)
	if raider.alive:
		fails.append("raider still alive after death at 0")
	if world.units.has(raider.id):
		fails.append("dead raider remained in world.units")


func _test_depot_death_spills_without_life_support(fails: PackedStringArray) -> void:
	var world := World.new()
	var sim := Sim.new()
	sim.world = world
	var scrap := 7
	var ice := 4
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Vector2i(10, 10)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Inventory.new(Constants.DEPOT_CAP_SCRAP, Constants.DEPOT_CAP_ICE)
	depot.inventory.add(Types.ResourceKind.SCRAP, scrap)
	depot.inventory.add(Types.ResourceKind.ICE, ice)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	Combat.apply_damage(depot, Constants.DEPOT_HP)
	Combat.process_deaths(world)
	if world.buildings.has(depot.id):
		fails.append("dead depot remained in world.buildings")
	if world.loot.size() != 1:
		fails.append("depot death loot piles: %d, expected 1" % world.loot.size())
		return
	var pile: Loot = world.loot.values()[0]
	if pile.inventory.scrap != scrap or pile.inventory.ice != ice:
		fails.append(
			"spilled loot is %d/%d, expected %d/%d"
			% [pile.inventory.scrap, pile.inventory.ice, scrap, ice]
		)
	var center := world.footprint_aabb(depot).get_center()
	if pile.pos != center:
		fails.append("loot pos is %s, expected depot center %s" % [pile.pos, center])
	if sim.outcome != Types.Outcome.NONE:
		fails.append("depot death set outcome %d" % sim.outcome)


func _test_two_arg_spill_rejects_ore(fails: PackedStringArray) -> void:
	var bag := Inventory.new(999, 999)
	if bag.add(Types.ResourceKind.ORE, 4) != 4 or bag.ore != 0:
		fails.append("two-arg Inventory.new(999, 999) accepted ore")
	var pile := Loot.new()
	if pile.inventory.add(Types.ResourceKind.ORE, 4) != 0 or pile.inventory.ore != 4:
		fails.append("Loot four-arg pile rejected ore")


func _test_four_arg_spill_holds_ore(fails: PackedStringArray) -> void:
	var world := World.new()
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Vector2i(10, 10)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Inventory.new(
		Constants.DEPOT_CAP_SCRAP,
		Constants.DEPOT_CAP_ICE,
		Constants.DEPOT_CAP_ORE,
		Constants.DEPOT_CAP_PARTS
	)
	depot.inventory.add(Types.ResourceKind.ORE, 6)
	depot.inventory.add(Types.ResourceKind.PARTS, 2)
	depot.inventory.add(Types.ResourceKind.FOOD, 4)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	Combat.apply_damage(depot, Constants.DEPOT_HP)
	Combat.process_deaths(world)
	if world.loot.size() != 1:
		fails.append("four-arg depot spill piles: %d, expected 1" % world.loot.size())
		return
	var pile: Loot = world.loot.values()[0]
	if pile.inventory.ore != 6 or pile.inventory.parts != 2:
		fails.append(
			"four-arg spill ore/parts %d/%d, expected 6/2" % [pile.inventory.ore, pile.inventory.parts]
		)
	if pile.inventory.food != 0:
		fails.append("four-arg spill accepted food %d" % pile.inventory.food)
	var five := Inventory.new(
		Constants.DEPOT_CAP_SCRAP,
		Constants.DEPOT_CAP_ICE,
		Constants.DEPOT_CAP_ORE,
		Constants.DEPOT_CAP_PARTS,
		Constants.DEPOT_CAP_FOOD
	)
	if five.cap_food != 0:
		fails.append("depot cap_food is %d, expected 0" % five.cap_food)
	if five.add(Types.ResourceKind.FOOD, 4) != 4 or five.food != 0:
		fails.append("five-arg depot bag accepted food")


func _test_five_kind_spill_holds_food(fails: PackedStringArray) -> void:
	var world := World.new()
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Vector2i(10, 10)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Inventory.new(
		Constants.DEPOT_CAP_SCRAP,
		Constants.DEPOT_CAP_ICE,
		Constants.DEPOT_CAP_ORE,
		Constants.DEPOT_CAP_PARTS,
		999
	)
	depot.inventory.add(Types.ResourceKind.FOOD, 7)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	Combat.apply_damage(depot, Constants.DEPOT_HP)
	Combat.process_deaths(world)
	if world.loot.size() != 1:
		fails.append("five-kind depot spill piles: %d, expected 1" % world.loot.size())
		return
	var pile: Loot = world.loot.values()[0]
	if pile.inventory.food != 7:
		fails.append("five-kind spill food is %d, expected 7" % pile.inventory.food)


func _test_player_on_gate_shot_lives(fails: PackedStringArray) -> void:
	var world := World.new()
	var tile := Vector2i(8, 8)
	var gate := _place_building(world, Types.BuildingKind.GATE, Types.Faction.PLAYER, tile, Constants.GATE_HP)
	var player := _make_unit(
		world, Types.UnitKind.PLAYER, Types.Faction.PLAYER, world.tile_center(tile.x, tile.y), Constants.PLAYER_HP
	)
	var ignore := Combat.overlapping_friendly_gate_id(world, player)
	if ignore != gate.id:
		fails.append("centered player should ignore the overlapped Gate, got %d" % ignore)
	var muzzle := player.pos + Vector2(Constants.MUZZLE_OFFSET, 0.0)
	var proj := _make_proj(Types.Faction.PLAYER, muzzle, Constants.PLAYER_PROJ_DAMAGE)
	proj.vel = Vector2(Constants.PLAYER_PROJ_SPEED, 0.0)
	proj.ignore_gate_id = ignore
	if Combat.integrate_projectile(world, proj):
		fails.append("shot from a Gate into empty ground should live after first integrate")
	if proj.ignore_gate_id != 0:
		fails.append("ignore_gate_id should clear after the first integrate")
	if gate.hp != Constants.GATE_HP:
		fails.append("friendly Gate took damage from the first-integrate shot")
	var linger := _make_proj(Types.Faction.PLAYER, muzzle, Constants.PLAYER_PROJ_DAMAGE)
	linger.vel = Vector2(40.0, 0.0)
	linger.ignore_gate_id = gate.id
	if Combat.integrate_projectile(world, linger):
		fails.append("first integrate should skip the overlapped friendly Gate")
	var eat := _make_proj(Types.Faction.PLAYER, world.footprint_aabb(gate).get_center(), Constants.PLAYER_PROJ_DAMAGE)
	if not Combat.resolve_projectile_hit(world, eat):
		fails.append("projectile hitting a player Gate should be eaten")
	if gate.hp != Constants.GATE_HP:
		fails.append("friendly Gate should eat a shot with no damage")


func _test_muzzle_in_friendly_wall_eaten(fails: PackedStringArray) -> void:
	var world := World.new()
	var gate_tile := Vector2i(8, 8)
	var wall_tile := Vector2i(9, 8)
	var gate := _place_building(world, Types.BuildingKind.GATE, Types.Faction.PLAYER, gate_tile, Constants.GATE_HP)
	var wall := _place_building(world, Types.BuildingKind.WALL, Types.Faction.PLAYER, wall_tile, Constants.WALL_HP)
	var player_pos := Vector2(float(wall_tile.x * Constants.TILE) - Constants.MUZZLE_OFFSET, world.tile_center(gate_tile.x, gate_tile.y).y)
	var player := _make_unit(world, Types.UnitKind.PLAYER, Types.Faction.PLAYER, player_pos, Constants.PLAYER_HP)
	var ignore := Combat.overlapping_friendly_gate_id(world, player)
	if ignore != gate.id:
		fails.append("offset player should still overlap the Gate, ignore=%d" % ignore)
	var muzzle := player.pos + Vector2(Constants.MUZZLE_OFFSET, 0.0)
	if world.world_to_tile(muzzle) != wall_tile:
		fails.append("muzzle should sit in the Wall tile, got %s" % world.world_to_tile(muzzle))
	var proj := _make_proj(Types.Faction.PLAYER, muzzle, Constants.PLAYER_PROJ_DAMAGE)
	proj.vel = Vector2(Constants.PLAYER_PROJ_SPEED, 0.0)
	proj.ignore_gate_id = ignore
	if not Combat.integrate_projectile(world, proj):
		fails.append("shot whose muzzle is in a friendly Wall should be eaten on first integrate")
	if wall.hp != Constants.WALL_HP:
		fails.append("friendly Wall should eat the shot with no damage")
	if gate.hp != Constants.GATE_HP:
		fails.append("friendly Gate should not take the muzzle-in-wall shot")


func _test_solid_terrain_eats_shots(fails: PackedStringArray) -> void:
	for kind in [Types.TileTerrain.CLIFF, Types.TileTerrain.CRATER]:
		var world := World.new()
		var tile := Vector2i(5, 5)
		world.set_terrain(tile.x, tile.y, kind)
		var unit := _make_unit(
			world,
			Types.UnitKind.RAIDER,
			Types.Faction.ENEMY,
			world.tile_center(8, 5),
			Constants.RAIDER_HP
		)
		var proj := _make_proj(Types.Faction.PLAYER, world.tile_center(tile.x, tile.y), Constants.PLAYER_PROJ_DAMAGE)
		if not Combat.resolve_projectile_hit(world, proj):
			fails.append("projectile should be eaten by terrain kind %d" % kind)
		if unit.hp != Constants.RAIDER_HP:
			fails.append("terrain kind %d shot damaged a unit" % kind)


func _place_building(world: World, kind: int, faction: int, tile: Vector2i, hp: int) -> Building:
	var building := Building.new()
	building.id = world.alloc_id()
	building.kind = kind
	building.faction = faction
	building.origin_tile = tile
	building.hp = hp
	building.hp_max = hp
	world.buildings[building.id] = building
	world.occupy(building)
	return building


func _make_unit(world: World, kind: int, faction: int, pos: Vector2, hp: int) -> Unit:
	var unit := Unit.new()
	unit.id = world.alloc_id()
	unit.kind = kind
	unit.faction = faction
	unit.pos = pos
	unit.hp = hp
	unit.hp_max = hp
	unit.radius = Constants.RAIDER_RADIUS
	if kind == Types.UnitKind.PLAYER:
		unit.radius = Constants.PLAYER_RADIUS
	unit.alive = true
	unit.inventory = Unit.inventory_for(kind)
	world.units[unit.id] = unit
	return unit


func _make_proj(faction: int, pos: Vector2, damage: int) -> Projectile:
	var proj := Projectile.new()
	proj.faction = faction
	proj.pos = pos
	proj.damage = damage
	proj.life = Constants.PLAYER_PROJ_LIFE
	return proj
