extends ColorRect
## Full-screen red flash when the player takes damage; bigger hits flash stronger.

@export_group("Flash")
## Flash opacity for the smallest hit.
@export var min_flash_alpha: float = 0.12
## Flash opacity for a hit that takes all health.
@export var max_flash_alpha: float = 0.55
## Seconds the flash takes to fade out.
@export var fade_time: float = 0.6

var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_alpha(0.0)
	var damaged_callback: Callable = Callable(self, "_on_damaged")
	if not HealthManager.damaged.is_connected(damaged_callback):
		HealthManager.damaged.connect(damaged_callback)


func _process(delta: float) -> void:
	if _alpha <= 0.0:
		return
	_set_alpha(maxf(_alpha - (max_flash_alpha / maxf(fade_time, 0.01)) * delta, 0.0))


func _on_damaged(amount: float, _current_health: float) -> void:
	var hit_ratio: float = clampf(amount / maxf(HealthManager.get_max_health(), 0.001), 0.0, 1.0)
	_set_alpha(maxf(_alpha, lerpf(min_flash_alpha, max_flash_alpha, hit_ratio)))


func _set_alpha(alpha: float) -> void:
	_alpha = alpha
	color.a = alpha
	visible = alpha > 0.0
