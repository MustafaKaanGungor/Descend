extends Node

@export_group("Blend")
## How quickly hook hold and swing poses blend in and out.
@export var blend_speed: float = 10.0

@export_group("Camera Feel")
## Extra FOV added while swinging fast.
@export var swing_fov_bonus: float = 8.0
## Camera roll while swinging sideways.
@export var swing_roll_degrees: float = 5.0
## Swing speed where FOV and roll reach full strength.
@export var swing_full_speed: float = 16.0
## Small camera position impulse when throwing.
@export var throw_camera_position_impulse: Vector3 = Vector3(0.0, 0.0, 0.012)
## Small camera rotation impulse when throwing.
@export var throw_camera_rotation_degrees: Vector3 = Vector3(-0.6, 0.0, 0.8)
## Camera position jolt when the hook catches.
@export var catch_camera_position_impulse: Vector3 = Vector3(0.0, -0.018, 0.015)
## Camera rotation jolt when the hook catches.
@export var catch_camera_rotation_degrees: Vector3 = Vector3(-1.2, 0.0, 0.0)

@export_group("Rope Look")
## Extra rope trailing behind a flying hook, as a share of its distance. Pulls straight as the rope runs out.
@export var flight_rope_slack: float = 0.06
## Small slack on a taut rope so it still droops slightly under its own weight.
@export var taut_rope_slack: float = 0.002
## Deepest the rope can sag.
@export var max_rope_sag: float = 1.6
## Segments used to draw a sagging rope.
@export var rope_sag_segments: int = 10
## Camera tug when a thrown rope runs out and jerks taut.
@export var rope_snap_camera_rotation_degrees: Vector3 = Vector3(-0.5, 0.0, 0.4)

@export_group("Sound")
## Volume of the clank when the hook catches a ledge.
@export var catch_sound_volume_db: float = 0.0
## Random pitch change per catch, so repeated catches don't sound identical.
@export var catch_sound_pitch_variation: float = 0.08
## Random volume change per catch.
@export var catch_sound_volume_variation_db: float = 1.5

@export_group("Hand Feel")
## Right hand offset while holding the rope.
@export var hold_right_hand_position: Vector3 = Vector3(0.0, 0.07, -0.08)
## Right hand rotation while holding the rope.
@export var hold_right_hand_rotation_degrees: Vector3 = Vector3(28.0, 0.0, -8.0)
## Left hand offset while swinging; both hands grab the rope.
@export var swing_left_hand_position: Vector3 = Vector3(0.12, 0.14, -0.06)
## Left hand rotation while swinging.
@export var swing_left_hand_rotation_degrees: Vector3 = Vector3(34.0, 0.0, 10.0)


func get_blend(current_blend: float, target_blend: float, delta: float) -> float:
	return lerpf(current_blend, target_blend, 1.0 - exp(-maxf(blend_speed, 0.0) * delta))


func get_swing_fov_bonus(swing_blend: float, speed: float) -> float:
	return swing_fov_bonus * clampf(swing_blend, 0.0, 1.0) * _get_speed_ratio(speed)


func get_swing_roll(side_speed: float, swing_blend: float) -> float:
	var side_ratio: float = clampf(side_speed / maxf(swing_full_speed, 0.001), -1.0, 1.0)
	return -side_ratio * deg_to_rad(swing_roll_degrees) * clampf(swing_blend, 0.0, 1.0)


func get_throw_camera_rotation_impulse(strength: float) -> Vector3:
	return _degrees_to_radians(throw_camera_rotation_degrees) * maxf(strength, 0.0)


func get_catch_camera_rotation_impulse(strength: float) -> Vector3:
	return _degrees_to_radians(catch_camera_rotation_degrees) * maxf(strength, 0.0)


## Depth of a parabola-shaped sag whose arc is `slack` longer than the straight span.
func get_rope_sag_depth(span_length: float, slack: float) -> float:
	if span_length <= 0.001 or slack <= 0.0:
		return 0.0
	return minf(sqrt(3.0 * span_length * slack / 8.0), maxf(max_rope_sag, 0.0))


func get_rope_snap_camera_rotation_impulse(strength: float) -> Vector3:
	return _degrees_to_radians(rope_snap_camera_rotation_degrees) * maxf(strength, 0.0)


func _get_speed_ratio(speed: float) -> float:
	return clampf(speed / maxf(swing_full_speed, 0.001), 0.0, 1.0)


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees_value.x), deg_to_rad(degrees_value.y), deg_to_rad(degrees_value.z))
