class_name RhodesFinance
extends RefCounted

## 罗德岛运营与资产管理策划案 v0.12: what Rhodes spends and keeps.
## §2 the daily bill (罗德岛日账): every facility eats a family of PRTS
## materials out of the 罗德岛库存 (§2.5, one way in), what is short is bought
## at the cheapest live ask; salaries in each operator's home currency; the
## canteen's crop rations and 热餐 (§2.2.1). §3.1 demand and term deposits.
## §3.7.1 the credit line: limit off net worth, a floating daily rate, auto
## repayment, everything earned goes to an overdue debt, past twice the limit
## the holdings are sold. The 龙门币 balance itself is the 资金池 (v0.6).

## Per facility level a day, 龙门币 of base price, before the tier's index.
## Calibrated 2026-11-14 with tools/upkeep_model.py (§2.2: about 20% of what two
## runs a day bring in once the base is grown, run 30 on; 2–9% before that).
const UPKEEP_LMD := 2500.0
## The bill grows a little faster than income's index: income per run rises
## within a tier while the bill does not, so the share would fall off otherwise.
const UPKEEP_EXP := 1.6
## facility -> the family it eats, lowest tier first; one tier up every 3 tiers.
const UPKEEP := {
	"workshop": ["异铁碎片", "异铁", "异铁组"],
	"lab": ["破损装置", "装置", "全新装置"],
	"farm": ["酯原料", "聚酸酯"],
	"canteen": ["代糖", "糖"],
	"warehouse": ["螺栓", "螺母", "钉子", "金属板"],
	"outfit": ["研磨石", "化合切削液"],
	# 燃料储备修订案 v0.6: the hub burns fuel units, from the 燃料储备 (stock["燃料"]),
	# then the warehouse's cans, then bought by the cheapest unit (_pay_fuel).
	"hub": ["燃料"],
}
const UPKEEP_ORDER := ["hub", "warehouse", "outfit", "workshop", "lab", "farm", "canteen"]
const FACILITY_NAMES := {"workshop": "加工部", "lab": "科研部", "farm": "农业部", "canteen": "食堂", "warehouse": "仓储部", "outfit": "整备部", "hub": "基建总控台"}
const TIERS_PER_STEP := 3
## 科研 财务优化: the bill −10%.
const FINANCE_CUT := 0.9
## Salaries: 龙门币 a day per operator before the tier's index, paid in the home currency.
const SALARY_LMD := 1500.0
const HOME := {"amiya_guard": "lmd", "lappland": "sir", "hellagur": "urs", "rosa": "urs", "hoshiguma": "lmd", "lin": "lmd",
	"typhon": "sam", "santalla": "sam", "texas": "sir"}
## §2.4: what stops, in order, while the bill is unpaid.
const STOP_ORDER := ["strategies", "workshop", "farm", "lab"]
## §2.2.1: one base crop a day per operator aboard; the glowing ones are not rations.
const RATION_CROPS := ["舰载麦", "块茎薯", "温室豆"]
const HOT_MEAL_HP := 0.03
## §3.1 / §3.5 a day at the cycle's neutral point.
const DEMAND_RATE := {"lmd": 0.0002, "gold": 0.00015}
const TERM_DAYS := [1, 3, 7]
const TERM_RATE := {1: 0.0003, 3: 0.00045, 7: 0.0006}
const DEPOSIT_ISSUER := {"lmd": "龙门商会", "gold": "喀兰贸易"}
## §3.7 / §3.5: the credit line.
const LOAN_FACTOR := 0.5
const LOAN_FLOOR := 20000
const LOAN_BASE_RATE := 0.001
const LOAN_DEBT_PREMIUM := 0.002
const LOAN_RESEARCH := 0.8
const OVERDUE := 1.5
const SEVERE := 2.0
const RESERVE_DAYS := 3
const KEEP_BILLS := 30
const KEEP_WORTH := 60

var ex: Exchange
## 罗德岛库存: material -> count. Nothing ever comes back out.
var stock := {}
var harvest_to_stock := false
## 龙门币 only, whole (货币精简与取整修订案 v1.0); the 赤金 rate in DEMAND_RATE
## stays as the funds' bond yield. An old save's 赤金 or foreign deposits are
## paid out by Exchange.migrate_money.
var demand := {"lmd": 0}
var terms: Array = []          # {id, cur, amount, rate, days, due}
var auto_repay := true
var reserve_days := RESERVE_DAYS
var hot_day := -1
var stop_day := -1
var arrears := 0.0
var stopped: Array = []
var bills: Array = []          # {day, items: [{facility, material, from_stock, bought, cost}], salary, rations, hot, stopped, total, interest}
var worth: Array = []          # [day, net worth]
var today_in := 0.0
var today_out := 0.0
var _gold_mark := -1
## Everything the bills took off the balance this session (tests and the offline summary).
var paid_total := 0
var repaid_total := 0
var _next_id := 1
## 时间缩放策划案 v0.2 §6.3: a trading day pays ÷ scale of the design's day.
## What a facility's last bill took over its share (龙门币 of base price), and
## the rations eaten ahead, come off the next days' (whole units, no loss).
var carry := {}
var ration_carry := 0.0

func _init(p_ex: Exchange = null) -> void:
	ex = p_ex

func _game() -> GameManager: return ex.game

func today() -> int: return MarketState.day_key(ex.market.t)

# --- The tier ---------------------------------------------------------------------

## The income tier of the deepest camp unlocked (§2.2).
func tier() -> int:
	var g := _game()
	if g == null or g.research == null: return 0
	return Economy.tier_of(maxi(1, g.research.deepest_camp()))

static func upkeep_index(t: int) -> float:
	return pow(Economy.income_index(t), UPKEEP_EXP)

## The family member a facility eats at tier `t`.
static func material_for(facility: String, t: int) -> String:
	var fam: Array = UPKEEP.get(facility, [])
	if fam.is_empty(): return ""
	return str(fam[mini(t / TIERS_PER_STEP, fam.size() - 1)])

static func unit_lmd(material: String) -> float:
	if material == Fuel.RESERVE: return Fuel.unit_lmd()
	return float(MaterialCatalog.create(material, 1).unit_value * Economy.LMD_PER_VALUE)

## 龙门币 of base price `facility` uses a day now.
func need_lmd(facility: String) -> float:
	var g := _game()
	var level := g.base.facility_level(facility)
	if level <= 0: return 0.0
	var v := UPKEEP_LMD * level * upkeep_index(tier()) * BaseState.day_share()
	if g.base.researched("finance_opt"): v *= FINANCE_CUT
	if facility == "hub" and g.voyage != null and not g.voyage.sailing.is_empty(): v *= 2.0
	return v

func need_units(facility: String) -> int:
	var m := material_for(facility, tier())
	return 0 if m.is_empty() else maxi(0, ceili(_owed(facility) / unit_lmd(m) - 1e-9))

## Today's share less what the last bills took ahead (§6.3).
func _owed(facility: String) -> float:
	return need_lmd(facility) - float(carry.get(facility, 0.0))

# --- 罗德岛库存 (§2.5) --------------------------------------------------------------------

func stock_count(material: String) -> int: return int(stock.get(material, 0))

func _add_stock(material: String, count: int) -> void:
	if count > 0: stock[material] = stock_count(material) + count

func _take_stock(material: String, count: int) -> int:
	var n := mini(count, stock_count(material))
	if n <= 0: return 0
	stock[material] = stock_count(material) - n
	if int(stock[material]) <= 0: stock.erase(material)
	return n

## Why `material` cannot go into the 罗德岛库存 ("" when it can).
func transfer_refusal(material: String, count: int) -> String:
	if count <= 0: return "无效"
	if not can_stock(material): return "不消耗"
	if _game().material_count(material) < count: return "数量不足"
	return ""

## What the base eats: the upkeep families and the ration crops.
static func can_stock(material: String) -> bool:
	if material in RATION_CROPS: return true
	# Fuel is poured in (pour_in), not moved as goods.
	if material == Fuel.RESERVE: return false
	for f in UPKEEP:
		if material in UPKEEP[f]: return true
	return false

## One way: off the warehouse (and pack in the base) into the 罗德岛库存.
func transfer_in(material: String, count: int) -> bool:
	if ex.blocked() or not transfer_refusal(material, count).is_empty(): return false
	if not _game().consume_materials({material: count}): return false
	_add_stock(material, count)
	return true

## A harvest goes straight in when the switch is on (§2.5).
func harvest_in(crop: String, count: int) -> bool:
	if not harvest_to_stock or not crop in RATION_CROPS: return false
	_add_stock(crop, count)
	return true

## Days the stock of `facility`'s family lasts at today's use.
func days_left(facility: String) -> float:
	var need := need_lmd(facility)
	if need <= 0.0: return INF
	return family_value(facility) / need

func family_value(facility: String) -> float:
	var v := 0.0
	for m in UPKEEP.get(facility, []): v += stock_count(str(m)) * unit_lmd(str(m))
	return v

func rations() -> int:
	if _game().base.facility_level("canteen") <= 0: return 0
	return _game().base.roster.size()

## Rations a trading day eats: the roster ÷ scale (§6.3).
func daily_rations() -> float:
	return rations() * BaseState.day_share()

## Whole rations today's meal takes, after what was eaten ahead.
func ration_need() -> int:
	return maxi(0, ceili(daily_rations() - ration_carry - 1e-9))

func crops_in_stock() -> int:
	var n := 0
	for c in RATION_CROPS: n += stock_count(c)
	return n

func ration_days() -> float:
	var r := daily_rations()
	return INF if r <= 0.0 else float(crops_in_stock()) / r

## Market value of the stock now (asks of the cheapest seller, else base price).
func stock_value() -> float:
	var v := 0.0
	for m in stock: v += stock_count(str(m)) * unit_lmd(str(m))
	return v

# --- 热餐 (§2.2.1) ------------------------------------------------------------------------

func hot_meal() -> bool: return hot_day >= 0 and hot_day == today()
func supply_stopped() -> bool: return stop_day >= 0 and stop_day == today()

## Takes today's rations, cheapest crops first. False (and nothing taken) when short.
func _eat_rations() -> bool:
	if rations() <= 0: return false
	var need := ration_need()
	if crops_in_stock() < need: return false
	ration_carry += need - daily_rations()
	var order := RATION_CROPS.duplicate()
	order.sort_custom(func(a, b): return unit_lmd(a) < unit_lmd(b) or (unit_lmd(a) == unit_lmd(b) and RATION_CROPS.find(a) < RATION_CROPS.find(b)))
	var left := need
	for c in order: left -= _take_stock(c, left)
	return true

## 开饭: the rations made up today serve at once (§2.2.1).
func serve_refusal() -> String:
	if rations() <= 0: return "需要食堂"
	if hot_meal(): return "已开饭"
	if crops_in_stock() < ration_need(): return "作物不足"
	return ""

func serve_now() -> bool:
	if ex.blocked() or not serve_refusal().is_empty(): return false
	if not _eat_rations(): return false
	hot_day = today()
	stop_day = -1
	if not bills.is_empty() and int(bills[-1].day) == today():
		bills[-1].hot = true
		bills[-1].rations = daily_rations()
	return true

# --- The daily bill (§2) ------------------------------------------------------------------

## The cheapest seller of `material` now: {faction, unit_lmd, currency, unit, market} or {}.
func cheapest(material: String) -> Dictionary:
	var best := {}
	for f in FactionCatalog.ORDER:
		var q := ex.quote_buy(str(f), material)
		if not q.ok: continue
		var each := Exchange.live_lmd(str(q.currency), float(q.unit))
		if best.is_empty() or each < float(best.unit_lmd):
			best = {"faction": str(f), "unit_lmd": each, "currency": str(q.currency), "unit": float(q.unit), "market": str(q.get("market", ""))}
	return best

## What one family's day costs: from the stock, lowest tier first by value, the
## rest bought as today's tier (or the next one on sale).
func _pay_family(facility: String, out: Dictionary) -> float:
	if facility == "hub": return _pay_fuel(out)
	if need_lmd(facility) <= 0.0: return 0.0
	var owed := _owed(facility)
	if owed <= 0.0:
		carry[facility] = -owed
		return 0.0
	var need := owed
	var fam: Array = UPKEEP[facility]
	var used := {}
	for m in fam:
		if need <= 0.0: break
		var each := unit_lmd(str(m))
		var n := mini(stock_count(str(m)), ceili(need / each))
		if n > 0:
			_take_stock(str(m), n)
			used[str(m)] = n
			need -= n * each
	var bought := 0
	var cost := 0.0
	var material := material_for(facility, tier())
	if need > 0.0:
		var seller := cheapest(material)
		if seller.is_empty():
			for m in fam:
				seller = cheapest(str(m))
				if not seller.is_empty():
					material = str(m)
					break
		if not seller.is_empty():
			bought = ceili(need / unit_lmd(material))
			cost = float(seller.unit_lmd) * bought
			if not str(seller.market).is_empty(): ex.market.add_flow(str(seller.market), unit_lmd(material) * bought, "rhodes_upkeep")
			need -= bought * unit_lmd(material)
	# Whole units: what they came to over the share is the next days' (§6.3;
	# at scale 1 each day rounds up on its own, as before).
	carry[facility] = maxf(0.0, -need) if BaseState.time_scale > 1 else 0.0
	out.items.append({"facility": facility, "material": material, "from_stock": used, "bought": bought, "cost": roundi(cost)})
	return cost

# --- 燃料储备 (燃料储备修订案 v0.6) -----------------------------------------------------

func fuel_reserve() -> int: return stock_count(Fuel.RESERVE)

func add_fuel(units: int) -> void: _add_stock(Fuel.RESERVE, units)

## The 燃料罐 on the warehouse's shelves and in its cases (not the pack or safe bag).
func warehouse_tanks() -> Array[Item]:
	var out: Array[Item] = []
	for item in _game().stash:
		if Fuel.is_tank(item): out.append(item)
	return out

func tank_fuel() -> int:
	var n := 0
	for t in warehouse_tanks(): n += t.fuel
	return n

## What the base can burn without buying: the reserve and the warehouse's cans.
func fuel_on_hand() -> int: return fuel_reserve() + tank_fuel()

## Takes up to `units`: the reserve first, then the warehouse's cans, the
## emptiest first so the full ones stay for builds (§4). {reserve, tanks, short}.
func take_fuel(units: int) -> Dictionary:
	var from_reserve := _take_stock(Fuel.RESERVE, units)
	var left := units - from_reserve
	var from_tanks := 0
	var tanks := warehouse_tanks().filter(func(t): return t.fuel > 0)
	tanks.sort_custom(func(a, b): return a.fuel < b.fuel)
	for t: Item in tanks:
		if left <= 0: break
		var n := mini(left, t.fuel)
		Fuel.set_fill(t, t.fuel - n)
		left -= n
		from_tanks += n
	return {"reserve": from_reserve, "tanks": from_tanks, "short": left}

## The cheapest fuel on sale now, per unit: barrels, full cans less the can, or
## 固体燃料 (§4). {faction, unit_lmd, material, market} or {}.
func cheapest_fuel() -> Dictionary:
	var best := {}
	for lot in [[Fuel.BARREL, Fuel.BARREL_UNITS, 0.0], [Fuel.TANK, Fuel.TANK_FULL, Fuel.TANK_SHELL * Economy.LMD_PER_VALUE], [Fuel.SOLID, Fuel.SOLID_UNITS, 0.0]]:
		var seller := cheapest(str(lot[0]))
		if seller.is_empty(): continue
		var each := maxf(0.0, float(seller.unit_lmd) - float(lot[2])) / float(lot[1])
		if best.is_empty() or each < float(best.unit_lmd):
			best = {"faction": seller.faction, "unit_lmd": each, "material": str(lot[0]), "market": str(seller.market)}
	return best

## Burns `units` for the base: what is held first, the rest bought at the
## cheapest unit (at base price when nobody sells). {reserve, tanks, bought, cost}.
func burn_fuel(units: int) -> Dictionary:
	var got := take_fuel(maxi(0, units))
	var bought := int(got.short)
	var cost := 0.0
	if bought > 0:
		var seller := cheapest_fuel()
		cost = (float(seller.unit_lmd) if not seller.is_empty() else Fuel.unit_lmd()) * bought
		if not seller.is_empty() and not str(seller.market).is_empty(): ex.market.add_flow(str(seller.market), Fuel.unit_lmd() * bought, "rhodes_upkeep")
	return {"reserve": int(got.reserve), "tanks": int(got.tanks), "bought": bought, "cost": cost}

## The hub's day (§4): its units, held fuel first.
func _pay_fuel(out: Dictionary) -> float:
	if need_lmd("hub") <= 0.0: return 0.0
	var units := need_units("hub")
	carry["hub"] = maxf(0.0, units * unit_lmd(Fuel.RESERVE) - _owed("hub")) if BaseState.time_scale > 1 else 0.0
	if units <= 0: return 0.0
	var r := burn_fuel(units)
	var used := {}
	if int(r.reserve) > 0: used["燃料储备"] = int(r.reserve)
	if int(r.tanks) > 0: used[Fuel.TANK] = int(r.tanks)
	out.items.append({"facility": "hub", "material": Fuel.RESERVE, "from_stock": used, "bought": int(r.bought), "cost": roundi(float(r.cost))})
	return float(r.cost)

## Why `item` cannot be poured into the reserve ("" when it can).
func pour_refusal(item: Item) -> String:
	if ex.blocked(): return "只读"
	if not Fuel.is_fuel(item): return "不是燃料"
	if Fuel.units_of(item) <= 0: return "空罐"
	var g := _game()
	if not (g.stash.has(item) or (g.in_base and (g.inventory.items.has(item) or g.safe_bag.items.has(item)))): return "不在仓库"
	return ""

## One way into the 燃料储备: a can's fuel (the can stays, empty) or a whole
## 固体燃料 stack (§2). Returns the units poured.
func pour_in(item: Item) -> int:
	if not pour_refusal(item).is_empty(): return 0
	var units := Fuel.units_of(item)
	if Fuel.is_tank(item): Fuel.set_fill(item, 0)
	elif not _game()._hand_over(item): return 0
	add_fuel(units)
	return units

## Every can and 固体燃料 in the warehouse into the reserve.
func pour_all() -> int:
	var n := 0
	for item in _game().stash.duplicate():
		if Fuel.is_fuel(item) and Fuel.units_of(item) > 0: n += pour_in(item)
	return n

## A save's 燃料包 (gone, §3): OLD_PACK_UNITS each into the reserve, with a mail.
func migrate_fuel_packs() -> int:
	var g := _game()
	var packs := 0
	for item in g.stash.duplicate():
		if item.material_id == Fuel.OLD_PACK and g._hand_over(item): packs += item.quantity
	for bag in [g.inventory, g.safe_bag]:
		for item in bag.items.duplicate():
			if item.material_id == Fuel.OLD_PACK:
				bag.remove(item)
				packs += item.quantity
	if packs <= 0: return 0
	add_fuel(packs * Fuel.OLD_PACK_UNITS)
	if g.has_method("broadcast"): g.broadcast("PRTS：燃料包 ×%d → 燃料储备 +%d" % [packs, packs * Fuel.OLD_PACK_UNITS])
	return packs

## Salaries at the live rate of each home currency (§2.2).
func salary_lmd() -> float:
	var total := 0.0
	var idx := Economy.income_index(tier())
	for id in _game().base.roster:
		var cur := str(HOME.get(str(id), "lmd"))
		var amount := Exchange.from_lmd(cur, SALARY_LMD * idx * BaseState.day_share())
		total += Exchange.live_lmd(cur, amount)
	return total

## The 08:00 boundary (Exchange._new_day): the bill, rations, deposits, the loan.
func new_day() -> void:
	var g := _game()
	if g == null or g.base == null: return
	var bill := {"day": today(), "items": [], "salary": 0, "rations": 0, "hot": false, "stopped": [], "total": 0, "interest": 0, "borrowed": 0}
	var total := 0.0
	for f in UPKEEP_ORDER: total += _pay_family(f, bill)
	var sal := salary_lmd()
	bill.salary = roundi(sal)
	total += sal
	bill.total = roundi(total)
	_charge(total, bill)
	# The canteen's rations and 热餐.
	if rations() > 0:
		if _eat_rations():
			hot_day = today()
			stop_day = -1
			bill.rations = daily_rations()
			bill.hot = true
		else:
			hot_day = -1
			stop_day = today()
	else:
		hot_day = -1
		stop_day = -1
	_mature_terms()
	_deposit_interest()
	bill.interest = _loan_interest()
	if auto_repay: _auto_repay(bill)
	bill.stopped = stopped.duplicate()
	bills.append(bill)
	if bills.size() > KEEP_BILLS: bills = bills.slice(bills.size() - KEEP_BILLS)
	worth.append([today(), roundi(net_worth())])
	if worth.size() > KEEP_WORTH: worth = worth.slice(worth.size() - KEEP_WORTH)
	today_in = 0.0
	today_out = 0.0
	_mail_bill(bill)

func _charge(total: float, bill: Dictionary) -> void:
	var g := _game()
	var lmd := ceili(total)
	if g.gold < lmd:
		var short := lmd - g.gold
		var can := maxi(0, loan_limit() - ex.loan) if not loan_locked() else 0
		var take := mini(short, can)
		if take > 0:
			ex.loan += take
			g.gold += take
			bill.borrowed = take
	var paid := mini(lmd, g.gold)
	g.gold -= paid
	paid_total += paid
	today_out += paid
	arrears += lmd - paid
	_update_stops()

func _update_stops() -> void:
	stopped.clear()
	if arrears <= 0.5: return
	stopped = STOP_ORDER.duplicate()

func facility_stopped(id: String) -> bool:
	return arrears > 0.5 and id in stopped

## Arrears are paid as soon as there is money.
func _pay_arrears() -> void:
	if arrears <= 0.5: return
	var g := _game()
	var pay := mini(ceili(arrears), g.gold)
	if pay <= 0: return
	g.gold -= pay
	arrears = maxf(0.0, arrears - pay)
	_update_stops()

func _mail_bill(bill: Dictionary) -> void:
	var g := _game()
	if not g.has_method("broadcast") or not ex.unlocked(): return
	var line := "PRTS：运营账单 %s 龙门币%s%s" % [Economy.format(int(bill.total)), "  热餐" if bill.hot else ("  停发补给" if rations() > 0 else ""), ("  欠费 %s" % Economy.format(roundi(arrears))) if arrears > 0.5 else ""]
	g.broadcast(line)

# --- Deposits (§3.1) ----------------------------------------------------------------------

## The cycle's lift on deposit rates (±30%, §3.6); 1 before the cycle runs.
func cycle_mult() -> float:
	return ex.market.econ.deposit_mult() if ex.market.econ != null and ex.market.actors_on else 1.0

## Rates a trading day: the design's ÷ scale (§6.3).
func demand_rate(cur: String) -> float:
	return float(DEMAND_RATE.get(cur, 0.0)) * cycle_mult() * BaseState.day_share()

func term_rate(days: int) -> float:
	return float(TERM_RATE.get(days, 0.0)) * cycle_mult() * BaseState.day_share()

func deposit(cur: String, amount: float) -> bool:
	var whole := roundi(amount)
	if ex.blocked() or cur != "lmd" or whole <= 0: return false
	if not ex.pay(cur, whole): return false
	demand.lmd = int(demand.get("lmd", 0)) + whole
	return true

func withdraw(cur: String, amount: float) -> bool:
	var whole := roundi(amount)
	if ex.blocked() or cur != "lmd" or whole <= 0 or int(demand.get("lmd", 0)) < whole: return false
	demand.lmd = int(demand.lmd) - whole
	ex.credit(cur, whole)
	return true

func open_term(cur: String, amount: float, days: int) -> bool:
	var whole := roundi(amount)
	if ex.blocked() or cur != "lmd" or not days in TERM_DAYS or whole <= 0: return false
	if not ex.pay(cur, whole): return false
	terms.append({"id": _next_id, "cur": cur, "amount": whole, "rate": term_rate(days), "days": days, "due": today() + days})
	_next_id += 1
	return true

## Early: the principal back, the interest forfeit.
func break_term(id: int) -> bool:
	if ex.blocked(): return false
	for d in terms:
		if int(d.id) == id:
			terms.erase(d)
			ex.credit(str(d.cur), float(d.amount))
			return true
	return false

func _mature_terms() -> void:
	for d in terms.duplicate():
		if int(d.due) <= today():
			terms.erase(d)
			var paid := roundi(float(d.amount) * pow(1.0 + float(d.rate), int(d.days)))
			ex.credit(str(d.cur), paid)
			today_in += Exchange.live_lmd(str(d.cur), paid - float(d.amount))

## A day's interest on the demand deposit, rounded on its own (no remainder kept).
func _deposit_interest() -> void:
	for cur in demand.keys():
		var held := int(demand[cur])
		if held <= 0: continue
		var gain := roundi(held * demand_rate(str(cur)))
		demand[cur] = held + gain
		today_in += Exchange.live_lmd(str(cur), gain)

func deposits_lmd() -> float:
	var v := 0.0
	for cur in demand: v += Exchange.live_lmd(str(cur), float(demand[cur]))
	for d in terms: v += Exchange.live_lmd(str(d.cur), float(d.amount))
	return v

# --- Net worth (§3.7) ---------------------------------------------------------------------

## Everything at the live rate less the debt, the 罗德岛库存 included.
func net_worth() -> float:
	return ex.account_value() + deposits_lmd() + holdings_lmd() + stock_value()

## Securities and strategies (P3–P5), at market.
func holdings_lmd() -> float:
	var v := 0.0
	if ex.securities != null: v += ex.securities.value_lmd()
	if ex.strategies != null: v += ex.strategies.value_lmd()
	return v

# --- The credit line (§3.7, §3.7.1) -------------------------------------------------------

func loan_limit() -> int:
	var base := maxf(0.0, net_worth() - stock_value()) * LOAN_FACTOR
	var limit := maxi(LOAN_FLOOR, roundi(base))
	return roundi(limit * 1.5) if _game().base.researched("loan_terms") else limit

## The day's rate: the credit pool's base plus a premium near the limit.
func loan_rate(debt: int = -1) -> float:
	if debt < 0: debt = ex.loan
	var base: float = ex.market.credit.base_rate(ex.market) if ex.market.credit != null and ex.market.actors_on else LOAN_BASE_RATE
	var r := base + LOAN_DEBT_PREMIUM * clampf(float(debt) / maxf(1.0, loan_limit()), 0.0, 1.0)
	if _game().base.researched("loan_terms"): r *= LOAN_RESEARCH
	return r * BaseState.day_share()

func loan_locked() -> bool:
	return ex.loan > roundi(loan_limit() * OVERDUE)

func severe() -> bool:
	return ex.loan > roundi(loan_limit() * SEVERE)

func borrow(amount: int) -> bool:
	if ex.blocked(): return false
	if amount <= 0 or loan_locked() or ex.loan + amount > loan_limit(): return false
	ex.loan += amount
	_game().gold += amount
	_gold_mark = _game().gold
	if ex.market.credit != null: ex.market.credit.player_borrowed(amount)
	return true

func repay(amount: int) -> bool:
	if ex.blocked(): return false
	amount = mini(amount, ex.loan)
	if amount <= 0 or _game().gold < amount: return false
	_game().gold -= amount
	ex.loan -= amount
	_gold_mark = _game().gold
	if ex.market.credit != null: ex.market.credit.player_repaid(amount)
	return true

## Compounded once a trading day; a 商业联合会担保函 waives the day (§3.7.1).
func _loan_interest() -> int:
	if ex.loan <= 0: return 0
	var g := _game()
	if g.base.stock().any(func(i): return i.material_id == "商业联合会担保函") and g.base.take_material("商业联合会担保函", 1): return 0
	var before := ex.loan
	ex.loan = ceili(ex.loan * (1.0 + loan_rate()))
	return ex.loan - before

func reserve() -> int:
	var last := float(bills[-1].total) if not bills.is_empty() else 0.0
	return roundi(last * reserve_days)

func _auto_repay(bill: Dictionary) -> void:
	if ex.loan <= 0: return
	var spare := _game().gold - reserve()
	if spare <= 0: return
	var pay := mini(spare, ex.loan)
	_game().gold -= pay
	ex.loan -= pay
	repaid_total += pay
	bill["repaid"] = pay
	if ex.market.credit != null: ex.market.credit.player_repaid(pay)

## Every step: arrears first; an overdue debt takes all 龙门币 income; past
## twice the limit the holdings are sold back to 1.5× (§3.7.1).
func step() -> void:
	var g := _game()
	if g == null: return
	if _gold_mark < 0: _gold_mark = g.gold
	var gained := g.gold - _gold_mark
	if gained > 0: today_in += gained
	_pay_arrears()
	if ex.loan > 0 and loan_locked() and g.gold > _gold_mark:
		var take := mini(g.gold - maxi(_gold_mark, 0), ex.loan)
		if take > 0:
			g.gold -= take
			ex.loan -= take
			repaid_total += take
	if ex.loan > 0 and severe(): liquidate()
	_gold_mark = g.gold

## Sells in the plan's order until the debt is back to 1.5× the limit:
## strategies → shares, bonds, funds → term deposits → demand deposits.
func liquidate() -> void:
	var target := func(): return ex.loan <= roundi(loan_limit() * OVERDUE)
	if ex.strategies != null and not target.call(): ex.strategies.liquidate_all("强制变卖")
	if ex.securities != null and not target.call(): ex.securities.liquidate_until(target)
	for d in terms.duplicate():
		if target.call(): break
		terms.erase(d)
		ex.credit(str(d.cur), float(d.amount))
	for cur in demand.keys():
		if target.call(): break
		var held := float(demand[cur])
		if held > 0.0:
			demand[cur] = 0
			ex.credit(str(cur), held)
	# What came in pays the debt.
	var g := _game()
	var pay := mini(g.gold, ex.loan)
	g.gold -= pay
	ex.loan -= pay
	g.broadcast("PRTS：欠款超过额度两倍，已变卖持仓还款。")

# --- Saving -------------------------------------------------------------------------------

func to_data() -> Dictionary:
	return {"stock": stock.duplicate(), "harvest_to_stock": harvest_to_stock, "demand": demand.duplicate(), "terms": terms.duplicate(true),
		"auto_repay": auto_repay, "reserve_days": reserve_days, "hot_day": hot_day, "stop_day": stop_day, "arrears": arrears,
		"stopped": stopped.duplicate(), "bills": bills.duplicate(true), "worth": worth.duplicate(true), "today_in": today_in, "today_out": today_out, "next_id": _next_id,
		"carry": carry.duplicate(), "ration_carry": ration_carry}

func load_data(d: Dictionary) -> void:
	stock = {}
	var s: Variant = d.get("stock", {})
	if s is Dictionary:
		for m in s:
			if int(s[m]) <= 0: continue
			# Cans and 固体燃料 moved in before the 燃料储备 are its units now (§7).
			if str(m) == Fuel.TANK: _add_stock(Fuel.RESERVE, int(s[m]) * Fuel.TANK_FULL)
			elif str(m) == Fuel.SOLID: _add_stock(Fuel.RESERVE, int(s[m]) * Fuel.SOLID_UNITS)
			elif str(m) == Fuel.RESERVE or MaterialCatalog.MATERIALS.has(str(m)): _add_stock(str(m), int(s[m]))
	harvest_to_stock = bool(d.get("harvest_to_stock", false))
	demand = {"lmd": 0}
	var dm: Variant = d.get("demand", {})
	if dm is Dictionary:
		for cur in dm:
			# Whole 龙门币; anything else is an old save's, for Exchange.migrate_money.
			if str(cur) == "lmd": demand.lmd = maxi(0, roundi(float(dm[cur])))
			elif cur in DEMAND_RATE and float(dm[cur]) > 0.0: demand[cur] = float(dm[cur])
	terms = (d.get("terms", []) as Array).duplicate(true) if d.get("terms") is Array else []
	auto_repay = bool(d.get("auto_repay", true))
	reserve_days = clampi(int(d.get("reserve_days", RESERVE_DAYS)), 0, 30)
	hot_day = int(d.get("hot_day", -1))
	carry = (d.get("carry", {}) as Dictionary).duplicate() if d.get("carry") is Dictionary else {}
	ration_carry = float(d.get("ration_carry", 0.0))
	stop_day = int(d.get("stop_day", -1))
	arrears = maxf(0.0, float(d.get("arrears", 0.0)))
	stopped = (d.get("stopped", []) as Array).duplicate() if d.get("stopped") is Array else []
	bills = (d.get("bills", []) as Array).duplicate(true) if d.get("bills") is Array else []
	worth = (d.get("worth", []) as Array).duplicate(true) if d.get("worth") is Array else []
	today_in = float(d.get("today_in", 0.0))
	today_out = float(d.get("today_out", 0.0))
	_next_id = maxi(1, int(d.get("next_id", 1)))
	_gold_mark = -1
