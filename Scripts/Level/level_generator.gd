@tool
extends Node3D
## Builds a descent level: a deep, irregular shaft that widens into chambers and narrows into
## choke points, with a route of stations down it. Each station is a ledge on the wall or a
## platform hanging in the open middle, and has a hook point above it (a beam on the wall or a
## girder on chains). Every hook point is placed so that hooking it from the station before and
## swinging bottoms out just above the station it belongs to.
## The route's throw lines, swing arcs and landing spaces are kept as clear corridors, and the
## rest of the shaft (pillars, bridges, overhangs, ribs, buttresses, pipes) is only placed where
## it stays out of them, so the route always stays playable.
## Generates when the scene starts (a new layout every run while level_seed is 0) and previews
## in the editor; use the Regenerate button to roll a new one.

signal generated
## The player reached the goal on the shaft floor.
signal goal_reached(body: Node3D)

const GROUP_RESPAWN_GROUND: StringName = &"respawn_ground"
const META_RESPAWN_POINT: StringName = &"respawn_point"
const GENERATED_ROOT_NAME: String = "Generated"
const STATION_START: StringName = &"start"
const STATION_WALL: StringName = &"wall"
const STATION_MID: StringName = &"mid"
const STYLE_BOX: StringName = &"box"
const STYLE_ARC: StringName = &"arc"
const STYLE_STEPPED: StringName = &"stepped"
const STYLE_BROKEN: StringName = &"broken"
## Body capsule radius used for swing corridors (covers the player's height around its center).
const SWING_CORRIDOR_RADIUS: float = 0.85
## Extra space kept between solid pieces.
const SOLID_MARGIN: float = 0.8
## Height of the slices solids and corridors are indexed by.
const BUCKET_HEIGHT: float = 8.0

@export_tool_button("Regenerate", "Reload") var regenerate_action: Callable = regenerate

@export_group("Seed")
## 0 builds a new random layout every time; any other value always builds the same level.
@export var level_seed: int = 0

@export_group("Shaft")
## Radius at the narrowest choke points.
@export var shaft_radius_min: float = 15.0
## Radius in the widest chambers.
@export var shaft_radius_max: float = 27.0
## How quickly the shaft swaps between chambers and choke points with depth. Lower is slower.
@export var chamber_frequency: float = 0.011
## How far the wall bulges in and out around the shaft.
@export var wall_bumpiness: float = 1.6
## How busy the bulges are.
@export var wall_bump_frequency: float = 0.09
@export var wall_thickness: float = 6.0
## Wall pieces around the circle. More is rounder.
@export var wall_segments: int = 56
## Height of each ring of wall pieces; rings step in and out against each other.
@export var wall_band_height: float = 6.0
## Wall height above the start platform.
@export var wall_height_above_start: float = 10.0
## Floor depth below the last station.
@export var floor_depth_below_last_ledge: float = 8.0

@export_group("Stages")
## Stations below the start platform.
@export var stage_count: int = 30
## Height drop from one station to the next.
@export var stage_drop_min: float = 6.0
@export var stage_drop_max: float = 11.0
## How far around the shaft the next wall ledge is.
@export var stage_turn_min_degrees: float = 6.0
@export var stage_turn_max_degrees: float = 70.0
## Chance per stage that the spiral switches direction.
@export_range(0.0, 1.0) var direction_flip_chance: float = 0.2
## Chance per stage that the next station hangs in the open middle instead of on the wall.
@export_range(0.0, 1.0) var mid_station_chance: float = 0.28
## Most hanging stations in a row before the route returns to the wall.
@export var max_consecutive_mid_stations: int = 2
## Times the route may step back and re-plan a station that left no way on.
@export var max_route_backtracks: int = 40
## Space kept between a hanging platform and the wall.
@export var mid_station_wall_clearance: float = 4.0

@export_group("Ledges")
## Start platform size: width along the wall, thickness, depth out from the wall.
@export var start_platform_size: Vector3 = Vector3(8.0, 0.8, 5.0)
@export var ledge_width_min: float = 3.6
@export var ledge_width_max: float = 6.5
@export var ledge_depth_min: float = 2.8
@export var ledge_depth_max: float = 4.0
@export var ledge_thickness: float = 0.7
## How far ledges and beams sink into the wall so there is no gap.
@export var wall_embed: float = 0.4
## Chances of the ledge styles; the rest are plain boxes.
@export_range(0.0, 1.0) var arc_ledge_chance: float = 0.35
@export_range(0.0, 1.0) var stepped_ledge_chance: float = 0.2
@export_range(0.0, 1.0) var broken_ledge_chance: float = 0.2

@export_group("Hanging Platforms")
## Size of a hanging platform: width, thickness, depth.
@export var hanging_platform_size: Vector3 = Vector3(4.6, 0.6, 4.6)
## Girder above a hanging platform that the hook catches: length, thickness, depth.
@export var girder_size: Vector3 = Vector3(3.4, 0.6, 1.2)
## Upright plate on the girder's far side, so throws aimed a little high hit it and drop onto the girder.
@export var girder_backboard_height: float = 2.2
## Fence on a hanging platform's far side; it stops the swing like a wall does on wall ledges.
@export var hanging_fence_height: float = 1.6
## How far chains run up out of sight above hanging pieces.
@export var chain_height_above: float = 28.0

@export_group("Hook Beams")
@export var hook_beam_width: float = 3.4
@export var hook_beam_thickness: float = 0.45
## Beam length out from the wall; it stretches so its lip sits over the ledge below.
@export var hook_beam_depth_min: float = 1.2
@export var hook_beam_depth_max: float = 4.5
## Height on the body where the rope attaches. Keep equal to MovementHook.body_attach_height.
@export var rope_attach_height: float = 1.9
## Rope length when the hook catches; keep under MovementHook.max_rope_length.
@export var max_initial_rope_length: float = 15.0
## Hook point must sit at least this far above the player's hand on the station before it.
@export var min_anchor_height_above_hand: float = 1.0
## Throw speed and hook gravity used to keep each throw's flight path clear.
## Keep equal to MovementHook.throw_speed and MovementHook.hook_gravity.
@export var hook_throw_speed: float = 32.0
@export var hook_throw_gravity: float = 14.0
## Feet clear the next station by this much at the bottom of the swing.
@export var swing_landing_clearance: float = 0.4
## Plank on the wall above each beam, so throws aimed a little high drop straight onto the beam.
@export var hook_beam_backplate_height: float = 2.2
## Chance per stage of an extra beam somewhere on the wall, for alternate routes.
@export_range(0.0, 1.0) var extra_beam_chance: float = 0.6

@export_group("Structures")
## Pillars rising from the shaft floor.
@export var pillar_count: int = 4
@export var pillar_radius_min: float = 1.2
@export var pillar_radius_max: float = 2.6
## Bridges spanning the shaft.
@export var bridge_count: int = 6
## Rock overhangs, one roughly every this many meters of depth.
@export var overhang_spacing: float = 12.0
## Thin ribs along the wall, one roughly every this many meters of depth.
@export var rib_spacing: float = 16.0
## Buttresses along the wall, one roughly every this many meters of depth.
@export var buttress_spacing: float = 14.0
## Vertical pipes along the wall.
@export var pipe_count: int = 8

@export_group("Look")
@export var rock_color: Color = Color(0.36, 0.33, 0.31)
@export var ledge_color: Color = Color(0.52, 0.49, 0.45)
@export var beam_color: Color = Color(0.33, 0.21, 0.12)
@export var metal_color: Color = Color(0.24, 0.25, 0.27)
## Glowing strip on hook points so they read from across the shaft.
@export var beam_strip_color: Color = Color(1.0, 0.62, 0.25)
@export var lamp_color: Color = Color(1.0, 0.72, 0.42)
@export var lamp_energy: float = 2.4
@export var lamp_range: float = 14.0
@export var goal_color: Color = Color(0.3, 0.95, 0.85)

@export_group("Nodes")
## Marker the level's main script spawns the player at.
@export var player_spawn_path: NodePath = NodePath("../PlayerSpawn")

var _generated_root: Node3D
var _rng: RandomNumberGenerator
var _chamber_noise: FastNoiseLite
var _bump_noise: FastNoiseLite
## Solid boxes already placed: {center, basis, half, aabb_min, aabb_max}.
var _solids: Array[Dictionary] = []
## Spaces the route needs clear: {a, b, radius, aabb_min, aabb_max}.
var _corridors: Array[Dictionary] = []
var _stages: Array[Dictionary] = []
## Solids and corridors indexed by height slice, so checks only look at nearby ones.
var _solid_buckets: Dictionary = {}
var _corridor_buckets: Dictionary = {}
var _current_seed: int = 0
var _start_transform: Transform3D = Transform3D.IDENTITY
var _floor_y: float = 0.0
var _rock_material: StandardMaterial3D
var _ledge_material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _strip_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _goal_material: StandardMaterial3D


func _ready() -> void:
	regenerate()


func get_current_seed() -> int:
	return _current_seed


func get_start_transform() -> Transform3D:
	return _start_transform


## Stations from the start platform down. Every station has type, y (top surface), landing_center,
## landing_basis, landing_half (top rectangle) and respawn_point. Every station after the first also
## has lip (where its hook point catches), anchor_y and launch (where the swing to it starts, on the
## station before). Wall stations also have angle and depth.
func get_stages() -> Array[Dictionary]:
	return _stages


## Widest possible wall radius; the actual wall is closer in most places.
func get_shaft_radius() -> float:
	return shaft_radius_max + wall_bumpiness


## Distance from the shaft's axis to the wall at this angle and height.
func get_wall_radius(angle: float, y: float) -> float:
	return _wall_radius(angle, y)


func get_floor_y() -> float:
	return _floor_y


## Builds the next level: the following seed when a seed is set, otherwise a new random one.
func generate_next_level() -> void:
	if level_seed != 0:
		level_seed += 1
	regenerate()


func regenerate() -> void:
	_clear_generated()
	_build_materials()
	_solids.clear()
	_corridors.clear()
	_solid_buckets.clear()
	_corridor_buckets.clear()
	_stages.clear()

	_rng = RandomNumberGenerator.new()
	_current_seed = level_seed
	if _current_seed == 0:
		_current_seed = randi_range(1, 2147483646)
	_rng.seed = _current_seed
	_setup_noise()

	_generated_root = Node3D.new()
	_generated_root.name = GENERATED_ROOT_NAME
	add_child(_generated_root)

	var start: Dictionary = _build_start_platform(_rng.randf() * TAU)
	_stages.append(start)

	# Plan the whole route as data first. When a station leaves no way on, undo it and try again
	# from the one before, so a dead end never cuts the level short.
	var direction: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var backtracks: int = 0
	while _stages.size() - 1 < stage_count:
		var current: Dictionary = _stages.back()
		if _rng.randf() < direction_flip_chance:
			direction = -direction
		var wants_mid: bool = _consecutive_mid_stations() < max_consecutive_mid_stations and _rng.randf() < mid_station_chance
		var next: Dictionary = _plan_station(current, direction, wants_mid)
		if next.is_empty() and (not wants_mid or _consecutive_mid_stations() < max_consecutive_mid_stations + 1):
			next = _plan_station(current, direction, not wants_mid)
		if not next.is_empty():
			_reserve_station(next)
			_stages.append(next)
			continue
		if _stages.size() <= 1 or backtracks >= max_route_backtracks:
			push_warning("Level generator: no valid stage %d for seed %d; level ends early." % [_stages.size() - 1, _current_seed])
			break
		_unreserve_station(_stages.pop_back())
		backtracks += 1

	for i in range(1, _stages.size()):
		_build_station(_stages[i])
	for i in range(1, _stages.size()):
		if _rng.randf() < extra_beam_chance:
			_try_add_extra_beam(float(_stages[i - 1].y), float(_stages[i].y))

	var last: Dictionary = _stages.back()
	_floor_y = float(last.y) - floor_depth_below_last_ledge
	var top_y: float = wall_height_above_start
	_add_structures(_floor_y, top_y)
	_add_walls(_floor_y, top_y)
	_add_floor_and_goal(_floor_y)
	_set_start(start, _stages[1] if _stages.size() > 1 else {})
	print("Descent level generated. Seed: %d, %d stations, %.0f m deep" % [_current_seed, _stages.size() - 1, -_floor_y])
	generated.emit()


# --- Shaft shape -------------------------------------------------------------------------------

func _setup_noise() -> void:
	_chamber_noise = FastNoiseLite.new()
	_chamber_noise.seed = _rng.randi()
	_chamber_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_chamber_noise.frequency = chamber_frequency
	_chamber_noise.fractal_octaves = 2

	_bump_noise = FastNoiseLite.new()
	_bump_noise.seed = _rng.randi()
	_bump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_bump_noise.frequency = wall_bump_frequency
	_bump_noise.fractal_octaves = 3


## Radius of the shaft at this depth: chambers and choke points.
func _chamber_radius(y: float) -> float:
	var t: float = smoothstep(0.15, 0.85, 0.5 + 0.5 * _chamber_noise.get_noise_1d(y))
	return lerpf(shaft_radius_min, shaft_radius_max, t)


## The wall is made of flat pieces in rings; this is the inner face distance of the piece that
## covers this angle and height. Everything that touches the wall uses this.
func _wall_radius(angle: float, y: float) -> float:
	var band: int = floori(y / wall_band_height)
	var band_center_y: float = (float(band) + 0.5) * wall_band_height
	var segments: int = maxi(wall_segments, 6)
	var segment: int = posmod(roundi(wrapf(angle, 0.0, TAU) / TAU * float(segments)), segments)
	var segment_angle: float = TAU * float(segment) / float(segments)
	var bump: float = _bump_noise.get_noise_3d(cos(segment_angle) * 20.0, band_center_y, sin(segment_angle) * 20.0)
	return _chamber_radius(band_center_y) + wall_bumpiness * bump


func _is_inside_wall(point: Vector3, margin: float) -> bool:
	var radius: float = Vector2(point.x, point.z).length()
	return radius > _wall_radius(atan2(point.z, point.x), point.y) - margin


func _segment_hits_wall(a: Vector3, b: Vector3, margin: float) -> bool:
	var steps: int = maxi(ceili(a.distance_to(b) / 0.5), 1)
	for i in steps + 1:
		if _is_inside_wall(a.lerp(b, float(i) / float(steps)), margin):
			return true
	return false


# --- Route planning ----------------------------------------------------------------------------

func _plan_station(current: Dictionary, direction: float, mid: bool) -> Dictionary:
	for attempt in 220:
		# Some attempts go the other way around the shaft, in case this side is crowded.
		var attempt_direction: float = direction if attempt % 3 != 2 else -direction
		var plan: Dictionary = _plan_mid_station(current) if mid else _plan_wall_station(current, attempt_direction)
		if plan.is_empty():
			continue
		plan["from_floor_solids"] = current.get("floor_solids", [])
		if _is_plan_clear(plan):
			return plan
	return {}


func _plan_wall_station(current: Dictionary, direction: float) -> Dictionary:
	var drop: float = _rng.randf_range(stage_drop_min, stage_drop_max)
	var next_y: float = float(current.y) - drop
	var base_angle: float = _station_angle(current)
	var turn: float = deg_to_rad(_rng.randf_range(stage_turn_min_degrees, stage_turn_max_degrees)) * direction
	var angle: float = wrapf(base_angle + turn, 0.0, TAU)
	var width: float = _rng.randf_range(ledge_width_min, ledge_width_max)
	var depth: float = _rng.randf_range(ledge_depth_min, ledge_depth_max)
	var ledge_wall_radius: float = _wall_radius(angle, next_y - ledge_thickness * 0.5)
	var lip_radius_min: float = ledge_wall_radius - depth + 0.6
	var lip_radius_max: float = ledge_wall_radius - 0.8

	# The beam's lip sits over the ledge; its height comes from the swing solve, and the wall
	# radius at that height decides how long the beam must be. Two passes settle both.
	var lip_radius: float = ledge_wall_radius - depth * 0.55
	var solve: Dictionary = {}
	var beam_wall_radius: float = 0.0
	var converged: bool = false
	for pass_index in 3:
		solve = _solve_swing(current, _polar(angle, lip_radius, 0.0), drop)
		if solve.is_empty():
			return {}
		beam_wall_radius = _wall_radius(angle, float(solve.anchor_y) - hook_beam_thickness * 0.5)
		var clamped_radius: float = clampf(lip_radius, beam_wall_radius - hook_beam_depth_max, beam_wall_radius - hook_beam_depth_min)
		if absf(clamped_radius - lip_radius) < 0.001:
			converged = true
			break
		lip_radius = clamped_radius
		if lip_radius < lip_radius_min or lip_radius > lip_radius_max:
			return {}
	if not converged:
		return {}
	var anchor_y: float = float(solve.anchor_y)
	# The beam top must be open above near its lip so a thrown hook can land on it.
	if _wall_radius(angle, anchor_y + 1.2) < lip_radius + 1.0:
		return {}

	var plan: Dictionary = {
		"type": STATION_WALL,
		"angle": angle,
		"y": next_y,
		"width": width,
		"depth": depth,
		"wall_radius": ledge_wall_radius,
		"lip": _polar(angle, lip_radius, anchor_y),
		"anchor_y": anchor_y,
		"launch": solve.launch,
		"beam_wall_radius": beam_wall_radius,
		"throw_target": _polar(angle, beam_wall_radius - 0.6, anchor_y + 1.0),
		"style": _pick_ledge_style(),
		"style_seed": _rng.randi(),
	}
	_add_station_pieces(plan)
	return plan


func _plan_mid_station(current: Dictionary) -> Dictionary:
	var drop: float = _rng.randf_range(stage_drop_min, stage_drop_max)
	var next_y: float = float(current.y) - drop
	var from: Vector3 = Vector3(current.landing_center)
	var direction: Vector3
	if current.type == STATION_MID:
		var random_angle: float = _rng.randf() * TAU
		direction = Vector3(cos(random_angle), 0.0, sin(random_angle))
	else:
		# Off the wall, out into the open: inward with a sideways lean.
		var station_angle: float = _station_angle(current)
		var inward: Vector3 = -Vector3(cos(station_angle), 0.0, sin(station_angle))
		var sideways: Vector3 = Vector3(-sin(station_angle), 0.0, cos(station_angle)) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var lean: float = deg_to_rad(_rng.randf_range(10.0, 60.0))
		direction = (inward * cos(lean) + sideways * sin(lean)).normalized()
	var reach: float = _rng.randf_range(8.0, 14.0)
	var lip_flat: Vector3 = Vector3(from.x, 0.0, from.z) + direction * reach
	var solve: Dictionary = _solve_swing(current, lip_flat, drop)
	if solve.is_empty():
		return {}

	var anchor_y: float = float(solve.anchor_y)
	var launch: Vector3 = solve.launch
	var approach: Vector3 = Vector3(lip_flat.x - launch.x, 0.0, lip_flat.z - launch.z).normalized()
	var girder_center: Vector3 = Vector3(lip_flat.x, anchor_y - girder_size.y * 0.5, lip_flat.z) + approach * girder_size.z * 0.5
	var platform_center: Vector3 = Vector3(girder_center.x, next_y, girder_center.z)

	# Keep the hanging platform and its chains clear of the wall over its whole height.
	var reach_radius: float = Vector2(platform_center.x, platform_center.z).length() + hanging_platform_size.x * 0.71
	var check_y: float = next_y - 2.0
	while check_y < anchor_y + 2.0:
		if reach_radius > _wall_radius(atan2(platform_center.z, platform_center.x), check_y) - mid_station_wall_clearance:
			return {}
		check_y += 2.0
	if Vector2(platform_center.x, platform_center.z).length() < 4.0:
		return {}

	var plan: Dictionary = {
		"type": STATION_MID,
		"y": next_y,
		"lip": Vector3(lip_flat.x, anchor_y, lip_flat.z),
		"anchor_y": anchor_y,
		"launch": launch,
		"approach": approach,
		"girder_center": girder_center,
		"platform_center": platform_center,
		"throw_target": girder_center + approach * (girder_size.z * 0.5 - 0.5) + Vector3.UP * (girder_size.y * 0.5 + girder_backboard_height * 0.5),
	}
	_add_station_pieces(plan)
	return plan


## Solves how high a hook point at lip_flat must be so that swinging from the current station
## bottoms out just above a station drop meters lower. Returns {launch, anchor_y} or {}.
##   (v + k)^2 = s^2 + v^2  ->  v = (s^2 - k^2) / (2k)
## s = horizontal launch-to-lip distance, v = lip height above the hand, k = drop - clearance.
func _solve_swing(current: Dictionary, lip_flat: Vector3, drop: float) -> Dictionary:
	var launch: Vector3 = _closest_launch_point(current, lip_flat)
	var s: float = Vector2(launch.x - lip_flat.x, launch.z - lip_flat.z).length()
	var k: float = drop - swing_landing_clearance
	if k <= 0.5:
		return {}
	var v: float = (s * s - k * k) / (2.0 * k)
	if v < min_anchor_height_above_hand or v + k > max_initial_rope_length:
		return {}
	return {"launch": launch, "anchor_y": float(current.y) + rope_attach_height + v}


## Closest standing spot on a station's top to a target, kept back from the edges.
func _closest_launch_point(station: Dictionary, target: Vector3) -> Vector3:
	var center: Vector3 = station.landing_center
	var landing_basis: Basis = station.landing_basis
	var half: Vector3 = station.landing_half
	var local: Vector3 = landing_basis.transposed() * (target - center)
	local.x = clampf(local.x, -maxf(half.x - 0.6, 0.0), maxf(half.x - 0.6, 0.0))
	local.z = clampf(local.z, -maxf(half.z - 0.6, 0.0), maxf(half.z - 0.6, 0.0))
	local.y = 0.0
	return center + landing_basis * local


func _station_angle(station: Dictionary) -> float:
	if station.has("angle"):
		return float(station.angle)
	var center: Vector3 = station.landing_center
	return atan2(center.z, center.x)


func _pick_ledge_style() -> StringName:
	var roll: float = _rng.randf()
	if roll < arc_ledge_chance:
		return STYLE_ARC
	roll -= arc_ledge_chance
	if roll < stepped_ledge_chance:
		return STYLE_STEPPED
	roll -= stepped_ledge_chance
	if roll < broken_ledge_chance:
		return STYLE_BROKEN
	return STYLE_BOX


## Works out every piece a planned station is made of, so it can be checked before it is built.
## Adds pieces, visuals, landing_center/basis/half and respawn_point to the plan.
func _add_station_pieces(plan: Dictionary) -> void:
	var pieces: Array[Dictionary] = []
	var visuals: Array[Dictionary] = []
	if plan.type == STATION_WALL:
		_wall_ledge_pieces(plan, pieces, visuals)
		var angle: float = plan.angle
		var lip_radius: float = Vector2(Vector3(plan.lip).x, Vector3(plan.lip).z).length()
		var beam_wall_radius: float = plan.beam_wall_radius
		var beam_depth: float = beam_wall_radius - lip_radius + wall_embed
		var beam_center: Vector3 = _polar(angle, lip_radius + beam_depth * 0.5, float(plan.anchor_y) - hook_beam_thickness * 0.5)
		pieces.append(_piece(beam_center, _radial_basis(angle), Vector3(hook_beam_width, hook_beam_thickness, beam_depth), &"beam"))
		var plate_inner_radius: float = beam_wall_radius - 0.25
		var plate_outer_radius: float = beam_wall_radius + wall_embed + wall_bumpiness
		var plate_center: Vector3 = _polar(angle, (plate_inner_radius + plate_outer_radius) * 0.5, float(plan.anchor_y) + hook_beam_backplate_height * 0.5)
		pieces.append(_piece(plate_center, _radial_basis(angle), Vector3(hook_beam_width, hook_beam_backplate_height, plate_outer_radius - plate_inner_radius), &"beam"))
		# Glowing strip on the lip's outer face: visual only, so it can't change how the hook catches.
		visuals.append(_piece(_polar(angle, lip_radius - 0.025, float(plan.anchor_y) - 0.06), _radial_basis(angle), Vector3(hook_beam_width, 0.12, 0.05), &"strip"))
	else:
		_hanging_station_pieces(plan, pieces, visuals)
	plan["pieces"] = pieces
	plan["visuals"] = visuals


func _wall_ledge_pieces(plan: Dictionary, pieces: Array[Dictionary], visuals: Array[Dictionary]) -> void:
	var angle: float = plan.angle
	var top_y: float = plan.y
	var width: float = plan.width
	var depth: float = plan.depth
	var wall_radius: float = plan.wall_radius
	var style_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	style_rng.seed = int(plan.style_seed)
	var main_basis: Basis = _radial_basis(angle)
	var main_center: Vector3 = _polar(angle, wall_radius - depth * 0.5 + wall_embed * 0.5, top_y - ledge_thickness * 0.5)
	var main_size: Vector3 = Vector3(width, ledge_thickness, depth + wall_embed)

	match plan.style:
		STYLE_ARC:
			# A curved shelf that follows the wall, built from short radial pieces.
			var span_angle: float = (width * 1.8) / maxf(wall_radius - depth * 0.5, 1.0)
			var piece_count: int = maxi(ceili((width * 1.8) / 1.3), 3)
			if piece_count % 2 == 0:
				piece_count += 1
			var step_angle: float = span_angle / float(piece_count)
			for i in piece_count:
				var piece_angle: float = angle + (float(i) - float(piece_count - 1) * 0.5) * step_angle
				var piece_wall_radius: float = wall_radius if i == piece_count / 2 else _wall_radius(piece_angle, top_y - ledge_thickness * 0.5)
				var piece_depth: float = depth * (1.0 - 0.35 * absf(float(i) - float(piece_count - 1) * 0.5) / maxf(float(piece_count) * 0.5, 1.0))
				var piece_length: float = step_angle * (piece_wall_radius - piece_depth * 0.5) * 1.12
				var center: Vector3 = _polar(piece_angle, piece_wall_radius - piece_depth * 0.5 + wall_embed * 0.5, top_y - ledge_thickness * 0.5)
				pieces.append(_piece(center, _radial_basis(piece_angle), Vector3(piece_length, ledge_thickness, piece_depth + wall_embed), &"ledge", i == piece_count / 2))
		STYLE_STEPPED:
			# Main step under the hook point, with lower steps to either side.
			pieces.append(_piece(main_center, main_basis, main_size, &"ledge", true))
			var along: Vector3 = main_basis.x
			for side in [-1.0, 1.0]:
				var step_drop: float = style_rng.randf_range(0.3, 0.45)
				var step_width: float = style_rng.randf_range(1.6, 2.6)
				var step_center: Vector3 = main_center + along * side * (width * 0.5 + step_width * 0.5 - 0.05) + Vector3.DOWN * step_drop
				pieces.append(_piece(step_center, main_basis, Vector3(step_width, ledge_thickness, depth * 0.8 + wall_embed), &"ledge"))
		STYLE_BROKEN:
			# Main slab plus fallen chunks wedged against the wall beside it.
			pieces.append(_piece(main_center, main_basis, main_size, &"ledge", true))
			for chunk in style_rng.randi_range(2, 3):
				var side: float = -1.0 if chunk % 2 == 0 else 1.0
				var chunk_size: Vector3 = Vector3(style_rng.randf_range(0.7, 1.4), style_rng.randf_range(0.5, 0.9), style_rng.randf_range(0.8, 1.6))
				var offset: Vector3 = main_basis.x * side * (width * 0.5 + chunk_size.x * 0.5 + style_rng.randf_range(0.2, 0.7))
				offset += main_basis.z * style_rng.randf_range(-0.6, 0.2) + Vector3.DOWN * style_rng.randf_range(0.4, 1.2)
				var chunk_basis: Basis = main_basis * Basis.from_euler(Vector3(style_rng.randf_range(-0.3, 0.3), style_rng.randf_range(-0.5, 0.5), style_rng.randf_range(-0.3, 0.3)))
				pieces.append(_piece(main_center + offset, chunk_basis, chunk_size, &"ledge"))
		_:
			pieces.append(_piece(main_center, main_basis, main_size, &"ledge", true))

	# Slanted rock brace under the ledge: visual only.
	var brace_length: float = depth * 1.15
	var brace_basis: Basis = main_basis * Basis(Vector3.RIGHT, deg_to_rad(38.0))
	var brace_center: Vector3 = _polar(angle, wall_radius - depth * 0.38, top_y - ledge_thickness - depth * 0.32)
	visuals.append(_piece(brace_center, brace_basis, Vector3(width * 0.7, 0.6, brace_length), &"rock"))

	plan["landing_center"] = _polar(angle, wall_radius - depth * 0.5, top_y)
	plan["landing_basis"] = main_basis
	plan["landing_half"] = Vector3(width * 0.5, 0.0, depth * 0.5)
	plan["respawn_point"] = _polar(angle, wall_radius - minf(depth * 0.4, 1.4), top_y + 0.05)


func _hanging_station_pieces(plan: Dictionary, pieces: Array[Dictionary], visuals: Array[Dictionary]) -> void:
	var approach: Vector3 = plan.approach
	# X along the girder, Y up, Z along the approach.
	var station_basis: Basis = Basis(Vector3.UP.cross(approach).normalized(), Vector3.UP, approach)
	var platform_center: Vector3 = plan.platform_center
	var girder_center: Vector3 = plan.girder_center
	pieces.append(_piece(platform_center + Vector3.DOWN * hanging_platform_size.y * 0.5, station_basis, hanging_platform_size, &"ledge", true))
	pieces.append(_piece(girder_center, station_basis, girder_size, &"metal"))
	var fence_center: Vector3 = platform_center + approach * (hanging_platform_size.z * 0.5 - 0.1) + Vector3.UP * hanging_fence_height * 0.5
	pieces.append(_piece(fence_center, station_basis, Vector3(hanging_platform_size.x, hanging_fence_height, 0.2), &"metal"))
	var backboard_center: Vector3 = girder_center + approach * (girder_size.z * 0.5 - 0.1) + Vector3.UP * (girder_size.y * 0.5 + girder_backboard_height * 0.5)
	pieces.append(_piece(backboard_center, station_basis, Vector3(girder_size.x, girder_backboard_height, 0.2), &"metal"))
	# Glowing strip along the girder's near edge.
	visuals.append(_piece(girder_center - approach * (girder_size.z * 0.5 + 0.025) + Vector3.UP * (girder_size.y * 0.5 - 0.06), station_basis, Vector3(girder_size.x, 0.12, 0.05), &"strip"))

	# Chains: platform corners up out of sight, and the girder's ends up out of sight.
	var half: Vector3 = hanging_platform_size * 0.5
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner_point: Vector3 = platform_center + station_basis.x * corner.x * (half.x - 0.2) + station_basis.z * corner.y * (half.z - 0.2)
		visuals.append(_chain(corner_point, corner_point + Vector3.UP * (float(plan.anchor_y) - float(plan.y) + chain_height_above)))
	for end in [-1.0, 1.0]:
		var end_point: Vector3 = girder_center + station_basis.x * end * (girder_size.x * 0.5 - 0.2) + Vector3.UP * (girder_size.y * 0.5 + girder_backboard_height)
		visuals.append(_chain(end_point, end_point + Vector3.UP * chain_height_above))

	plan["landing_center"] = platform_center
	plan["landing_basis"] = station_basis
	plan["landing_half"] = Vector3(half.x, 0.0, half.z)
	plan["respawn_point"] = platform_center + Vector3.UP * 0.05


## True when a planned station fits: its pieces stay clear of everything placed so far and of
## the route, and its own throw line, swing arc and landing space stay clear of the wall and of
## everything placed so far.
func _is_plan_clear(plan: Dictionary) -> bool:
	var plan_solids: Array[Dictionary] = []
	var floor_solids: Array[Dictionary] = []
	for piece in plan.pieces:
		var solid: Dictionary = _solid_from_piece(piece)
		plan_solids.append(solid)
		var piece_top: float = Vector3(piece.center).y + Vector3(piece.size).y * 0.5
		# Floor the player walks off when launching from here: the slab, curved shelf segments and
		# side steps a short step down.
		if piece.material == &"ledge" and piece_top <= float(plan.y) + 0.05 and piece_top >= float(plan.y) - 0.6:
			floor_solids.append(solid)
	plan["floor_solids"] = floor_solids
	for solid in plan_solids:
		if _solid_hits_solids(solid, SOLID_MARGIN) or _solid_hits_corridors(solid):
			return false

	# The player walks off the launch station's floor (its slab, or every segment of a curved
	# shelf), so that floor doesn't block the route; lower steps, rubble and fences still count.
	var launch_floor: Array = plan.get("from_floor_solids", [])
	var corridors: Array[Dictionary] = _transition_corridors(plan)
	var corridors_min_y: float = INF
	var corridors_max_y: float = -INF
	for corridor in corridors:
		corridors_min_y = minf(corridors_min_y, Vector3(corridor.aabb_min).y)
		corridors_max_y = maxf(corridors_max_y, Vector3(corridor.aabb_max).y)
	var other_solids: Array = []
	for solid in _near(_solid_buckets, corridors_min_y, corridors_max_y):
		if not launch_floor.has(solid):
			other_solids.append(solid)
	# The throw line ends on this station's own hook point, so only other geometry can block it.
	var structure_solids: Array[Dictionary] = []
	for i in plan_solids.size():
		if plan.pieces[i].material == &"ledge":
			structure_solids.append(plan_solids[i])
	for corridor in corridors:
		if _segment_hits_wall(corridor.a, corridor.b, float(corridor.radius) * 0.7):
			return false
		var own_solids: Array[Dictionary] = structure_solids if corridor.has("ends_on_hook_point") else plan_solids
		if _corridor_hits_solids(corridor, other_solids) or _corridor_hits_solids(corridor, own_solids):
			return false
	plan["corridors"] = corridors
	plan["solids"] = plan_solids
	return true


## The hook's flight from the hand to where a player aims (just above the hook point, so a slightly
## high throw drops onto it): a low ballistic arc, kept clear so nothing deflects the throw.
func _throw_flight_corridors(hand: Vector3, target: Vector3) -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	var delta: Vector3 = target - hand
	var flat: Vector3 = Vector3(delta.x, 0.0, delta.z)
	var distance: float = flat.length()
	var speed_squared: float = hook_throw_speed * hook_throw_speed
	var root: float = speed_squared * speed_squared - hook_throw_gravity * (hook_throw_gravity * distance * distance + 2.0 * delta.y * speed_squared)
	if distance < 0.5 or root < 0.0:
		return corridors
	var launch_angle: float = atan((speed_squared - sqrt(root)) / (hook_throw_gravity * distance))
	var horizontal_speed: float = hook_throw_speed * cos(launch_angle)
	var vertical_speed: float = hook_throw_speed * sin(launch_angle)
	var direction: Vector3 = flat / distance
	var steps: int = maxi(ceili(distance / 0.9), 2)
	var previous: Vector3 = hand
	for i in range(1, steps + 1):
		var travelled: float = distance * float(i) / float(steps)
		var t: float = travelled / horizontal_speed
		var point: Vector3 = hand + direction * travelled + Vector3.UP * (vertical_speed * t - 0.5 * hook_throw_gravity * t * t)
		# Skip the bit right at the hand and the last stretch into the hook point itself.
		if travelled > 0.7 and travelled < distance - 0.9:
			var flight: Dictionary = _corridor(previous, point, 0.3)
			flight["ends_on_hook_point"] = true
			corridors.append(flight)
		previous = point
	return corridors


## Throw line, swing arc and landing space for reaching this station from the one before.
func _transition_corridors(plan: Dictionary) -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	var lip: Vector3 = plan.lip
	var hand: Vector3 = Vector3(plan.launch) + Vector3.UP * rope_attach_height
	var throw_direction: Vector3 = (lip - hand).normalized()
	var rope_at_catch: Dictionary = _corridor(hand + throw_direction * 0.7, lip - throw_direction * 0.9, 0.3)
	rope_at_catch["ends_on_hook_point"] = true
	corridors.append(rope_at_catch)
	for flight in _throw_flight_corridors(hand, plan.throw_target):
		corridors.append(flight)

	# Pendulum from the launch spot down to under the hook point; the body center sits a bit below
	# the rope's attach point.
	var offset: Vector3 = hand - lip
	var rope_length: float = offset.length()
	var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
	var horizontal: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT
	var start_angle: float = atan2(flat.length(), -offset.y)
	var steps: int = maxi(ceili(absf(start_angle) * rope_length / 0.7), 4)
	var previous: Vector3 = Vector3.ZERO
	for i in steps + 1:
		var swing_angle: float = start_angle * (1.0 - float(i) / float(steps))
		var attach: Vector3 = lip + horizontal * rope_length * sin(swing_angle) + Vector3.DOWN * rope_length * cos(swing_angle)
		var body_center: Vector3 = attach + Vector3.DOWN * 0.95
		# Skip the first bit while the player still stands on the launch station.
		if i > 0 and i * 0.7 > 1.2:
			corridors.append(_corridor(previous, body_center, SWING_CORRIDOR_RADIUS))
			# The rope itself sweeps between the hook point and the player; keep that clear too,
			# or the rope bends over something mid-swing and the swing ends too high.
			if i % 2 == 0:
				var rope_direction: Vector3 = (lip - attach).normalized()
				var rope: Dictionary = _corridor(attach + rope_direction * 0.6, lip - rope_direction * 0.9, 0.25)
				rope["ends_on_hook_point"] = true
				corridors.append(rope)
		previous = body_center

	var landing_spot: Vector3 = Vector3(lip.x, float(plan.y), lip.z)
	corridors.append(_corridor(landing_spot + Vector3.UP * 1.0, landing_spot + Vector3.UP * 2.6, 0.8))
	return corridors


func _consecutive_mid_stations() -> int:
	var count: int = 0
	for i in range(_stages.size() - 1, 0, -1):
		if _stages[i].type != STATION_MID:
			break
		count += 1
	return count


## Claims a planned station's space and corridors so later stations keep clear of them.
func _reserve_station(plan: Dictionary) -> void:
	plan["solid_start"] = _solids.size()
	plan["corridor_start"] = _corridors.size()
	for solid in plan.solids:
		_add_solid(solid)
	for corridor in plan.corridors:
		_add_corridor(corridor)


func _unreserve_station(plan: Dictionary) -> void:
	_solids.resize(int(plan.solid_start))
	_corridors.resize(int(plan.corridor_start))
	_rebuild_buckets()


func _add_solid(solid: Dictionary) -> void:
	_solids.append(solid)
	_add_to_buckets(_solid_buckets, solid)


func _add_corridor(corridor: Dictionary) -> void:
	_corridors.append(corridor)
	_add_to_buckets(_corridor_buckets, corridor)


func _add_to_buckets(buckets: Dictionary, item: Dictionary) -> void:
	for bucket in range(floori(Vector3(item.aabb_min).y / BUCKET_HEIGHT), floori(Vector3(item.aabb_max).y / BUCKET_HEIGHT) + 1):
		if not buckets.has(bucket):
			buckets[bucket] = []
		buckets[bucket].append(item)


func _rebuild_buckets() -> void:
	_solid_buckets.clear()
	_corridor_buckets.clear()
	for solid in _solids:
		_add_to_buckets(_solid_buckets, solid)
	for corridor in _corridors:
		_add_to_buckets(_corridor_buckets, corridor)


## Items whose height slices overlap this range; an item spanning slices can appear more than once.
func _near(buckets: Dictionary, y_min: float, y_max: float) -> Array:
	var found: Array = []
	for bucket in range(floori(y_min / BUCKET_HEIGHT), floori(y_max / BUCKET_HEIGHT) + 1):
		if buckets.has(bucket):
			found.append_array(buckets[bucket])
	return found


func _build_station(plan: Dictionary) -> void:
	var main_body: StaticBody3D = null
	for piece in plan.pieces:
		var body: Node3D = _add_box(piece.center, piece.basis, piece.size, _material_for(piece.material), true)
		if bool(piece.get("main", false)):
			main_body = body as StaticBody3D
		elif piece.material == &"ledge":
			body.add_to_group(GROUP_RESPAWN_GROUND)
			body.set_meta(META_RESPAWN_POINT, plan.respawn_point)
	for visual in plan.visuals:
		if visual.has("chain_from"):
			_add_chain_mesh(visual.chain_from, visual.chain_to)
		else:
			_add_box(visual.center, visual.basis, visual.size, _material_for(visual.material), false)
	if main_body != null:
		main_body.add_to_group(GROUP_RESPAWN_GROUND)
		main_body.set_meta(META_RESPAWN_POINT, plan.respawn_point)

	if plan.type == STATION_WALL:
		_add_lamp(_polar(float(plan.angle), float(plan.wall_radius) - 0.3, float(plan.y) + 2.8))
	else:
		_add_lamp(Vector3(plan.platform_center) + Vector3.UP * 2.6 - Vector3(plan.approach) * 1.6)


func _try_add_extra_beam(upper_y: float, lower_y: float) -> void:
	for attempt in 16:
		var angle: float = _rng.randf() * TAU
		var top_y: float = _rng.randf_range(lower_y + 3.0, upper_y + 4.0)
		var wall_radius: float = _wall_radius(angle, top_y - hook_beam_thickness * 0.5)
		var depth: float = _rng.randf_range(hook_beam_depth_min, 2.2)
		var center: Vector3 = _polar(angle, wall_radius - depth * 0.5 + wall_embed * 0.5, top_y - hook_beam_thickness * 0.5)
		var piece: Dictionary = _piece(center, _radial_basis(angle), Vector3(hook_beam_width, hook_beam_thickness, depth + wall_embed), &"beam")
		var solid: Dictionary = _solid_from_piece(piece)
		if _solid_hits_solids(solid, SOLID_MARGIN) or _solid_hits_corridors(solid):
			continue
		if _wall_radius(angle, top_y + 1.2) < wall_radius - depth + 1.0:
			continue
		_add_solid(solid)
		_add_box(piece.center, piece.basis, piece.size, _beam_material, true)
		_add_box(_polar(angle, wall_radius - depth - 0.025, top_y - 0.06), _radial_basis(angle), Vector3(hook_beam_width, 0.12, 0.05), _strip_material, false)
		return


# --- Structures ----------------------------------------------------------------------------

func _add_structures(floor_y: float, top_y: float) -> void:
	var depth: float = top_y - floor_y
	for i in pillar_count:
		_try_add_pillar(floor_y)
	for i in bridge_count:
		_try_add_bridge(floor_y, top_y)
	for i in roundi(depth / maxf(overhang_spacing, 1.0)):
		_try_add_overhang(floor_y, top_y)
	for i in roundi(depth / maxf(rib_spacing, 1.0)):
		_try_add_rib(floor_y, top_y)
	for i in roundi(depth / maxf(buttress_spacing, 1.0)):
		_try_add_buttress(floor_y, top_y)
	for i in pipe_count:
		_try_add_pipe(floor_y, top_y)


func _try_add_pillar(floor_y: float) -> void:
	for attempt in 24:
		var radius: float = _rng.randf_range(pillar_radius_min, pillar_radius_max)
		var height: float = _rng.randf_range(18.0, 70.0)
		var angle: float = _rng.randf() * TAU
		var distance: float = _rng.randf_range(6.0, shaft_radius_min - radius - 3.0)
		var base: Vector3 = Vector3(cos(angle) * distance, floor_y - 1.0, sin(angle) * distance)
		var top: float = floor_y + height
		var fits: bool = true
		var check_y: float = floor_y
		while check_y < top + 1.0:
			if distance + radius > _wall_radius(angle, check_y) - 2.5:
				fits = false
				break
			check_y += 3.0
		if not fits:
			continue
		var column: Dictionary = _piece(base + Vector3.UP * (height + 1.0) * 0.5, Basis.IDENTITY, Vector3(radius * 2.0, height + 1.0, radius * 2.0), &"rock")
		var capital: Dictionary = _piece(Vector3(base.x, top + 0.35, base.z), Basis(Vector3.UP, _rng.randf() * TAU), Vector3(radius * 2.8, 0.7, radius * 2.8), &"ledge")
		if not _pieces_fit([column, capital]):
			continue
		_add_solid(_solid_from_piece(column))
		_add_solid(_solid_from_piece(capital))
		_add_cylinder(base + Vector3.UP * (height + 1.0) * 0.5, radius, height + 1.0, _rock_material, true)
		var capital_body: Node3D = _add_box(capital.center, capital.basis, capital.size, _ledge_material, true)
		capital_body.add_to_group(GROUP_RESPAWN_GROUND)
		capital_body.set_meta(META_RESPAWN_POINT, Vector3(base.x, top + 0.75, base.z))
		_add_lamp(Vector3(base.x, top + 2.2, base.z))
		return


func _try_add_bridge(floor_y: float, top_y: float) -> void:
	for attempt in 30:
		var y: float = _rng.randf_range(floor_y + 12.0, top_y - 16.0)
		var angle_a: float = _rng.randf() * TAU
		var angle_b: float = angle_a + deg_to_rad(_rng.randf_range(110.0, 180.0))
		var end_a: Vector3 = _polar(angle_a, _wall_radius(angle_a, y - 0.3) + wall_embed, y)
		var end_b: Vector3 = _polar(angle_b, _wall_radius(angle_b, y - 0.3) + wall_embed, y)
		var span: Vector3 = end_b - end_a
		var along: Vector3 = Vector3(span.x, 0.0, span.z).normalized()
		var bridge_basis: Basis = Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
		var deck: Dictionary = _piece((end_a + end_b) * 0.5 + Vector3.DOWN * 0.3, bridge_basis, Vector3(span.length(), 0.6, 2.4), &"ledge")
		if not _pieces_fit([deck]):
			continue
		_add_solid(_solid_from_piece(deck))
		var deck_body: Node3D = _add_box(deck.center, deck.basis, deck.size, _ledge_material, true)
		deck_body.add_to_group(GROUP_RESPAWN_GROUND)
		deck_body.set_meta(META_RESPAWN_POINT, (end_a + end_b) * 0.5 + Vector3.UP * 0.05)
		# Low metal rails along both sides and an arch of struts underneath: visual only.
		var deck_basis: Basis = deck.basis
		for side in [-1.0, 1.0]:
			_add_box(deck.center + deck_basis.z * side * 1.12 + Vector3.UP * 0.45, deck_basis, Vector3(span.length(), 0.08, 0.08), _metal_material, false)
		var strut_count: int = maxi(floori(span.length() / 4.0), 2)
		for i in strut_count:
			var t: float = (float(i) + 0.5) / float(strut_count)
			var sag: float = sin(t * PI) * minf(span.length() * 0.12, 4.0)
			var strut_top: Vector3 = end_a.lerp(end_b, t) + Vector3.DOWN * 0.6
			_add_box(strut_top + Vector3.DOWN * sag * 0.5, deck_basis, Vector3(0.18, sag, 0.18), _metal_material, false)
		_add_lamp((end_a + end_b) * 0.5 + Vector3.UP * 1.4)
		return


func _try_add_overhang(floor_y: float, top_y: float) -> void:
	for attempt in 12:
		var angle: float = _rng.randf() * TAU
		var y: float = _rng.randf_range(floor_y + 6.0, top_y - 4.0)
		var wall_radius: float = _wall_radius(angle, y)
		var depth: float = _rng.randf_range(2.0, 4.0)
		var width: float = _rng.randf_range(4.0, 9.0)
		var tilt: float = deg_to_rad(_rng.randf_range(-28.0, 12.0))
		var overhang_basis: Basis = _radial_basis(angle) * Basis(Vector3.RIGHT, tilt)
		var piece: Dictionary = _piece(_polar(angle, wall_radius - depth * 0.5 + wall_embed, y), overhang_basis, Vector3(width, _rng.randf_range(0.8, 1.6), depth + wall_embed * 2.0), &"rock")
		if _place_piece(piece, true):
			return


func _try_add_rib(floor_y: float, top_y: float) -> void:
	for attempt in 12:
		var angle: float = _rng.randf() * TAU
		var y: float = _rng.randf_range(floor_y + 4.0, top_y - 4.0)
		var span_angle: float = deg_to_rad(_rng.randf_range(25.0, 80.0))
		var depth: float = _rng.randf_range(0.6, 1.1)
		var pieces: Array[Dictionary] = []
		var piece_count: int = maxi(ceili(span_angle * shaft_radius_max / 2.0), 2)
		for i in piece_count:
			var piece_angle: float = angle + span_angle * (float(i) / float(piece_count - 1) - 0.5)
			var wall_radius: float = _wall_radius(piece_angle, y)
			var length: float = span_angle / float(piece_count) * wall_radius * 1.15
			pieces.append(_piece(_polar(piece_angle, wall_radius - depth * 0.5 + wall_embed * 0.5, y), _radial_basis(piece_angle), Vector3(length, 0.4, depth + wall_embed), &"rock"))
		if not _pieces_fit(pieces):
			continue
		for piece in pieces:
			_add_solid(_solid_from_piece(piece))
			_add_box(piece.center, piece.basis, piece.size, _rock_material, true)
		return


func _try_add_buttress(floor_y: float, top_y: float) -> void:
	for attempt in 12:
		var angle: float = _rng.randf() * TAU
		var height: float = _rng.randf_range(12.0, 36.0)
		var bottom: float = _rng.randf_range(floor_y, top_y - height)
		var depth: float = _rng.randf_range(1.0, 2.0)
		var width: float = _rng.randf_range(1.4, 2.8)
		# Reach from the closest-in wall along its height out into the farthest, so it never floats.
		var nearest_wall: float = INF
		var farthest_wall: float = 0.0
		var check_y: float = bottom
		while check_y <= bottom + height:
			nearest_wall = minf(nearest_wall, _wall_radius(angle, check_y))
			farthest_wall = maxf(farthest_wall, _wall_radius(angle, check_y))
			check_y += wall_band_height * 0.5
		var inner_face: float = nearest_wall - depth
		var outer_face: float = farthest_wall + wall_embed
		var piece: Dictionary = _piece(_polar(angle, (inner_face + outer_face) * 0.5, bottom + height * 0.5), _radial_basis(angle), Vector3(width, height, outer_face - inner_face), &"rock")
		if _place_piece(piece, true):
			return


func _try_add_pipe(floor_y: float, top_y: float) -> void:
	for attempt in 12:
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(0.3, 0.55)
		var height: float = _rng.randf_range(20.0, 70.0)
		var bottom: float = _rng.randf_range(floor_y, top_y - height)
		var wall_radius: float = INF
		var check_y: float = bottom
		while check_y <= bottom + height:
			wall_radius = minf(wall_radius, _wall_radius(angle, check_y))
			check_y += wall_band_height * 0.5
		var distance: float = wall_radius - radius - 0.15
		var center: Vector3 = _polar(angle, distance, bottom + height * 0.5)
		var piece: Dictionary = _piece(center, _radial_basis(angle), Vector3(radius * 2.0, height, radius * 2.0), &"metal")
		if not _pieces_fit([piece]):
			continue
		_add_solid(_solid_from_piece(piece))
		_add_cylinder(center, radius, height, _metal_material, true)
		# Brackets back to the wall every few meters: visual only.
		var bracket_y: float = bottom + 2.0
		while bracket_y < bottom + height - 1.0:
			var bracket_wall: float = _wall_radius(angle, bracket_y)
			var bracket_length: float = bracket_wall - distance + wall_embed
			_add_box(_polar(angle, distance + bracket_length * 0.5, bracket_y), _radial_basis(angle), Vector3(radius * 1.4, 0.15, bracket_length), _metal_material, false)
			bracket_y += 5.0
		return


## Places a single solid piece if it fits; wall-attached pieces skip the inside-the-shaft check.
func _place_piece(piece: Dictionary, wall_attached: bool) -> bool:
	if not _pieces_fit([piece]):
		return false
	if not wall_attached and _is_inside_wall(piece.center, 0.0):
		return false
	_add_solid(_solid_from_piece(piece))
	_add_box(piece.center, piece.basis, piece.size, _material_for(piece.material), true)
	return true


func _pieces_fit(pieces: Array) -> bool:
	for piece in pieces:
		var solid: Dictionary = _solid_from_piece(piece)
		if _solid_hits_solids(solid, SOLID_MARGIN * 0.5) or _solid_hits_corridors(solid):
			return false
	return true


# --- Geometry checks -----------------------------------------------------------------------

func _piece(center: Vector3, piece_basis: Basis, size: Vector3, material: StringName, main: bool = false) -> Dictionary:
	return {"center": center, "basis": piece_basis, "size": size, "material": material, "main": main}


func _chain(from: Vector3, to: Vector3) -> Dictionary:
	return {"chain_from": from, "chain_to": to}


func _solid_from_piece(piece: Dictionary) -> Dictionary:
	var center: Vector3 = piece.center
	var piece_basis: Basis = Basis(piece.basis).orthonormalized()
	var half: Vector3 = Vector3(piece.size) * 0.5
	var extent: Vector3 = Vector3(
		absf(piece_basis.x.x) * half.x + absf(piece_basis.y.x) * half.y + absf(piece_basis.z.x) * half.z,
		absf(piece_basis.x.y) * half.x + absf(piece_basis.y.y) * half.y + absf(piece_basis.z.y) * half.z,
		absf(piece_basis.x.z) * half.x + absf(piece_basis.y.z) * half.y + absf(piece_basis.z.z) * half.z
	)
	return {"center": center, "basis": piece_basis, "half": half, "aabb_min": center - extent, "aabb_max": center + extent}


func _corridor(a: Vector3, b: Vector3, radius: float) -> Dictionary:
	var pad: Vector3 = Vector3.ONE * radius
	return {"a": a, "b": b, "radius": radius, "aabb_min": a.min(b) - pad, "aabb_max": a.max(b) + pad}


func _aabbs_overlap(a_min: Vector3, a_max: Vector3, b_min: Vector3, b_max: Vector3, margin: float) -> bool:
	return (a_min.x - margin <= b_max.x and a_max.x + margin >= b_min.x
		and a_min.y - margin <= b_max.y and a_max.y + margin >= b_min.y
		and a_min.z - margin <= b_max.z and a_max.z + margin >= b_min.z)


func _solid_hits_solids(solid: Dictionary, margin: float) -> bool:
	for other in _near(_solid_buckets, Vector3(solid.aabb_min).y - margin, Vector3(solid.aabb_max).y + margin):
		if _aabbs_overlap(solid.aabb_min, solid.aabb_max, other.aabb_min, other.aabb_max, margin) and _solids_overlap(solid, other, margin):
			return true
	return false


## Separating-axis test between two boxes, with a margin of empty space required between them.
func _solids_overlap(a: Dictionary, b: Dictionary, margin: float) -> bool:
	var a_basis: Basis = a.basis
	var b_basis: Basis = b.basis
	var a_half: Vector3 = a.half
	var b_half: Vector3 = b.half
	var a_axes: Array[Vector3] = [a_basis.x, a_basis.y, a_basis.z]
	var b_axes: Array[Vector3] = [b_basis.x, b_basis.y, b_basis.z]
	var axes: Array[Vector3] = []
	axes.append_array(a_axes)
	axes.append_array(b_axes)
	for a_axis in a_axes:
		for b_axis in b_axes:
			var cross_axis: Vector3 = a_axis.cross(b_axis)
			if cross_axis.length_squared() > 0.000001:
				axes.append(cross_axis.normalized())
	var offset: Vector3 = Vector3(b.center) - Vector3(a.center)
	for axis in axes:
		var a_reach: float = a_half.x * absf(a_axes[0].dot(axis)) + a_half.y * absf(a_axes[1].dot(axis)) + a_half.z * absf(a_axes[2].dot(axis))
		var b_reach: float = b_half.x * absf(b_axes[0].dot(axis)) + b_half.y * absf(b_axes[1].dot(axis)) + b_half.z * absf(b_axes[2].dot(axis))
		if absf(offset.dot(axis)) > a_reach + b_reach + margin:
			return false
	return true


func _solid_hits_corridors(solid: Dictionary) -> bool:
	for corridor in _near(_corridor_buckets, Vector3(solid.aabb_min).y, Vector3(solid.aabb_max).y):
		if not _aabbs_overlap(solid.aabb_min, solid.aabb_max, corridor.aabb_min, corridor.aabb_max, 0.0):
			continue
		if _segment_hits_solid(corridor.a, corridor.b, corridor.radius, solid):
			return true
	return false


func _corridor_hits_solids(corridor: Dictionary, solids: Array) -> bool:
	for solid in solids:
		if not _aabbs_overlap(solid.aabb_min, solid.aabb_max, corridor.aabb_min, corridor.aabb_max, 0.0):
			continue
		if _segment_hits_solid(corridor.a, corridor.b, corridor.radius, solid):
			return true
	return false


func _segment_hits_solid(a: Vector3, b: Vector3, radius: float, solid: Dictionary) -> bool:
	var steps: int = maxi(ceili(a.distance_to(b) / maxf(radius * 0.8, 0.2)), 1)
	for i in steps + 1:
		if _point_solid_distance(a.lerp(b, float(i) / float(steps)), solid) < radius:
			return true
	return false


func _point_solid_distance(point: Vector3, solid: Dictionary) -> float:
	var solid_basis: Basis = solid.basis
	var half: Vector3 = solid.half
	var local: Vector3 = solid_basis.transposed() * (point - Vector3(solid.center))
	var clamped: Vector3 = Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
	return local.distance_to(clamped)


# --- Building --------------------------------------------------------------------------------

func _build_start_platform(angle: float) -> Dictionary:
	var size: Vector3 = start_platform_size
	var wall_radius: float = _wall_radius(angle, -size.y * 0.5)
	var start_basis: Basis = _radial_basis(angle)
	var piece: Dictionary = _piece(_polar(angle, wall_radius - size.z * 0.5 + wall_embed * 0.5, -size.y * 0.5), start_basis, Vector3(size.x, size.y, size.z + wall_embed), &"ledge", true)
	var start_solid: Dictionary = _solid_from_piece(piece)
	_add_solid(start_solid)
	var station: Dictionary = {
		"type": STATION_START,
		"angle": angle,
		"y": 0.0,
		"depth": size.z,
		"wall_radius": wall_radius,
		"landing_center": _polar(angle, wall_radius - size.z * 0.5, 0.0),
		"landing_basis": start_basis,
		"landing_half": Vector3(size.x * 0.5, 0.0, size.z * 0.5),
		"respawn_point": _polar(angle, wall_radius - size.z * 0.45, 0.05),
		"floor_solids": [start_solid],
	}
	var body: Node3D = _add_box(piece.center, piece.basis, piece.size, _ledge_material, true)
	body.add_to_group(GROUP_RESPAWN_GROUND)
	body.set_meta(META_RESPAWN_POINT, station.respawn_point)
	_add_lamp(_polar(angle, wall_radius - 0.3, 2.8))
	return station


func _add_walls(floor_y: float, top_y: float) -> void:
	var segments: int = maxi(wall_segments, 6)
	var first_band: int = floori((floor_y - 2.0) / wall_band_height)
	var last_band: int = floori(top_y / wall_band_height)
	for band in range(first_band, last_band + 1):
		var band_center_y: float = (float(band) + 0.5) * wall_band_height
		var surface_tool: SurfaceTool = SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var body: StaticBody3D = StaticBody3D.new()
		_generated_root.add_child(body)
		for i in segments:
			var angle: float = TAU * float(i) / float(segments)
			var inner_radius: float = _wall_radius(angle, band_center_y)
			var outer_radius: float = inner_radius + wall_thickness
			var size: Vector3 = Vector3(2.0 * outer_radius * tan(PI / float(segments)) + 0.1, wall_band_height + 0.06, wall_thickness)
			var piece_transform: Transform3D = Transform3D(_radial_basis(angle), _polar(angle, inner_radius + wall_thickness * 0.5, band_center_y))
			var box_mesh: BoxMesh = BoxMesh.new()
			box_mesh.size = size
			surface_tool.append_from(box_mesh, 0, piece_transform)
			var shape: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = size
			shape.shape = box
			shape.transform = piece_transform
			body.add_child(shape)
		surface_tool.generate_tangents()
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = surface_tool.commit()
		mesh_instance.material_override = _rock_material
		body.add_child(mesh_instance)


func _add_floor_and_goal(floor_y: float) -> void:
	var floor_radius: float = shaft_radius_max + wall_bumpiness + wall_thickness
	var floor_body: StaticBody3D = StaticBody3D.new()
	_generated_root.add_child(floor_body)
	floor_body.position = Vector3(0.0, floor_y - 1.0, 0.0)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
	cylinder_shape.radius = floor_radius
	cylinder_shape.height = 2.0
	floor_shape.shape = cylinder_shape
	floor_body.add_child(floor_shape)
	var floor_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = floor_radius
	floor_mesh.bottom_radius = floor_radius
	floor_mesh.height = 2.0
	floor_mesh.radial_segments = maxi(wall_segments, 6)
	floor_mesh.material = _rock_material
	floor_mesh_instance.mesh = floor_mesh
	floor_body.add_child(floor_mesh_instance)
	floor_body.add_to_group(GROUP_RESPAWN_GROUND)
	floor_body.set_meta(META_RESPAWN_POINT, Vector3(0.0, floor_y + 0.05, 0.0))

	# Glowing goal ring in the middle of the floor.
	var ring_instance: MeshInstance3D = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 2.2
	ring.outer_radius = 2.6
	ring.rings = 48
	ring.material = _goal_material
	ring_instance.mesh = ring
	_generated_root.add_child(ring_instance)
	ring_instance.position = Vector3(0.0, floor_y + 0.05, 0.0)
	var goal_light: OmniLight3D = OmniLight3D.new()
	goal_light.light_color = goal_color
	goal_light.light_energy = 3.0
	goal_light.omni_range = 16.0
	_generated_root.add_child(goal_light)
	goal_light.position = Vector3(0.0, floor_y + 2.5, 0.0)

	if Engine.is_editor_hint():
		return
	var goal_area: Area3D = Area3D.new()
	var goal_shape: CollisionShape3D = CollisionShape3D.new()
	var goal_cylinder: CylinderShape3D = CylinderShape3D.new()
	goal_cylinder.radius = 2.6
	goal_cylinder.height = 3.0
	goal_shape.shape = goal_cylinder
	goal_area.add_child(goal_shape)
	_generated_root.add_child(goal_area)
	goal_area.position = Vector3(0.0, floor_y + 1.5, 0.0)
	goal_area.body_entered.connect(func(body: Node3D) -> void: goal_reached.emit(body))


func _set_start(start: Dictionary, first: Dictionary) -> void:
	var start_position: Vector3 = start.respawn_point
	var look_target: Vector3 = Vector3(first.lip) if not first.is_empty() else Vector3(0.0, 0.05, 0.0)
	var look_direction: Vector3 = Vector3(look_target.x - start_position.x, 0.0, look_target.z - start_position.z)
	var start_basis: Basis = Basis.IDENTITY
	if look_direction.length_squared() > 0.001:
		start_basis = Basis.looking_at(look_direction.normalized(), Vector3.UP)
	_start_transform = Transform3D(start_basis, start_position)

	var spawn_marker: Node3D = get_node_or_null(player_spawn_path) as Node3D
	if spawn_marker != null:
		spawn_marker.global_transform = _start_transform


func _add_lamp(lamp_position: Vector3) -> void:
	var lamp_mesh: MeshInstance3D = MeshInstance3D.new()
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.14
	bulb.height = 0.28
	bulb.material = _lamp_material
	lamp_mesh.mesh = bulb
	_generated_root.add_child(lamp_mesh)
	lamp_mesh.position = lamp_position
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = lamp_color
	lamp.light_energy = lamp_energy
	lamp.omni_range = lamp_range
	lamp.shadow_enabled = false
	_generated_root.add_child(lamp)
	lamp.position = lamp_position + Vector3.DOWN * 0.2


func _add_chain_mesh(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length <= 0.01:
		return
	var chain: CylinderMesh = CylinderMesh.new()
	chain.top_radius = 0.05
	chain.bottom_radius = 0.05
	chain.height = length
	chain.radial_segments = 6
	chain.rings = 1
	chain.material = _metal_material
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = chain
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated_root.add_child(mesh_instance)
	mesh_instance.position = (from + to) * 0.5


func _add_cylinder(center: Vector3, radius: float, height: float, material: Material, with_collision: bool) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = material
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if not with_collision:
		_generated_root.add_child(mesh_instance)
		mesh_instance.position = center
		return
	var body: StaticBody3D = StaticBody3D.new()
	_generated_root.add_child(body)
	body.position = center
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	body.add_child(mesh_instance)


func _add_box(center: Vector3, box_basis: Basis, size: Vector3, material: Material, with_collision: bool) -> Node3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if not with_collision:
		_generated_root.add_child(mesh_instance)
		mesh_instance.transform = Transform3D(box_basis, center)
		return mesh_instance

	var body: StaticBody3D = StaticBody3D.new()
	_generated_root.add_child(body)
	body.transform = Transform3D(box_basis, center)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mesh_instance)
	return body


func _material_for(key: StringName) -> Material:
	match key:
		&"beam":
			return _beam_material
		&"metal":
			return _metal_material
		&"strip":
			return _strip_material
		&"rock":
			return _rock_material
	return _ledge_material


func _clear_generated() -> void:
	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		remove_child(old_root)
		old_root.queue_free()
	_generated_root = null


func _build_materials() -> void:
	_rock_material = _make_stone_material(rock_color, 0.18, 1)
	_ledge_material = _make_stone_material(ledge_color, 0.35, 2)

	_beam_material = StandardMaterial3D.new()
	_beam_material.albedo_color = beam_color
	_beam_material.roughness = 0.85

	_metal_material = StandardMaterial3D.new()
	_metal_material.albedo_color = metal_color
	_metal_material.metallic = 0.6
	_metal_material.roughness = 0.5

	_strip_material = StandardMaterial3D.new()
	_strip_material.albedo_color = beam_strip_color
	_strip_material.emission_enabled = true
	_strip_material.emission = beam_strip_color
	_strip_material.emission_energy_multiplier = 1.6

	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = lamp_color
	_lamp_material.emission_enabled = true
	_lamp_material.emission = lamp_color
	_lamp_material.emission_energy_multiplier = 3.0

	_goal_material = StandardMaterial3D.new()
	_goal_material.albedo_color = goal_color
	_goal_material.emission_enabled = true
	_goal_material.emission = goal_color
	_goal_material.emission_energy_multiplier = 2.5


## Rough stone with a world-space noise texture, so long walls never show stretched UVs.
func _make_stone_material(color: Color, uv_scale: float, noise_seed: int) -> StandardMaterial3D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.02
	noise.fractal_octaves = 4

	var albedo_texture: NoiseTexture2D = NoiseTexture2D.new()
	albedo_texture.noise = noise
	albedo_texture.seamless = true
	albedo_texture.width = 256
	albedo_texture.height = 256
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, color.darkened(0.35))
	gradient.set_color(1, color.lightened(0.15))
	albedo_texture.color_ramp = gradient

	var normal_texture: NoiseTexture2D = NoiseTexture2D.new()
	normal_texture.noise = noise
	normal_texture.seamless = true
	normal_texture.width = 256
	normal_texture.height = 256
	normal_texture.as_normal_map = true
	normal_texture.bump_strength = 6.0

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = albedo_texture
	material.normal_enabled = true
	material.normal_texture = normal_texture
	material.roughness = 0.95
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * uv_scale
	return material


func _polar(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


## Basis for a piece on the wall at `angle`: X along the wall, Y up, Z through the wall.
func _radial_basis(angle: float) -> Basis:
	var outward: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
	var along_wall: Vector3 = Vector3(-sin(angle), 0.0, cos(angle))
	return Basis(along_wall, Vector3.UP, -outward)
