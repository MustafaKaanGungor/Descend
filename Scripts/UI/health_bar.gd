extends Control
## HUD health bar driven by the HealthManager autoload.

@export_group("Nodes")
## ProgressBar node that displays current health.
@export var progress_bar_path: NodePath = NodePath("HealthProgressBar")

@export_group("Colors")
## Fill color while health is high.
@export var healthy_color: Color = Color(0.86, 0.22, 0.26, 1.0)
## Fill color while health is low.
@export var low_color: Color = Color(0.62, 0.08, 0.1, 1.0)
## Health ratio where the bar starts using the low color.
@export var low_health_ratio: float = 0.3

var _progress_bar: ProgressBar


func _ready() -> void:
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	var health_changed_callback: Callable = Callable(self, "_on_health_changed")
	if not HealthManager.health_changed.is_connected(health_changed_callback):
		HealthManager.health_changed.connect(health_changed_callback)
	_on_health_changed(HealthManager.get_health(), HealthManager.get_max_health(), HealthManager.get_health_ratio())


func _on_health_changed(current_health: float, max_health: float, health_ratio: float) -> void:
	if _progress_bar == null:
		return

	var safe_max_health: float = maxf(max_health, 0.001)
	_progress_bar.max_value = safe_max_health
	_progress_bar.value = clampf(current_health, 0.0, safe_max_health)
	var fill_style: StyleBoxFlat = _progress_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill_style == null:
		return
	var low_threshold: float = clampf(low_health_ratio, 0.001, 1.0)
	fill_style.bg_color = low_color.lerp(healthy_color, clampf(health_ratio / low_threshold, 0.0, 1.0))
