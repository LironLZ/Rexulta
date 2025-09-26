extends Control

# Row scene + icons (assign in Inspector)
@export var attr_row_scene: PackedScene
@export var attack_icon: Texture2D
@export var dex_icon: Texture2D
@export var defense_icon: Texture2D
@export var int_icon: Texture2D

# Base weapon damage range for the hint
@export var base_min_damage: int = 1
@export var base_max_damage: int = 4

@onready var frame: NinePatchRect = $Margin/Panel
@onready var ap_l: Label = $Margin/Panel/InnerPad/VBox/APHeader/APLabel
@onready var list: GridContainer = $Margin/Panel/InnerPad/VBox/List
@onready var range_hint: Label = %RangeHint

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)

	if frame:
		frame.mouse_filter = Control.MOUSE_FILTER_PASS
		# place mid-left
		if frame.size == Vector2.ZERO:
			frame.custom_minimum_size = Vector2(240, 180)
			frame.size = frame.custom_minimum_size
		var viewport_height := get_viewport_rect().size.y
		frame.position = Vector2(32, (viewport_height - frame.size.y) * 0.5)

	var inner := $Margin/Panel/InnerPad
	if inner:
		inner.mouse_filter = Control.MOUSE_FILTER_PASS
	var vbox := $Margin/Panel/InnerPad/VBox
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	var header := $Margin/Panel/InnerPad/VBox/APHeader
	if header:
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if list:
		list.mouse_filter = Control.MOUSE_FILTER_PASS

	_build_rows()
	_refresh_ap()
	_refresh_range_hint()

	State.ability_points_changed.connect(_on_ap_changed)
	State.level_up.connect(_on_level_up)
	State.attribute_changed.connect(_on_attribute_changed)

func _build_rows() -> void:
	for child in list.get_children():
		child.queue_free()
	list.columns = 1

	if attr_row_scene == null:
		push_error("CharacterPanel: attr_row_scene not assigned")
		return

	var rows := [
		{"key": "attack", "icon": attack_icon},
		{"key": "dex", "icon": dex_icon},
		{"key": "defense", "icon": defense_icon},
		{"key": "magic", "icon": int_icon}, # displays as "Intelligence"
	]

	for row_def in rows:
		var row := attr_row_scene.instantiate()
		if row == null:
			push_error("CharacterPanel: failed to instance attr_row_scene")
			continue
		row.set("key", row_def["key"])
		if row_def["icon"]:
			row.set("icon", row_def["icon"])
		list.add_child(row)

func _refresh_ap() -> void:
	ap_l.text = "Attribute Points: %d" % State.ability_points

func _on_ap_changed(_remaining: int) -> void:
	_refresh_ap()

func _on_level_up(_level: int) -> void:
	_refresh_ap()
	_refresh_range_hint()

# ===== Damage scaling display (from Attack) =====
func _refresh_range_hint() -> void:
	if !is_instance_valid(range_hint):
		return

	var base_range := Economy.weapon_melee_range()
	var base_min := base_range.x if base_range.x > 0 else base_min_damage
	var base_max := base_range.y if base_range.y > 0 else base_max_damage
	if base_max < base_min:
		base_max = base_min

	var scaled := State.get_attack_scaled_range(base_min, base_max, Economy.weapon_attack_bonus())
	range_hint.text = "Damage Range: %d-%d" % [scaled.x, scaled.y]

func _on_attribute_changed(key: String, _value: int) -> void:
	if key == "attack" or key == "dex":
		_refresh_range_hint()

# (Optional debug)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[Panel] got click at ", get_global_mouse_position())
