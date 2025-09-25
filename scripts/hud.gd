extends CanvasLayer

# ------- Existing stats + top bar -------
@onready var gold_l:   Label  = $Root/StatsBox/GoldLabel
@onready var lvl_l:    Label  = $Root/StatsBox/LvlLabel
@onready var inv_l:    Label  = $Root/StatsBox/InvLabel
@onready var arena_b:  Button = $Root/TopBar/ArenaBtn
@onready var fish_b:   Button = $Root/TopBar/FishingBtn
@onready var mine_b:   Button = $Root/TopBar/MiningBtn
@onready var ascend_b: Button = $Root/TopBar/AscendBtn

# ------- Drawer bits (live in Main.tscn under Hud/HUDRoot) -------
@onready var _arrow_btn:    TextureButton = $HUDRoot/ArrowMenuButton
@onready var _tabs_root:    Control       = $HUDRoot/QuickTabs
@onready var _btn_upgrades: TextureButton = $HUDRoot/QuickTabs/BtnUpgrades
# NOTE: The scene node is still named BtnCrafting in Main.tscn even though the
# art/intent is the "Skills" tab. Keeping the path avoids breaking the scene
# until we rename the node itself.
@onready var _btn_crafting: TextureButton = $HUDRoot/QuickTabs/BtnCrafting
@onready var _btn_fishing:  TextureButton = $HUDRoot/QuickTabs/BtnFishing
@onready var _btn_mining:   TextureButton = $HUDRoot/QuickTabs/BtnMining
@onready var _btn_settings: TextureButton = $HUDRoot/QuickTabs/BtnSettings

# ------- Panels (live in HUD.tscn under Root) -------
@onready var _panels_root:     Control = $Root/Panels
@onready var _panel_character: Control = $Root/Panels/CharacterPanel
@onready var _panel_skills:    Control = $Root/Panels/SkillsPanel
@onready var _panel_fishing:   Control = $Root/Panels/FishingPanel
@onready var _panel_mining:    Control = $Root/Panels/MiningPanel
@onready var _panel_settings:  Control = $Root/Panels/SettingsPanel

# Drawer config
const SHOW_TIME   := 0.18               # seconds for tween
const HIDDEN_POS  := Vector2(-160, 0)   # offscreen start/end for items (left)
const TABS_MARGIN := 16                 # px from screen edges

# Hover FX config (applies to QuickTabs buttons)
const HOVER_SCALE := Vector2(1.06, 1.06)
const NORMAL_SCALE := Vector2.ONE
const HOVER_TINT := Color(1.08, 1.08, 1.08, 1.0)
const NORMAL_TINT := Color(1, 1, 1, 1)

var _tabs_open := false
var _open_panel: Control = null

func _ready() -> void:
	# Root (HUD.tscn) must fill viewport and pass mouse so HUDRoot can catch it
	var root := $Root as Control
	if root:
		root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		root.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		push_error("HUD: Missing $Root Control inside Hud.tscn")

	# --- IMPORTANT: HUDRoot must NOT eat clicks (it covers the screen) ---
	var hudroot := $HUDRoot as Control
	if hudroot:
		hudroot.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		hudroot.mouse_filter = Control.MOUSE_FILTER_IGNORE   # << was STOP by default
	else:
		push_error("HUD: Missing $HUDRoot in Main.tscn under Hud")

	# Top bar setup
	for b in [arena_b, fish_b, mine_b]:
		if b:
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(arena_b):  arena_b.pressed.connect(_on_arena)
	if is_instance_valid(fish_b):   fish_b.pressed.connect(_on_fishing)
	if is_instance_valid(mine_b):   mine_b.pressed.connect(_on_mining)
	if is_instance_valid(ascend_b): ascend_b.pressed.connect(_on_ascend)

	# Ensure TopBar container itself doesn't blanket-clicks
	var topbar := $Root/TopBar
	if topbar and topbar is Control:
		topbar.mouse_filter = Control.MOUSE_FILTER_PASS  # buttons inside will STOP

	# Ensure StatsBox/labels never block input
	var stats := $Root/StatsBox
	if stats and stats is Control:
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for n in stats.get_children():
			if n is Control: n.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Arrow button bottom-right with exact hitbox
	if is_instance_valid(_arrow_btn):
		_arrow_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
		_arrow_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_arrow_btn.z_index = 100
		_place_bottom_right(_arrow_btn, TABS_MARGIN)
		_arrow_btn.pressed.connect(_toggle_tabs)
	else:
		push_error("HUD: ArrowMenuButton not found at $HUDRoot/ArrowMenuButton")

	# QuickTabs: bottom-left horizontal row
	if is_instance_valid(_tabs_root):
		_tabs_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
		_tabs_root.offset_left   = TABS_MARGIN
		_tabs_root.offset_bottom = -TABS_MARGIN
		_tabs_root.mouse_filter = Control.MOUSE_FILTER_PASS  # container passes; buttons stop
		# Ensure it doesn't stretch strangely
		if _tabs_root is HBoxContainer:
			var hb := _tabs_root as HBoxContainer
			hb.alignment = BoxContainer.ALIGNMENT_END
			hb.clip_contents = false
		_set_tabs_visible(false, true)
	else:
		push_error("HUD: QuickTabs not found at $HUDRoot/QuickTabs")

	# Hook up quick-tab buttons (press actions)
        if is_instance_valid(_btn_upgrades): _btn_upgrades.pressed.connect(_on_tab_character) # reuse the old "Upgrades" button
        if is_instance_valid(_btn_crafting): _btn_crafting.pressed.connect(_on_tab_skills)
        if is_instance_valid(_btn_fishing):  _btn_fishing.pressed.connect(_on_tab_fishing)
        if is_instance_valid(_btn_mining):   _btn_mining.pressed.connect(_on_tab_mining)
        if is_instance_valid(_btn_settings): _btn_settings.pressed.connect(_on_tab_settings)

	# --- Hover FX for all QuickTabs buttons ---
	_wire_all_tab_hovers()

	# Panels config (they live under Root/Panels)
	if is_instance_valid(_panels_root):
		_panels_root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_panels_root.visible = false
		_panels_root.mouse_filter = Control.MOUSE_FILTER_PASS   # << allow children to handle clicks
		_panels_root.z_index = 200
		_hide_all_panels(true)
	else:
		push_error("HUD: Root/Panels not found")

	# State signals
	if Engine.has_singleton("State"):
		State.level_up.connect(_refresh)
		State.mode_changed.connect(_refresh)
		State.unlocks_changed.connect(_refresh)

	_refresh()

# --- Hover helper (non-invasive; works even if you have a hover sprite) ---
func _wire_hover_button(b: TextureButton) -> void:
	if !is_instance_valid(b):
		return
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# ensure sensible hitbox if layout is tight
	if b.custom_minimum_size == Vector2.ZERO and b.texture_normal:
		b.custom_minimum_size = b.texture_normal.get_size()

	# reset to normal state on ready
	b.scale = NORMAL_SCALE
	b.modulate = NORMAL_TINT

	# connect once
	if not b.mouse_entered.is_connected(_on_btn_hover_in.bind(b)):
		b.mouse_entered.connect(_on_btn_hover_in.bind(b))
	if not b.mouse_exited.is_connected(_on_btn_hover_out.bind(b)):
		b.mouse_exited.connect(_on_btn_hover_out.bind(b))
	# also play nice with keyboard/gamepad focus changes if they ever happen
	if not b.focus_entered.is_connected(_on_btn_hover_in.bind(b)):
		b.focus_entered.connect(_on_btn_hover_in.bind(b))
	if not b.focus_exited.is_connected(_on_btn_hover_out.bind(b)):
		b.focus_exited.connect(_on_btn_hover_out.bind(b))

func _wire_all_tab_hovers() -> void:
	if !is_instance_valid(_tabs_root):
		return
	# Catch any existing or future TextureButtons dropped into the quick-tab row.
	for child in _tabs_root.get_children():
		if child is TextureButton:
			_wire_hover_button(child)

func _on_btn_hover_in(b: TextureButton) -> void:
	if !is_instance_valid(b): return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", HOVER_SCALE, 0.08)
	t.parallel().tween_property(b, "modulate", HOVER_TINT, 0.08)

func _on_btn_hover_out(b: TextureButton) -> void:
	if !is_instance_valid(b): return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", NORMAL_SCALE, 0.08)
	t.parallel().tween_property(b, "modulate", NORMAL_TINT, 0.08)

# Place a bottom-right anchored Control with pixel margin and exact hitbox.
func _place_bottom_right(ctrl: Control, margin_px: int) -> void:
	var sz := ctrl.size
	if sz == Vector2.ZERO and ctrl.has_method("get") and ctrl.has_property("texture_normal") and ctrl.texture_normal:
		sz = ctrl.texture_normal.get_size()
		ctrl.custom_minimum_size = sz
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

# ------- Drawer logic (slide/fade whole row) -------

func _toggle_tabs() -> void:
	_tabs_open = !_tabs_open
	_set_tabs_visible(_tabs_open, false)

func _set_tabs_visible(v: bool, instant: bool) -> void:
	if !is_instance_valid(_tabs_root):
		return

	# We animate the container itself (so children keep their layout).
	var start_x := HIDDEN_POS.x
	var end_x   := 0.0
	var target := end_x if v else start_x

	_tabs_root.visible = true
	if instant:
		_tabs_root.position = Vector2(target, _tabs_root.position.y)
		var col := _tabs_root.modulate
		col.a = (1.0 if v else 0.0)
		_tabs_root.modulate = col
		if !v: _tabs_root.visible = false
	else:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_tabs_root, "position:x", target, SHOW_TIME)
		tw.parallel().tween_property(_tabs_root, "modulate:a", (1.0 if v else 0.0), SHOW_TIME)
		if !v:
			tw.tween_callback(func(): _tabs_root.visible = false)

# ------- Panels (open/close) -------

func _hide_all_panels(instant := false) -> void:
	if !is_instance_valid(_panels_root):
		return
	for c in _panels_root.get_children():
		if c is CanvasItem:
			if instant:
				(c as CanvasItem).visible = false
				(c as CanvasItem).modulate.a = 0.0
			else:
				var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(c, "modulate:a", 0.0, SHOW_TIME)
				tw.tween_callback(func(): (c as CanvasItem).visible = false)
	_open_panel = null
	_panels_root.visible = false

func _show_panel(p: Control) -> void:
        if !is_instance_valid(p) or !is_instance_valid(_panels_root):
                return
        _panels_root.visible = true
        # hide others
        for c in _panels_root.get_children():
                if c is CanvasItem and c != p:
                        (c as CanvasItem).visible = false
                        (c as CanvasItem).modulate.a = 0.0
        # fade in selected
        p.visible = true
        var col := p.modulate
        col.a = 0.0
        p.modulate = col
        var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.tween_property(p, "modulate:a", 1.0, SHOW_TIME)
        _open_panel = p

func _toggle_panel(p: Control) -> void:
	if _open_panel == p and is_instance_valid(p) and p.visible:
		_hide_all_panels()
	else:
		_show_panel(p)

# ------- Quick tab callbacks -------

func _on_tab_character() -> void:
        if is_instance_valid(_panel_character):
                _toggle_panel(_panel_character)
        else:
                _hide_all_panels()

func _on_tab_skills() -> void:
        if is_instance_valid(_panel_skills):
                _toggle_panel(_panel_skills)
        else:
                _hide_all_panels()

func _on_tab_fishing() -> void:
        if is_instance_valid(_panel_fishing):
                _toggle_panel(_panel_fishing)
        else:
                _hide_all_panels()

func _on_tab_mining() -> void:
        if is_instance_valid(_panel_mining):
                _toggle_panel(_panel_mining)
        else:
                _hide_all_panels()

func _on_tab_settings() -> void:
        if is_instance_valid(_panel_settings):
                _toggle_panel(_panel_settings)
        else:
                _hide_all_panels()

# ------- Existing behavior -------

func _on_arena() -> void:   State.set_mode("arena")
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
		arena_b.button_pressed = (m == "arena");   arena_b.disabled = (m == "arena")
	if is_instance_valid(fish_b):
		fish_b.button_pressed  = (m == "fishing");  fish_b.disabled  = (m == "fishing")
	if is_instance_valid(mine_b):
		mine_b.button_pressed  = (m == "mining");   mine_b.disabled  = (m == "mining")
