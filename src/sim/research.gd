class_name Research
extends RefCounted


static func cost(kind: int) -> Dictionary:
	match kind:
		Types.TechKind.HYDROPONICS:
			return {Types.ResourceKind.ICE: Constants.TECH_HYDROPONICS_ICE}
		Types.TechKind.METALLURGY:
			return {Types.ResourceKind.ORE: Constants.TECH_METALLURGY_ORE}
		Types.TechKind.FIELD_MEDICINE:
			return {
				Types.ResourceKind.ICE: Constants.TECH_FIELD_MED_ICE,
				Types.ResourceKind.SCRAP: Constants.TECH_FIELD_MED_SCRAP,
			}
		Types.TechKind.BALLISTICS:
			return {Types.ResourceKind.PARTS: Constants.TECH_BALLISTICS_PARTS}
		_:
			return {}


static func duration(kind: int) -> float:
	match kind:
		Types.TechKind.HYDROPONICS:
			return Constants.TECH_HYDROPONICS_TIME
		Types.TechKind.METALLURGY:
			return Constants.TECH_METALLURGY_TIME
		Types.TechKind.FIELD_MEDICINE:
			return Constants.TECH_FIELD_MED_TIME
		Types.TechKind.BALLISTICS:
			return Constants.TECH_BALLISTICS_TIME
		_:
			return 0.0


static func prereq(kind: int) -> int:
	if kind == Types.TechKind.BALLISTICS:
		return Types.TechKind.METALLURGY
	return -1


static func building_unlocked(sim: Sim, building_kind: int) -> bool:
	return building_unlocked_bits(_techs_done(sim), building_kind)


static func building_unlocked_bits(techs_done: int, building_kind: int) -> bool:
	match building_kind:
		Types.BuildingKind.WALL, Types.BuildingKind.TURRET, Types.BuildingKind.WORKSHOP, Types.BuildingKind.LAB:
			return true
		Types.BuildingKind.GREENHOUSE:
			return _bit(techs_done, Types.TechKind.HYDROPONICS)
		Types.BuildingKind.GATE:
			return _bit(techs_done, Types.TechKind.METALLURGY)
		Types.BuildingKind.MEDBAY:
			return _bit(techs_done, Types.TechKind.FIELD_MEDICINE)
		_:
			return false


static func workshop_unlocked(sim: Sim) -> bool:
	return sim != null and sim.tech_complete(Types.TechKind.METALLURGY)


static func turret_range(sim: Sim, faction: int) -> float:
	if faction == Types.Faction.PLAYER and sim != null and sim.tech_complete(Types.TechKind.BALLISTICS):
		return Constants.TURRET_RANGE_UPGRADED
	return Constants.TURRET_RANGE


static func select(sim: Sim, kind: int) -> void:
	if sim == null:
		return
	if kind < Types.TechKind.HYDROPONICS or kind > Types.TechKind.BALLISTICS:
		return
	if sim.tech_complete(kind):
		return
	var need := prereq(kind)
	if need >= 0 and not sim.tech_complete(need):
		return
	if kind == sim.research_selected:
		return
	sim.research_selected = kind
	sim.research_progress = 0.0
	sim.research_paid = false


static func mark_complete(sim: Sim, kind: int) -> void:
	if sim == null or kind < Types.TechKind.HYDROPONICS or kind > Types.TechKind.BALLISTICS:
		return
	sim.techs_done |= (1 << kind)


static func _techs_done(sim: Sim) -> int:
	if sim == null:
		return 0
	return sim.techs_done


static func _bit(techs_done: int, kind: int) -> bool:
	if kind < 0:
		return false
	return (techs_done & (1 << kind)) != 0
