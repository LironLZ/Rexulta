extends PopupPanel

var bow_btn: Button
var wand_btn: Button

func _ready() -> void:
	# Find buttons by name anywhere under this scene (no unique-name needed)
	bow_btn  = find_child("BowBtn",  true, false) as Button
	wand_btn = find_child("WandBtn", true, false) as Button

	# Guard so we don't crash if names don't match yet
	if not bow_btn or not wand_btn:
		push_error("WeaponPicker: BowBtn/WandBtn not found. Check names in WeaponPicker.tscn.")
		return

	bow_btn.pressed.connect(func(): _choose("bow"))
	wand_btn.pressed.connect(func(): _choose("wand"))

	# Show if no weapon is chosen yet
	if not State.is_connected("mode_changed", _maybe_open):
		State.connect("mode_changed", Callable(self, "_maybe_open"))
	_maybe_open()

func _maybe_open(_m := "") -> void:
	if State.chosen_weapon == "":
		popup_centered()

func _choose(id: String) -> void:
	State.choose_weapon(id)
	hide()
