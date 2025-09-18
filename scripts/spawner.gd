# res://scripts/spawner.gd
extends Node

@export var enemy_scene: PackedScene = preload("res://scenes/actors/Enemy.tscn")
@export var respawn_delay: float = 0.8

# Placement
@export var ahead_px: float = 64.0            # how far beyond the right screen edge
@export var player_path: NodePath             # set this to your Player (e.g., ../Player)
@export var match_y_bias: float = 0.0         # optional tweak (px), +down / -up

# (optional) fallback ray settings if player_path is missing
@export var use_ground_ray_fallback := true
@export var drop_above_px: float = 200.0
@export var ground_mask: int = 1

var _current: Node2D = null
@onready var _timer: Timer = Timer.new()

var _baseline_feet_y: float = NAN   # cached once per Arena entry

func _ready() -> void:
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_maybe_spawn)

	State.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(State.mode)

	call_deferred("_maybe_spawn")

func _on_mode_changed(m: String) -> void:
	if m == "arena":
		_cache_baseline_feet_y()
		if _current == null and _timer.is_stopped():
			_timer.start(0.1)
	else:
		_timer.stop()
		_baseline_feet_y = NAN

func _cache_baseline_feet_y() -> void:
	var player := get_node_or_null(player_path) as Node2D
	if player:
		_baseline_feet_y = player.global_position.y + _bottom_margin_world(player)
	elif use_ground_ray_fallback:
		var vp := get_viewport()
		var cam: Camera2D = vp.get_camera_2d()
		if cam:
			# ray in center x just to get a floor height
			var from := cam.global_position - Vector2(0, drop_above_px)
			var to   := from + Vector2(0, 2000)
			var params := PhysicsRayQueryParameters2D.create(from, to)
			params.collision_mask = ground_mask
			var hit := vp.get_world_2d().direct_space_state.intersect_ray(params)
			if hit and hit.has("position"):
				_baseline_feet_y = (hit.position as Vector2).y
	if is_nan(_baseline_feet_y):
		# last ditch fallback
		var cam := get_viewport().get_camera_2d()
		_baseline_feet_y = cam.global_position.y if cam else 0.0

# distance from node origin to *bottom* of its collider, in world space
func _bottom_margin_world(body: Node2D) -> float:
	var cs := body.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if cs == null or cs.shape == null:
		return 8.0
	var half_h := 8.0
	if cs.shape is RectangleShape2D:
		half_h = (cs.shape as RectangleShape2D).size.y * 0.5
	elif cs.shape is CapsuleShape2D:
		var cap := cs.shape as CapsuleShape2D
		half_h = cap.height * 0.5 + cap.radius
	elif cs.shape is CircleShape2D:
		half_h = (cs.shape as CircleShape2D).radius
	var scale_y = abs(cs.get_global_transform().get_scale().y)
	var half_h_world = half_h * scale_y
	var offset_world := cs.get_global_position().y - body.get_global_position().y
	return offset_world + half_h_world

func _maybe_spawn() -> void:
	if State.mode != "arena":
		return
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return
	if is_instance_valid(_current) or enemy_scene == null:
		return

	var vp := get_viewport()
	var cam: Camera2D = vp.get_camera_2d()
	if cam == null:
		return

	# X: just beyond the right edge
	var viewport_px: Vector2i = vp.get_visible_rect().size
	var half_w: float = float(viewport_px.x) * 0.5 * cam.zoom.x
	var spawn_x: float = cam.global_position.x + half_w + ahead_px

	# Y: ALWAYS use cached baseline feet height
	if is_nan(_baseline_feet_y):
		_cache_baseline_feet_y()
	var ground_y := _baseline_feet_y

	# Spawn at exact same floor line as player baseline
	var e := enemy_scene.instantiate() as Node2D
	_current = e
	e.add_to_group("enemies")
	get_tree().current_scene.add_child(e)

	var enemy_feet_offset := _bottom_margin_world(e)  # origin -> feet (world px)
	var spawn_pos := Vector2(spawn_x, ground_y - enemy_feet_offset + 15.0)
	e.global_position = spawn_pos.snapped(Vector2.ONE)

	e.tree_exited.connect(func():
		_current = null
		if State.mode == "arena":
			_timer.start(respawn_delay)
	)
