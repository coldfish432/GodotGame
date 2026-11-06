class_name Exchange
extends RefCounted

## The Doctor's account at the exchange (势力与交易所策划案_v0_7.md §1, §5–§11):
## the 赤金 account held by 喀兰贸易, relations with the factions, spot trades,
## orders, forwards (physical delivery), CFDs (cash-settled, profit uncapped),
## 可露希尔's loan, the money changer and 企鹅物流 shipments. 龙门币 stay in
## GameManager.gold; everything here works through `game`.
##
## Prices: an item's base is its 交付价 (Economy.price). A faction pays
## base × preference × bid, less slippage and the remote fee; a 赤金 or
## foreign-currency faction converts at the fixed base (§4; 莱茵生命 in 金券,
## 地区货币策划案 §1.5). Leverage follows Japan's caps by kind of underlying
## (地区货币策划案 §9), losses stop at the margin: the balance never goes
## negative (用户: 不做穿仓负余额).

## Relation ranks climb like Grim Dawn's reputation (沙盘航行策划案 §1, 用户
## 2026-10-19): each rank needs more than the last. RANK_AT[r] is where Rr starts.
const RANK_AT := [0, 150, 500, 1000, 2500, 5000]
## What each rank is called (用户 2026-11-02: 声望等级改为具体名称).
const RANK_NAMES := ["冷漠", "中立", "友好", "尊敬", "崇敬", "崇拜"]
## 势力声望解锁策划案 v0.1 (用户 2026-11-02 拍板). §2.1: what each rank pays
## and fetches; a shelf never sells below what the same faction pays for it × 1.01.
const RANK_BUY := [1.05, 1.0, 0.97, 0.94, 0.91, 0.88]
const RANK_SELL := [0.95, 1.0, 1.01, 1.02, 1.03, 1.05]
const BUY_FLOOR := 1.01
## §2.2: a special one rank above its door −10%, two and more −20%.
const SPECIAL_OFF := [1.0, 0.9, 0.8]
const RELATION_MAX := 5000
## Where each faction starts, by its attitude to Rhodes in the story (用户
## 2026-11-02, 势力声望解锁策划案 §2.6; the same tiers as RELATION_EXPECTED):
## 喀兰贸易 and 萨米 are old friends (友好); 龙门商会, 莱茵生命 and 企鹅物流 trade
## with Rhodes under agreements, 鼠王 keeps an eye on it (中立); 卡西米尔's
## tolerance is for show, 乌萨斯's mines hate the infected and 整合运动's
## remnants have fought Rhodes (冷漠). Old saves are raised to these once.
const START_RELATIONS := {"karlan": 500, "sami": 500, "lungmen": 300, "rhine": 300, "penguin": 300, "rat": 150,
	"kazimierz": 100, "ursus": 0, "reunion": 0}
## Above its expected value a relation is corrected every trading day by
## E × (DRIFT_BASE + DRIFT_PER_1000 × E / 1000), E the excess (用户 2026-10-19).
const DRIFT_BASE := 0.01
const DRIFT_PER_1000 := 0.01
## Saves before the ladder had 100 a rank up to 500.
const OLD_RANK_STEP := 100
const RELATION_SCALE := 2
const REMOTE_FEE := 0.04
const FEE_STEP := 0.005
const FEE_MIN := 0.01
const SLIP_MAX := 0.3
const QUOTA_STEP := 20000.0
const QUOTA_REGEN := 0.10          # of the cap every QUOTA_REGEN_SECS
const QUOTA_REGEN_SECS := 600.0
## Forwards (§8): terms in seconds and their premium; leverage needs this rank.
const TERMS := [3600, 14400, 86400, 259200]
const TERM_NAMES := ["1 小时", "4 小时", "1 日", "3 日"]
const TERM_PREMIUM := [0.005, 0.01, 0.02, 0.04]
## Leverage by kind (地区货币策划案 §9.2, 用户 2026-10-25: 杠杆用现实日本的限制):
## a rate book is FX (25×), a faction composite a stock index (10×), a goods
## book and every forward a commodity (20×; contraband the same, 拍板 #7).
## The n-th step needs relation rank n.
const LEVERAGE_STEPS := {"fx": [1, 5, 10, 15, 20, 25], "index": [1, 2, 3, 5, 8, 10], "goods": [1, 3, 5, 10, 15, 20]}
## Opening a forward: of the notional, whatever the leverage (§9.4).
const FORWARD_FEE := 0.005
const FORWARD_SLOTS := 3
## The old warning, for positions opened before the caps (no "cap" on them).
const WARN_RATIO := 0.3
## Maintenance (§9.3): equity over the margin the cap asks for. Under 100% a
## call until the next 08:00, under 50% closed at once.
const CALL_RATIO := 1.0
const CUT_RATIO := 0.5
const DEFAULT_RELATION := -40
const DEFAULT_MIN_COOLDOWN := 6 * 3600
const DELIVERY_RELATION := 10
## CFDs (§9).
const CFD_FEE := 0.0005
## A day on goods and composites (≈7% a year, §9.4); rate books pay or charge
## the swap of their currency's policy rate instead.
const CFD_OVERNIGHT := 0.0002
const CFD_NOTIONAL_STEP := 50000.0
## Orders (§7).
const ORDER_FEE := 0.005
const ORDER_SLOTS := 3
const ORDER_TERMS := {"session": -1, "1d": 1, "3d": 3, "7d": 7, "settle": 0}
## Loans (§10, 先照用).
const LOAN_STEP := 56000
const LOAN_CAP := 560000
const LOAN_TIERS := [[28000, 0.01], [140000, 0.02], [280000, 0.03], [INF, 0.04]]
const LOAN_OVERDUE := 1.5
## 企鹅物流 (§11).
const SHIP_FEE := 0.10
const SHIP_FEE_MIN := 0.05
const SHIP_RISK := 0.08
const SHIP_HOURS := Vector2i(2 * 3600, 4 * 3600)
const HISTORY_KEEP := 20
## The field region a contract runs in, as the news names it (事件表 §10).
const CONTRACT_REGIONS := {"mine": "乌萨斯", "city": "龙门", "snow": "萨米", "siracusa": "叙拉古"}
const WATCH_MAX := 12

var game: GameManager
var market: MarketState
var gold_account := 0.0
## Foreign currencies (地区货币策划案 §1.2): balances only, never an item.
var fx_accounts := {}
var relations := {}
## The ranks whose gift each faction has sent (势力声望解锁策划案 §2.4): faction -> [rank].
var rank_gifts := {}
var quota_used := {}          # faction -> 龙门币 equivalent bought
var orders: Array = []
var forwards: Array = []
var cfds: Array = []
var forward_cooldown := {}    # faction -> until
var loan := 0
var shipments: Array = []
var history: Array = []
var watch: Array[String] = []
var alerts: Array = []        # {id, market, op: ">=" / "<=", price}
var cfd_day := {"day": 0, "pending_lmd": 0.0, "pending_gold": 0.0}
var recent_sales := {}        # faction -> 龙门币 sold recently, for news weights
var counters := {}            # offline summary: fills, liquidations, defaults, arrivals
var _next_id := 1
var _day := 0
## 1 once the account trades packs (交易包修订案 §7.3).
var packs_version := 1
## notify(text, kind): the game decides how to show it (PRTS log in the field).
var notify := Callable()

func setup(p_game: GameManager, p_market: MarketState) -> void:
	game = p_game
	market = p_market
	market.on_step = on_step
	market.weight_hook = _news_weight
	if relations.is_empty(): relations = START_RELATIONS.duplicate()
	_start_attitude()
	_day = MarketState.day_key(market.t)
	if int(cfd_day.day) == 0: cfd_day.day = _day

var start_attitude := false

## Once per account: each faction at least where it starts, and the ranks it
## starts at are not gifts (§2.4 sends them for ranks won).
func _start_attitude() -> void:
	if start_attitude: return
	start_attitude = true
	for f in START_RELATIONS:
		relations[f] = maxi(int(relations.get(f, 0)), int(START_RELATIONS[f]))
		var sent: Array = rank_gifts.get(f, [])
		for r in FactionRewards.GIFT_RANKS:
			if r <= rank_of(int(START_RELATIONS[f])) and not sent.has(r): sent.append(r)
		rank_gifts[f] = sent
func _id() -> int:
	_next_id += 1
	return _next_id - 1

func _say(text: String, kind: String) -> void:
	counters[kind] = int(counters.get(kind, 0)) + 1
	if notify.is_valid(): notify.call(text, kind)

func _log(entry: Dictionary) -> void:
	entry["t"] = market.t
	history.append(entry)
	if history.size() > HISTORY_KEEP: history = history.slice(history.size() - HISTORY_KEEP)

## Set while the market's own step runs (fills, expiries, liquidations), which
## go on in a read-only terminal too.
var _auto := false

## A read-only terminal or ticker refuses what the player does
## (交易终端与盯盘小窗策划案_v1_0.md §0-3); the market's own step is never refused.
func blocked() -> bool:
	return not _auto and game != null and not game.trade_block().is_empty()

# --- Relations, fees, quota --------------------------------------------------------

func relation(faction: String) -> int:
	return int(relations.get(faction, 0))

func rank(faction: String) -> int:
	return rank_of(relation(faction))

static func rank_name(r: int) -> String:
	return RANK_NAMES[clampi(r, 0, RANK_NAMES.size() - 1)]

## What `material` costs off its door rank: 1.0, 0.9 or 0.8 (§2.2).
func special_mult(faction: String, material: String) -> float:
	if not FactionSpecials.is_special(material): return 1.0
	return float(SPECIAL_OFF[clampi(rank(faction) - FactionSpecials.rank_needed(material), 0, SPECIAL_OFF.size() - 1)])

## 冷漠 (§2.5): no flash offers and no forwards.
func cold(faction: String) -> bool:
	return rank(faction) == 0

static func rank_of(value: int) -> int:
	var r := 0
	for i in range(RANK_AT.size()):
		if value >= int(RANK_AT[i]): r = i
	return r

## The day's correction for a relation of `value` against `expected` (0 at or below it).
static func drift(value: int, expected: int) -> int:
	var excess := value - expected
	if excess <= 0: return 0
	return mini(excess, ceili(excess * (DRIFT_BASE + DRIFT_PER_1000 * excess / 1000.0)))

func relation_drift(faction: String) -> int:
	var d := drift(relation(faction), int(FactionCatalog.RELATION_EXPECTED.get(faction, RELATION_MAX)))
	return roundi(d * 0.7) if game.base.researched("relation_drift") else d   # 商务部 3 阶

## Where the next rank starts (RELATION_MAX at R5).
static func next_rank_at(value: int) -> int:
	var r := rank_of(value)
	return int(RANK_AT[mini(r + 1, RANK_AT.size() - 1)])

## A pre-ladder value (100 a rank) at the same rank and progress on the ladder.
static func migrate_relation(old: int) -> int:
	var r := clampi(old / OLD_RANK_STEP, 0, RANK_AT.size() - 1)
	if r >= RANK_AT.size() - 1: return RELATION_MAX
	var f := float(old - r * OLD_RANK_STEP) / OLD_RANK_STEP
	return int(RANK_AT[r]) + roundi(f * (int(RANK_AT[r + 1]) - int(RANK_AT[r])))

func add_relation(faction: String, delta: int) -> void:
	if faction.is_empty() or not FactionCatalog.FACTIONS.has(faction): return
	var before := rank(faction)
	relations[faction] = clampi(relation(faction) + delta, 0, RELATION_MAX)
	if rank(faction) > before and game.has_method("broadcast"):
		game.broadcast("PRTS：%s关系达到%s。" % [FactionCatalog.name_of(faction), rank_name(rank(faction))])
	if delta > 0: send_gifts(faction)

## Each rank reached and not yet thanked for sends its gift to the receiving bay
## (§2.4; once ever, so a rank lost and won back sends nothing).
func send_gifts(faction: String) -> void:
	var sent: Array = rank_gifts.get(faction, [])
	for r in FactionRewards.GIFT_RANKS:
		if r > rank(faction) or sent.has(r): continue
		sent.append(r)
		var gift := FactionRewards.gift(faction, r)
		for id in gift:
			if id == "money":
				var cur := FactionCatalog.currency(faction)
				credit(cur, from_lmd(cur, float(gift.money)))
			else: _deliver_goods(str(id), int(gift[id]))
	rank_gifts[faction] = sent

## The remote fee (§5.4): 4%, −0.5% a rank, at least 1%, plus the market's own.
func remote_fee(faction: String, market_id: String = "") -> float:
	var base_fee := REMOTE_FEE - FEE_STEP * rank(faction) - (0.01 if game.base.researched("remote_fee") else 0.0)   # 商务部 1 阶
	var fee := maxf(FEE_MIN, base_fee) + float(FactionCatalog.info(faction).get("fee_extra", 0.0))
	return fee + (market.fee_extra(market_id) if not market_id.is_empty() else 0.0)

func quota_cap(faction: String) -> float:
	return QUOTA_STEP * (rank(faction) + 1) * market.quota_mult(faction)

func quota_left(faction: String) -> float:
	return maxf(0.0, quota_cap(faction) - float(quota_used.get(faction, 0.0)))

## Built at the base (基建设施修订案 v1.1 §三.7; its building waits for 喀兰贸易 R2).
func unlocked() -> bool:
	return game.base.facility_level("exchange") >= 1

# --- Money --------------------------------------------------------------------------------

func balance(currency: String) -> float:
	if currency == "gold": return gold_account
	if currency == "lmd": return float(game.gold)
	return float(fx_accounts.get(currency, 0.0))

## Funds free for margin: 龙门币 less what is owed (贷款不能当保证金).
func free_for_margin(currency: String) -> float:
	return float(game.gold - loan) if currency == "lmd" else balance(currency)

func pay(currency: String, amount: float) -> bool:
	if amount <= 0.0: return true
	if currency == "lmd":
		var lmd := ceili(amount)
		if game.gold < lmd: return false
		game.gold -= lmd
		return true
	if balance(currency) + 0.0001 < amount: return false
	_set_balance(currency, snappedf(balance(currency) - amount, 0.01))
	return true

func credit(currency: String, amount: float) -> void:
	if amount <= 0.0: return
	if currency == "lmd": game.gold += floori(amount)
	else: _set_balance(currency, snappedf(balance(currency) + amount, 0.01))

func _set_balance(currency: String, amount: float) -> void:
	if currency == "gold": gold_account = amount
	else: fx_accounts[currency] = amount

## 龙门币 equivalent of `amount` in `currency` at the fixed base rate (§4).
static func lmd_eq(currency: String, amount: float) -> float:
	return amount * Currencies.lmd_per_unit(currency)

static func from_lmd(currency: String, lmd: float) -> float:
	return lmd / Currencies.lmd_per_unit(currency)

static func format_money(currency: String, amount: float) -> String:
	if currency == "lmd": return "%s 龙门币" % Economy.format(roundi(amount))
	return "%.2f %s" % [amount, Currencies.unit(currency)]

## In the field 赤金 is whole bars: she pays a post rounded up, is paid rounded down.
static func field_bars(amount: float, buying: bool = false) -> int:
	return ceili(amount - 0.0001) if buying else floori(amount + 0.0001)

## A field price: the whole bars, the exact quote in brackets.
static func format_field(currency: String, amount: float, buying: bool = false) -> String:
	if currency != "gold": return format_money(currency, amount)
	return "%d 赤金 (%.2f)" % [field_bars(amount, buying), amount]

## Everything at the live rate, in 龙门币 (the account overview).
func account_value() -> float:
	var total := float(game.gold) + gold_account * Economy.fx - loan
	for c in fx_accounts: total += live_lmd(str(c), float(fx_accounts[c]))
	for f in forwards: total += live_lmd(str(f.currency), float(f.margin) + forward_pnl(f))
	for c in cfds: total += live_lmd(str(c.currency), float(c.margin) + cfd_pnl(c))
	return total

## 龙门币 at the live rate.
static func live_lmd(currency: String, amount: float) -> float:
	return amount * Currencies.live_lmd_per_unit(currency)

func margin_total() -> float:
	var total := 0.0
	for f in forwards: total += lmd_eq(f.currency, float(f.margin))
	for c in cfds: total += lmd_eq(c.currency, float(c.margin))
	return total

func floating() -> float:
	var total := 0.0
	for f in forwards: total += lmd_eq(f.currency, forward_pnl(f))
	for c in cfds: total += lmd_eq(c.currency, cfd_pnl(c))
	return total

# --- Spot ---------------------------------------------------------------------------------

func market_of(item: Item, faction: String) -> String:
	var category := FactionCatalog.category_of(item)
	if category.is_empty() or FactionCatalog.preference(faction, category) <= 0.0: return ""
	return "%s:%s" % [faction, category]

## Who would take this item, best first: [[faction, net in its currency, 龙门币 eq]].
func offers_for(item: Item, remote: bool = true) -> Array:
	var out: Array = []
	for f in FactionCatalog.trading():
		var q := quote_sell(item, f, remote)
		if q.ok: out.append([f, q.net, lmd_eq(q.currency, q.net)])
	out.sort_custom(func(a, b): return a[2] > b[2])
	return out

## What `faction` pays for `item` now: {ok, why, gross, slip, fee, net, currency, market}.
func quote_sell(item: Item, faction: String, remote: bool = true, flash_mult: float = 1.0) -> Dictionary:
	var out := {"ok": false, "why": "", "currency": FactionCatalog.currency(faction), "net": 0.0}
	var m := market_of(item, faction)
	if m.is_empty():
		out.why = "不收这类货"
		return out
	if remote and FactionCatalog.info(faction).get("field_only", false):
		out.why = "只能在局内据点交易"
		return out
	# The terminal trades packs only (交易包修订案 §6); posts still take loose goods.
	if remote and not Packs.is_pack(item.material_id):
		out.why = "只收交易包"
		return out
	if market.halted(m):
		out.why = "暂停收货"
		return out
	var category := FactionCatalog.category_of(item)
	var value := float(Economy.price(item)) * FactionCatalog.preference(faction, category)
	var slip := minf(SLIP_MAX, 0.5 * value / market.depth(m))
	var gross := value * market.bid(m) * (1.0 - slip) * flash_mult * float(RANK_SELL[rank(faction)])
	# 商会荣誉理事章: 龙门's posts pay more (势力声望解锁策划案 §三).
	if not remote and game.region_id == "city" and not game.in_base and FactionRewards.badge_on(game, "lungmen"): gross *= FactionRewards.COUNCIL_PAY
	var fee := remote_fee(faction, m) if remote else 0.0
	out.ok = true
	out.market = m
	out.slip = slip
	out.fee = fee
	out.gross = from_lmd(out.currency, gross)
	out.net = from_lmd(out.currency, gross * (1.0 - fee))
	if out.currency != "lmd": out.net = snappedf(out.net, 0.01)
	return out

## Sells `item` to `faction`. remote = at the terminal; false at a post or camp.
func sell_item(item: Item, faction: String, remote: bool = true, flash: Dictionary = {}) -> bool:
	if blocked(): return false
	var q := quote_sell(item, faction, remote, float(flash.get("mult", 1.0)))
	if not q.ok or not game._hand_over(item): return false
	# Face to face in the field she is paid in bars, into the pack.
	var field: bool = not remote and q.currency == "gold" and not game.in_base
	if field: game.give_gold_bars(field_bars(q.net))
	else: credit(q.currency, q.net)
	var value := float(Economy.price(item))
	market.add_pressure(q.market, value)
	var category := FactionCatalog.category_of(item)
	add_relation(faction, clampi(roundi(value / 5000.0), 1, 10))
	# 老鼠王的信物: 龙门商会 does not hear of what goes to the rat king.
	if category == "contraband" and not (faction == "rat" and FactionRewards.badge_on(game, "rat")):
		for rival in FactionCatalog.RIVALS.get(faction, []): add_relation(rival, -5)
	recent_sales[faction] = float(recent_sales.get(faction, 0.0)) + value
	_log({"kind": "sell", "what": item.display_name(), "faction": faction, "amount": float(field_bars(q.net)) if field else q.net, "currency": q.currency})
	return true

## Unit price of `material` from `faction`'s shelf: {ok, why, unit, currency, market}.
func quote_buy(faction: String, material: String) -> Dictionary:
	var out := {"ok": false, "why": "", "currency": FactionCatalog.currency(faction), "unit": 0.0}
	var shelf: Array = FactionCatalog.packs_sold(faction) if Packs.is_pack(material) else FactionCatalog.info(faction).get("sells", []) + FactionRewards.post_extra(faction, rank(faction))
	if not material in shelf:
		out.why = "不出售"
		return out
	# 势力特供 (势力特供策划案_v0_2 §二): only from their relation rank.
	if rank(faction) < FactionSpecials.rank_needed(material):
		out.why = "需要关系 %s" % rank_name(FactionSpecials.rank_needed(material))
		return out
	var category := FactionCatalog.material_category(material)
	var m := "%s:%s" % [faction, category]
	if not market.books.has(m):
		# Shelves outside its buying categories still follow its composite.
		m = ""
	var unit_lmd := float(MaterialCatalog.create(material, 1).unit_value * Economy.LMD_PER_VALUE)
	var mult := market.ask(m) if not m.is_empty() else market.composite(faction) * 1.04
	var base_price := unit_lmd * mult * special_mult(faction, material)
	var price := base_price * float(RANK_BUY[rank(faction)])
	# The rank's discount stops at what this faction pays for the same unit × 1.01
	# (§2.1); it never lifts a price above the one it had without the discount.
	if not m.is_empty() and FactionCatalog.preference(faction, category) > 0.0:
		var floor_price := unit_lmd * FactionCatalog.preference(faction, category) * market.bid(m) * float(RANK_SELL[rank(faction)]) * BUY_FLOOR
		price = maxf(price, minf(base_price, floor_price))
	out.ok = true
	out.market = m
	out.unit = from_lmd(out.currency, price)
	return out

func buy_material(faction: String, material: String, count: int, remote: bool = true, flash: Dictionary = {}) -> bool:
	if blocked(): return false
	if count <= 0: return false
	if remote and FactionCatalog.info(faction).get("field_only", false): return false
	# At the terminal: packs, and the 势力特供 (交易包修订案 §6).
	if remote and not Packs.is_pack(material) and not FactionSpecials.is_special(material): return false
	var q := quote_buy(faction, material)
	if not q.ok: return false
	var unit := float(q.unit) * float(flash.get("mult", 1.0))
	var fee := remote_fee(faction, str(q.market)) if remote else 0.0
	var cost := unit * count * (1.0 + fee)
	var eq := lmd_eq(q.currency, cost)
	if eq > quota_left(faction) + 0.5:
		_say("%s的买入额度不足" % FactionCatalog.name_of(faction), "refused")
		return false
	if not pay(q.currency, cost): return false
	quota_used[faction] = float(quota_used.get(faction, 0.0)) + eq
	_deliver_goods(material, count)
	add_relation(faction, clampi(roundi(eq / 5000.0), 1, 10))
	special_bought(material)
	_log({"kind": "buy", "what": "%s ×%d" % [material, count], "faction": faction, "amount": cost, "currency": q.currency})
	return true

## 下城区耳目 is the rat king's: 龙门商会 hears of every one bought (§二).
func special_bought(material: String) -> void:
	if material == "下城区耳目": add_relation(FactionSpecials.RAT_RIVAL, -FactionSpecials.RAT_RIVAL_COST)

## Bought goods arrive at the receiving bay, one sealed crate per stack.
func _deliver_goods(material: String, count: int) -> void:
	var left := count
	while left > 0:
		var stack := FactionRewards.as_goods(material, mini(left, MaterialCatalog.stack_size(material)))
		left -= stack.quantity
		# 商务部 6 阶: straight onto the shelves when there is room.
		if not (game.base.researched("forward_dock") and not game.base.store(stack).is_empty()): game.base.receive(stack)

# --- Flash offers (§6.1) ---------------------------------------------------------------

func flash_offer(id: int) -> Dictionary:
	for f in market.flash:
		if int(f.id) == id and int(f.until) > market.t and int(f.left) > 0: return f
	return {}

func sell_to_flash(id: int, item: Item, at_post: bool = false) -> bool:
	if blocked(): return false
	var offer := flash_offer(id)
	if offer.is_empty() or offer.kind != "buy" or FactionCatalog.category_of(item) != str(offer.category): return false
	var faction := str(offer.faction)
	if cold(faction): return false
	if FactionCatalog.info(faction).get("field_only", false) and not at_post: return false
	var value := float(Economy.price(item))
	if value > float(offer.left): return false
	if not sell_item(item, faction, not at_post, offer): return false
	offer.left = int(offer.left) - roundi(value)
	return true

func buy_from_flash(id: int, count: int, at_post: bool = false) -> bool:
	if blocked(): return false
	var offer := flash_offer(id)
	if offer.is_empty() or offer.kind != "sell" or count > int(offer.left): return false
	var faction := str(offer.faction)
	if cold(faction): return false
	if FactionCatalog.info(faction).get("field_only", false) and not at_post: return false
	if not buy_material(faction, str(offer.material), count, not at_post, offer): return false
	offer.left = int(offer.left) - count
	return true

# --- Orders (§7) --------------------------------------------------------------------------

func orders_with(faction: String) -> int:
	return orders.filter(func(o): return o.faction == faction).size()

func order_slots(faction: String) -> int:
	return ORDER_SLOTS + rank(faction)

func _order_expiry(term: String) -> int:
	var days := int(ORDER_TERMS.get(term, 1))
	if days == 0: return 0          # until the next settlement
	if days < 0: return MarketState.next_day_start(market.t)
	return MarketState.next_day_start(market.t) + (days - 1) * MarketState.DAY

func _escrow(item: Item) -> Dictionary:
	var data := item.to_data()
	game._hand_over(item)
	return data

func _return_item(data: Dictionary) -> void:
	var item := Item.from_data(data)
	if not game.base.receive_to_staging(item): game.base.receive(item)

## A limit sell (`kind` "limit") fills when the index reaches `price` (display
## units); a stop sell ("stop") sells at market once it falls to `price`.
func place_sell_order(item: Item, faction: String, kind: String, price: float, term: String = "1d") -> bool:
	if blocked(): return false
	var m := market_of(item, faction)
	if m.is_empty() or FactionCatalog.info(faction).get("field_only", false): return false
	if orders_with(faction) >= order_slots(faction): return false
	var fee := float(Economy.price(item)) * ORDER_FEE
	if not pay("lmd", fee): return false
	orders.append({"id": _id(), "type": kind, "side": "sell", "faction": faction, "market": m, "price": price,
		"item": _escrow(item), "expires": _order_expiry(term)})
	return true

func place_buy_order(faction: String, material: String, count: int, price: float, term: String = "1d") -> bool:
	if blocked(): return false
	if not Packs.is_pack(material): return false
	var q := quote_buy(faction, material)
	if not q.ok or str(q.market).is_empty() or FactionCatalog.info(faction).get("field_only", false): return false
	if orders_with(faction) >= order_slots(faction): return false
	var unit_lmd := float(MaterialCatalog.create(material, 1).unit_value * Economy.LMD_PER_VALUE)
	var reserve := from_lmd(q.currency, unit_lmd * count * price / 100.0 * (1.0 + remote_fee(faction)))
	if not pay("lmd", unit_lmd * count * ORDER_FEE) or not pay(q.currency, reserve): return false
	orders.append({"id": _id(), "type": "limit", "side": "buy", "faction": faction, "market": str(q.market), "price": price,
		"material": material, "count": count, "reserve": reserve, "currency": q.currency, "expires": _order_expiry(term)})
	return true

## "When `watch_market` goes `op` `price`, sell `item` to `faction` at market."
func place_conditional(watch_market: String, op: String, price: float, item: Item, faction: String, term: String = "1d") -> bool:
	if blocked(): return false
	var m := market_of(item, faction)
	if m.is_empty() or not market.books.has(watch_market) or orders_with(faction) >= order_slots(faction): return false
	if not pay("lmd", float(Economy.price(item)) * ORDER_FEE): return false
	orders.append({"id": _id(), "type": "cond", "side": "sell", "faction": faction, "market": m, "watch": watch_market, "op": op,
		"price": price, "item": _escrow(item), "expires": _order_expiry(term)})
	return true

func cancel_order(id: int) -> bool:
	if blocked(): return false
	for o in orders:
		if int(o.id) != id: continue
		orders.erase(o)
		if o.has("item"): _return_item(o.item)
		if o.has("reserve"): credit(str(o.currency), float(o.reserve))
		return true
	return false

func _tick_orders() -> void:
	for o in orders.duplicate():
		var expires := int(o.expires)
		if expires > 0 and market.t >= expires:
			cancel_order(int(o.id))
			continue
		var m := str(o.market)
		if market.locked(m) or market.halted(m): continue
		var faction := str(o.faction)
		var level := market.price(m)
		match str(o.type):
			"limit":
				if o.side == "sell" and level >= float(o.price): _fill_sell(o, float(o.price) / maxf(level, 0.01))
				elif o.side == "buy" and level <= float(o.price): _fill_buy(o)
			"stop":
				if level <= float(o.price): _fill_sell(o, 1.0)
			"cond":
				var w := market.price(str(o.watch))
				if market.locked(str(o.watch)): continue
				if (o.op == ">=" and w >= float(o.price)) or (o.op == "<=" and w <= float(o.price)): _fill_sell(o, 1.0)

func _fill_sell(o: Dictionary, scale: float) -> void:
	var item := Item.from_data(o.item)
	var q := quote_sell(item, str(o.faction), true)
	if not q.ok: return
	orders.erase(o)
	var net := float(q.net) * scale
	credit(str(q.currency), net)
	market.add_pressure(str(q.market), float(Economy.price(item)))
	add_relation(str(o.faction), clampi(roundi(float(Economy.price(item)) / 5000.0), 1, 10))
	_log({"kind": "fill", "what": item.display_name(), "faction": o.faction, "amount": net, "currency": q.currency})
	_say("挂单成交：%s → %s，%s" % [item.display_name(), FactionCatalog.name_of(str(o.faction)), format_money(str(q.currency), net)], "fill")

func _fill_buy(o: Dictionary) -> void:
	var q := quote_buy(str(o.faction), str(o.material))
	if not q.ok: return
	var cost := float(q.unit) * int(o.count) * (1.0 + remote_fee(str(o.faction)))
	var eq := lmd_eq(str(o.currency), cost)
	if eq > quota_left(str(o.faction)): return
	orders.erase(o)
	quota_used[o.faction] = float(quota_used.get(o.faction, 0.0)) + eq
	credit(str(o.currency), maxf(0.0, float(o.reserve) - cost))
	_deliver_goods(str(o.material), int(o.count))
	_log({"kind": "fill", "what": "%s ×%d" % [o.material, o.count], "faction": o.faction, "amount": cost, "currency": o.currency})
	_say("挂单成交：买入 %s ×%d" % [o.material, int(o.count)], "fill")

# --- Forwards (§8) ----------------------------------------------------------------------

## Packs `faction` writes forwards on (交易包修订案 §6): what it buys or sells.
func forward_materials(faction: String) -> Array[String]:
	return FactionCatalog.packs_traded(faction)

## Why a forward on `pack` in this direction cannot be written ("" = it can):
## she delivers what the faction buys, receives only what it sells (§3.3).
static func forward_side_refusal(faction: String, pack: String, deliver: bool) -> String:
	if not Packs.is_pack(pack): return "只做交易包"
	if deliver: return "" if FactionCatalog.preference(faction, Packs.category_of(pack)) > 0.0 else "不收这类货"
	return "" if FactionCatalog.packs_sold(faction).has(pack) else "只能交货"

## Unit spot of a material at a faction: what it pays (deliver) or asks (receive).
func material_spot(faction: String, material: String, deliver: bool) -> float:
	var currency := FactionCatalog.currency(faction)
	var unit_lmd := float(MaterialCatalog.create(material, 1).unit_value * Economy.LMD_PER_VALUE)
	var category := FactionCatalog.material_category(material)
	var m := "%s:%s" % [faction, category]
	if not market.books.has(m): return from_lmd(currency, unit_lmd * market.composite(faction))
	if deliver: return from_lmd(currency, unit_lmd * FactionCatalog.preference(faction, category) * market.bid(m))
	return from_lmd(currency, unit_lmd * market.ask(m))

## The contract price for a term: below spot to deliver, above it to receive.
func forward_price(faction: String, material: String, term: int, deliver: bool) -> float:
	var spot := material_spot(faction, material, deliver)
	return spot * (1.0 - TERM_PREMIUM[term]) if deliver else spot * (1.0 + TERM_PREMIUM[term])

# --- Leverage (地区货币策划案 §9) -------------------------------------------------------

static func leverage_kind(underlying: String) -> String:
	if Currencies.is_money(underlying): return "fx"
	if underlying.begins_with("comp:"): return "index"
	return "goods"

static func leverage_steps(underlying: String) -> Array:
	return LEVERAGE_STEPS[leverage_kind(underlying)]

## The cap for this kind: the margin it asks for is notional / cap.
static func leverage_cap(underlying: String) -> int:
	return int(leverage_steps(underlying).back())

## The rank a leverage needs on this kind, -1 when it is not offered.
static func rank_for(underlying: String, lev: int) -> int:
	return leverage_steps(underlying).find(lev)

## The highest step `rank` reaches.
static func max_leverage(underlying: String, r: int) -> int:
	var steps := leverage_steps(underlying)
	return int(steps[clampi(r, 0, steps.size() - 1)])

func forward_refusal(faction: String, lev: int) -> String:
	if FactionCatalog.info(faction).get("transport", false): return "不签合约"
	if int(forward_cooldown.get(faction, 0)) > market.t: return "违约冷却中"
	if cold(faction): return "需要关系 %s" % rank_name(1)
	var need := rank_for("goods", lev)
	if need < 0: return "杠杆不可用"
	if rank(faction) < need: return "需要关系 %s" % rank_name(need)
	if forwards.filter(func(f): return f.faction == faction).size() >= FORWARD_SLOTS + rank(faction): return "合约已满"
	return ""

## Opens a forward: `deliver` (交货合约) or receive (收货合约).
func open_forward(faction: String, material: String, count: int, term: int, deliver: bool, lev: int) -> bool:
	if blocked(): return false
	if count <= 0 or term < 0 or term >= TERMS.size() or rank_for("goods", lev) < 0: return false
	if not forward_refusal(faction, lev).is_empty() or not forward_side_refusal(faction, material, deliver).is_empty(): return false
	var currency := FactionCatalog.currency(faction)
	var k := forward_price(faction, material, term, deliver)
	var notional := k * count
	var margin := notional / lev
	var fee := notional * FORWARD_FEE
	if free_for_margin(currency) < margin + fee: return false
	if not pay(currency, margin + fee): return false
	forwards.append({"id": _id(), "dir": "deliver" if deliver else "receive", "faction": faction, "material": material, "count": count,
		"k": k, "margin": margin, "opening": margin, "lev": lev, "cap": leverage_cap("goods"), "currency": currency, "expires": market.t + TERMS[term], "opened": market.t, "warned": false, "auto": 0.0})
	_log({"kind": "forward", "what": "%s %s ×%d" % ["交货" if deliver else "收货", material, count], "faction": faction, "amount": margin, "currency": currency})
	return true

func forward_pnl(f: Dictionary) -> float:
	var spot := material_spot(str(f.faction), str(f.material), f.dir == "deliver")
	var diff := (float(f.k) - spot) if f.dir == "deliver" else (spot - float(f.k))
	return diff * int(f.count)

## The maintenance ratio (§9.3): equity over the margin the cap asks for. A
## position from before the caps measures against its own margin, as it did.
func margin_ratio(position: Dictionary, pnl: float) -> float:
	var need := float(position.margin)
	if position.has("cap"): need = position_notional(position) / float(position.cap)
	return (float(position.margin) + pnl) / maxf(need, 0.0001)

func position_notional(position: Dictionary) -> float:
	if position.has("notional"): return float(position.notional)
	return float(position.k) * int(position.count)

## Delivers the goods of a 交货合约 now: from the warehouse, then the bags
## (`warehouse_only` when it settles by itself while she is out in the field).
func deliver_forward(id: int, warehouse_only: bool = false) -> bool:
	if blocked(): return false
	for f in forwards:
		if int(f.id) != id or f.dir != "deliver": continue
		if warehouse_only:
			if not _consume_stash(str(f.material), int(f.count)): return false
		elif not game.consume_materials({str(f.material): int(f.count)}): return false
		forwards.erase(f)
		credit(str(f.currency), float(f.k) * int(f.count) + float(f.margin))
		add_relation(str(f.faction), DELIVERY_RELATION)
		_log({"kind": "delivered", "what": "%s ×%d" % [f.material, f.count], "faction": f.faction, "amount": float(f.k) * int(f.count), "currency": f.currency})
		_say("交割完成：%s ×%d → %s" % [f.material, int(f.count), FactionCatalog.name_of(str(f.faction))], "delivery")
		return true
	return false

## Pays the rest of a 收货合约 now and takes the goods.
func take_forward(id: int) -> bool:
	if blocked(): return false
	for f in forwards:
		if int(f.id) != id or f.dir != "receive": continue
		var rest := float(f.k) * int(f.count) - float(f.margin)
		if not pay(str(f.currency), rest): return false
		forwards.erase(f)
		_deliver_goods(str(f.material), int(f.count))
		add_relation(str(f.faction), DELIVERY_RELATION)
		_log({"kind": "delivered", "what": "%s ×%d" % [f.material, f.count], "faction": f.faction, "amount": rest, "currency": f.currency})
		_say("收货完成：%s ×%d 已入库" % [f.material, int(f.count)], "delivery")
		return true
	return false

func _consume_stash(material: String, count: int) -> bool:
	var have := 0
	for item in game.stash:
		if item.material_id == material: have += item.quantity
	if have < count: return false
	var need := count
	for item: Item in game.stash.duplicate():
		if need <= 0: break
		if item.material_id != material: continue
		var used := mini(need, item.quantity)
		need -= used
		if used < item.quantity: item.set_quantity(item.quantity - used)
		else: game.base.take_from_shelf(item)
	return true

func add_margin(id: int, amount: float) -> bool:
	if blocked(): return false
	for list in [forwards, cfds]:
		for p in list:
			if int(p.id) != id: continue
			if free_for_margin(str(p.currency)) < amount or not pay(str(p.currency), amount): return false
			p.margin = float(p.margin) + amount
			p.warned = false
			return true
	return false

## Auto top-up (挂单 "自动追加保证金"): refill to the opening margin; a capped
## position tops up below 100% (any `ratio` > 0 turns it on), an old one below `ratio`.
func set_auto_margin(id: int, ratio: float) -> void:
	if blocked(): return
	for list in [forwards, cfds]:
		for p in list:
			if int(p.id) == id: p.auto = ratio

func _default(f: Dictionary) -> void:
	forwards.erase(f)
	var faction := str(f.faction)
	add_relation(faction, DEFAULT_RELATION)
	forward_cooldown[faction] = maxi(MarketState.next_day_start(market.t), market.t + DEFAULT_MIN_COOLDOWN)
	_log({"kind": "default", "what": "%s ×%d" % [f.material, f.count], "faction": faction, "amount": f.margin, "currency": f.currency})
	_say("合约违约：%s，保证金没收，关系下降" % FactionCatalog.name_of(faction), "default")

func _tick_forwards() -> void:
	for f in forwards.duplicate():
		var pnl := forward_pnl(f)
		_watch_margin(f, pnl, "合约")
		if not forwards.has(f): continue
		if market.t < int(f.expires): continue
		# At expiry, settle by itself when it can (§8.3 离线到期).
		if f.dir == "deliver":
			if not deliver_forward(int(f.id), not game.in_base): _default(f)
		else:
			if not take_forward(int(f.id)): _default(f)

## Maintenance (§9.3, 拍板 #6): auto top-up below 100%; under 100% a call
## until the next 08:00, under 50% (or gapped through) closed at once at what
## is left. A position from before the caps keeps the old rule: warning at
## 30%, closed when the margin is gone.
func _watch_margin(p: Dictionary, pnl: float, what: String) -> void:
	if not p.has("cap"):
		_watch_old_margin(p, pnl, what)
		return
	var ratio := margin_ratio(p, pnl)
	if float(p.get("auto", 0.0)) > 0.0 and ratio < CALL_RATIO:
		var need := float(p.get("opening", p.margin)) - (float(p.margin) + pnl)
		if need > 0.0 and free_for_margin(str(p.currency)) >= need and pay(str(p.currency), need):
			p.margin = float(p.margin) + need
			ratio = margin_ratio(p, pnl)
	var call_due := int(p.get("call_until", 0)) > 0 and market.t >= int(p.call_until)
	if ratio < CUT_RATIO or (ratio < CALL_RATIO and call_due):
		_force_close(p, pnl, what)
		return
	if ratio >= CALL_RATIO:
		p.erase("call_until")
		p.warned = false
		return
	if not p.has("call_until"):
		p.call_until = MarketState.next_day_start(market.t)
		p.warned = true
		_say("追加保证金：%s维持率 %d%%" % [what, roundi(ratio * 100)], "warning")

## Closed by the exchange: what is left of the margin comes back, never less than nothing.
func _force_close(p: Dictionary, pnl: float, what: String) -> void:
	var back := maxf(0.0, float(p.margin) + pnl)
	if cfds.has(p):
		back = maxf(0.0, back - float(p.notional) * CFD_FEE)
		cfds.erase(p)
	if forwards.has(p): forwards.erase(p)
	credit(str(p.currency), back)
	_log({"kind": "liquidated", "what": what, "faction": p.get("faction", p.get("issuer", "")), "amount": back - float(p.margin), "currency": p.currency})
	_say("%s强制平仓：退回 %s" % [what, format_money(str(p.currency), back)], "liquidation")

func _watch_old_margin(p: Dictionary, pnl: float, what: String) -> void:
	var ratio := margin_ratio(p, pnl)
	if float(p.get("auto", 0.0)) > 0.0 and ratio < float(p.auto):
		var need := float(p.get("opening", p.margin)) - (float(p.margin) + pnl)
		if need > 0.0 and free_for_margin(str(p.currency)) >= need and pay(str(p.currency), need):
			p.margin = float(p.margin) + need
			ratio = margin_ratio(p, pnl)
	if ratio <= 0.0:
		if forwards.has(p): forwards.erase(p)
		if cfds.has(p): cfds.erase(p)
		_log({"kind": "liquidated", "what": what, "faction": p.get("faction", p.get("issuer", "")), "amount": p.margin, "currency": p.currency})
		_say("%s强制了结：保证金 %s 没收" % [what, format_money(str(p.currency), float(p.margin))], "liquidation")
		return
	if ratio < WARN_RATIO and not p.get("warned", false):
		p.warned = true
		_say("保证金预警：%s保证金率 %d%%" % [what, roundi(ratio * 100)], "warning")

# --- CFDs (§9) ---------------------------------------------------------------------------

## What a CFD can be written on: the rate books and crosses, category markets,
## faction composites (field-only factions left out).
func cfd_underlyings() -> Array[String]:
	var out: Array[String] = Currencies.books()
	out.append_array(Currencies.crosses())
	for id in FactionCatalog.trading():
		if FactionCatalog.info(id).get("field_only", false): continue
		out.append("comp:" + id)
	for m in market.books:
		if Currencies.is_fx(m): continue
		var f: String = FactionCatalog.split(m)[0]
		if not FactionCatalog.info(f).get("field_only", false): out.append(m)
	return out

static func cfd_issuer(underlying: String) -> String:
	return "kazimierz" if underlying.begins_with("comp:") else "karlan"

## The rate books against 赤金 and the composites settle in 赤金, 龙门币's book
## and the crosses in 龙门币, goods books in their faction's currency.
static func cfd_currency(underlying: String) -> String:
	if underlying == FactionCatalog.FX or Currencies.is_cross(underlying): return "lmd"
	if Currencies.is_fx(underlying) or underlying.begins_with("comp:"): return "gold"
	return FactionCatalog.currency(FactionCatalog.split(underlying)[0])

static func cfd_name(underlying: String) -> String:
	if underlying.begins_with("comp:"): return "%s综合指数" % FactionCatalog.name_of(underlying.substr(5))
	return FactionCatalog.market_name(underlying)

func cfd_price(underlying: String) -> float:
	if underlying.begins_with("comp:"): return market.composite(underlying.substr(5)) * 100.0
	return market.price(underlying)

func _cfd_half_spread(underlying: String) -> float:
	# CFDs trade on the book's level, not its goods: a thin slice of its spread.
	if Currencies.is_money(underlying) or underlying.begins_with("comp:"): return 0.001
	return 0.001 + market.spread(underlying) * 0.05

func cfd_pnl(c: Dictionary) -> float:
	var exit := cfd_price(str(c.underlying)) * (1.0 - float(c.dir) * _cfd_half_spread(str(c.underlying)))
	return float(c.dir) * (exit / float(c.entry) - 1.0) * float(c.notional)

func cfd_notional_used(issuer: String) -> float:
	var total := 0.0
	for c in cfds:
		if c.issuer == issuer: total += lmd_eq(str(c.currency), float(c.notional))
	return total

func cfd_notional_cap(issuer: String) -> float:
	return CFD_NOTIONAL_STEP * rank(issuer)

func cfd_refusal(underlying: String, lev: int, margin: float) -> String:
	var issuer := cfd_issuer(underlying)
	if market.cfd_halted(issuer): return "暂停开新仓"
	var need := rank_for(underlying, lev)
	if need < 0: return "杠杆不可用"
	if rank(issuer) < need: return "需要%s关系 %s" % [FactionCatalog.name_of(issuer), rank_name(need)]
	var currency := cfd_currency(underlying)
	var notional := margin * lev
	if cfd_notional_used(issuer) + lmd_eq(currency, notional) > cfd_notional_cap(issuer) + 0.5: return "持仓上限"
	if free_for_margin(currency) < margin * (1.0 + cfd_fee() * lev): return "保证金不足"
	return ""

func open_cfd(underlying: String, dir: int, lev: int, margin: float) -> bool:
	if blocked(): return false
	if not underlying in cfd_underlyings() or rank_for(underlying, lev) < 0 or margin <= 0.0 or absi(dir) != 1: return false
	if not cfd_refusal(underlying, lev, margin).is_empty(): return false
	var currency := cfd_currency(underlying)
	var notional := margin * lev
	if not pay(currency, margin + notional * cfd_fee()): return false
	var entry := cfd_price(underlying) * (1.0 + dir * _cfd_half_spread(underlying))
	cfds.append({"id": _id(), "underlying": underlying, "issuer": cfd_issuer(underlying), "dir": dir, "lev": lev, "margin": margin,
		"opening": margin, "notional": notional, "cap": leverage_cap(underlying), "entry": entry, "currency": currency, "opened": market.t, "tp": 0.0, "sl": 0.0, "warned": false, "auto": 0.0})
	_log({"kind": "cfd", "what": "%s %s %d×" % [cfd_name(underlying), "做多" if dir > 0 else "做空", lev], "faction": cfd_issuer(underlying), "amount": margin, "currency": currency})
	return true

func set_cfd_limits(id: int, tp: float, sl: float) -> void:
	if blocked(): return
	for c in cfds:
		if int(c.id) == id:
			c.tp = tp
			c.sl = sl

## Closes a CFD: the margin back plus the whole result; profit has no daily cap
## (用户 2026-10-23: 不设上限，玩的就是心跳).
func close_cfd(id: int, reason: String = "") -> bool:
	if blocked(): return false
	for c in cfds:
		if int(c.id) != id: continue
		cfds.erase(c)
		var pnl := cfd_pnl(c)
		var fee := float(c.notional) * CFD_FEE
		var currency := str(c.currency)
		var profit := pnl - fee
		var paid := float(c.margin) + minf(profit, 0.0)
		if profit > 0.0: paid += profit
		credit(currency, maxf(0.0, paid))
		_log({"kind": "closed", "what": cfd_name(str(c.underlying)), "faction": c.issuer, "amount": profit, "currency": currency})
		if not reason.is_empty(): _say("%s：%s %s" % [reason, cfd_name(str(c.underlying)), format_money(currency, profit)], "fill")
		return true
	return false

## Profit held back by the old daily cap, from saves before it went.
func cfd_pending() -> float:
	return float(cfd_day.pending_lmd) + float(cfd_day.pending_gold) * Economy.GOLD_BAR_LMD

func _tick_cfds() -> void:
	for c in cfds.duplicate():
		var pnl := cfd_pnl(c)
		_watch_margin(c, pnl, "差价合约")
		if not cfds.has(c): continue
		if not str(c.underlying).begins_with("comp:") and market.locked(str(c.underlying)): continue
		var price := cfd_price(str(c.underlying))
		var dir := int(c.dir)
		if float(c.tp) > 0.0 and ((dir > 0 and price >= float(c.tp)) or (dir < 0 and price <= float(c.tp))): close_cfd(int(c.id), "止盈")
		elif float(c.sl) > 0.0 and ((dir > 0 and price <= float(c.sl)) or (dir < 0 and price >= float(c.sl))): close_cfd(int(c.id), "止损")

## The 08:00 boundary: overnight fees and swaps, interest on the foreign
## accounts, 喀兰贸易's account fee while it lasts; profit an old save held
## back comes in.
func _new_day() -> void:
	for c in cfds.duplicate():
		c.margin = float(c.margin) + overnight(c)
		if c.margin <= 0.0:
			cfds.erase(c)
			_say("差价合约保证金被隔夜费耗尽，已了结", "liquidation")
	cfd_day.day = _day
	var pend_l := float(cfd_day.pending_lmd)
	var pend_g := float(cfd_day.pending_gold)
	cfd_day.pending_lmd = 0.0
	cfd_day.pending_gold = 0.0
	credit("lmd", pend_l)
	credit("gold", pend_g)
	if pend_l + pend_g > 0.0: _say("差价合约待入账 %s 龙门币已到账" % Economy.format(roundi(pend_l + pend_g * Economy.GOLD_BAR_LMD)), "cap")
	for f in recent_sales.keys(): recent_sales[f] = float(recent_sales[f]) * 0.5
	_interest()

## A day on a CFD: a rate book pays or charges the swap (long the book is long
## 赤金 against the currency: it pays the currency's rate), the rest a fee.
func overnight(c: Dictionary) -> float:
	var cur := Currencies.of_book(str(c.underlying))
	if not cur.is_empty(): return -float(c.dir) * market.policy_rate(cur) / 365.0 * float(c.notional)
	# Long X / 龙门币 holds X and owes 龙门币: it earns the difference.
	var cross := Currencies.cross_cur(str(c.underlying))
	if not cross.is_empty(): return float(c.dir) * (market.policy_rate(cross) - market.policy_rate("lmd")) / 365.0 * float(c.notional)
	return -float(c.notional) * CFD_OVERNIGHT

## Interest at the policy rate on the foreign accounts (拍板 #8: idle money
## may earn); 喀兰贸易's fee (F17) off the 赤金 and foreign accounts.
func _interest() -> void:
	for cur in fx_accounts.keys():
		var held := float(fx_accounts[cur])
		if held > 0.0: fx_accounts[cur] = snappedf(held * (1.0 + market.policy_rate(str(cur)) / 365.0), 0.01)
	var fee := market.custody_rate()
	if fee > 0.0:
		gold_account = snappedf(gold_account * (1.0 - fee), 0.01)
		for cur in fx_accounts.keys(): fx_accounts[cur] = snappedf(float(fx_accounts[cur]) * (1.0 - fee), 0.01)

func _roll_day() -> void:
	var day := MarketState.day_key(market.t)
	if day != _day:
		# The market only replays the last seven days of a long absence; the
		# relation correction counts every trading day that passed.
		_correct_relations(clampi(day - _day, 1, 3650))
		_day = day
		_new_day()

## The daily correction above each faction's expected value, `days` times.
func _correct_relations(days: int) -> void:
	for f in relations.keys():
		for i in range(days):
			var d := relation_drift(f)
			if d <= 0: break
			relations[f] = relation(f) - d

# --- Loans (§10) --------------------------------------------------------------------------

## LOAN_STEP per 交易所 level; 商务部 5 阶: ×1.5 and a point off the rate.
func loan_limit() -> int:
	var limit := mini(LOAN_CAP, LOAN_STEP * maxi(1, game.base.facility_level("exchange")))
	return roundi(limit * 1.5) if game.base.researched("loan_terms") else limit

func loan_rate_now(debt: int) -> float:
	return maxf(0.0, loan_rate(debt) - (0.01 if game.base.researched("loan_terms") else 0.0))

## 骑士竞技场赞助证 halves what opening a 差价合约 costs (势力声望解锁策划案 §三).
func cfd_fee() -> float:
	return CFD_FEE * (FactionRewards.ARENA_CFD if FactionRewards.badge_on(game, "kazimierz") else 1.0)

func loan_locked() -> bool:
	return loan > roundi(loan_limit() * LOAN_OVERDUE)

func borrow(amount: int) -> bool:
	if blocked(): return false
	if amount <= 0 or loan_locked() or loan + amount > loan_limit(): return false
	loan += amount
	game.gold += amount
	return true

func repay(amount: int) -> bool:
	if blocked(): return false
	amount = mini(amount, loan)
	if amount <= 0 or game.gold < amount: return false
	game.gold -= amount
	loan -= amount
	return true

static func loan_rate(debt: int) -> float:
	for tier in LOAN_TIERS:
		if debt <= float(tier[0]): return float(tier[1])
	return 0.04

## Settlement: interest once, quotas back, an overdue loan takes the reward first,
## "settle"-term orders cancelled.
## Returns how much of `reward` went to the loan.
func on_settlement(reward: int) -> int:
	_auto = true
	var taken := _settle(reward)
	_auto = false
	return taken

func _settle(reward: int) -> int:
	var taken := 0
	if loan > 0:
		# 商业联合会担保函 in the warehouse: this settlement's interest is waived.
		if game.base.stock().any(func(i): return i.material_id == "商业联合会担保函") and game.base.take_material("商业联合会担保函", 1): pass
		else: loan = ceili(loan * (1.0 + loan_rate_now(loan)))
		if loan_locked() and reward > 0:
			taken = mini(reward, loan)
			loan -= taken
			game.gold -= taken
	quota_used.clear()
	for o in orders.duplicate():
		if int(o.expires) == 0: cancel_order(int(o.id))
	return taken

# --- The money changer (§1.3) --------------------------------------------------------------

## 龙门币 → 赤金账户 (`to_gold`) or back, at the live rate less the spread.
func convert(to_gold: bool, amount: float, closure: bool = false) -> bool:
	if blocked(): return false
	if amount <= 0.0: return false
	if not closure and not unlocked(): return false
	var spread := Economy.closure_spread if closure else Economy.EXCHANGE_FX_SPREAD
	if to_gold:
		var lmd := ceili(amount)
		if not pay("lmd", lmd): return false
		credit("gold", lmd / (Economy.fx * (1.0 + spread)))
	else:
		if not pay("gold", amount): return false
		credit("lmd", amount * Economy.fx * (1.0 - spread))
	return true

## Any two of 龙门币, 赤金 and the foreign currencies at the terminal
## (地区货币策划案 §1.1): {ok, why, out, spread}. `amount` is in `from`.
func quote_convert(from: String, to: String, amount: float) -> Dictionary:
	var out := {"ok": false, "why": "", "out": 0.0, "spread": 0.0}
	if from == to or amount <= 0.0: return out
	for c in [from, to]:
		if c != "gold" and not Currencies.is_currency(c): return out
	var from_book := Currencies.book(from)
	if not from_book.is_empty() and market.halted(from_book):
		out.why = "暂停换出"
		return out
	var spread := Economy.EXCHANGE_FX_SPREAD if [from, to].has("lmd") and [from, to].has("gold") else Currencies.spread(from, to)
	var fee := 0.0
	for c in [from, to]:
		var book := Currencies.book(c)
		if book.is_empty() or c == "lmd": continue
		spread *= float(market.mods(book).get("spread", 1.0))
		fee += market.fee_extra(book)
	out.spread = spread + fee
	out.out = amount / Currencies.rate(from) * Currencies.rate(to) * (1.0 - spread - fee)
	out.ok = true
	return out

func convert_fx(from: String, to: String, amount: float) -> bool:
	if blocked() or not unlocked(): return false
	var q := quote_convert(from, to, amount)
	if not q.ok or balance(from) + 0.0001 < amount: return false
	if not pay(from, amount): return false
	credit(to, float(q.out))
	return true

## Bars (the item) into the 赤金 account, and whole bars out.
func deposit_bars(count: int) -> bool:
	if blocked(): return false
	if count <= 0 or not game.consume_materials({Economy.GOLD_ID: count}): return false
	credit("gold", count)
	return true

func withdraw_bars(count: int) -> bool:
	if blocked(): return false
	if count <= 0 or not pay("gold", count): return false
	var left := count
	while left > 0:
		var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)))
		left -= stack.quantity
		if not game.base.receive_to_staging(stack): game.base.receive(stack)
	return true

# --- 企鹅物流 (§11) -------------------------------------------------------------------------

func ship_fee(item: Item) -> int:
	if game.base.researched("forward_dock"): return 0   # 商务部 6 阶
	var rate := maxf(SHIP_FEE_MIN, SHIP_FEE - 0.01 * rank("penguin")) * market.penguin_fee()
	return ceili(Economy.price(item) * rate)

func ship(item: Item, faction: String) -> bool:
	if blocked(): return false
	if not Packs.is_pack(item.material_id) or market_of(item, faction).is_empty() or FactionCatalog.info(faction).get("transport", false): return false
	var fee := ship_fee(item)
	if not pay("lmd", fee): return false
	var due := market.t + game.rng_base.randi_range(SHIP_HOURS.x, SHIP_HOURS.y)
	shipments.append({"id": _id(), "faction": faction, "item": _escrow(item), "due": due})
	add_relation("penguin", 2)
	return true

func _tick_shipments() -> void:
	for s in shipments.duplicate():
		if market.t < int(s.due): continue
		shipments.erase(s)
		var item := Item.from_data(s.item)
		var faction := str(s.faction)
		var q := quote_sell(item, faction, false)
		if not q.ok:
			_return_item(s.item)
			_say("企鹅物流：%s暂停收货，货物退回" % FactionCatalog.name_of(faction), "arrival")
			continue
		var net := float(q.net)
		var risk := maxf(0.0, SHIP_RISK - 0.01 * rank("penguin") + market.penguin_risk())
		var lost := game.rng_base.randf() < risk
		if lost: net *= 1.0 - game.rng_base.randf_range(0.2, 0.5)
		credit(str(q.currency), net)
		market.add_pressure(str(q.market), float(Economy.price(item)))
		add_relation(faction, clampi(roundi(float(Economy.price(item)) / 5000.0), 1, 10))
		_log({"kind": "arrived", "what": item.display_name(), "faction": faction, "amount": net, "currency": q.currency})
		_say("企鹅物流送达：%s → %s，%s%s" % [item.display_name(), FactionCatalog.name_of(faction), format_money(str(q.currency), net), "（途中遇险，部分损失）" if lost else ""], "arrival")

# --- Watching -------------------------------------------------------------------------------

func toggle_watch(market_id: String) -> void:
	if watch.has(market_id): watch.erase(market_id)
	elif watch.size() < WATCH_MAX: watch.append(market_id)

func add_alert(market_id: String, op: String, price: float) -> void:
	alerts.append({"id": _id(), "market": market_id, "op": op, "price": price})

func remove_alert(id: int) -> void:
	alerts = alerts.filter(func(a): return int(a.id) != id)

func _tick_alerts() -> void:
	for a in alerts.duplicate():
		var p := cfd_price(str(a.market)) if str(a.market).begins_with("comp:") else market.price(str(a.market))
		if (a.op == ">=" and p >= float(a.price)) or (a.op == "<=" and p <= float(a.price)):
			alerts.erase(a)
			_say("到价提醒：%s %s %s" % [cfd_name(str(a.market)), a.op, str(snappedf(float(a.price), 0.01))], "alert")

# --- The step -----------------------------------------------------------------------------

## Called by MarketState after each step (live and while catching up).
func on_step(_t: int, dt: int) -> void:
	_auto = true
	_step_account(dt)
	_auto = false

func _step_account(dt: int) -> void:
	_roll_day()
	for f in quota_used.keys():
		quota_used[f] = maxf(0.0, float(quota_used[f]) - quota_cap(f) * QUOTA_REGEN * dt / QUOTA_REGEN_SECS)
	if not orders.is_empty(): _tick_orders()
	if not forwards.is_empty(): _tick_forwards()
	if not cfds.is_empty(): _tick_cfds()
	if not shipments.is_empty(): _tick_shipments()
	if not alerts.is_empty(): _tick_alerts()

## News weights from the player's own trading (事件表 §10).
func _news_weight(event_id: String) -> float:
	var ev: Dictionary = MarketEvents.EVENTS.get(event_id, {})
	var w := 1.0
	if event_id == "L3": w *= 1.0 + float(recent_sales.get("rat", 0.0)) / 50000.0
	if str(ev.get("region", "")) == str(CONTRACT_REGIONS.get(game.region_id, "")): w *= 1.2
	for f in forwards:
		if str(ev.get("region", "")) == str(FactionCatalog.info(str(f.faction)).get("region", "")): w *= 1.1
	return w

## Event-level relation shifts (S4).
func on_event(ev: Dictionary, picks: Dictionary = {}) -> void:
	for f in ev.get("relation", {}):
		if recent_sales.has(f): add_relation(f, int(ev.relation[f]))
	# I27: the faction Rhodes signed with.
	if ev.has("relation_pick") and not str(picks.get("faction", "")).is_empty(): add_relation(str(picks.faction), int(ev.relation_pick))

# --- Trade packs (交易包修订案 §7.3) -----------------------------------------------------------

## Once, on a save from before the packs: positions on loose materials and on
## the old 贸易品 books close at today's price (no relation lost, not a default),
## their orders are cancelled with the fee back, the watch list moves to packs.
func migrate_packs() -> void:
	if packs_version >= 1: return
	packs_version = 1
	_auto = true
	for f in forwards.duplicate():
		if Packs.is_pack(str(f.material)): continue
		forwards.erase(f)
		credit(str(f.currency), maxf(0.0, float(f.margin) + forward_pnl(f)))
	for o in orders.duplicate():
		var loose: bool = o.has("material") and not Packs.is_pack(str(o.material))
		if o.has("item"): loose = not Packs.is_pack(str(o.item.get("material", "")))
		if not loose and market.books.has(str(o.market)): continue
		var fee := float(Economy.price(Item.from_data(o.item))) * ORDER_FEE if o.has("item") else 			float(MaterialCatalog.create(str(o.material), 1).unit_value * Economy.LMD_PER_VALUE) * int(o.count) * ORDER_FEE if MaterialCatalog.MATERIALS.has(str(o.material)) else 0.0
		cancel_order(int(o.id))
		credit("lmd", fee)
	for c in cfds.duplicate():
		var u := str(c.underlying)
		if Currencies.is_money(u) or u.begins_with("comp:") or market.books.has(u): continue
		cfds.erase(c)
		credit(str(c.currency), float(c.margin))
	var moved: Array[String] = []
	for w in watch:
		if (Currencies.is_money(w) or w.begins_with("comp:") or market.books.has(w)) and not moved.has(w): moved.append(w)
	watch = moved
	alerts = alerts.filter(func(a): return Currencies.is_fx(str(a.market)) or str(a.market).begins_with("comp:") or market.books.has(str(a.market)))
	_auto = false

# --- Saving ---------------------------------------------------------------------------------

func to_data() -> Dictionary:
	return {"gold_account": gold_account, "fx_accounts": fx_accounts, "relations": relations, "quota_used": quota_used, "orders": orders, "forwards": forwards,
		"cfds": cfds, "forward_cooldown": forward_cooldown, "loan": loan, "shipments": shipments, "history": history,
		"watch": watch, "alerts": alerts, "cfd_day": cfd_day, "recent_sales": recent_sales, "next_id": _next_id, "relation_scale": RELATION_SCALE, "rank_gifts": rank_gifts, "start_attitude": start_attitude,
		"packs_version": packs_version}

func load_data(d: Dictionary) -> void:
	gold_account = float(d.get("gold_account", 0.0))
	fx_accounts = (d.get("fx_accounts", {}) as Dictionary).duplicate()
	relations = (d.get("relations", START_RELATIONS) as Dictionary).duplicate()
	if not d.is_empty() and int(d.get("relation_scale", 1)) < RELATION_SCALE:
		for f in relations: relations[f] = migrate_relation(int(relations[f]))
	rank_gifts = (d.get("rank_gifts", {}) as Dictionary).duplicate(true)
	start_attitude = bool(d.get("start_attitude", false))
	_start_attitude()
	quota_used = d.get("quota_used", {})
	orders = d.get("orders", [])
	forwards = d.get("forwards", [])
	cfds = d.get("cfds", [])
	forward_cooldown = d.get("forward_cooldown", {})
	loan = int(d.get("loan", 0))
	shipments = d.get("shipments", [])
	history = d.get("history", [])
	watch.assign(d.get("watch", []))
	alerts = d.get("alerts", [])
	cfd_day = d.get("cfd_day", cfd_day)
	recent_sales = d.get("recent_sales", {})
	_next_id = int(d.get("next_id", 1))
	# A fresh account starts on packs; an old one migrates once (migrate_packs).
	packs_version = int(d.get("packs_version", 0 if not d.is_empty() else 1))
