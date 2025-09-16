extends Node2D

@onready var _arena:   Node = $Arena
@onready var _fishing: Node = $FishingZone
@onready var _mining:  Node = $MiningZone

func _ready() -> void:
	State.connect("mode_changed", Callable(self, "_apply_mode"))
	_apply_mode(State.mode)

func _apply_mode(_m := State.mode) -> void:
	_arena.visible   = (State.mode == "arena")
	_fishing.visible = (State.mode == "fishing")
	_mining.visible  = (State.mode == "mining")

func _unhandled_input(e: InputEvent) -> void:
	# F11 fullscreen toggle (add Input Map action "ui_fullscreen" bound to F11).
	if e.is_action_pressed("ui_fullscreen"):
		var cur := DisplayServer.window_get_mode()
		var full := DisplayServer.WINDOW_MODE_FULLSCREEN
		var win  := DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode( win if cur == full else full )
