extends Node2D

@export var ore_interval := 5.0
var t: Timer

func _ready() -> void:
	t = get_node_or_null("OreTimer") as Timer
	if t == null:
		t = Timer.new()
		t.name = "OreTimer"
		add_child(t)
	t.wait_time = ore_interval
	t.one_shot = false
	t.autostart = false
	if not t.timeout.is_connected(_on_ore_tick):
		t.timeout.connect(_on_ore_tick)

	if not State.is_connected("mode_changed", _on_mode_changed):
		State.connect("mode_changed", Callable(self, "_on_mode_changed"))
	_on_mode_changed(State.mode)

func _on_mode_changed(_m: String) -> void:
	var active := (State.mode == "mining")
	if active:
		if t.is_stopped(): t.start()
	else:
		t.stop()

func _on_ore_tick() -> void:
	if State.mode != "mining": return
	State.ore += 1
	State.add_xp(0.5)

func _unhandled_input(event: InputEvent) -> void:
	if State.mode != "mining": return
	if event is InputEventMouseButton and event.pressed:
		# Clicking speeds up next tick a bit
		var reduce = min(0.3, t.time_left * 0.4)
		t.start(max(0.1, t.time_left - reduce))
