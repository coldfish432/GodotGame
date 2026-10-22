class_name CombatStats
extends RefCounted

## Stat sheet and damage formulas. Numbers and their reasoning are in
## 局内构筑与数值策划案_v1_0.md §3 (stat model) and §4 (damage pipeline).
##
## Damage follows 明日方舟's split: physical hits are cut by the target's
## defence against the floor's K (复利数值改造清单 A: damage × K / (K + DEF),
## so armour always matters and never stops a hit), arts hits are scaled by
## its resistance (10% floor), true damage ignores both.

## Small on purpose (清单 A): gear is most of a Doctor's numbers, so the same
## floor's gear against the same floor's enemies feels alike from 1 to 100.
## Each operator's HP and DEF are then multiplied (Operators.STAT_MULT).
const BASE := {
	"hp": 600.0, "atk": 150.0, "arts": 150.0, "def": 50.0, "res": 10.0,
	"aspd": 100.0, "crit": 0.0, "crit_dmg": 1.5, "regen_max_pct": 0.001,
	"move": 5.0, "stamina_regen": 18.0,
}
## Every key a relic or equipment affix may add to. Flat and
## percentage keys combine as (base + flat) * (1 + pct), the way 明日方舟
## stacks its own "+X" and "+X%" buffs.
const KEYS := ["hp", "hp_pct", "atk", "atk_pct", "arts", "arts_pct", "def", "def_pct", "res",
	"aspd", "interval_pct", "crit", "crit_dmg", "move_pct", "regen", "regen_pct", "regen_max_pct", "lifesteal",
	"dmg_pct", "arts_dmg_pct", "phys_dmg_pct", "def_ignore", "taken_pct", "evasion", "evasion_arts", "heal_pct", "stamina_regen_pct", "dash_cost", "dash_cd_pct",
	"potion_cap", "gold_pct", "elite_pct", "wave_pct", "pressure_pct", "contam_pct",
	# 装备前缀策划案 §2.4 / §2.7 / §6: reach, skill damage and cooldown, the
	# melee / ranged dodge, overall damage reduction, dodge stamina.
	"reach_pct", "skill_pct", "skill_cd_pct", "evasion_melee", "evasion_ranged", "dmg_reduce", "dash_cost_pct",
	# 底材固有属性表 v1.0: operator experience, the gear share of drops.
	"exp_pct", "drop_pct"]
## 技能冷却 can at most halve the skill's cooldown (or charge needed).
const SKILL_CD_CAP := 0.5

## Equipment "power" (基础效能) turns into stats per slot (清单 A, F). A weapon
## gives its wearer's main stat (ATK for the physical operators, arts for the
## arts ones); a trinket splits its share between ATK and arts by its own roll
## (Item.atk_share); stamina from a trinket does not grow with the tier.
const WEAPON_MAIN_PER_POWER := 220.0
## 1300: with 警戒 at its cap an ordinary blow stays near 15% of her life.
const ARMOR_HP_PER_POWER := 1300.0
const ARMOR_DEF_PER_POWER := 80.0
const TRINKET_MAIN_PER_POWER := 110.0
const TRINKET_STAMINA_PER_POWER := 1.0

## The main stat a weapon's panel shows and gives ("atk" / "arts"): the player
## sets it for the operator she plays, so tooltips read the same numbers.
static var wearer_main := "atk"
## K for physical mitigation on the current floor (Scaling.physical_k); the
## game sets it when a floor starts.
static var physical_k := Scaling.K0

const DAMAGE_FLOOR := 0.10
const RES_CAP := 80.0
const ASPD_MIN := 40.0
const ASPD_MAX := 300.0
const CRIT_CAP := 1.0
const EVASION_CAP := 0.6
const REDUCTION_CAP := 0.8
const LIFESTEAL_CAP := 0.3

static func empty() -> Dictionary:
	var sheet := {}
	for key in KEYS: sheet[key] = 0.0
	return sheet

static func add(sheet: Dictionary, stats: Dictionary, times: float = 1.0) -> void:
	for key in stats:
		sheet[key] = float(sheet.get(key, 0.0)) + float(stats[key]) * times

static func physical(raw: float, defence: float, k: float = -1.0) -> float:
	var kk := physical_k if k <= 0.0 else k
	return raw * kk / (kk + maxf(defence, 0.0))

static func arts(raw: float, resistance: float) -> float:
	return raw * maxf(1.0 - minf(resistance, RES_CAP) / 100.0, DAMAGE_FLOOR)

## kind: "phys", "arts" or "true".
static func mitigate(raw: float, kind: String, defence: float, resistance: float) -> float:
	if raw <= 0.0: return 0.0
	match kind:
		"phys": return physical(raw, defence)
		"arts": return arts(raw, resistance)
	return raw

## What an equipment piece's power gives, as the sheet keys it adds to.
## `atk_share` splits a trinket (1 all ATK, 0 all arts); `tier` keeps its
## stamina the same at every depth; `main` is the weapon wearer's stat.
## Each armour slot takes its share of one armour's panel, the amulet and the
## ring theirs of one trinket's (装备部位拆分与数值案 §3, GearSlots.PANEL).
static func power_stats(category: int, power: float, atk_share: float = 1.0, tier: int = 1, main: String = "") -> Dictionary:
	if category == Item.Category.WEAPON:
		return {(wearer_main if main.is_empty() else main): power * WEAPON_MAIN_PER_POWER}
	var share_of := GearSlots.panel(category)
	if Item.is_armor_slot(category):
		return {"hp": power * ARMOR_HP_PER_POWER * share_of, "def": power * ARMOR_DEF_PER_POWER * share_of}
	if Item.is_jewel_slot(category):
		var share := clampf(atk_share, 0.0, 1.0)
		var out := {"stamina_regen": power / Scaling.tier_base(maxi(tier, 1)) * TRINKET_STAMINA_PER_POWER * share_of}
		if share > 0.0: out["atk"] = power * TRINKET_MAIN_PER_POWER * share * share_of
		if share < 1.0: out["arts"] = power * TRINKET_MAIN_PER_POWER * (1.0 - share) * share_of
		return out
	return {}

## The same for an item.
static func item_stats(item: Item, main: String = "") -> Dictionary:
	return power_stats(item.category, item.power, item.atk_share, item.grade, main)
