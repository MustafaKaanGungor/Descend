extends Node

@export_group("Throw")
## Enables throwing the grappling hook.
@export var enable_hook: bool = true
## Speed the hook leaves the hand with.
@export var throw_speed: float = 32.0
## Downward acceleration on the hook while it flies or hangs. Aim above a ledge to throw over it.
@export var hook_gravity: float = 14.0
## Portion of the player's velocity added to the throw.
@export var inherit_player_velocity: float = 0.5
## Longest the rope can be. The hook stops flying outward at this distance.
@export var max_rope_length: float = 18.0
## Delay after the hook comes back before it can be thrown again.
@export var throw_cooldown: float = 0.25
## Drag from the trailing rope at full length; grows as more rope pays out, so the hook slows before it runs out.
@export var rope_payout_drag: float = 34.0
## How hard the rope pulls back once stretched past full length. Lower stretches further and stops softer.
@export var rope_stretch_stiffness: float = 420.0
## Damping on the stretched rope; higher means less spring-back toward the player.
@export var rope_stretch_damping: float = 3.0
## Hard limit on how far the rope can stretch past full length.
@export var rope_max_stretch: float = 1.4
## Rope origin in camera space, roughly where the right hand holds it.
@export var hand_offset: Vector3 = Vector3(0.22, -0.22, -0.35)
## Physics layers the hook collides with and catches on.
@export_flags_3d_physics var hook_collision_mask: int = 1

@export_group("Retract And Catch")
## Catch right away when the hook settles on any upward-facing top surface, ground included.
@export var catch_on_top_surfaces: bool = true
## How far across a top surface the hook looks for the edge nearest the player when the rope
## runs over that edge.
@export var surface_catch_lip_search_distance: float = 4.0
## Speed the rope is pulled in while the player holds the reel key on a hook that has not caught.
@export var retract_speed: float = 7.0
## Speed the hook is reeled in after letting go of the hook button.
@export var cancel_reel_speed: float = 55.0
## Share of speed along a wall the hook keeps when it hits one; low, so it drops onto what is below.
@export var wall_hit_speed_keep: float = 0.03
## Collision radius of the hook head.
@export var hook_radius: float = 0.08
## Lowest surface normal Y that the hook can rest on and drag across.
@export var min_catch_surface_normal_y: float = 0.7
## Down probe distance used to keep a dragged hook on its surface.
@export var support_probe_depth: float = 0.3
## Minimum drop past a lip before the hook can catch it.
@export var min_lip_height: float = 0.6
## Anchor is pushed this far out and up from the edge so the rope clears the corner.
@export var anchor_surface_offset: float = 0.06
## Air drag on a hanging hook so it settles instead of swinging forever.
@export var hook_air_drag: float = 1.2
## Hook is caught back in the hand inside this distance.
@export var return_distance: float = 0.9

@export_group("Swing")
## Rope attach point height on the player body; the hands hold it above the head.
@export var body_attach_height: float = 1.9
## Shortest rope length reachable by reeling in.
@export var min_rope_length: float = 0.5
## Rope shortened per second while reeling in (sprint key).
@export var reel_in_speed: float = 4.5
## Rope lengthened per second while letting out (crouch key).
@export var reel_out_speed: float = 5.0
## Acceleration added along the swing arc from movement input.
@export var pump_acceleration: float = 7.0
## Gravity multiplier while hanging on the rope. Constant, so the swing neither gains nor loses energy on its own.
@export var swing_gravity_multiplier: float = 1.2
## Air drag while swinging.
@export var swing_air_drag: float = 0.08
## Highest speed reachable while swinging.
@export var max_swing_speed: float = 26.0
## Fallback only: if the rope is blocked and no corner can be found to wrap around, it breaks after this long.
@export var rope_blocked_break_time: float = 0.2

@export_group("Rope Wrap")
## How far a wrap point sits off the corner it wraps around, so the rope clears it.
@export var wrap_point_offset: float = 0.06
## Most corners the rope can wrap around at once.
@export var max_wrap_points: int = 8
## Rope this close to the hook may touch the surface the hook rests on without bending over it.
@export var rope_contact_ignore_distance: float = 0.3
## A hook pulled this close to a corner the rope bends over is pulled over it.
@export var wrap_pass_distance: float = 0.3
## Shortest free rope after the last corner; reeling in stops here.
@export var min_free_rope_length: float = 0.4

@export_group("Ledge Climb")
## Lets the player climb over the ledge the rope hangs from.
@export var enable_rope_ledge_climb: bool = true
## Highest ledge top above the feet that can be grabbed from the rope (arms stretched up).
@export var ledge_grab_reach: float = 2.5
## Rope hold point must be this close to the anchor or corner before a climb can start.
@export var ledge_grab_max_distance: float = 1.3
## Forward input needed to climb without reeling. Reeling in (sprint key) also climbs.
@export var ledge_climb_forward_input: float = 0.3
## Extra distance the climb carries the body onto the ledge so it doesn't end on the lip.
@export var ledge_climb_pull_distance: float = 0.5

@export_group("Release")
## Upward velocity added when jumping off the rope.
@export var release_jump_up_velocity: float = 5.5
## Horizontal momentum kept when jumping off the rope.
@export var release_momentum_multiplier: float = 1.08
## Horizontal speed cap right after a release jump.
@export var release_max_horizontal_speed: float = 22.0

@export_group("Loudness")
## Loudness pushed when the hook is thrown.
@export var throw_loudness: float = 6.0
## Loudness pushed when the hook catches a ledge.
@export var catch_loudness: float = 18.0


func is_support_normal(normal: Vector3) -> bool:
	return normal.y >= min_catch_surface_normal_y


func get_clamped_rope_length(rope_length: float) -> float:
	return clampf(rope_length, maxf(min_rope_length, 0.1), maxf(max_rope_length, min_rope_length))


func is_rope_taut(attach_position: Vector3, anchor: Vector3, rope_length: float) -> bool:
	return attach_position.distance_to(anchor) >= rope_length - 0.01


## Removes velocity that would stretch the rope.
func get_rope_constrained_velocity(velocity: Vector3, attach_position: Vector3, anchor: Vector3, rope_length: float) -> Vector3:
	var offset: Vector3 = attach_position - anchor
	var distance: float = offset.length()
	if distance <= 0.001 or distance < rope_length - 0.01:
		return velocity

	var outward: Vector3 = offset / distance
	var outward_speed: float = velocity.dot(outward)
	if outward_speed > 0.0:
		velocity -= outward * outward_speed
	return velocity


## Movement input pushes along the swing arc, never along the rope.
func get_pump_velocity(wish_direction: Vector3, attach_position: Vector3, anchor: Vector3, delta: float) -> Vector3:
	if wish_direction == Vector3.ZERO:
		return Vector3.ZERO

	var rope_direction: Vector3 = (anchor - attach_position).normalized()
	var tangent_push: Vector3 = wish_direction - rope_direction * wish_direction.dot(rope_direction)
	return tangent_push * maxf(pump_acceleration, 0.0) * delta


func get_swing_velocity(velocity: Vector3, delta: float) -> Vector3:
	velocity *= exp(-maxf(swing_air_drag, 0.0) * delta)
	return velocity.limit_length(maxf(max_swing_speed, 0.0))


func get_release_velocity(velocity: Vector3) -> Vector3:
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * maxf(release_momentum_multiplier, 0.0)
	horizontal = horizontal.limit_length(maxf(release_max_horizontal_speed, 0.0))
	return Vector3(horizontal.x, maxf(velocity.y, 0.0) + maxf(release_jump_up_velocity, 0.0), horizontal.z)
