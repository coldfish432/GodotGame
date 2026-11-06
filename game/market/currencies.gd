class_name Currencies
extends RefCounted

## The regional currencies (地区货币与地区互动事件策划案_v0_2.md §1, 用户
## 2026-10-25). Each has a rate book quoted as units per 赤金: up means the
## currency weakens. 龙门币's book is the old "fx"; the five without a name in
## PRTS are named after their real-world model (拍板 #3) and settle nothing:
## their regions' factions still take 赤金.
##
## base: units per 赤金 at index 1. rate: policy rate a year (paid on balances
## at the 08:00 turn, no interest-parity offset, 拍板 #8). noise: volatility
## against the old FX book's. spread: the conversion spread to or from 赤金.
## peg: held in a band around its centre. haven: strengthens in a panic.
## drift: a steady weakening per day (index up).
const LIST := {
	"lmd": {"name": "龙门币", "unit": "龙门币", "book": "fx", "region": "龙门", "base": 1000.0, "rate": 0.02, "noise": 1.0, "spread": 0.005},
	"col": {"name": "哥伦比亚金券", "unit": "金券", "book": "fx_col", "region": "哥伦比亚", "base": 400.0, "rate": 0.05, "noise": 1.2, "spread": 0.006},
	"vic": {"name": "维多利亚镑", "unit": "镑", "book": "fx_vic", "region": "维多利亚", "base": 80.0, "rate": 0.04, "noise": 1.4, "spread": 0.006},
	"sar": {"name": "萨尔贡第纳尔", "unit": "第纳尔", "book": "fx_sar", "region": "萨尔贡", "base": 1500.0, "rate": 0.07, "noise": 0.3, "spread": 0.008, "peg": 0.02},
	"lei": {"name": "莱塔尼亚杜卡特金币", "unit": "杜卡特", "book": "fx_lei", "region": "莱塔尼亚", "base": 12.0, "rate": 0.01, "noise": 0.5, "spread": 0.006},
	"urs": {"name": "乌萨斯卢布", "unit": "卢布", "book": "fx_urs", "region": "乌萨斯", "base": 9000.0, "rate": 0.09, "noise": 1.5, "spread": 0.012},
	"kje": {"name": "谢拉格法郎", "unit": "法郎", "book": "fx_kje", "region": "谢拉格", "base": 90.0, "rate": 0.005, "noise": 0.6, "spread": 0.006, "haven": true},
	"kaz": {"name": "卡西米尔兹罗提", "unit": "兹罗提", "book": "fx_kaz", "region": "卡西米尔", "base": 450.0, "rate": 0.05, "noise": 1.2, "spread": 0.008},
	"sir": {"name": "叙拉古里拉", "unit": "里拉", "book": "fx_sir", "region": "叙拉古", "base": 25000.0, "rate": 0.10, "noise": 1.3, "spread": 0.01, "drift": 0.0003},
	"sam": {"name": "萨米克朗", "unit": "克朗", "book": "fx_sam", "region": "萨米", "base": 1200.0, "rate": 0.03, "noise": 1.0, "spread": 0.02},
}
const ORDER: Array[String] = ["lmd", "col", "vic", "sar", "lei", "urs", "kje", "kaz", "sir", "sam"]
## High-yield currencies a panic drags down (§1.4).
const RISKY := ["sir", "urs", "sar"]
## Cross conversion: the two spreads together, at this share (§1.1).
const CROSS_SHARE := 0.75

## Contagion (§3.3): when an event moves a currency, these follow later, by
## [selector, coefficient] in value terms (the currency falling, a positive
## coefficient falls with it; for goods books, their price falls).
const TIES := {
	"col": [["kazimierz:*", 0.5], ["sami:medical", 0.3], ["fx_vic", 0.4], ["fx_kaz", 0.3]],
	"vic": [["karlan:*", -0.4], ["fx_kje", -0.5]],
	"sar": [["*:trinket", 0.6]],
	"lmd": [["lungmen:*", -0.3], ["rat:*", -0.3]],
	"urs": [["ursus:*", 0.4], ["reunion:*", 0.4]],
	"kje": [["karlan:*", 0.3]],
	"kaz": [["kazimierz:*", 0.5]],
	"sir": [["rat:weapon", -0.2]],
	"sam": [["sami:*", 0.5]],
}

## Live units per 赤金, kept by MarketState after every step (like Economy.fx).
static var live := {}

static func is_currency(cur: String) -> bool:
	return LIST.has(cur)

## A foreign account currency: not 龙门币 (game.gold) and not 赤金.
static func foreign() -> Array[String]:
	var out: Array[String] = []
	for c in ORDER:
		if c != "lmd": out.append(c)
	return out

static func book(cur: String) -> String:
	return str(LIST.get(cur, {}).get("book", ""))

static func books() -> Array[String]:
	var out: Array[String] = []
	for c in ORDER: out.append(book(c))
	return out

static func of_book(market: String) -> String:
	for c in ORDER:
		if book(c) == market: return c
	return ""

static func is_fx(market: String) -> bool:
	return not of_book(market).is_empty()

# --- Against 龙门币 (用户 2026-10-25: 只做龙门币和其他货币的) ---------------------------
## "x_col" = 金券 / 龙门币: 1 金券 in 龙门币, derived from the two books over 赤金,
## never a market of its own (no events, no pressure; it moves when they do).
const CROSS_PREFIX := "x_"

static func cross(cur: String) -> String:
	return CROSS_PREFIX + cur

static func crosses() -> Array[String]:
	var out: Array[String] = []
	for c in foreign(): out.append(cross(c))
	return out

static func is_cross(id: String) -> bool:
	return id.begins_with(CROSS_PREFIX) and LIST.has(id.substr(CROSS_PREFIX.length()))

## The foreign currency of a cross ("x_col" -> "col").
static func cross_cur(id: String) -> String:
	return id.substr(CROSS_PREFIX.length()) if is_cross(id) else ""

## A rate book or a cross: what the 外汇 page lists.
static func is_money(id: String) -> bool:
	return is_fx(id) or is_cross(id)

static func info(cur: String) -> Dictionary:
	return LIST.get(cur, {})

static func name_of(cur: String) -> String:
	if cur == "gold": return "赤金"
	return str(info(cur).get("name", cur))

static func unit(cur: String) -> String:
	if cur == "gold": return "赤金"
	return str(info(cur).get("unit", cur))

static func base(cur: String) -> float:
	return float(info(cur).get("base", 1.0))

## Units of `cur` per 赤金 now (赤金 itself: 1).
static func rate(cur: String) -> float:
	if cur == "gold": return 1.0
	if cur == "lmd": return maxf(Economy.fx, 1.0)
	return maxf(float(live.get(cur, base(cur))), 0.0001)

## 龙门币 per unit of `cur` at the fixed base (quotas, notional caps; §4 of the
## exchange spec: 1 赤金 = 1000).
static func lmd_per_unit(cur: String) -> float:
	if cur == "gold": return Economy.GOLD_BAR_LMD
	if cur == "lmd" or not is_currency(cur): return 1.0
	return Economy.GOLD_BAR_LMD / base(cur)

## 龙门币 per unit of `cur` at today's rates.
static func live_lmd_per_unit(cur: String) -> float:
	if cur == "lmd" or (cur != "gold" and not is_currency(cur)): return 1.0
	return Economy.fx / rate(cur)

## The conversion spread between `from` and `to` (one of them may be 赤金).
static func spread(from: String, to: String) -> float:
	var s := 0.0
	for c in [from, to]:
		if c != "gold": s += float(info(c).get("spread", 0.005))
	return s * (CROSS_SHARE if from != "gold" and to != "gold" else 1.0)
