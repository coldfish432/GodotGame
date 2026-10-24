class_name Scaling
extends RefCounted

## The compound numbers (复利数值改造清单.md, 用户 2026-10-20): enemies grow
## ×1.04 a floor; gear comes in ten-floor tiers ×1.48, each rarity rolling
## inside its own band; flat affixes grow ×1.30 a tier; heals, flasks and
## traps carry the current tier's coefficient. Pure arithmetic, no state.

## Enemy growth per floor below the first (A: HP, ATK and DEF alike).
const GROWTH := 1.04
## A tier spans a camp's ten floors; its base value is ×1.48 the last one's (B).
const TIER_FLOORS := 10
const TIER_GROWTH := 1.48
const TIER_MAX := 10
## Flat affixes grow slower than the panel (C): worth more early, less deep.
const FLAT_GROWTH := 1.30
## Physical mitigation: damage × K / (K + DEF), K = K0 × the floor's growth (A).
## 600 rather than the checklist's 400: with tiers the gear sits still for ten
## floors, and armour cut physical hits too hard against arts (balance_model.py).
const K0 := 600.0
## 基础效能 of a blue piece at its band's middle, tier 1 (B). The panel is
## power × CombatStats' per-power figures. 3.1 puts a tier's gear level with
## the enemies of its fifth floor rather than its first, so the ten floors
## run from a little easier to a little harder (tools/balance_model.py).
const POWER_BASE := 3.1

## Each rarity rolls inside its own share of the tier's base value (B), grey
## to red on the ladder (属性伤害与地区装备策划案 v1.1 §2.2, checked in §17:
## a body's panel stays within 1–4% of the old white / blue / gold). Orange's
## and red's floors are above the next tier's blue floor (0.9 × 1.48), so they
## always cross.
const BANDS := [[0.62, 0.76], [0.78, 0.90], [0.90, 1.10], [1.15, 1.30], [1.35, 1.50], [1.55, 1.70]]
## The S curve both rolls follow (B): midpoint floor 45, width 8, 0 on floor 1,
## 1 on floor 90, read on the loot stair so it only climbs.
const S_MID := 45.0
const S_WIDTH := 8.0
## In-band roll u = randf()^e (B): e from 12 on a block's first floor to 4 on
## its tenth, divided by (1 + 0.6 × S).
const E_START := 12.0
const E_END := 4.0
const E_DEEP := 0.6
## Research hook (课题"鉴定协议", 龙门币平衡与科研部策划案): multiplies e; below 1
## rolls land higher. Set at departure, 1 otherwise.
static var band_exponent_mult := 1.0

static func floor_growth(floor_number: int) -> float:
	return pow(GROWTH, maxi(floor_number, 1) - 1)

static func tier_of(floor_number: int) -> int:
	return clampi((maxi(floor_number, 1) - 1) / TIER_FLOORS + 1, 1, TIER_MAX)

## A tier's base value: 1 for tier 1, ×1.48 each tier after.
static func tier_base(tier: int) -> float:
	return pow(TIER_GROWTH, clampi(tier, 1, TIER_MAX) - 1)

## 档位系数 (D, E): the current floor's tier base; heals, flasks, traps.
static func tier_coef(floor_number: int) -> float:
	return tier_base(tier_of(floor_number))

## What a flat affix written at tier 1 is worth at `tier` (C).
static func flat_scale(tier: int) -> float:
	return pow(FLAT_GROWTH, clampi(tier, 1, TIER_MAX) - 1)

static func physical_k(floor_number: int) -> float:
	return K0 * floor_growth(floor_number)

static func _logistic(x: float) -> float:
	return 1.0 / (1.0 + exp(-(x - S_MID) / S_WIDTH))

## 0 on floor 1, 1 from floor 90; slow, then steep around 35–60, then flat.
static func s_curve(floor_number: int) -> float:
	var quantised := 1.0 + float(LootTables.stair(floor_number)) * 90.0 / float(LootTables.STAIR_TOP)
	return clampf((_logistic(quantised) - _logistic(1.0)) / (_logistic(91.0) - _logistic(1.0)), 0.0, 1.0)

## The in-band exponent on `floor_number` (higher: harder to roll high).
static func roll_exponent(floor_number: int) -> float:
	var place := float((maxi(floor_number, 1) - 1) % TIER_FLOORS) / float(TIER_FLOORS - 1)
	return lerpf(E_START, E_END, place) / (1.0 + E_DEEP * s_curve(floor_number)) * band_exponent_mult

## Where in its band a roll lands, 0 (bottom) to 1 (top).
static func roll_position(floor_number: int, rng: RandomNumberGenerator) -> float:
	return pow(rng.randf(), roll_exponent(floor_number))

static func band(rarity: int) -> Array:
	return BANDS[clampi(rarity, 0, BANDS.size() - 1)]

static func band_value(rarity: int, position: float) -> float:
	var b := band(rarity)
	return lerpf(float(b[0]), float(b[1]), clampf(position, 0.0, 1.0))

## The band's middle, for gear whose power does not roll.
static func band_mid(rarity: int) -> float:
	return band_value(rarity, 0.5)

## 基础效能 of an ordinary piece: tier base × the rarity's band at `position`.
static func gear_power(tier: int, rarity: int, position: float) -> float:
	return POWER_BASE * tier_base(tier) * band_value(rarity, position)

## Where a piece's panel sits in its rarity's band, 0 to 1 (0.5 if it does not roll).
static func band_position(item: Item) -> float:
	return item.power_position() if item != null else 0.5

## A piece whose panel reaches the next tier's blue minimum (清单 B: the only
## way to cross a tier); on the ladder that is every orange.
static func crosses_tier(item: Item) -> bool:
	if item == null or item.rarity < Item.PURPLE or item.grade <= 0 or item.grade >= TIER_MAX or not item.special.is_empty(): return false
	var factor := float(GearCatalog.base(item.base_id).get("factor", 1.0)) if not item.base_id.is_empty() else 1.0
	var at := item.power / (POWER_BASE * tier_base(item.grade) * factor)
	return at >= float(BANDS[1][0]) * TIER_GROWTH
