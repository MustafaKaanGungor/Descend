extends Node
## Player health. Hard landings hurt: the faster the player hits the ground, the more damage.
## Damage is tuned in fall heights (meters of free fall), converted from the landing speed,
## so a rope-slowed landing after a long swing doesn't count as a long fall.

signal health_changed(current_health: float, max_health: float, health_ratio: float)
signal damaged(amount: float, current_health: float)
signal died

@export_group("Health Pool")
## Maximum health; the player starts full.
@export var max_health: float = 100.0

@export_group("Fall Damage")
## Falls up to this height do no damage. A normal jump lands from about 1.4 m.
@export var safe_fall_height: float = 4.0
## Fall height that takes all of max health.
@export var lethal_fall_height: float = 24.0
## Shape of the damage ramp between the safe and lethal heights; above 1, short falls hurt
## less and long falls ramp up faster.
@export var fall_damage_curve: float = 1.35
## Hits smaller than this are ignored.
@export var min_fall_damage: float = 2.0

@export_group("Reset")
## No damage for this long after health resets (respawn, new level).
@export var invulnerable_time_after_reset: float = 0.5

var _current_health: float = 100.0
var _invulnerable_timer: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	reset_health()


func _physics_process(delta: float) -> void:
	if _invulnerable_timer > 0.0:
		_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)


func reset_health() -> void:
	_current_health = maxf(max_health, 0.0)
	_is_dead = false
	_invulnerable_timer = maxf(invulnerable_time_after_reset, 0.0)
	_emit_health_changed()


func get_health() -> float:
	return _current_health


func get_max_health() -> float:
	return maxf(max_health, 0.0)


func get_health_ratio() -> float:
	return clampf(_current_health / maxf(get_max_health(), 0.001), 0.0, 1.0)


func is_dead() -> bool:
	return _is_dead


## Free-fall height that would produce this landing speed under the player's falling gravity.
func get_fall_height_from_speed(fall_speed: float) -> float:
	var fall_gravity: float = WorldBasicRules.get_gravity() * MovementJump.player_weight * MovementJump.jump_fall_gravity_multiplier
	return (fall_speed * fall_speed) / (2.0 * maxf(fall_gravity, 0.001))


func get_fall_damage(fall_speed: float) -> float:
	var fall_height: float = get_fall_height_from_speed(absf(fall_speed))
	var safe_height: float = maxf(safe_fall_height, 0.0)
	if fall_height <= safe_height:
		return 0.0
	var damage_range: float = maxf(lethal_fall_height - safe_height, 0.001)
	var ratio: float = (fall_height - safe_height) / damage_range
	var damage: float = get_max_health() * pow(ratio, maxf(fall_damage_curve, 0.001))
	return damage if damage >= min_fall_damage else 0.0


## Applies fall damage for a landing at this vertical speed. Returns the damage dealt.
func register_landing(fall_speed: float) -> float:
	return apply_damage(get_fall_damage(fall_speed))


func apply_damage(amount: float) -> float:
	if amount <= 0.0 or _is_dead or _invulnerable_timer > 0.0:
		return 0.0

	var dealt: float = minf(amount, _current_health)
	_current_health = maxf(_current_health - amount, 0.0)
	damaged.emit(dealt, _current_health)
	_emit_health_changed()
	if _current_health <= 0.0:
		_is_dead = true
		died.emit()
	return dealt


func _emit_health_changed() -> void:
	health_changed.emit(_current_health, get_max_health(), get_health_ratio())
