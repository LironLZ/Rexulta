extends HBoxContainer

@export var key: String = "attack"
@export var icon: Texture2D

@onready var icon_n:  TextureRect   = $Icon
@onready var name_l:  Label         = $Name
@onready var plus_b:  TextureButton = $Plus

func _ready() -> void:
	if icon:
		icon_n.texture = icon
	icon_n.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	$Spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plus_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	if not State.attributes.has(key):
		push_error("AttributeRow: unknown key %s" % key)
		queue_free()
		return

	name_l.text = State.attributes[key].name
	_update_ui()

	plus_b.pressed.connect(_on_plus_pressed)
	State.ability_points_changed.connect(_on_ap_changed)
	State.attribute_changed.connect(_on_attr_changed)

func _on_plus_pressed() -> void:
	if State.add_attr_alloc(key, 1):
		_update_ui()

func _on_ap_changed(_remaining: int) -> void:
	_update_ui()

func _on_attr_changed(changed: String, _val: int) -> void:
	if changed == key:
		_update_ui()

func _update_ui() -> void:
	plus_b.disabled = not State.can_alloc_attr(key, 1)
