extends Node2D

@onready var label: Label = $Label

@export var rise_distance: float = 18.0
@export var duration: float      = 0.6
@export var color_normal: Color  = Color(1, 1, 1)
@export var color_crit: Color    = Color(1.0, 0.85, 0.3)

func show_value(value: float, is_crit: bool = false) -> void:
	label.text = String.num(value, 0)
	label.modulate = color_crit if is_crit else color_normal
	z_index = 100  # draw above actors

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", position + Vector2(0, -rise_distance), duration)
	tw.parallel().tween_property(label, "modulate:a", 0.0, duration)
	tw.finished.connect(queue_free)
