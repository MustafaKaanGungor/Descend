extends Control
## HUD bar for the grappling rope: how much rope is out right now and how much is left.

const METHOD_GET_ROPE_USED_LENGTH: StringName = &"get_rope_used_length"
const METHOD_GET_ROPE_MAX_LENGTH: StringName = &"get_rope_max_length"

@export_group("Nodes")
## ProgressBar node that displays the rope in use.
@export var progress_bar_path: NodePath = NodePath("RopeProgressBar")
## Label that shows used and total rope in meters.
@export var label_path: NodePath = NodePath("Label")
## Optional player path; if empty or missing, the bar searches the scene for the player.
@export var player_path: NodePath = NodePath("")

@export_group("Colors")
## Fill color while plenty of rope is left.
@export var plenty_color: Color = Color(0.86, 0.69, 0.43, 1.0)
## Fill color as the rope runs low.
@export var low_color: Color = Color(0.95, 0.55, 0.18, 1.0)
## Fill color when all the rope is out.
@export var out_color: Color = Color(0.95, 0.18, 0.13, 1.0)
## Share of rope left where the bar starts warning.
@export var low_remaining_ratio: float = 0.25

var _progress_bar: ProgressBar
var _label: Label
var _player: Node
var _player_search_timer: float = 0.0


func _ready() -> void:
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	_label = get_node_or_null(label_path) as Label
	_set_bar_values(0.0, 18.0)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player_search_timer -= delta
		if _player_search_timer > 0.0:
			return
		_player_search_timer = 0.5
		_resolve_player()
		if _player == null:
			return

	_set_bar_values(
		float(_player.call(METHOD_GET_ROPE_USED_LENGTH)),
		float(_player.call(METHOD_GET_ROPE_MAX_LENGTH))
	)


func _resolve_player() -> void:
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
		if _player != null and _player.has_method(METHOD_GET_ROPE_USED_LENGTH):
			return

	var search_root: Node = get_tree().current_scene
	if search_root == null:
		search_root = get_tree().root
	_player = _find_player(search_root)


func _find_player(search_node: Node) -> Node:
	if search_node is CharacterBody3D and search_node.has_method(METHOD_GET_ROPE_USED_LENGTH):
		return search_node
	for child in search_node.get_children():
		var found_player: Node = _find_player(child)
		if found_player != null:
			return found_player
	return null


func _set_bar_values(used_length: float, max_length: float) -> void:
	var safe_max_length: float = maxf(max_length, 0.001)
	var clean_used_length: float = clampf(used_length, 0.0, safe_max_length)
	if _progress_bar != null:
		_progress_bar.max_value = safe_max_length
		_progress_bar.value = clean_used_length
		_update_fill_color(1.0 - clean_used_length / safe_max_length)
	if _label != null:
		_label.text = "Rope %.1f / %.0f m" % [clean_used_length, safe_max_length]


func _update_fill_color(remaining_ratio: float) -> void:
	var fill_style: StyleBoxFlat = _progress_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill_style == null:
		return

	var low_threshold: float = clampf(low_remaining_ratio, 0.001, 1.0)
	if remaining_ratio <= 0.001:
		fill_style.bg_color = out_color
	elif remaining_ratio < low_threshold:
		fill_style.bg_color = out_color.lerp(low_color, remaining_ratio / low_threshold)
	else:
		fill_style.bg_color = low_color.lerp(plenty_color, (remaining_ratio - low_threshold) / maxf(1.0 - low_threshold, 0.001))
