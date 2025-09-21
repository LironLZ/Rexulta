# Main.gd
extends Node2D

@onready var _arena:   Node = $Arena
@onready var _fishing: Node = $FishingZone
@onready var _mining:  Node = $MiningZone

@onready var _menu_layer: CanvasLayer = $MainMenu/CanvasLayer
@onready var _menu_root: CanvasItem   = $MainMenu/CanvasLayer/MenuRoot
@onready var _menu: Control           = $MainMenu/CanvasLayer/MenuRoot/UIRoot
@onready var _hud := $Hud 
@onready var _hud_layer: CanvasLayer  = $Hud

func _ready() -> void:
	# Menu should render above gameplay and still run while paused.
	_menu_layer.layer = 100
	_menu_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	State.connect("mode_changed", Callable(self, "_apply_mode"))
	_apply_mode(State.mode)
	_enter_menu()

	if is_instance_valid(_menu):
		_menu.play_requested.connect(_on_play_requested)
		_menu.settings_requested.connect(_on_settings_requested)
		_menu.quit_requested.connect(_on_quit_requested)

# Recursively show/hide + enable/disable a subtree
func _toggle_menu(on: bool) -> void:
	if not is_instance_valid(_menu_root): return
	_menu_root.visible = on
	_menu_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED if on else Node.PROCESS_MODE_DISABLED
	for child in _menu_root.get_children():
		_toggle_node(child, on)

func _toggle_node(n: Node, on: bool) -> void:
	if n is CanvasItem:
		n.visible = on
	n.process_mode = Node.PROCESS_MODE_WHEN_PAUSED if on else Node.PROCESS_MODE_DISABLED
	for c in n.get_children():
		_toggle_node(c, on)

func _set_hud_visible(v: bool) -> void:
	_hud_layer.process_mode = Node.PROCESS_MODE_INHERIT if v else Node.PROCESS_MODE_DISABLED
	for child in _hud_layer.get_children():
		if child is CanvasItem:
			child.visible = v

func _enter_menu() -> void:
	_set_gameplay_enabled(false)
	_toggle_menu(true)          # <<< show menu subtree
	_set_hud_visible(false)
	get_tree().paused = true
	if is_instance_valid(_menu) and _menu.has_method("focus_default"):
		_menu.focus_default()
	if is_instance_valid(_hud):
		_hud.visible = false 

func _start_game() -> void:
	_toggle_menu(false)         # <<< hide/disable *entire* menu subtree
	_set_gameplay_enabled(true)
	_set_hud_visible(true)
	get_tree().paused = false
	if is_instance_valid(_hud):
		_hud.visible = true 
	_apply_mode(State.mode)

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
