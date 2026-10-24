class_name SystemScreens
extends Control

## Title, loading and settings (界面策划案 v1.1 #11–#13). Only the real game
## shows the title (main scene); tests instantiate the scene and go straight in.
## Settings live in user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const TIPS := [
	"赤金占背包格子，营地里可以卖给可露希尔。",
	"安全袋由博士随身携带，撤退时也会带回。",
	"投保的装备没带出局就会在 2–4 小时后送回；带出来保险不失效。",
	"每十层之后是营地，营地里有固定撤离点。",
	"罗德岛小队可以为一件装备投保，或直接送回基地。",
	"坎诺特的货架可以刷新，也收购物品。",
]

var game: GameManager
var _title: Control
## The title's save slots (SaveSlots): the one loaded now (-1 before any), the
## one asked to be deleted, and how pixel_display starts the game on one.
var _slots: Control
var _menu: Control
var _deleting := -1
var slot := -1
var launch: Callable
## A slot picked while another was in play: the reloaded scene goes straight in.
static var pending_slot := -1
static var _window_applied := false
var _loading: Control
var _tip: Label
## The region's load card (art/ui/key/load_*.png) over the loading screen, and
## the place under the title (改造案 v1.1 §1.1: the card shows 上城 or 下城).
var _card: TextureRect
var _place: Label
var _card_key := ""
const CARDS := {"mine": "load_mine", "snow": "load_snow", "siracusa": "load_siracusa", "city_lower": "load_city", "city_upper": "load_city_upper"}
var _settings: Control
var _loading_left := 0.0
var _was_transitioning := false
## The loading bar: where it is drawn and where it is heading. The map's stages
## move the target while a floor is built. It paints straight to its canvas
## item: mid-build no frame ends, so a queued redraw would never run.
var _progress := 0.0
var _target := 0.0
var _bar: Control
const BAR := Rect2(96, 676, 1088, 4)
const BAR_BUILT := 0.85
const BAR_SPEED := 1.6
static var settings := {"master_volume": 0.8, "mute": false, "fullscreen": false, "vsync": true, "damage_numbers": true, "tracker": true, "broadcasts": true, "hotbar": [], "keybinds": {}, "language": "zh",
	"auto_potion": "potion_A", "auto_potion_low": 0.4, "auto_potion_high": 0.9, "base_look": "",
	# 界面动效 (界面动态美术方案 v3 §2): the scan reveal, wipes and typing titles.
	"ui_motion": true,
	# Ask before a dragged buy or sale goes through (TraderScreen.ask).
	"trade_confirm": true,
	# 站点总览 (用户 2026-10-18: 不常驻，快捷键开启，设置里自定义显示哪些):
	# open or not, and the station kinds left out of it.
	"station_panel": false, "station_hidden": [],
	# 新手引导: the step reached (TutorialCard.STEPS.size() = done or off).
	"tutorial_step": 0,
	# The first-sight cards (TutorialSpotlight): on or not, and the ids already shown.
	"tutorial_tips": true, "tutorial_seen": [],
	# 主线引导 (Story): on or off; off, every region is open from the start.
	"story_guide": true,
	# The save slot last played (SaveSlots); the terminal and ticker open it.
	"save_slot": 0}
static var _game: GameManager

func _ready() -> void:
	_game = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SystemScreens.load_settings()
	SystemScreens.apply_settings()
	# Once per launch: a reload onto another save keeps the window as it is.
	if not _window_applied: SystemScreens.apply_window()
	_window_applied = true
	_title = _build_title()
	_loading = _build_loading()
	_settings = _build_settings()
	_title.hide()
	_loading.hide()
	_settings.hide()

func show_title() -> void:
	_deleting = -1
	_show_slots(false)
	_title.show()
	if is_instance_valid(game) and game.is_inside_tree(): game.open_modal("title")

## 开始游戏 swaps the title's buttons for the slots; 返回 (or Esc) swaps back.
func _show_slots(on: bool) -> void:
	_deleting = -1
	_menu.visible = not on
	_slots.visible = on
	if on: _fill_slots()

## The three slots, a narrow column left of the landship: a used one enters
## (or 删除, twice to be sure), an empty one starts a new save there.
func _fill_slots() -> void:
	for child in _slots.get_children(): child.queue_free()
	var last := int(settings.get("save_slot", 0))
	for i in range(SaveSlots.COUNT):
		var used := SaveSlots.used(i)
		var row := Control.new()
		row.position = Vector2(0, i * 70)
		_slots.add_child(row)
		var pick := AK.button("", "blue" if used and i == last else "plain", 14)
		pick.pressed.connect(_pick.bind(i))
		AK.put(row, pick, Vector2.ZERO, Vector2(200, 64))
		var name := AK.label("存档 %d" % (i + 1), 15, AK.FG)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AK.put(row, name, Vector2(14, 5))
		var colour := AK.FG if used and i == last else AK.MUTE
		var lines := _slot_lines(i) if used else ["空", ""]
		for n in range(2):
			var info := AK.label(lines[n], 11, colour)
			info.mouse_filter = Control.MOUSE_FILTER_IGNORE
			AK.put(row, info, Vector2(14, 28 + n * 16))
		if i == slot:
			var tag := AK.tag("当前", AK.PAPER)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			AK.put(row, tag, Vector2(152, 7))
		var busy := used and SaveSlots.busy(i)
		var side := AK.button("使用中" if busy else (("确认" if _deleting == i else "删除") if used else "新存档"), "plain" if used else "green", 12)
		side.disabled = busy
		side.pressed.connect((_delete if used else _pick).bind(i))
		if used and _deleting == i: side.add_theme_color_override("font_color", AK.RED)
		AK.put(row, side, Vector2(206, 0), Vector2(64, 64))
	var back := AK.button("返回", "plain", 14)
	back.pressed.connect(_show_slots.bind(false))
	AK.put(_slots, back, Vector2(0, 3 * 70), Vector2(270, 36))

func _slot_lines(i: int) -> Array:
	var s := SaveSlots.summary(i)
	if s.is_empty(): return ["—", ""]
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(int(s.saved) + bias)
	return ["龙门币 %d · 干员 %d" % [s.lmd, s.operators], "%02d-%02d %02d:%02d" % [t.month, t.day, t.hour, t.minute]]

func _pick(i: int) -> void:
	_deleting = -1
	SystemScreens.set_setting("save_slot", i)
	if not game.is_inside_tree():
		slot = i
		_title.hide()
		await show_loading_now()
		launch.call(i)
	elif i == slot:
		_start()
	else:
		# Another save: the whole scene starts again on it (as quitting would).
		if game.in_base and not game.transitioning: game.save_base()
		pending_slot = i
		get_tree().reload_current_scene()

func _delete(i: int) -> void:
	if _deleting != i:
		_deleting = i
		_fill_slots()
		return
	_deleting = -1
	if i == slot and game.is_inside_tree():
		# The save in play: it stops writing first, then the scene starts over.
		game.save_enabled = false
		if game.save_lock != null: game.save_lock.leave()
		if SaveSlots.delete(i):
			pending_slot = -1
			get_tree().reload_current_scene()
		return
	SaveSlots.delete(i)
	_fill_slots()

## The loading screen up and drawn before a save is loaded: the game's own
## _ready holds the frame while it builds.
func show_loading_now() -> void:
	begin_loading()
	_target = 0.3
	_progress = 0.3
	_draw_bar()
	# Two frames: the first one ends drawn (frame_post_draw never comes headless).
	await get_tree().process_frame
	await get_tree().process_frame

func _start() -> void:
	_title.hide()
	_flash_loading()
	if is_instance_valid(game) and game.modal == "title": game.close_modal()

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	if game.transitioning and not _was_transitioning and not _title.visible and not _loading.visible: _flash_loading()
	_was_transitioning = game.transitioning
	if _loading.visible:
		_show_card()
		_loading_left -= delta
		# Waiting on the navigation creeps on to just short of full; done fills it.
		if game.transitioning or game.booting: _target = maxf(_target, minf(_target + delta * 0.05, 0.95))
		else: _target = 1.0
		_progress = move_toward(_progress, _target, delta * BAR_SPEED)
		_draw_bar()
		if _loading_left <= 0.0 and not game.transitioning and not game.booting and _progress >= 1.0: _loading.hide()

func _flash_loading() -> void:
	_tip.text = TIPS[randi() % TIPS.size()]
	_loading_left = 0.8
	_progress = 0.0
	_target = 0.3
	_draw_bar()
	_show_card()
	_loading.show()

## A floor is about to be built: the screen goes up at once, before the work.
func begin_loading() -> void:
	_flash_loading()
	_target = 0.1

## One stage of the map done (ContinuousWorldMap.mark). The frame is busy
## building, so the bar is drawn here and now.
func step_loading(_stage: String) -> void:
	_target = minf(BAR_BUILT, _target + (BAR_BUILT - _target) * 0.15)
	_progress = maxf(_progress, _target)
	_draw_bar()
	RenderingServer.force_draw()

func _draw_bar() -> void:
	var ci := _bar.get_canvas_item()
	var done := clampf(_progress, 0.0, 1.0)
	RenderingServer.canvas_item_clear(ci)
	RenderingServer.canvas_item_add_rect(ci, BAR, AK.LINE_2)
	RenderingServer.canvas_item_add_rect(ci, Rect2(BAR.position, Vector2(BAR.size.x * done, BAR.size.y)), AK.BLUE)
	AK.en().draw_string(ci, Vector2(BAR.position.x, BAR.position.y - 8), "%d%%" % roundi(done * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, BAR.size.x, 12, AK.MUTE)

## The card of the floor being entered: the region's, Lungmen's by its upper
## or lower city; none for the base or a camp.
func _show_card() -> void:
	var key := ""
	var place := ""
	if is_instance_valid(game) and not game.in_base and not game.in_camp and is_instance_valid(game.world_map):
		key = game.region_id
		if key == "city": key += "_" + (game.world_map.city_variant if not game.world_map.city_variant.is_empty() else "upper")
		place = game.place_name()
	if key == _card_key and _place.text == place: return
	_card_key = key
	_place.text = place
	var path := "res://art/ui/key/%s.png" % CARDS.get(key, "")
	_card.texture = load(path) if CARDS.has(key) and ResourceLoader.exists(path) else null

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
	# Sol's key art (UD title): the landship on the wasteland, darkened from the
	# left so the name and buttons read over it.
	var art := TextureRect.new()
	art.texture = load("res://art/ui/key/title.png")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(art)
	var shade := TextureRect.new()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.32, 0.62])
	ramp.colors = PackedColorArray([Color(AK.BG, 0.88), Color(AK.BG, 0.6), Color(AK.BG, 0.0)])
	var fade := GradientTexture2D.new()
	fade.gradient = ramp
	fade.width = 256
	fade.height = 4
	shade.texture = fade
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
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
	_slots = Control.new()
	_slots.position = Vector2(128, 380)
	screen.add_child(_slots)
	var buttons := VBoxContainer.new()
	buttons.position = Vector2(128, 430)
	buttons.add_theme_constant_override("separation", 8)
	screen.add_child(buttons)
	_menu = buttons
	var start := AK.button("开始游戏", "blue", 18)
	start.custom_minimum_size = Vector2(240, 48)
	start.pressed.connect(_show_slots.bind(true))
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
	_card = TextureRect.new()
	_card.position = Vector2(0, 0)
	_card.size = Vector2(1280, 360)
	_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.add_child(_card)
	var bar := ColorRect.new()
	bar.color = AK.BLUE
	bar.position = Vector2(0, 360)
	bar.size = Vector2(1280, 4)
	screen.add_child(bar)
	var title := AK.label("行动开始", 34, AK.FG)
	title.position = Vector2(96, 410)
	screen.add_child(title)
	var en := AK.label("OPERATION START", 12, AK.MUTE, AK.en())
	en.position = Vector2(98, 394)
	screen.add_child(en)
	_place = AK.label("", 18, AK.MUTE)
	_place.position = Vector2(98, 462)
	screen.add_child(_place)
	var tag := AK.tag("TIPS", AK.PAPER)
	tag.position = Vector2(96, 620)
	screen.add_child(tag)
	_tip = AK.label("", 15, AK.FG)
	_tip.position = Vector2(150, 618)
	screen.add_child(_tip)
	_bar = Control.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	screen.add_child(_bar)
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
	panel.add_theme_stylebox_override("panel", AK.box(Color("0d1012"), AK.LINE_2, 1, 20))
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
	column.add_child(look_toggle(_rebuild_settings))
	column.add_child(language_toggle(_rebuild_settings))
	var done := AK.button("确定", "blue", 15)
	done.pressed.connect(func(): SystemScreens.save_settings(); screen.hide())
	column.add_child(done)
	return screen

## 基地形象: who walks the base. "" follows whoever deploys; 博士 joins the
## list once its sheets are in LapplandAnimator3D.CHARACTERS.
static func look_toggle(after: Callable) -> Control:
	var ids: Array = [""]
	var names: Array = ["出战干员"]
	if LapplandAnimator3D.has_sheets("doctor"):
		ids.append("doctor")
		names.append("博士")
	for id in Operators.ORDER:
		# Her sheets, and she has joined (干员寻访策划案 §2.3).
		if not LapplandAnimator3D.CHARACTERS.has(id) or (is_instance_valid(_game) and not _game.base.recruited(id)): continue
		ids.append(id)
		names.append(Operators.display_name(id))
	var row := HBoxContainer.new()
	row.add_child(AK.label("基地形象", 14, AK.FG))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(AK.toggle(names, maxi(ids.find(str(settings.base_look)), 0), func(i):
		SystemScreens.set_setting("base_look", ids[i])
		after.call(), 13))
	return row

## 语言 / Language: the two names stay in their own language whichever is shown.
static func language_toggle(after: Callable) -> Control:
	var row := HBoxContainer.new()
	row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(AK.label("语言 / Language", 14, AK.FG))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var current := 1 if str(settings.language) == "en" else 0
	row.add_child(AK.toggle(["中文", "English"], current, func(i):
		SystemScreens.set_setting("language", "en" if i == 1 else "zh")
		after.call(), 13))
	return row

## After a language pick: the panel again, so the picked button is lit.
func _rebuild_settings() -> void:
	_settings.queue_free()
	_settings = _build_settings()
	_settings.show()

func show_settings() -> void:
	_settings.show()

## Esc on the system layer: the settings overlay closes; the title stays. True
## when the press was used here.
func go_back() -> bool:
	if _settings.visible:
		SystemScreens.save_settings()
		_settings.hide()
		return true
	if _title.visible and _slots.visible: _show_slots(false)
	return _title.visible

static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK: return
	for key in settings: settings[key] = config.get_value("game", key, settings[key])
	Keybinds.apply()

static func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings: config.set_value("game", key, settings[key])
	config.save(SETTINGS_PATH)

## Changes one setting, applies it now and saves (pause → 设置).
static func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	# Only these touch the window: the tutorial saves its step here mid-play.
	if key in ["fullscreen", "vsync"]: apply_window()
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
	if _game.is_node_ready(): _game.refresh_look()
	I18n.set_language(str(settings.language))
	apply_audio()

static func apply_window() -> void:
	if _game == null: return
	# Windowed leaves a maximised window as it is; only fullscreen is undone.
	var mode := DisplayServer.window_get_mode()
	if settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
