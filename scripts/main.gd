extends Node2D

@onready var _arena:   Node = $Arena
@onready var _fishing: Node = $FishingZone
@onready var _mining:  Node = $MiningZone

@onready var _menu_layer: CanvasLayer = $MainMenu/CanvasLayer
@onready var _menu: Control = $MainMenu/CanvasLayer/UIRoot

# HUD is a CanvasLayer at $Hud
@onready var _hud_layer: CanvasLayer = $Hud

func _ready() -> void:
	# Menu should work while paused AND be above the HUD
	_menu_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_menu_layer.layer = 100   # draw on top of everything UI-ish

	State.connect("mode_changed", Callable(self, "_apply_mode"))
	_apply_mode(State.mode)

	_enter_menu()

	if is_instance_valid(_menu):
		_menu.play_requested.connect(_on_play_requested)
		_menu.settings_requested.connect(_on_settings_requested)
		_menu.quit_requested.connect(_on_quit_requested)

# --- helpers to toggle HUD ---

func _set_hud_visible(v: bool) -> void:
	if not is_instance_valid(_hud_layer):
		return
	# stop the whole HUD from processing / receiving input
	_hud_layer.process_mode = Node.PROCESS_MODE_INHERIT if v else Node.PROCESS_MODE_DISABLED
	# hide/show all visible UI under the layer
	for child in _hud_layer.get_children():
		if child is CanvasItem:
			child.visible = v

# --- menu / gameplay switching ---

func _enter_menu() -> void:
	_set_gameplay_enabled(false)
	if is_instance_valid(_menu):
		_menu.visible = true
		_menu.process_mode = Node.PROCESS_MODE_INHERIT
	_set_hud_visible(false)          # <<< hide HUD on menu
	get_tree().paused = true
	if is_instance_valid(_menu) and _menu.has_method("focus_default"):
		_menu.focus_default()

func _start_game() -> void:
	if is_instance_valid(_menu):
		_menu.visible = false
		_menu.process_mode = Node.PROCESS_MODE_DISABLED
	_set_gameplay_enabled(true)
	_set_hud_visible(true)           # <<< show HUD in gameplay
	get_tree().paused = false
	_apply_mode(State.mode)

# --- unchanged below ---
func _set_gameplay_enabled(enabled: bool) -> void:
	var pm := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	_arena.process_mode   = pm
	_fishing.process_mode = pm
	_mining.process_mode  = pm

	_arena.visible   = enabled and (State.mode == "arena")
	_fishing.visible = enabled and (State.mode == "fishing")
	_mining.visible  = enabled and (State.mode == "mining")

func _apply_mode(_m := State.mode) -> void:
	var gameplay_on := (_arena.process_mode != Node.PROCESS_MODE_DISABLED) \
		or (_fishing.process_mode != Node.PROCESS_MODE_DISABLED) \
		or (_mining.process_mode != Node.PROCESS_MODE_DISABLED)
	_arena.visible   = gameplay_on and (State.mode == "arena")
	_fishing.visible = gameplay_on and (State.mode == "fishing")
	_mining.visible  = gameplay_on and (State.mode == "mining")

func _on_play_requested() -> void:
	State.mode = "arena"
	_start_game()

func _on_settings_requested() -> void:
	pass

func _on_quit_requested() -> void:
	if OS.has_feature("web"): return
	get_tree().quit()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_enter_menu()
	if e.is_action_pressed("ui_fullscreen"):
		var cur := DisplayServer.window_get_mode()
		var full := DisplayServer.WINDOW_MODE_FULLSCREEN
		var win := DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(win if cur == full else full)
