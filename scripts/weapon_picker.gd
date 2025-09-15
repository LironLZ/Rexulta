extends PopupPanel
@onready var bow_btn: Button  = %BowBtn
@onready var wand_btn: Button = %WandBtn

func _ready():
	bow_btn.pressed.connect(func(): _choose("bow"))
	wand_btn.pressed.connect(func(): _choose("wand"))
	# show on load if no weapon chosen
	_maybe_open()
	State.connect("mode_changed", Callable(self, "_maybe_open"))

func _maybe_open(_m := ""):
	if State.chosen_weapon == "":
		popup_centered()

func _choose(id: String):
	State.choose_weapon(id)
	hide()
