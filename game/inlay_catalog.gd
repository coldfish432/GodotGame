class_name InlayCatalog
extends RefCounted

## 镶件 (抗性为王修订案 v0.4 §5.2–§5.3, 用户 2026-11-25: 不做成物品、格子角上代码画菱形；
## 镶件不止加元素抗性): not an item but a line on a piece of gear, set at the
## workbench's 镶嵌 page. Each of the seven non-weapon slots holds one; setting
## another overwrites it (the old one is gone, its materials too). It stays with
## the piece — sold, stored, insured. Saved on the item as
##   item.inlay = {"id": String, "tier": 0–3, "kinds": [element, …]}
## 0 初级, 1 中级, 2 高级, 3 特制 (★ only). Values below are 高级's.

const C := Item.Category
const ARMOUR := [C.HEAD, C.CHEST, C.HANDS, C.LEGS, C.FEET, C.AMULET, C.RING]
const ELEMENTS := ["burn", "cold", "corr", "nerve"]
const DMG_ELEMENTS := ["burn", "cold", "corr", "nerve", "necro"]

## id -> name, group, slots, stats (key -> 高级 value), pick (how many
## elements she chooses: their keys are "<kind>" templates), special (特制 only).
const INLAYS := {
	# 抗性类
	"res_one": {"name": "元素抗性", "group": "resist", "slots": ARMOUR, "stats": {"res_%s": 20.0}, "pick": 1},
	"res_two": {"name": "双元素抗性", "group": "resist", "slots": ARMOUR, "stats": {"res_%s": 12.0}, "pick": 2},
	"res_all": {"name": "全元素抗性", "group": "resist", "slots": ARMOUR, "stats": {"res_all_elem": 8.0}},
	"res_arts": {"name": "法抗", "group": "resist", "slots": [C.HEAD, C.CHEST, C.AMULET], "stats": {"res": 10.0}},
	"res_bleed": {"name": "流血抗性", "group": "resist", "slots": [C.CHEST, C.LEGS], "stats": {"res_bleed": 25.0}},
	"res_cap": {"name": "元素抗性上限", "group": "resist", "slots": [C.AMULET], "stats": {"res_cap": 1.0}, "special": true},
	# 防御类
	"def": {"name": "防御", "group": "guard", "slots": [C.CHEST, C.LEGS], "stats": {"def_pct": 0.06}},
	"hp": {"name": "生命上限", "group": "guard", "slots": [C.HEAD, C.CHEST], "stats": {"hp_pct": 0.04}},
	"ranged": {"name": "受到远程伤害", "group": "guard", "slots": [C.HEAD], "stats": {"ranged_taken": -0.06}},
	"melee": {"name": "受到近战伤害", "group": "guard", "slots": [C.CHEST], "stats": {"melee_taken": -0.05}},
	"evasion": {"name": "闪避", "group": "guard", "slots": [C.FEET], "stats": {"evasion": 0.03}},
	"boss": {"name": "受到首领伤害", "group": "guard", "slots": [C.CHEST], "stats": {"boss_taken": -0.08}, "special": true},
	# 异常类
	"freeze": {"name": "冰冻时间", "group": "ailment", "slots": [C.FEET], "stats": {"freeze_taken": -0.30}},
	"dot": {"name": "持续伤害时间", "group": "ailment", "slots": [C.LEGS], "stats": {"dot_taken_dur": -0.25}},
	"gauge": {"name": "自身损伤积累", "group": "ailment", "slots": [C.HEAD], "stats": {"gauge_taken": -0.20}},
	"slow": {"name": "受到的减速", "group": "ailment", "slots": [C.FEET], "stats": {"slow_taken": -0.30}},
	"shred": {"name": "受到的减抗", "group": "ailment", "slots": [C.AMULET, C.RING], "stats": {"shred_taken": -0.40}},
	"burst": {"name": "元素爆发对自身", "group": "ailment", "slots": [C.CHEST], "stats": {"burst_taken": -0.35}, "special": true},
	# 恢复类
	"heal": {"name": "治疗效果", "group": "mend", "slots": [C.HANDS, C.RING], "stats": {"heal_pct": 0.10}},
	"kill_heal": {"name": "击杀回复生命", "group": "mend", "slots": [C.HANDS], "stats": {"kill_heal": 0.01}},
	"regen": {"name": "脱战回血", "group": "mend", "slots": [C.LEGS], "stats": {"regen_pct": 0.50}},
	# 机动与进攻类
	"move": {"name": "移动速度", "group": "edge", "slots": [C.FEET], "stats": {"move_pct": 0.04}},
	"dash": {"name": "冲刺冷却", "group": "edge", "slots": [C.FEET], "stats": {"dash_cd_pct": -0.08}},
	"elem_dmg": {"name": "元素伤害", "group": "edge", "slots": [C.HANDS, C.RING], "stats": {"%s_dmg_pct": 0.08}, "pick": 1, "kinds": DMG_ELEMENTS},
	"crit_dmg": {"name": "暴击伤害", "group": "edge", "slots": [C.RING], "stats": {"crit_dmg": 0.10}},
	"skill_cd": {"name": "技能冷却", "group": "edge", "slots": [C.AMULET], "stats": {"skill_cd_pct": -0.04}},
}
const ORDER := ["res_one", "res_two", "res_all", "res_arts", "res_bleed", "res_cap", "def", "hp", "ranged", "melee", "evasion", "boss",
	"freeze", "dot", "gauge", "slow", "shred", "burst", "heal", "kill_heal", "regen", "move", "dash", "elem_dmg", "crit_dmg", "skill_cd"]

const TIER_NAMES := ["初级", "中级", "高级", "特制"]
const TIER_MULT := [0.5, 0.75, 1.0, 1.0]
const TIER_LMD := [200, 600, 1500, 4000]
## Each group's material line: ★2, ★3, ★4 (特制 adds D32钢).
const LINES := {
	"resist": ["固源岩", "固源岩组", "提纯源岩"],
	"guard": ["异铁", "异铁组", "改量装置"],
	"ailment": ["聚酸酯", "扭转醇", "改量装置"],
	"mend": ["糖", "凝胶", "提纯源岩"],
	"edge": ["酮凝集", "轻锰矿", "改量装置"],
}
const SPECIAL_MATERIAL := "D32钢"

static func has_slot(item: Item) -> bool:
	return item != null and item.category in ARMOUR

static func entry(id: String) -> Dictionary:
	return INLAYS.get(id, {})

## The inlays `slot` takes, in ORDER.
static func for_slot(slot: int) -> Array:
	return ORDER.filter(func(id): return slot in (INLAYS[id].slots as Array))

## The tiers `id` comes in: 特制 alone for a ★ one, else 初级–高级.
static func tiers_of(id: String) -> Array:
	return [3] if bool(entry(id).get("special", false)) else [0, 1, 2]

static func kinds_pool(id: String) -> Array:
	return entry(id).get("kinds", ELEMENTS)

static func picks(id: String) -> int:
	return int(entry(id).get("pick", 0))

## The stat sheet an inlay adds.
static func stats_for(id: String, tier: int, kinds: Array) -> Dictionary:
	var out := {}
	var e := entry(id)
	if e.is_empty(): return out
	var mult: float = TIER_MULT[clampi(tier, 0, 3)]
	for key in e.stats:
		var value := float(e.stats[key]) * mult
		if str(key).contains("%s"):
			for kind in kinds: out[str(key) % str(kind)] = float(out.get(str(key) % str(kind), 0.0)) + value
		else:
			out[str(key)] = value
	return out

static func stats_of(item: Item) -> Dictionary:
	if item == null or item.inlay.is_empty() or not has_slot(item): return {}
	return stats_for(str(item.inlay.get("id", "")), int(item.inlay.get("tier", 0)), item.inlay.get("kinds", []))

## Points for resistances, a share otherwise.
const POINT_KEYS := ["res", "res_bleed", "res_all_elem", "res_cap", "res_burn", "res_cold", "res_corr", "res_nerve"]
const KIND_NAMES := {"burn": "灼燃", "cold": "寒冷", "corr": "侵蚀", "nerve": "神经", "necro": "凋亡"}

static func value_text(key: String, value: float) -> String:
	if key in POINT_KEYS: return "%+d" % roundi(value)
	var pct := value * 100.0
	var shown := ("%+.0f%%" if absf(pct - roundf(pct)) < 0.05 else "%+.1f%%") % pct
	return shown.replace("-", "−")

## "灼燃抗性 +20", "双元素抗性 灼燃 +12 · 寒冷 +12", "防御 +6%".
static func describe(id: String, tier: int, kinds: Array) -> String:
	var e := entry(id)
	if e.is_empty(): return ""
	var mult: float = TIER_MULT[clampi(tier, 0, 3)]
	var parts: Array = []
	for key in e.stats:
		var value := float(e.stats[key]) * mult
		if str(key).contains("%s"):
			for kind in kinds:
				var label := str(KIND_NAMES.get(kind, kind)) + ("抗性" if str(key).begins_with("res_") else "伤害")
				parts.append("%s %s" % [label, value_text(str(key) % str(kind), value)])
		else:
			parts.append("%s %s" % [str(e.name), value_text(str(key), value)])
	return " · ".join(parts)

## The item's line on its hover card ("" without one).
static func line(item: Item) -> String:
	if item == null or item.inlay.is_empty(): return ""
	return "镶嵌：" + describe(str(item.inlay.get("id", "")), int(item.inlay.get("tier", 0)), item.inlay.get("kinds", []))

## The materials and 龙门币 one setting costs.
static func materials(id: String, tier: int) -> Dictionary:
	var lineup: Array = LINES[str(entry(id).group)]
	match tier:
		0: return {lineup[0]: 3}
		1: return {lineup[1]: 3}
		2: return {lineup[2]: 2, lineup[1]: 2}
		_: return {SPECIAL_MATERIAL: 1, lineup[2]: 2}

static func price(tier: int) -> int:
	return int(TIER_LMD[clampi(tier, 0, 3)])

## The research a tier needs (初级 none).
static func tier_key(tier: int) -> String:
	return "" if tier <= 0 else ("inlay_mid" if tier == 1 else "inlay_high")

# --- The diamond in a cell's corner (§7.1), drawn in code -----------------------------

const MARK_EMPTY := Color(0.62, 0.66, 0.68, 0.9)

## Its fill: none for an empty slot, the element colour(s), or white.
static func mark_colours(item: Item) -> Array:
	if item == null or item.inlay.is_empty(): return []
	var id := str(item.inlay.get("id", ""))
	var kinds: Array = item.inlay.get("kinds", [])
	if id in ["res_one", "res_two", "elem_dmg"] and not kinds.is_empty():
		return kinds.map(func(k): return Elements.COLORS.get(k, Color.WHITE))
	if id == "res_bleed": return [Elements.COLORS.bleed]
	return [Color.WHITE]

## Draws it at `centre` (half-diagonal `r`) on `control`.
static func draw_mark(control: Control, item: Item, centre: Vector2, r: float = 4.5) -> void:
	if not has_slot(item): return
	var top := centre + Vector2(0, -r)
	var right := centre + Vector2(r, 0)
	var bottom := centre + Vector2(0, r)
	var left := centre + Vector2(-r, 0)
	var colours := mark_colours(item)
	if colours.is_empty():
		control.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), MARK_EMPTY, 1.0, true)
		return
	if colours.size() >= 2:
		control.draw_colored_polygon(PackedVector2Array([top, bottom, left]), colours[0])
		control.draw_colored_polygon(PackedVector2Array([top, right, bottom]), colours[1])
	else:
		control.draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), colours[0])
	control.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0, 0, 0, 0.7), 1.0, true)
