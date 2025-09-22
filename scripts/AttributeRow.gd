extends HBoxContainer

@export var key: String

@onready var name_l:  Label  = $Name
@onready var total_l: Label  = $Total
@onready var minus_b: Button = $Minus
@onready var plus_b:  Button = $Plus

func _ready() -> void:
	if not State.attributes.has(key):
		push_error("AttributeRow: unknown key %s" % key)
		queue_free()
		return

	name_l.text = State.attributes[key].name
	_refresh()

	plus_b.pressed.connect(_on_plus_pressed)
	minus_b.pressed.connect(_on_minus_pressed)

	State.ability_points_changed.connect(_on_ap_changed)
	State.attribute_changed.connect(_on_attr_changed)

func _on_plus_pressed() -> void:
	if State.add_attr_alloc(key, 1):
		_refresh()

func _on_minus_pressed() -> void:
	if State.refund_attr_alloc(key, 1):
		_refresh()

func _on_ap_changed(_remaining: int) -> void:
	_refresh()

func _on_attr_changed(changed: String, _val: int) -> void:
	if changed == key:
		_refresh()

func _refresh() -> void:
	total_l.text = "Total: %d" % State.get_attr_total(key)
	plus_b.disabled  = not State.can_alloc_attr(key, 1)
	minus_b.disabled = State.attributes[key].alloc <= 0
