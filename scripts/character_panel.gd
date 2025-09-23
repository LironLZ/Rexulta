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

@onready var frame: NinePatchRect  = $Margin/Panel
@onready var ap_l:   Label         = $Margin/Panel/InnerPad/VBox/APHeader/APLabel
@onready var list:   GridContainer = $Margin/Panel/InnerPad/VBox/List
@onready var range_hint: Label     = %RangeHint

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)

	if frame:
		frame.mouse_filter = Control.MOUSE_FILTER_PASS
		# place mid-left
		if frame.size == Vector2.ZERO:
			frame.custom_minimum_size = Vector2(240, 180)
			frame.size = frame.custom_minimum_size
		var H := get_viewport_rect().size.y
		frame.position = Vector2(32, (H - frame.size.y) * 0.5)

	var inner := $Margin/Panel/InnerPad
	if inner: inner.mouse_filter = Control.MOUSE_FILTER_PASS
	var vbox := $Margin/Panel/InnerPad/VBox
	if vbox: vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	var header := $Margin/Panel/InnerPad/VBox/APHeader
	if header: header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if list: list.mouse_filter = Control.MOUSE_FILTER_PASS

	_build_rows()
	_refresh_ap()
	_refresh_range_hint()

	State.ability_points_changed.connect(_on_ap_changed)
	State.level_up.connect(_on_level_up)
	State.attribute_changed.connect(func(key: String, _v: int):
		if key == "attack":
			_refresh_range_hint()
	)

func _build_rows() -> void:
	for c in list.get_children():
		c.queue_free()
	list.columns = 1

	if attr_row_scene == null:
		push_error("CharacterPanel: attr_row_scene not assigned")
		return

	var rows := [
		{"key":"attack",  "icon": attack_icon},
		{"key":"dex",     "icon": dex_icon},
		{"key":"defense", "icon": defense_icon},
		{"key":"magic",   "icon": int_icon}, # displays as "Intelligence"
	]

	for r in rows:
		var row := attr_row_scene.instantiate()
		if row == null:
			push_error("CharacterPanel: failed to instance attr_row_scene")
			continue
		row.set("key",  r["key"])
		if r["icon"]:
			row.set("icon", r["icon"])
		list.add_child(row)

func _refresh_ap() -> void:
	ap_l.text = "Attribute Points: %d" % State.ability_points

func _on_ap_changed(_remaining: int) -> void:
	_refresh_ap()

func _on_level_up(_n: int) -> void:
	_refresh_ap()
	_refresh_range_hint()

# ===== Damage scaling display (from Attack) =====
func _refresh_range_hint() -> void:
	if not is_instance_valid(range_hint):
		return
	var dm := _compute_scaled_damage(base_min_damage, base_max_damage)
	range_hint.text = "Damage: %d–%d" % [dm.x, dm.y]

func _compute_scaled_damage(min_base: int, max_base: int) -> Vector2i:
	var atk_total := State.get_attr_total("attack")
	var mult := 1.0 + 0.10 * float(atk_total)
	var new_min := int(ceil(float(min_base) * mult))
	var new_max := int(ceil(float(max_base) * mult))
	return Vector2i(new_min, new_max)

# (Optional debug)
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		print("[Panel] got click at ", get_global_mouse_position())
