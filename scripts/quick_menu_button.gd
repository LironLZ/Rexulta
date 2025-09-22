extends Control

signal toggled(open: bool)

@export var open := false  # true = expanded, false = collapsed

@onready var _btn: TextureButton = $Button

func _ready() -> void:
	if _btn:
		_btn.pressed.connect(_on_pressed)

func _on_pressed() -> void:
	open = !open
	toggled.emit(open)  
