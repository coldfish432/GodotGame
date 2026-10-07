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
## 可露希尔 pays this much 龙门币 for one 赤金.
const GOLD_BAR_LMD := 1000
## Old reward units per 赤金: the loot tables still speak in the old 待交付报酬
## amounts (enemies 8–14, chests 30–60), turned into bars when they hit the ground.
const OLD_REWARD_PER_BAR := 10.0
## Contract reward on a successful extraction (§3): every floor travelled pays
## a random 800–1200 in steps of 10.
const CONTRACT_REWARD_MIN := 800
const CONTRACT_REWARD_MAX := 1200
const CONTRACT_REWARD_STEP := 10
## A new save's balance (the old 60 资金 ×100).
const STARTING_LMD := 6000

## 交付价 in 龙门币: the base price of an item.
static func price(item: Item) -> int:
	return lmd(item.value) if item != null else 0

static func lmd(value: int) -> int:
	return value * LMD_PER_VALUE

## Old reward units → whole 赤金, the remainder rolled as a chance of one more,
## so the expected amount is exact.
static func bars_from_reward(amount: float, rng: RandomNumberGenerator) -> int:
	var exact := maxf(amount, 0.0) / OLD_REWARD_PER_BAR
	var whole := floori(exact)
	return whole + (1 if rng.randf() < exact - whole else 0)

## The sum of `floors` random per-floor rewards.
static func contract_reward(floors: int, rng: RandomNumberGenerator) -> int:
	var total := 0
	var steps := (CONTRACT_REWARD_MAX - CONTRACT_REWARD_MIN) / CONTRACT_REWARD_STEP
	for i in range(maxi(floors, 0)):
		total += CONTRACT_REWARD_MIN + rng.randi_range(0, steps) * CONTRACT_REWARD_STEP
	return total

## "6,000" — thousands separated, as the base shows 龙门币.
static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out
