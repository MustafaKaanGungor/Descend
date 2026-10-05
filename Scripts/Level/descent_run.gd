extends Node
## Runs a descent level: puts the player back on the last ledge they stood on after a long
## fall, and builds the next level when they reach the goal at the bottom of the shaft.

const GROUP_RESPAWN_GROUND: StringName = &"respawn_ground"
const META_RESPAWN_POINT: StringName = &"respawn_point"
const METHOD_RESPAWN_AT: StringName = &"respawn_at"

@export_group("Nodes")
@export var generator_path: NodePath = NodePath("../LevelGenerator")
@export var player_path: NodePath = NodePath("../Player")

@export_group("Respawn")
## Falling this far below the last ledge stood on puts the player back on it.
@export var respawn_fall_distance: float = 16.0

var _generator: Node3D
var _player: CharacterBody3D
var _safe_point: Vector3 = Vector3.ZERO
var _has_safe_point: bool = false
var _is_changing_level: bool = false


func _ready() -> void:
	_generator = get_node_or_null(generator_path) as Node3D
	if _generator != null and _generator.has_signal(&"goal_reached"):
		_generator.connect(&"goal_reached", _on_goal_reached)


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as CharacterBody3D
		if _player == null:
			return

	_update_safe_point()
	if _has_safe_point and _player.global_position.y < _safe_point.y - respawn_fall_distance:
		_respawn(_safe_point, _player.rotation.y)


func _update_safe_point() -> void:
	if not _player.is_on_floor():
		return
	for i in _player.get_slide_collision_count():
		var collision: KinematicCollision3D = _player.get_slide_collision(i)
		if collision.get_normal().y < 0.7:
			continue
		var collider: Node = collision.get_collider() as Node
		if collider != null and collider.is_in_group(GROUP_RESPAWN_GROUND) and collider.has_meta(META_RESPAWN_POINT):
			_safe_point = Vector3(collider.get_meta(META_RESPAWN_POINT))
			_has_safe_point = true
			return


func _respawn(spawn_position: Vector3, yaw: float) -> void:
	if _player.has_method(METHOD_RESPAWN_AT):
		_player.call(METHOD_RESPAWN_AT, spawn_position, yaw)


func _on_goal_reached(body: Node3D) -> void:
	if body != _player or _is_changing_level:
		return
	_is_changing_level = true
	# Rebuilding collision from inside a physics callback isn't allowed; do it right after.
	_start_next_level.call_deferred()


func _start_next_level() -> void:
	if _generator != null and _generator.has_method(&"generate_next_level"):
		_generator.call(&"generate_next_level")
		var start: Transform3D = Transform3D(_generator.call(&"get_start_transform"))
		_has_safe_point = false
		if _player != null and is_instance_valid(_player):
			_respawn(start.origin, start.basis.get_euler().y)
	_is_changing_level = false
