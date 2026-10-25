class_name Scaling
extends RefCounted

## The numbers by depth (属性伤害与地区装备策划案 v1.1 §19, 用户 2026-10-24:
## 层数只决定稀有度). Gear no longer grows with depth: a piece's numbers are
## its rarity's band alone, and depth only moves the odds of each rarity
## (LootTables). Enemies follow her expected growth (ENEMY_CURVE, from
## tools/depth_model.py); heals, flasks and traps follow the enemies.

## Enemy life, attack and defence ×floor 1, every ten floors from floor 1 to
## 90: the geometric mean of her ATK and HP growth in the depth model (she
## keeps the best piece found per slot, attribute points, research, prefix
## families). Between points: geometric interpolation; past 90 ×1.003 a floor.
const ENEMY_CURVE := [1.00, 1.37, 1.69, 2.02, 2.40, 2.89, 3.46, 4.01, 4.61, 4.94]
const CURVE_STEP := 10
const PAST_CURVE := 1.003
## The ten-floor blocks still count for 随队物资 and the 龙门币 economy; gear
## and flasks no longer have tiers (tier 1 is all there is).
const TIER_FLOORS := 10
const TIER_MAX := 10
## Saves before §19 kept gear in tiers: ×1.48 a tier, flat affixes ×1.30.
const OLD_TIER_GROWTH := 1.48
const OLD_FLAT_GROWTH := 1.30
## Physical mitigation: damage × K / (K + DEF), K = K0 × the floor's growth (A).
## 600 rather than the checklist's 400: armour cut physical hits too hard
## against arts (balance_model.py).
const K0 := 600.0
## 基础效能 of a blue piece at its band's middle (B). The panel is power ×
## CombatStats' per-power figures.
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
## In-band roll u = randf()^e (B): e from 12 on floor 1 to 4 at the loot
## stair's top along the S curve, divided by (1 + 0.6 × S): deeper rolls higher.
const E_START := 12.0
const E_END := 4.0
const E_DEEP := 0.6
## Research hook (课题"鉴定协议", 龙门币平衡与科研部策划案): multiplies e; below 1
## rolls land higher. Set at departure, 1 otherwise.
static var band_exponent_mult := 1.0

static func floor_growth(floor_number: int) -> float:
	var f := maxi(floor_number, 1)
	var last := (ENEMY_CURVE.size() - 1) * CURVE_STEP
	if f >= last: return float(ENEMY_CURVE.back()) * pow(PAST_CURVE, f - last)
	var i := (f - 1) / CURVE_STEP
	var lo := 1 if i == 0 else i * CURVE_STEP
	var hi := (i + 1) * CURVE_STEP
	var t := float(f - lo) / float(hi - lo)
	return float(ENEMY_CURVE[i]) * pow(float(ENEMY_CURVE[i + 1]) / float(ENEMY_CURVE[i]), t)

## 合同深入系数 (藏品数值修订案 v1.0 §4): relics pile up within a contract and
## ENEMY_CURVE does not count them, so enemies also grow with the floors this
## contract has gone, n = 1 on its first floor (tools/relic_model.py: half the
## median player's relic gain, s = 0.5). Defence does not take it.
const CONTRACT_HP := 1.045
const CONTRACT_ATK := 1.018
const CONTRACT_CAP := 30

static func contract_floors(floor_number: int, start_floor: int) -> int:
	return clampi(floor_number - start_floor + 1, 1, CONTRACT_CAP)

static func contract_hp(n: int) -> float:
	return pow(CONTRACT_HP, clampi(n, 0, CONTRACT_CAP))

static func contract_atk(n: int) -> float:
	return pow(CONTRACT_ATK, clampi(n, 0, CONTRACT_CAP))

static func tier_of(floor_number: int) -> int:
	return clampi((maxi(floor_number, 1) - 1) / TIER_FLOORS + 1, 1, TIER_MAX)

## Gear has no tiers now (§19): every tier's base is 1.
static func tier_base(_tier: int) -> float:
	return 1.0

## A save's old tier `tier`: what it multiplied the panel (×1.48 a tier) and a
## flat affix (×1.30) by, for folding old gear back to tier 1.
static func old_tier_base(tier: int) -> float:
	return pow(OLD_TIER_GROWTH, clampi(tier, 1, TIER_MAX) - 1)

static func old_flat_scale(tier: int) -> float:
	return pow(OLD_FLAT_GROWTH, clampi(tier, 1, TIER_MAX) - 1)

## 档位系数 (D, E): heals, flasks and traps on `floor_number` follow the
## enemies' growth there (§19).
static func tier_coef(floor_number: int) -> float:
	return floor_growth(floor_number)

## Flat affixes no longer grow with depth (§19).
static func flat_scale(_tier: int) -> float:
	return 1.0

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
	var s := s_curve(floor_number)
	return lerpf(E_START, E_END, s) / (1.0 + E_DEEP * s) * band_exponent_mult

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

## 基础效能 of an ordinary piece: the rarity's band at `position` (no tier, §19).
static func gear_power(_tier: int, rarity: int, position: float) -> float:
	return POWER_BASE * band_value(rarity, position)

## Where a piece's panel sits in its rarity's band, 0 to 1 (0.5 if it does not roll).
static func band_position(item: Item) -> float:
	return item.power_position() if item != null else 0.5

## Crossing a tier is gone with the tiers (§19).
static func crosses_tier(_item: Item) -> bool:
	return false
