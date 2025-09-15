extends Node

@export var enemy_scene: PackedScene = preload("res://scenes/actors/Enemy.tscn")
@export var count: int = 6
@export var start_x: float = 80.0
@export var spacing: float = 96.0
@export var wave_x_drift: float = 12.0

var ground_top_y: float = 330.0
var wave_index: int = 0
@onready var _timer: Timer = Timer.new()

func _ready():
	_compute_ground_y()
	add_child(_timer)
	_timer.wait_time = 4.0
	_timer.one_shot = false
	_timer.timeout.connect(spawn_wave)
	State.connect("mode_changed", Callable(self, "_on_mode_changed"))

	if State.mode == "arena":
		_timer.start()
		call_deferred("spawn_wave")
	else:
		_timer.stop()

func _on_mode_changed(_m: String) -> void:
	if State.mode == "arena":
		if _timer.is_stopped(): _timer.start()
		call_deferred("spawn_wave")
	else:
		_timer.stop()

func _compute_ground_y():
	var ground = get_parent().get_node_or_null("Ground")
	if ground:
		var cshape = ground.get_node_or_null("CollisionShape2D")
		if cshape and cshape.shape is RectangleShape2D:
			var rect: RectangleShape2D = cshape.shape
			ground_top_y = ground.position.y - rect.size.y * 0.5
		else:
			ground_top_y = ground.position.y

func spawn_wave():
	if State.mode != "arena": return
	var parent = get_parent()
	var x_offset = start_x + wave_index * wave_x_drift
	for i in range(count):
		var e = enemy_scene.instantiate()
		e.position = Vector2(x_offset + i * spacing, ground_top_y)
		parent.call_deferred("add_child", e)
	wave_index += 1
