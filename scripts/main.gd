extends Node2D
@onready var _arena:   Node = $Arena
@onready var _fishing: Node = $FishingZone
@onready var _mining:  Node = $MiningZone

func _ready():
	State.connect("mode_changed", Callable(self, "_apply_mode"))
	_apply_mode(State.mode)

func _apply_mode(_m := State.mode) -> void:
	print("Main._apply_mode -> ", State.mode)
	_arena.visible   = (State.mode == "arena")
	_fishing.visible = (State.mode == "fishing")
	_mining.visible  = (State.mode == "mining")
