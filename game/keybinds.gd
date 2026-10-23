class_name Keybinds
extends RefCounted

## Every rebindable function and its two keys (用户 2026-10-10, after Grim Dawn's
## Options → Keybindings: 所有功能可改键，主键＋副键；药剂可放快捷栏，也能绑专用键，
## 如鼠标侧键). A binding is a keyboard key or a mouse button (middle, side
## buttons, wheel). Left mouse (attack / move), Ctrl+click (safe bag) and Esc
## (pause, so the menu is always reachable) stay fixed. Right mouse is an
## ordinary key, by default slot 1, the dodge (用户 2026-10-20: 右键改为可绑键，
## 默认绑闪避，Shift 不再是闪避).
##
## No movement keys: she walks where the left button points (用户 2026-10-22:
## 移除 wasd 移动方式).
##
## Each function is an InputMap action of the same id. Stored in settings.cfg
## under "keybinds" as {id: [primary, secondary]}, each {"key": code} or
## {"mouse": button} or null.

## [id, name, group, primary, secondary]
const FUNCTIONS := [
	["hotbar_1", "快捷栏 1", "快捷栏", {"mouse": MOUSE_BUTTON_RIGHT}, null],
	["hotbar_2", "快捷栏 2", "快捷栏", {"key": KEY_SPACE}, null],
	["hotbar_3", "快捷栏 3", "快捷栏", {"key": KEY_Q}, null],
	["hotbar_4", "快捷栏 4", "快捷栏", {"key": KEY_1}, null],
	["hotbar_5", "快捷栏 5", "快捷栏", {"key": KEY_2}, null],
	["hotbar_6", "快捷栏 6", "快捷栏", {"key": KEY_3}, null],
	["hotbar_7", "快捷栏 7", "快捷栏", {"key": KEY_4}, null],
	["hotbar_8", "快捷栏 8", "快捷栏", {"key": KEY_5}, null],
	["dash", "闪避", "专用键", null, null],
	["operator_skill", "绝影", "专用键", null, null],
	["potion_A", "标准急救剂", "专用键", null, null],
	["potion_B", "缓释凝胶", "专用键", null, null],
	["potion_C", "抑制喷剂", "专用键", null, null],
	["camera_zoom_in", "拉近视角", "视角", {"mouse": MOUSE_BUTTON_WHEEL_UP}, null],
	["camera_zoom_out", "拉远视角", "视角", {"mouse": MOUSE_BUTTON_WHEEL_DOWN}, null],
	["camera_turn_left", "视角左转", "视角", {"key": KEY_Z}, null],
	["camera_turn_right", "视角右转", "视角", {"key": KEY_X}, null],
	["camera_tilt_up", "视角抬高", "视角", {"key": KEY_PAGEUP}, null],
	["camera_tilt_down", "视角压低", "视角", {"key": KEY_PAGEDOWN}, null],
	["camera_drag", "拖动旋转视角", "视角", {"mouse": MOUSE_BUTTON_MIDDLE}, null],
	["camera_reset", "复位视角", "视角", {"key": KEY_HOME}, null],
	["interact", "交互", "界面", {"key": KEY_E}, null],
	["toggle_inventory", "背包", "界面", {"key": KEY_I}, null],
	# I and C are two windows now (界面美术与布局策划案 v2 S1).
	["toggle_operator", "干员", "界面", {"key": KEY_C}, null],
	["toggle_relics", "藏品", "界面", {"key": KEY_R}, null],
	["toggle_map", "地图", "界面", {"key": KEY_M}, null],
	["toggle_journal", "合同", "界面", {"key": KEY_J}, null],
	["stash_item", "存入安全袋", "界面", {"key": KEY_B}, null],
	["show_items", "显示全部地面物品", "界面", {"key": KEY_ALT}, null],
	["toggle_watch", "盯盘小窗（基地）", "界面", {"key": KEY_K}, null],
	["toggle_stations", "站点总览（基地）", "界面", {"key": KEY_TAB}, null],
]
## Shown on the keys page, not changeable.
const FIXED := [["攻击 / 移动 / 拾取 / 选择", "左键"], ["安全袋", "Ctrl + 左键"], ["暂停", "Esc"]]
const BLOCKED_KEYS := [KEY_ESCAPE]
const BLOCKED_MOUSE := [MOUSE_BUTTON_LEFT]

static func ids() -> Array:
	return FUNCTIONS.map(func(f): return f[0])

static func info(id: String) -> Array:
	for f in FUNCTIONS:
		if f[0] == id: return f
	return []

static func _valid(binding: Variant) -> bool:
	if not binding is Dictionary: return false
	if binding.has("key"): return int(binding.key) > 0 and not int(binding.key) in BLOCKED_KEYS
	if binding.has("mouse"): return int(binding.mouse) > 0 and not int(binding.mouse) in BLOCKED_MOUSE
	return false

static func _same(a: Variant, b: Variant) -> bool:
	return a is Dictionary and b is Dictionary and a.get("key", -1) == b.get("key", -1) and a.get("mouse", -1) == b.get("mouse", -1)

## {id: [primary, secondary]}, saved values over the defaults, bad ones dropped.
static func all() -> Dictionary:
	var saved: Variant = SystemScreens.settings.get("keybinds", {})
	var out := {}
	for f in FUNCTIONS:
		var pair: Array = [f[3], f[4]]
		if saved is Dictionary and saved.has(f[0]) and saved[f[0]] is Array:
			var s: Array = saved[f[0]]
			for k in range(2):
				if k < s.size(): pair[k] = s[k] if _valid(s[k]) else null
		out[f[0]] = pair
	return out

static func get_pair(id: String) -> Array:
	return all().get(id, [null, null])

## Bind `binding` to `id`'s slot `which` (0 primary, 1 secondary). Whatever
## else had it loses it, so one press never means two things. null clears.
static func bind(id: String, which: int, binding: Variant) -> bool:
	if info(id).is_empty() or which < 0 or which > 1: return false
	if binding != null and not _valid(binding): return false
	var data := all()
	if binding != null:
		for other in data:
			for k in range(2):
				if _same(data[other][k], binding): data[other][k] = null
	data[id][which] = binding
	_store(data)
	return true

static func reset() -> void:
	_store({})

static func _store(data: Dictionary) -> void:
	SystemScreens.settings["keybinds"] = data
	apply()
	# Only a running game writes settings.cfg (as SystemScreens.set_setting).
	if SystemScreens._game != null: SystemScreens.save_settings()

## Rebuild every function's InputMap action from the bindings.
static func apply() -> void:
	var data := all()
	for id in data:
		if not InputMap.has_action(id): InputMap.add_action(id, 0.5)
		InputMap.action_erase_events(id)
		for binding in data[id]:
			var event := event_for(binding)
			if event != null: InputMap.action_add_event(id, event)

static func event_for(binding: Variant) -> InputEvent:
	if not binding is Dictionary: return null
	if binding.has("key"):
		var key := InputEventKey.new()
		key.physical_keycode = int(binding.key)
		return key
	if binding.has("mouse"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(binding.mouse)
		return mouse
	return null

## A binding from a real input event, or null if it cannot be bound.
static func from_event(event: InputEvent) -> Variant:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var b := {"key": code}
		return b if _valid(b) else null
	if event is InputEventMouseButton:
		var b := {"mouse": event.button_index}
		return b if _valid(b) else null
	return null

const MOUSE_NAMES := {MOUSE_BUTTON_RIGHT: "右键", MOUSE_BUTTON_MIDDLE: "中键", MOUSE_BUTTON_XBUTTON1: "侧键 1", MOUSE_BUTTON_XBUTTON2: "侧键 2",
	MOUSE_BUTTON_WHEEL_UP: "滚轮上", MOUSE_BUTTON_WHEEL_DOWN: "滚轮下", MOUSE_BUTTON_WHEEL_LEFT: "滚轮左", MOUSE_BUTTON_WHEEL_RIGHT: "滚轮右"}

static func label(binding: Variant) -> String:
	if not binding is Dictionary: return ""
	if binding.has("mouse"): return MOUSE_NAMES.get(int(binding.mouse), "鼠标 %d" % int(binding.mouse))
	match int(binding.key):
		KEY_SHIFT: return "⇧"
		KEY_SPACE: return "SPC"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
	return OS.get_keycode_string(int(binding.key))

## The short label for a function on the bar: its primary, else secondary.
static func short_label(id: String) -> String:
	var pair := get_pair(id)
	return label(pair[0]) if pair[0] != null else label(pair[1])
