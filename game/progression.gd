class_name Progression
extends RefCounted

## Operator growth rules (精英化与加点策划案_v0_2.md): 明日方舟's 精英化 is the
## gate (level caps, which tier of the tree opens, which gear grades she may
## wear), Grim Dawn's attribute points shape her body, the skill tree (see
## SkillTrees) shapes how she fights. Numbers only — the state lives in
## OperatorProgress, one per operator, kept by BaseState.

# --- Levels (§3.1): PRTS 50 / 70 / 80 divided by five ----------------------------
const LEVEL_CAPS := [10, 14, 16]
const ELITE_NAMES := ["精英 0", "精英 1", "精英 2"]
## Each promotion also hands out these (§3.1).
const PROMOTION_ATTRIBUTE_POINTS := 2
const PROMOTION_SKILL_POINTS := 2

## Experience to go from `level` to `level + 1` at `elite` (§4.1).
static func exp_to_next(elite: int, level: int) -> int:
	match elite:
		0: return 300 + 50 * (level - 1)
		1: return 800 + 100 * (level - 1)
	return 1600 + 150 * (level - 1)

# --- Kills (§4.2) -------------------------------------------------------------
const KILL_EXP := {"normal": 8, "elite": 50, "leader": 120, "boss": 300}
## Every ten-floor block below the first adds this share.
const KILL_EXP_PER_BLOCK := 0.25

static func block(floor_number: int) -> int:
	return maxi(0, (floor_number - 1) / 10)

static func kill_exp(kind: String, floor_number: int) -> int:
	return roundi(float(KILL_EXP.get(kind, 0)) * (1.0 + KILL_EXP_PER_BLOCK * block(floor_number)))

# --- 作战记录 (§4.2): counters at the base, never items -----------------------
const RECORDS := ["基础作战记录", "初级作战记录", "中级作战记录", "高级作战记录"]
const RECORD_EXP := {"基础作战记录": 100, "初级作战记录": 200, "中级作战记录": 500, "高级作战记录": 1000}
const RECORD_STAR := {"基础作战记录": 2, "初级作战记录": 3, "中级作战记录": 4, "高级作战记录": 5}
## How many ordinary kills make one basic record (零头作废).
const NORMALS_PER_RECORD := 10
const LMD_PER_EXP := 0.5

## What a contract's kills pay out: {record name: count}.
static func records_for(kills: Dictionary) -> Dictionary:
	var out := {}
	var basic := int(kills.get("normal", 0)) / NORMALS_PER_RECORD
	if basic > 0: out["基础作战记录"] = basic
	if int(kills.get("elite", 0)) > 0: out["初级作战记录"] = int(kills.elite)
	if int(kills.get("leader", 0)) > 0: out["中级作战记录"] = int(kills.leader)
	if int(kills.get("boss", 0)) > 0: out["高级作战记录"] = int(kills.boss)
	return out

# --- Promotion (§3.2): PRTS 拉普兰德's recipe, 龙门币 × 0.3 ---------------------
const PROMOTION := [
	{},
	{"lmd": 6000, "materials": {"近卫芯片": 4, "装置": 3, "固源岩": 4}},
	{"lmd": 36000, "materials": {"近卫双芯片": 3, "改量装置": 6, "异铁组": 10}},
]
## PRTS 10 → 15 at 精英 2.
const E2_RES := 5.0

# --- Attributes (§5) ---------------------------------------------------------
const ATTRIBUTES := ["phy", "tec", "agi", "arts"]
const ATTRIBUTE_NAMES := {"phy": "体魄", "tec": "技巧", "agi": "敏捷", "arts": "源石技艺"}
## What one point adds, in CombatStats keys.
const PER_POINT := {
	"phy": {"hp": 24.0, "def": 2.0, "regen": 0.5},
	"tec": {"atk": 5.0, "crit": 0.002, "crit_dmg": 0.01},
	"agi": {"aspd": 0.6, "stamina_regen": 0.1, "move_pct": 0.002},
	"arts": {"arts": 4.0, "arts_dmg_pct": 0.005, "res": 0.3},
}
## The starting forty points are the existing base stats; bonuses count up from here.
const START := {
	"lappland": {"phy": 10, "tec": 12, "agi": 10, "arts": 8},
	"amiya_guard": {"phy": 10, "tec": 10, "agi": 8, "arts": 12},
}

static func start_attributes(operator_id: String) -> Dictionary:
	return (START.get(operator_id, START.lappland) as Dictionary).duplicate()

## The stat sheet of the points above the start.
static func attribute_sheet(attributes: Dictionary, start: Dictionary) -> Dictionary:
	var sheet := {}
	for key in ATTRIBUTES:
		var extra := int(attributes.get(key, 0)) - int(start.get(key, 0))
		if extra <= 0: continue
		for stat in PER_POINT[key]:
			sheet[stat] = float(sheet.get(stat, 0.0)) + float(PER_POINT[key][stat]) * extra
	return sheet

# --- Respec (§10) --------------------------------------------------------------
static func respec_cost(points: int, elite: int) -> int:
	return points * 200 * (elite + 1)

# --- Gear grades and requirements (§7) --------------------------------------
const GRADE_MAX := 6
const GRADE_MARKS := ["", "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ"]
## Per grade T1..T6 (index 1..6).
const REQ_ELITE := [0, 0, 0, 0, 1, 1, 2]
const REQ_TABLE := {
	"light": [0, 0, 12, 16, 22, 30, 40],
	"heavy": [0, 0, 12, 18, 25, 33, 43],
	"gear": [0, 0, 11, 14, 19, 24, 30],
	"heavy_armor": [0, 0, 12, 18, 25, 33, 43],
}

## Base layer (0 浅 / 1 中 / 2 深) + ten-floor block, capped at T6.
static func grade_for(tier: int, floor_number: int, bonus: int = 0) -> int:
	return clampi(tier + 1 + mini(2, block(floor_number)) + bonus, 1, GRADE_MAX)

const FORM_ATTRIBUTE := {"blade": "tec", "heavy": "phy", "fist": "agi", "polearm": "tec"}
const FORM_COLUMN := {"blade": "light", "heavy": "heavy", "fist": "light", "polearm": "heavy"}
const STAT_ATTRIBUTE := {
	ItemModifier.Stat.MAX_HP_PCT: "phy", ItemModifier.Stat.DEF_FLAT: "phy",
	ItemModifier.Stat.ATK_PCT: "tec", ItemModifier.Stat.CRIT_RATE: "tec", ItemModifier.Stat.CRIT_DMG: "tec",
	ItemModifier.Stat.ATTACK_SPEED_PCT: "agi", ItemModifier.Stat.MOVE_SPEED_PCT: "agi",
	ItemModifier.Stat.ARTS_PCT: "arts", ItemModifier.Stat.RES_FLAT: "arts",
}

## {"grade", "elite", "attribute", "value"} for a piece of gear; an empty
## Dictionary when it asks nothing (materials, legacy gear without a grade).
static func requirement(item: Item) -> Dictionary:
	if item == null or not item.is_equippable() or item.grade <= 0: return {}
	var attribute := ""
	var column := "gear"
	var data: Dictionary = {}
	if not item.special.is_empty(): data = SpecialGear.GEAR.get(item.special, {})
	elif not item.base_id.is_empty(): data = GearCatalog.base(item.base_id)
	if data.has("req"):
		attribute = str(data.req)
		column = str(data.get("req_column", "gear" if item.category != Item.Category.WEAPON else "light"))
	elif item.category == Item.Category.WEAPON:
		var form := str(data.get("form", "blade"))
		attribute = FORM_ATTRIBUTE.get(form, "tec")
		column = FORM_COLUMN.get(form, "light")
	else:
		var implicit: Array = data.get("implicit", [])
		var heavy := false
		for pair in implicit:
			if int(pair[0]) == ItemModifier.Stat.MOVE_SPEED_PCT and float(pair[1]) < 0.0: heavy = true
		if heavy or bool(data.get("heavy", false)):
			attribute = "phy"
			column = "heavy_armor"
		else:
			for pair in implicit:
				if STAT_ATTRIBUTE.has(int(pair[0])):
					attribute = STAT_ATTRIBUTE[int(pair[0])]
					break
			if attribute.is_empty(): attribute = "phy" if item.category == Item.Category.ARMOR else "tec"
	var grade := clampi(item.grade, 1, GRADE_MAX)
	return {"grade": grade, "elite": REQ_ELITE[grade], "attribute": attribute, "value": int(REQ_TABLE[column][grade])}

## Why `progress` cannot wear `item`, or "" when she can.
static func refusal(item: Item, progress: OperatorProgress) -> String:
	var req := requirement(item)
	if req.is_empty() or progress == null: return ""
	if progress.elite < int(req.elite): return "需要%s" % ELITE_NAMES[int(req.elite)]
	if int(req.value) > 0 and progress.attribute(str(req.attribute)) < int(req.value):
		return "需要%s %d" % [ATTRIBUTE_NAMES[req.attribute], int(req.value)]
	return ""

## For gear saved before grades existed: its layer, and the depth its power
## suggests (power = (1 + 0.3·depth + roll) × quality × base factor).
static func backfill_grade(item: Item) -> void:
	if item.grade > 0 or not item.is_equippable(): return
	var tier := -1
	var factor := 1.0
	if not item.special.is_empty():
		tier = 2
	elif not item.base_id.is_empty():
		var b := GearCatalog.base(item.base_id)
		tier = int(b.get("tier", 0))
		factor = float(b.get("factor", 1.0))
	if tier < 0: return
	var depth := 1.0
	if item.special.is_empty():
		depth = maxf(1.0, (item.power / maxf(0.1, (1.0 + item.rarity * 0.3) * factor) - 1.5) / 0.3)
	item.grade = grade_for(tier, roundi(depth))
