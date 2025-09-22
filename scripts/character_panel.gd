extends Control

@export var attr_row_scene: PackedScene = preload("res://scenes//ui//AttributeRow.tscn")

@onready var frame:   NinePatchRect = $Margin/Panel
@onready var ap_l:    Label         = $Margin/Panel/VBox/APHeader/APLabel
@onready var list:    GridContainer = $Margin/Panel/VBox/List

func _ready() -> void:
	# ensure the panel blocks input and sits mid-left
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	if frame:
		if frame.size == Vector2.ZERO:
			frame.custom_minimum_size = Vector2(240, 180)
			frame.size = frame.custom_minimum_size
		var H := get_viewport_rect().size.y
		frame.position = Vector2(32, (H - frame.size.y) * 0.5)

	_build_rows()
	_refresh_ap()

	# live updates
	State.ability_points_changed.connect(_on_ap_changed)
	State.level_up.connect(_on_level_up)

func _build_rows() -> void:
	for c in list.get_children():
		c.queue_free()

	# Attack only for now
	var row := attr_row_scene.instantiate()
	# If your AttributeRow.gd default key is "attack" you don't need to set this,
	# but no harm either:
	row.key = "attack"
	list.columns = 1
	list.add_child(row)

func _refresh_ap() -> void:
	# shows remaining AP (should be 20 at level 5 if you haven't spent any)
	ap_l.text = "Attribute Points: %d" % State.ability_points

func _on_ap_changed(_remaining: int) -> void:
	_refresh_ap()

func _on_level_up(_new: int) -> void:
	_refresh_ap()
