extends CanvasLayer

@onready var gold_l:   Label  = $Root/StatsBox/GoldLabel
@onready var lvl_l:    Label  = $Root/StatsBox/LvlLabel
@onready var inv_l:    Label  = $Root/StatsBox/InvLabel
@onready var arena_b:  Button = $Root/TopBar/ArenaBtn
@onready var fish_b:   Button = $Root/TopBar/FishingBtn
@onready var mine_b:   Button = $Root/TopBar/MiningBtn
@onready var ascend_b: Button = $Root/TopBar/AscendBtn

func _ready() -> void:
	# Make the mode buttons behave like toggles and avoid keyboard focus outlines.
	for b in [arena_b, fish_b, mine_b]:
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE

	arena_b.pressed.connect(_on_arena)
	fish_b.pressed.connect(_on_fishing)
	mine_b.pressed.connect(_on_mining)
	ascend_b.pressed.connect(_on_ascend)

	State.connect("level_up", Callable(self, "_refresh"))
	State.connect("mode_changed", Callable(self, "_refresh"))
	_refresh()

func _on_arena() -> void:
	State.set_mode("arena")

func _on_fishing() -> void:
	State.set_mode("fishing")

func _on_mining() -> void:
	State.set_mode("mining")

func _on_ascend() -> void:
	# Clear any remaining arena enemies, reset run, return to arena.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	State.ascend()
	State.set_mode("arena")

func _process(_dt: float) -> void:
	_refresh()

func _refresh() -> void:
	gold_l.text = "Gold: " + String.num(State.gold, 0)
	lvl_l.text  = "Lv: %d  (XP %.0f)" % [State.level, State.xp]
	inv_l.text  = "Fish: %d   Ore: %d" % [State.fish, State.ore]

	# Reflect active mode visually.
	var m := State.mode
	arena_b.button_pressed = (m == "arena")
	fish_b.button_pressed  = (m == "fishing")
	mine_b.button_pressed  = (m == "mining")

	# Optionally disable the active one so it looks locked-in.
	arena_b.disabled = (m == "arena")
	fish_b.disabled  = (m == "fishing")
	mine_b.disabled  = (m == "mining")
