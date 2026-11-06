class_name LostCatalog
extends RefCounted

## 失散干员 (失散干员与主线流程策划案_v0_2.md): the Rhodes Island special
## operators who walk the base were cut off in the breakout from Chernobog.
## Each waits on a floor of one region, a base floor ±2 rolled afresh every
## contract (用户 2026-11-01: 层数在±2浮动, 每次外勤重掷), guarded by a squad;
## clear it, press E, and she is back on board at once. Until then the
## department she runs is shut (§4.2). Names are PRTS's (用户: prts名).

## id -> {name, region, floor (the base floor), depts}. In thread order.
const LOST := {
	"sharp": {"name": "Sharp", "region": "mine", "floor": 7, "depts": ["outfit"]},
	"stormeye": {"name": "Stormeye", "region": "mine", "floor": 16, "depts": ["voyage"]},
	"misery": {"name": "Misery", "region": "city", "floor": 7, "depts": ["warehouse"]},
	"pith": {"name": "Pith", "region": "snow", "floor": 8, "depts": ["lab"]},
	"mechanist": {"name": "机械师", "region": "siracusa", "floor": 9, "depts": ["workshop"]},
	"raidian": {"name": "电弧", "region": "city", "floor": 17, "depts": ["intel"]},
	"touch": {"name": "Touch", "region": "snow", "floor": 18, "depts": ["farm", "canteen"]},
	"tulip": {"name": "郁金香", "region": "siracusa", "floor": 27, "depts": ["exchange"]},
}
## What each department key is called on the roster.
const DEPT_NAMES := {"outfit": "整备部", "voyage": "沙盘航行", "warehouse": "仓储部", "lab": "科研部", "workshop": "加工部",
	"intel": "情报部研究", "farm": "农业部", "canteen": "食堂", "exchange": "交易所"}

static func dept_text(id: String) -> String:
	return "、".join((LOST[id].depts as Array).map(func(d): return DEPT_NAMES[d]))

## How far her floor strays from the base floor.
const SPREAD := 2
## Floors she is never on: camps and boss floors (every 10th).
const SKIP_EVERY := 10
## The squad round her: a squad led by an elite (as a 寻访点).
const GUARDS := 3
## Her stand-in figure until her own sheets are in (CR4: 电弧).
const STAND_IN := {"raidian": "reserve_supporter"}

## What she says when the Doctor reaches her (§7.2); PRTS's pickup line follows.
const FIELD_LINES := {
	"sharp": "博士。……这份工作比预想的拖得久了一点。",
	"stormeye": "来得正好。后面的追兵，我已经替你们拖了很久了。",
	"misery": "别那样看着我，博士，我不是刺客。只是不想被发现而已。",
	"pith": "你的判断还是那么准，博士。我还以为再也见不到罗德岛的舰灯了。",
	"mechanist": "哦，博士！工作服的电量只剩三格了，你们来得刚好。",
	"raidian": "嘿嘿……被找到了。博士，你的信号我隔着好几层就感觉到了。",
	"touch": "你们来了。这片冻土下面还有活着的根……可惜没时间研究了。",
	"tulip": "哈，博士亲自来接我？在伊比利亚，我可没这待遇。",
}
## Back on board, the next time the Doctor walks the base (§7.1): [speaker, line].
const BASE_LINES := {
	"sharp": [["Sharp", "整备部我来接手。装备、训练，都按规矩来——这是工作。"],
		["杜宾", "有人管训练，我就能专心盯着出勤的人了。博士，别让他失望。"]],
	"stormeye": [["Stormeye", "航线我来看。哪里危险我最清楚，因为我总往那儿去。"],
		["凯尔希", "舰体修复到这个程度，罗德岛可以离开切尔诺伯格了。博士，航线由你决定。"]],
	"misery": [["Misery", "仓库的空间……我能让它比看上去大一点。别问原理。"]],
	"pith": [["Pith", "科研部交给我。源石技艺的解析，我带人从头做起。"]],
	"mechanist": [["机械师", "加工部？热力学在上，那些机床被谁拆成这样的……给我一天。"]],
	"raidian": [["电弧", "通讯频段我来重新校准。情报那边也交给我吧，信息要讲究效率。"]],
	"touch": [["Touch", "种子在铁做的船里也能发芽。农业舱和食堂，我会照看。"]],
	"tulip": [["郁金香", "交易所交给我吧。拿物资换消息，这买卖我跟凯尔希医生做了好多年。"],
		["阿米娅", "大家……都回来了。博士，谢谢您。"],
		["PRTS", "罗德岛全部部门恢复运转。博士，接下来的航程，由你决定。"]],
}

static func valid(id: String) -> bool:
	return LOST.has(id)

static func name_of(id: String) -> String:
	return str(LOST.get(id, {}).get("name", id))

static func region_of(id: String) -> String:
	return str(LOST.get(id, {}).get("region", ""))

## The ones in `region`, in thread order.
static func in_region(region: String) -> Array[String]:
	var out: Array[String] = []
	for id in LOST:
		if LOST[id].region == region: out.append(id)
	return out

## Who runs department `dept` ("" for none: those stay open).
static func owner_of(dept: String) -> String:
	for id in LOST:
		if dept in LOST[id].depts: return id
	return ""

## The floors she can be on: her base floor ±SPREAD, never a camp or boss floor.
static func floors(id: String) -> Array[int]:
	var out: Array[int] = []
	var base := int(LOST[id].floor)
	for f in range(base - SPREAD, base + SPREAD + 1):
		if f >= 1 and f % SKIP_EVERY != 0: out.append(f)
	return out

## "5–9", for the cards and the roster (a gap shows as its ends: 机械师 7–11).
static func range_text(id: String) -> String:
	var f := floors(id)
	return "%d–%d" % [f[0], f[f.size() - 1]]

## Her floor for a contract that starts on `start`: one of floors() at or
## past it, or -1 when the start is already beyond all of them.
static func roll(id: String, start: int, rng: RandomNumberGenerator) -> int:
	var options := floors(id).filter(func(f): return f >= start)
	if options.is_empty(): return -1
	return int(options[rng.randi() % options.size()])

## Whose sheets stand for her on the field (her own once they are in).
static func figure_id(id: String) -> String:
	if LapplandAnimator3D.has_sheets(id): return id
	return str(STAND_IN.get(id, "reserve_guard"))
