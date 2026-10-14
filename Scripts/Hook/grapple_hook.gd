extends Node3D
## Thrown grappling hook.
## Flies out on an arc until it reaches the rope length or hits something. Landing on an
## upward-facing top surface above the hand catches right away. Otherwise it lies or hangs on
## slack rope until the player pulls it in (set_pulling); a pulled hook is dragged over
## surfaces and can still catch on a top or a lip on the way.
## The rope bends over any corner between the hook and the hand, so the hook is always
## pulled along the rope's real path and never through walls.
## Tuning lives in the MovementHook autoload. The player drives it with release().

signal anchored(anchor_point: Vector3)
signal returned
## The thrown rope ran out and jerked taut. strength is 0..1.
signal rope_snapped(strength: float)

const STATE_FLYING: StringName = &"flying"
const STATE_RETRACTING: StringName = &"retracting"
const STATE_REELING: StringName = &"reeling"
const STATE_ANCHORED: StringName = &"anchored"
const STATE_RETURNED: StringName = &"returned"

@export_group("Nodes")
@export var model_path: NodePath = NodePath("Model")
@export var rope_path: NodePath = NodePath("Rope")
@export var catch_sound_path: NodePath = NodePath("CatchSound")

@export_group("Sound")
## Clanks played when the hook catches a ledge; one is picked at random each time.
@export var catch_sounds: Array[AudioStream] = []

var _state: StringName = STATE_FLYING
var _velocity: Vector3 = Vector3.ZERO
var _hand_node: Node3D
var _hand_offset: Vector3 = Vector3.ZERO
var _exclude: Array[RID] = []
var _is_supported: bool = false
var _is_climbing_wall: bool = false
var _wall_normal: Vector3 = Vector3.ZERO
var _rope_out: float = 0.0
var _rope_path_length: float = 0.0
var _is_pulling: bool = false
## Corners the rope bent over when the hook anchored, ordered from the anchor toward the hand.
var _anchor_wraps: PackedVector3Array = PackedVector3Array()
var _anchor_point: Vector3 = Vector3.ZERO
var _model: Node3D
var _rope: MeshInstance3D
var _catch_sound: AudioStreamPlayer3D
## Player-owned corners while anchored, ordered from the anchor toward the player.
var _wrap_points: PackedVector3Array = PackedVector3Array()
## Hook-owned corners before anchoring, ordered from the hand toward the hook.
var _hook_wraps: PackedVector3Array = PackedVector3Array()
var _hook_wrap_sides: PackedVector3Array = PackedVector3Array()
var _last_clear_hook_position: Vector3 = Vector3.ZERO
var _has_clear_hook_position: bool = false
var _rope_segments: Array[MeshInstance3D] = []
## Slack in the free rope while anchored, sent by the player; drives how much the rope sags.
var _anchored_slack: float = 0.0
var _has_rope_snapped: bool = false


func _ready() -> void:
	_model = get_node_or_null(model_path) as Node3D
	_rope = get_node_or_null(rope_path) as MeshInstance3D
	_catch_sound = get_node_or_null(catch_sound_path) as AudioStreamPlayer3D
	if _rope != null:
		_rope.top_level = true
		_rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_rope_segments.append(_rope)


## hand_node is usually the player camera; hand_offset is in its local space.
func launch(from: Vector3, start_velocity: Vector3, hand_node: Node3D, hand_offset: Vector3, exclude: Array[RID] = []) -> void:
	_hand_node = hand_node
	_hand_offset = hand_offset
	_exclude = exclude
	_velocity = start_velocity
	_state = STATE_FLYING
	global_position = from
	_last_clear_hook_position = from
	_has_clear_hook_position = true
	_face_direction(start_velocity)
	reset_physics_interpolation()


func release() -> void:
	if _state == STATE_RETURNED:
		return
	if _state == STATE_ANCHORED and not _wrap_points.is_empty():
		# Reel back along the rope's wrapped path instead of straight through the corners.
		_hook_wraps.clear()
		_hook_wrap_sides.clear()
		for i in range(_wrap_points.size() - 1, -1, -1):
			_hook_wraps.append(_wrap_points[i])
			_hook_wrap_sides.append(Vector3.ZERO)
	_wrap_points.clear()
	_state = STATE_REELING


## The player owns the rope path while anchored; the hook only draws it.
func set_wrap_points(points: PackedVector3Array) -> void:
	_wrap_points = points


func set_rope_slack(slack: float) -> void:
	_anchored_slack = maxf(slack, 0.0)


## True while the player is pulling the rope in. A hook that has not caught stays put otherwise.
func set_pulling(pulling: bool) -> void:
	_is_pulling = pulling


func get_anchor_wraps() -> PackedVector3Array:
	return _anchor_wraps


## Rope paid out between the hand and the hook along its wrapped path. 0 once anchored;
## the player owns the rope length from then on.
func get_rope_out_length() -> float:
	if _state == STATE_ANCHORED or _state == STATE_RETURNED or _hand_node == null or not is_instance_valid(_hand_node):
		return 0.0
	var hand_position: Vector3 = _get_hand_position()
	return _get_wrapped_rope_length(hand_position) + global_position.distance_to(_get_rope_pivot(hand_position))


func get_state() -> StringName:
	return _state


func get_anchor_point() -> Vector3:
	return _anchor_point


func get_hook_position() -> Vector3:
	return global_position


func _physics_process(delta: float) -> void:
	if _hand_node == null or not is_instance_valid(_hand_node):
		queue_free()
		return

	match _state:
		STATE_FLYING:
			_update_flying(delta)
		STATE_RETRACTING:
			_update_retracting(delta)
		STATE_REELING:
			_update_reeling(delta)
		STATE_ANCHORED:
			global_position = _anchor_point


func _process(_delta: float) -> void:
	_update_rope_visual()


func _update_flying(delta: float) -> void:
	_velocity.y -= maxf(MovementHook.hook_gravity, 0.0) * delta
	var hand_position: Vector3 = _get_hand_position()
	var pivot: Vector3 = _get_rope_pivot(hand_position)
	var wrapped_length: float = _get_wrapped_rope_length(hand_position)
	var max_length: float = maxf(MovementHook.max_rope_length, 0.1)
	_apply_rope_payout_drag(pivot, wrapped_length, max_length, delta)
	var is_stretched: bool = _apply_rope_stretch(pivot, wrapped_length, max_length, delta)

	var from: Vector3 = global_position
	var to: Vector3 = from + _velocity * delta
	var free_limit: float = maxf(max_length + maxf(MovementHook.rope_max_stretch, 0.0) - wrapped_length, 0.05)
	if to.distance_to(pivot) > free_limit:
		to = pivot + (to - pivot).normalized() * free_limit

	var hit: Dictionary = _raycast(from, to)
	if not hit.is_empty():
		_settle_on_hit(hit)
		_update_hook_rope_wrap(hand_position)
		if _is_supported and _try_catch_on_surface():
			return
		_start_retract()
		return

	global_position = to
	_face_direction(_velocity)
	_update_hook_rope_wrap(hand_position)
	_rope_path_length = _get_wrapped_rope_length(hand_position) + global_position.distance_to(_get_rope_pivot(hand_position))
	# Once the stretched rope has stopped the hook and starts pulling it back, the throw is over.
	if is_stretched and _velocity.dot((to - pivot).normalized()) <= 0.0:
		_start_retract()


## The trailing rope gets heavier as more of it is paid out, slowing the hook before it runs out.
func _apply_rope_payout_drag(pivot: Vector3, wrapped_length: float, max_length: float, delta: float) -> void:
	var to_hook: Vector3 = global_position - pivot
	var distance: float = to_hook.length()
	if distance <= 0.001:
		return

	var outward: Vector3 = to_hook / distance
	var outward_speed: float = _velocity.dot(outward)
	if outward_speed <= 0.0:
		return
	var payout_ratio: float = clampf((wrapped_length + distance) / max_length, 0.0, 1.0)
	var drag: float = maxf(MovementHook.rope_payout_drag, 0.0) * payout_ratio * payout_ratio * delta
	_velocity -= outward * minf(outward_speed, drag)


## Past full length the rope stretches like a stiff spring: it brakes the hook over a short
## distance and springs it back, instead of stopping it dead. Returns true while stretched.
func _apply_rope_stretch(pivot: Vector3, wrapped_length: float, max_length: float, delta: float) -> bool:
	var to_hook: Vector3 = global_position - pivot
	var distance: float = to_hook.length()
	var stretch: float = wrapped_length + distance - max_length
	if stretch <= 0.0 or distance <= 0.001:
		return false

	var outward: Vector3 = to_hook / distance
	if not _has_rope_snapped:
		_has_rope_snapped = true
		var snap_strength: float = clampf(_velocity.dot(outward) / maxf(MovementHook.throw_speed, 0.001), 0.0, 1.0)
		rope_snapped.emit(snap_strength)

	_velocity -= outward * stretch * maxf(MovementHook.rope_stretch_stiffness, 0.0) * delta
	var outward_speed: float = _velocity.dot(outward)
	_velocity -= outward * outward_speed * (1.0 - exp(-maxf(MovementHook.rope_stretch_damping, 0.0) * delta))
	return true


func _start_retract() -> void:
	_state = STATE_RETRACTING
	var hand_position: Vector3 = _get_hand_position()
	_rope_out = _get_wrapped_rope_length(hand_position) + global_position.distance_to(_get_rope_pivot(hand_position))


func _update_retracting(delta: float) -> void:
	var hand_position: Vector3 = _get_hand_position()
	_update_hook_rope_wrap(hand_position)
	if _hook_wraps.is_empty() and global_position.distance_to(hand_position) <= MovementHook.return_distance:
		_finish_return()
		return

	var pivot: Vector3 = _get_rope_pivot(hand_position)
	var wrapped_length: float = _get_wrapped_rope_length(hand_position)
	var free_distance: float = global_position.distance_to(pivot)
	_rope_path_length = wrapped_length + free_distance

	if not _is_pulling:
		# Nobody is pulling: the rope pays out freely up to its full length and the hook just
		# lies or hangs where it is. It can still fall onto a top surface and catch there.
		_rope_out = maxf(MovementHook.max_rope_length, _rope_path_length)
		_is_climbing_wall = false
		if not _is_supported:
			_update_hanging(delta, pivot, maxf(_rope_out - wrapped_length, 0.05))
		_try_catch_after_move(hand_position)
		return

	# The player pulls the rope in along its wrapped path; slack rope is taken up first.
	_rope_out = minf(_rope_out, _rope_path_length)
	_rope_out = maxf(_rope_out - maxf(MovementHook.retract_speed, 0.0) * delta, 0.0)

	# Pulled right up to a corner while hanging or climbing: the hook goes over it.
	if not _is_supported and not _hook_wraps.is_empty() and free_distance <= MovementHook.wrap_pass_distance:
		_pass_over_wrap(hand_position)
		_try_catch_after_move(hand_position)
		return

	if _is_climbing_wall:
		_update_wall_climb(delta)
	elif _is_supported:
		_update_supported_drag(delta, pivot, hand_position)
	else:
		_update_hanging(delta, pivot, maxf(_rope_out - wrapped_length, 0.05))
	_try_catch_after_move(hand_position)


func _try_catch_after_move(hand_position: Vector3) -> void:
	if _state != STATE_RETRACTING or not _is_supported:
		return
	_update_hook_rope_wrap(hand_position)
	_try_catch_on_surface()


## The hook rests on an upward-facing top surface (ground included): anchor right here.
## When the rope runs over the edge nearest the player, it anchors on that edge instead.
func _try_catch_on_surface() -> bool:
	if not MovementHook.catch_on_top_surfaces:
		return false
	var hand_position: Vector3 = _get_hand_position()
	var radius: float = maxf(MovementHook.hook_radius, 0.01)
	var offset: float = maxf(MovementHook.anchor_surface_offset, 0.0)
	var anchor: Vector3 = global_position + Vector3.UP * (offset - radius)
	if _hook_wraps.is_empty():
		if _raycast(hand_position, anchor).is_empty():
			_anchor_at(anchor, anchor - hand_position, false)
			return true
		# The rope runs over this surface's edge on the way to the hand: catch on that edge.
		return _try_anchor_on_lip_toward(hand_position)

	var pivot: Vector3 = _get_rope_pivot(hand_position)
	if _raycast_rope(pivot, anchor).is_empty():
		_anchor_at(anchor, anchor - pivot, true)
		return true
	return false


## Walks across the top surface toward the hand until it runs out, then anchors on that lip.
func _try_anchor_on_lip_toward(hand_position: Vector3) -> bool:
	var to_hand: Vector3 = hand_position - global_position
	var direction: Vector3 = Vector3(to_hand.x, 0.0, to_hand.z).normalized()
	if direction == Vector3.ZERO:
		return false

	var radius: float = maxf(MovementHook.hook_radius, 0.01)
	var step: float = 0.1
	var probe_depth: float = maxf(MovementHook.support_probe_depth, MovementHook.min_lip_height)
	var probe_position: Vector3 = global_position
	var top_y: float = probe_position.y - radius
	var travelled: float = 0.0
	while travelled < MovementHook.surface_catch_lip_search_distance:
		var next_position: Vector3 = probe_position + direction * step
		if not _raycast(probe_position, next_position + direction * radius).is_empty():
			return false
		var floor_hit: Dictionary = _raycast(next_position + Vector3.UP * radius, next_position + Vector3.DOWN * (probe_depth + radius))
		if floor_hit.is_empty() or not MovementHook.is_support_normal(Vector3(floor_hit.normal)):
			var edge_point: Vector3 = _find_edge_point(next_position, direction, top_y, step + radius * 2.0)
			return _try_anchor(edge_point, hand_position)
		probe_position = Vector3(next_position.x, Vector3(floor_hit.position).y + radius, next_position.z)
		top_y = probe_position.y - radius
		travelled += step
	return false


## Hook lies on a top surface and is dragged along the rope until it reaches a lip.
func _update_supported_drag(delta: float, pivot: Vector3, hand_position: Vector3) -> void:
	var to_pivot: Vector3 = pivot - global_position
	var drag_direction: Vector3 = Vector3(to_pivot.x, 0.0, to_pivot.z).normalized()
	if drag_direction == Vector3.ZERO:
		_is_supported = false
		return

	var step: float = maxf(MovementHook.retract_speed, 0.0) * delta
	var radius: float = maxf(MovementHook.hook_radius, 0.01)
	var next_position: Vector3 = global_position + drag_direction * step
	var blocked_hit: Dictionary = _raycast(global_position, next_position + drag_direction * radius)
	if not blocked_hit.is_empty():
		# The rope runs over this wall, so it pulls the hook up the face.
		_start_wall_climb(Vector3(blocked_hit.normal))
		return

	var top_y: float = global_position.y - radius
	var probe_depth: float = maxf(MovementHook.support_probe_depth, MovementHook.min_lip_height)
	var floor_hit: Dictionary = _raycast(next_position + Vector3.UP * radius, next_position + Vector3.DOWN * (probe_depth + radius))
	if not floor_hit.is_empty() and MovementHook.is_support_normal(Vector3(floor_hit.normal)):
		global_position = Vector3(floor_hit.position) + Vector3(floor_hit.normal) * radius
		_face_direction(-drag_direction)
		return

	# No floor past this point: the hook is at a lip.
	var edge_point: Vector3 = _find_edge_point(next_position, drag_direction, top_y, step + radius * 2.0)
	if _try_anchor(edge_point, hand_position):
		return

	global_position = next_position
	_velocity = drag_direction * maxf(MovementHook.retract_speed, 0.0)
	_is_supported = false


## Hook hangs or falls from the rope like a pendulum around its pivot while the rope shortens.
func _update_hanging(delta: float, pivot: Vector3, free_rope: float) -> void:
	_velocity.y -= maxf(MovementHook.hook_gravity, 0.0) * delta
	_velocity *= exp(-maxf(MovementHook.hook_air_drag, 0.0) * delta)
	var from: Vector3 = global_position
	var to: Vector3 = from + _velocity * delta
	var offset: Vector3 = to - pivot
	if offset.length() > free_rope:
		to = pivot + offset.normalized() * free_rope

	var hit: Dictionary = _raycast(from, to)
	if hit.is_empty():
		global_position = to
		# Velocity from the actual move, so the rope's pull shows up in it. Not after a hit:
		# the snap out to the surface isn't real motion and would read as a sideways jolt.
		if delta > 0.0:
			_velocity = (global_position - from) / delta
	else:
		_settle_on_hit(hit)
		var hit_normal: Vector3 = Vector3(hit.normal)
		# A wall between the hook and where the rope leads means the rope runs over it: climb the face.
		if not _is_supported and hit_normal.dot(pivot - global_position) < 0.0:
			_start_wall_climb(hit_normal)
			return
	_face_direction(_velocity)


func _start_wall_climb(wall_normal: Vector3) -> void:
	var flat_normal: Vector3 = Vector3(wall_normal.x, 0.0, wall_normal.z)
	if flat_normal.length_squared() < 0.0001:
		_state = STATE_REELING
		return
	_wall_normal = flat_normal.normalized()
	_is_climbing_wall = true
	_is_supported = false
	_velocity = Vector3.ZERO


## Hook is pulled up a wall face by the rope until it tips over the top.
func _update_wall_climb(delta: float) -> void:
	var step: float = maxf(MovementHook.retract_speed, 0.0) * delta
	var radius: float = maxf(MovementHook.hook_radius, 0.01)
	var into_wall: Vector3 = -_wall_normal
	var next_position: Vector3 = global_position + Vector3.UP * step
	if not _raycast(global_position, next_position + Vector3.UP * radius).is_empty():
		# Stuck under an overhang.
		_is_climbing_wall = false
		_state = STATE_REELING
		return

	var wall_hit: Dictionary = _raycast(next_position, next_position + into_wall * radius * 3.0)
	if not wall_hit.is_empty():
		global_position = Vector3(wall_hit.position) + Vector3(wall_hit.normal) * radius
		_face_direction(Vector3.UP)
		return

	# Cleared the top of the wall: rise clear of the top, then tip over onto it.
	var over_position: Vector3 = next_position + into_wall * radius * 3.0
	var floor_hit: Dictionary = _raycast(over_position + Vector3.UP * radius, over_position + Vector3.DOWN * (radius * 4.0 + step))
	var has_top: bool = not floor_hit.is_empty() and MovementHook.is_support_normal(Vector3(floor_hit.normal))
	if has_top:
		var clear_height: float = Vector3(floor_hit.position).y + radius
		if global_position.y < clear_height - 0.001:
			global_position.y = clear_height
			return
		global_position = Vector3(floor_hit.position) + Vector3(floor_hit.normal) * radius
		_is_supported = true
	else:
		global_position = over_position
		_velocity = Vector3.ZERO
	_is_climbing_wall = false


## Hook reached the corner the rope bends over: it is pulled over it and continues toward the next point.
func _pass_over_wrap(hand_position: Vector3) -> void:
	var corner: Vector3 = _hook_wraps[_hook_wraps.size() - 1]
	_pop_hook_wrap()
	var toward_next: Vector3 = _get_rope_pivot(hand_position) - corner
	toward_next.y = 0.0
	var radius: float = maxf(MovementHook.hook_radius, 0.01)
	var over_position: Vector3 = corner + Vector3.UP * radius
	if toward_next.length_squared() > 0.0001:
		over_position += toward_next.normalized() * radius * 2.0

	var path_hit: Dictionary = _raycast(global_position, over_position)
	if path_hit.is_empty():
		global_position = over_position
	else:
		_settle_on_hit(path_hit)
	_is_climbing_wall = false
	_velocity = Vector3.ZERO
	var floor_hit: Dictionary = _raycast(global_position + Vector3.UP * radius, global_position + Vector3.DOWN * radius * 4.0)
	_is_supported = not floor_hit.is_empty() and MovementHook.is_support_normal(Vector3(floor_hit.normal))
	if _is_supported:
		global_position = Vector3(floor_hit.position) + Vector3(floor_hit.normal) * radius
	_last_clear_hook_position = corner
	_has_clear_hook_position = true


func _update_reeling(delta: float) -> void:
	var hand_position: Vector3 = _get_hand_position()
	var step: float = maxf(MovementHook.cancel_reel_speed, 0.0) * delta
	# Corners can still appear while reeling, e.g. when the player moves behind a wall.
	if _has_clear_hook_position:
		var pivot: Vector3 = _get_rope_pivot(hand_position)
		if _raycast_rope(pivot, global_position).is_empty():
			_last_clear_hook_position = global_position
		else:
			_try_wrap_hook_rope(pivot)
	# Follow the rope's path corner by corner so the hook never cuts through walls.
	while not _hook_wraps.is_empty():
		var corner: Vector3 = _hook_wraps[_hook_wraps.size() - 1]
		var corner_distance: float = global_position.distance_to(corner)
		if corner_distance > step:
			_face_direction(global_position - corner)
			global_position = global_position.move_toward(corner, step)
			return
		global_position = corner
		step -= corner_distance
		_pop_hook_wrap()

	var to_hand: Vector3 = hand_position - global_position
	if to_hand.length() <= maxf(step, MovementHook.return_distance):
		_finish_return()
		return

	global_position += to_hand.normalized() * step
	_face_direction(-to_hand)


## Bends the rope over a new corner or straightens it off the last one.
func _update_hook_rope_wrap(hand_position: Vector3) -> void:
	_try_unwrap_hook_rope(hand_position)

	var pivot: Vector3 = _get_rope_pivot(hand_position)
	if _raycast_rope(pivot, global_position).is_empty():
		_last_clear_hook_position = global_position
		_has_clear_hook_position = true
		return

	if _has_clear_hook_position:
		_try_wrap_hook_rope(pivot)


func _try_wrap_hook_rope(pivot: Vector3) -> bool:
	if _hook_wraps.size() >= MovementHook.max_wrap_points:
		return false

	# Narrow down where between the last clear rope and this tick's blocked rope the corner sits.
	var clear_position: Vector3 = _last_clear_hook_position
	var blocked_position: Vector3 = global_position
	for i in 12:
		var middle_position: Vector3 = clear_position.lerp(blocked_position, 0.5)
		if _raycast_rope(pivot, middle_position).is_empty():
			clear_position = middle_position
		else:
			blocked_position = middle_position

	var corner_hit: Dictionary = _raycast_rope(pivot, blocked_position)
	if corner_hit.is_empty():
		return false

	var corner: Vector3 = Vector3(corner_hit.position)
	var corner_normal: Vector3 = Vector3(corner_hit.normal)
	# Push the wrap point back the way the rope swept in from, so it sits just clear of the edge.
	# Use this tick's whole sweep: the bisected pair is too close together for float precision.
	var rope_direction: Vector3 = (corner - pivot).normalized()
	var away_from_corner: Vector3 = _last_clear_hook_position - global_position
	away_from_corner -= rope_direction * away_from_corner.dot(rope_direction)
	if away_from_corner.length_squared() < 0.0000000001:
		away_from_corner = corner_normal
	var offset: float = maxf(MovementHook.wrap_point_offset, 0.0)
	var wrap_point: Vector3 = corner + away_from_corner.normalized() * offset + corner_normal * offset * 0.5
	if not _raycast_rope(pivot, wrap_point).is_empty():
		return false

	var bend_side: Vector3 = (wrap_point - pivot).cross(global_position - wrap_point)
	if bend_side.length_squared() < 0.000001:
		return false

	_hook_wraps.append(wrap_point)
	_hook_wrap_sides.append(bend_side.normalized())
	# If more corners sit between this one and the hook, the next ticks search between the
	# rope's last clear position (which also clears this corner) and the hook.
	if _raycast_rope(wrap_point, global_position).is_empty():
		_last_clear_hook_position = global_position
	else:
		_last_clear_hook_position = clear_position
	return true


func _try_unwrap_hook_rope(hand_position: Vector3) -> void:
	while not _hook_wraps.is_empty():
		var wrap_count: int = _hook_wraps.size()
		var wrap_point: Vector3 = _hook_wraps[wrap_count - 1]
		var previous_point: Vector3 = hand_position if wrap_count == 1 else _hook_wraps[wrap_count - 2]
		# The rope still presses on the corner while it bends the same way it did when it wrapped.
		var bend_side: Vector3 = (wrap_point - previous_point).cross(global_position - wrap_point)
		if bend_side.dot(_hook_wrap_sides[wrap_count - 1]) > 0.0:
			return
		if not _raycast_rope(previous_point, global_position).is_empty():
			return

		_pop_hook_wrap()
		_last_clear_hook_position = global_position
		_has_clear_hook_position = true


func _pop_hook_wrap() -> void:
	_hook_wraps.remove_at(_hook_wraps.size() - 1)
	_hook_wrap_sides.remove_at(_hook_wrap_sides.size() - 1)


func _clear_hook_wraps() -> void:
	_hook_wraps.clear()
	_hook_wrap_sides.clear()


## Where the free end of the rope leads: the last corner, or the hand.
func _get_rope_pivot(hand_position: Vector3) -> Vector3:
	if _hook_wraps.is_empty():
		return hand_position
	return _hook_wraps[_hook_wraps.size() - 1]


## Rope used up between the hand and the last corner.
func _get_wrapped_rope_length(hand_position: Vector3) -> float:
	var length: float = 0.0
	var previous_point: Vector3 = hand_position
	for wrap_point in _hook_wraps:
		length += previous_point.distance_to(wrap_point)
		previous_point = wrap_point
	return length


func _settle_on_hit(hit: Dictionary) -> void:
	var normal: Vector3 = Vector3(hit.normal)
	global_position = Vector3(hit.position) + normal * maxf(MovementHook.hook_radius, 0.01)
	_is_supported = MovementHook.is_support_normal(normal) and not (hit.collider is RigidBody3D)
	if _is_supported:
		_velocity = Vector3.ZERO
	else:
		# Steel on stone: most of the speed along the surface is lost, so the hook drops instead of skidding.
		_velocity = _velocity.slide(normal) * clampf(MovementHook.wall_hit_speed_keep, 0.0, 1.0)


## Finds the exact edge by casting back at the face just below the top surface.
func _find_edge_point(past_edge_position: Vector3, drag_direction: Vector3, top_y: float, back_distance: float) -> Vector3:
	var probe_origin: Vector3 = Vector3(past_edge_position.x, top_y - 0.05, past_edge_position.z)
	var face_hit: Dictionary = _raycast(probe_origin, probe_origin - drag_direction * back_distance)
	var edge_point: Vector3 = Vector3(past_edge_position.x, top_y, past_edge_position.z)
	if not face_hit.is_empty():
		edge_point = Vector3(face_hit.position.x, top_y, face_hit.position.z)
	return edge_point


func _try_anchor(edge_point: Vector3, hand_position: Vector3) -> bool:
	var toward_hand: Vector3 = hand_position - edge_point
	toward_hand.y = 0.0
	var offset: float = maxf(MovementHook.anchor_surface_offset, 0.0)
	var anchor: Vector3 = edge_point + toward_hand.normalized() * offset + Vector3.UP * offset
	if not _raycast(hand_position, anchor).is_empty():
		return false

	_anchor_at(anchor, -toward_hand, false)
	return true


## keep_wraps hands the corners the rope bends over to the player along with the anchor.
func _anchor_at(anchor: Vector3, facing_direction: Vector3, keep_wraps: bool) -> void:
	_anchor_wraps.clear()
	if keep_wraps:
		for i in range(_hook_wraps.size() - 1, -1, -1):
			_anchor_wraps.append(_hook_wraps[i])
	_anchor_point = anchor
	_state = STATE_ANCHORED
	_velocity = Vector3.ZERO
	_is_supported = false
	_is_climbing_wall = false
	_clear_hook_wraps()
	global_position = anchor
	_face_direction(Vector3(facing_direction.x, 0.0, facing_direction.z))
	_play_catch_sound()
	anchored.emit(anchor)


func _play_catch_sound() -> void:
	if _catch_sound == null or catch_sounds.is_empty():
		return
	var pitch_variation: float = clampf(HookFeel.catch_sound_pitch_variation, 0.0, 0.9)
	var volume_variation: float = maxf(HookFeel.catch_sound_volume_variation_db, 0.0)
	_catch_sound.stream = catch_sounds.pick_random()
	_catch_sound.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	_catch_sound.volume_db = HookFeel.catch_sound_volume_db + randf_range(-volume_variation, volume_variation)
	_catch_sound.play()


func _finish_return() -> void:
	_state = STATE_RETURNED
	returned.emit()
	queue_free()


func _get_hand_position() -> Vector3:
	return _hand_node.global_transform * _hand_offset


## Raycast along a rope span, ignoring contact right at the hook: the rope near the hook may
## lie on the surface the hook rests on without counting as bent over it.
func _raycast_rope(from: Vector3, to: Vector3) -> Dictionary:
	var span: Vector3 = to - from
	var length: float = span.length()
	if length <= 0.001:
		return {}
	var direction: Vector3 = span / length
	var end_trim: float = minf(maxf(MovementHook.rope_contact_ignore_distance, 0.0), length * 0.5)
	var start_trim: float = minf(0.02, length * 0.25)
	return _raycast(from + direction * start_trim, to - direction * end_trim)


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MovementHook.hook_collision_mask, _exclude)
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)


func _face_direction(direction: Vector3) -> void:
	if _model == null or direction.length_squared() < 0.0001:
		return
	var forward: Vector3 = direction.normalized()
	var up: Vector3 = Vector3.UP
	if absf(forward.dot(up)) > 0.98:
		up = Vector3.FORWARD
	_model.global_basis = Basis.looking_at(forward, up)


func _update_rope_visual() -> void:
	if _rope == null or _hand_node == null or not is_instance_valid(_hand_node):
		return

	# Rope path: hook → wrapped corners → hand. Only the free span after the last corner can sag.
	var points: PackedVector3Array = PackedVector3Array([get_global_transform_interpolated().origin])
	if _state == STATE_ANCHORED:
		points.append_array(_wrap_points)
	else:
		for i in range(_hook_wraps.size() - 1, -1, -1):
			points.append(_hook_wraps[i])
	var free_start: Vector3 = points[points.size() - 1]
	var hand_position: Vector3 = _hand_node.get_global_transform_interpolated() * _hand_offset
	var free_length: float = free_start.distance_to(hand_position)
	var sag_depth: float = HookFeel.get_rope_sag_depth(free_length, _get_free_rope_slack(free_length))
	if sag_depth > 0.01:
		var sag_segments: int = maxi(HookFeel.rope_sag_segments, 2)
		for i in range(1, sag_segments):
			var t: float = float(i) / float(sag_segments)
			points.append(free_start.lerp(hand_position, t) + Vector3.DOWN * sag_depth * 4.0 * t * (1.0 - t))
	points.append(hand_position)
	var segment_count: int = points.size() - 1
	while _rope_segments.size() < segment_count:
		var segment: MeshInstance3D = _rope.duplicate() as MeshInstance3D
		add_child(segment)
		segment.top_level = true
		segment.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_rope_segments.append(segment)

	for i in _rope_segments.size():
		if i < segment_count:
			_place_rope_segment(_rope_segments[i], points[i], points[i + 1])
		else:
			_rope_segments[i].visible = false


func _get_free_rope_slack(free_length: float) -> float:
	match _state:
		STATE_FLYING:
			# Rope trails loose behind the hook and pulls straight as it runs out.
			var payout_ratio: float = clampf(_rope_path_length / maxf(MovementHook.max_rope_length, 0.1), 0.0, 1.0)
			var trailing_slack: float = maxf(HookFeel.flight_rope_slack, 0.0) * (1.0 - payout_ratio)
			return free_length * (trailing_slack + maxf(HookFeel.taut_rope_slack, 0.0))
		STATE_RETRACTING:
			return free_length * maxf(HookFeel.taut_rope_slack, 0.0)
		STATE_ANCHORED:
			return _anchored_slack + free_length * maxf(HookFeel.taut_rope_slack, 0.0)
	return 0.0


func _place_rope_segment(segment: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var span: Vector3 = end - start
	var length: float = span.length()
	segment.visible = length > 0.05
	if not segment.visible:
		return

	var axis_y: Vector3 = span / length
	var side: Vector3 = axis_y.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis_y.cross(Vector3.RIGHT)
	var axis_x: Vector3 = side.normalized()
	var axis_z: Vector3 = axis_x.cross(axis_y).normalized()
	segment.global_transform = Transform3D(Basis(axis_x, axis_y * length, axis_z), start + span * 0.5)
