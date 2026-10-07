class_name SystemScreens
extends Control

## Title, loading and settings (界面策划案 v1.1 #11–#13). Only the real game
## shows the title (main scene); tests instantiate the scene and go straight in.
## Settings live in user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const TIPS := [
	"赤金占背包格子，营地里可以卖给可露希尔。",
	"安全袋里的物品阵亡后也会保留。",
	"投保的物品阵亡后会在 1–3 份合同后送回。",
	"每十层之后是营地，营地里有固定撤离点。",
	"罗德岛小队可以为一件装备投保，或直接送回基地。",
	"坎诺特的货架可以刷新，也收购物品。",
]

var game: GameManager
var _title: Control
var _loading: Control
var _tip: Label
var _settings: Control
var _loading_left := 0.0
var _was_transitioning := false
static var settings := {"master_volume": 0.8, "mute": false, "fullscreen": false, "vsync": true, "damage_numbers": true, "tracker": true, "broadcasts": true}
static var _game: GameManager

func _ready() -> void:
	_game = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SystemScreens.load_settings()
	SystemScreens.apply_settings()
	_title = _build_title()
	_loading = _build_loading()
	_settings = _build_settings()
	_title.hide()
	_loading.hide()
	_settings.hide()

func show_title() -> void:
	_title.show()
	if is_instance_valid(game): game.open_modal("title")

func _start() -> void:
	_title.hide()
	_flash_loading()
	if is_instance_valid(game) and game.modal == "title": game.close_modal()

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	if game.transitioning and not _was_transitioning and not _title.visible: _flash_loading()
	_was_transitioning = game.transitioning
	if _loading.visible:
		_loading_left -= delta
		if _loading_left <= 0.0 and not game.transitioning: _loading.hide()

func _flash_loading() -> void:
	_tip.text = TIPS[randi() % TIPS.size()]
	_loading_left = 0.8
	_loading.show()

func _backdrop() -> Control:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = AK.BG
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(back)
	add_child(screen)
	return screen

func _build_title() -> Control:
	var screen := _backdrop()
	var stripe := ColorRect.new()
	stripe.color = AK.PAPER
	stripe.position = Vector2(96, 236)
	stripe.size = Vector2(8, 120)
	screen.add_child(stripe)
	var name_en := AK.label("DOWNFALL", 76, AK.FG, AK.en())
	name_en.position = Vector2(124, 220)
	screen.add_child(name_en)
	var name_cn := AK.label("罗德岛 · 外勤", 22, AK.MUTE)
	name_cn.position = Vector2(128, 318)
	screen.add_child(name_cn)
	var buttons := VBoxContainer.new()
	buttons.position = Vector2(128, 430)
	buttons.add_theme_constant_override("separation", 8)
	screen.add_child(buttons)
	var start := AK.button("开始唤醒", "blue", 18)
	start.custom_minimum_size = Vector2(240, 48)
	start.pressed.connect(_start)
	buttons.add_child(start)
	var open_settings := AK.button("设置", "plain", 15)
	open_settings.custom_minimum_size = Vector2(240, 40)
	open_settings.pressed.connect(show_settings)
	buttons.add_child(open_settings)
	var quit := AK.button("退出", "plain", 15)
	quit.custom_minimum_size = Vector2(240, 40)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	var version := AK.label("PRTS · v1.1", 11, AK.DIM, AK.en())
	version.position = Vector2(1180, 690)
	screen.add_child(version)
	return screen

func _build_loading() -> Control:
	var screen := _backdrop()
	var bar := ColorRect.new()
	bar.color = AK.BLUE
	bar.position = Vector2(0, 330)
	bar.size = Vector2(1280, 4)
	screen.add_child(bar)
	var title := AK.label("行动开始", 34, AK.FG)
	title.position = Vector2(96, 260)
	screen.add_child(title)
	var en := AK.label("OPERATION START", 12, AK.MUTE, AK.en())
	en.position = Vector2(98, 244)
	screen.add_child(en)
	var tag := AK.tag("TIPS", AK.PAPER)
	tag.position = Vector2(96, 620)
	screen.add_child(tag)
	_tip = AK.label("", 15, AK.FG)
	_tip.position = Vector2(150, 618)
	screen.add_child(_tip)
	return screen

func _build_settings() -> Control:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(400, 200)
	panel.size = Vector2(480, 300)
	panel.add_theme_stylebox_override("panel", AK.box(Color("101010"), AK.LINE_2, 1, 20))
	screen.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(AK.label("SETTINGS", 10, AK.MUTE, AK.en()))
	column.add_child(AK.label("设置", 22, AK.FG))
	var volume_row := HBoxContainer.new()
	volume_row.add_child(AK.label("音量", 14, AK.FG))
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = settings.master_volume
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value_changed.connect(func(v): SystemScreens.set_setting("master_volume", v))
	volume_row.add_child(volume)
	column.add_child(volume_row)
	var mute := CheckButton.new()
	mute.text = "静音"
	mute.add_theme_font_override("font", AK.cn())
	mute.button_pressed = settings.mute
	mute.toggled.connect(func(on): SystemScreens.set_setting("mute", on))
	column.add_child(mute)
	var full := CheckButton.new()
	full.text = "全屏"
	full.add_theme_font_override("font", AK.cn())
	full.button_pressed = settings.fullscreen
	full.toggled.connect(func(on): SystemScreens.set_setting("fullscreen", on))
	column.add_child(full)
	var done := AK.button("确定", "blue", 15)
	done.pressed.connect(func(): SystemScreens.save_settings(); screen.hide())
	column.add_child(done)
	return screen

func show_settings() -> void:
	_settings.show()

## Esc on the system layer: the settings overlay closes; the title stays. True
## when the press was used here.
func go_back() -> bool:
	if _settings.visible:
		SystemScreens.save_settings()
		_settings.hide()
		return true
	return _title.visible

static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK: return
	for key in settings: settings[key] = config.get_value("game", key, settings[key])

static func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings: config.set_value("game", key, settings[key])
	config.save(SETTINGS_PATH)

## Changes one setting, applies it now and saves (pause → 设置).
static func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	if _game != null: save_settings()

## Only the real game touches the window, audio and save file; tests never
## create SystemScreens, so _game stays null there.
## Master volume and mute. Separate so the audio test can apply it without a window.
static func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0: return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(settings.master_volume), 0.0001)))
	AudioServer.set_bus_mute(bus, bool(settings.mute))

static func apply_settings() -> void:
	if is_instance_valid(_game) and is_instance_valid(_game.number_layer): _game.number_layer.visible = bool(settings.damage_numbers)
	if _game == null: return
	apply_audio()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
