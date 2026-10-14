extends CharacterBody3D

const FEEDBACK_MEMORY_TIME: float = 0.14
const HOOK_STATE_REELING: StringName = &"reeling"
const METHOD_HOOK_LAUNCH: StringName = &"launch"
const METHOD_HOOK_RELEASE: StringName = &"release"
const METHOD_HOOK_GET_STATE: StringName = &"get_state"
const METHOD_HOOK_SET_WRAP_POINTS: StringName = &"set_wrap_points"
const METHOD_HOOK_SET_ROPE_SLACK: StringName = &"set_rope_slack"
const METHOD_HOOK_SET_PULLING: StringName = &"set_pulling"
const METHOD_HOOK_GET_ANCHOR_WRAPS: StringName = &"get_anchor_wraps"
const METHOD_HOOK_GET_ROPE_OUT_LENGTH: StringName = &"get_rope_out_length"

@export var hook_scene: PackedScene = preload("res://Scenes/Hook/grapple_hook.tscn")

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_body: MeshInstance3D = $MeshInstance3D

var _current_body_height: float = 1.8
var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _was_on_floor: bool = false
var _ground_normal: Vector3 = Vector3.UP
var _move_input: Vector2 = Vector2.ZERO
var _wish_direction: Vector3 = Vector3.ZERO
var _target_speed: float = 0.0
var _horizontal_speed: float = 0.0
var _wants_crouch: bool = false
var _wants_sprint: bool = false
var _is_sprinting: bool = false
var _sprint_pressed_time: float = 0.0
var _is_crouching: bool = false
var _is_forced_crouching: bool = false
var _is_sliding: bool = false
var _slide_direction: Vector3 = Vector3.ZERO
var _slide_speed: float = 0.0
var _slide_start_speed: float = 0.0
var _slide_timer: float = 0.0
var _slide_blend: float = 0.0
var _landing_impact: float = 0.0
var _jump_feedback: float = 0.0
var _crouch_enter_feedback: float = 0.0
var _crouch_exit_feedback: float = 0.0
var _recent_landing_impact: float = 0.0
var _recent_landing_strength: float = 0.0
var _recent_landing_timer: float = 0.0
var _airborne_highest_y: float = 0.0
var _recent_landing_drop_height: float = 0.0
var _recent_landing_drop_timer: float = 0.0
var _recent_jump_feedback: float = 0.0
var _recent_jump_strength: float = 0.0
var _recent_jump_timer: float = 0.0
var _recent_crouch_feedback: float = 0.0
var _recent_crouch_strength: float = 0.0
var _recent_crouch_timer: float = 0.0
var _jump_hold_timer: float = 0.0
var _jump_hold_active: bool = false
var _step_view_offset: float = 0.0
var _stair_blend: float = 0.0
var _stair_hold_timer: float = 0.0
var _stair_step_cooldown_timer: float = 0.0
var _stair_step_feedback: float = 0.0
var _recent_stair_step: float = 0.0
var _recent_stair_strength: float = 0.0
var _recent_stair_timer: float = 0.0
var _recent_stair_feedback_duration: float = 0.0
var _time_since_floor: float = 0.0
var _edge_help_cooldown_timer: float = 0.0
var _recent_jump_momentum_speed: float = 0.0
var _recent_jump_momentum_direction: Vector3 = Vector3.ZERO
var _recent_jump_momentum_timer: float = 0.0
var _combo_speed_bonus: float = 0.0
var _combo_speed_timer: float = 0.0
var _is_climbing: bool = false
var _climb_direction: Vector3 = Vector3.ZERO
var _climb_wall_normal: Vector3 = Vector3.ZERO
var _climb_timer: float = 0.0
var _climb_duration: float = 0.0
var _climb_blend: float = 0.0
var _climb_entry_horizontal_speed: float = 0.0
var _climb_cooldown_timer: float = 0.0
var _climb_start_head_y: float = 0.0
var _climb_feedback: float = 0.0
var _climb_started_from_wall_run: bool = false
var _is_edge_pulling_over: bool = false
var _edge_pull_feedback_active: bool = false
var _edge_pull_start_position: Vector3 = Vector3.ZERO
var _edge_pull_target_position: Vector3 = Vector3.ZERO
var _edge_pull_direction: Vector3 = Vector3.ZERO
var _edge_pull_floor_normal: Vector3 = Vector3.UP
var _edge_pull_timer: float = 0.0
var _edge_pull_duration: float = 0.0
var _edge_pull_strength: float = 0.0
var _edge_pull_entry_horizontal_speed: float = 0.0
var _is_edge_holding: bool = false
var _edge_hold_position: Vector3 = Vector3.ZERO
var _edge_hold_wall_normal: Vector3 = Vector3.ZERO
var _edge_hold_direction: Vector3 = Vector3.ZERO
var _edge_hold_side_direction: Vector3 = Vector3.ZERO
var _edge_hold_floor_normal: Vector3 = Vector3.UP
var _edge_hold_pull_result: Dictionary = {}
var _edge_hold_timer: float = 0.0
var _edge_hold_lost_timer: float = 0.0
var _edge_hold_cooldown_timer: float = 0.0
var _edge_hold_blend: float = 0.0
var _edge_hold_side_input: float = 0.0
var _edge_hold_forward_released: bool = false
var _edge_hold_lift_height: float = 0.0
var _edge_hold_feedback_strength: float = 0.0
var _edge_hold_feedback_time_multiplier: float = 1.0
var _edge_hold_entry_horizontal_speed: float = 0.0
var _recent_climb_feedback: float = 0.0
var _recent_climb_strength: float = 0.0
var _recent_climb_timer: float = 0.0
var _recent_climb_feedback_duration: float = 0.0
var _is_wall_running: bool = false
var _is_wall_run_releasing: bool = false
var _wall_run_normal: Vector3 = Vector3.ZERO
var _wall_run_direction: Vector3 = Vector3.ZERO
var _wall_run_side: int = 0
var _wall_run_timer: float = 0.0
var _wall_run_release_timer: float = 0.0
var _wall_run_blend: float = 0.0
var _wall_run_entry_speed: float = 0.0
var _last_wall_jump_normal: Vector3 = Vector3.ZERO
var _wall_jump_lockout_timer: float = 0.0
var _wall_jump_feedback: float = 0.0
var _hook: Node3D
var _is_hook_anchored: bool = false
var _hook_anchor: Vector3 = Vector3.ZERO
var _rope_length: float = 0.0
var _hook_reel_input: float = 0.0
var _hook_cooldown_timer: float = 0.0
var _hook_rope_blocked_timer: float = 0.0
var _hook_hold_blend: float = 0.0
var _hook_swing_blend: float = 0.0
var _hook_throw_feedback: float = 0.0
var _hook_catch_feedback: float = 0.0
var _hook_snap_feedback: float = 0.0
var _hook_wrap_points: Array[Vector3] = []
var _hook_wrap_sides: Array[Vector3] = []
var _hook_wrap_fixed_length: float = 0.0
var _hook_last_clear_attach: Vector3 = Vector3.ZERO
var _has_hook_clear_attach: bool = false


func _ready() -> void:
	_sanitize_physics_transform()
	_apply_character_body_physics_settings()
	_current_body_height = MovementCrouch.standing_height
	_airborne_highest_y = global_position.y
	MovementSlide.clear_landing_drop_slide_multiplier()

	visual_body.visible = false
	_apply_body_dimensions()


func _physics_process(delta: float) -> void:
	if _needs_physics_transform_sanitize():
		_sanitize_physics_transform()

	var on_floor: bool = is_on_floor()
	var previous_crouch_feel_active: bool = _is_crouch_feel_active()
	_update_fall_height_tracking(on_floor)
	_update_recent_feedback(delta)
	_update_stair_feedback(delta)
	_update_step_view_offset(delta)
	_update_edge_help_timers(delta, on_floor)
	_update_climb_timers(delta)
	_update_edge_pull_over_feedback(delta)
	_update_momentum_timers(delta)
	_update_combo_speed(delta)
	_update_wall_jump_lockout(delta)
	InputManager.update_movement_state(delta)
	_move_input = _read_move_input()
	_wish_direction = _get_wish_direction(_move_input)
	_wants_crouch = InputManager.is_crouch_pressed()
	_wants_sprint = InputManager.wants_sprint(_move_input)
	if _wants_sprint and not StaminaManager.can_sprint():
		_cancel_stamina_sprint_request()
	_update_hook(delta, on_floor)
	_is_forced_crouching = _should_force_crouch()
	if _is_edge_pulling_over or _is_edge_holding:
		_stop_slide()
	else:
		_update_slide_state(delta, on_floor)
	_update_slide_blend(delta)
	_is_crouching = not _is_edge_pulling_over and not _is_edge_holding and (_wants_crouch or _is_forced_crouching or _is_sliding)
	_update_crouch_transition_feedback(previous_crouch_feel_active, on_floor)
	_is_sprinting = _wants_sprint and _move_input != Vector2.ZERO and not _is_crouching and not _is_edge_pulling_over and not _is_edge_holding and StaminaManager.can_sprint()
	_update_climb_state(on_floor)
	_update_climb_blend(delta)
	_update_edge_hold_blend(delta)
	if _is_edge_pulling_over or _is_edge_holding:
		_stop_wall_run()
	elif _is_climbing:
		_stop_wall_run()
	elif _is_hook_anchored:
		_stop_wall_run()
	else:
		_update_wall_run_state(delta, on_floor)
	_update_wall_run_blend(delta)
	_update_wall_run_release_state(delta, on_floor)
	_update_sprint_pressed_time(delta)
	_target_speed = _get_target_speed()

	_update_jump_timers(delta, on_floor)
	_update_crouch(delta)

	if _is_edge_pulling_over:
		_apply_edge_pull_over_movement(delta)
	elif _is_edge_holding:
		_apply_edge_hold_movement(delta)
	elif _is_climbing:
		_apply_climb_movement(delta)
	elif _is_hook_anchored and not on_floor:
		_apply_hook_swing_movement(delta)
	elif on_floor and _is_sliding:
		_apply_slide_movement(delta)
	elif _is_wall_running:
		_apply_wall_run_movement(delta)
	elif _is_wall_run_releasing:
		_apply_wall_run_release_movement(delta)
	elif on_floor:
		_apply_ground_movement(_wish_direction, _target_speed, delta)
	else:
		_apply_air_movement(_wish_direction, _target_speed, delta)

	if not _is_climbing and not _is_edge_pulling_over and not _is_edge_holding:
		_apply_vertical_motion(delta, on_floor)
	_spend_active_stamina(delta)

	var fall_speed_before_slide: float = velocity.y
	var was_climbing_before_slide: bool = _is_climbing
	var was_edge_pulling_before_slide: bool = _is_edge_pulling_over
	var was_edge_holding_before_slide: bool = _is_edge_holding
	if _is_edge_pulling_over or _is_edge_holding:
		_update_ground_contact_state(false, delta)
	else:
		_apply_hook_rope_velocity_constraint()
		move_and_slide()
		_apply_hook_rope_position_correction()
		_update_ground_contact_state(is_on_floor(), delta)
	if was_edge_pulling_before_slide:
		if _edge_pull_timer >= _edge_pull_duration:
			_finish_edge_pull_over()
	elif was_edge_holding_before_slide:
		pass
	elif was_climbing_before_slide:
		if not _try_climb_edge_help(delta) and _climb_timer >= _climb_duration:
			_finish_climb(true)
	else:
		_try_step_up(delta, on_floor)
		_try_edge_help(delta, on_floor)

	_update_landing_feedback(fall_speed_before_slide)
	_horizontal_speed = Vector2(velocity.x, velocity.z).length()
	_update_loudness(delta)
	_was_on_floor = is_on_floor() or _time_since_floor <= 0.0


func get_move_input() -> Vector2:
	return _move_input


func get_horizontal_speed() -> float:
	return _horizontal_speed


func get_current_body_height() -> float:
	return _current_body_height


func get_target_speed() -> float:
	return _target_speed


func get_wish_direction() -> Vector3:
	return _wish_direction


func is_sprinting() -> bool:
	return _is_sprinting


func get_sprint_ramp_blend() -> float:
	if not _is_sprinting:
		return 0.0
	return _get_sprint_ramp_blend()


func is_crouching() -> bool:
	return _is_crouching


func is_forced_crouching() -> bool:
	return _is_forced_crouching


func is_sliding() -> bool:
	return _is_sliding


func get_slide_blend() -> float:
	return _slide_blend


func get_slide_speed() -> float:
	return _slide_speed


func get_combo_speed_bonus() -> float:
	return _combo_speed_bonus


func get_combo_speed_blend() -> float:
	_sync_movement_run_combo_bonus()
	return MovementRun.get_combo_speed_blend()


func is_climbing() -> bool:
	return _is_climbing


func get_climb_blend() -> float:
	return maxf(_climb_blend, _edge_hold_blend)


func get_climb_progress() -> float:
	if _edge_hold_blend > _climb_blend:
		return clampf(MovementClimb.edge_hold_climb_progress, 0.0, 1.0)
	if _climb_duration <= 0.0:
		return 0.0
	return MovementClimb.get_climb_progress(_climb_timer, _climb_duration)


func is_edge_holding() -> bool:
	return _is_edge_holding


func get_edge_hold_blend() -> float:
	return _edge_hold_blend


func get_edge_hold_side_input() -> float:
	return _edge_hold_side_input


func is_edge_pulling_over() -> bool:
	return _is_edge_pulling_over


func get_edge_pull_over_blend() -> float:
	if not _edge_pull_feedback_active:
		return 0.0
	if _edge_pull_duration <= 0.0:
		return 0.0
	if _edge_pull_timer <= _edge_pull_duration:
		return 1.0

	var finish_duration: float = maxf(ClimbFeel.climb_edge_over_finish_feedback_duration, 0.001)
	var finish_progress: float = clampf((_edge_pull_timer - _edge_pull_duration) / finish_duration, 0.0, 1.0)
	var smooth_finish: float = finish_progress * finish_progress * (3.0 - (2.0 * finish_progress))
	return 1.0 - smooth_finish


func get_edge_pull_over_progress() -> float:
	return MovementClimb.get_edge_pull_over_progress(_edge_pull_timer, _edge_pull_duration)


func get_edge_pull_over_timer() -> float:
	return _edge_pull_timer


func get_edge_pull_over_duration() -> float:
	return _edge_pull_duration


func get_edge_pull_over_strength() -> float:
	return _edge_pull_strength


func is_wall_running() -> bool:
	return _is_wall_running


func is_wall_run_releasing() -> bool:
	return _is_wall_run_releasing


func get_wall_run_blend() -> float:
	return _wall_run_blend


func get_wall_run_side() -> int:
	return _wall_run_side


func consume_wall_jump_feedback() -> float:
	var feedback: float = _wall_jump_feedback
	_wall_jump_feedback = 0.0
	return feedback


func consume_climb_feedback() -> float:
	var feedback: float = _climb_feedback
	_climb_feedback = 0.0
	return feedback


func is_on_stairs() -> bool:
	return _stair_blend > 0.05


func get_step_view_offset() -> float:
	return _step_view_offset


func get_stair_blend() -> float:
	return _stair_blend


func get_recent_stair_step() -> float:
	return _recent_stair_step


func consume_landing_impact() -> float:
	var impact: float = _landing_impact
	_landing_impact = 0.0
	return impact


func consume_jump_feedback() -> float:
	var feedback: float = _jump_feedback
	_jump_feedback = 0.0
	return feedback


func consume_crouch_enter_feedback() -> float:
	var feedback: float = _crouch_enter_feedback
	_crouch_enter_feedback = 0.0
	return feedback


func consume_crouch_exit_feedback() -> float:
	var feedback: float = _crouch_exit_feedback
	_crouch_exit_feedback = 0.0
	return feedback


func consume_stair_step_feedback() -> float:
	var feedback: float = _stair_step_feedback
	_stair_step_feedback = 0.0
	return feedback


func get_recent_landing_impact() -> float:
	return _recent_landing_impact


func get_recent_jump_feedback() -> float:
	return _recent_jump_feedback


func get_recent_crouch_feedback() -> float:
	return _recent_crouch_feedback


func get_recent_climb_feedback() -> float:
	return _recent_climb_feedback


func get_vertical_velocity() -> float:
	return velocity.y


func get_ground_normal() -> Vector3:
	return _ground_normal


## Puts the player at a safe spot (fall respawn, new level) with all movement state and the hook cleared.
func respawn_at(spawn_position: Vector3, yaw: float) -> void:
	_release_hook()
	if _hook != null and is_instance_valid(_hook):
		_hook.queue_free()
		_on_hook_returned()
	_stop_slide()
	_stop_wall_run()
	_stop_climb()
	_stop_edge_hold(true)
	_is_edge_pulling_over = false
	_stop_variable_jump()
	velocity = Vector3.ZERO
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_landing_impact = 0.0
	_recent_landing_impact = 0.0
	global_transform = Transform3D(Basis(Vector3.UP, yaw), spawn_position)
	_airborne_highest_y = spawn_position.y
	reset_physics_interpolation()
	var head_node: Node = get_node_or_null("Head")
	if head_node != null and head_node.has_method(&"sync_with_player_rotation"):
		head_node.call(&"sync_with_player_rotation")


func is_hook_anchored() -> bool:
	return _is_hook_anchored


func is_hook_swinging() -> bool:
	return _is_hook_anchored and not is_on_floor()


func get_hook_hold_blend() -> float:
	return _hook_hold_blend


func get_hook_swing_blend() -> float:
	return _hook_swing_blend


func get_rope_length() -> float:
	return _rope_length


## Rope currently out: the anchored rope's full length, or what a thrown hook has paid out.
func get_rope_used_length() -> float:
	if _is_hook_anchored:
		return _rope_length
	if _hook != null and is_instance_valid(_hook):
		return float(_hook.call(METHOD_HOOK_GET_ROPE_OUT_LENGTH))
	return 0.0


func get_rope_max_length() -> float:
	return maxf(MovementHook.max_rope_length, 0.1)


func consume_hook_throw_feedback() -> float:
	var feedback: float = _hook_throw_feedback
	_hook_throw_feedback = 0.0
	return feedback


func consume_hook_catch_feedback() -> float:
	var feedback: float = _hook_catch_feedback
	_hook_catch_feedback = 0.0
	return feedback


func consume_hook_snap_feedback() -> float:
	var feedback: float = _hook_snap_feedback
	_hook_snap_feedback = 0.0
	return feedback


func _read_move_input() -> Vector2:
	return InputManager.get_move_input()


func _get_wish_direction(move_input: Vector2) -> Vector3:
	if move_input == Vector2.ZERO:
		return Vector3.ZERO

	var movement_basis: Basis = Basis(Vector3.UP, rotation.y)
	var direction: Vector3 = (movement_basis.x * move_input.x) + (movement_basis.z * move_input.y)
	direction.y = 0.0
	return direction.normalized()


func _get_target_speed() -> float:
	if _is_edge_holding:
		return 0.0
	if _is_edge_pulling_over:
		return 0.0
	if _is_climbing:
		return 0.0
	if _is_sliding:
		return maxf(_slide_speed, MovementSlide.slide_exit_speed)
	if _is_wall_running:
		_sync_wall_run_speed_context(Vector2(velocity.x, velocity.z).length())
		var wall_run_input_speed: float = MovementWalk.walk_speed
		if _is_sprinting:
			wall_run_input_speed = _get_sprint_ramp_speed()
		return MovementWallRun.get_wall_run_target_speed(wall_run_input_speed, _combo_speed_bonus)

	var target_speed: float = MovementWalk.walk_speed
	if _is_crouching:
		target_speed = MovementCrouch.crouch_speed
	elif _is_sprinting:
		target_speed = _get_sprint_ramp_speed()

	return MovementWalk.get_scaled_target_speed(target_speed, _move_input) * _get_stair_speed_multiplier()


func _spend_active_stamina(delta: float) -> void:
	if _hook_reel_input > 0.0:
		if not StaminaManager.drain_hook_reel(delta):
			_hook_reel_input = 0.0
		return

	if _is_climbing:
		if not StaminaManager.drain_climb(delta):
			_finish_climb(false)
		return

	if _is_wall_running:
		if not StaminaManager.drain_wall_run(delta):
			_stop_wall_run()
		return

	if _is_sliding:
		if not StaminaManager.drain_slide(delta):
			_stop_slide()
		return

	if _is_sprinting:
		if not StaminaManager.drain_sprint(delta):
			_cancel_stamina_sprint_request()


func _cancel_stamina_sprint_request() -> void:
	_wants_sprint = false
	_is_sprinting = false
	_sprint_pressed_time = 0.0
	InputManager.cancel_sprint_request_until_release()


func _update_loudness(delta: float) -> void:
	var climb_related: bool = _is_climbing or _is_edge_pulling_over or _is_edge_holding
	LoudnessManger.update_player_movement(
		delta,
		_horizontal_speed,
		MovementWalk.get_input_strength(_move_input),
		is_on_floor(),
		_is_sprinting,
		_is_sliding,
		_is_wall_running,
		climb_related,
		_is_crouching
	)


func _update_sprint_pressed_time(delta: float) -> void:
	if _is_sprinting:
		_sync_movement_run_combo_bonus()
		_sprint_pressed_time = minf(_sprint_pressed_time + delta, MovementRun.get_sprint_ramp_duration())
	else:
		_sprint_pressed_time = 0.0


func _get_sprint_ramp_speed() -> float:
	_sync_movement_run_combo_bonus()
	return MovementRun.get_sprint_ramp_speed(_sprint_pressed_time)


func _get_sprint_ramp_blend() -> float:
	_sync_movement_run_combo_bonus()
	return MovementRun.get_sprint_ramp_blend(_sprint_pressed_time)


func _get_sprint_speed_limit() -> float:
	_sync_movement_run_combo_bonus()
	return MovementRun.get_sprint_speed_limit()


func _apply_ground_movement(wish_direction: Vector3, target_speed: float, delta: float) -> void:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = MovementWalk.apply_ground_movement(
		horizontal_velocity,
		wish_direction,
		target_speed,
		delta,
		_ground_normal
	)
	horizontal_velocity = _apply_stair_speed_limit(horizontal_velocity, target_speed, delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _apply_air_movement(wish_direction: Vector3, target_speed: float, delta: float) -> void:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = MovementWalk.apply_air_movement(
		horizontal_velocity,
		wish_direction,
		target_speed,
		velocity.y,
		delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _update_climb_state(on_floor: bool) -> void:
	if _is_edge_holding:
		return
	if _is_edge_pulling_over:
		return

	if _is_climbing:
		if not StaminaManager.can_climb():
			_finish_climb(false)
			return
		if on_floor:
			_stop_climb()
			return
		var can_jump_from_climb: bool = MovementClimb.enable_wall_climb_jump
		can_jump_from_climb = can_jump_from_climb and _climb_timer >= MovementClimb.wall_climb_jump_lockout_time
		can_jump_from_climb = can_jump_from_climb and InputManager.is_jump_just_pressed()
		if can_jump_from_climb:
			_apply_climb_jump()
			return
		if _try_climb_edge_help(0.0):
			return
		if not _is_climb_wall_contact_valid():
			if _try_climb_edge_help(0.0):
				return
			_finish_climb(true)
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var probe_direction: Vector3 = _get_climb_probe_direction()
	if not StaminaManager.can_climb():
		return
	if not MovementClimb.can_try_climb(
		on_floor,
		_is_sliding,
		_is_crouching,
		_is_wall_running,
		probe_direction,
		horizontal_speed,
		velocity.y,
		_time_since_floor,
		_has_climb_jump_intent(),
		_climb_cooldown_timer
	):
		return

	var climb_candidate: Dictionary = {}
	if _is_wall_running:
		climb_candidate = _find_wall_run_to_climb_candidate(probe_direction, horizontal_speed)
	else:
		climb_candidate = _find_climb_candidate(probe_direction)
	if climb_candidate.is_empty():
		return

	_start_climb(climb_candidate)


func _apply_climb_movement(delta: float) -> void:
	if _climb_duration <= 0.0:
		_stop_climb()
		return

	var current_horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	velocity = MovementClimb.get_wall_climb_velocity(
		current_horizontal_velocity,
		_climb_wall_normal,
		_get_climb_probe_direction(),
		_climb_timer,
		_climb_duration,
		_climb_entry_horizontal_speed,
		delta,
		_climb_started_from_wall_run
	)
	_climb_timer = minf(_climb_timer + delta, _climb_duration)


func _apply_edge_pull_over_movement(delta: float) -> void:
	if _edge_pull_duration <= 0.0:
		_finish_edge_pull_over()
		return

	_edge_pull_timer = minf(_edge_pull_timer + delta, _edge_pull_duration)
	global_position = MovementClimb.get_edge_pull_over_position(
		_edge_pull_start_position,
		_edge_pull_target_position,
		_edge_pull_timer,
		_edge_pull_duration
	)
	velocity = Vector3.ZERO


func _apply_edge_hold_movement(delta: float) -> void:
	_edge_hold_timer += delta
	_edge_hold_side_input = MovementClimb.get_edge_hold_side_input(_move_input)
	velocity = Vector3.ZERO
	var forward_pressed: bool = InputManager.is_forward_pressed()
	if not forward_pressed:
		_edge_hold_forward_released = true

	if MovementClimb.should_edge_hold_drop(_move_input, InputManager.is_crouch_pressed()):
		_release_edge_hold()
		return

	if MovementClimb.should_edge_hold_pull_over(
		_move_input,
		_jump_buffer_timer > 0.0,
		InputManager.is_forward_just_pressed(),
		_edge_hold_forward_released,
		_edge_hold_timer
	):
		_start_edge_pull_over_from_hold()
		return

	var side_distance: float = MovementClimb.get_edge_hold_side_distance(_move_input, delta)
	var hold_result: Dictionary = {}
	if absf(side_distance) > 0.0:
		hold_result = _find_climb_edge_hold_result(_edge_hold_direction, side_distance)

	if hold_result.is_empty():
		hold_result = _find_climb_edge_hold_result(_edge_hold_direction, 0.0)

	if hold_result.is_empty():
		_edge_hold_lost_timer += delta
		if _edge_hold_lost_timer >= maxf(MovementClimb.edge_hold_lost_grace_time, 0.0):
			_release_edge_hold()
			return
	else:
		_apply_edge_hold_result(hold_result)

	var hold_blend: float = MovementClimb.get_edge_hold_position_blend(delta)
	global_position = global_position.lerp(_edge_hold_position, hold_blend)


func _start_climb(climb_candidate: Dictionary) -> void:
	_release_hook()
	var wall_normal: Vector3 = Vector3(climb_candidate.get("wall_normal", Vector3.ZERO))
	var climb_direction: Vector3 = Vector3(climb_candidate.get("climb_direction", Vector3.ZERO))
	var started_from_wall_run: bool = bool(climb_candidate.get("from_wall_run", _is_wall_running))
	var transition_wall_run_blend: float = _wall_run_blend
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if started_from_wall_run:
		horizontal_speed = maxf(horizontal_speed, _wall_run_entry_speed)

	_stop_variable_jump()
	if started_from_wall_run:
		_wall_run_blend = WallRunFeel.get_wall_run_to_climb_release_blend(_wall_run_blend)
	_stop_wall_run()
	_stop_slide()

	_is_climbing = true
	_is_sprinting = false
	_climb_direction = climb_direction
	_climb_wall_normal = MovementClimb.get_horizontal_wall_normal(wall_normal)
	_climb_timer = 0.0
	_climb_duration = MovementClimb.get_wall_climb_duration(horizontal_speed, started_from_wall_run)
	_climb_entry_horizontal_speed = horizontal_speed
	_climb_start_head_y = _get_player_head_y()
	_climb_started_from_wall_run = started_from_wall_run
	_climb_blend = maxf(_climb_blend, clampf(MovementClimb.climb_enter_blend, 0.0, 1.0))
	if started_from_wall_run:
		velocity = MovementClimb.get_wall_run_transition_velocity(velocity, _climb_wall_normal, _climb_direction)
	else:
		velocity = Vector3.ZERO
	_jump_buffer_timer = 0.0

	var feedback_strength: float = ClimbFeel.get_wall_climb_feedback_strength(horizontal_speed)
	if started_from_wall_run:
		feedback_strength = ClimbFeel.get_wall_run_to_climb_feedback_strength(horizontal_speed, transition_wall_run_blend)
	_climb_feedback = maxf(_climb_feedback, feedback_strength)
	_register_recent_climb_feedback(feedback_strength)


func _finish_climb(use_edge_release: bool = false) -> void:
	var finish_velocity: Vector3 = MovementClimb.get_wall_climb_release_velocity(_climb_wall_normal, _climb_entry_horizontal_speed)
	if use_edge_release:
		finish_velocity = MovementClimb.get_wall_climb_edge_release_velocity(_climb_direction, _climb_entry_horizontal_speed)
	_stop_climb()
	velocity = finish_velocity
	_climb_cooldown_timer = maxf(MovementClimb.cooldown_time, 0.0)


func _start_edge_hold(
	hold_result: Dictionary,
	feedback_lift_height: float,
	feedback_strength: float,
	entry_horizontal_speed: float,
	feedback_time_multiplier: float
) -> void:
	_release_hook()
	_stop_variable_jump()
	_stop_wall_run()
	_stop_slide()
	_stop_climb()

	_is_edge_holding = true
	_edge_hold_timer = 0.0
	_edge_hold_lost_timer = 0.0
	_edge_hold_blend = maxf(_edge_hold_blend, clampf(MovementClimb.edge_hold_enter_blend, 0.0, 1.0))
	_edge_hold_lift_height = feedback_lift_height
	_edge_hold_feedback_strength = maxf(feedback_strength, 0.0)
	_edge_hold_feedback_time_multiplier = maxf(feedback_time_multiplier, 0.001)
	_edge_hold_entry_horizontal_speed = maxf(entry_horizontal_speed, 0.0)
	_edge_hold_forward_released = not InputManager.is_forward_pressed()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_apply_edge_hold_result(hold_result)

	_climb_feedback = maxf(_climb_feedback, _edge_hold_feedback_strength)
	_register_recent_climb_feedback(_edge_hold_feedback_strength, _edge_hold_feedback_time_multiplier)


func _apply_edge_hold_result(hold_result: Dictionary) -> void:
	_edge_hold_lost_timer = 0.0
	_edge_hold_position = Vector3(hold_result.get("hold_position", global_position))
	_edge_hold_pull_result = {
		"position": Vector3(hold_result.get("position", global_position)),
		"lift_height": float(hold_result.get("lift_height", _edge_hold_lift_height)),
		"edge_top_y": float(hold_result.get("edge_top_y", global_position.y + _edge_hold_lift_height)),
		"floor_normal": MovementWalk.get_safe_floor_normal(Vector3(hold_result.get("floor_normal", Vector3.UP)))
	}
	_edge_hold_wall_normal = MovementClimb.get_horizontal_wall_normal(Vector3(hold_result.get("wall_normal", _edge_hold_wall_normal)))
	_edge_hold_direction = MovementClimb.get_horizontal_direction(Vector3(hold_result.get("climb_direction", _edge_hold_direction)))
	_edge_hold_side_direction = MovementClimb.get_horizontal_direction(Vector3(hold_result.get("side_direction", _edge_hold_side_direction)))
	_edge_hold_floor_normal = MovementWalk.get_safe_floor_normal(Vector3(hold_result.get("floor_normal", _edge_hold_floor_normal)))
	if _edge_hold_direction == Vector3.ZERO and _edge_hold_wall_normal != Vector3.ZERO:
		_edge_hold_direction = MovementClimb.get_climb_direction_from_wall(_edge_hold_wall_normal)
	if _edge_hold_side_direction == Vector3.ZERO and _edge_hold_wall_normal != Vector3.ZERO:
		_edge_hold_side_direction = MovementClimb.get_edge_hold_side_direction(_edge_hold_wall_normal)
	_ground_normal = _edge_hold_floor_normal


func _start_edge_pull_over_from_hold() -> void:
	if _edge_hold_pull_result.is_empty():
		_release_edge_hold()
		return

	var pull_result: Dictionary = _edge_hold_pull_result.duplicate()
	var feedback_lift_height: float = _edge_hold_lift_height
	var feedback_strength: float = _edge_hold_feedback_strength
	var entry_horizontal_speed: float = _edge_hold_entry_horizontal_speed
	var feedback_time_multiplier: float = _edge_hold_feedback_time_multiplier
	_stop_edge_hold(false)
	_edge_hold_cooldown_timer = maxf(MovementClimb.edge_hold_cooldown_time, 0.0)
	_start_edge_pull_over(
		pull_result,
		feedback_lift_height,
		feedback_strength,
		entry_horizontal_speed,
		MovementEdgeHelp.climb_edge_cooldown_time,
		feedback_time_multiplier
	)


func _release_edge_hold() -> void:
	var release_velocity: Vector3 = MovementClimb.get_edge_hold_release_velocity(_edge_hold_wall_normal)
	_stop_edge_hold()
	velocity = release_velocity
	_climb_cooldown_timer = maxf(MovementClimb.cooldown_time, 0.0)
	_edge_help_cooldown_timer = maxf(MovementEdgeHelp.climb_edge_cooldown_time, 0.0)
	_edge_hold_cooldown_timer = maxf(MovementClimb.edge_hold_cooldown_time, 0.0)


func _stop_edge_hold(reset_blend: bool = false) -> void:
	_is_edge_holding = false
	_edge_hold_position = Vector3.ZERO
	_edge_hold_wall_normal = Vector3.ZERO
	_edge_hold_direction = Vector3.ZERO
	_edge_hold_side_direction = Vector3.ZERO
	_edge_hold_floor_normal = Vector3.UP
	_edge_hold_pull_result = {}
	_edge_hold_timer = 0.0
	_edge_hold_lost_timer = 0.0
	_edge_hold_side_input = 0.0
	_edge_hold_forward_released = false
	_edge_hold_lift_height = 0.0
	_edge_hold_feedback_strength = 0.0
	_edge_hold_feedback_time_multiplier = 1.0
	_edge_hold_entry_horizontal_speed = 0.0
	if reset_blend:
		_edge_hold_blend = 0.0


func _start_edge_pull_over(
	edge_result: Dictionary,
	feedback_lift_height: float,
	feedback_strength: float,
	entry_horizontal_speed: float,
	cooldown_time: float,
	feedback_time_multiplier: float
) -> void:
	_release_hook()
	var proposed_position: Vector3 = Vector3(edge_result.get("position", global_position))
	var edge_floor_normal: Vector3 = _ground_normal
	if edge_result.has("floor_normal"):
		edge_floor_normal = MovementWalk.get_safe_floor_normal(Vector3(edge_result["floor_normal"]))

	var pull_direction: Vector3 = Vector3(
		proposed_position.x - global_position.x,
		0.0,
		proposed_position.z - global_position.z
	)
	if pull_direction.length_squared() <= 0.001:
		pull_direction = _climb_direction
	if pull_direction.length_squared() > 0.001:
		pull_direction = pull_direction.normalized()

	_stop_variable_jump()
	_stop_wall_run()
	_stop_slide()
	_stop_climb()
	_stop_edge_hold(false)

	_is_edge_pulling_over = true
	_edge_pull_feedback_active = true
	_edge_pull_start_position = global_position
	_edge_pull_target_position = proposed_position
	_edge_pull_direction = pull_direction
	_edge_pull_floor_normal = edge_floor_normal
	_edge_pull_timer = 0.0
	_edge_pull_duration = MovementClimb.get_edge_pull_over_duration(feedback_lift_height, entry_horizontal_speed)
	_edge_pull_strength = maxf(feedback_strength, 0.0)
	_edge_pull_entry_horizontal_speed = maxf(entry_horizontal_speed, 0.0)
	_ground_normal = edge_floor_normal
	velocity = Vector3.ZERO
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_edge_help_cooldown_timer = maxf(cooldown_time, 0.0)

	_climb_feedback = maxf(_climb_feedback, _edge_pull_strength)
	_register_recent_climb_feedback(_edge_pull_strength, feedback_time_multiplier)


func _finish_edge_pull_over() -> void:
	global_position = _edge_pull_target_position
	_ground_normal = _edge_pull_floor_normal
	velocity = MovementClimb.get_edge_pull_over_finish_velocity(_edge_pull_direction, _edge_pull_entry_horizontal_speed)
	_is_edge_pulling_over = false
	_time_since_floor = 0.0
	_coyote_timer = MovementJump.coyote_time
	_climb_cooldown_timer = maxf(MovementClimb.cooldown_time, 0.0)
	_edge_hold_cooldown_timer = maxf(MovementClimb.edge_hold_cooldown_time, 0.0)


func _apply_climb_jump() -> void:
	var previous_wall_normal: Vector3 = _climb_wall_normal
	var previous_wall_side: int = MovementWallRun.get_wall_side(previous_wall_normal, rotation.y)
	velocity = MovementClimb.get_wall_climb_jump_velocity(
		velocity,
		previous_wall_normal,
		_wish_direction,
		_climb_entry_horizontal_speed
	)

	_stop_climb()
	_last_wall_jump_normal = previous_wall_normal
	_wall_jump_lockout_timer = maxf(MovementWallRun.same_wall_reattach_lockout, 0.0)
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_start_variable_jump(false)
	_register_jump_momentum()

	var feedback_strength: float = maxf(WallRunFeel.wall_jump_feedback_multiplier, 0.0) * 0.85
	_jump_feedback = maxf(_jump_feedback, feedback_strength)
	_recent_jump_feedback = maxf(_recent_jump_feedback, feedback_strength)
	_recent_jump_strength = maxf(_recent_jump_strength, feedback_strength)
	_recent_jump_timer = FEEDBACK_MEMORY_TIME
	var signed_wall_feedback: float = feedback_strength * float(previous_wall_side)
	if absf(signed_wall_feedback) > absf(_wall_jump_feedback):
		_wall_jump_feedback = signed_wall_feedback


func _stop_climb() -> void:
	_is_climbing = false
	_climb_direction = Vector3.ZERO
	_climb_wall_normal = Vector3.ZERO
	_climb_timer = 0.0
	_climb_duration = 0.0
	_climb_entry_horizontal_speed = 0.0
	_climb_start_head_y = 0.0
	_climb_started_from_wall_run = false


func _update_climb_blend(delta: float) -> void:
	_climb_blend = MovementClimb.get_climb_blend(_climb_blend, _is_climbing, delta)


func _update_edge_hold_blend(delta: float) -> void:
	_edge_hold_blend = MovementClimb.get_edge_hold_blend(_edge_hold_blend, _is_edge_holding, delta)


func _find_climb_candidate(probe_direction: Vector3) -> Dictionary:
	if probe_direction == Vector3.ZERO:
		return {}

	var wall_hit: Dictionary = _find_climb_wall_hit(probe_direction, MovementClimb.wall_check_distance)
	if wall_hit.is_empty():
		return {}

	var wall_normal: Vector3 = _get_climb_hit_normal(wall_hit)
	var climb_direction: Vector3 = MovementClimb.get_climb_direction_from_wall(wall_normal)
	if climb_direction == Vector3.ZERO:
		return {}

	return {
		"wall_normal": wall_normal,
		"climb_direction": climb_direction
	}


func _find_wall_run_to_climb_candidate(probe_direction: Vector3, horizontal_speed: float) -> Dictionary:
	if probe_direction == Vector3.ZERO:
		return {}

	var probe_distance: float = MovementClimb.wall_check_distance
	probe_distance += maxf(MovementWallRun.wall_run_to_climb_extra_probe_distance, 0.0)
	var wall_hit: Dictionary = _find_climb_wall_hit(probe_direction, probe_distance)
	if wall_hit.is_empty():
		return {}

	var wall_normal: Vector3 = _get_climb_hit_normal(wall_hit)
	if not MovementWallRun.can_transition_to_front_climb(
		_wall_run_timer,
		horizontal_speed,
		_get_player_forward_direction(),
		_move_input,
		wall_normal
	):
		return {}

	var climb_direction: Vector3 = MovementClimb.get_climb_direction_from_wall(wall_normal)
	if climb_direction == Vector3.ZERO:
		return {}

	return {
		"wall_normal": wall_normal,
		"climb_direction": climb_direction,
		"from_wall_run": true
	}


func _has_climb_jump_intent() -> bool:
	return InputManager.is_jump_pressed() or _jump_hold_active or _recent_jump_timer > 0.0


func _find_climb_wall_hit(ray_direction: Vector3, ray_distance: float) -> Dictionary:
	if ray_direction == Vector3.ZERO:
		return {}

	var lower_height: float = minf(_current_body_height * 0.62, MovementClimb.wall_check_height)
	var upper_height: float = minf(_current_body_height * 0.86, MovementClimb.wall_upper_check_height)
	var lower_hit: Dictionary = _raycast_climb(global_position + Vector3.UP * lower_height, ray_direction, ray_distance)
	if _is_climb_wall_hit_valid(lower_hit, ray_direction):
		return lower_hit

	var upper_hit: Dictionary = _raycast_climb(global_position + Vector3.UP * upper_height, ray_direction, ray_distance)
	if _is_climb_wall_hit_valid(upper_hit, ray_direction):
		return upper_hit

	return {}


func _is_climb_wall_hit_valid(wall_hit: Dictionary, probe_direction: Vector3) -> bool:
	if wall_hit.is_empty():
		return false

	var wall_normal: Vector3 = _get_climb_hit_normal(wall_hit)
	return MovementClimb.is_valid_front_climb_hit(probe_direction, _get_player_forward_direction(), wall_normal)


func _is_climb_wall_contact_valid() -> bool:
	if _climb_direction == Vector3.ZERO:
		return false

	var wall_hit: Dictionary = _find_climb_wall_hit(_climb_direction, MovementClimb.wall_release_distance)
	if wall_hit.is_empty():
		return false

	var wall_normal: Vector3 = _get_climb_hit_normal(wall_hit)
	var climb_direction: Vector3 = MovementClimb.get_climb_direction_from_wall(wall_normal)
	if climb_direction == Vector3.ZERO:
		return false

	_climb_wall_normal = MovementClimb.get_horizontal_wall_normal(wall_normal)
	_climb_direction = climb_direction
	return true


func _get_climb_probe_direction() -> Vector3:
	return MovementClimb.get_front_climb_probe_direction(_get_player_forward_direction(), _wish_direction)


func _get_player_forward_direction() -> Vector3:
	var forward_direction: Vector3 = -Basis(Vector3.UP, rotation.y).z
	forward_direction.y = 0.0
	if forward_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return forward_direction.normalized()


func _get_player_head_y() -> float:
	return global_position.y + _current_body_height


func _get_climb_edge_reference_head_y() -> float:
	if _climb_start_head_y > 0.0:
		return _climb_start_head_y
	return _get_player_head_y()


func _is_climb_edge_result_high_enough(edge_result: Dictionary) -> bool:
	var edge_top_y: float = float(edge_result.get("edge_top_y", edge_result.get("lift_height", 0.0) + global_position.y))
	return MovementClimb.is_climb_edge_top_high_enough(edge_top_y, _get_climb_edge_reference_head_y())


func _raycast_climb(ray_from: Vector3, ray_direction: Vector3, ray_distance: float) -> Dictionary:
	if ray_direction == Vector3.ZERO:
		return {}

	var ray_to: Vector3 = ray_from + ray_direction.normalized() * maxf(ray_distance, 0.0)
	return _raycast_climb_segment(ray_from, ray_to)


func _raycast_climb_segment(ray_from: Vector3, ray_to: Vector3) -> Dictionary:
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, collision_mask)
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	var excluded_bodies: Array[RID] = [get_rid()]
	ray_query.exclude = excluded_bodies
	return get_world_3d().direct_space_state.intersect_ray(ray_query)


## top_probe_height overrides how high above the feet a ledge top can be (the rope uses a longer reach).
func _find_climb_edge_hold_result(forward_direction: Vector3, side_offset: float, top_probe_height: float = -1.0) -> Dictionary:
	var probe_height: float = MovementClimb.edge_hold_top_probe_height if top_probe_height < 0.0 else top_probe_height
	var clean_forward: Vector3 = MovementClimb.get_horizontal_direction(forward_direction)
	if clean_forward == Vector3.ZERO:
		return {}

	var side_direction: Vector3 = _edge_hold_side_direction
	if side_direction == Vector3.ZERO:
		side_direction = MovementClimb.get_edge_hold_side_direction(_edge_hold_wall_normal)
	if side_direction == Vector3.ZERO:
		side_direction = MovementClimb.get_edge_hold_side_direction(_climb_wall_normal)
	if side_direction == Vector3.ZERO:
		side_direction = MovementClimb.get_edge_hold_side_direction(-clean_forward)
	if side_direction == Vector3.ZERO:
		return {}

	var base_position: Vector3 = global_position + (side_direction * side_offset)
	var top_origin: Vector3 = base_position
	top_origin += Vector3.UP * maxf(probe_height, 0.0)
	top_origin += clean_forward * maxf(MovementClimb.edge_hold_top_forward_distance, 0.0)
	var top_target: Vector3 = top_origin + Vector3.DOWN * maxf(MovementClimb.edge_hold_top_down_distance, 0.001)
	var top_hit: Dictionary = _raycast_climb_segment(top_origin, top_target)
	if top_hit.is_empty():
		return {}

	var floor_normal: Vector3 = MovementWalk.get_safe_floor_normal(Vector3(top_hit.get("normal", Vector3.UP)))
	if floor_normal.y < MovementEdgeHelp.climb_edge_floor_min_normal_y:
		return {}

	var top_position: Vector3 = Vector3(top_hit.get("position", top_origin))
	var wall_origin: Vector3 = Vector3(
		base_position.x,
		top_position.y - maxf(MovementClimb.edge_hold_wall_probe_below_top, 0.0),
		base_position.z
	)
	var wall_hit: Dictionary = _raycast_climb(wall_origin, clean_forward, MovementClimb.edge_hold_wall_probe_distance)
	if not _is_edge_hold_wall_hit_valid(wall_hit, clean_forward):
		return {}
	if not _edge_hold_has_upper_clearance(base_position, top_position.y, clean_forward):
		return {}

	var wall_normal: Vector3 = MovementClimb.get_horizontal_wall_normal(_get_climb_hit_normal(wall_hit))
	var climb_direction: Vector3 = MovementClimb.get_climb_direction_from_wall(wall_normal)
	if climb_direction == Vector3.ZERO:
		return {}

	var wall_point: Vector3 = Vector3(wall_hit.get("position", wall_origin + (clean_forward * MovementClimb.edge_hold_wall_probe_distance)))
	var hold_position: Vector3 = MovementClimb.get_edge_hold_position(
		base_position,
		top_position,
		wall_point,
		wall_normal,
		MovementCrouch.capsule_radius
	)
	var proposed_position: Vector3 = base_position
	proposed_position.y = top_position.y
	proposed_position = _get_edge_help_pulled_position(
		proposed_position,
		climb_direction,
		MovementEdgeHelp.climb_edge_pull_forward_distance
	)

	return {
		"position": proposed_position,
		"hold_position": hold_position,
		"lift_height": top_position.y - global_position.y,
		"edge_top_y": top_position.y,
		"floor_normal": floor_normal,
		"wall_normal": wall_normal,
		"climb_direction": climb_direction,
		"side_direction": side_direction,
		"top_position": top_position
	}


func _is_edge_hold_wall_hit_valid(wall_hit: Dictionary, forward_direction: Vector3) -> bool:
	if wall_hit.is_empty():
		return false

	var wall_normal: Vector3 = _get_climb_hit_normal(wall_hit)
	if not MovementClimb.is_valid_wall_normal(wall_normal):
		return false
	return MovementClimb.is_aligned_with_wall(forward_direction, wall_normal)


func _edge_hold_has_upper_clearance(base_position: Vector3, top_y: float, forward_direction: Vector3) -> bool:
	var clearance_height: float = maxf(MovementClimb.edge_hold_upper_clearance, 0.0)
	if clearance_height <= 0.0:
		return true

	var clear_origin: Vector3 = Vector3(base_position.x, top_y + clearance_height, base_position.z)
	var clear_hit: Dictionary = _raycast_climb(clear_origin, forward_direction, MovementClimb.edge_hold_wall_probe_distance)
	return clear_hit.is_empty()


func _get_climb_hit_normal(hit: Dictionary) -> Vector3:
	return Vector3(hit.get("normal", Vector3.ZERO))


func _update_wall_run_state(delta: float, on_floor: bool) -> void:
	if on_floor or _is_crouching or _is_sliding:
		_stop_wall_run()
		return
	if _is_wall_run_releasing:
		return
	if _is_wall_running and not StaminaManager.can_wall_run():
		_start_wall_run_release()
		return

	var wall_hit: Dictionary = _find_wall_run_state_hit()
	if wall_hit.is_empty():
		if _is_wall_running:
			_start_wall_run_release()
		return

	var wall_normal: Vector3 = _get_wall_run_hit_normal(wall_hit)
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if _is_wall_running:
		_wall_run_timer += delta
		_sync_wall_run_speed_context(horizontal_speed)
		if MovementWallRun.should_soft_release_wall_run(_wish_direction, wall_normal):
			_start_wall_run_release()
			return
		if not MovementWallRun.can_continue_wall_run(_wish_direction, horizontal_speed, _wall_run_timer, wall_normal):
			_start_wall_run_release()
			return

		_refresh_wall_run_from_normal(wall_normal)
		return

	if not StaminaManager.can_wall_run():
		return
	if not MovementWallRun.can_start_wall_run(
		on_floor,
		_is_crouching,
		_is_sliding,
		_wish_direction,
		horizontal_speed,
		velocity.y,
		wall_normal,
		_last_wall_jump_normal,
		_wall_jump_lockout_timer
	):
		return

	_start_wall_run(wall_normal)


func _apply_wall_run_movement(delta: float) -> void:
	if _wall_run_direction == Vector3.ZERO or _wall_run_normal == Vector3.ZERO:
		_stop_wall_run()
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = MovementWallRun.get_wall_run_horizontal_velocity(
		horizontal_velocity,
		_wall_run_direction,
		_wall_run_normal,
		_get_wall_run_desired_direction(),
		_target_speed,
		delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _apply_wall_run_release_movement(delta: float) -> void:
	if _wall_run_direction == Vector3.ZERO or _wall_run_normal == Vector3.ZERO:
		_finish_wall_run_release()
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = MovementWallRun.get_wall_run_release_horizontal_velocity(
		horizontal_velocity,
		_wall_run_direction,
		_wall_run_normal,
		_get_wall_run_desired_direction(),
		delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _start_wall_run(wall_normal: Vector3) -> void:
	_stop_variable_jump()
	_is_wall_run_releasing = false
	_wall_run_release_timer = 0.0
	_wall_run_entry_speed = Vector2(velocity.x, velocity.z).length()
	_sync_wall_run_speed_context(_wall_run_entry_speed)
	_refresh_wall_run_from_normal(wall_normal)
	_wall_run_timer = 0.0
	_wall_run_blend = maxf(_wall_run_blend, clampf(MovementWallRun.wall_run_enter_blend, 0.0, 1.0))
	_is_wall_running = true


func _start_wall_run_release() -> void:
	if not MovementWallRun.enable_soft_wall_release:
		_stop_wall_run()
		return
	if _wall_run_normal == Vector3.ZERO or _wall_run_direction == Vector3.ZERO:
		_stop_wall_run()
		return

	_is_wall_running = false
	_is_wall_run_releasing = true
	_wall_run_release_timer = 0.0
	_wall_run_timer = 0.0


func _stop_wall_run() -> void:
	_is_wall_running = false
	_is_wall_run_releasing = false
	_wall_run_timer = 0.0
	_wall_run_release_timer = 0.0
	_wall_run_normal = Vector3.ZERO
	_wall_run_direction = Vector3.ZERO
	_wall_run_side = 0
	_wall_run_entry_speed = 0.0


func _finish_wall_run_release() -> void:
	_is_wall_run_releasing = false
	_wall_run_release_timer = 0.0
	_wall_run_normal = Vector3.ZERO
	_wall_run_direction = Vector3.ZERO
	_wall_run_side = 0
	_wall_run_entry_speed = 0.0


func _refresh_wall_run_from_normal(wall_normal: Vector3) -> void:
	_wall_run_normal = MovementWallRun.get_horizontal_wall_normal(wall_normal)
	_wall_run_direction = MovementWallRun.get_wall_run_direction(_wall_run_normal, _get_wall_run_desired_direction())
	_wall_run_side = MovementWallRun.get_wall_side(_wall_run_normal, rotation.y)


func _sync_wall_run_speed_context(horizontal_speed: float) -> void:
	if _wall_run_entry_speed <= 0.001:
		_wall_run_entry_speed = horizontal_speed
	MovementWallRun.set_wall_run_speed_context(
		_wall_run_entry_speed,
		_get_wall_run_sprint_blend_context(),
		_combo_speed_bonus
	)


func _get_wall_run_sprint_blend_context() -> float:
	if not _is_sprinting:
		return 0.0
	return _get_sprint_ramp_blend()


func _update_wall_run_blend(delta: float) -> void:
	_wall_run_blend = MovementWallRun.get_wall_run_blend(
		_wall_run_blend,
		_is_wall_running,
		delta,
		_is_wall_run_releasing
	)


func _update_wall_run_release_state(delta: float, on_floor: bool) -> void:
	if not _is_wall_run_releasing:
		return
	if on_floor or _is_crouching or _is_sliding or _is_climbing or _is_edge_pulling_over or _is_edge_holding:
		_finish_wall_run_release()
		return

	_wall_run_release_timer += delta
	var release_duration: float = maxf(MovementWallRun.wall_release_duration, 0.0)
	if _wall_run_release_timer >= release_duration and _wall_run_blend <= 0.035:
		_finish_wall_run_release()


func _update_wall_jump_lockout(delta: float) -> void:
	if _wall_jump_lockout_timer > 0.0:
		_wall_jump_lockout_timer = maxf(_wall_jump_lockout_timer - delta, 0.0)
	elif _last_wall_jump_normal != Vector3.ZERO:
		_last_wall_jump_normal = Vector3.ZERO


func _find_best_wall_run_hit() -> Dictionary:
	var right_direction: Vector3 = Basis(Vector3.UP, rotation.y).x.normalized()
	var left_hit: Dictionary = _find_wall_run_hit(-right_direction)
	var right_hit: Dictionary = _find_wall_run_hit(right_direction)
	if left_hit.is_empty():
		return right_hit
	if right_hit.is_empty():
		return left_hit

	var desired_direction: Vector3 = _get_wall_run_desired_direction()
	var left_score: float = _get_wall_run_hit_score(left_hit, desired_direction)
	var right_score: float = _get_wall_run_hit_score(right_hit, desired_direction)
	if right_score > left_score:
		return right_hit
	return left_hit


func _find_wall_run_state_hit() -> Dictionary:
	if not _is_wall_running or _wall_run_side == 0:
		return _find_best_wall_run_hit()

	var previous_wall_direction: Vector3 = -_wall_run_normal
	if previous_wall_direction.length_squared() > 0.001:
		var previous_wall_hit: Dictionary = _find_wall_run_hit(previous_wall_direction)
		if not previous_wall_hit.is_empty():
			return previous_wall_hit

	var right_direction: Vector3 = Basis(Vector3.UP, rotation.y).x.normalized()
	var locked_side_direction: Vector3 = right_direction * float(_wall_run_side)
	var locked_hit: Dictionary = _find_wall_run_hit(locked_side_direction)
	if not locked_hit.is_empty():
		return locked_hit

	return _find_best_wall_run_hit()


func _find_wall_run_hit(ray_direction: Vector3) -> Dictionary:
	var lower_height: float = minf(_current_body_height * 0.62, MovementWallRun.wall_check_height)
	var upper_height: float = minf(_current_body_height * 0.88, MovementWallRun.wall_check_upper_height)
	var lower_hit: Dictionary = _raycast_wall_run(global_position + Vector3.UP * lower_height, ray_direction)
	if _is_wall_run_hit_valid(lower_hit, ray_direction):
		return lower_hit

	var upper_hit: Dictionary = _raycast_wall_run(global_position + Vector3.UP * upper_height, ray_direction)
	if _is_wall_run_hit_valid(upper_hit, ray_direction):
		return upper_hit

	return {}


func _raycast_wall_run(ray_from: Vector3, ray_direction: Vector3) -> Dictionary:
	if ray_direction == Vector3.ZERO:
		return {}

	var ray_to: Vector3 = ray_from + ray_direction.normalized() * maxf(MovementWallRun.wall_check_distance, 0.0)
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, collision_mask)
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	var excluded_bodies: Array[RID] = [get_rid()]
	ray_query.exclude = excluded_bodies
	return get_world_3d().direct_space_state.intersect_ray(ray_query)


func _is_wall_run_hit_valid(wall_hit: Dictionary, ray_direction: Vector3) -> bool:
	if wall_hit.is_empty():
		return false

	var wall_normal: Vector3 = _get_wall_run_hit_normal(wall_hit)
	if not MovementWallRun.is_side_wall_hit(ray_direction, wall_normal):
		return false
	return MovementWallRun.can_attach_to_wall(wall_normal, _last_wall_jump_normal, _wall_jump_lockout_timer)


func _get_wall_run_hit_score(wall_hit: Dictionary, desired_direction: Vector3) -> float:
	var wall_normal: Vector3 = _get_wall_run_hit_normal(wall_hit)
	var wall_direction: Vector3 = MovementWallRun.get_wall_run_direction(wall_normal, desired_direction)
	if wall_direction == Vector3.ZERO or desired_direction == Vector3.ZERO:
		return 0.0
	return wall_direction.dot(desired_direction.normalized())


func _get_wall_run_hit_normal(wall_hit: Dictionary) -> Vector3:
	var wall_normal: Vector3 = Vector3(wall_hit.get("normal", Vector3.ZERO))
	return wall_normal


func _get_wall_run_desired_direction() -> Vector3:
	if _wish_direction != Vector3.ZERO:
		return _wish_direction

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() > 0.001:
		return horizontal_velocity.normalized()

	return -Basis(Vector3.UP, rotation.y).z.normalized()


func _update_slide_state(delta: float, on_floor: bool) -> void:
	if not _can_use_slide():
		_stop_slide()
		return

	if _is_sliding:
		_slide_timer += delta
		if _should_stop_slide(on_floor):
			_stop_slide()
		return

	if _should_start_slide(on_floor):
		_start_slide()


func _apply_slide_movement(delta: float) -> void:
	if _slide_direction == Vector3.ZERO:
		_stop_slide()
		return

	var floor_normal: Vector3 = _ground_normal
	_slide_direction = MovementSlide.get_steered_slide_direction(
		_slide_direction,
		_wish_direction,
		floor_normal,
		_slide_speed,
		delta
	)
	MovementSlide.set_slide_motion_context(_slide_direction, floor_normal, _combo_speed_bonus, _wish_direction)
	_slide_speed = MovementSlide.get_next_slide_speed(
		_slide_speed,
		_slide_start_speed,
		_slide_timer,
		delta
	)
	if _slide_timer >= MovementSlide.slide_min_time and _slide_speed <= MovementSlide.slide_exit_speed:
		_stop_slide()
		return

	var horizontal_velocity: Vector3 = _slide_direction * _slide_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _can_use_slide() -> bool:
	return MovementSlide.enable_slide_movement and MovementSlide.enable_slide


func _should_start_slide(on_floor: bool) -> bool:
	if not on_floor:
		return false
	if not StaminaManager.can_slide():
		return false
	if _move_input == Vector2.ZERO or _wish_direction == Vector3.ZERO:
		return false

	var manual_slide: bool = MovementSlide.enable_manual_slide and _wants_sprint and _wants_crouch
	var auto_slide: bool = MovementSlide.slide_from_auto_crouch
	auto_slide = auto_slide and MovementSlide.enable_auto_slide_under_obstacles
	auto_slide = auto_slide and _wants_sprint
	auto_slide = auto_slide and _is_forced_crouching
	if not manual_slide and not auto_slide:
		return false

	return _get_slide_candidate_start_speed() >= MovementSlide.slide_min_start_speed


func _should_stop_slide(on_floor: bool) -> bool:
	if not on_floor:
		return true
	if not StaminaManager.can_slide():
		return true
	if _slide_timer < MovementSlide.slide_min_time:
		return false
	if _slide_speed <= MovementSlide.slide_stop_to_crouch_speed:
		return true
	if not _wants_crouch and not _is_forced_crouching:
		return true
	return false


func _start_slide() -> void:
	var started_from_jump_momentum: bool = _can_slide_inherit_jump_momentum()
	if started_from_jump_momentum:
		_add_combo_speed_bonus(MovementRun.combo_bonus_per_jump_slide)

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() > 0.001:
		_slide_direction = horizontal_velocity.normalized()
	else:
		_slide_direction = _wish_direction

	var start_speed: float = horizontal_velocity.length()
	start_speed *= MovementSlide.slide_start_speed_multiplier
	start_speed = _get_slide_start_speed_with_jump_momentum(start_speed)
	_sync_movement_slide_combo_bonus()
	start_speed = MovementSlide.get_combo_slide_start_speed(start_speed)
	var landing_drop_height: float = _get_recent_landing_slide_drop_height()
	var landing_slide_multiplier: float = MovementSlide.get_landing_drop_slide_multiplier(landing_drop_height)
	MovementSlide.set_landing_drop_slide_multiplier(landing_slide_multiplier)
	start_speed = MovementSlide.get_landing_drop_slide_start_speed(start_speed, landing_drop_height)
	_slide_direction = _get_slide_direction_with_jump_momentum(_slide_direction)
	_slide_speed = minf(
		maxf(start_speed, MovementSlide.slide_min_start_speed),
		MovementSlide.get_slide_max_speed()
	)
	_slide_start_speed = _slide_speed
	_slide_timer = 0.0
	_slide_blend = maxf(_slide_blend, clampf(MovementSlide.slide_enter_blend, 0.0, 1.0))
	_is_sliding = true
	if started_from_jump_momentum:
		_consume_jump_slide_combo_momentum()
	if landing_slide_multiplier > 1.001:
		_consume_landing_slide_boost()


func _stop_slide() -> void:
	_is_sliding = false
	_slide_start_speed = 0.0
	_slide_timer = 0.0
	MovementSlide.clear_landing_drop_slide_multiplier()


func _get_slide_attempt_speed() -> float:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var input_speed: float = MovementWalk.walk_speed
	if _wants_sprint:
		input_speed = _get_sprint_speed_limit()
	return maxf(horizontal_speed, input_speed * _move_input.length())


func _get_slide_candidate_start_speed() -> float:
	var start_speed: float = Vector2(velocity.x, velocity.z).length()
	if _can_slide_inherit_jump_momentum():
		var inherited_speed: float = _recent_jump_momentum_speed * MovementSlide.slide_jump_momentum_multiplier
		start_speed = maxf(start_speed, inherited_speed)
	if start_speed > 0.001:
		_sync_movement_slide_combo_bonus()
		start_speed = MovementSlide.get_combo_slide_start_speed(start_speed)
		start_speed = MovementSlide.get_landing_drop_slide_start_speed(start_speed, _get_recent_landing_slide_drop_height())
	return start_speed


func _get_slide_start_speed_with_jump_momentum(start_speed: float) -> float:
	if not _can_slide_inherit_jump_momentum():
		return start_speed

	var inherited_speed: float = _recent_jump_momentum_speed * MovementSlide.slide_jump_momentum_multiplier
	return maxf(start_speed, inherited_speed)


func _get_slide_direction_with_jump_momentum(slide_direction: Vector3) -> Vector3:
	if not _can_slide_inherit_jump_momentum():
		return slide_direction
	if _recent_jump_momentum_direction == Vector3.ZERO:
		return slide_direction

	var influence: float = clampf(MovementSlide.slide_jump_direction_influence, 0.0, 1.0)
	if slide_direction == Vector3.ZERO:
		return _recent_jump_momentum_direction
	return slide_direction.lerp(_recent_jump_momentum_direction, influence).normalized()


func _can_slide_inherit_jump_momentum() -> bool:
	if not MovementJump.enable_momentum_links or not MovementSlide.slide_inherit_jump_momentum:
		return false
	if _recent_jump_momentum_timer <= 0.0:
		return false
	return _recent_jump_momentum_speed >= MovementSlide.slide_min_jump_momentum_speed


func _consume_jump_slide_combo_momentum() -> void:
	_recent_jump_momentum_timer = 0.0
	_recent_jump_momentum_speed = 0.0
	_recent_jump_momentum_direction = Vector3.ZERO


func _update_slide_blend(delta: float) -> void:
	var target_slide_blend: float = 0.0
	if _is_sliding:
		target_slide_blend = 1.0

	var slide_blend_speed: float = maxf(MovementSlide.slide_blend_lerp_speed, 0.001)
	var slide_blend_amount: float = 1.0 - exp(-slide_blend_speed * delta)
	_slide_blend = lerpf(_slide_blend, target_slide_blend, slide_blend_amount)


func _apply_vertical_motion(delta: float, on_floor: bool) -> void:
	if _is_hook_anchored and not on_floor and _jump_buffer_timer > 0.0:
		_release_hook(true)
		_jump_buffer_timer = 0.0
		return

	if _is_hook_anchored and not on_floor:
		# Constant gravity on the rope; the jump arc's rise/fall split would pump energy into the swing.
		_stop_variable_jump()
		velocity.y = maxf(
			velocity.y - WorldBasicRules.get_gravity() * maxf(MovementHook.swing_gravity_multiplier, 0.0) * delta,
			-WorldBasicRules.get_terminal_fall_speed()
		)
		return

	if _is_wall_run_releasing:
		if _jump_buffer_timer > 0.0 and MovementWallRun.enable_wall_release_jump:
			_apply_wall_jump(true)
			return

		velocity.y = MovementWallRun.get_wall_run_release_vertical_velocity(
			velocity.y,
			_wall_run_release_timer,
			delta
		)
		return

	if _is_wall_running:
		if _jump_buffer_timer > 0.0:
			_apply_wall_jump()
			return

		velocity.y = MovementWallRun.get_wall_run_vertical_velocity(velocity.y, _wall_run_timer, delta)
		return

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		var jump_started_from_slide: bool = _is_sliding
		var jump_started_from_crouch: bool = _is_crouching and not jump_started_from_slide
		var uses_slide_jump_boost: bool = jump_started_from_slide and MovementSlide.enable_slide_jump_boost
		uses_slide_jump_boost = uses_slide_jump_boost and StaminaManager.spend_slide_jump()
		var sprint_jump_power: float = _get_sprint_jump_power()
		var jump_velocity: float = _get_jump_start_velocity(jump_started_from_crouch)
		var uses_sprint_jump_boost: bool = not jump_started_from_slide and sprint_jump_power > 0.0 and MovementRun.enable_sprint_jump_boost
		uses_sprint_jump_boost = uses_sprint_jump_boost and StaminaManager.spend_sprint_jump()
		if uses_sprint_jump_boost:
			jump_velocity = MovementJump.get_sprint_jump_velocity(
				jump_velocity,
				sprint_jump_power,
				MovementRun.sprint_jump_height_multiplier
			)
			_apply_sprint_jump_boost(sprint_jump_power)
		if uses_slide_jump_boost:
			_add_combo_speed_bonus(MovementRun.combo_bonus_per_slide_jump)
			_apply_slide_jump_boost()
		if jump_started_from_slide:
			_stop_slide()

		LoudnessManger.register_jump(
			uses_sprint_jump_boost,
			jump_started_from_crouch,
			uses_slide_jump_boost,
			Vector2(velocity.x, velocity.z).length()
		)
		_apply_jump_horizontal_momentum(jump_started_from_crouch, uses_slide_jump_boost, delta)
		_register_jump_momentum()
		velocity.y = jump_velocity
		_start_variable_jump(jump_started_from_crouch)
		var jump_feedback_strength: float = _get_jump_feedback_strength(jump_started_from_crouch, uses_slide_jump_boost)
		jump_feedback_strength *= maxf(JumpFeel.jump_feedback_multiplier, 0.0)
		_jump_feedback = jump_feedback_strength
		_recent_jump_feedback = jump_feedback_strength
		_recent_jump_strength = jump_feedback_strength
		_recent_jump_timer = FEEDBACK_MEMORY_TIME
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		return

	if on_floor and velocity.y < 0.0:
		_stop_variable_jump()
		velocity.y = -maxf(LandingFeel.landing_stick_velocity, 0.0)
		return

	var gravity_multiplier: float = _get_airborne_gravity_multiplier(delta)
	velocity.y = maxf(
		velocity.y - WorldBasicRules.get_gravity() * gravity_multiplier * delta,
		-WorldBasicRules.get_terminal_fall_speed()
	)


func _apply_wall_jump(is_release_jump: bool = false) -> void:
	var previous_wall_normal: Vector3 = _wall_run_normal
	var previous_wall_side: int = _wall_run_side
	if is_release_jump:
		velocity = MovementWallRun.get_wall_release_jump_velocity(
			velocity,
			_wall_run_normal,
			_wall_run_direction,
			_wish_direction,
			_combo_speed_bonus
		)
	else:
		velocity = MovementWallRun.get_wall_jump_velocity(
			velocity,
			_wall_run_normal,
			_wall_run_direction,
			_wish_direction,
			_combo_speed_bonus
		)

	_stop_wall_run()
	_last_wall_jump_normal = previous_wall_normal
	_wall_jump_lockout_timer = maxf(MovementWallRun.same_wall_reattach_lockout, 0.0)
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_start_variable_jump(false)
	_register_jump_momentum()

	var feedback_strength: float = maxf(WallRunFeel.wall_jump_feedback_multiplier, 0.0)
	if is_release_jump:
		feedback_strength *= maxf(WallRunFeel.wall_release_jump_feedback_multiplier, 0.0)
	_jump_feedback = maxf(_jump_feedback, feedback_strength)
	_recent_jump_feedback = maxf(_recent_jump_feedback, feedback_strength)
	_recent_jump_strength = maxf(_recent_jump_strength, feedback_strength)
	_recent_jump_timer = FEEDBACK_MEMORY_TIME
	var signed_wall_feedback: float = feedback_strength * float(previous_wall_side)
	if absf(signed_wall_feedback) > absf(_wall_jump_feedback):
		_wall_jump_feedback = signed_wall_feedback


func _get_jump_start_velocity(jump_started_from_crouch: bool) -> float:
	return MovementJump.get_jump_start_velocity(jump_started_from_crouch)


func _get_jump_feedback_strength(jump_started_from_crouch: bool, jump_started_from_slide: bool) -> float:
	var feedback_strength: float = 1.0
	if jump_started_from_slide and MovementSlide.enable_slide_jump_boost:
		feedback_strength = clampf(MovementSlide.slide_jump_feedback_multiplier, 0.0, 1.0)
	elif jump_started_from_crouch and MovementJump.enable_crouch_jump:
		feedback_strength = clampf(MovementJump.crouch_jump_feedback_multiplier, 0.0, 1.0)

	if MovementJump.enable_momentum_links:
		feedback_strength += _get_jump_feedback_speed_bonus()

	return clampf(feedback_strength, 0.0, 1.35)


func _get_jump_feedback_speed_bonus() -> float:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	return MovementJump.get_feedback_speed_bonus(horizontal_speed, _get_sprint_speed_limit())


func _start_variable_jump(jump_started_from_crouch: bool) -> void:
	if not MovementJump.can_start_variable_jump(jump_started_from_crouch):
		_stop_variable_jump()
		return

	_jump_hold_timer = MovementJump.jump_hold_time
	_jump_hold_active = true


func _stop_variable_jump() -> void:
	_jump_hold_timer = 0.0
	_jump_hold_active = false


func _get_variable_jump_gravity_multiplier(delta: float) -> float:
	if not _jump_hold_active:
		return 1.0
	if velocity.y <= 0.0:
		_stop_variable_jump()
		return 1.0
	if not InputManager.is_jump_pressed():
		_cut_variable_jump_velocity()
		_stop_variable_jump()
		return 1.0
	if _jump_hold_timer <= 0.0:
		_stop_variable_jump()
		return 1.0

	_jump_hold_timer = maxf(_jump_hold_timer - delta, 0.0)
	return clampf(MovementJump.jump_hold_gravity_multiplier, 0.0, 1.0)


func _get_airborne_gravity_multiplier(delta: float) -> float:
	var variable_jump_multiplier: float = _get_variable_jump_gravity_multiplier(delta)
	return MovementJump.get_airborne_gravity_multiplier(variable_jump_multiplier, velocity.y)


func _cut_variable_jump_velocity() -> void:
	if velocity.y <= 0.0:
		return

	velocity.y = MovementJump.get_released_jump_velocity(velocity.y)


func _get_sprint_jump_power() -> float:
	if not _is_sprinting:
		return 0.0
	if not MovementJump.enable_momentum_links:
		return 1.0

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_sync_movement_run_combo_bonus()
	return MovementRun.get_sprint_jump_power(_is_sprinting, _get_sprint_ramp_blend(), horizontal_speed)


func _apply_jump_horizontal_momentum(jump_started_from_crouch: bool, jump_started_from_slide: bool, delta: float) -> void:
	if not MovementJump.enable_momentum_links:
		return
	if _wish_direction == Vector3.ZERO:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = MovementJump.get_takeoff_control_velocity(
		horizontal_velocity,
		_wish_direction,
		_target_speed,
		MovementWalk.get_input_strength(_move_input),
		jump_started_from_crouch,
		jump_started_from_slide,
		delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _register_jump_momentum() -> void:
	if not MovementJump.enable_momentum_links:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	_recent_jump_momentum_speed = horizontal_velocity.length()
	if _recent_jump_momentum_speed > 0.001:
		_recent_jump_momentum_direction = horizontal_velocity.normalized()
	else:
		_recent_jump_momentum_direction = Vector3.ZERO
	_recent_jump_momentum_timer = maxf(MovementSlide.slide_jump_momentum_window, 0.0)


func _apply_sprint_jump_boost(sprint_jump_power: float) -> void:
	var boost_direction: Vector3 = _wish_direction
	if boost_direction == Vector3.ZERO:
		boost_direction = Vector3(velocity.x, 0.0, velocity.z)
		if boost_direction.length_squared() > 0.001:
			boost_direction = boost_direction.normalized()

	if boost_direction == Vector3.ZERO:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity += boost_direction * MovementRun.sprint_jump_forward_boost * sprint_jump_power

	var horizontal_speed: float = horizontal_velocity.length()
	if horizontal_speed > MovementRun.sprint_jump_max_horizontal_speed:
		horizontal_velocity = horizontal_velocity.normalized() * MovementRun.sprint_jump_max_horizontal_speed

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _apply_slide_jump_boost() -> void:
	var boost_direction: Vector3 = _slide_direction
	if boost_direction == Vector3.ZERO:
		boost_direction = _wish_direction
	if boost_direction == Vector3.ZERO:
		boost_direction = Vector3(velocity.x, 0.0, velocity.z)
		if boost_direction.length_squared() > 0.001:
			boost_direction = boost_direction.normalized()

	if boost_direction == Vector3.ZERO:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_forward_speed: float = horizontal_velocity.dot(boost_direction)
	_sync_movement_slide_combo_bonus()
	var target_forward_speed: float = MovementSlide.get_slide_jump_target_forward_speed(current_forward_speed, _slide_speed)
	var forward_speed_to_add: float = maxf(target_forward_speed - current_forward_speed, 0.0)
	horizontal_velocity += boost_direction * forward_speed_to_add

	var horizontal_speed: float = horizontal_velocity.length()
	var slide_jump_max_speed: float = MovementSlide.get_slide_jump_max_horizontal_speed(_slide_speed)
	if horizontal_speed > slide_jump_max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * slide_jump_max_speed

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _get_stair_speed_multiplier() -> float:
	return StairFeel.get_speed_multiplier(_is_sprinting, _stair_blend)


func _apply_stair_speed_limit(horizontal_velocity: Vector3, target_speed: float, delta: float) -> Vector3:
	if _stair_blend <= 0.0:
		return horizontal_velocity

	var speed: float = horizontal_velocity.length()
	if speed <= target_speed:
		return horizontal_velocity

	var speed_blend: float = StairFeel.get_speed_limit_blend(_stair_blend, delta)
	var limited_speed: float = lerpf(speed, target_speed, speed_blend)
	return horizontal_velocity.normalized() * limited_speed


func _update_jump_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = MovementJump.coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if InputManager.is_jump_just_pressed():
		_jump_buffer_timer = MovementJump.jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _update_crouch(delta: float) -> void:
	var target_height: float = MovementCrouch.get_target_height(_is_crouching)
	var blend: float = MovementCrouch.get_height_blend(delta, _is_crouching)
	_current_body_height = lerpf(_current_body_height, target_height, blend)
	_apply_body_dimensions()


func _update_crouch_transition_feedback(previous_crouch_feel_active: bool, on_floor: bool) -> void:
	var current_crouch_feel_active: bool = _is_crouch_feel_active()
	if current_crouch_feel_active == previous_crouch_feel_active:
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if current_crouch_feel_active:
		var enter_strength: float = CrouchFeel.get_enter_feedback_strength(horizontal_speed, MovementWalk.walk_speed, on_floor)
		_crouch_enter_feedback = maxf(_crouch_enter_feedback, enter_strength)
		_register_recent_crouch_feedback(enter_strength)
	else:
		var exit_strength: float = CrouchFeel.get_exit_feedback_strength(horizontal_speed, MovementWalk.walk_speed, on_floor)
		_crouch_exit_feedback = maxf(_crouch_exit_feedback, exit_strength)
		_register_recent_crouch_feedback(-exit_strength)


func _is_crouch_feel_active() -> bool:
	return _is_crouching and not _is_sliding


func _register_recent_crouch_feedback(feedback_strength: float) -> void:
	_recent_crouch_strength = feedback_strength
	_recent_crouch_feedback = feedback_strength
	_recent_crouch_timer = maxf(CrouchFeel.recent_feedback_time, 0.0)


func _should_force_crouch() -> bool:
	if not MovementCrouch.enable_auto_crouch:
		return false

	if MovementCrouch.force_crouch_when_head_blocked and not _has_body_clearance(
		MovementCrouch.standing_height + MovementCrouch.stand_clearance_margin,
		global_position
	):
		return true

	if _move_input == Vector2.ZERO or _wish_direction == Vector3.ZERO:
		return false

	var probe_speed: float = maxf(Vector2(velocity.x, velocity.z).length(), _get_slide_attempt_speed())
	if probe_speed < MovementCrouch.auto_crouch_probe_min_speed:
		return false

	var probe_position: Vector3 = global_position + (_wish_direction * MovementCrouch.auto_crouch_probe_distance)
	var standing_clear: bool = _has_body_clearance(
		MovementCrouch.standing_height + MovementCrouch.stand_clearance_margin,
		probe_position
	)
	if standing_clear:
		return false

	return _has_body_clearance(
		MovementCrouch.crouching_height + MovementCrouch.crouch_clearance_margin,
		probe_position
	)


func _has_body_clearance(body_height: float, body_origin: Vector3) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = MovementCrouch.capsule_radius
	capsule.height = body_height

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(
		Basis(Vector3.UP, rotation.y),
		body_origin + Vector3.UP * ((body_height * 0.5) + MovementCrouch.clearance_test_margin)
	)
	query.collision_mask = collision_mask
	query.margin = 0.0
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded_bodies: Array[RID] = [get_rid()]
	query.exclude = excluded_bodies

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hits: Array = space_state.intersect_shape(query, MovementCrouch.clearance_max_results)
	return hits.is_empty()


func _apply_character_body_physics_settings() -> void:
	up_direction = Vector3.UP
	floor_max_angle = MovementWalk.get_max_walkable_floor_angle()
	floor_snap_length = maxf(MovementWalk.floor_snap_length, 0.0)
	floor_stop_on_slope = MovementWalk.floor_stop_on_slope
	floor_constant_speed = MovementWalk.floor_constant_speed
	floor_block_on_wall = MovementWalk.floor_block_on_wall
	safe_margin = maxf(MovementWalk.body_safe_margin, 0.0)


func _update_ground_contact_state(on_floor: bool, delta: float) -> void:
	var target_normal: Vector3 = Vector3.UP
	if on_floor:
		target_normal = MovementWalk.get_safe_floor_normal(get_floor_normal())

	var normal_blend: float = MovementWalk.get_ground_normal_blend(delta)
	_ground_normal = _ground_normal.lerp(target_normal, normal_blend)
	if _ground_normal.length_squared() <= 0.001:
		_ground_normal = Vector3.UP
	else:
		_ground_normal = _ground_normal.normalized()


func _update_fall_height_tracking(on_floor: bool) -> void:
	if on_floor:
		if _was_on_floor:
			_airborne_highest_y = global_position.y
		return

	if _was_on_floor:
		_airborne_highest_y = global_position.y
		return

	_airborne_highest_y = maxf(_airborne_highest_y, global_position.y)


func _cache_landing_drop_height() -> void:
	var drop_height: float = _get_current_landing_drop_height()
	if MovementSlide.has_landing_drop_slide_boost(drop_height):
		_recent_landing_drop_height = drop_height
		_recent_landing_drop_timer = maxf(MovementSlide.landing_drop_slide_boost_window, 0.0)
	else:
		_consume_landing_slide_boost()

	_airborne_highest_y = global_position.y


func _update_landing_slide_boost_timer(delta: float) -> void:
	if _recent_landing_drop_timer > 0.0:
		_recent_landing_drop_timer = maxf(_recent_landing_drop_timer - delta, 0.0)
		if _recent_landing_drop_timer <= 0.0:
			_recent_landing_drop_height = 0.0
	else:
		_recent_landing_drop_height = 0.0


func _get_recent_landing_slide_drop_height() -> float:
	if _recent_landing_drop_timer <= 0.0:
		return 0.0
	return maxf(_recent_landing_drop_height, 0.0)


func _consume_landing_slide_boost() -> void:
	_recent_landing_drop_height = 0.0
	_recent_landing_drop_timer = 0.0


func _get_current_landing_drop_height() -> float:
	return maxf(_airborne_highest_y - global_position.y, 0.0)


func _register_stair_floor_contact(floor_normal: Vector3) -> void:
	_ground_normal = MovementWalk.get_safe_floor_normal(floor_normal)
	_time_since_floor = 0.0
	_coyote_timer = MovementJump.coyote_time
	apply_floor_snap()


func _apply_body_dimensions() -> void:
	collision_shape.scale = Vector3.ONE
	collision_shape.position.y = _current_body_height * 0.5

	var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if capsule != null:
		capsule.radius = MovementCrouch.capsule_radius
		capsule.height = _current_body_height

	visual_body.scale = Vector3.ONE
	visual_body.position.y = _current_body_height * 0.5


func _try_step_up(delta: float, was_on_floor: bool) -> void:
	if not StairFeel.enable_stair_stepping:
		return
	if not was_on_floor:
		return
	if _wish_direction == Vector3.ZERO:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var attempt_speed: float = _get_step_attempt_speed(horizontal_velocity.length())
	if attempt_speed < StairFeel.stair_min_speed:
		return

	var probe_distance: float = maxf(StairFeel.stair_forward_distance, attempt_speed * delta)
	if not _has_step_blocker(probe_distance):
		return

	var forward_motion: Vector3 = _wish_direction * probe_distance
	var current_transform: Transform3D = global_transform
	var raised_transform: Transform3D = current_transform.translated(Vector3.UP * StairFeel.stair_max_height)
	var forward_collision: KinematicCollision3D = KinematicCollision3D.new()
	if test_move(raised_transform, forward_motion, forward_collision, StairFeel.stair_safe_margin):
		return

	var down_collision: KinematicCollision3D = KinematicCollision3D.new()
	var down_start: Transform3D = raised_transform.translated(forward_motion)
	var down_motion: Vector3 = Vector3.DOWN * (StairFeel.stair_max_height + StairFeel.stair_snap_down_distance)
	if not test_move(down_start, down_motion, down_collision, StairFeel.stair_safe_margin):
		return

	var floor_normal: Vector3 = down_collision.get_normal()
	if floor_normal.y < StairFeel.stair_floor_min_normal_y:
		return

	var proposed_position: Vector3 = down_start.origin + down_collision.get_travel()
	var step_height: float = proposed_position.y - global_position.y
	if step_height < StairFeel.stair_min_height or step_height > StairFeel.stair_max_height:
		return

	global_position = proposed_position
	_register_stair_floor_contact(floor_normal)
	_keep_stair_forward_velocity(attempt_speed)
	_add_step_view_lift(step_height, StairFeel.stair_max_view_step_offset)
	_register_stair_step(step_height)


func _try_edge_help(delta: float, was_on_floor: bool) -> void:
	if not MovementEdgeHelp.enable_edge_help:
		return
	if was_on_floor or is_on_floor():
		return
	if _edge_help_cooldown_timer > 0.0:
		return
	if _wish_direction == Vector3.ZERO:
		return
	if _time_since_floor > MovementEdgeHelp.max_time_after_leaving_floor:
		return
	if velocity.y < MovementEdgeHelp.min_vertical_velocity or velocity.y > MovementEdgeHelp.max_vertical_velocity:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var attempt_speed: float = _get_edge_help_attempt_speed(horizontal_velocity.length())
	if attempt_speed < MovementEdgeHelp.min_horizontal_speed:
		return

	var edge_result: Dictionary = _find_edge_help_landing(
		_wish_direction,
		attempt_speed,
		delta,
		MovementEdgeHelp.max_lift_height,
		MovementEdgeHelp.min_lift_height,
		MovementEdgeHelp.min_probe_lift_height,
		MovementEdgeHelp.lift_probe_count,
		MovementEdgeHelp.forward_distance,
		MovementEdgeHelp.pull_forward_distance,
		MovementEdgeHelp.snap_down_distance,
		MovementEdgeHelp.floor_min_normal_y
	)
	if edge_result.is_empty():
		return

	_apply_stair_like_edge_result(edge_result, attempt_speed, _wish_direction, false)


func _apply_climbed_low_edge_as_normal_path(edge_result: Dictionary, attempt_speed: float, help_direction: Vector3) -> void:
	_apply_stair_like_edge_result(edge_result, attempt_speed, help_direction, true)


func _apply_stair_like_edge_result(
	edge_result: Dictionary,
	attempt_speed: float,
	help_direction: Vector3,
	stop_climb_after: bool
) -> void:
	var proposed_position: Vector3 = Vector3(edge_result.get("position", global_position))
	var edge_floor_normal: Vector3 = _ground_normal
	if edge_result.has("floor_normal"):
		edge_floor_normal = MovementWalk.get_safe_floor_normal(Vector3(edge_result["floor_normal"]))

	var lift_height: float = float(edge_result.get("lift_height", 0.0))
	var clean_help_direction: Vector3 = MovementClimb.get_horizontal_direction(help_direction)

	global_position = proposed_position
	_register_stair_floor_contact(edge_floor_normal)
	_keep_edge_help_forward_velocity_scaled(
		attempt_speed,
		StairFeel.stair_velocity_keep_multiplier,
		clean_help_direction,
		true,
		attempt_speed
	)
	velocity.y = 0.0
	_edge_help_cooldown_timer = maxf(MovementEdgeHelp.cooldown_time, 0.0)

	if lift_height > 0.0:
		_add_step_view_lift(lift_height, StairFeel.stair_max_view_step_offset)
		_register_stair_step(lift_height)

	if stop_climb_after:
		_stop_climb()
		_climb_cooldown_timer = maxf(MovementClimb.cooldown_time, 0.0)


func _apply_climb_edge_result(edge_result: Dictionary, attempt_speed: float, entry_horizontal_speed: float) -> void:
	var proposed_position: Vector3 = Vector3(edge_result.get("position", global_position))
	var edge_floor_normal: Vector3 = _ground_normal
	if edge_result.has("floor_normal"):
		edge_floor_normal = MovementWalk.get_safe_floor_normal(Vector3(edge_result["floor_normal"]))

	var lift_height: float = float(edge_result.get("lift_height", 0.0))
	var feedback_lift_height: float = _get_edge_help_feedback_height(
		lift_height,
		MovementEdgeHelp.climb_edge_min_feedback_lift_height
	)
	var climb_edge_feedback: float = ClimbFeel.get_climb_edge_help_feedback_strength(
		feedback_lift_height,
		MovementEdgeHelp.climb_edge_max_lift_height,
		entry_horizontal_speed
	)

	if MovementEdgeHelp.climb_edge_use_smooth_pull_over and MovementClimb.enable_edge_pull_over:
		_start_edge_pull_over(
			edge_result,
			feedback_lift_height,
			climb_edge_feedback,
			entry_horizontal_speed,
			MovementEdgeHelp.climb_edge_cooldown_time,
			MovementEdgeHelp.climb_edge_feedback_time_multiplier
		)
		return

	global_position = proposed_position
	_ground_normal = edge_floor_normal
	_keep_edge_help_forward_velocity_scaled(
		attempt_speed,
		MovementEdgeHelp.climb_edge_forward_velocity_keep_multiplier,
		_climb_direction,
		MovementEdgeHelp.climb_edge_allow_forward_velocity_boost,
		MovementEdgeHelp.climb_edge_max_forward_velocity_boost
	)
	_limit_edge_help_forward_velocity(_climb_direction, MovementEdgeHelp.climb_edge_max_forward_velocity_after_help)
	velocity.y = MovementEdgeHelp.get_climb_edge_exit_vertical_velocity(velocity.y)
	_edge_help_cooldown_timer = maxf(MovementEdgeHelp.climb_edge_cooldown_time, 0.0)

	var view_lift: float = feedback_lift_height * MovementEdgeHelp.climb_edge_view_lift_feedback_multiplier
	_add_step_view_lift(view_lift, MovementEdgeHelp.climb_edge_max_visual_lift_height)
	_register_edge_help_feedback(
		feedback_lift_height,
		MovementEdgeHelp.climb_edge_step_feedback_multiplier,
		MovementEdgeHelp.climb_edge_feedback_time_multiplier
	)

	_climb_feedback = maxf(_climb_feedback, climb_edge_feedback)
	_register_recent_climb_feedback(climb_edge_feedback, MovementEdgeHelp.climb_edge_feedback_time_multiplier)
	_stop_climb()
	_climb_cooldown_timer = maxf(MovementClimb.cooldown_time, 0.0)


func _try_climb_edge_help(delta: float) -> bool:
	if not MovementEdgeHelp.enable_edge_help or not MovementEdgeHelp.enable_climb_edge_help:
		return false
	if not _is_climbing:
		return false
	if is_on_floor():
		_stop_climb()
		return true
	if _climb_direction == Vector3.ZERO:
		return false
	if _climb_timer < MovementEdgeHelp.climb_edge_min_climb_time:
		return false

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var attempt_speed: float = _get_climb_edge_help_attempt_speed(horizontal_speed)
	if _edge_hold_cooldown_timer > 0.0:
		return false

	if MovementClimb.auto_pull_over_climb_edges or MovementClimb.enable_edge_hold:
		var hold_result: Dictionary = _find_climb_edge_hold_result(_climb_direction, 0.0)
		if not hold_result.is_empty():
			if not _is_climb_edge_result_high_enough(hold_result):
				_apply_climbed_low_edge_as_normal_path(hold_result, attempt_speed, _climb_direction)
				return true

			if MovementClimb.auto_pull_over_climb_edges:
				_apply_climb_edge_result(hold_result, attempt_speed, _climb_entry_horizontal_speed)
				return true

			var hold_lift_height: float = float(hold_result.get("lift_height", 0.0))
			var hold_feedback_lift_height: float = _get_edge_help_feedback_height(
				hold_lift_height,
				MovementEdgeHelp.climb_edge_min_feedback_lift_height
			)
			var hold_feedback: float = ClimbFeel.get_climb_edge_help_feedback_strength(
				hold_feedback_lift_height,
				MovementEdgeHelp.climb_edge_max_lift_height,
				_climb_entry_horizontal_speed
			)
			_start_edge_hold(
				hold_result,
				hold_feedback_lift_height,
				hold_feedback,
				_climb_entry_horizontal_speed,
				MovementEdgeHelp.climb_edge_feedback_time_multiplier
			)
			return true

	var edge_result: Dictionary = _find_edge_help_landing(
		_climb_direction,
		attempt_speed,
		delta,
		MovementEdgeHelp.climb_edge_max_lift_height,
		MovementEdgeHelp.climb_edge_min_lift_height,
		MovementEdgeHelp.climb_edge_min_probe_lift_height,
		MovementEdgeHelp.climb_edge_lift_probe_count,
		MovementEdgeHelp.climb_edge_forward_distance,
		MovementEdgeHelp.climb_edge_pull_forward_distance,
		MovementEdgeHelp.climb_edge_snap_down_distance,
		MovementEdgeHelp.climb_edge_floor_min_normal_y
	)
	if edge_result.is_empty():
		return false

	if not _is_climb_edge_result_high_enough(edge_result):
		_apply_climbed_low_edge_as_normal_path(edge_result, attempt_speed, _climb_direction)
		return true

	_apply_climb_edge_result(edge_result, attempt_speed, _climb_entry_horizontal_speed)
	return true


func _get_edge_help_attempt_speed(horizontal_speed: float) -> float:
	var input_speed: float = _target_speed * _move_input.length()
	return maxf(horizontal_speed, input_speed)


func _get_climb_edge_help_attempt_speed(horizontal_speed: float) -> float:
	var input_speed: float = _target_speed * _move_input.length()
	return maxf(maxf(horizontal_speed, input_speed), _climb_entry_horizontal_speed)


func _get_edge_help_feedback_height(lift_height: float, min_feedback_height: float) -> float:
	return maxf(absf(lift_height), maxf(min_feedback_height, 0.0))


func _find_edge_help_landing(
	help_direction: Vector3,
	attempt_speed: float,
	delta: float,
	max_lift_height: float,
	min_lift_height: float,
	min_probe_lift_height: float,
	lift_probe_count: int,
	forward_distance: float,
	pull_forward_distance: float,
	snap_down_distance: float,
	floor_min_normal_y: float
) -> Dictionary:
	if help_direction == Vector3.ZERO:
		return {}

	var forward_direction: Vector3 = help_direction.normalized()
	var clean_max_lift_height: float = maxf(max_lift_height, 0.001)
	var clean_min_lift_height: float = clampf(min_lift_height, -clean_max_lift_height, clean_max_lift_height)
	var first_probe_lift: float = clampf(min_probe_lift_height, 0.0, clean_max_lift_height)
	var probe_count: int = lift_probe_count
	if probe_count < 1:
		probe_count = 1
	var probe_distance: float = maxf(forward_distance, attempt_speed * delta)
	var probe_index: int = 0

	while probe_index < probe_count:
		var lift_ratio: float = 1.0
		if probe_count > 1:
			lift_ratio = float(probe_index) / float(probe_count - 1)

		var probe_lift_height: float = lerpf(first_probe_lift, clean_max_lift_height, lift_ratio)
		var edge_result: Dictionary = _try_edge_help_landing_at_height(
			forward_direction,
			probe_distance,
			pull_forward_distance,
			probe_lift_height,
			clean_min_lift_height,
			clean_max_lift_height,
			snap_down_distance,
			floor_min_normal_y
		)
		if not edge_result.is_empty():
			return edge_result

		probe_index += 1

	return {}


func _try_edge_help_landing_at_height(
	forward_direction: Vector3,
	probe_distance: float,
	pull_forward_distance: float,
	probe_lift_height: float,
	min_lift_height: float,
	max_lift_height: float,
	snap_down_distance: float,
	floor_min_normal_y: float
) -> Dictionary:
	var forward_motion: Vector3 = forward_direction * probe_distance
	var raised_transform: Transform3D = global_transform.translated(Vector3.UP * probe_lift_height)
	var forward_collision: KinematicCollision3D = KinematicCollision3D.new()
	if test_move(raised_transform, forward_motion, forward_collision, MovementEdgeHelp.safe_margin):
		return {}

	var down_collision: KinematicCollision3D = KinematicCollision3D.new()
	var down_start: Transform3D = raised_transform.translated(forward_motion)
	var down_motion: Vector3 = Vector3.DOWN * (probe_lift_height + snap_down_distance)
	if not test_move(down_start, down_motion, down_collision, MovementEdgeHelp.safe_margin):
		return {}

	var floor_normal: Vector3 = down_collision.get_normal()
	if floor_normal.y < floor_min_normal_y:
		return {}

	var landing_position: Vector3 = down_start.origin + down_collision.get_travel()
	var lift_height: float = landing_position.y - global_position.y
	if lift_height < min_lift_height or lift_height > max_lift_height:
		return {}

	var proposed_position: Vector3 = global_position
	proposed_position.y = landing_position.y
	proposed_position = _get_edge_help_pulled_position(
		proposed_position,
		forward_direction,
		pull_forward_distance
	)

	return {
		"position": proposed_position,
		"lift_height": lift_height,
		"edge_top_y": landing_position.y,
		"floor_normal": floor_normal
	}


func _get_edge_help_pulled_position(
	start_position: Vector3,
	forward_direction: Vector3,
	pull_forward_distance: float
) -> Vector3:
	if forward_direction == Vector3.ZERO:
		return start_position
	if pull_forward_distance <= 0.0:
		return start_position

	var pull_motion: Vector3 = forward_direction.normalized() * pull_forward_distance
	var pull_transform: Transform3D = Transform3D(global_transform.basis, start_position)
	var pull_collision: KinematicCollision3D = KinematicCollision3D.new()
	if test_move(pull_transform, pull_motion, pull_collision, MovementEdgeHelp.safe_margin):
		return start_position + pull_collision.get_travel()

	return start_position + pull_motion


func _keep_edge_help_forward_velocity(attempt_speed: float) -> void:
	_keep_edge_help_forward_velocity_scaled(
		attempt_speed,
		MovementEdgeHelp.forward_velocity_keep_multiplier,
		_wish_direction,
		MovementEdgeHelp.allow_forward_velocity_boost,
		MovementEdgeHelp.max_forward_velocity_boost
	)


func _keep_edge_help_forward_velocity_scaled(
	attempt_speed: float,
	keep_multiplier: float,
	help_direction: Vector3,
	allow_forward_boost: bool,
	max_forward_boost: float
) -> void:
	if help_direction == Vector3.ZERO:
		return

	var keep_speed: float = attempt_speed * maxf(keep_multiplier, 0.0)
	if keep_speed <= 0.0:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_horizontal_speed: float = horizontal_velocity.length()
	var forward_direction: Vector3 = help_direction.normalized()
	var forward_speed: float = horizontal_velocity.dot(forward_direction)
	if forward_speed >= keep_speed:
		return

	if not allow_forward_boost:
		return

	var forward_boost: float = minf(keep_speed - forward_speed, maxf(max_forward_boost, 0.0))
	if forward_boost <= 0.0:
		return

	horizontal_velocity += forward_direction * forward_boost

	var max_speed: float = maxf(maxf(_target_speed, keep_speed), current_horizontal_speed)
	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _limit_edge_help_forward_velocity(help_direction: Vector3, max_forward_speed: float) -> void:
	if max_forward_speed < 0.0:
		return
	if help_direction == Vector3.ZERO:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var forward_direction: Vector3 = help_direction.normalized()
	var forward_speed: float = horizontal_velocity.dot(forward_direction)
	if forward_speed <= max_forward_speed:
		return

	horizontal_velocity -= forward_direction * (forward_speed - max_forward_speed)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _register_edge_help_feedback(
	feedback_height: float,
	feedback_multiplier: float = 0.1,
	feedback_time_multiplier: float = 20.0
) -> void:
	var feedback_strength: float = StairFeel.get_step_strength(feedback_height) * maxf(feedback_multiplier, 0.0)
	if feedback_strength <= 0.0:
		return

	_stair_hold_timer = maxf(_stair_hold_timer, StairFeel.stair_state_hold_time * maxf(feedback_time_multiplier, 0.001))
	_stair_blend = maxf(_stair_blend, clampf(StairFeel.stair_enter_blend * 0.85, 0.0, 1.0))
	_stair_step_feedback = maxf(_stair_step_feedback, feedback_strength)
	_recent_stair_step = maxf(_recent_stair_step, feedback_strength)
	_recent_stair_strength = maxf(_recent_stair_strength, feedback_strength)
	_recent_stair_feedback_duration = maxf(
		StairFeel.stair_step_feedback_time * maxf(feedback_time_multiplier, 0.001),
		0.001
	)
	_recent_stair_timer = maxf(_recent_stair_timer, _recent_stair_feedback_duration)


func _register_stair_step(step_height: float) -> void:
	var step_strength: float = StairFeel.get_step_strength(step_height)
	_stair_hold_timer = maxf(_stair_hold_timer, StairFeel.stair_state_hold_time)
	_stair_blend = maxf(_stair_blend, clampf(StairFeel.stair_enter_blend, 0.0, 1.0))

	if _stair_step_cooldown_timer > 0.0:
		return

	_stair_step_cooldown_timer = maxf(_stair_step_cooldown_timer, StairFeel.stair_step_cooldown)
	_stair_step_feedback = maxf(_stair_step_feedback, step_strength)
	_recent_stair_step = maxf(_recent_stair_step, step_strength)
	_recent_stair_strength = maxf(_recent_stair_strength, step_strength)
	_recent_stair_feedback_duration = maxf(StairFeel.stair_step_feedback_time, 0.001)
	_recent_stair_timer = StairFeel.stair_step_feedback_time


func _get_step_attempt_speed(horizontal_speed: float) -> float:
	var input_speed: float = _target_speed * _move_input.length()
	return maxf(horizontal_speed, input_speed)


func _keep_stair_forward_velocity(attempt_speed: float) -> void:
	var keep_speed: float = attempt_speed * StairFeel.stair_velocity_keep_multiplier
	if keep_speed <= 0.0:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed: float = horizontal_velocity.dot(_wish_direction)
	if forward_speed >= keep_speed:
		return

	horizontal_velocity += _wish_direction * (keep_speed - forward_speed)

	var max_speed: float = maxf(_target_speed, keep_speed)
	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _add_step_view_lift(step_height: float, max_visual_height: float) -> void:
	var visual_step_height: float = StairFeel.get_visual_step_height(step_height, max_visual_height)
	if visual_step_height <= 0.0:
		return

	var max_view_offset: float = maxf(max_visual_height, 0.001)
	_step_view_offset = maxf(_step_view_offset - visual_step_height, -max_view_offset)


func _has_step_blocker(probe_distance: float) -> bool:
	if _has_direct_step_blocker(probe_distance):
		return true

	var collision_count: int = get_slide_collision_count()
	for collision_index in range(collision_count):
		var collision: KinematicCollision3D = get_slide_collision(collision_index)
		if _is_step_blocking_normal(collision.get_normal()):
			return true

	return false


func _has_direct_step_blocker(probe_distance: float) -> bool:
	var blocker_collision: KinematicCollision3D = KinematicCollision3D.new()
	var blocker_motion: Vector3 = _wish_direction * probe_distance
	if not test_move(global_transform, blocker_motion, blocker_collision, StairFeel.stair_safe_margin):
		return false

	var normal: Vector3 = blocker_collision.get_normal()
	if _is_step_blocking_normal(normal):
		return true

	return normal.y <= StairFeel.stair_direct_blocker_max_normal_y


func _is_step_blocking_normal(normal: Vector3) -> bool:
	if normal.y > StairFeel.stair_wall_max_normal_y:
		return false

	var horizontal_normal: Vector3 = Vector3(normal.x, 0.0, normal.z)
	if horizontal_normal.length_squared() <= 0.001:
		return false

	var blocking_dot: float = horizontal_normal.normalized().dot(-_wish_direction)
	return blocking_dot >= StairFeel.stair_min_blocking_dot


func _sanitize_physics_transform() -> void:
	var clean_position: Vector3 = global_position
	var clean_yaw: float = global_transform.basis.orthonormalized().get_euler().y

	top_level = true
	scale = Vector3.ONE
	global_transform = Transform3D(Basis(Vector3.UP, clean_yaw), clean_position)


func _needs_physics_transform_sanitize() -> bool:
	if not top_level:
		return true

	var basis_scale: Vector3 = global_transform.basis.get_scale()
	return not basis_scale.is_equal_approx(Vector3.ONE)


func _update_recent_feedback(delta: float) -> void:
	_update_landing_slide_boost_timer(delta)

	if _recent_landing_timer > 0.0:
		var landing_feedback_time: float = maxf(LandingFeel.recent_feedback_time, 0.001)
		_recent_landing_timer = maxf(_recent_landing_timer - delta, 0.0)
		_recent_landing_impact = _recent_landing_strength * (_recent_landing_timer / landing_feedback_time)
	else:
		_recent_landing_impact = 0.0
		_recent_landing_strength = 0.0

	if _recent_jump_timer > 0.0:
		_recent_jump_timer = maxf(_recent_jump_timer - delta, 0.0)
		_recent_jump_feedback = _recent_jump_strength * (_recent_jump_timer / FEEDBACK_MEMORY_TIME)
	else:
		_recent_jump_feedback = 0.0
		_recent_jump_strength = 0.0

	if _recent_crouch_timer > 0.0:
		var crouch_feedback_time: float = maxf(CrouchFeel.recent_feedback_time, 0.001)
		_recent_crouch_timer = maxf(_recent_crouch_timer - delta, 0.0)
		_recent_crouch_feedback = _recent_crouch_strength * (_recent_crouch_timer / crouch_feedback_time)
	else:
		_recent_crouch_feedback = 0.0
		_recent_crouch_strength = 0.0

	if _recent_climb_timer > 0.0:
		var climb_feedback_time: float = maxf(_recent_climb_feedback_duration, 0.001)
		_recent_climb_timer = maxf(_recent_climb_timer - delta, 0.0)
		_recent_climb_feedback = _recent_climb_strength * (_recent_climb_timer / climb_feedback_time)
	else:
		_recent_climb_feedback = 0.0
		_recent_climb_strength = 0.0
		_recent_climb_feedback_duration = 0.0


func _update_step_view_offset(delta: float) -> void:
	var step_blend: float = StairFeel.get_view_recovery_blend(delta)
	_step_view_offset = lerpf(_step_view_offset, 0.0, step_blend)


func _update_edge_help_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_time_since_floor = 0.0
	else:
		_time_since_floor += delta

	if _edge_help_cooldown_timer > 0.0:
		_edge_help_cooldown_timer = maxf(_edge_help_cooldown_timer - delta, 0.0)


func _update_climb_timers(delta: float) -> void:
	if _climb_cooldown_timer > 0.0:
		_climb_cooldown_timer = maxf(_climb_cooldown_timer - delta, 0.0)
	if _edge_hold_cooldown_timer > 0.0:
		_edge_hold_cooldown_timer = maxf(_edge_hold_cooldown_timer - delta, 0.0)


func _update_edge_pull_over_feedback(delta: float) -> void:
	if not _edge_pull_feedback_active or _is_edge_pulling_over:
		return

	_edge_pull_timer += delta
	if ClimbFeel.is_climb_edge_over_feedback_finished(_edge_pull_timer, _edge_pull_duration):
		_edge_pull_feedback_active = false
		_edge_pull_timer = 0.0
		_edge_pull_duration = 0.0
		_edge_pull_strength = 0.0
		_edge_pull_entry_horizontal_speed = 0.0
		_edge_pull_direction = Vector3.ZERO


func _register_recent_climb_feedback(feedback_strength: float, feedback_time_multiplier: float = 1.0) -> void:
	_recent_climb_strength = maxf(feedback_strength, 0.0)
	_recent_climb_feedback = _recent_climb_strength
	_recent_climb_feedback_duration = maxf(
		ClimbFeel.recent_feedback_time * maxf(feedback_time_multiplier, 0.001),
		0.001
	)
	_recent_climb_timer = _recent_climb_feedback_duration


func _update_momentum_timers(delta: float) -> void:
	if _recent_jump_momentum_timer > 0.0:
		_recent_jump_momentum_timer = maxf(_recent_jump_momentum_timer - delta, 0.0)
	else:
		_recent_jump_momentum_speed = 0.0
		_recent_jump_momentum_direction = Vector3.ZERO


func _update_combo_speed(delta: float) -> void:
	if _combo_speed_timer > 0.0:
		_combo_speed_timer = maxf(_combo_speed_timer - delta, 0.0)

	_combo_speed_bonus = MovementRun.get_combo_speed_bonus_after_decay(_combo_speed_bonus, _combo_speed_timer, delta)
	_sync_movement_run_combo_bonus()


func _add_combo_speed_bonus(speed_bonus: float) -> void:
	if speed_bonus <= 0.0:
		return

	_combo_speed_bonus = MovementRun.get_combo_speed_bonus_after_gain(_combo_speed_bonus, speed_bonus)
	_combo_speed_timer = MovementRun.get_combo_speed_hold_time()
	_sync_movement_run_combo_bonus()


func _sync_movement_run_combo_bonus() -> void:
	MovementRun.set_combo_speed_bonus(_combo_speed_bonus)


func _sync_movement_slide_combo_bonus() -> void:
	MovementSlide.set_combo_speed_bonus(_combo_speed_bonus)


func _update_stair_feedback(delta: float) -> void:
	if _stair_step_cooldown_timer > 0.0:
		_stair_step_cooldown_timer = maxf(_stair_step_cooldown_timer - delta, 0.0)

	if _stair_hold_timer > 0.0:
		_stair_hold_timer = maxf(_stair_hold_timer - delta, 0.0)

	var target_stair_blend: float = 0.0
	if _stair_hold_timer > 0.0 and is_on_floor():
		target_stair_blend = 1.0

	var stair_blend_amount: float = StairFeel.get_state_blend(delta)
	_stair_blend = lerpf(_stair_blend, target_stair_blend, stair_blend_amount)

	if _recent_stair_timer > 0.0:
		var feedback_time: float = maxf(_recent_stair_feedback_duration, 0.001)
		_recent_stair_timer = maxf(_recent_stair_timer - delta, 0.0)
		_recent_stair_step = _recent_stair_strength * StairFeel.get_feedback_decay_strength(
			_recent_stair_timer,
			feedback_time
		)
	else:
		_recent_stair_step = 0.0
		_recent_stair_strength = 0.0
		_recent_stair_feedback_duration = 0.0


func _update_landing_feedback(fall_speed_before_slide: float) -> void:
	var landed_this_frame: bool = not _was_on_floor and is_on_floor()
	var landing_drop_height: float = 0.0
	if landed_this_frame:
		landing_drop_height = _get_current_landing_drop_height()
		_cache_landing_drop_height()
		_refresh_landing_momentum()

	var fall_speed: float = absf(fall_speed_before_slide)
	if not landed_this_frame:
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var impact: float = LandingFeel.get_impact_strength(fall_speed, horizontal_speed, _get_sprint_speed_limit())
	LoudnessManger.register_landing(fall_speed, landing_drop_height, impact)
	HealthManager.register_landing(fall_speed)
	if impact <= 0.0:
		return

	_landing_impact = maxf(_landing_impact, impact)
	_recent_landing_impact = maxf(_recent_landing_impact, impact)
	_recent_landing_strength = maxf(_recent_landing_strength, impact)
	_recent_landing_timer = LandingFeel.recent_feedback_time


func _refresh_landing_momentum() -> void:
	if not MovementJump.enable_momentum_links or not MovementSlide.slide_inherit_jump_momentum:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed: float = horizontal_velocity.length()
	if horizontal_speed < MovementSlide.slide_min_jump_momentum_speed:
		return

	_recent_jump_momentum_speed = horizontal_speed
	_recent_jump_momentum_direction = horizontal_velocity.normalized()
	_recent_jump_momentum_timer = maxf(_recent_jump_momentum_timer, MovementSlide.slide_jump_momentum_window)


func _update_hook(delta: float, on_floor: bool) -> void:
	_hook_cooldown_timer = maxf(_hook_cooldown_timer - delta, 0.0)
	if _hook != null and not is_instance_valid(_hook):
		_on_hook_returned()

	if InputManager.is_hook_just_pressed() and _can_throw_hook():
		_throw_hook()
	elif _hook != null and not InputManager.is_hook_pressed():
		_release_hook()

	_hook_reel_input = 0.0
	if _is_hook_anchored:
		_update_hook_rope_wrap(delta)
	if _is_hook_anchored:
		# While anchored, sprint reels in and crouch lets out instead of their normal actions.
		_wants_sprint = false
		_wants_crouch = false
		_update_hook_reel(delta)
		_try_hook_ledge_climb(on_floor)
	if _is_hook_anchored and _hook != null and is_instance_valid(_hook):
		var free_slack: float = _get_hook_free_rope_length() - _get_hook_attach_position().distance_to(_get_hook_pivot())
		_hook.call(METHOD_HOOK_SET_ROPE_SLACK, free_slack)
	if not _is_hook_anchored and _hook != null and is_instance_valid(_hook):
		# A hook that hasn't caught stays put until the player pulls it in with the reel key.
		var is_pulling_hook: bool = InputManager.is_sprint_pressed()
		if is_pulling_hook:
			_wants_sprint = false
		_hook.call(METHOD_HOOK_SET_PULLING, is_pulling_hook)

	var is_holding_hook: bool = _hook != null and StringName(_hook.call(METHOD_HOOK_GET_STATE)) != HOOK_STATE_REELING
	_hook_hold_blend = HookFeel.get_blend(_hook_hold_blend, 1.0 if is_holding_hook else 0.0, delta)
	_hook_swing_blend = HookFeel.get_blend(_hook_swing_blend, 1.0 if _is_hook_anchored and not on_floor else 0.0, delta)


func _can_throw_hook() -> bool:
	if not MovementHook.enable_hook or hook_scene == null:
		return false
	if _hook != null or _hook_cooldown_timer > 0.0:
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	return not _is_climbing and not _is_edge_holding and not _is_edge_pulling_over


func _throw_hook() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	# Aim through the screen center, then throw from the hand toward that point.
	var camera_origin: Vector3 = camera.global_position
	var aim_direction: Vector3 = -camera.global_basis.z.normalized()
	var aim_end: Vector3 = camera_origin + aim_direction * maxf(MovementHook.max_rope_length, 0.1)
	var aim_hit: Dictionary = _raycast_climb_segment(camera_origin, aim_end)
	var aim_point: Vector3 = aim_end if aim_hit.is_empty() else Vector3(aim_hit.position)
	var hand_position: Vector3 = camera.global_transform * MovementHook.hand_offset
	var spawn_position: Vector3 = camera_origin
	var throw_direction: Vector3 = aim_direction
	# If the hand is poking into a wall, throw from the camera so the hook can't start inside it.
	var hand_blocked: bool = not _raycast_climb_segment(camera_origin, hand_position).is_empty()
	if not hand_blocked and camera_origin.distance_to(aim_point) > 1.0:
		spawn_position = hand_position
		throw_direction = (aim_point - hand_position).normalized()

	var hook: Node3D = hook_scene.instantiate() as Node3D
	if hook == null:
		return
	var hook_parent: Node = get_tree().current_scene
	if hook_parent == null:
		hook_parent = get_tree().root
	hook_parent.add_child(hook)
	hook.connect(&"anchored", _on_hook_anchored)
	hook.connect(&"returned", _on_hook_returned)
	hook.connect(&"rope_snapped", _on_hook_rope_snapped)

	var exclude: Array[RID] = [get_rid()]
	var throw_velocity: Vector3 = throw_direction * maxf(MovementHook.throw_speed, 0.0)
	throw_velocity += velocity * clampf(MovementHook.inherit_player_velocity, 0.0, 1.0)
	hook.call(METHOD_HOOK_LAUNCH, spawn_position, throw_velocity, camera, MovementHook.hand_offset, exclude)
	_hook = hook
	_hook_throw_feedback = 1.0
	LoudnessManger.register_sound(MovementHook.throw_loudness)


func _on_hook_anchored(anchor_point: Vector3) -> void:
	if _is_climbing or _is_edge_holding or _is_edge_pulling_over:
		_release_hook()
		return

	_is_hook_anchored = true
	_hook_anchor = anchor_point
	_clear_hook_rope_wrap()
	var attach_position: Vector3 = _get_hook_attach_position()
	if _hook != null and is_instance_valid(_hook):
		_adopt_hook_rope_wraps(PackedVector3Array(_hook.call(METHOD_HOOK_GET_ANCHOR_WRAPS)), attach_position)
	var pivot: Vector3 = _get_hook_pivot()
	var min_free_length: float = maxf(MovementHook.min_free_rope_length, 0.1)
	_rope_length = clampf(
		_hook_wrap_fixed_length + attach_position.distance_to(pivot),
		maxf(MovementHook.min_rope_length, _hook_wrap_fixed_length + min_free_length),
		maxf(MovementHook.max_rope_length, _hook_wrap_fixed_length + min_free_length)
	)
	_hook_last_clear_attach = attach_position
	_has_hook_clear_attach = _raycast_climb_segment(attach_position, pivot).is_empty()
	if not _has_hook_clear_attach:
		# The hook checked its line from the hand; the body's attach point sits a little lower and
		# can graze a corner the hand clears. Start from the hand so that corner gets wrapped.
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			var hand_position: Vector3 = camera.global_transform * MovementHook.hand_offset
			if _raycast_climb_segment(hand_position, pivot).is_empty():
				_hook_last_clear_attach = hand_position
				_has_hook_clear_attach = true
	_hook_rope_blocked_timer = 0.0
	_hook_catch_feedback = 1.0
	_stop_wall_run()
	LoudnessManger.register_sound(MovementHook.catch_loudness)


func _on_hook_rope_snapped(strength: float) -> void:
	_hook_snap_feedback = maxf(_hook_snap_feedback, strength)


func _on_hook_returned() -> void:
	_hook = null
	_is_hook_anchored = false
	_hook_reel_input = 0.0
	_hook_cooldown_timer = maxf(MovementHook.throw_cooldown, 0.0)
	_clear_hook_rope_wrap()
	floor_snap_length = maxf(MovementWalk.floor_snap_length, 0.0)


func _release_hook(with_jump: bool = false) -> void:
	var was_anchored: bool = _is_hook_anchored
	_is_hook_anchored = false
	_hook_reel_input = 0.0
	_hook_rope_blocked_timer = 0.0
	_clear_hook_rope_wrap()
	floor_snap_length = maxf(MovementWalk.floor_snap_length, 0.0)
	if _hook != null and is_instance_valid(_hook):
		_hook.call(METHOD_HOOK_RELEASE)

	if not with_jump or not was_anchored:
		return

	velocity = MovementHook.get_release_velocity(velocity)
	_stop_variable_jump()
	var jump_feedback_strength: float = maxf(JumpFeel.jump_feedback_multiplier, 0.0)
	_jump_feedback = jump_feedback_strength
	_recent_jump_feedback = jump_feedback_strength
	_recent_jump_strength = jump_feedback_strength
	_recent_jump_timer = FEEDBACK_MEMORY_TIME
	LoudnessManger.register_jump(false, false, false, Vector2(velocity.x, velocity.z).length())


func _update_hook_reel(delta: float) -> void:
	var reel_input: float = 0.0
	if InputManager.is_sprint_pressed() and StaminaManager.can_hook_reel():
		reel_input += 1.0
	if InputManager.is_crouch_pressed():
		reel_input -= 1.0

	# Rope wrapped around corners is fixed; only the free part after the last corner can be reeled.
	var min_free_length: float = maxf(MovementHook.min_free_rope_length, 0.1)
	var min_length: float = maxf(MovementHook.min_rope_length, _hook_wrap_fixed_length + min_free_length)
	var max_length: float = maxf(MovementHook.max_rope_length, _hook_wrap_fixed_length + min_free_length)
	if reel_input > 0.0:
		if _rope_length <= min_length:
			return
		# Slack rope is taken up first so reeling responds right away.
		var free_distance: float = _get_hook_attach_position().distance_to(_get_hook_pivot())
		_rope_length = minf(_rope_length, _hook_wrap_fixed_length + free_distance) - maxf(MovementHook.reel_in_speed, 0.0) * delta
	elif reel_input < 0.0:
		_rope_length += maxf(MovementHook.reel_out_speed, 0.0) * delta

	_rope_length = clampf(_rope_length, min_length, max_length)
	_hook_reel_input = reel_input


## Reeled up to the ledge the rope hangs from: climb over it with the regular edge pull-over.
func _try_hook_ledge_climb(on_floor: bool) -> void:
	if not MovementHook.enable_rope_ledge_climb or on_floor:
		return
	var wants_climb: bool = InputManager.is_sprint_pressed() or _move_input.y <= -MovementHook.ledge_climb_forward_input
	if not wants_climb or not StaminaManager.can_climb():
		return

	var pivot: Vector3 = _get_hook_pivot()
	if _get_hook_attach_position().distance_to(pivot) > MovementHook.ledge_grab_max_distance:
		return

	var to_pivot: Vector3 = pivot - global_position
	to_pivot.y = 0.0
	var climb_probe_direction: Vector3 = _get_player_forward_direction()
	if to_pivot.length_squared() > 0.01:
		climb_probe_direction = to_pivot.normalized()

	var ledge_result: Dictionary = _find_climb_edge_hold_result(climb_probe_direction, 0.0, MovementHook.ledge_grab_reach)
	if ledge_result.is_empty():
		return

	var entry_horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_release_hook()
	_climb_direction = Vector3(ledge_result.get("climb_direction", climb_probe_direction))
	# A rope climb has no run-up to carry the body onto the ledge, so end it further in.
	ledge_result["position"] = _get_edge_help_pulled_position(
		Vector3(ledge_result.get("position", global_position)),
		_climb_direction,
		MovementHook.ledge_climb_pull_distance
	)
	_apply_climb_edge_result(ledge_result, entry_horizontal_speed, entry_horizontal_speed)


## Keeps the rope's path around corners: wraps when the rope hits a new corner,
## unwraps when the player swings back past the last one.
func _update_hook_rope_wrap(delta: float) -> void:
	var attach_position: Vector3 = _get_hook_attach_position()
	_try_unwrap_hook_rope(attach_position)

	var pivot: Vector3 = _get_hook_pivot()
	if _raycast_climb_segment(attach_position, pivot).is_empty():
		_hook_rope_blocked_timer = 0.0
		_hook_last_clear_attach = attach_position
		_has_hook_clear_attach = true
		return

	if _has_hook_clear_attach and _try_wrap_hook_rope(attach_position, pivot):
		_hook_rope_blocked_timer = 0.0
		_hook_last_clear_attach = attach_position
		return

	# Fallback when no clean corner can be found: the rope breaks after a short delay.
	_hook_rope_blocked_timer += delta
	if _hook_rope_blocked_timer >= MovementHook.rope_blocked_break_time:
		_release_hook()


func _try_wrap_hook_rope(attach_position: Vector3, pivot: Vector3) -> bool:
	if _hook_wrap_points.size() >= MovementHook.max_wrap_points:
		return false

	# Narrow down where between last tick's clear rope and this tick's blocked rope the corner sits.
	var clear_attach: Vector3 = _hook_last_clear_attach
	var blocked_attach: Vector3 = attach_position
	for i in 12:
		var middle_attach: Vector3 = clear_attach.lerp(blocked_attach, 0.5)
		if _raycast_climb_segment(middle_attach, pivot).is_empty():
			clear_attach = middle_attach
		else:
			blocked_attach = middle_attach

	var corner_hit: Dictionary = _raycast_climb_segment(blocked_attach, pivot)
	if corner_hit.is_empty():
		return false

	var corner: Vector3 = Vector3(corner_hit.position)
	var corner_normal: Vector3 = Vector3(corner_hit.normal)
	# Push the wrap point back the way the rope swept in from, so it sits just clear of the edge.
	# Use this tick's whole sweep: the bisected pair is too close together for float precision.
	var rope_direction: Vector3 = (corner - pivot).normalized()
	var away_from_corner: Vector3 = _hook_last_clear_attach - attach_position
	away_from_corner -= rope_direction * away_from_corner.dot(rope_direction)
	if away_from_corner.length_squared() < 0.0000000001:
		away_from_corner = corner_normal
	var offset: float = maxf(MovementHook.wrap_point_offset, 0.0)
	var wrap_point: Vector3 = corner + away_from_corner.normalized() * offset + corner_normal * offset * 0.5
	if not _raycast_climb_segment(wrap_point, pivot).is_empty():
		return false
	if not _raycast_climb_segment(attach_position, wrap_point).is_empty():
		return false

	var bend_side: Vector3 = (wrap_point - pivot).cross(attach_position - wrap_point)
	if bend_side.length_squared() < 0.000001:
		return false

	_hook_wrap_points.append(wrap_point)
	_hook_wrap_sides.append(bend_side.normalized())
	_hook_wrap_fixed_length += pivot.distance_to(wrap_point)
	_sync_hook_rope_wrap_visual()
	return true


func _try_unwrap_hook_rope(attach_position: Vector3) -> void:
	while not _hook_wrap_points.is_empty():
		var wrap_count: int = _hook_wrap_points.size()
		var wrap_point: Vector3 = _hook_wrap_points[wrap_count - 1]
		var previous_point: Vector3 = _hook_anchor if wrap_count == 1 else _hook_wrap_points[wrap_count - 2]
		# The rope still presses on the corner while it bends the same way it did when it wrapped.
		var bend_side: Vector3 = (wrap_point - previous_point).cross(attach_position - wrap_point)
		if bend_side.dot(_hook_wrap_sides[wrap_count - 1]) > 0.0:
			return
		if not _raycast_climb_segment(attach_position, previous_point).is_empty():
			return

		_hook_wrap_fixed_length = maxf(_hook_wrap_fixed_length - previous_point.distance_to(wrap_point), 0.0)
		_hook_wrap_points.pop_back()
		_hook_wrap_sides.pop_back()
		_sync_hook_rope_wrap_visual()


## Takes over the corners the thrown rope already bends over (ordered anchor -> player),
## so the swing pivots on the right corner from the first tick.
func _adopt_hook_rope_wraps(points: PackedVector3Array, attach_position: Vector3) -> void:
	var previous_point: Vector3 = _hook_anchor
	for i in points.size():
		var wrap_point: Vector3 = points[i]
		var next_point: Vector3 = attach_position if i == points.size() - 1 else points[i + 1]
		var bend_side: Vector3 = (wrap_point - previous_point).cross(next_point - wrap_point)
		if bend_side.length_squared() < 0.000001:
			continue
		_hook_wrap_points.append(wrap_point)
		_hook_wrap_sides.append(bend_side.normalized())
		_hook_wrap_fixed_length += previous_point.distance_to(wrap_point)
		previous_point = wrap_point
	_sync_hook_rope_wrap_visual()


func _clear_hook_rope_wrap() -> void:
	_hook_wrap_points.clear()
	_hook_wrap_sides.clear()
	_hook_wrap_fixed_length = 0.0
	_has_hook_clear_attach = false
	_sync_hook_rope_wrap_visual()


func _sync_hook_rope_wrap_visual() -> void:
	if _hook == null or not is_instance_valid(_hook):
		return
	_hook.call(METHOD_HOOK_SET_WRAP_POINTS, PackedVector3Array(_hook_wrap_points))


func _get_hook_pivot() -> Vector3:
	if _hook_wrap_points.is_empty():
		return _hook_anchor
	return _hook_wrap_points[_hook_wrap_points.size() - 1]


func _get_hook_free_rope_length() -> float:
	return maxf(_rope_length - _hook_wrap_fixed_length, maxf(MovementHook.min_free_rope_length, 0.1))


func _apply_hook_swing_movement(delta: float) -> void:
	var attach_position: Vector3 = _get_hook_attach_position()
	var pivot: Vector3 = _get_hook_pivot()
	if MovementHook.is_rope_taut(attach_position, pivot, _get_hook_free_rope_length()):
		velocity += MovementHook.get_pump_velocity(_wish_direction, attach_position, pivot, delta)
	else:
		_apply_air_movement(_wish_direction, _target_speed, delta)
	velocity = MovementHook.get_swing_velocity(velocity, delta)


func _apply_hook_rope_velocity_constraint() -> void:
	if not _is_hook_anchored:
		return

	var attach_position: Vector3 = _get_hook_attach_position()
	var pivot: Vector3 = _get_hook_pivot()
	var free_length: float = _get_hook_free_rope_length()
	var is_taut: bool = MovementHook.is_rope_taut(attach_position, pivot, free_length)
	# Floor snap would pull the body back down while the rope is lifting it.
	floor_snap_length = 0.0 if is_taut else maxf(MovementWalk.floor_snap_length, 0.0)
	velocity = MovementHook.get_rope_constrained_velocity(velocity, attach_position, pivot, free_length)


func _apply_hook_rope_position_correction() -> void:
	if not _is_hook_anchored:
		return

	var offset: Vector3 = _get_hook_attach_position() - _get_hook_pivot()
	var stretch: float = offset.length() - _get_hook_free_rope_length()
	if stretch <= 0.001:
		return
	# Slide along whatever blocks the pull, e.g. the wall below the ledge, instead of stopping on it.
	var collision: KinematicCollision3D = move_and_collide(-offset.normalized() * stretch)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))


func _get_hook_attach_position() -> Vector3:
	return global_position + Vector3.UP * MovementHook.body_attach_height
