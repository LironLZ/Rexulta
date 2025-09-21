extends CanvasLayer

# ------- Existing stats + top bar -------
@onready var gold_l:   Label  = $Root/StatsBox/GoldLabel
@onready var lvl_l:    Label  = $Root/StatsBox/LvlLabel
@onready var inv_l:    Label  = $Root/StatsBox/InvLabel
@onready var arena_b:  Button = $Root/TopBar/ArenaBtn
@onready var fish_b:   Button = $Root/TopBar/FishingBtn
@onready var mine_b:   Button = $Root/TopBar/MiningBtn
@onready var ascend_b: Button = $Root/TopBar/AscendBtn

# ------- New drawer bits (live in Main.tscn under Hud/HUDRoot) -------
@onready var _arrow_btn: TextureButton = $HUDRoot/ArrowMenuButton
@onready var _tabs_root: Control       = $HUDRoot/QuickTabs

# Drawer config
const TABS_Y_STEP := 48      # vertical spacing between items
const SHOW_TIME   := 0.18    # seconds for tween
const HIDDEN_POS  := Vector2(-150, 16)   # offscreen position for items
var _tabs_open := false

func _ready() -> void:
	# Root must not eat mouse, and must fill viewport
	var root := $Root as Control
	if root:
		root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		root.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		push_error("HUD: Missing $Root Control inside Hud.tscn")

	# >>> NEW: make HUDRoot fill the screen too
	var hudroot := $HUDRoot as Control
	if hudroot:
		hudroot.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	else:
		push_error("HUD: Missing $HUDRoot in Main.tscn under Hud")

	# Top bar setup (unchanged)
	for b in [arena_b, fish_b, mine_b]:
		if b:
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(arena_b):  arena_b.pressed.connect(_on_arena)
	if is_instance_valid(fish_b):   fish_b.pressed.connect(_on_fishing)
	if is_instance_valid(mine_b):   mine_b.pressed.connect(_on_mining)
	if is_instance_valid(ascend_b): ascend_b.pressed.connect(_on_ascend)

	# Arrow button
	if is_instance_valid(_arrow_btn):
		_arrow_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
		_arrow_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_arrow_btn.z_index = 100
		_place_arrow_button(_arrow_btn, 16)   # <<< use offsets, not position
		_arrow_btn.pressed.connect(_toggle_tabs)
	else:
		push_error("HUD: ArrowMenuButton not found at $HUDRoot/ArrowMenuButton")

	# QuickTabs container and initial hide
	if is_instance_valid(_tabs_root):
		_tabs_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
		# keep its own (0,0) as the stacking origin; leave offsets default
		_set_tabs_visible(false, true)
	else:
		push_error("HUD: QuickTabs not found at $HUDRoot/QuickTabs")

	# State signals
	if Engine.has_singleton("State"):
		State.level_up.connect(_refresh)
		State.mode_changed.connect(_refresh)
		State.unlocks_changed.connect(_refresh)

	_refresh()

# Helper: place a bottom-right anchored control with a pixel margin
func _place_arrow_button(ctrl: Control, margin_px: int) -> void:
	# compute the visual size once (so the hitbox matches the art)
	var sz := ctrl.size
	if sz == Vector2.ZERO:
		# Try to infer from TextureButton art if size hasn't been set yet
		if "texture_normal" in ctrl and ctrl.texture_normal:
			sz = ctrl.texture_normal.get_size()
			ctrl.custom_minimum_size = sz
	# With anchors at bottom-right, set offsets (margins) like this:
	ctrl.offset_right  = -margin_px
	ctrl.offset_bottom = -margin_px
	ctrl.offset_left   = ctrl.offset_right  - sz.x
	ctrl.offset_top    = ctrl.offset_bottom - sz.y

func _process(_dt: float) -> void:
	_refresh()

func _unhandled_input(e: InputEvent) -> void:
	# quick debug toggle
	if e is InputEventKey and e.pressed and !e.echo and e.keycode == KEY_U:
		_toggle_tabs()

# ------- Drawer logic -------

func _toggle_tabs() -> void:
	_tabs_open = !_tabs_open
	_set_tabs_visible(_tabs_open, false)

func _set_tabs_visible(v: bool, instant: bool) -> void:
	if !is_instance_valid(_tabs_root):
		return

	var items: Array[CanvasItem] = []
	for child in _tabs_root.get_children():
		if child is CanvasItem:
			items.append(child as CanvasItem)

	var i := 0
	for item in items:
		item.visible = true
		item.mouse_filter = Control.MOUSE_FILTER_STOP if item is Control else item.mouse_filter
		var target_pos := Vector2(0, -i * TABS_Y_STEP)

		if instant:
			item.position = (target_pos if v else HIDDEN_POS)
			var c := item.modulate
			c.a = (1.0 if v else 0.0)
			item.modulate = c
		else:
			var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "position", (target_pos if v else HIDDEN_POS), SHOW_TIME)
			tw.parallel().tween_property(item, "modulate:a", (1.0 if v else 0.0), SHOW_TIME)
			if !v:
				tw.tween_callback(func(): item.visible = false)

		i += 1

# ------- Existing behavior -------

func _on_arena() -> void:  State.set_mode("arena")
func _on_fishing() -> void: State.set_mode("fishing")
func _on_mining() -> void:  State.set_mode("mining")

func _on_ascend() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	State.ascend()
	State.set_mode("arena")

func _refresh() -> void:
	if is_instance_valid(gold_l):
		gold_l.text = "Gold: " + String.num(State.gold, 0)
	if is_instance_valid(lvl_l):
		lvl_l.text  = "Lv: %d  (XP %.0f)" % [State.level, State.xp]
	if is_instance_valid(inv_l):
		inv_l.text  = "Fish: %d   Ore: %d" % [State.fish, State.ore]

	if is_instance_valid(fish_b):
		fish_b.visible   = State.fishing_unlocked
	if is_instance_valid(mine_b):
		mine_b.visible   = State.mining_unlocked
	if is_instance_valid(ascend_b):
		ascend_b.visible = State.ascend_unlocked

	var m := State.mode
	if is_instance_valid(arena_b):
		arena_b.button_pressed = (m == "arena"); arena_b.disabled = (m == "arena")
	if is_instance_valid(fish_b):
		fish_b.button_pressed  = (m == "fishing"); fish_b.disabled  = (m == "fishing")
	if is_instance_valid(mine_b):
		mine_b.button_pressed  = (m == "mining");  mine_b.disabled  = (m == "mining")
