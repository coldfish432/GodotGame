class_name CombatStats
extends RefCounted

## Stat sheet and damage formulas. Numbers and their reasoning are in
## 局内构筑与数值策划案_v1_0.md §3 (stat model) and §4 (damage pipeline).
##
## Damage follows 明日方舟's split: physical hits subtract the target's
## defence, arts hits are scaled by its resistance, true damage ignores both.
## The floor is 10% rather than the original 5% so that every hit an action
## game player lands (or takes) still registers as a number.

const BASE := {
	"hp": 2400.0, "atk": 600.0, "arts": 360.0, "def": 200.0, "res": 10.0,
	"aspd": 100.0, "crit": 0.0, "crit_dmg": 1.5, "regen": 48.0,
	"move": 5.0, "stamina_regen": 18.0,
}
## Every key a relic, resonance tier or equipment affix may add to. Flat and
## percentage keys combine as (base + flat) * (1 + pct), the way 明日方舟
## stacks its own "+X" and "+X%" buffs.
const KEYS := ["hp", "hp_pct", "atk", "atk_pct", "arts", "arts_pct", "def", "def_pct", "res",
	"aspd", "interval_pct", "crit", "crit_dmg", "move_pct", "regen", "regen_pct", "regen_max_pct", "lifesteal",
	"dmg_pct", "arts_dmg_pct", "taken_pct", "evasion", "heal_pct", "stamina_regen_pct", "dash_cost", "dash_cd_pct",
	"potion_cap", "gold_pct", "elite_pct", "wave_pct", "pressure_pct", "contam_pct"]

## Equipment "power" (基础效能) turns into stats per slot (§7). Matches the old
## mapping in proportion: +8% damage per weapon power is +48 ATK on 600.
const WEAPON_ATK_PER_POWER := 40.0
const ARMOR_HP_PER_POWER := 360.0
const ARMOR_DEF_PER_POWER := 20.0
const TRINKET_ARTS_PER_POWER := 30.0
const TRINKET_STAMINA_PER_POWER := 1.0

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

static func physical(raw: float, defence: float) -> float:
	return maxf(raw - maxf(defence, 0.0), raw * DAMAGE_FLOOR)

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
static func power_stats(category: int, power: float) -> Dictionary:
	match category:
		Item.Category.WEAPON: return {"atk": power * WEAPON_ATK_PER_POWER}
		Item.Category.ARMOR: return {"hp": power * ARMOR_HP_PER_POWER, "def": power * ARMOR_DEF_PER_POWER}
		Item.Category.TRINKET: return {"arts": power * TRINKET_ARTS_PER_POWER, "stamina_regen": power * TRINKET_STAMINA_PER_POWER}
	return {}
