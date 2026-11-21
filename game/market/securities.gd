class_name Securities
extends RefCounted

## §3.1 / §3.3: what Rhodes holds besides money. Shares of the listed firms
## (paid and valued in the firm's currency at the live rate, dividends in cash
## or in kind), bonds (sovereign in a currency at its policy rate, corporate
## at a spread; prices move against the rate; defaults), the two funds (赤金,
## NAV over a basket, payout and fee follow the cycle) and 赤金存单 (earns the
## 赤金 demand rate, redeemable as bars for 0.5%).

const FX_SPREAD := 0.005
const BOND_DURATION := 3.0
## A year's coupon = the policy rate + BOND_PREMIUM (+ CORP_SPREAD for a firm),
## paid a 365th a day: 0.05–0.09% a day (§3.5, calibrated 2026-11-14).
const BOND_PREMIUM := 0.16
const CORP_SPREAD := 0.06
## 用户 2026-11-14 "时间太长了", then "3 / 7天": 3 / 7 days (was 30 / 90).
const BOND_TERMS := [3, 7]
const SOVEREIGN_DEFAULT_RATE := 0.15
const SOVEREIGN_DEFAULT_ODDS := 0.02
const DEFAULT_HAIRCUT := 0.4
const FUND_PAYOUT := 0.0004
const FUND_FEE := 0.0002
const FUNDS := {
	"karlan_fund": {"name": "喀兰稳健基金", "issuer": "karlan", "basket": ["swire", "penguin", "longitudinal", "sunherb", "blacksteel", "fengchi"], "bond": 0.4},
	"kaz_fund": {"name": "卡西米尔骑士基金", "issuer": "kazimierz", "basket": ["mieszko", "sunherb", "rose", "raythean", "venezia", "sunvalley"], "bond": 0.1},
}

var ex: Exchange
var shares := {}      # firm -> {n, cost} (cost: 龙门币 paid)
var bonds: Array = [] # {id, issuer (cur or firm), cur, face, coupon, rate0, due, corp}
var funds := {}       # fund -> {units, cost}
var fund_nav := {}    # fund -> NAV in 赤金
var fund_base := {}   # fund -> {firm: index at the base}
var cert := 0.0       # 赤金存单, in 赤金
var dividends: Array = []  # last payouts [day, firm, 龙门币, kind]
var _next_id := 1

func _init(p_ex: Exchange = null) -> void:
	ex = p_ex

func m() -> MarketState: return ex.market
func today() -> int: return MarketState.day_key(m().t)

# --- Shares -------------------------------------------------------------------------------

func share_price_lmd(firm: String) -> float:
	return m().firms.share_price_lmd(firm, m())

## 龙门币 of the firm's currency a 龙门币 buys, after the change spread.
static func _fx_cost(cur: String) -> float:
	return 1.0 if cur == "lmd" else 1.0 + FX_SPREAD

func buy_stock_refusal(firm: String, lmd: float) -> String:
	if not FirmCatalog.FIRMS.has(firm): return "无效"
	if lmd < 1000.0: return "最少 1,000"
	if ex.game.gold < ceili(lmd * _fx_cost(FirmCatalog.currency(firm))): return "龙门币不足"
	return ""

func buy_stock(firm: String, lmd: float) -> bool:
	if ex.blocked() or not buy_stock_refusal(firm, lmd).is_empty(): return false
	ex.game.gold -= ceili(lmd * _fx_cost(FirmCatalog.currency(firm)))
	var n: float = m().firms.buy_shares(m(), firm, lmd, "rhodes")
	var h: Dictionary = shares.get(firm, {"n": 0.0, "cost": 0.0})
	h.n = float(h.n) + n
	h.cost = float(h.cost) + lmd
	shares[firm] = h
	ex._log({"kind": "buy", "what": "%s ×%.1f 股" % [FirmCatalog.name_of(firm), n], "faction": "", "amount": lmd, "currency": "lmd"})
	return true

func sell_stock(firm: String, n: float) -> bool:
	if ex.blocked(): return false
	var h: Dictionary = shares.get(firm, {})
	if h.is_empty() or n <= 0.0: return false
	n = minf(n, float(h.n))
	var got: float = m().firms.sell_shares(m(), firm, n, "rhodes")
	if got <= 0.0: return false
	h.cost = float(h.cost) * (1.0 - n / maxf(float(h.n), 1e-9))
	h.n = float(h.n) - n
	if float(h.n) <= 1e-6: shares.erase(firm)
	ex.credit("lmd", got / _fx_cost(FirmCatalog.currency(firm)))
	ex._log({"kind": "sell", "what": "%s ×%.1f 股" % [FirmCatalog.name_of(firm), n], "faction": "", "amount": got, "currency": "lmd"})
	return true

func held(firm: String) -> float: return float((shares.get(firm, {}) as Dictionary).get("n", 0.0))

## A firm's dividend (Firms._pay_holders): cash into the firm's currency, or in kind (§3.3).
func on_dividend(firm: String, per_share_lmd: float) -> void:
	var n := held(firm)
	if n <= 0.0: return
	# A quarter is 7 trading days: ÷ scale of the design's (时间缩放策划案 v0.2 §6.3).
	var total := n * per_share_lmd * BaseState.day_share()
	var kind := str(FirmCatalog.info(firm).get("dividend", "cash"))
	var cur := FirmCatalog.currency(firm)
	if kind == "gold":
		# Whole bars; what is short of a bar comes as 龙门币 (货币精简与取整修订案 v1.0).
		var bars := int(total / Economy.GOLD_BAR_LMD)
		var rest := total - bars * Economy.GOLD_BAR_LMD
		if bars > 0: ex._deliver_goods(Economy.GOLD_ID, bars)
		ex.credit("lmd", rest)
	elif kind.begins_with("material:"):
		var mat := str(FirmCatalog.DIVIDEND_MATERIALS.get(kind.substr(9), ""))
		var each := RhodesFinance.unit_lmd(mat) if MaterialCatalog.MATERIALS.has(mat) else 0.0
		var count := int(total / each) if each > 0.0 else 0
		if count > 0: ex._deliver_goods(mat, count)
		ex.credit(cur, Exchange.from_lmd(cur, total - count * each))
	elif kind != "none":
		ex.credit(cur, Exchange.from_lmd(cur, total))
	ex.fin.today_in += total
	dividends.append([today(), firm, roundi(total), kind])
	if dividends.size() > 30: dividends = dividends.slice(dividends.size() - 30)

# --- Bonds --------------------------------------------------------------------------------

## The bonds on offer: every currency's sovereign, every firm's corporate.
func bond_issuers() -> Array:
	var out: Array = ["lmd"]
	out.append_array(Currencies.foreign())
	for f in FirmCatalog.ORDER: out.append("firm:" + f)
	return out

func bond_currency(issuer: String) -> String:
	return FirmCatalog.currency(issuer.substr(5)) if issuer.begins_with("firm:") else issuer

func bond_coupon(issuer: String) -> float:
	var cur := bond_currency(issuer)
	return maxf(0.0, m().policy_rate(cur) + BOND_PREMIUM + (CORP_SPREAD if issuer.begins_with("firm:") else 0.0))

## Price per 1 of face: down as the rate rises since it was bought (duration 3 years).
func bond_price(b: Dictionary) -> float:
	var r := m().policy_rate(str(b.cur))
	return clampf(1.0 - BOND_DURATION * (r - float(b.rate0)), 0.3, 1.5)

func buy_bond(issuer: String, lmd: float, days: int) -> bool:
	if ex.blocked() or lmd < 1000.0 or not days in BOND_TERMS: return false
	var cur := bond_currency(issuer)
	if ex.game.gold < ceili(lmd * _fx_cost(cur)): return false
	ex.game.gold -= ceili(lmd * _fx_cost(cur))
	bonds.append({"id": _next_id, "issuer": issuer, "cur": cur, "face": Exchange.from_lmd(cur, lmd), "coupon": bond_coupon(issuer), "rate0": m().policy_rate(cur),
		"due": today() + days, "corp": issuer.begins_with("firm:")})
	_next_id += 1
	return true

func sell_bond(id: int) -> bool:
	if ex.blocked(): return false
	for b in bonds:
		if int(b.id) == id:
			bonds.erase(b)
			ex.credit("lmd", Exchange.live_lmd(str(b.cur), float(b.face) * bond_price(b)) / _fx_cost(str(b.cur)))
			return true
	return false

func bond_value(b: Dictionary) -> float:
	return Exchange.live_lmd(str(b.cur), float(b.face) * bond_price(b))

# --- Funds and 赤金存单 -------------------------------------------------------------------

func nav(fund: String) -> float:
	return float(fund_nav.get(fund, 1.0))

## The basket's move since the last step, the bond part at the 赤金 rate, less the fee.
func _fund_day(fund: String) -> void:
	var info: Dictionary = FUNDS[fund]
	var base: Dictionary = fund_base.get(fund, {})
	var move := 0.0
	var n := 0
	for firm in info.basket:
		var b: MarketState.Book = m().stocks.get(firm)
		if b == null: continue
		var was := float(base.get(firm, b.i))
		move += b.i / maxf(was, 1e-6) - 1.0
		base[firm] = b.i
		n += 1
	fund_base[fund] = base
	var stock_part := (move / maxf(1.0, n)) * (1.0 - float(info.bond))
	var bond_part := float(info.bond) * ex.fin.demand_rate("gold") * 3.0
	var fee := FUND_FEE * m().econ.fund_fee_mult()
	fund_nav[fund] = maxf(0.05, nav(fund) * (1.0 + stock_part + bond_part - fee))

func fund_payout_rate() -> float:
	return FUND_PAYOUT * m().econ.fund_payout_mult()

## Bought with whole bars from the warehouse, sold back for whole bars (rounded).
func buy_fund(fund: String, gold: float) -> bool:
	var bars := roundi(gold)
	if ex.blocked() or not FUNDS.has(fund) or bars <= 0 or not ex.pay("gold", bars): return false
	var h: Dictionary = funds.get(fund, {"units": 0.0, "cost": 0.0})
	h.units = float(h.units) + bars / nav(fund)
	h.cost = float(h.cost) + bars
	funds[fund] = h
	return true

func sell_fund(fund: String, units: float) -> bool:
	if ex.blocked(): return false
	var h: Dictionary = funds.get(fund, {})
	if h.is_empty() or units <= 0.0: return false
	units = minf(units, float(h.units))
	h.cost = float(h.cost) * (1.0 - units / maxf(float(h.units), 1e-9))
	h.units = float(h.units) - units
	if float(h.units) <= 1e-6: funds.erase(fund)
	ex.credit("gold", units * nav(fund))
	return true

## 赤金存单 went with the 赤金 deposits (货币精简与取整修订案 v1.0, 拍板 Q1);
## `cert` is only an old save's, paid out as bars by Exchange.migrate_money.

# --- The day ------------------------------------------------------------------------------

func new_day() -> void:
	for f in FUNDS: _fund_day(f)
	# Fund payouts: a day's is a fraction of a bar, so it comes as 龙门币 at the live rate, rounded.
	for f in funds:
		var pay := float(funds[f].units) * nav(f) * fund_payout_rate() * Economy.fx * BaseState.day_share()
		ex.credit("lmd", pay)
		ex.fin.today_in += pay
	# Coupons, maturity, defaults.
	for b in bonds.duplicate():
		var cur := str(b.cur)
		ex.credit(cur, float(b.face) * float(b.coupon) / 365.0 * BaseState.day_share())
		if bool(b.corp):
			var firm := str(b.issuer).substr(5)
			if m().firms.equity(firm) < 0.0:
				_default(b)
				continue
		elif m().policy_rate(cur) > SOVEREIGN_DEFAULT_RATE and m().rng.randf() < SOVEREIGN_DEFAULT_ODDS * BaseState.day_share():
			_default(b)
			continue
		if int(b.due) <= today():
			bonds.erase(b)
			ex.credit(cur, float(b.face))

func _default(b: Dictionary) -> void:
	bonds.erase(b)
	ex.credit(str(b.cur), float(b.face) * (1.0 - DEFAULT_HAIRCUT))
	ex._say("%s债券违约，按 %d%% 兑付" % [FirmCatalog.name_of(str(b.issuer).substr(5)) if bool(b.corp) else Currencies.name_of(str(b.cur)), roundi((1.0 - DEFAULT_HAIRCUT) * 100)], "default")

func value_lmd() -> float:
	var v := 0.0
	for firm in shares: v += held(str(firm)) * share_price_lmd(str(firm))
	for b in bonds: v += bond_value(b)
	for f in funds: v += float(funds[f].units) * nav(str(f)) * Economy.fx
	v += cert * Economy.fx
	return v

## §3.7.1: shares, bonds, funds, certificates sold until `done` says enough.
func liquidate_until(done: Callable) -> void:
	for firm in shares.keys():
		if done.call(): return
		sell_stock(str(firm), held(str(firm)))
	for b in bonds.duplicate():
		if done.call(): return
		sell_bond(int(b.id))
	for f in funds.keys():
		if done.call(): return
		sell_fund(str(f), float(funds[f].units))

func to_data() -> Dictionary:
	return {"shares": shares.duplicate(true), "bonds": bonds.duplicate(true), "funds": funds.duplicate(true), "fund_nav": fund_nav.duplicate(), "fund_base": fund_base.duplicate(true),
		"cert": cert, "dividends": dividends.duplicate(true), "next_id": _next_id}

func load_data(d: Dictionary) -> void:
	shares = (d.get("shares", {}) as Dictionary).duplicate(true) if d.get("shares") is Dictionary else {}
	bonds = (d.get("bonds", []) as Array).duplicate(true) if d.get("bonds") is Array else []
	funds = (d.get("funds", {}) as Dictionary).duplicate(true) if d.get("funds") is Dictionary else {}
	fund_nav = (d.get("fund_nav", {}) as Dictionary).duplicate() if d.get("fund_nav") is Dictionary else {}
	fund_base = (d.get("fund_base", {}) as Dictionary).duplicate(true) if d.get("fund_base") is Dictionary else {}
	cert = maxf(0.0, float(d.get("cert", 0.0)))
	dividends = (d.get("dividends", []) as Array).duplicate(true) if d.get("dividends") is Array else []
	_next_id = maxi(1, int(d.get("next_id", 1)))
