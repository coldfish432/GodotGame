class_name Progression
extends RefCounted

## Operator growth rules (精英化与加点策划案_v0_2.md): 明日方舟's 精英化 is the
## gate (level caps, which tier of the tree opens, which gear grades she may
## wear), Grim Dawn's attribute points shape her body, the skill tree (see
## SkillTrees) shapes how she fights. Numbers only — the state lives in
## OperatorProgress, one per operator, kept by BaseState.

# --- Levels (复利数值改造清单 J, 用户 2026-10-20) -------------------------------
## 精英 0 to 60, then 1 again; 精英 1 to 80, then 1 again; 精英 2 to 90. A skill
## point every level, an attribute point every second level (the even ones).
const LEVEL_CAPS := [60, 80, 90]
const OLD_LEVEL_CAPS := [10, 14, 16]
const ATTRIBUTE_EVERY := 2
## Experience: the n-th level-up of her whole career (n = 1…227, across the
## promotions) needs EXP_A × (1 + n / 25); 315,530 in all.
const EXP_A := 250.0
const EXP_SLOPE := 25.0
const ELITE_NAMES := ["精英 0", "精英 1", "精英 2"]
## Each promotion also hands out these (§3.1).
const PROMOTION_ATTRIBUTE_POINTS := 2
const PROMOTION_SKILL_POINTS := 2

## Level-ups before this stage's first one.
static func levels_before(elite: int) -> int:
	var total := 0
	for e in range(clampi(elite, 0, 2)): total += LEVEL_CAPS[e] - 1
	return total

## Experience to go from `level` to `level + 1` at `elite`.
static func exp_to_next(elite: int, level: int) -> int:
	var n := levels_before(elite) + level
	return roundi(EXP_A * (1.0 + float(n) / EXP_SLOPE))

## Attribute points the levels up to `level` at `elite` have given (promotions apart).
static func level_attribute_points(elite: int, level: int) -> int:
	var total := 0
	for e in range(clampi(elite, 0, 2)): total += (LEVEL_CAPS[e]) / ATTRIBUTE_EVERY
	return total + level / ATTRIBUTE_EVERY

## Skill points the same levels have given.
static func level_skill_points(elite: int, level: int) -> int:
	return levels_before(elite) + level - 1

# --- Kills (§4.2) -------------------------------------------------------------
const KILL_EXP := {"normal": 8, "elite": 50, "leader": 120, "boss": 300, "region_boss": 300}
## Every ten-floor block below the first adds this share.
const KILL_EXP_PER_BLOCK := 0.25

static func block(floor_number: int) -> int:
	return maxi(0, (floor_number - 1) / 10)

static func kill_exp(kind: String, floor_number: int) -> int:
	return roundi(float(KILL_EXP.get(kind, 0)) * (1.0 + KILL_EXP_PER_BLOCK * block(floor_number)))

## A region boss or warden of `tier` (BossCatalog.EXP), with the same block share.
static func boss_exp(rank: String, tier: int, floor_number: int) -> int:
	return roundi(float(BossCatalog.kill_exp(rank, tier)) * (1.0 + KILL_EXP_PER_BLOCK * block(floor_number)))

# --- 作战记录 (§4.2): counters at the base, never items -----------------------
const RECORDS := ["基础作战记录", "初级作战记录", "中级作战记录", "高级作战记录"]
const RECORD_EXP := {"基础作战记录": 100, "初级作战记录": 200, "中级作战记录": 500, "高级作战记录": 1000}
const RECORD_STAR := {"基础作战记录": 2, "初级作战记录": 3, "中级作战记录": 4, "高级作战记录": 5}
## How many ordinary kills make one basic record (零头作废).
const NORMALS_PER_RECORD := 10
const LMD_PER_EXP := 1.4

## What a contract's kills pay out: {record name: count}.
static func records_for(kills: Dictionary) -> Dictionary:
	var out := {}
	var basic := int(kills.get("normal", 0)) / NORMALS_PER_RECORD
	if basic > 0: out["基础作战记录"] = basic
	if int(kills.get("elite", 0)) > 0: out["初级作战记录"] = int(kills.elite)
	if int(kills.get("leader", 0)) > 0: out["中级作战记录"] = int(kills.leader)
	var top := int(kills.get("boss", 0)) + int(kills.get("region_boss", 0))
	if top > 0: out["高级作战记录"] = top
	return out

# --- Promotion (§3.2): PRTS 拉普兰德's recipe; 龙门币 raised in 龙门币平衡与科研部策划案 v1.1 §4.2 --
const PROMOTION := [
	{},
	{"lmd": 22000, "materials": {"近卫芯片": 4, "装置": 3, "固源岩": 4}},
	{"lmd": 168000, "materials": {"近卫双芯片": 3, "改量装置": 6, "异铁组": 10}},
]
## PRTS 10 → 15 at 精英 2.
const E2_RES := 5.0

# --- Attributes (§5) ---------------------------------------------------------
const ATTRIBUTES := ["phy", "tec", "agi", "arts"]
const ATTRIBUTE_NAMES := {"phy": "体魄", "tec": "技巧", "agi": "敏捷", "arts": "源石技艺"}
## What one point adds, in CombatStats keys (复利数值改造清单 J: shares now, and
## 41/119 of the old point, so 119 points give what 41 did). 体魄's regeneration
## is tier Ⅰ, × the floor's 档位系数 (Player.bonus_regen).
const PER_POINT := {
	"phy": {"hp_pct": 0.0035, "def_pct": 0.0035, "regen": 0.17},
	"tec": {"atk_pct": 0.0028, "crit": 0.0007, "crit_dmg": 0.0035},
	"agi": {"aspd": 0.2, "stamina_regen": 0.035, "move_pct": 0.0007},
	"arts": {"arts_pct": 0.0038, "arts_dmg_pct": 0.0017, "res": 0.1},
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
	return points * 560 * (elite + 1)

# --- Gear grades and requirements (§7) --------------------------------------
## Grades are the ten-floor tiers Ⅰ–Ⅹ (复利数值改造清单 B, Scaling.tier_of).
const GRADE_MAX := 10
const GRADE_MARKS := ["", "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ"]
## Per tier Ⅰ..Ⅹ (index 1..10). 精英 1 lands near floor 18 and 精英 2 near floor
## 40 (tools/economy_model.py), so tiers Ⅲ–Ⅳ ask 精英 1 and Ⅴ on 精英 2.
const REQ_ELITE := [0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 2]
## Finer points (119 over a career) let each kind ask its own (清单 J): heavy
## pieces climb toward half of a specialised build, light ones a third.
const REQ_TABLE := {
	"light": [0, 0, 16, 21, 28, 34, 40, 45, 48, 51, 54],
	"heavy": [0, 0, 18, 25, 34, 42, 50, 56, 60, 64, 68],
	"gear": [0, 0, 14, 18, 23, 28, 32, 36, 39, 42, 45],
	"heavy_armor": [0, 0, 18, 25, 34, 42, 50, 56, 60, 64, 68],
}

## The tier of a piece found on `floor_number` (the base layer only decides
## which bases drop there now), `bonus` tiers higher.
static func grade_for(_tier: int, floor_number: int, bonus: int = 0) -> int:
	return clampi(Scaling.tier_of(floor_number) + bonus, 1, GRADE_MAX)

const FORM_ATTRIBUTE := {"blade": "tec", "heavy": "phy", "fist": "agi", "polearm": "tec"}
const FORM_COLUMN := {"blade": "light", "heavy": "heavy", "fist": "light", "polearm": "heavy"}
const STAT_ATTRIBUTE := {
	ItemModifier.Stat.MAX_HP_PCT: "phy", ItemModifier.Stat.DEF_FLAT: "phy",
	ItemModifier.Stat.ATK_PCT: "tec", ItemModifier.Stat.CRIT_RATE: "tec", ItemModifier.Stat.CRIT_DMG: "tec",
	ItemModifier.Stat.ATTACK_SPEED_PCT: "agi", ItemModifier.Stat.MOVE_SPEED_PCT: "agi",
	ItemModifier.Stat.ARTS_PCT: "arts", ItemModifier.Stat.RES_FLAT: "arts",
	ItemModifier.Stat.HP_FLAT: "phy", ItemModifier.Stat.ATK_FLAT: "tec", ItemModifier.Stat.ARTS_FLAT: "arts",
	ItemModifier.Stat.EVASION: "agi", ItemModifier.Stat.SKILL_CD_PCT: "arts", ItemModifier.Stat.SKILL_PCT: "arts",
	ItemModifier.Stat.STAMINA_REGEN_PCT: "agi", ItemModifier.Stat.DASH_COST_PCT: "agi",
	ItemModifier.Stat.GOLD_GAIN_PCT: "tec", ItemModifier.Stat.DROP_RATE_PCT: "tec", ItemModifier.Stat.EXP_GAIN_PCT: "arts",
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
		# 装备部位拆分与数值案 §9: chest and legs ask the heavy column, head,
		# hands and feet the light one, amulet and ring the trinket one; a heavy
		# piece (slows her) always asks 体魄 on the heavy column.
		var implicit: Array = data.get("implicit", [])
		var heavy := false
		for pair in implicit:
			if int(pair[0]) == ItemModifier.Stat.MOVE_SPEED_PCT and float(pair[1]) < 0.0: heavy = true
		column = str(GearSlots.REQ_COLUMN.get(Item.slot_of(item.category), "gear"))
		if heavy or bool(data.get("heavy", false)):
			attribute = "phy"
			column = "heavy_armor"
		else:
			for pair in implicit:
				if STAT_ATTRIBUTE.has(int(pair[0])):
					attribute = STAT_ATTRIBUTE[int(pair[0])]
					break
			if attribute.is_empty(): attribute = "phy" if Item.is_armor_slot(item.category) else "tec"
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

## For gear saved before grades existed: the depth its power suggests under the
## old formula (power = (1.5 + 0.3·depth) × (1 + 0.3·rarity) × base factor), as
## a tier.
static func backfill_grade(item: Item) -> void:
	if item.grade > 0 or not item.is_equippable(): return
	if item.special.is_empty() and item.base_id.is_empty(): return
	var factor := float(GearCatalog.base(item.base_id).get("factor", 1.0)) if not item.base_id.is_empty() else 1.0
	var depth := 1.0
	if item.special.is_empty():
		depth = maxf(1.0, (item.power / maxf(0.1, (1.0 + item.rarity * 0.3) * factor) - 1.5) / 0.3)
	item.grade = grade_for(0, roundi(depth))
