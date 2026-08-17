class_name SpatialIndex
extends RefCounted

## 8×8 tile buckets for units, projectiles, deposits, and loot.

var _unit_chunk: Dictionary = {}
var _units: Dictionary = {}
var _proj_chunk: Dictionary = {}
var _projectiles: Dictionary = {}
var _deposit_chunk: Dictionary = {}
var _deposits: Dictionary = {}
var _loot_chunk: Dictionary = {}
var _loot: Dictionary = {}
var max_unit_radius: float = 0.0


func indexed_unit_ids() -> int:
	return _unit_chunk.size()


func chunk_n() -> int:
	return int(Constants.MAP_W / Constants.SPATIAL_CHUNK_TILES)


func chunk_of_tile(tile: Vector2i) -> Vector2i:
	var n := Constants.SPATIAL_CHUNK_TILES
	return Vector2i(int(floor(float(tile.x) / float(n))), int(floor(float(tile.y) / float(n))))


func chunk_of_pos(pos: Vector2) -> Vector2i:
	var tile := Vector2i(
		int(floor(pos.x / float(Constants.TILE))),
		int(floor(pos.y / float(Constants.TILE)))
	)
	return chunk_of_tile(tile)


func chunk_index(c: Vector2i) -> int:
	var n := chunk_n()
	return c.y * n + c.x


func rebuild(world: World) -> void:
	clear()
	if world == null:
		return
	rebuild_units(world)
	for raw in world.projectiles.values():
		var proj := raw as Projectile
		if proj != null:
			insert_projectile(proj)
	for raw in world.deposits.values():
		var deposit := raw as Deposit
		if deposit != null:
			insert_deposit(deposit)
	for raw in world.loot.values():
		var pile := raw as Loot
		if pile != null:
			insert_loot(pile)


func rebuild_units(world: World) -> void:
	_unit_chunk.clear()
	_units.clear()
	max_unit_radius = 0.0
	if world == null:
		return
	for raw in world.units.values():
		var unit := raw as Unit
		if unit != null and unit.alive:
			insert_unit(unit)


func clear() -> void:
	_unit_chunk.clear()
	_units.clear()
	_proj_chunk.clear()
	_projectiles.clear()
	_deposit_chunk.clear()
	_deposits.clear()
	_loot_chunk.clear()
	_loot.clear()
	max_unit_radius = 0.0


func insert_unit(unit: Unit) -> void:
	if unit == null:
		return
	_insert(_unit_chunk, _units, unit.id, chunk_of_pos(unit.pos), unit)
	if unit.radius > max_unit_radius:
		max_unit_radius = unit.radius


func remove_unit(unit: Unit) -> void:
	if unit == null:
		return
	_remove(_unit_chunk, _units, unit.id)


func move_unit(unit: Unit, old_tile: Vector2i, new_tile: Vector2i) -> void:
	if unit == null or old_tile == new_tile:
		return
	var old_c := chunk_of_tile(old_tile)
	var new_c := chunk_of_tile(new_tile)
	if old_c == new_c:
		return
	_remove(_unit_chunk, _units, unit.id)
	_insert(_unit_chunk, _units, unit.id, new_c, unit)


func units_in_chunk(c: Vector2i) -> Array:
	return _bucket(_units, c)


func units_near_tile(tile: Vector2i, chebyshev: int) -> Array:
	var out: Array = []
	var seen := {}
	var min_t := Vector2i(tile.x - chebyshev, tile.y - chebyshev)
	var max_t := Vector2i(tile.x + chebyshev, tile.y + chebyshev)
	var c0 := chunk_of_tile(min_t)
	var c1 := chunk_of_tile(max_t)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			for raw in units_in_chunk(Vector2i(cx, cy)):
				var unit := raw as Unit
				if unit == null or seen.has(unit.id):
					continue
				seen[unit.id] = true
				var ut := Vector2i(
					int(floor(unit.pos.x / float(Constants.TILE))),
					int(floor(unit.pos.y / float(Constants.TILE)))
				)
				if maxi(absi(ut.x - tile.x), absi(ut.y - tile.y)) <= chebyshev:
					out.append(unit)
	return out


func enemy_units_in_aabb(rect: Rect2i) -> int:
	var n := 0
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0
	var min_t := rect.position
	var max_t := rect.position + rect.size - Vector2i(1, 1)
	var c0 := chunk_of_tile(min_t)
	var c1 := chunk_of_tile(max_t)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			for raw in units_in_chunk(Vector2i(cx, cy)):
				var unit := raw as Unit
				if unit == null or not unit.alive:
					continue
				if unit.faction != Types.Faction.ENEMY:
					continue
				if unit.kind != Types.UnitKind.RAIDER and unit.kind != Types.UnitKind.GUARD:
					continue
				var t := Vector2i(
					int(floor(unit.pos.x / float(Constants.TILE))),
					int(floor(unit.pos.y / float(Constants.TILE)))
				)
				if t.x < rect.position.x or t.y < rect.position.y:
					continue
				if t.x >= rect.position.x + rect.size.x or t.y >= rect.position.y + rect.size.y:
					continue
				n += 1
	return n


func insert_projectile(proj: Projectile) -> void:
	if proj == null:
		return
	_insert(_proj_chunk, _projectiles, proj.id, chunk_of_pos(proj.pos), proj)


func remove_projectile(proj: Projectile) -> void:
	if proj == null:
		return
	_remove(_proj_chunk, _projectiles, proj.id)


func projectiles_in_chunk(c: Vector2i) -> Array:
	return _bucket(_projectiles, c)


func insert_deposit(deposit: Deposit) -> void:
	if deposit == null:
		return
	_insert(_deposit_chunk, _deposits, deposit.id, chunk_of_tile(deposit.tile), deposit)


func remove_deposit(deposit: Deposit) -> void:
	if deposit == null:
		return
	_remove(_deposit_chunk, _deposits, deposit.id)


func insert_loot(pile: Loot) -> void:
	if pile == null:
		return
	_insert(_loot_chunk, _loot, pile.id, chunk_of_pos(pile.pos), pile)


func remove_loot(pile: Loot) -> void:
	if pile == null:
		return
	_remove(_loot_chunk, _loot, pile.id)


func _insert(id_to_chunk: Dictionary, buckets: Dictionary, id: int, c: Vector2i, item: Variant) -> void:
	if id_to_chunk.has(id):
		_remove(id_to_chunk, buckets, id)
	var key := chunk_index(c)
	id_to_chunk[id] = key
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(item)


func _remove(id_to_chunk: Dictionary, buckets: Dictionary, id: int) -> void:
	if not id_to_chunk.has(id):
		return
	var key: int = int(id_to_chunk[id])
	id_to_chunk.erase(id)
	var bucket: Variant = buckets.get(key)
	if not bucket is Array:
		return
	var items: Array = bucket
	for i in range(items.size() - 1, -1, -1):
		var item: Variant = items[i]
		if item != null and int(item.id) == id:
			items.remove_at(i)
			break
	if items.is_empty():
		buckets.erase(key)


func _bucket(buckets: Dictionary, c: Vector2i) -> Array:
	var n := chunk_n()
	if c.x < 0 or c.y < 0 or c.x >= n or c.y >= n:
		return []
	var bucket: Variant = buckets.get(chunk_index(c))
	if bucket is Array:
		return bucket
	return []
