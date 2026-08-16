class_name SimSnapshot
extends RefCounted

var tick: int = 0
var time: float = 0.0
var outcome: int = Types.Outcome.NONE
var outcome_reason: int = Types.OutcomeReason.NONE
var tiles: PackedByteArray = PackedByteArray()
var units: Array[Dictionary] = []
