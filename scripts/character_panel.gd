extends Control

# Set these in the Inspector
@export var attr_row_scene: PackedScene
@export var attack_icon: Texture2D  # optional bicep icon to pass to the row

@onready var frame: NinePatchRect  = $Margin/Panel
@onready var ap_l:   Label         = $Margin/Panel/InnerPad/VBox/APHeader/APLabel
@onready var list:   GridContainer = $Margin/Panel/InnerPad/VBox/List

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)

	# place frame mid-left
	if frame:
		if frame.size == Vector2.ZERO:
			frame.custom_minimum_size = Vector2(240, 180)
			frame.size = frame.custom_minimum_size
		var H := get_viewport_rect().size.y
		frame.position = Vector2(32, (H - frame.size.y) * 0.5)

	_build_rows()
	_refresh_ap()

	State.ability_points_changed.connect(_on_ap_changed)
	State.level_up.connect(_on_level_up)

func _build_rows() -> void:
	for c in list.get_children():
		c.queue_free()
	list.columns = 1

	if attr_row_scene == null:
		push_error("CharacterPanel: attr_row_scene not assigned")
		return

	var row := attr_row_scene.instantiate()
	if row == null:
		push_error("CharacterPanel: failed to instance attr_row_scene")
		return

	# Configure the Attack row (AttributeRow.gd expects 'key' and optional 'icon')
	row.set("key", "attack")
	if attack_icon:
		row.set("icon", attack_icon)
	list.add_child(row)

func _refresh_ap() -> void:
	ap_l.text = "Attribute Points: %d" % State.ability_points

func _on_ap_changed(_remaining: int) -> void:
	_refresh_ap()

func _on_level_up(_n: int) -> void:
	_refresh_ap()
