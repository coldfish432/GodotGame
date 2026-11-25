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
## 首领件's 抗性上限 +5 lifts her cap; two of them and 科研 极限防护 +2 reach 92 (抗性为王修订案 v0.4 §5.1).
const RES_CAP_MAX := 92.0

## Every elemental hit and DoT is one of these; physical, arts and true keep
## CombatStats' own rules.
static func is_element(kind: String) -> bool:
	return kind in KINDS

static func multiplier(resistance: float) -> float:
	return clampf(1.0 - maxf(resistance, RES_MIN) / 100.0, FLOOR, CEIL)

# --- Depth (§4.2) ----------------------------------------------------------------

## Her five new resistances lose 5 every ten floors from floor 21, −50 at most
## (抗性为王修订案 v0.4 §4; was −40).
const PENALTY_MAX := 50.0
static func penalty(floor_number: int) -> float:
	if floor_number <= 20: return 0.0
	return minf(PENALTY_MAX, 5.0 * float((floor_number - 11) / 10))

## Her 法抗 loses half of that, −25 at most (§4).
const ARTS_PENALTY_MAX := 25.0
static func arts_penalty(floor_number: int) -> float:
	return minf(ARTS_PENALTY_MAX, penalty(floor_number) * 0.5)

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
## An enemy's ring is no share of its life any more (元素阈值修订案 v0.1, 用户
## 2026-11-24): T = T0 × its rank × the depth its life grew by (floor and
## contract), as 明日方舟's 1000 / 1000 / 2000.
const T0 := 250.0
const RANK := {"normal": 1.0, "elite": 1.0, "boss": 2.0}
## Hers stays a share of her life.
const HER_THRESHOLD := 0.60
## 元素反应策划案 v0.2 (用户 2026-11-24): one ring, 4 s (was 8 s a gauge).
const BURST_COOLDOWN := 4.0
## An enemy's ring takes this many times the elemental damage it is dealt.
## ×4 (2026-11-24, §20) made up for thresholds of its life; with fixed
## thresholds it is back to ×1 (元素阈值修订案 v0.1).
const GAUGE_FILL := 1.0
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

# --- One ring, pure bursts and reactions (元素反应策划案 v0.2) ---------------------

## The leading kind at or above this share bursts alone (§5.1 table);
## below it the two leading kinds react.
const PURE_SHARE := 0.70
## A reaction's damage × (K_BASE + K_BALANCE × second ÷ first): 1.2 at 50/50.
const K_BASE := 0.7
const K_BALANCE := 0.5
const REACT_RADIUS := 3.0

## Pair key (GAUGE_KINDS order) → name, damage as a share of the threshold,
## its kind, the share of DEF it ignores; the rest of each one's effect is in
## Enemy._react.
const REACTIONS := {
	"burn+cold": {"name": "骤裂", "damage": 0.70, "kind": "phys", "pierce": 0.5},
	"burn+corr": {"name": "源石爆燃", "damage": 0.50, "kind": "burn"},
	"burn+nerve": {"name": "过载", "damage": 0.45, "kind": "true", "stun": 0.8, "elite_stun": 0.4, "boss_slow": 0.30, "boss_secs": 2.0},
	"burn+necro": {"name": "焚身", "damage": 0.90, "kind": "arts", "secs": 6.0, "res_down": 20.0, "res_secs": 8.0},
	"cold+corr": {"name": "脆化", "damage": 0.30, "kind": "phys", "fragile": 0.25, "slow": 0.30, "secs": 6.0},
	"cold+nerve": {"name": "僵直", "damage": 0.25, "kind": "true", "freeze": 2.5, "elite_freeze": 1.2, "boss_slow": 0.50, "boss_secs": 4.0},
	"cold+necro": {"name": "寂灭", "damage": 0.40, "kind": "arts", "weaken": 0.30, "slow": 0.30, "secs": 6.0},
	"corr+nerve": {"name": "蚀神", "damage": 0.45, "kind": "true", "stacks": 2},
	"corr+necro": {"name": "溃散", "damage": 0.50, "kind": "phys", "stacks": 1, "weaken": 0.30, "secs": 6.0},
	"nerve+necro": {"name": "崩溃", "damage": 0.35, "kind": "true", "stun": 1.0, "elite_stun": 0.5, "boss_slow": 0.30, "boss_secs": 3.0, "fragile": 0.20, "secs": 6.0},
}

## The kind with the largest share (ties: GAUGE_KINDS order).
static func leading(split: Dictionary) -> String:
	var best := ""
	for kind in GAUGE_KINDS:
		if float(split.get(kind, 0.0)) > float(split.get(best, 0.0)): best = kind
	return best

## What a full ring does: {"pure": kind} or {"pair": key, "main": kind, "k": k}.
static func outcome(split: Dictionary) -> Dictionary:
	var order: Array = GAUGE_KINDS.filter(func(kind): return float(split.get(kind, 0.0)) > 0.0)
	order.sort_custom(func(a, b): return float(split[a]) > float(split[b]) or (float(split[a]) == float(split[b]) and GAUGE_KINDS.find(a) < GAUGE_KINDS.find(b)))
	if order.is_empty(): return {}
	var first: String = order[0]
	var s1 := float(split[first])
	if order.size() < 2 or s1 >= PURE_SHARE: return {"pure": first}
	var second: String = order[1]
	return {"pair": pair_key(first, second), "main": first, "k": K_BASE + K_BALANCE * float(split[second]) / s1}

static func pair_key(a: String, b: String) -> String:
	return a + "+" + b if GAUGE_KINDS.find(a) < GAUGE_KINDS.find(b) else b + "+" + a

## An enemy's T: `growth` is Scaling.floor_growth × the contract's life factor.
static func threshold(elite: bool, boss: bool, growth: float) -> float:
	var rank := float(RANK.boss) if boss else (float(RANK.elite) if elite else float(RANK.normal))
	return T0 * rank * maxf(growth, 0.0)

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
## 高血量 (元素转化与高血量词条修订案 v0.1 §5): a target whose life is at
## least this × the floor's growth × 合同深入系数 (as enemy life grows).
const HIGH_HP := 2500.0
