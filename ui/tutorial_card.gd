class_name TutorialCard
extends PanelContainer

## 新手引导 (用户 2026-10-22: 做简单教程 → 游戏内首次引导; 以 PRTS 的口吻，
## 形式用群星挂在右侧的教程卡片; 教程覆盖所有操作，基础操作游戏开始就教).
## Stellaris's advisor card, PRTS speaking: it hangs on the right above the
## bottom edge, one step at a time — a title, what PRTS says, and the objective
## with a box that ticks itself when she does it. The basic controls, in the
## order she meets them; what she first sees on screen (密室, 踪迹, 火堆, 陷阱…)
## is TutorialSpotlight's. The only places with explanatory text; the PRTS
## toasts stay notices only. Progress is SystemScreens.settings.tutorial_step
## (STEPS.size() = done); 暂停 → 设置 → 界面 → 新手引导 turns both off, or back
## on from the start. Only the real game shows it (game.system_screens set), or
## a test that sets `forced`.

## [id, title, what PRTS says, objective ("" = read it, 下一步), where: "base" / "field"]
const STEPS := [
	["move", "行动确认", "欢迎回来，博士。PRTS 已完成同步。请先确认行动能力：左键点击地面即可前往目标位置，按住左键可以持续移动。", "移动", "base"],
	# 用户 2026-10-24: 三个台的介绍之后，介绍左键移动、右键闪现 — both on board.
	["dodge", "闪避", "按闪避键沿移动方向快速闪避，站着时朝面向闪避，每次消耗体力。外勤时敌人出手前，地面会出现攻击预警，及时闪避就能脱离。", "闪避一次", "base"],
	["camera", "观察视角", "可以按需调整观察视角：滚轮缩放，旋转键每次转动 45°，翻页键调整俯角，按住中键拖动自由旋转，复位键恢复默认视角。", "调整一次视角", "base"],
	# 用户 2026-10-24: 合同委托之前加一个整备台选装备.
	["outfit", "整备", "出发前先到整备台备好装备：仓库里的装备可以直接穿上，缺的部位可以在制式页免费领取罗德岛制式装备。", "在整备台穿上一件装备", "base"],
	["contract", "合同委托", "调度台已收到新的合同委托。请前往调度台按交互键，选择地区和合同，在出发准备里确认干员后即可出击。", "调度台接合同出击", "base"],
	["kill", "接敌", "已抵达作业区域，检测到敌对单位。左键点击敌人，干员会自动接近并攻击；按住左键可以持续进攻。", "击败一个敌人", "field"],
	["skill", "干员技能", "每名干员都有一个主动技能，冷却完毕后按技能键施放；快捷栏上的技能格会显示冷却进度。", "施放一次技能", "field"],
	["search", "搜索", "作业区域内有可以搜索的箱柜。靠近后按交互键打开，点击或拖动即可取出其中的物品。", "搜索一个容器", "field"],
	["pickup", "物资回收", "地面上的物资会显示名牌，左键点击名牌即可拾取；按住显示键列出附近全部地面物品。背包标题栏的过滤按钮可以隐藏低品质物品的名牌。", "拾取一件物品", "field"],
	["inventory", "携带物品", "物资已收入背包。打开背包可检查携带物品与装备；背包装满后将无法继续拾取。", "打开背包", "field"],
	["equip", "换装", "在背包里右键一件装备即可穿上，也可以拖到左侧人偶的格子上；右键已穿的装备会卸回背包。属性需求不足的装备无法穿戴。", "穿上一件装备", "field"],
	["safe_bag", "安全袋", "安全袋由博士随身携带，即使行动失败，袋中的物品也会保留。在背包中 Ctrl + 左键点击物品放入，或按安全袋键放入最近拾取的物品。", "放入安全袋", "field"],
	["operator", "干员档案", "干员档案里可以查看属性，并分配升级获得的属性点和技能点。", "打开干员面板", "field"],
	["relics", "藏品", "本次行动获得的藏品都记录在这里，点击即可查看效果；图鉴页收录全部藏品。", "打开藏品面板", "field"],
	["journal", "合同目标", "合同面板显示本次合同的目标进度，以及基地各部门的订单需求。", "打开合同面板", "field"],
	["map", "作战地图", "地图上可查看本层已探明的区域，深入入口、撤离信标等标记也会显示在上面。", "打开地图", "field"],
	["hotbar", "快捷栏", "屏幕下方是快捷栏：闪避、技能和药剂都在这里。左键点击一个格子可以更换其中的内容；最右侧的自动格放急救剂，生命过低时会自动饮用。", "", "field"],
	["descend", "深入", "沿道路寻找深入入口，按交互键选择路线进入下一层。越往深处，敌人越强，收获也越好。", "进入下一层", "field"],
	# 用户 2026-10-22: 第一次外勤必须从随机撤离点撤离 (GameManager.first_run_lock).
	["extract", "撤离", "第 5 层设有撤离信标。进入撤离区域停留数秒即可返回罗德岛，携带的物品一同带回。首次外勤请从撤离信标撤离。", "从撤离信标撤离", "field"],
]
## Steps that can stall on what the floor gives (no gear to put on yet): 下一步 too.
const OPTIONAL := ["equip", "outfit"]
const DONE_TEXT := "基础操作确认完毕。PRTS 将持续为您提供支援，博士。"
## The ticked box shows this long before the next step comes up.
const TICK_SECONDS := 0.8
const DONE_SECONDS := 4.0
const MOVE_DISTANCE := 4.0
const WIDTH := 300.0
const RIGHT := 1268.0
## Clear of the stamina label in the field and the base buttons.
const BOTTOM := 630.0

var game: GameManager
var forced := false
var _index := -1
var _from := Vector3.ZERO
var _kills := 0
var _carried := 0
var _floor := 0
var _view := []
var _bagged := 0
var _gear := []
var _next_pressed := false
var _cooldown := 0.0
var _next: Button
var _tick_left := 0.0
var _done_left := 0.0
var _count: Label
var _title: Label
var _text: Label
var _box: Panel
var _goal: Label
var _keys: Label
var _goal_row: HBoxContainer

func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var plate := AK.box(AK.PLATE, AK.BLUE, 0, 12)
	plate.border_width_left = 3
	add_theme_stylebox_override("panel", plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var badge := AK.label("PRTS", 11, AK.INK, AK.en())
	var badge_plate := AK.box(AK.BLUE, Color.TRANSPARENT, 0, 0)
	badge_plate.content_margin_left = 6
	badge_plate.content_margin_right = 6
	badge.add_theme_stylebox_override("normal", badge_plate)
	head.add_child(badge)
	_title = AK.label("", 15, AK.FG)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = AK.label("", 11, AK.MUTE, AK.en())
	head.add_child(_count)
	column.add_child(AK.rect(AK.LINE, Vector2.ZERO, Vector2(WIDTH - 24, 1)))
	_text = AK.label("", 13, AK.FG)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# It wraps instead: English keeps the full size (AK.fit would shrink it).
	_text.remove_meta("fit_size")
	_text.custom_minimum_size = Vector2(WIDTH - 24, 0)
	column.add_child(_text)
	_goal_row = HBoxContainer.new()
	_goal_row.add_theme_constant_override("separation", 6)
	column.add_child(_goal_row)
	_box = Panel.new()
	_box.custom_minimum_size = Vector2(14, 14)
	_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_goal_row.add_child(_box)
	_goal = AK.label("", 13, AK.FG)
	_goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_row.add_child(_goal)
	_keys = AK.label("", 12, AK.SP)
	_goal_row.add_child(_keys)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 6)
	column.add_child(foot)
	# A step with nothing to do (an objective of "") reads and goes on.
	_next = AK.button("下一步", "blue", 11)
	_next.pressed.connect(func(): _next_pressed = true)
	foot.add_child(_next)
	var skip := AK.button("跳过引导", "ghost", 11)
	skip.pressed.connect(skip_all)
	foot.add_child(skip)
	visible = false

## The key that dodges: the 闪避 key if one is bound, else the bar slot holding it.
static func dodge_action() -> String:
	if Keybinds.get_pair("dash").any(func(b): return b != null): return "dash"
	var bar := Hotbar.slots()
	for i in range(bar.size()):
		if bar[i].action == "dash": return Hotbar.input_of(i)
	return Hotbar.input_of(0)

static func index_of(id: String) -> int:
	for i in range(STEPS.size()):
		if STEPS[i][0] == id: return i
	return -1

## The key that casts the operator's skill: its own key if bound, else the bar slot.
static func skill_action() -> String:
	if Keybinds.get_pair("operator_skill").any(func(b): return b != null): return "operator_skill"
	var bar := Hotbar.slots()
	for i in range(bar.size()):
		if bar[i].action == "shadow": return Hotbar.input_of(i)
	return Hotbar.input_of(1)

func waiting_for_intro(at: int) -> bool:
	if not game.in_base or at > TutorialCard.index_of("contract") or not TutorialSpotlight.tips_on(): return false
	var spot := game.tutorial_spotlight
	if not is_instance_valid(spot) or not (spot.forced or is_instance_valid(game.system_screens)): return false
	return not TutorialSpotlight.seen("base_departure") or not spot.showing.is_empty()

static func step() -> int:
	return int(SystemScreens.settings.get("tutorial_step", 0))

static func finished() -> bool:
	return step() >= STEPS.size()

## Settings: on starts over from the first step, off skips it all.
static func set_on(on: bool) -> void:
	SystemScreens.settings["tutorial_seen"] = []
	SystemScreens.set_setting("tutorial_tips", on)
	SystemScreens.set_setting("tutorial_step", 0 if on else STEPS.size())

## 跳过引导 skips the basic steps; the first-sight cards keep coming.
func skip_all() -> void:
	_done_left = 0.0
	_tick_left = 0.0
	SystemScreens.set_setting("tutorial_step", STEPS.size())

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or not (forced or is_instance_valid(game.system_screens)):
		visible = false
		return
	_place()
	if _done_left > 0.0:
		_done_left -= delta
		visible = _done_left > 0.0 and _calm()
		return
	var at := step()
	if at >= STEPS.size():
		visible = false
		_index = -1
		return
	# The first base visit goes: the waking talk, the three departure stations
	# (TutorialSpotlight), then this card. Until those are past, it waits and
	# counts nothing (用户 2026-10-24).
	if waiting_for_intro(at):
		visible = false
		_index = -1
		return
	if _tick_left > 0.0:
		_tick_left -= delta
		if _tick_left <= 0.0: _advance(at)
		return
	if at != _index: _begin(at)
	if _met(STEPS[at][0]):
		_tick_left = TICK_SECONDS
		_tick(true)
		return
	var here: String = "base" if game.in_base else "field"
	visible = here == STEPS[at][4] and _calm()
	if visible: _keys.text = _key_text(STEPS[at][0])

## Bottom-right, growing upward as the text wraps.
func _place() -> void:
	reset_size()
	position = Vector2(RIGHT - size.x, BOTTOM - size.y)

func _advance(at: int) -> void:
	SystemScreens.set_setting("tutorial_step", at + 1)
	if at + 1 < STEPS.size(): return
	_done_left = DONE_SECONDS
	_count.text = ""
	_title.text = "引导完成"
	_text.text = DONE_TEXT
	_goal_row.visible = false

## Out of the way of menus, loading and the camp screen.
func _calm() -> bool:
	return game.modal.is_empty() and not game.transitioning and not game.in_camp

## Where each step's check counts from.
func _begin(at: int) -> void:
	_index = at
	_from = game.player.global_position
	_kills = _kill_total()
	_carried = _carried_total()
	_floor = game.floor_number
	_view = _view_now()
	_bagged = game.safe_bag.items.size()
	_gear = _gear_now()
	_cooldown = game.player.skill_cooldown_left() if game.player.has_skill() else 0.0
	_next_pressed = false
	var reading: bool = str(STEPS[at][3]).is_empty()
	_next.visible = reading or STEPS[at][0] in OPTIONAL
	_count.text = "%d/%d" % [at + 1, STEPS.size()]
	_title.text = STEPS[at][1]
	_text.text = STEPS[at][2]
	_goal.text = STEPS[at][3]
	_goal_row.visible = not reading
	_tick(false)

## The objective's box: empty, or filled green once it is done.
func _tick(done: bool) -> void:
	_box.add_theme_stylebox_override("panel", AK.box(AK.GREEN if done else Color.TRANSPARENT, AK.GREEN if done else AK.FG, 2, 0))
	_goal.add_theme_color_override("font_color", AK.GREEN if done else AK.FG)

func ticked() -> bool:
	return _tick_left > 0.0

func _met(id: String) -> bool:
	match id:
		"move":
			var offset := game.player.global_position - _from
			offset.y = 0.0
			return game.in_base and offset.length() >= MOVE_DISTANCE
		"camera": return _view_now() != _view
		"contract": return not game.in_base and not game.transitioning
		"dodge": return game.player.dash_remaining > 0.0
		"skill":
			if not game.player.has_skill(): return true
			# Cast: the cooldown jumps up from where it was.
			var left := game.player.skill_cooldown_left()
			var cast := left > _cooldown + 0.5
			_cooldown = left
			return cast
		"equip": return _gear_now() != _gear or _next_pressed
		"outfit": return (game.in_base and _gear_now() != _gear) or _next_pressed
		"operator": return game.modal == "training"
		"relics": return game.modal == "relics"
		"journal": return game.modal == "journal"
		"hotbar": return _next_pressed
		"search": return is_instance_valid(game.looting)
		"safe_bag":
			if game.safe_bag.items.size() < _bagged: _bagged = game.safe_bag.items.size()
			return game.safe_bag.items.size() > _bagged
		"map": return game.modal == "map"
		"kill": return _kill_total() > _kills
		"pickup": return _carried_total() > _carried
		"inventory": return game.modal == "inventory"
		"descend": return game.floor_number > _floor
		"extract": return game.base.extracted_once
	return false

func _gear_now() -> Array:
	return game.player.equipped.values().map(func(i): return i.get_instance_id() if i != null else 0)

func _view_now() -> Array:
	return [snappedf(game.camera_yaw_goal, 0.01), snappedf(game.camera_size_goal, 0.01), snappedf(game.camera_pitch_goal, 0.01)]

func _kill_total() -> int:
	var total := 0
	for kind in game.run_kills: total += int(game.run_kills[kind])
	# A new contract clears the tally: count from wherever it is now.
	if total < _kills: _kills = total
	return total

func _carried_total() -> int:
	var total := 0
	for item in game.inventory.items: total += maxi(1, item.quantity)
	if total < _carried: _carried = total
	return total

func _key_text(id: String) -> String:
	match id:
		"move": return "左键"
		"camera": return "%s / %s %s / %s %s" % [Keybinds.short_label("camera_zoom_in"), Keybinds.short_label("camera_turn_left"), Keybinds.short_label("camera_turn_right"), Keybinds.short_label("camera_tilt_up"), Keybinds.short_label("camera_tilt_down")]
		"contract", "search", "outfit": return Keybinds.short_label("interact")
		"dodge": return Keybinds.short_label(TutorialCard.dodge_action())
		"skill": return Keybinds.short_label(TutorialCard.skill_action())
		"equip": return "右键"
		"operator": return Keybinds.short_label("toggle_operator")
		"relics": return Keybinds.short_label("toggle_relics")
		"journal": return Keybinds.short_label("toggle_journal")
		"kill": return "左键"
		"pickup": return "左键 / %s" % Keybinds.short_label("show_items")
		"safe_bag": return "Ctrl + 左键 / %s" % Keybinds.short_label("stash_item")
		"map": return Keybinds.short_label("toggle_map")
		"inventory": return Keybinds.short_label("toggle_inventory")
		"descend": return Keybinds.short_label("interact")
		"extract": return ""
	return ""
