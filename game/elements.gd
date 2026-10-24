class_name Elements
extends RefCounted

## 属性伤害与地区装备策划案 v1.1 (用户 2026-10-24): four elemental damage
## kinds after 明日方舟's 元素损伤, each with its own resistance; two damage
## over time kinds of the old ones (流血 for physical, 凋亡 for arts); a gauge
## per kind on every enemy and on her that bursts when full. Pure data and
## arithmetic; Enemy and Player keep the state.

## The elemental kinds, in the order the HUD lists them.
const KINDS := ["burn", "cold", "corr", "nerve"]
const NAMES := {"burn": "灼燃", "cold": "寒冷", "corr": "侵蚀", "nerve": "神经", "bleed": "流血", "necro": "凋亡"}
## One character each, in the manner of the map features' 染 / 债 / 寒 (§3.2).
const BADGES := {"burn": "灼", "cold": "寒", "corr": "蚀", "nerve": "神", "bleed": "血", "necro": "凋"}
## Damage numbers, single-character marks and the gauges' rings only; never
## an item name, so they do not mix with the rarity ladder (§3.2).
const COLORS := {"burn": Color("ffd25a"), "cold": Color("9fe8ff"), "corr": Color("e8642c"), "nerve": Color("d6f25a"),
	"bleed": Color("d23b3b"), "necro": Color("8a63c9")}
## Her sheet's resistance key per kind; 凋亡 is cut by 法抗 ("res").
const RES_KEY := {"burn": "res_burn", "cold": "res_cold", "corr": "res_corr", "nerve": "res_nerve", "bleed": "res_bleed", "necro": "res"}
const RES_KEYS := ["res_burn", "res_cold", "res_corr", "res_nerve", "res_bleed"]
## Elemental damage multiplier = 1 − res/100, held in [FLOOR, CEIL] (§3.3).
const FLOOR := 0.10
const CEIL := 1.50
const RES_MIN := -50.0
const RES_CAP := 80.0
## 首领件's 抗性上限 +5 lifts her cap; two of them reach 90 (§4.1).
const RES_CAP_MAX := 90.0

## Every elemental hit and DoT is one of these; physical, arts and true keep
## CombatStats' own rules.
static func is_element(kind: String) -> bool:
	return kind in KINDS

static func multiplier(resistance: float) -> float:
	return clampf(1.0 - maxf(resistance, RES_MIN) / 100.0, FLOOR, CEIL)

# --- Depth (§4.2) ----------------------------------------------------------------

## Her five new resistances lose 5 every ten floors from floor 21, −40 at most.
static func penalty(floor_number: int) -> float:
	if floor_number <= 20: return 0.0
	return minf(40.0, 5.0 * float((floor_number - 11) / 10))

## Enemies' elemental share of their damage (§11): half on floors 1–10, three
## quarters on 11–20, all of it from 21.
static func enemy_share_mult(floor_number: int) -> float:
	if floor_number <= 10: return 0.5
	if floor_number <= 20: return 0.75
	return 1.0

# --- Enemies' resistances (§9, §17) -------------------------------------------------

## Every enemy resists each element 20; its own region's element +30; the
## region its weakness lies in −25; elites +10 on all four; bosses and
## wardens 80 on their own and 5 on the weakness.
const ENEMY_BASE := 20.0
const LOCAL_BONUS := 30.0
const WEAK_DROP := 25.0
const ELITE_BONUS := 10.0
const BOSS_LOCAL := 80.0
const BOSS_WEAK := 5.0
## The region's own element and the one that beats it (萨米 → 矿区 → 叙拉古 → 龙门 → 萨米).
const LOCAL := {"mine": "corr", "city": "burn", "snow": "cold", "siracusa": "nerve"}
const WEAKNESS := {"mine": "cold", "snow": "burn", "city": "nerve", "siracusa": "corr"}

static func enemy_resists(region: String, elite: bool, boss: bool) -> Dictionary:
	var out := {}
	for kind in KINDS:
		var r := ENEMY_BASE + (ELITE_BONUS if elite else 0.0)
		if LOCAL.get(region, "") == kind: r = BOSS_LOCAL if boss else r + LOCAL_BONUS
		elif WEAKNESS.get(region, "") == kind: r = BOSS_WEAK if boss else r - WEAK_DROP
		out[kind] = r
	return out

# --- Gauges and bursts (§5, §17) --------------------------------------------------

## A gauge fills with the elemental damage dealt (after resistance) and bursts
## at this share of the target's max life; 凋亡 fills from arts DoT ticks.
const GAUGE_KINDS := ["burn", "cold", "corr", "nerve", "necro"]
const THRESHOLD := {"normal": 0.20, "elite": 0.30, "boss": 0.08}
const HER_THRESHOLD := 0.60
const BURST_COOLDOWN := 8.0
const HER_COOLDOWN := 10.0
## 3 s without a new fill, the gauge loses 10% of the threshold a second.
const DECAY_DELAY := 3.0
const DECAY_RATE := 0.10

## On an enemy (§5.1): a share of the threshold as damage, and what it does.
const BURST := {
	"burn": {"damage": 0.40, "kind": "burn", "res_down": 20.0, "secs": 8.0},
	"cold": {"freeze": 2.0, "elite_freeze": 1.0, "boss_slow": 0.40, "boss_secs": 3.0},
	"corr": {"damage": 0.30, "kind": "phys", "def_down": 0.15, "stacks": 3},
	"nerve": {"damage": 0.25, "kind": "true", "stun": 1.5, "elite_stun": 0.8, "boss_windup": 0.5},
	"necro": {"weaken": 0.30, "secs": 6.0, "tick": 0.06},
}
## On her (§5.2).
const HER_BURST := {
	"burn": {"damage": 0.12},
	"cold": {"freeze": 0.8},
	"corr": {"def_down": 0.10, "stacks": 3},
	"nerve": {"stun": 1.0},
	"necro": {"atk_down": 0.20, "secs": 5.0},
}

static func threshold_share(elite: bool, boss: bool) -> float:
	if boss: return float(THRESHOLD.boss)
	return float(THRESHOLD.elite) if elite else float(THRESHOLD.normal)

# --- Damage over time (§6) ---------------------------------------------------------

## kind: [damage kind, seconds, share of the hit it came from in all].
const DOTS := {
	"bleed": ["bleed", 4.0, 0.40],
	"burnout": ["burn", 3.0, 0.35],
	"frost": ["cold", 5.0, 0.30],
	"rot": ["corr", 5.0, 0.30],
	"necro": ["arts", 6.0, 0.45],
}
const DOT_NAMES := {"bleed": "流血", "burnout": "灼烧", "frost": "冻伤", "rot": "源石腐蚀", "necro": "凋亡"}
## 流血 hurts more while the target moves; 冻伤 slows; 源石腐蚀 lowers DEF a stack.
const BLEED_MOVING := 0.5
const FROST_SLOW := 0.20
const ROT_DEF := 0.03
const ROT_STACKS := 5
const DOT_TICK := 0.5
## Heavy weapons and guns proc more, fists less (§6).
const FORM_PROC := {"heavy": 1.3, "gun": 1.3, "fist": 0.7}

## The stat keys that hold each DoT's proc chance, and its element for the
## "〈元素〉伤害 +%" bonus.
const DOT_CHANCE_KEY := {"bleed": "bleed_chance", "burnout": "burnout_chance", "frost": "frost_chance", "rot": "rot_chance", "necro": "necro_chance"}
const DOT_ELEMENT := {"bleed": "bleed", "burnout": "burn", "frost": "cold", "rot": "corr", "necro": "necro"}

# --- Her sheet keys ---------------------------------------------------------------

const ADD_KEY := {"burn": "add_burn", "cold": "add_cold", "corr": "add_corr", "nerve": "add_nerve"}
const CONV_KEY := {"burn": "conv_burn", "cold": "conv_cold", "corr": "conv_corr", "nerve": "conv_nerve"}
const DMG_KEY := {"burn": "burn_dmg_pct", "cold": "cold_dmg_pct", "corr": "corr_dmg_pct", "nerve": "nerve_dmg_pct", "bleed": "bleed_dmg_pct", "necro": "necro_dmg_pct"}
## Conversion never takes more than this of a hit (§3.4).
const CONV_CAP := 0.60
