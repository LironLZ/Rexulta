extends Control

signal play_requested
signal settings_requested
signal quit_requested

# Buttons (paths are relative to THIS node)
@onready var btn_play: TextureButton     = get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer/Play")
@onready var btn_settings: TextureButton = get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer/Settings")
@onready var btn_quit: TextureButton     = get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer/Quit")

func _ready() -> void:
	# Focus Play for keyboard/controller
	focus_default()

	# Safe connects (avoid null crashes)
	if btn_play:
		btn_play.pressed.connect(func(): play_requested.emit())
	else:
		push_error("UIRoot: Play button not found at CenterContainer/HBoxContainer/Play")

	if btn_settings:
		btn_settings.pressed.connect(func(): settings_requested.emit())
	else:
		push_error("UIRoot: Settings button not found at CenterContainer/HBoxContainer/Settings")

	if btn_quit:
		btn_quit.pressed.connect(func(): quit_requested.emit())
	else:
		push_error("UIRoot: Quit button not found at CenterContainer/HBoxContainer/Quit")

# Allow Main to restore focus when returning to menu
func focus_default() -> void:
	if btn_play:
		btn_play.grab_focus()

# (Editor-signal stubs are fine; they just emit our own signals)
func _on_play_pressed() -> void:
	play_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()
