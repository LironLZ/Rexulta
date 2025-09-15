extends Node2D

@export var bite_interval := 3.0
var t: Timer

func _ready() -> void:
	# Ensure we have a timer even if the scene didn't contain one or it was misnamed.
	t = get_node_or_null("BiteTimer") as Timer
	if t == null:
		t = Timer.new()
		t.name = "BiteTimer"
		add_child(t)
	t.wait_time = bite_interval
	t.one_shot = false
	t.autostart = false
	if not t.timeout.is_connected(_on_bite):
		t.timeout.connect(_on_bite)

	if not State.is_connected("mode_changed", _on_mode_changed):
		State.connect("mode_changed", Callable(self, "_on_mode_changed"))
	_on_mode_changed(State.mode)  # apply current mode on load

func _on_mode_changed(_m: String) -> void:
	var active := (State.mode == "fishing")
	if active:
		if t.is_stopped(): t.start()
	else:
		t.stop()

func _on_bite() -> void:
	if State.mode != "fishing": return
	State.fish += 1
	State.add_xp(0.5)
