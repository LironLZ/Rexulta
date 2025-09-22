extends Control

@export var attr_row_scene: PackedScene = preload("res://scenes//ui//AttributeRow.tscn")

@onready var title_l:   Label         = $Margin/Panel/VBox/Title
@onready var list:      GridContainer = $Margin/Panel/VBox/List
@onready var close_btn: Button        = $Margin/Panel/VBox/CloseRow/CloseBtn

var order := ["attack", "dex", "defense", "magic"]

func _ready() -> void:
	_build_attribute_rows()
	_refresh_header()

	close_btn.pressed.connect(_on_close)

	State.level_up.connect(_on_level_up)
	State.ability_points_changed.connect(_on_ap_changed)
	State.skill_points_changed.connect(_on_sp_changed)

func _on_close() -> void:
	visible = false

func _on_level_up(_new_level: int) -> void:
	_refresh_header()

func _on_ap_changed(_remaining: int) -> void:
	_refresh_header()

func _on_sp_changed(_remaining: int) -> void:
	_refresh_header()

func _build_attribute_rows() -> void:
	for c in list.get_children():
		c.queue_free()
	for k in order:
		if not State.attributes.has(k):
			continue
		var row := attr_row_scene.instantiate()
		row.key = k
		list.add_child(row)

func _refresh_header() -> void:
	title_l.text = "Character — Lv %d   AP: %d   SP: %d" % [State.level, State.ability_points, State.skill_points]
