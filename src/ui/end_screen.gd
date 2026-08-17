class_name EndScreen
extends Control

const TEXT := Color("F2EDE6")
const FONT_SIZE := 16
const TITLE_WIN := "Colony standing"
const TITLE_LOSE := "Colony lost"

signal play_again
signal menu

var _title: Label
var _reason: Label


func _ready() -> void:
	if theme == null:
		theme = preload("res://assets/theme/default.tres")
	_bind_nodes()
	_style_labels()
	var play_again_btn := get_node_or_null("Center/VBox/PlayAgain") as Button
	var menu_btn := get_node_or_null("Center/VBox/Menu") as Button
	if play_again_btn != null and not play_again_btn.pressed.is_connected(_on_play_again):
		play_again_btn.pressed.connect(_on_play_again)
	if menu_btn != null and not menu_btn.pressed.is_connected(_on_menu):
		menu_btn.pressed.connect(_on_menu)


func set_outcome(outcome: int, reason: int) -> void:
	if not _bind_nodes():
		return
	if outcome == Types.Outcome.PLAYER_WIN:
		_title.text = TITLE_WIN
	elif outcome == Types.Outcome.PLAYER_LOSE:
		_title.text = TITLE_LOSE
	else:
		_title.text = ""
	_reason.text = _reason_line(outcome, reason)


func _reason_line(outcome: int, reason: int) -> String:
	if outcome == Types.Outcome.PLAYER_WIN and reason == Types.OutcomeReason.HABITAT_DESTROYED:
		return "Enemy habitat destroyed"
	if outcome == Types.Outcome.PLAYER_WIN and reason == Types.OutcomeReason.LIFE_SUPPORT:
		return "Enemy life support failed"
	if outcome == Types.Outcome.PLAYER_LOSE and reason == Types.OutcomeReason.HABITAT_DESTROYED:
		return "Habitat destroyed"
	if outcome == Types.Outcome.PLAYER_LOSE and reason == Types.OutcomeReason.LIFE_SUPPORT:
		return "Life support failed"
	return ""


func _on_play_again() -> void:
	play_again.emit()


func _on_menu() -> void:
	menu.emit()


func _bind_nodes() -> bool:
	if _title != null and _reason != null:
		return true
	_title = get_node_or_null("Center/VBox/Title") as Label
	_reason = get_node_or_null("Center/VBox/Reason") as Label
	return _title != null and _reason != null


func _style_labels() -> void:
	for node in [_title, _reason]:
		if node == null:
			continue
		node.add_theme_color_override("font_color", TEXT)
		node.add_theme_font_size_override("font_size", FONT_SIZE)
