class_name Session
extends RefCounted

func start(_seed: int) -> void:
	pass


func submit_command(_cmd: InputCommand) -> void:
	pass


func set_paused(_p: bool) -> void:
	pass


func tick(_real_delta: float) -> void:
	pass


func get_snapshot() -> SimSnapshot:
	return SimSnapshot.new()


func get_outcome() -> int:
	return Types.Outcome.NONE


func get_outcome_reason() -> int:
	return Types.OutcomeReason.NONE
