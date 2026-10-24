class_name Economy
extends RefCounted

## Money (经济修订案_v1_0.md). Two currencies only:
##   赤金    the in-run money, a stackable material in the pack (it takes cells,
##           is lost on death unless in the safe bag, comes home as an item);
##   龙门币  the out-of-run money, the account balance (GameManager.gold).
## 可露希尔 buys 赤金 for 龙门币. Every fixed price here is a base price: a
## later multi-faction trading system will move prices around (§7), so prices
## are read through these functions rather than written at the call site.

const GOLD_ID := "赤金"
## An item's delivery price (交付价) in 龙门币 is Item.value times this.
const LMD_PER_VALUE := 100
## The base of the 龙门币/赤金 rate: foreign base prices convert at this fixed
## rate (势力与交易所策划案 §4), the live rate floats around it (§1.3).
const GOLD_BAR_LMD := 1000
## The live rate, kept by MarketState (龙门币 per 赤金).
static var fx := 1000.0
## 可露希尔 changes money at the live rate with this spread (§1.3); the
## exchange terminal at EXCHANGE_FX_SPREAD.
const CLOSURE_FX_SPREAD := 0.03
## What 可露希尔 charges now: 2% with 商务部 2 阶 (Research.apply_globals).
static var closure_spread := CLOSURE_FX_SPREAD
const EXCHANGE_FX_SPREAD := 0.005
## Plain delivery at the base is Rhodes Island's internal buy-back (§13).
const DIRECT_DELIVERY := 0.8
## Old reward units per 赤金: the loot tables still speak in the old 待交付报酬
## amounts (enemies 8–14, chests 30–60), turned into bars when they hit the ground.
const OLD_REWARD_PER_BAR := 10.0
## A new save's balance (the old 60 资金 ×100).
const STARTING_LMD := 6000

## The yardstick for anything priced by depth (龙门币平衡与科研部策划案 v1.1 §1):
## a tier's drop income per floor, tier 1 = 1 (tools/economy_model.py). Prices
## follow income, not the tier coefficient 1.48^(tier − 1), because item values
## stay linear in depth (复利数值改造清单 G).
const INCOME_INDEX := [1.0, 1.49, 1.99, 2.57, 3.28, 4.06, 4.79, 5.46, 6.10, 6.73]
const FLOORS_PER_TIER := 10

## Floors 1–10 are tier 1, 11–20 tier 2 … capped at 10.
static func tier_of(floor_number: int) -> int:
	return clampi((maxi(floor_number, 1) - 1) / FLOORS_PER_TIER + 1, 1, INCOME_INDEX.size())

static func income_index(tier: int) -> float:
	return float(INCOME_INDEX[clampi(tier, 1, INCOME_INDEX.size()) - 1])

## `base` at tier 1, scaled to `tier` and rounded to 100.
static func tiered(base: int, tier: int) -> int:
	return roundi(base * income_index(tier) / 100.0) * 100

## The contract reward (v1.1 §2.2, 用户: 合同报酬在接取时就算好，之后不改变):
## the random share is rolled with the offer, the card shows the pay for the
## chosen start, and taking the contract fixes it. Paid on extraction with the
## objective done, nothing otherwise.
const CONTRACT_BASE := 8000
const CONTRACT_KIND := {"recover": 0.9, "search": 1.0, "hunt": 1.1}
## Deep contracts by how many floors past the start (FieldCatalog.DEEP_STEPS).
const CONTRACT_DEEP := {4: 0.8, 6: 1.1, 9: 1.5}
const CONTRACT_ROLL := Vector2(0.85, 1.15)

## Kinds that pay this reward (寻访 and 运送 have their own).
static func pays_contract_reward(contract: Dictionary) -> bool:
	var kind := str(contract.get("type", ""))
	return kind == "deep" or CONTRACT_KIND.has(kind)

static func contract_reward(contract: Dictionary, start_floor: int) -> int:
	if not pays_contract_reward(contract): return 0
	var kind := str(contract.type)
	var factor: float = float(CONTRACT_DEEP.get(int(contract.get("steps", 6)), 1.0)) if kind == "deep" else float(CONTRACT_KIND[kind])
	var roll := float(contract.get("roll", 1.0))
	return maxi(100, roundi(CONTRACT_BASE * income_index(tier_of(start_floor)) * factor * roll / 100.0) * 100)

## 交付价 in 龙门币: the base price of an item.
static func price(item: Item) -> int:
	return lmd(item.value) if item != null else 0

## 可露希尔's direct delivery: the internal buy-back price.
static func direct_price(item: Item) -> int:
	return roundi(price(item) * DIRECT_DELIVERY)

## What 可露希尔 pays in 龙门币 for one 赤金 (the live rate less her spread).
static func closure_bar_price() -> int:
	return roundi(fx * (1.0 - closure_spread))

## 龙门币 per 赤金 at the live rate, for fees quoted in 赤金.
static func bar_lmd() -> float:
	return maxf(fx, 1.0)

static func lmd(value: int) -> int:
	return value * LMD_PER_VALUE

## Old reward units → whole 赤金, the remainder rolled as a chance of one more,
## so the expected amount is exact.
static func bars_from_reward(amount: float, rng: RandomNumberGenerator) -> int:
	var exact := maxf(amount, 0.0) / OLD_REWARD_PER_BAR
	var whole := floori(exact)
	return whole + (1 if rng.randf() < exact - whole else 0)

## "6,000" — thousands separated, as the base shows 龙门币.
static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out
