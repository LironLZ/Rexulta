extends Control

# Set these in the Inspector
@export var attr_row_scene: PackedScene
@export var attack_icon: Texture2D  # optional bicep icon to pass to the row

@onready var frame: NinePatchRect  = $Margin/Panel
@onready var ap_l:   Label         = $Margin/Panel/InnerPad/VBox/APHeader/APLabel
@onready var list:   GridContainer = $Margin/Panel/InnerPad/VBox/List



func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)

	# Let children receive events; labels don't block clicks.
	if frame:
		frame.mouse_filter = Control.MOUSE_FILTER_PASS

	var inner := $Margin/Panel/InnerPad
	if inner: inner.mouse_filter = Control.MOUSE_FILTER_PASS

	var vbox := $Margin/Panel/InnerPad/VBox
	if vbox: vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var header := $Margin/Panel/InnerPad/VBox/APHeader
	if header: header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if list:
		list.mouse_filter = Control.MOUSE_FILTER_PASS
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
	
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		print("[Panel] got click at ", get_global_mouse_position())
