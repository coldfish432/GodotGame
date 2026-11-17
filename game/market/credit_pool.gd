class_name CreditPool
extends RefCounted

## §3.7 信贷池 (after Victoria 3's investment pool and credit): what everyone
## leaves idle is lent to whoever borrows. Supply: the actors' idle cash,
## Rhodes' deposits, the crowd's cash. Demand: what factions and firms owe and
## Rhodes' loan. Tightness = demand ÷ supply sets the base rate = the policy
## rate a day plus a tightness premium.

const PREMIUM := 0.0012        # a day at full tightness
const NEUTRAL := 0.5
const MIN_SUPPLY := 1000000.0

var supply := 0.0
var demand := 0.0
var rhodes_loan := 0.0
var rhodes_deposits := 0.0

func tightness() -> float:
	return clampf(demand / maxf(supply, MIN_SUPPLY), 0.0, 2.0)

## 龙门币's policy rate a day plus the premium (0.1%/天 near neutral, 待校准).
func base_rate(m: MarketState = null) -> float:
	var policy := (m.policy_rate("lmd") if m != null else 0.02) / 365.0
	return maxf(0.0002, policy + 0.0006 + PREMIUM * (tightness() - NEUTRAL))

## A borrower gets this much at most (the pool lends what is idle).
func can_lend(amount: float) -> bool:
	return demand + amount <= maxf(supply, MIN_SUPPLY) * 1.2

## Rebuilt from the actors each decision round.
func rebuild(actors: MarketActors, firms: Firms, rhodes_debt: float, deposits: float) -> void:
	rhodes_loan = rhodes_debt
	rhodes_deposits = deposits
	var s := deposits
	var d := rhodes_debt
	if actors != null:
		for f in actors.factions:
			var a: Dictionary = actors.factions[f]
			s += maxf(0.0, float(a.cash) * (1.0 - float(a.traits.get("cash", 0.5))) * 0.5)
			d += float(a.debt)
		for g in actors.groups: s += maxf(0.0, float(actors.groups[g].cash) * 0.3)
	if firms != null:
		for id in firms.firms:
			var f: Dictionary = firms.firms[id]
			s += maxf(0.0, Exchange.live_lmd(str(f.cur), float(f.cash)) * 0.2)
			d += Exchange.live_lmd(str(f.cur), float(f.debt))
	supply = s
	demand = d

func player_borrowed(amount: int) -> void: demand += amount
func player_repaid(amount: int) -> void: demand = maxf(0.0, demand - amount)

func to_data() -> Dictionary:
	return {"supply": supply, "demand": demand}

func load_data(d: Dictionary) -> void:
	supply = float(d.get("supply", 0.0))
	demand = float(d.get("demand", 0.0))
