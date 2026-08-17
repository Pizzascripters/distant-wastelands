class_name SimSnapshot
extends RefCounted

var tick: int = 0
var time: float = 0.0
var outcome: int = Types.Outcome.NONE
var outcome_reason: int = Types.OutcomeReason.NONE
var tiles: PackedByteArray = PackedByteArray()
var tiles_generation: int = 0
var units: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var deposits: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var next_wave_at: float = 0.0
var wave_index: int = 0
var banner_timer: float = 0.0
var player_respawn_timer: float = 0.0
var player_zero_ice_timer: float = 0.0
var enemy_zero_ice_timer: float = 0.0
var player_living_depot_ice_empty: bool = false
var enemy_living_depot_ice_empty: bool = false
var gather_deposit_id: int = 0
var gather_progress: float = 0.0
var player_o2: float = Constants.PLAYER_O2_MAX
var player_o2_max: float = Constants.PLAYER_O2_MAX
var research_selected: int = -1
var research_progress: float = 0.0
var research_paid: bool = false
var techs_done: int = 0
var oxygen_failed: bool = false
var hunger_starving: bool = false
var sim_ms: float = 0.0
var view_ms: float = 0.0
var completed_this_tick: int = 0
