extends HBoxContainer

@export var key: String = "attack"
@export var icon: Texture2D

@onready var value_l: Label         = get_node_or_null("Value")
@onready var icon_n:  TextureRect   = get_node_or_null("Icon")
@onready var name_l:  Label         = get_node_or_null("Name")
@onready var plus_b:  TextureButton = get_node_or_null("PlusPad/Plus") 

func _ready() -> void:
	if value_l == null:  push_warning("[AttrRow] Missing Label 'Value'")
	if icon_n == null:   push_warning("[AttrRow] Missing TextureRect 'Icon'")
	if name_l == null:   push_warning("[AttrRow] Missing Label 'Name'")
	if plus_b == null:   push_warning("[AttrRow] Missing TextureButton 'PlusPad/Plus'")

	
	if icon_n:
		if icon: icon_n.texture = icon
		icon_n.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if name_l:
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var spacer := get_node_or_null("Spacer")
	if spacer: spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if plus_b:
		plus_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# validate the stat key
	if not State.attributes.has(key):
		push_error("[AttrRow] Unknown key '%s'" % key)
		queue_free()
		return

	if name_l:
		name_l.text = State.attributes[key].name

	# hook signals
	if plus_b:
		plus_b.pressed.connect(_on_plus_pressed)
	State.ability_points_changed.connect(func(_r): _refresh())
	State.attribute_changed.connect(func(changed: String, _v: int):
		if changed == key: _refresh()
	)

	# first paint
	_refresh()
	print("[AttrRow] Ready for key=", key, " AP=", State.ability_points, " total=", State.get_attr_total(key))

func _on_plus_pressed() -> void:
	var can := State.can_alloc_attr(key, 1)
	print("[AttrRow] + pressed (key=", key, ") can_alloc=", can, " AP=", State.ability_points)
	if can:
		var ok := State.add_attr_alloc(key, 1)
		print("[AttrRow] add_attr_alloc returned ", ok, " new total=", State.get_attr_total(key), " AP=", State.ability_points)
	_refresh()

func _refresh() -> void:
	# update number and button state
	if value_l:
		value_l.text = str(State.get_attr_total(key))
	if plus_b:
		plus_b.disabled = not State.can_alloc_attr(key, 1)
