class_name FeatureMeter
extends RefCounted
## 地图特色 for one contract (地图特色策划案_v1_0.md): 源石污染, 血债 and 寒冷,
## each 0–100. Every one starts at 0 at departure, follows her from floor to
## floor whole, and is gone at settlement. What raises one is multiplied by the
## depth step (FeatureCatalog.depth_mult) and by the base kit taken for it;
## what lowers one is not.

var values := {"contamination": 0.0, "debt": 0.0, "cold": 0.0}
## The highest step already announced, per feature.
var announced := {"contamination": 0, "debt": 0, "cold": 0}
## Base kits on this contract: feature -> [kit id, tier] (FeatureCatalog.KITS).
var kits := {}
## 科研部 (医疗部Ⅳ, the 源石尘抑制 project): what raises every feature is also × this.
var research_mult := 1.0
## 清算 (血债 90): seconds before another reckoning may be sent, and how many
## have been sent this contract (each stronger than the last).
var reckon_wait := 0.0
var reckonings := 0
## 营地处理 in the camp she is in: contamination done, 血债 payments made.
var camp_cleansed := false
var camp_debt_paid := 0
## The depth step last announced.
var depth_step := 0

func reset() -> void:
	for kind in values: values[kind] = 0.0
	for kind in announced: announced[kind] = 0
	kits = {}
	research_mult = 1.0
	reckon_wait = 0.0
	reckonings = 0
	camp_cleansed = false
	camp_debt_paid = 0
	depth_step = 0

func value(kind: String) -> float:
	return clampf(float(values[kind]), 0.0, FeatureCatalog.MAX)

func tier(kind: String) -> int:
	return FeatureCatalog.tier(value(kind))

## The kit's multiplier on what raises `kind` on `floor_number` (1 without one).
func kit_mult(kind: String, floor_number: int = 1) -> float:
	if not kits.has(kind): return 1.0
	var kit: Array = kits[kind]
	return 1.0 - FeatureCatalog.kit_cut(str(kit[0]), int(kit[1]), Economy.tier_of(floor_number))

## All that raises `kind` on `floor_number` is multiplied by this.
func growth_mult(kind: String, floor_number: int) -> float:
	return FeatureCatalog.depth_mult(floor_number) * kit_mult(kind, floor_number) * research_mult

## Raises `kind` by an amount already multiplied.
func add(kind: String, amount: float) -> void:
	values[kind] = clampf(float(values[kind]) + amount, 0.0, FeatureCatalog.MAX)

## Lowers `kind`; never below 0.
func reduce(kind: String, amount: float) -> void:
	values[kind] = clampf(float(values[kind]) - amount, 0.0, FeatureCatalog.MAX)

## The step `kind` has newly reached (0 when nothing new to announce). A fall
## lets the same step be announced again on the way back up.
func newly_reached(kind: String) -> int:
	var now := tier(kind)
	var before: int = announced[kind]
	announced[kind] = now
	return now if now > before else 0

## A camp: its fire clears the cold, its counters start again.
func enter_camp() -> void:
	values.cold = 0.0
	announced.cold = 0
	camp_cleansed = false
	camp_debt_paid = 0

## 赔偿金 in this camp: 2, 3, 4 … 赤金.
func camp_debt_price() -> int:
	return FeatureCatalog.CAMP_DEBT_BARS + camp_debt_paid

## A reckoning is due: 血债 at 90 or more and none sent in the last
## RECKONING_EVERY seconds. Ticks the wait by `delta`.
func reckoning_due(delta: float) -> bool:
	reckon_wait = maxf(0.0, reckon_wait - delta)
	return value("debt") >= FeatureCatalog.TIER_AT[2] and reckon_wait <= 0.0

## One sent: the wait starts and the families take their share.
func reckoning_sent() -> void:
	reckonings += 1
	reckon_wait = FeatureCatalog.RECKONING_EVERY
	reduce("debt", FeatureCatalog.RECKONING_PAYOFF)
