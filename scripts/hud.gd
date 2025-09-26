extends CanvasLayer

# ------- Stats / top bar (optional) -------
@onready var gold_l:   Label  = $Root/StatsBox/GoldLabel
@onready var lvl_l:    Label  = $Root/StatsBox/LvlLabel
@onready var inv_l:    Label  = $Root/StatsBox/InvLabel
@onready var arena_b:  Button = $Root/TopBar/ArenaBtn
@onready var fish_b:   Button = $Root/TopBar/FishingBtn
@onready var mine_b:   Button = $Root/TopBar/MiningBtn
@onready var ascend_b: Button = $Root/TopBar/AscendBtn

# ------- Drawer bits (Main.tscn → Hud/HUDRoot) -------
@onready var _arrow_btn: TextureButton = $HUDRoot/ArrowMenuButton
@onready var _tabs_root: Control       = $HUDRoot/QuickTabs

# Buttons (left → right)
@onready var _btn_character:    TextureButton = $HUDRoot/QuickTabs/BtnCharacter
@onready var _btn_buildings:    TextureButton = $HUDRoot/QuickTabs/BtnBuildings
@onready var _btn_upgrades:     TextureButton = $HUDRoot/QuickTabs/BtnUpgrades
@onready var _btn_skills:       TextureButton = $HUDRoot/QuickTabs/BtnSkills
@onready var _btn_fishing:      TextureButton = $HUDRoot/QuickTabs/BtnFishing
@onready var _btn_mining:       TextureButton = $HUDRoot/QuickTabs/BtnMining
@onready var _btn_prestige:     TextureButton = $HUDRoot/QuickTabs/BtnPrestige
@onready var _btn_achievements: TextureButton = $HUDRoot/QuickTabs/BtnAchievements
@onready var _btn_settings:     TextureButton = $HUDRoot/QuickTabs/BtnSettings

# ------- Panels (HUD.tscn → Root) -------
@onready var _panels_root:        Control = $Root/Panels
@onready var _panel_character:    Control = $Root/Panels/CharacterPanel
@onready var _panel_buildings:    Control = $Root/Panels/BuildingsPanel
@onready var _panel_upgrades:     Control = $Root/Panels/UpgradesPanel
@onready var _panel_skills:       Control = $Root/Panels/SkillsPanel
@onready var _panel_fishing:      Control = $Root/Panels/FishingPanel
@onready var _panel_mining:       Control = $Root/Panels/MiningPanel
@onready var _panel_prestige:     Control = $Root/Panels/PrestigePanel
@onready var _panel_achievements: Control = $Root/Panels/AchievementsPanel
@onready var _panel_settings:     Control = $Root/Panels/SettingsPanel

# ------- Config -------
const SHOW_TIME   := 0.18
const HIDDEN_POS  := Vector2(-160, 0)
const TABS_MARGIN := 16
const DEV_SHOW_ALL_TABS := true

const HOVER_SCALE := Vector2(1.06, 1.06)
const NORMAL_SCALE := Vector2.ONE
const HOVER_TINT := Color(1.08, 1.08, 1.08, 1.0)
const NORMAL_TINT := Color(1, 1, 1, 1)

var _tabs_open := false
var _open_panel: Control = null

func _ready() -> void:
	# Root fills viewport; HUDRoot passes clicks
	var root := $Root as Control
	if root:
		root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		root.mouse_filter = Control.MOUSE_FILTER_PASS
	var hudroot := $HUDRoot as Control
	if hudroot:
		hudroot.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		hudroot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Stats never block input
	var stats := $Root/StatsBox
	if stats and stats is Control:
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for n in stats.get_children():
			if n is Control: n.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Arrow button bottom-right
	if is_instance_valid(_arrow_btn):
		_arrow_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
		_arrow_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_arrow_btn.z_index = 100
		_place_bottom_right(_arrow_btn, TABS_MARGIN)
		_arrow_btn.pressed.connect(_toggle_tabs)

	# QuickTabs bottom-left
	if is_instance_valid(_tabs_root):
		_tabs_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
		_tabs_root.offset_left   = TABS_MARGIN
		_tabs_root.offset_bottom = -TABS_MARGIN
		_tabs_root.mouse_filter = Control.MOUSE_FILTER_PASS
		if _tabs_root is HBoxContainer:
			var hb := _tabs_root as HBoxContainer
			hb.alignment = BoxContainer.ALIGNMENT_BEGIN
			hb.clip_contents = false
		_tabs_root.add_theme_constant_override("margin_left", -8)  # slight nudge left
		_enforce_tab_order()
		_set_tabs_visible(false, true)

	_connect_tabs()
	_wire_all_tab_hovers()

	# Panels root config
	if is_instance_valid(_panels_root):
		_panels_root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_panels_root.visible = false
		_panels_root.mouse_filter = Control.MOUSE_FILTER_PASS
		_panels_root.z_index = 200
		_hide_all_panels(true)

	# Optional top bar signals
	if is_instance_valid(arena_b):  arena_b.pressed.connect(_on_arena)
	if is_instance_valid(fish_b):   fish_b.pressed.connect(_on_fishing)
	if is_instance_valid(mine_b):   mine_b.pressed.connect(_on_mining)
	if is_instance_valid(ascend_b): ascend_b.pressed.connect(_on_ascend)

	# State signals for stats text
	if Engine.has_singleton("State"):
		State.level_up.connect(_refresh)
		State.mode_changed.connect(_refresh)
		State.unlocks_changed.connect(_refresh)

	_refresh()

# ---------- helpers ----------
func _connect_tabs() -> void:
	if _btn_character:    _btn_character.pressed.connect(_on_tab_character)
	if _btn_buildings:    _btn_buildings.pressed.connect(_on_tab_buildings)
	if _btn_upgrades:     _btn_upgrades.pressed.connect(_on_tab_upgrades)
	if _btn_skills:       _btn_skills.pressed.connect(_on_tab_skills)
	if _btn_fishing:      _btn_fishing.pressed.connect(_on_tab_fishing)
	if _btn_mining:       _btn_mining.pressed.connect(_on_tab_mining)
	if _btn_prestige:     _btn_prestige.pressed.connect(_on_tab_prestige)
	if _btn_achievements: _btn_achievements.pressed.connect(_on_tab_achievements)
	if _btn_settings:     _btn_settings.pressed.connect(_on_tab_settings)

func _enforce_tab_order() -> void:
	var order := [
		_btn_character, _btn_buildings, _btn_upgrades, _btn_skills,
		_btn_fishing, _btn_mining, _btn_prestige, _btn_achievements, _btn_settings
	]
	for i in range(order.size()):
		if is_instance_valid(order[i]):
			_tabs_root.move_child(order[i], i)

# Hover FX
func _wire_hover_button(b: TextureButton) -> void:
	if !is_instance_valid(b): return
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if b.custom_minimum_size == Vector2.ZERO and b.texture_normal:
		b.custom_minimum_size = b.texture_normal.get_size()
	b.scale = NORMAL_SCALE
	b.modulate = NORMAL_TINT
	if not b.mouse_entered.is_connected(_on_btn_hover_in.bind(b)):
		b.mouse_entered.connect(_on_btn_hover_in.bind(b))
	if not b.mouse_exited.is_connected(_on_btn_hover_out.bind(b)):
		b.mouse_exited.connect(_on_btn_hover_out.bind(b))
	if not b.focus_entered.is_connected(_on_btn_hover_in.bind(b)):
		b.focus_entered.connect(_on_btn_hover_in.bind(b))
	if not b.focus_exited.is_connected(_on_btn_hover_out.bind(b)):
		b.focus_exited.connect(_on_btn_hover_out.bind(b))

func _wire_all_tab_hovers() -> void:
	if !is_instance_valid(_tabs_root): return
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

# Bottom-right placement for the arrow
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
	if e is InputEventKey and e.pressed and !e.echo and e.keycode == KEY_U:
		_toggle_tabs()

# ------- Drawer logic -------
func _toggle_tabs() -> void:
	_tabs_open = !_tabs_open
	_set_tabs_visible(_tabs_open, false)

func _set_tabs_visible(v: bool, instant: bool) -> void:
	if !is_instance_valid(_tabs_root): return
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

# ------- Panels -------
func _hide_all_panels(instant := false) -> void:
	if !is_instance_valid(_panels_root): return
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
	if !is_instance_valid(p) or !is_instance_valid(_panels_root): return
	_panels_root.visible = true
	for c in _panels_root.get_children():
		if c is CanvasItem and c != p:
			(c as CanvasItem).visible = false
			(c as CanvasItem).modulate.a = 0.0
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
func _toggle_or_hide(panel: Control) -> void:
	if is_instance_valid(panel): _toggle_panel(panel)
	else: _hide_all_panels()

func _on_tab_character()    -> void: _toggle_or_hide(_panel_character)
func _on_tab_buildings()    -> void: _toggle_or_hide(_panel_buildings)
func _on_tab_upgrades()     -> void: _toggle_or_hide(_panel_upgrades)
func _on_tab_skills()       -> void: _toggle_or_hide(_panel_skills)
func _on_tab_fishing()      -> void: _toggle_or_hide(_panel_fishing)
func _on_tab_mining()       -> void: _toggle_or_hide(_panel_mining)
func _on_tab_prestige()     -> void: _toggle_or_hide(_panel_prestige)
func _on_tab_achievements() -> void: _toggle_or_hide(_panel_achievements)
func _on_tab_settings()     -> void: _toggle_or_hide(_panel_settings)

# ------- Optional top bar behavior -------
func _on_arena() -> void:   State.set_mode("arena")
func _on_fishing() -> void: State.set_mode("fishing")
func _on_mining() -> void:  State.set_mode("mining")
func _on_ascend() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	State.ascend()
	State.set_mode("arena")

# ------- Refresh -------
func _refresh() -> void:
	if is_instance_valid(gold_l): gold_l.text = "Gold: " + String.num(State.gold, 0)
	if is_instance_valid(lvl_l):  lvl_l.text  = "Lv: %d  (XP %.0f)" % [State.level, State.xp]
	if is_instance_valid(inv_l):  inv_l.text  = "Fish: %d   Ore: %d" % [State.fish, State.ore]

	# Always show tabs during dev
	if DEV_SHOW_ALL_TABS:
		for b in [_btn_character, _btn_buildings, _btn_upgrades, _btn_skills,
				  _btn_fishing, _btn_mining, _btn_prestige, _btn_achievements, _btn_settings]:
			if is_instance_valid(b): b.visible = true
