extends Control

const CONFIG_PATH := "user://settings.cfg"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const AMBIENCE_BUS := "Ambience"

const RESOLUTIONS := [
	{"label": "1280 x 720", "size": Vector2i(1280, 720)},
	{"label": "1920 x 1080", "size": Vector2i(1920, 1080)},
	{"label": "2560 x 1440", "size": Vector2i(2560, 1440)}
]

@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _ambience_slider: HSlider = %AmbienceSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _ambience_value: Label = %AmbienceValue
@onready var _mute_toggle: CheckBox = %MuteToggle
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _save_button: Button = %SaveButton
@onready var _reset_button: Button = %ResetButton
@onready var _quit_button: Button = %QuitButton
@onready var _reset_dialog: ConfirmationDialog = %ResetConfirmDialog

var _settings := {
	"music": 1.0,
	"sfx": 1.0,
	"ambience": 1.0,
	"mute": false,
	"resolution": Vector2i(1280, 720)
}

var _loading := true

func _ready() -> void:
	_load_settings()
	_populate_resolution_options()
	_apply_settings_to_ui()
	_connect_signals()
	_loading = false

func _populate_resolution_options() -> void:
	if !is_instance_valid(_resolution_option):
		return
	_resolution_option.clear()
	var selected := 0
	for i in range(RESOLUTIONS.size()):
		var entry = RESOLUTIONS[i]
		_resolution_option.add_item(String(entry["label"]))
		if entry["size"] == _settings["resolution"]:
			selected = i
	_resolution_option.select(selected)

func _connect_signals() -> void:
	if is_instance_valid(_music_slider):
		_music_slider.value_changed.connect(_on_music_volume_changed)
	if is_instance_valid(_sfx_slider):
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if is_instance_valid(_ambience_slider):
		_ambience_slider.value_changed.connect(_on_ambience_volume_changed)
	if is_instance_valid(_mute_toggle):
		_mute_toggle.toggled.connect(_on_mute_toggled)
	if is_instance_valid(_resolution_option):
		_resolution_option.item_selected.connect(_on_resolution_selected)
	if is_instance_valid(_save_button):
		_save_button.pressed.connect(_on_save_pressed)
		if is_instance_valid(_reset_button):
				_reset_button.pressed.connect(_on_reset_pressed)
		if is_instance_valid(_quit_button):
				_quit_button.pressed.connect(_on_quit_pressed)
		if is_instance_valid(_reset_dialog):
				_reset_dialog.confirmed.connect(_on_reset_confirmed)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		return
	_settings["music"] = float(cfg.get_value("audio", "music", _settings["music"]))
	_settings["sfx"] = float(cfg.get_value("audio", "sfx", _settings["sfx"]))
	_settings["ambience"] = float(cfg.get_value("audio", "ambience", _settings["ambience"]))
	_settings["mute"] = bool(cfg.get_value("audio", "mute", _settings["mute"]))
	var stored_res = cfg.get_value("graphics", "resolution", _settings["resolution"])
	if typeof(stored_res) == TYPE_VECTOR2I:
		_settings["resolution"] = stored_res
	elif typeof(stored_res) == TYPE_VECTOR2:
		_settings["resolution"] = Vector2i(stored_res)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", _settings["music"])
	cfg.set_value("audio", "sfx", _settings["sfx"])
	cfg.set_value("audio", "ambience", _settings["ambience"])
	cfg.set_value("audio", "mute", _settings["mute"])
	cfg.set_value("graphics", "resolution", _settings["resolution"])
	cfg.save(CONFIG_PATH)

func _apply_settings_to_ui() -> void:
	if is_instance_valid(_music_slider):
		_music_slider.value = _settings["music"]
	if is_instance_valid(_sfx_slider):
		_sfx_slider.value = _settings["sfx"]
	if is_instance_valid(_ambience_slider):
		_ambience_slider.value = _settings["ambience"]
	if is_instance_valid(_mute_toggle):
		_mute_toggle.button_pressed = _settings["mute"]
	_update_volume_labels()
	_apply_audio_settings()
	_apply_resolution(_settings["resolution"])
	_sync_resolution_option()

func _update_volume_labels() -> void:
	if is_instance_valid(_music_value):
		_music_value.text = _format_volume_text(_settings["music"])
	if is_instance_valid(_sfx_value):
		_sfx_value.text = _format_volume_text(_settings["sfx"])
	if is_instance_valid(_ambience_value):
		_ambience_value.text = _format_volume_text(_settings["ambience"])

func _format_volume_text(amount: float) -> String:
	return "%d%%" % int(round(amount * 100.0))

func _apply_audio_settings() -> void:
	_set_bus_volume(MUSIC_BUS, _settings["music"])
	_set_bus_volume(SFX_BUS, _settings["sfx"])
	_set_bus_volume(AMBIENCE_BUS, _settings["ambience"])
	_set_master_mute(_settings["mute"])

func _sync_resolution_option() -> void:
	if !is_instance_valid(_resolution_option):
		return
	var target := 0
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i]["size"] == _settings["resolution"]:
			target = i
	_resolution_option.select(target)

func _set_bus_volume(bus_name: String, amount: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var value := clampf(amount, 0.0, 1.0)
	var db := -80.0 if value <= 0.001 else linear_to_db(value)
	AudioServer.set_bus_volume_db(idx, db)

func _set_master_mute(v: bool) -> void:
	var idx := AudioServer.get_bus_index(MASTER_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v)

func _apply_resolution(target_size: Vector2i) -> void:
	if target_size.x <= 0 or size.y <= 0:
		return
	if Engine.has_singleton("Display"):
		Display.set_window_size(size)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)

func _on_music_volume_changed(value: float) -> void:
	_settings["music"] = value
	if is_instance_valid(_music_value):
		_music_value.text = _format_volume_text(value)
	_apply_audio_settings()
	if !_loading:
		_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	_settings["sfx"] = value
	if is_instance_valid(_sfx_value):
		_sfx_value.text = _format_volume_text(value)
	_apply_audio_settings()
	if !_loading:
		_save_settings()

func _on_ambience_volume_changed(value: float) -> void:
	_settings["ambience"] = value
	if is_instance_valid(_ambience_value):
		_ambience_value.text = _format_volume_text(value)
	_apply_audio_settings()
	if !_loading:
		_save_settings()

func _on_mute_toggled(pressed: bool) -> void:
	_settings["mute"] = pressed
	_set_master_mute(pressed)
	if !_loading:
		_save_settings()

func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	var entry = RESOLUTIONS[index]
	_settings["resolution"] = entry["size"]
	_apply_resolution(entry["size"])
	_sync_resolution_option()
	if !_loading:
		_save_settings()

func _on_save_pressed() -> void:
	if Engine.has_singleton("State"):
		State.save()
	_save_settings()

func _on_reset_pressed() -> void:
		if is_instance_valid(_reset_dialog):
				_reset_dialog.popup_centered()
		else:
				_on_reset_confirmed()

func _on_reset_confirmed() -> void:
		if Engine.has_singleton("State"):
				State.reset_save()
		_apply_settings_to_ui()

func _on_quit_pressed() -> void:
	get_tree().quit()
