# res://scripts/spawner.gd
extends Node

@export var enemy_scene: PackedScene = preload("res://scenes/actors/Enemy.tscn")
@export var spawn_x: float = 160.0          # where to place the enemy horizontally
@export var respawn_delay: float = 0.8       # time before next enemy after death

var _ground_top_y: float = 320.0
var _current: Node2D = null

@onready var _timer := Timer.new()

func _ready() -> void:
	_compute_ground_y()

	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_maybe_spawn)

	# react to arena/other modes
	State.connect("mode_changed", Callable(self, "_on_mode_changed"))
	_on_mode_changed(State.mode)

	# start after the scene finishes setting up
	call_deferred("_maybe_spawn")

func _on_mode_changed(_m: String) -> void:
	if State.mode == "arena":
		# if there isn't an enemy, schedule one
		if _current == null and _timer.is_stopped():
			_timer.start(0.1)
	else:
		# leaving arena: stop timer (enemy can remain or be cleared elsewhere)
		_timer.stop()

func _compute_ground_y() -> void:
	var ground := get_parent().get_node_or_null("Ground")
	if ground:
		var col := ground.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			var rect: RectangleShape2D = col.shape
			_ground_top_y = ground.position.y - rect.size.y * 0.5
		else:
			_ground_top_y = ground.position.y

func _maybe_spawn() -> void:
	if State.mode != "arena":
		return
	# safety: if anything already in the enemies group, don't spawn
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return
	if is_instance_valid(_current):
		return

	var e := enemy_scene.instantiate() as Node2D
	e.position = Vector2(spawn_x, _ground_top_y)
	_current = e

	# when the enemy leaves the scene (dies/cleared), schedule the next
	e.tree_exited.connect(func():
		_current = null
		if State.mode == "arena":
			_timer.start(respawn_delay)
	)

	# add safely after parent is ready
	get_parent().call_deferred("add_child", e)
