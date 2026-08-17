extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_chunk_membership_and_move(fails)
	_test_enemy_units_in_aabb(fails)
	_test_projectile_insert_remove(fails)
	_test_rebuild_after_generate(fails)
	return fails


func _test_chunk_membership_and_move(fails: PackedStringArray) -> void:
	var world := World.new()
	var a := _make_unit(world, Types.UnitKind.RAIDER, Vector2(4, 4))
	var b := _make_unit(world, Types.UnitKind.GUARD, Vector2(12 * Constants.TILE, 4))
	var c := _make_unit(world, Types.UnitKind.PLAYER, Vector2(4, 12 * Constants.TILE))
	world.spatial.insert_unit(a)
	world.spatial.insert_unit(b)
	world.spatial.insert_unit(c)
	var ca := world.spatial.chunk_of_tile(Vector2i(0, 0))
	var cb := world.spatial.chunk_of_tile(Vector2i(12, 0))
	var cc := world.spatial.chunk_of_tile(Vector2i(0, 12))
	if ca == cb or ca == cc or cb == cc:
		fails.append("fixture units should occupy three different spatial chunks")
		return
	if not _chunk_has(world.spatial, ca, a.id):
		fails.append("unit A missing from chunk %s" % str(ca))
	if not _chunk_has(world.spatial, cb, b.id):
		fails.append("unit B missing from chunk %s" % str(cb))
	if not _chunk_has(world.spatial, cc, c.id):
		fails.append("unit C missing from chunk %s" % str(cc))
	var old := world.world_to_tile(a.pos)
	a.pos = Vector2(12 * Constants.TILE + 4, 4)
	var now := world.world_to_tile(a.pos)
	world.move_unit(a, old, now)
	if _chunk_has(world.spatial, ca, a.id):
		fails.append("unit A stayed in old chunk after crossing an 8-tile boundary")
	if not _chunk_has(world.spatial, cb, a.id):
		fails.append("unit A missing from new chunk after move")


func _test_enemy_units_in_aabb(fails: PackedStringArray) -> void:
	var world := World.new()
	var inside := _make_unit(world, Types.UnitKind.RAIDER, world.tile_center(4, 4))
	var edge := _make_unit(world, Types.UnitKind.GUARD, world.tile_center(31, 31))
	var outside := _make_unit(world, Types.UnitKind.RAIDER, world.tile_center(32, 4))
	var player := _make_unit(world, Types.UnitKind.PLAYER, world.tile_center(8, 8))
	world.spatial.insert_unit(inside)
	world.spatial.insert_unit(edge)
	world.spatial.insert_unit(outside)
	world.spatial.insert_unit(player)
	var window := Rect2i(0, 0, 32, 32)
	var n := world.spatial.enemy_units_in_aabb(window)
	if n != 2:
		fails.append("enemy_units_in_aabb counted %d, expected 2 in the 32×32 window" % n)
	if world.spatial.enemy_units_in_aabb(Rect2i(32, 0, 32, 32)) != 1:
		fails.append("neighbor 32×32 window should count only the outside raider")


func _test_projectile_insert_remove(fails: PackedStringArray) -> void:
	var world := World.new()
	var proj := Projectile.new()
	proj.id = world.alloc_id()
	proj.pos = Vector2(20, 20)
	world.spatial.insert_projectile(proj)
	var c := world.spatial.chunk_of_pos(proj.pos)
	if not _proj_in_chunk(world.spatial, c, proj.id):
		fails.append("inserted projectile missing from its chunk")
	world.spatial.remove_projectile(proj)
	if _proj_in_chunk(world.spatial, c, proj.id):
		fails.append("removed projectile still listed in its chunk")


func _test_rebuild_after_generate(fails: PackedStringArray) -> void:
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	if world.spatial == null:
		fails.append("World.spatial missing after generate")
		return
	var n := 0
	for raw in world.units.values():
		var unit := raw as Unit
		if unit == null:
			continue
		var c := world.spatial.chunk_of_pos(unit.pos)
		if _chunk_has(world.spatial, c, unit.id):
			n += 1
	if n != world.units.size():
		fails.append("spatial rebuild after generate indexed %d/%d units" % [n, world.units.size()])


func _make_unit(world: World, kind: int, pos: Vector2) -> Unit:
	var unit := Unit.new()
	unit.id = world.alloc_id()
	unit.kind = kind
	unit.faction = Types.Faction.PLAYER if kind == Types.UnitKind.PLAYER else Types.Faction.ENEMY
	unit.pos = pos
	unit.hp = 10
	unit.hp_max = 10
	unit.radius = Constants.RAIDER_RADIUS
	unit.alive = true
	world.units[unit.id] = unit
	return unit


func _chunk_has(index: SpatialIndex, c: Vector2i, id: int) -> bool:
	for raw in index.units_in_chunk(c):
		var unit := raw as Unit
		if unit != null and unit.id == id:
			return true
	return false


func _proj_in_chunk(index: SpatialIndex, c: Vector2i, id: int) -> bool:
	for raw in index.projectiles_in_chunk(c):
		var proj := raw as Projectile
		if proj != null and proj.id == id:
			return true
	return false
