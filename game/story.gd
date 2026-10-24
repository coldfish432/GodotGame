class_name Story
extends RefCounted

## 主线引导 (主基地线性叙事与教程策划案 v0.2): the base's linear thread. Each
## beat brings one or two facilities forward with a few lines of dialogue and
## an objective card; it ends when all its goals are done, and the next one
## begins. It only guides — nothing is locked but the regions before the first
## voyage (用户 2026-10-22: 不锁，只负责指引；沙盘航行前只能选切尔诺伯格). No
## chapters, no money (不引入章概念，不给龙门币). Each goal is "done once,
## done for good": once its check is true it is kept in `done`.
##
## State lives in BaseState.story: {"done": [goal ids], "seen": [beat ids
## whose dialogue was shown], "counts": {event: n}, "fell": bool (the last
## contract ended in a retreat)}. A save from before the thread has none and
## counts as finished.

## {id, title, after: [beat ids], lines (and lines_fell), goals: [[id, text]],
## hide_done: goals shown only while not done}
const BEATS := [
	{"id": "wake", "title": "苏醒", "after": [],
		"lines": [["PRTS", "系统同步完成。欢迎回来，博士。"], ["阿米娅", "博士，您终于醒了……罗德岛的情况不太好，我们需要您。"]],
		"goals": [["first_contract", "接下第一份合同出击"]]},
	{"id": "return", "title": "归舰", "after": ["wake"],
		"lines": [["PRTS", "外勤队已归舰。带回的物资还在背包里，可以在结算的仓库页一键入库，博士。"]],
		"lines_fell": [["凯尔希", "……回来就好。先去医疗部，然后看看你带回了什么。"]],
		"goals": [["shelve", "把带回的物品存进仓库"], ["order", "在出库区完成一张订单"], ["treat", "在医疗前台治疗重伤"]],
		"hide_done": ["treat"]},
	{"id": "outfit", "title": "整备", "after": ["return"],
		"lines": [["杜宾", "博士，外勤不是郊游。备齐装备，贵重的东西先投保，如果投保的装备遗落在外勤区域，罗德岛小队会去回收。"]],
		"goals": [["bench_equip", "在整备台穿上一件装备"], ["insure", "在后勤柜台为一件装备投保"]]},
	{"id": "hub", "title": "基建", "after": ["outfit"],
		"lines": [["可露希尔", "哟，博士！工程部那群人说总控台要是不修好，什么都升不了级。电线、继电器、灯泡，带回来我就给你装上——钱嘛，另算。"]],
		"goals": [["hub_parts", "备齐电线×2、继电器×1、灯泡×2"], ["hub_built", "建成基建总控台"], ["hub_link", "把仓储部接入总控台"]]},
	{"id": "supply", "title": "补给线", "after": ["hub"],
		"lines": [["可露希尔", "商店重新营业！不过我这儿只收赤金。"], ["PRTS", "博士，每十层之后设有前进据点，到达后可以在那里补给与撤离。"]],
		"goals": [["store_potion", "在可露希尔的商店买一瓶特供药剂"], ["camp", "到达前进据点"]]},
	{"id": "recruit", "title": "寻访", "after": ["supply"],
		"lines": [["阿米娅", "博士，外勤区域里有干员留下的行动痕迹……她应该还在附近。把这些线索交给人事部，就能查到她的下落。"]],
		"goals": [["personnel", "在人事部查看寻访进度"], ["joined", "让一名干员入职"]]},
	{"id": "voyage", "title": "航行", "after": ["supply"],
		"lines": [["凯尔希", "舰体修复到这个程度，罗德岛可以离开切尔诺伯格了。博士，航线由你决定。"]],
		"goals": [["sailed", "在沙盘上指挥罗德岛号航行"], ["away", "在新的地区完成一份合同"]]},
	{"id": "industry", "title": "产业", "after": ["voyage"],
		"lines": [["PRTS", "工程部与科研部申请恢复运转，博士。"]],
		"goals": [["crafted", "在加工站完成一次加工"], ["researching", "建成科研部并开始一项研究"]]},
	{"id": "deck2", "title": "二层", "after": ["industry"],
		"lines": [["阿米娅", "博士，二层的农业舱修好了！大家说想吃点热的……"]],
		"goals": [["lift", "乘升降梯去二层"], ["sowed", "建成农业部并播种一次"], ["meal", "建成食堂，出发前用一次餐"]]},
	{"id": "finale", "title": "罗德岛", "after": ["deck2"],
		"lines": [["PRTS", "罗德岛全部部门恢复运转。博士，接下来的航程，由你决定。"]],
		"goals": [["exchange", "建成交易所"]]},
]
## Who speaks with which standing art (UA/UB 120×240; 用户 2026-10-22: 头像位置
## 改为画面左侧全身立绘). None yet (杜宾, 凯尔希 until ST1a; PRTS never): the
## name in the box alone.
const PORTRAITS := {
	"阿米娅": "res://art/ui/portraits/op_amiya_guard.png",
	"可露希尔": "res://art/ui/portraits/npc_closure.png",
	"杜宾": "res://art/ui/portraits/npc_dobermann.png",
	"凯尔希": "res://art/ui/portraits/npc_kaltsit.png",
}
const HUB_PARTS := {"电线": 2, "继电器": 1, "灯泡": 2}

static func fresh() -> Dictionary:
	return {"done": [], "seen": [], "counts": {}, "fell": false}

## A save from before the thread: all of it done.
static func finished_state() -> Dictionary:
	var state := fresh()
	for beat in BEATS:
		for goal in beat.goals: state.done.append(goal[0])
		state.seen.append(beat.id)
	return state

static func beat(id: String) -> Dictionary:
	for b in BEATS:
		if b.id == id: return b
	return {}

static func is_on() -> bool:
	return bool(SystemScreens.settings.get("story_guide", true))

static func beat_done(state: Dictionary, b: Dictionary) -> bool:
	return b.goals.all(func(g): return g[0] in state.done)

## The beats under way: every one before them done, not done themselves (two
## at once only for 寻访 and 航行).
static func active(state: Dictionary) -> Array:
	var out: Array = []
	for b in BEATS:
		if beat_done(state, b): continue
		if b.after.all(func(a): return beat_done(state, beat(a))): out.append(b)
	return out

static func all_done(state: Dictionary) -> bool:
	return BEATS.all(func(b): return beat_done(state, b))

## Counts one event (a crate opened, an order filled…), for the goals that are
## about something done rather than a state.
static func note(state: Dictionary, event: String) -> void:
	state.counts[event] = int(state.counts.get(event, 0)) + 1

static func count(state: Dictionary, event: String) -> int:
	return int(state.counts.get(event, 0))

## Whether goal `id` is met now.
static func check(game: GameManager, state: Dictionary, id: String) -> bool:
	var base := game.base
	match id:
		"first_contract": return count(state, "contract") > 0
		"crate": return count(state, "crate") > 0
		"shelve": return count(state, "shelve") > 0
		"order": return count(state, "order") > 0
		"treat": return not base.any_injured()
		"bench_equip": return count(state, "bench_equip") > 0
		"insure": return count(state, "insure") > 0
		"hub_parts": return base.hub_built() or HUB_PARTS.keys().all(func(m): return game.material_count(m) >= int(HUB_PARTS[m]))
		"hub_built": return base.hub_built()
		"hub_link": return base.is_connected_to_hub("warehouse")
		"store_potion": return count(state, "store_potion") > 0
		"camp": return count(state, "camp") > 0
		"personnel": return count(state, "personnel") > 0
		"joined": return count(state, "joined") > 0
		"sailed": return count(state, "sailed") > 0
		"away": return count(state, "away") > 0
		"crafted": return count(state, "crafted") > 0
		"researching": return base.facility_level("lab") >= 1 and count(state, "research") > 0
		"lift": return count(state, "lift") > 0
		"sowed": return base.facility_level("farm") >= 1 and count(state, "sowed") > 0
		"meal": return base.facility_level("canteen") >= 1 and count(state, "meal") > 0
		"exchange": return base.facility_level("exchange") >= 1
	return false

## Ticks off what is met now; true when something new was ticked.
static func update(game: GameManager, state: Dictionary) -> bool:
	var changed := false
	for b in active(state):
		for g in b.goals:
			if g[0] in state.done: continue
			if check(game, state, g[0]):
				state.done.append(g[0])
				changed = true
	return changed

## The dialogue of `b`, by how the last contract ended where that matters.
static func lines_of(state: Dictionary, b: Dictionary) -> Array:
	if bool(state.get("fell", false)) and b.has("lines_fell"): return b.lines_fell
	return b.lines

## Regions other than 切尔诺伯格 wait for the first voyage, while the thread runs.
static func region_open(state: Dictionary, region: String) -> bool:
	return region == "mine" or not is_on() or "sailed" in state.done or count(state, "sailed") > 0 or all_done(state)
