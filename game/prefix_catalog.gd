class_name PrefixCatalog
extends RefCounted

## Named prefixes (装备前缀策划案_v1_1.md): a Terraria-style package of stats
## written into the item's name, "致命的·狂暴的·断镐战斧". Every piece of gear
## except set pieces rolls one, sometimes two (§2.3). Each stat line rolls
## within 80–120% of the table value (§2.8); an item keeps the multiplier per
## line ("rolls"), so ranges and refreshes work from the table.
##
## stats: keys added straight into the player's sheet (CombatStats.KEYS).
## fx: conditional effects read by Player (fx_* below), summed like relic fx.
## No prefix deals damage of its own: attack effects belong to special gear.

const W := "W"
const A := "A"
const T := "T"

## Grade odds for every prefix rolled, −2 to +2 (§0.1-11).
const GRADE_WEIGHTS := {-2: 15.0, -1: 20.0, 0: 30.0, 1: 30.0, 2: 5.0}
## Past the loot stair's top floor (LootTables.past_top, 0–1) each grade's
## weight is × (1 + shift × it): the bad ones fade, +1 doubles, +2 grows 5×
## — at ½ (floor 130) 7.5 / 13 / 30 / 45 / 15 (用户 2026-10-18).
const GOOD_SHIFT := {-2: -1.0, -1: -0.7, 0: 0.0, 1: 1.0, 2: 4.0}
const DOUBLE_CHANCE := 0.2
## The share of prefix rolls that are an effect family's (前缀放大与特效阶等案 §3).
const FAMILY_SHARE := 0.15
## Stat prefixes as players see them (前缀放大与特效阶等案 §2, 用户 2026-10-21):
## the table is the small pieces' size; weapons and the big pieces more.
const WEAPON_SCALE := 1.6
const BIG_SCALE := 1.5
const BIG_SLOTS := [Item.Category.CHEST, Item.Category.AMULET]
## A region's own prefixes are this much likelier there (§0.1-7).
const REGION_WEIGHT := 3.0
## The top prefixes count as +2 but are rarer and open later (§2.2).
const TOP_WEIGHT := 0.25
const TOP_DEPTH := 3
## Reforging may roll them on any tier now (grades are ten-floor tiers, 清单 B;
## a drop opens them from TOP_DEPTH).
const TOP_GRADE := 1
const ROLL_LOW := 0.8
const ROLL_HIGH := 1.2

## Prefix text colours by grade (§0.2-3); the item's own colour is untouched.
const GRADE_COLORS := {-2: Color("7d858c"), -1: Color("eef1f3"), 0: Color("6fcf7f"), 1: Color("5aa9ff"), 2: Color("f3b04a")}
const DOT_COLOR := Color("6d6d6d")

## Stats where a smaller number is the better one (for value and positions).
const LOWER_BETTER := ["taken_pct", "contam_pct", "pressure_pct", "skill_cd_pct", "dash_cd_pct", "dash_cost_pct"]
## Flat stats; everything else is a fraction shown as a percentage.
const FLAT := ["aspd", "def", "res"]
const LABELS := {
	"atk_pct": "攻击力", "aspd": "攻速", "crit": "暴击率", "crit_dmg": "暴击伤害", "move_pct": "移速",
	"hp_pct": "生命上限", "def": "防御", "res": "法抗", "arts_pct": "法术攻击力", "reach_pct": "攻击范围",
	"def_ignore": "攻击无视防御", "lifesteal": "吸血", "evasion": "物理闪避", "evasion_arts": "法术闪避",
	"evasion_melee": "近战闪避", "evasion_ranged": "远程闪避", "dmg_reduce": "整体减伤", "elite_pct": "对精英伤害",
	"skill_pct": "技能伤害", "skill_cd_pct": "技能冷却", "dash_cd_pct": "闪避冷却", "dash_cost_pct": "闪避体力",
	"stamina_regen_pct": "体力回复", "heal_pct": "受到治疗", "gold_pct": "赤金获取", "pressure_pct": "威胁累积",
	"contam_pct": "污染累积", "taken_pct": "受到伤害",
}
## 诡意: what its stats are drawn from (PrefixFamilies scales them by 阶等).
const FICKLE := {"atk_pct": 0.12, "aspd": 15.0, "crit": 0.075, "arts_pct": 0.15, "move_pct": 0.12}
## Effect lines a prefix's fx would print; the old ones moved into families.
const FX_TEXT := {}

static var _table: Dictionary = {}

## id → {name, en, grade, slots, stats, fx, form, region, group, value, top}.
static func all() -> Dictionary:
	if _table.is_empty(): _build()
	return _table

static func get_entry(id: String) -> Dictionary:
	return all().get(id, {})

static func _p(id: String, grade: int, slots: String, name: String, en: String, stats: Dictionary, extra: Dictionary = {}) -> void:
	var entry := {"name": name, "en": en, "grade": grade, "slots": slots, "stats": stats,
		"fx": extra.get("fx", {}), "form": extra.get("form", ""), "region": extra.get("region", ""),
		"group": extra.get("group", "reach" if stats.has("reach_pct") else ""),
		"value": float(extra.get("value", 1.0)), "top": bool(extra.get("top", false)), "family": extra.get("family", "")}
	_table[id] = entry

static func _build() -> void:
	# --- §3.1 武器通用 ----------------------------------------------------------
	_p("godly", 2, W, "神级的", "Godly", {"atk_pct": 0.06, "crit": 0.03, "crit_dmg": 0.10})
	_p("demonic", 2, W, "恶魔的", "Demonic", {"atk_pct": 0.08, "crit": 0.03})
	_p("murderous", 2, W, "凶残的", "Murderous", {"atk_pct": 0.04, "aspd": 5.0, "crit": 0.02})
	_p("deadly", 2, W, "致命的", "Deadly", {"atk_pct": 0.06, "aspd": 6.0})
	_p("sharp", 1, W, "锋利的", "Sharp", {"atk_pct": 0.07})
	_p("agile", 1, W, "灵巧的", "Agile", {"aspd": 6.0, "crit": 0.02})
	_p("quick", 1, W, "迅捷的", "Quick", {"aspd": 8.0})
	_p("ruthless", 1, W, "无情的", "Ruthless", {"atk_pct": 0.10, "aspd": -4.0})
	_p("zealous", 1, W, "狂热的", "Zealous", {"crit_dmg": 0.15})
	_p("keen", 1, W, "锐利的", "Keen", {"crit": 0.03})
	_p("frenzying", 0, W, "狂暴的", "Frenzying", {"atk_pct": -0.08, "aspd": 12.0})
	_p("powerful", 0, W, "厚重的", "Powerful", {"atk_pct": 0.10, "aspd": -8.0})
	_p("reckless", 0, W, "莽撞的", "Reckless", {"crit_dmg": 0.20, "crit": -0.03})
	_p("parrying", 0, W, "招架的", "Parrying", {"evasion_melee": 0.06, "aspd": -6.0})
	_p("damaged", -1, W, "损坏的", "Damaged", {"atk_pct": -0.06})
	_p("slow", -1, W, "迟缓的", "Slow", {"aspd": -8.0})
	_p("inaccurate", -1, W, "失准的", "Inaccurate", {"crit": -0.03})
	_p("broken", -2, W, "破损的", "Broken", {"atk_pct": -0.12, "aspd": -5.0})
	_p("annoying", -2, W, "恼人的", "Annoying", {"atk_pct": -0.08, "aspd": -6.0})
	_p("weak", -2, W, "无力的", "Weak", {"atk_pct": -0.08, "crit_dmg": -0.10})
	_p("shoddy", -2, W, "粗劣的", "Shoddy", {"atk_pct": -0.06, "crit": -0.03})
	_p("legendary", 2, W, "传奇的", "Legendary", {"atk_pct": 0.08, "aspd": 6.0, "crit": 0.03, "reach_pct": 0.06}, {"top": true})
	# --- §3.2 武器形制 ----------------------------------------------------------
	_p("savage", 2, W, "野蛮的", "Savage", {"atk_pct": 0.05, "reach_pct": 0.10}, {"form": "blade"})
	_p("large", 1, W, "修长的", "Large", {"reach_pct": 0.10}, {"form": "blade"})
	_p("small", -1, W, "短小的", "Small", {"reach_pct": -0.10}, {"form": "blade"})
	_p("dull", -1, W, "卷刃的", "Dull", {"atk_pct": -0.05, "crit": -0.02}, {"form": "blade"})
	_p("massive", 2, W, "巨型的", "Massive", {"reach_pct": 0.12, "atk_pct": 0.03}, {"form": "heavy"})
	_p("bulky", 1, W, "笨重的", "Bulky", {"atk_pct": 0.08, "reach_pct": 0.08, "aspd": -10.0}, {"form": "heavy"})
	_p("unhappy", -2, W, "沉坠的", "Sagging", {"aspd": -8.0, "reach_pct": -0.08}, {"form": "heavy"})
	_p("gale", 2, W, "疾风的", "Gale", {"aspd": 10.0, "move_pct": 0.04}, {"form": "fist"})
	_p("light", 0, W, "轻盈的", "Light", {"aspd": 10.0, "reach_pct": -0.05}, {"form": "fist"})
	_p("stiff", -1, W, "僵硬的", "Stiff", {"aspd": -8.0}, {"form": "fist"})
	_p("farreach", 2, W, "远击的", "Far-Reaching", {"reach_pct": 0.12, "crit": 0.02}, {"form": "polearm"})
	_p("sweeping", 0, W, "回旋的", "Sweeping", {"reach_pct": 0.10, "aspd": -6.0}, {"form": "polearm"})
	_p("stubby", -1, W, "短柄的", "Stubby", {"reach_pct": -0.10}, {"form": "polearm"})
	# --- §3.3 防具通用 ----------------------------------------------------------
	_p("warding", 2, A, "铁卫的", "Warding", {"def": 40.0, "hp_pct": 0.04})
	_p("bulwark", 2, A, "铁壁的", "Bulwark", {"def": 30.0, "res": 6.0})
	_p("steadfast", 2, A, "坚忍的", "Steadfast", {"dmg_reduce": 0.06, "def": 20.0})
	_p("armored", 1, A, "加固的", "Armored", {"def": 30.0})
	_p("sturdy", 1, A, "厚实的", "Sturdy", {"hp_pct": 0.06})
	_p("insulated", 1, A, "绝缘的", "Insulated", {"res": 6.0})
	_p("nimble", 1, A, "灵动的", "Nimble", {"evasion": 0.04})
	_p("spellward", 1, A, "避咒的", "Spellwarding", {"evasion_arts": 0.04})
	_p("closeguard", 1, A, "贴身的", "Close-Guarding", {"evasion_melee": 0.05})
	_p("lowprofile", 1, A, "低伏的", "Low-Profile", {"evasion_ranged": 0.07})
	_p("stable", 1, A, "稳固的", "Stable", {"dmg_reduce": 0.04})
	_p("lightweight", 0, A, "轻便的", "Lightweight", {"move_pct": 0.05, "def": -10.0})
	_p("bloated", 0, A, "臃肿的", "Bloated", {"hp_pct": 0.08, "move_pct": -0.05})
	_p("studded", 0, A, "镶钉的", "Studded", {"def": 30.0, "move_pct": -0.04})
	_p("flimsy", 0, A, "单薄的", "Flimsy", {"move_pct": 0.06, "hp_pct": -0.04})
	_p("sidestep", 0, A, "闪身的", "Sidestepping", {"evasion": 0.06, "def": -30.0})
	_p("worn", -1, A, "磨损的", "Worn", {"def": -20.0, "hp_pct": -0.03})
	_p("drafty", -1, A, "漏风的", "Drafty", {"res": -5.0})
	_p("loose", -1, A, "松垮的", "Loose", {"move_pct": -0.05})
	_p("exposed", -1, A, "破绽的", "Exposed", {"dmg_reduce": -0.04})
	_p("tattered", -2, A, "破烂的", "Tattered", {"def": -40.0, "hp_pct": -0.04})
	_p("rotten", -2, A, "腐朽的", "Rotten", {"res": -7.0, "hp_pct": -0.04})
	_p("immortal", 2, A, "不朽的", "Immortal", {"def": 40.0, "hp_pct": 0.06, "res": 6.0}, {"top": true})
	# --- §3.4 饰品通用 ----------------------------------------------------------
	_p("spiked", 1, T, "尖刺的", "Spiked", {"atk_pct": 0.05})
	_p("menacing", 2, T, "凶恶的", "Menacing", {"atk_pct": 0.11})
	_p("precise", 1, T, "精准的", "Precise", {"crit": 0.03})
	_p("lucky", 2, T, "幸运的", "Lucky", {"crit": 0.07})
	_p("rash", 1, T, "鲁莽的", "Rash", {"aspd": 6.0})
	_p("violent", 2, T, "暴烈的", "Violent", {"aspd": 13.0})
	_p("brisk", 1, T, "轻快的", "Brisk", {"move_pct": 0.05})
	_p("swift", 2, T, "疾速的", "Swift", {"move_pct": 0.11})
	_p("hard", 1, T, "坚硬的", "Hard", {"def": 25.0})
	_p("guarded", 2, T, "护佑的", "Guarded", {"def": 55.0})
	_p("lucid", 1, T, "清明的", "Lucid", {"res": 5.0})
	_p("clear", 2, T, "澄澈的", "Clear", {"res": 11.0})
	_p("glimmer", 1, T, "灵光的", "Glimmering", {"arts_pct": 0.06})
	_p("arcane", 2, T, "奥术的", "Arcane", {"arts_pct": 0.13})
	_p("hale", 1, T, "健壮的", "Hale", {"hp_pct": 0.05})
	_p("tough", 2, T, "强韧的", "Tough", {"hp_pct": 0.11})
	_p("focused", 1, T, "专注的", "Focused", {"skill_pct": 0.15})
	_p("masterful", 2, T, "精通的", "Masterful", {"skill_pct": 0.35})
	_p("quickwit", 1, T, "敏思的", "Quick-Witted", {"skill_cd_pct": -0.08})
	_p("flowing", 2, T, "心流的", "Flowing", {"skill_cd_pct": -0.16})
	_p("deft", 1, T, "敏捷的", "Deft", {"evasion": 0.03})
	_p("shadowstep", 2, T, "迅影的", "Shadowstepping", {"evasion": 0.07})
	_p("hexward", 1, T, "辟邪的", "Hexwarding", {"evasion_arts": 0.03})
	_p("spellbreak", 2, T, "破咒的", "Spellbreaking", {"evasion_arts": 0.07})
	_p("alert", 1, T, "机敏的", "Alert", {"evasion_melee": 0.04})
	_p("traceless", 2, T, "无影的", "Traceless", {"evasion_melee": 0.08})
	_p("wary", 1, T, "警觉的", "Wary", {"evasion_ranged": 0.05})
	_p("insightful", 2, T, "洞察的", "Insightful", {"evasion_ranged": 0.11})
	_p("sheltered", 1, T, "庇护的", "Sheltered", {"dmg_reduce": 0.04})
	_p("blessed", 2, T, "圣佑的", "Blessed", {"dmg_reduce": 0.08})
	_p("restless", 0, T, "躁动的", "Restless", {"aspd": 10.0, "arts_pct": -0.06})
	_p("allin", 0, T, "孤注的", "All-In", {"crit_dmg": 0.20, "hp_pct": -0.05})
	_p("dim", -1, T, "黯淡的", "Dim", {"arts_pct": -0.07})
	_p("sluggish", -1, T, "迟钝的", "Sluggish", {"aspd": -7.0})
	_p("fragile", -1, T, "脆弱的", "Fragile", {"hp_pct": -0.06})
	_p("murky", -1, T, "浑浊的", "Murky", {"res": -5.0})
	_p("absent", -1, T, "走神的", "Absent-Minded", {"skill_cd_pct": 0.08})
	_p("shattered", -2, T, "破碎的", "Shattered", {"arts_pct": -0.08, "hp_pct": -0.05})
	_p("ominous", -2, T, "不祥的", "Ominous", {"crit": -0.03, "taken_pct": 0.04})
	_p("perfect", 2, T, "完美的", "Perfect", {"arts_pct": 0.08, "crit_dmg": 0.15, "aspd": 6.0, "skill_pct": 0.10}, {"top": true})
	# --- §4.1 源石与天灾 --------------------------------------------------------
	_p("pure", 2, T, "纯净的", "Pure", {"arts_pct": 0.08, "res": 4.0})
	_p("messenger", 2, A, "信使的", "Messenger's", {"pressure_pct": -0.15, "move_pct": 0.03}, {"group": "threat"})
	_p("originium", 1, W, "源石化的", "Originium-Laced", {"arts_pct": 0.20, "contam_pct": 0.20}, {"group": "contam"})
	_p("crystal", 1, A, "结晶的", "Crystallized", {"res": 10.0, "hp_pct": -0.04})
	_p("active", 0, T, "活性的", "Active", {"arts_pct": 0.15, "contam_pct": 0.20}, {"group": "contam"})
	_p("infected", 0, W, "感染者的", "Infected's", {"atk_pct": 0.10, "heal_pct": -0.20})
	_p("catastrophe", 0, W, "天灾的", "Catastrophic", {"atk_pct": 0.16, "taken_pct": 0.08})
	_p("tainted", -1, W + A, "污损的", "Tainted", {"contam_pct": 0.25}, {"group": "contam"})
	_p("inert", -1, T, "失活的", "Inert", {"arts_pct": -0.08})
	# --- §4.2 切尔诺伯格（矿）----------------------------------------------------
	_p("ursus", 1, A, "乌萨斯的", "Ursine", {"def": 50.0, "move_pct": -0.04}, {"region": "mine"})
	_p("tunneling", 1, W, "掘进的", "Tunneling", {"def_ignore": 0.10}, {"region": "mine"})
	_p("cover", 1, A, "掩体的", "Covered", {"evasion_ranged": 0.08}, {"region": "mine"})
	_p("abandoned", -2, W, "废弃的", "Abandoned", {"atk_pct": -0.10, "crit": -0.02}, {"region": "mine"})
	# --- §4.3 龙门（城）----------------------------------------------------------
	_p("yanforged", 2, W, "炎铸的", "Yan-Forged", {"atk_pct": 0.05, "crit_dmg": 0.15}, {"region": "city"})
	_p("guarddept", 1, A, "近卫局的", "Guard Department", {"def": 25.0, "res": 5.0}, {"region": "city"})
	_p("garrison", 2, A, "卫戍的", "Garrison", {"dmg_reduce": 0.05, "evasion_melee": 0.04, "res": 2.0}, {"region": "city"})
	_p("gang", 1, T, "黑帮的", "Gangland", {"gold_pct": 0.20, "hp_pct": -0.03}, {"region": "city"})
	_p("alley", 0, A, "街巷的", "Back-Alley", {"evasion": 0.05, "hp_pct": -0.04}, {"region": "city"})
	_p("knockoff", -1, W, "仿制的", "Knockoff", {"atk_pct": -0.05}, {"region": "city", "value": 0.5, "group": "value"})
	# --- §4.4 萨米（雪）----------------------------------------------------------
	_p("snowpriest", 2, T, "雪祀的", "Snowpriest's", {"skill_pct": 0.20, "arts_pct": 0.05}, {"region": "snow"})
	_p("mountain", 2, A, "雪山的", "Mountaineer's", {"stamina_regen_pct": 0.20, "hp_pct": 0.03}, {"region": "snow"})
	_p("tundra", 1, A, "冰原的", "Tundra", {"res": 10.0, "move_pct": -0.03}, {"region": "snow"})
	_p("witchkin", 0, W, "邪魔的", "Witchkin-Touched", {"atk_pct": 0.14, "heal_pct": -0.30}, {"region": "snow"})
	_p("snowveil", 1, A, "雪隐的", "Snow-Veiled", {"evasion_ranged": 0.06, "move_pct": 0.02}, {"region": "snow"})
	_p("frostcracked", -1, A, "冻裂的", "Frost-Cracked", {"res": -4.0, "move_pct": -0.03}, {"region": "snow"})
	# --- §4.5 泰拉各国与势力 -----------------------------------------------------
	_p("precision", 2, A + T, "精工的", "Precision", {"dash_cd_pct": -0.12, "dash_cost_pct": -0.10})
	_p("laterano", 1, A, "拉特兰的", "Lateran", {"heal_pct": 0.15})
	_p("mercenary", 1, W, "佣兵的", "Mercenary", {"atk_pct": 0.04, "gold_pct": 0.10})
	_p("victorian", 1, A, "维多利亚的", "Victorian", {"def": 20.0, "aspd": 5.0})
	_p("chanting", 1, T, "咏唱的", "Chanting", {"arts_pct": 0.12, "aspd": -4.0})
	_p("formula", 1, T, "术式的", "Formulaic", {"skill_pct": 0.15, "skill_cd_pct": -0.06})
	_p("higashi", 1, W, "东国的", "Higashi", {"crit_dmg": 0.25, "crit": -0.01}, {"form": "blade"})
	_p("blacksteel", 1, A, "黑钢的", "Blacksteel", {"def": 35.0, "hp_pct": 0.03})
	_p("experimental", 1, T, "实验的", "Experimental", {"arts_pct": 0.10, "crit_dmg": 0.10, "taken_pct": 0.03})
	_p("spellguard", 1, T, "咒护的", "Spellguarded", {"evasion_arts": 0.04, "res": 2.0})
	_p("heavyknight", 1, A, "重骑的", "Heavy-Knight", {"dmg_reduce": 0.06, "def": 20.0, "move_pct": -0.03})
	_p("scaled", 0, A, "鳞甲的", "Scaled", {"dmg_reduce": 0.08, "heal_pct": -0.20})
	_p("cursed", -2, T, "诅咒的", "Cursed", {"taken_pct": 0.05, "hp_pct": -0.03})
	# --- §4.6 行动与行商 ---------------------------------------------------------
	_p("tactical", 1, T, "战术的", "Tactical", {"dash_cd_pct": -0.08, "aspd": 4.0})
	_p("smuggled", 0, W + A + T, "走私的", "Smuggled", {}, {"value": 2.0, "group": "value"})
	_p("derelict", -1, A, "失修的", "Derelict", {"def": -25.0, "res": -3.0})
	_p("collapsed", -2, A, "坍缩的", "Collapsed", {"def": -30.0, "res": -5.0})
	# --- §4.7 顶级 --------------------------------------------------------------
	_p("court", 2, W, "王庭的", "Royal Court", {"atk_pct": 0.10, "crit": 0.03, "crit_dmg": 0.15}, {"top": true})
	# --- Effect families (前缀放大与特效阶等案 §3): a W, an A and a T name each,
	# grade +1, no stats of their own; PrefixFamilies counts and runs them.
	for fam in PrefixFamilies.FAMILIES:
		var data: Dictionary = PrefixFamilies.FAMILIES[fam]
		for p in data.prefixes:
			_p(p[0], 1, p[3], p[1], p[2], {}, {"family": fam, "region": data.region, "group": "fam_" + fam})

# --- Rolling ----------------------------------------------------------------------

## Gear that carries prefixes: everything equippable but set pieces (§0.1-5).
static func eligible_item(item: Item) -> bool:
	return item != null and item.is_equippable() and item.material_id.is_empty() and item.named_kind() != "set"

## The prefix table's three kinds: the five armour slots take armour
## prefixes, the amulet and the ring trinket ones (装备部位拆分与数值案 §5).
static func _slot(item: Item) -> String:
	match Item.group_of(item.category):
		Item.Category.WEAPON: return W
		Item.Category.ARMOR: return A
	return T

## "W", "A" or "T" for `item`.
static func slot_kind(item: Item) -> String:
	return _slot(item)

static func _form(item: Item) -> String:
	if item.category != Item.Category.WEAPON: return ""
	var data: Dictionary = SpecialGear.GEAR.get(item.special, {}) if not item.special.is_empty() else GearCatalog.base(item.base_id)
	return str(data.get("form", "blade"))

## Whether prefix `id` can go on `item` next to `taken` (prefix ids).
static func fits(id: String, item: Item, taken: Array, top_open: bool) -> bool:
	var e: Dictionary = all()[id]
	if not str(e.slots).contains(_slot(item)): return false
	if not str(e.form).is_empty() and str(e.form) != _form(item): return false
	if bool(e.top) and not top_open: return false
	for other_id in taken:
		if other_id == id: return false
		var o: Dictionary = all()[other_id]
		if bool(o.top) and bool(e.top): return false
		if not str(o.region).is_empty() and not str(e.region).is_empty(): return false
		if not str(e.group).is_empty() and str(e.group) == str(o.group): return false
	return true

static func _weight(id: String, region: String) -> float:
	var e: Dictionary = all()[id]
	var w := TOP_WEIGHT if bool(e.top) else 1.0
	if not str(e.region).is_empty() and str(e.region) == region: w *= REGION_WEIGHT
	return w

## One prefix id for `item`, or "" when nothing fits. FAMILY_SHARE of the
## rolls are an effect family's prefix (前缀放大与特效阶等案 §3).
static func roll_one(item: Item, region: String, top_open: bool, taken: Array, rng: RandomNumberGenerator, good: float = 0.0) -> String:
	var by_grade := {}
	var family_ids: Array = []
	for id in all():
		if not str(all()[id].family).is_empty():
			if fits(id, item, taken, top_open): family_ids.append(id)
			continue
		if fits(id, item, taken, top_open):
			var g := int(all()[id].grade)
			if not by_grade.has(g): by_grade[g] = []
			by_grade[g].append(id)
	if not family_ids.is_empty() and (by_grade.is_empty() or rng.randf() < FAMILY_SHARE):
		return family_ids[LootTables._pick_weighted(family_ids.map(func(id): return _weight(id, region)), rng)]
	if by_grade.is_empty(): return ""
	var grades: Array = by_grade.keys()
	var weights: Array = grades.map(func(g): return grade_weight(g, good))
	var ids: Array = by_grade[grades[LootTables._pick_weighted(weights, rng)]]
	return ids[LootTables._pick_weighted(ids.map(func(id): return _weight(id, region)), rng)]

## A grade's weight, `good` (0–1) past the stair's top.
static func grade_weight(grade: int, good: float = 0.0) -> float:
	return float(GRADE_WEIGHTS[grade]) * maxf(0.0, 1.0 + float(GOOD_SHIFT[grade]) * clampf(good, 0.0, 1.0))

## A fresh entry {id, rolls}: one 80–120% multiplier per stat and fx line.
static func roll_entry(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = all()[id]
	var rolls := {}
	for key in e.stats: rolls[key] = rng.randf_range(ROLL_LOW, ROLL_HIGH)
	for key in e.fx: rolls[key] = rng.randf_range(ROLL_LOW, ROLL_HIGH)
	return {"id": id, "rolls": rolls}

## The whole prefix set: one, and a second at DOUBLE_CHANCE; higher grade first.
static func roll_set(item: Item, region: String, top_open: bool, rng: RandomNumberGenerator, good: float = 0.0) -> Array:
	var ids: Array = []
	var first := roll_one(item, region, top_open, ids, rng, good)
	if first.is_empty(): return []
	ids.append(first)
	if rng.randf() < DOUBLE_CHANCE:
		var second := roll_one(item, region, top_open, ids, rng, good)
		if not second.is_empty(): ids.append(second)
	if ids.size() == 2 and int(all()[ids[1]].grade) > int(all()[ids[0]].grade): ids.reverse()
	return ids.map(func(id): return roll_entry(id, rng))

## New gear: rolls its prefixes and settles its value (§2.3, §2.5).
static func roll_onto(item: Item, region: String, depth: int, rng: RandomNumberGenerator) -> void:
	if not eligible_item(item): return
	item.prefixes = roll_set(item, region, depth >= TOP_DEPTH, rng, LootTables.past_top(depth))
	refresh_value(item, true)

## Old saves (§0.2-6): gear without prefixes rolls them once on load.
static func backfill(item: Item) -> void:
	if not eligible_item(item) or not item.prefixes.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	item.prefixes = roll_set(item, item.origin_region, item.grade >= TOP_GRADE, rng)
	refresh_value(item, true)

## 重铸: the whole set again, the same odds as a drop (§2.5).
## `keep` ≥ 0 keeps that prefix and rolls only the other slot (工程部Ⅴ,
## 龙门币平衡与科研部策划案).
static func reforge(item: Item, rng: RandomNumberGenerator, keep: int = -1) -> void:
	if not eligible_item(item): return
	if keep < 0 or keep >= item.prefixes.size():
		item.prefixes = roll_set(item, item.origin_region, item.grade >= TOP_GRADE, rng)
	else:
		var kept: Dictionary = item.prefixes[keep]
		var other := roll_one(item, item.origin_region, item.grade >= TOP_GRADE, [str(kept.id)], rng)
		item.prefixes = [kept] if other.is_empty() else [kept, roll_entry(other, rng)]
		if item.prefixes.size() == 2 and int(all()[str(item.prefixes[1].id)].grade) > int(all()[str(kept.id)].grade): item.prefixes.reverse()
	refresh_value(item)

# --- Reading ----------------------------------------------------------------------

static func value_of(entry: Dictionary, key: String) -> float:
	var e: Dictionary = get_entry(str(entry.id))
	var base := float(e.stats.get(key, e.fx.get(key, 0.0)))
	return base * float(entry.rolls.get(key, 1.0))

## What a prefix's stat line is multiplied by on `item`: weapon 1.6, chest
## and amulet 1.5, the small pieces the table (前缀放大与特效阶等案 §2), and
## for flat DEF the tier's flat growth. Aspd and RES are shares already.
static func stat_scale(item: Item, key: String) -> float:
	var scale := 1.0
	if item.category == Item.Category.WEAPON: scale = WEAPON_SCALE
	elif item.category in BIG_SLOTS: scale = BIG_SCALE
	if key == "def": scale *= Scaling.flat_scale(item.grade)
	return scale

## Everything an item's prefixes add to the sheet.
static func stats_of(item: Item) -> Dictionary:
	var sheet := {}
	for entry in item.prefixes:
		var e := get_entry(str(entry.id))
		if e.is_empty(): continue
		# Flat DEF grows with the item's tier like every flat affix (复利数值改造清单 C);
		# the slot sets the size (前缀放大与特效阶等案 §2).
		for key in e.stats: sheet[key] = float(sheet.get(key, 0.0)) + value_of(entry, key) * stat_scale(item, key)
	return sheet

static func fx_of(item: Item) -> Dictionary:
	var fx := {}
	for entry in item.prefixes:
		var e := get_entry(str(entry.id))
		if e.is_empty(): continue
		for key in e.fx: fx[key] = float(fx.get(key, 0.0)) + value_of(entry, key)
	return fx

static func grade_of(entry: Dictionary) -> int:
	return int(get_entry(str(entry.id)).get("grade", 0))

static func is_top(entry: Dictionary) -> bool:
	return bool(get_entry(str(entry.id)).get("top", false))

static func color_of(entry: Dictionary) -> Color:
	return GRADE_COLORS[clampi(grade_of(entry), -2, 2)]

## "致命的·狂暴的·" (empty without prefixes).
static func name_part(item: Item) -> String:
	var out := ""
	for entry in item.prefixes: out += str(get_entry(str(entry.id)).get("name", "")) + "·"
	return out

static func format_value(key: String, value: float) -> String:
	if key in FLAT: return "%+d" % roundi(value)
	return ItemModifier.pct(value)

## One line, "攻击力 +6%" or an fx sentence.
static func line_text(key: String, value: float) -> String:
	if FX_TEXT.has(key): return str(FX_TEXT[key]) % format_value(key, value)
	return "%s %s" % [LABELS.get(key, key), format_value(key, value)]

## Every line of one prefix: [text, range text] pairs (range for Alt).
## With `item`, flat DEF shows at its tier's size (清单 C).
static func lines_of(entry: Dictionary, item: Item = null) -> Array:
	var e := get_entry(str(entry.id))
	var out: Array = []
	# A family prefix reads as its family; the tooltip lists its 阶等 below.
	if not str(e.get("family", "")).is_empty():
		out.append([str(PrefixFamilies.FAMILIES[e.family].name), ""])
		return out
	for key in e.stats:
		var scale := stat_scale(item, key) if item != null else 1.0
		var base := float(e.stats[key]) * scale
		out.append([line_text(key, value_of(entry, key) * scale), "（范围 %s ~ %s）" % _ends(key, base)])
	for key in e.fx:
		var base := float(e.fx[key])
		out.append([line_text(key, value_of(entry, key)), "（范围 %s ~ %s）" % _ends(key, base)])
	return out

static func _ends(key: String, base: float) -> Array:
	var a := base * ROLL_LOW
	var b := base * ROLL_HIGH
	return [format_value(key, minf(a, b)), format_value(key, maxf(a, b))]

# --- Value (§2.5, §2.8) -----------------------------------------------------------

## Grade factor × the value prefixes' own multipliers.
static func value_factor(item: Item) -> float:
	var grades := 0
	var mult := 1.0
	for entry in item.prefixes:
		grades += 4 if is_top(entry) else grade_of(entry)
		mult *= float(get_entry(str(entry.id)).get("value", 1.0))
	return maxf(0.3, 1.0 + 0.25 * grades) * mult

## 0 (every line at its worst) to 1 (every line at its best).
static func roll_quality(item: Item) -> float:
	var total := 0.0
	var count := 0
	if item.power_mid > 0.0:
		total += item.power_position()
		count += 1
	for mod in item.modifiers:
		if mod.is_rollable():
			total += mod.roll_position()
			count += 1
	for entry in item.prefixes:
		var e := get_entry(str(entry.id))
		for key in entry.rolls:
			var t := clampf((float(entry.rolls[key]) - ROLL_LOW) / (ROLL_HIGH - ROLL_LOW), 0.0, 1.0)
			var base := float(e.stats.get(key, e.fx.get(key, 1.0)))
			var higher_better: bool = (base > 0.0) != (key in LOWER_BETTER)
			total += t if higher_better else 1.0 - t
			count += 1
	return total / count if count > 0 else 0.5

## Sets `value` from the value before prefixes (`value_base`).
static func refresh_value(item: Item, fresh: bool = false) -> void:
	if not eligible_item(item): return
	if fresh or item.value_base <= 0: item.value_base = item.value
	item.value = maxi(1, roundi(item.value_base * value_factor(item) * (0.8 + 0.4 * roll_quality(item))))

# --- Refresh lines (校准 / 精调, §2.8) ---------------------------------------------

## Every line that rolls, as [kind, index, key]: "power", "mod" (modifier
## index) or "prefix" (prefix index + stat key).
static func rollable_lines(item: Item) -> Array:
	var out: Array = []
	if item.power_mid > 0.0: out.append(["power", 0, ""])
	for i in range(item.modifiers.size()):
		if item.modifiers[i].is_rollable(): out.append(["mod", i, ""])
	for i in range(item.prefixes.size()):
		for key in item.prefixes[i].rolls:
			out.append(["prefix", i, key])
	return out

static func line_label(item: Item, line: Array) -> String:
	match str(line[0]):
		"power":
			var parts: Array[String] = []
			var names := {"atk": "攻击力", "hp": "生命", "def": "防御", "arts": "法术攻击力", "stamina_regen": "体力回复"}
			var base := CombatStats.item_stats(item)
			for key in base: parts.append("%s +%d" % [names[key], roundi(base[key])])
			return " / ".join(parts)
		"mod": return item.modifiers[int(line[1])].describe()
	var entry: Dictionary = item.prefixes[int(line[1])]
	return str(get_entry(str(entry.id)).name) + " · " + line_text(str(line[2]), value_of(entry, str(line[2])))

static func reroll_line(item: Item, line: Array, rng: RandomNumberGenerator) -> void:
	match str(line[0]):
		"power":
			var r := item.power_range()
			item.power = rng.randf_range(float(r[0]), float(r[1]))
		"mod": item.modifiers[int(line[1])].reroll(rng)
		"prefix": item.prefixes[int(line[1])].rolls[str(line[2])] = rng.randf_range(ROLL_LOW, ROLL_HIGH)
	refresh_value(item)

## 校准: every line again; kinds, tiers and prefixes stay.
static func calibrate(item: Item, rng: RandomNumberGenerator) -> void:
	for line in rollable_lines(item): reroll_line(item, line, rng)
	refresh_value(item)
