@tool
extends Node3D
## Builds a circular descent level: a deep round shaft with ledges spiralling down its wall
## and a hook beam above each ledge. Each beam is placed so that hooking it from the ledge
## before and swinging across the shaft bottoms out just above the next ledge.
## Generates when the scene starts (a new layout every run while level_seed is 0) and
## previews in the editor; use the Regenerate button to roll a new one.

signal generated
## The player reached the goal on the shaft floor.
signal goal_reached(body: Node3D)

const GROUP_RESPAWN_GROUND: StringName = &"respawn_ground"
const META_RESPAWN_POINT: StringName = &"respawn_point"
const GENERATED_ROOT_NAME: String = "Generated"
## Extra vertical gap kept between pieces so the player fits between them.
const PIECE_VERTICAL_CLEARANCE: float = 2.6
const PIECE_SIDE_CLEARANCE: float = 0.8

@export_tool_button("Regenerate", "Reload") var regenerate_action: Callable = regenerate

@export_group("Seed")
## 0 builds a new random layout every time; any other value always builds the same level.
@export var level_seed: int = 0

@export_group("Shaft")
## Inner radius of the shaft wall.
@export var shaft_radius: float = 11.0
@export var wall_thickness: float = 2.0
## Flat wall pieces around the circle. More is rounder.
@export var wall_segments: int = 28
## Wall height above the start platform.
@export var wall_height_above_start: float = 10.0
## Floor depth below the last ledge.
@export var floor_depth_below_last_ledge: float = 7.0

@export_group("Stages")
## Ledges below the start platform.
@export var stage_count: int = 10
## Height drop from one ledge to the next.
@export var stage_drop_min: float = 6.0
@export var stage_drop_max: float = 11.0
## How far around the shaft the next ledge is.
@export var stage_angle_min_degrees: float = 55.0
@export var stage_angle_max_degrees: float = 120.0
## Chance per stage that the spiral switches direction.
@export_range(0.0, 1.0) var direction_flip_chance: float = 0.25

@export_group("Ledges")
## Start platform size: width along the wall, thickness, depth out from the wall.
@export var start_platform_size: Vector3 = Vector3(7.0, 0.8, 4.5)
@export var ledge_width_min: float = 3.6
@export var ledge_width_max: float = 5.5
@export var ledge_depth_min: float = 2.6
@export var ledge_depth_max: float = 3.6
@export var ledge_thickness: float = 0.7
## How far ledges and beams sink into the wall so there is no gap.
@export var wall_embed: float = 0.3

@export_group("Hook Beams")
## Beam size: width along the wall, thickness, depth out from the wall.
@export var hook_beam_size: Vector3 = Vector3(2.6, 0.45, 1.4)
## Height on the body where the rope attaches. Keep equal to MovementHook.body_attach_height.
@export var rope_attach_height: float = 1.9
## Rope length when the hook catches; keep under MovementHook.max_rope_length.
@export var max_initial_rope_length: float = 15.0
## Beam lip must sit at least this far above the player's hand on the ledge before it.
@export var min_anchor_height_above_hand: float = 1.0
## Feet clear the next ledge by this much at the bottom of the swing.
@export var swing_landing_clearance: float = 0.4
## Chance per stage of an extra beam somewhere on the wall, for alternate routes.
@export_range(0.0, 1.0) var extra_beam_chance: float = 0.6

@export_group("Look")
@export var rock_color: Color = Color(0.36, 0.33, 0.31)
@export var ledge_color: Color = Color(0.52, 0.49, 0.45)
@export var beam_color: Color = Color(0.33, 0.21, 0.12)
## Glowing strip on each beam's lip so hook points read from across the shaft.
@export var beam_strip_color: Color = Color(1.0, 0.62, 0.25)
@export var lamp_color: Color = Color(1.0, 0.72, 0.42)
@export var lamp_energy: float = 2.2
@export var lamp_range: float = 11.0
@export var goal_color: Color = Color(0.3, 0.95, 0.85)

@export_group("Nodes")
## Marker the level's main script spawns the player at.
@export var player_spawn_path: NodePath = NodePath("../PlayerSpawn")

var _generated_root: Node3D
var _pieces: Array[Dictionary] = []
var _stages: Array[Dictionary] = []
var _current_seed: int = 0
var _start_transform: Transform3D = Transform3D.IDENTITY
var _rock_material: StandardMaterial3D
var _ledge_material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _strip_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _goal_material: StandardMaterial3D


func _ready() -> void:
	regenerate()


func get_current_seed() -> int:
	return _current_seed


func get_start_transform() -> Transform3D:
	return _start_transform


## Ledges from the start platform down: {angle, y, depth, width}. Every ledge after the
## first also has anchor_y, the lip height of the hook beam above it.
func get_stages() -> Array[Dictionary]:
	return _stages


func get_shaft_radius() -> float:
	return shaft_radius


## Builds the next level: the following seed when a seed is set, otherwise a new random one.
func generate_next_level() -> void:
	if level_seed != 0:
		level_seed += 1
	regenerate()


func regenerate() -> void:
	_clear_generated()
	_build_materials()
	_pieces.clear()
	_stages.clear()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	_current_seed = level_seed
	if _current_seed == 0:
		_current_seed = randi_range(1, 2147483646)
	rng.seed = _current_seed

	_generated_root = Node3D.new()
	_generated_root.name = GENERATED_ROOT_NAME
	add_child(_generated_root)

	var start_angle: float = rng.randf() * TAU
	var current: Dictionary = {
		"angle": start_angle,
		"y": 0.0,
		"depth": start_platform_size.z,
	}
	_add_ledge(start_angle, 0.0, start_platform_size.x, start_platform_size.z, start_platform_size.y)
	_stages.append({"angle": start_angle, "y": 0.0, "depth": start_platform_size.z, "width": start_platform_size.x})

	var direction: float = 1.0 if rng.randf() < 0.5 else -1.0
	var first_anchor: Vector3 = Vector3.ZERO
	for stage in stage_count:
		if rng.randf() < direction_flip_chance:
			direction = -direction
		var next: Dictionary = _plan_stage(rng, current, direction)
		if next.is_empty():
			push_warning("Level generator: no valid stage %d for seed %d; level ends early." % [stage, _current_seed])
			break
		_add_hook_beam(next.angle, next.anchor_y)
		_add_ledge(next.angle, next.y, next.width, next.depth, ledge_thickness)
		_stages.append(next)
		if stage == 0:
			first_anchor = _polar(next.angle, shaft_radius - hook_beam_size.z, next.anchor_y)
		if rng.randf() < extra_beam_chance:
			_try_add_extra_beam(rng, current.y, next.y)
		current = next

	var floor_y: float = float(current.y) - floor_depth_below_last_ledge
	var top_y: float = wall_height_above_start
	_add_walls(floor_y, top_y)
	_add_floor_and_goal(floor_y)
	_set_start(start_angle, first_anchor)
	print("Descent level generated. Seed: %d" % _current_seed)
	generated.emit()


## Picks where the next ledge and the beam above it go. Returns {} when nothing fits.
func _plan_stage(rng: RandomNumberGenerator, current: Dictionary, direction: float) -> Dictionary:
	for attempt in 160:
		# Half the attempts go the other way around the shaft, in case this side is crowded.
		var attempt_direction: float = direction if attempt % 2 == 0 else -direction
		var drop: float = rng.randf_range(stage_drop_min, stage_drop_max)
		var turn: float = deg_to_rad(rng.randf_range(stage_angle_min_degrees, stage_angle_max_degrees)) * attempt_direction
		var angle: float = wrapf(float(current.angle) + turn, 0.0, TAU)
		var width: float = rng.randf_range(ledge_width_min, ledge_width_max)
		var depth: float = rng.randf_range(ledge_depth_min, ledge_depth_max)
		var next_y: float = float(current.y) - drop

		# Swing from the current ledge's outer edge on a rope hooked to the beam's lip.
		# The rope length at the catch decides how low the swing bottoms out; solve the beam
		# height so the bottom of the swing is just above the next ledge:
		#   (v + k)^2 = s^2 + v^2  ->  v = (s^2 - k^2) / (2k)
		# s = horizontal launch-to-lip distance, v = lip height above the hand, k = drop - clearance.
		var launch: Vector3 = _polar(float(current.angle), shaft_radius - float(current.depth), 0.0)
		var lip: Vector3 = _polar(angle, shaft_radius - hook_beam_size.z, 0.0)
		var s: float = Vector2(launch.x - lip.x, launch.z - lip.z).length()
		var k: float = drop - swing_landing_clearance
		if k <= 0.5:
			continue
		var v: float = (s * s - k * k) / (2.0 * k)
		if v < min_anchor_height_above_hand:
			continue
		if v + k > max_initial_rope_length:
			continue

		var anchor_y: float = float(current.y) + rope_attach_height + v
		if _overlaps_piece(angle, width, next_y - ledge_thickness, next_y):
			continue
		if _overlaps_piece(angle, hook_beam_size.x, anchor_y - hook_beam_size.y, anchor_y):
			continue
		return {
			"angle": angle,
			"y": next_y,
			"width": width,
			"depth": depth,
			"anchor_y": anchor_y,
		}
	return {}


func _try_add_extra_beam(rng: RandomNumberGenerator, upper_y: float, lower_y: float) -> void:
	for attempt in 12:
		var angle: float = rng.randf() * TAU
		var top_y: float = rng.randf_range(lower_y + 3.0, upper_y + 4.0)
		if not _overlaps_piece(angle, hook_beam_size.x, top_y - hook_beam_size.y, top_y):
			_add_hook_beam(angle, top_y)
			return


func _overlaps_piece(angle: float, width: float, y_min: float, y_max: float) -> bool:
	var half_angle: float = (width * 0.5 + PIECE_SIDE_CLEARANCE) / maxf(shaft_radius - 1.5, 0.5)
	for piece in _pieces:
		var angle_gap: float = absf(angle_difference(angle, float(piece.angle)))
		if angle_gap > half_angle + float(piece.half_angle):
			continue
		if y_max + PIECE_VERTICAL_CLEARANCE < float(piece.y_min) or y_min - PIECE_VERTICAL_CLEARANCE > float(piece.y_max):
			continue
		return true
	return false


func _register_piece(angle: float, width: float, y_min: float, y_max: float) -> void:
	_pieces.append({
		"angle": angle,
		"half_angle": (width * 0.5) / maxf(shaft_radius - 1.5, 0.5),
		"y_min": y_min,
		"y_max": y_max,
	})


func _add_ledge(angle: float, top_y: float, width: float, depth: float, thickness: float) -> void:
	var size: Vector3 = Vector3(width, thickness, depth + wall_embed)
	var center: Vector3 = _polar(angle, shaft_radius - depth * 0.5 + wall_embed * 0.5, top_y - thickness * 0.5)
	var body: StaticBody3D = _add_box(center, _radial_basis(angle), size, _ledge_material, true) as StaticBody3D
	body.add_to_group(GROUP_RESPAWN_GROUND)
	# Respawn toward the wall side so the player doesn't reappear on the edge.
	body.set_meta(META_RESPAWN_POINT, _polar(angle, shaft_radius - minf(depth * 0.4, 1.4), top_y + 0.05))
	_register_piece(angle, width, top_y - thickness, top_y)

	# Lamp on the wall above the ledge.
	var lamp_position: Vector3 = _polar(angle, shaft_radius - 0.25, top_y + 2.7)
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
	lamp.position = _polar(angle, shaft_radius - 0.6, top_y + 2.6)


func _add_hook_beam(angle: float, top_y: float) -> void:
	var size: Vector3 = Vector3(hook_beam_size.x, hook_beam_size.y, hook_beam_size.z + wall_embed)
	var center: Vector3 = _polar(angle, shaft_radius - hook_beam_size.z * 0.5 + wall_embed * 0.5, top_y - hook_beam_size.y * 0.5)
	_add_box(center, _radial_basis(angle), size, _beam_material, true)
	_register_piece(angle, hook_beam_size.x, top_y - hook_beam_size.y, top_y)

	# Glowing strip on the lip's outer face: visual only, so it can't change how the hook catches.
	var strip_center: Vector3 = _polar(angle, shaft_radius - hook_beam_size.z - 0.025, top_y - 0.06)
	_add_box(strip_center, _radial_basis(angle), Vector3(hook_beam_size.x, 0.12, 0.05), _strip_material, false)


func _add_walls(floor_y: float, top_y: float) -> void:
	var segments: int = maxi(wall_segments, 6)
	var height: float = top_y - floor_y + 2.0
	var center_y: float = floor_y - 1.0 + height * 0.5
	var outer_radius: float = shaft_radius + wall_thickness
	var segment_width: float = 2.0 * outer_radius * tan(PI / float(segments)) + 0.05
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		var center: Vector3 = _polar(angle, shaft_radius + wall_thickness * 0.5, center_y)
		_add_box(center, _radial_basis(angle), Vector3(segment_width, height, wall_thickness), _rock_material, true)


func _add_floor_and_goal(floor_y: float) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	_generated_root.add_child(floor_body)
	floor_body.position = Vector3(0.0, floor_y - 1.0, 0.0)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
	cylinder_shape.radius = shaft_radius + wall_thickness
	cylinder_shape.height = 2.0
	floor_shape.shape = cylinder_shape
	floor_body.add_child(floor_shape)
	var floor_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = shaft_radius + wall_thickness
	floor_mesh.bottom_radius = shaft_radius + wall_thickness
	floor_mesh.height = 2.0
	floor_mesh.radial_segments = maxi(wall_segments, 6) * 2
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
	goal_light.omni_range = 14.0
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


func _set_start(start_angle: float, first_anchor: Vector3) -> void:
	var start_position: Vector3 = _polar(start_angle, shaft_radius - start_platform_size.z * 0.45, 0.05)
	var look_target: Vector3 = first_anchor if first_anchor != Vector3.ZERO else Vector3(0.0, 0.05, 0.0)
	var look_direction: Vector3 = Vector3(look_target.x - start_position.x, 0.0, look_target.z - start_position.z)
	var start_basis: Basis = Basis.IDENTITY
	if look_direction.length_squared() > 0.001:
		start_basis = Basis.looking_at(look_direction.normalized(), Vector3.UP)
	_start_transform = Transform3D(start_basis, start_position)

	var spawn_marker: Node3D = get_node_or_null(player_spawn_path) as Node3D
	if spawn_marker != null:
		spawn_marker.global_transform = _start_transform


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
