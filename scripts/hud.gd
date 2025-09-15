extends CanvasLayer

@onready var gold_l: Label = $Root/StatsBox/GoldLabel
@onready var lvl_l:  Label = $Root/StatsBox/LvlLabel
@onready var inv_l:  Label = $Root/StatsBox/InvLabel
@onready var arena_b:   Button = $Root/TopBar/ArenaBtn
@onready var fish_b:    Button = $Root/TopBar/FishingBtn
@onready var mine_b:    Button = $Root/TopBar/MiningBtn
@onready var ascend_b: Button = $Root/TopBar/AscendBtn

func _ready():
	arena_b.pressed.connect(func(): State.set_mode("arena"))
	fish_b.pressed.connect(func(): State.set_mode("fishing"))
	mine_b.pressed.connect(func(): State.set_mode("mining"))
	ascend_b.pressed.connect(_on_ascend)
	State.connect("level_up", Callable(self, "_refresh"))
	State.connect("mode_changed", Callable(self, "_refresh"))
	_refresh()
	
func _on_arena():   print("HUD: Arena pressed");   State.set_mode("arena")
func _on_fishing(): print("HUD: Fishing pressed"); State.set_mode("fishing")
func _on_mining():  print("HUD: Mining pressed");  State.set_mode("mining")

func _process(_dt: float) -> void:
	_refresh()

func _refresh() -> void:
	gold_l.text = "Gold: " + String.num(State.gold, 0)
	lvl_l.text  = "Lv: %d  (XP %.0f)" % [State.level, State.xp]
	inv_l.text  = "Fish: %d   Ore: %d" % [State.fish, State.ore]

func _on_ascend():
	# clear any remaining arena enemies
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	State.ascend()
	# after ascend, weapon is blank -> weapon picker will pop automatically
	State.set_mode("arena")
