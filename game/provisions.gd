class_name Provisions
extends RefCounted

## 农业部 and 食堂 on Rhodes' second deck (势力特供策划案_v0_2 §三–§六, 用户
## 2026-10-22). The farm is three of RimWorld's classic sun-lamp rooms: a
## sun lamp each with 24 1×4 hydroponics basins round it in four groups of
## six, two groups a 农业部 level (用户: 可以多放几组水培). Crops grow in
## real time, the game closed or not, and never wither. The kitchen cooks
## them into 补给, eaten at the canteen before a contract: one at a time, for
## that contract, like a flask (the base itself still adds no combat stats).
## From Ⅱ up a 补给 also helps the Rhodes squads met on that contract; 企鹅物流
## can carry one out to the next squad met, as its 补给 service.

## crop -> {hours, yield (per basin), seed: 龙门币 for Rhodes' own, or the seed item}.
const CROPS := {
	"舰载麦": {"hours": 2, "yield": 6, "seed_lmd": 300},
	"块茎薯": {"hours": 3, "yield": 8, "seed_lmd": 400},
	"温室豆": {"hours": 4, "yield": 5, "seed_lmd": 600},
	"闪耀作物": {"hours": 8, "yield": 3, "seed": "闪耀作物种子"},
	"闪耀作物·变种": {"hours": 16, "yield": 2, "seed": "闪耀作物·变种种子"},
}
const CROP_ORDER := ["舰载麦", "块茎薯", "温室豆", "闪耀作物", "闪耀作物·变种"]
## The crops that glow once ripe (the RimWorld nod, §4.2).
const GLOWING := ["闪耀作物", "闪耀作物·变种"]
## Basins: a group of six, a swirl of four groups, three swirls; a 农业部
## level builds two groups.
const GROUP := 6
const SWIRL_BASINS := 24
const SWIRLS := 3
const BASINS := SWIRL_BASINS * SWIRLS
const BASINS_PER_LEVEL := GROUP * 2

## The swirl in tiles round the sun lamp (x east, z north; the lamp's tile
## is the middle, x and z −0.5…0.5), after RimWorld's classic 11×11 sun-lamp
## room (用户 2026-10-22, with the picture): six basins, then the same six
## turned 90° about the lamp three times — 24 in all, four single tiles left
## empty inside the pinwheel and the room's corners free. Basin `i` stands
## in swirl i / 24 (BaseMap.FARM_CENTRES), group i / 6; the rect is its place
## in its swirl (x0, z0, width, depth) with z0 its south edge.
## The first group as (column, row, width, height) on the 11×11 grid, row 0
## north, read off the picture.
const SWIRL_FIRST := [[3, 0, 1, 4], [4, 0, 4, 1], [1, 1, 1, 4], [2, 1, 1, 4], [4, 1, 1, 4], [5, 1, 1, 4]]
const SWIRL_SIZE := 11

static func basin_rect(i: int) -> Rect2:
	var cell: Array = SWIRL_FIRST[i % GROUP]
	var r := Rect2(float(cell[0]) - 5.5, 5.5 - float(cell[1]) - float(cell[3]), float(cell[2]), float(cell[3]))
	# A quarter turn clockwise seen from above: (x, z) → (z, −x).
	for k in range((i % SWIRL_BASINS) / GROUP):
		var a := Vector2(r.position.y, -r.position.x)
		var b := Vector2(r.end.y, -r.end.x)
		r = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y)))
	return r

static func swirl_of(i: int) -> int:
	return i / SWIRL_BASINS

## 补给 recipes: in, minutes each, the 食堂 level they need.
const RECIPES := {
	"舰内口粮": {"in": {"舰载麦": 4}, "minutes": 10, "level": 1},
	"食堂便当": {"in": {"舰载麦": 3, "块茎薯": 3, "温室豆": 2}, "minutes": 30, "level": 1},
	"闪耀定食": {"in": {"闪耀作物": 2, "舰载麦": 3, "块茎薯": 3, "温室豆": 2}, "minutes": 60, "level": 2},
	"变种盛宴": {"in": {"闪耀作物·变种": 2, "闪耀作物": 2, "温室豆": 4}, "minutes": 180, "level": 3},
}
const MEAL_ORDER := ["舰内口粮", "食堂便当", "闪耀定食", "变种盛宴"]
## What one does for the contract it is eaten for (shares). hp_pct and
## regen_pct join the sheet; atk and aspd ride the flasks' hexes.
const MEALS := {
	"舰内口粮": {"tier": 1, "hp_pct": 0.05},
	"食堂便当": {"tier": 2, "hp_pct": 0.08, "regen_pct": 0.10},
	"闪耀定食": {"tier": 3, "hp_pct": 0.10, "atk": 0.06},
	"变种盛宴": {"tier": 4, "hp_pct": 0.12, "atk": 0.10, "aspd": 0.05},
}
## For the squads, by the tier eaten (cumulative): Ⅱ its price one step
## lower, Ⅲ squads more often, Ⅳ two services from one squad.
const SQUAD_STEP_DOWN_TIER := 2
const SQUAD_STEP := 0.1
const SQUAD_CHANCE_TIER := 3
const SQUAD_CHANCE := 0.4
const SQUAD_USES_TIER := 4
const SQUAD_USES := 2
## The kitchen's queues: one, two from 食堂 Lv3.
const KITCHEN_SLOTS_LEVEL := 3
## 企鹅物流's cold chain: from this rank, for this much a parcel.
const MAIL_RANK := 2
const MAIL_LMD := 3000

var game: GameManager

func _init(p_game: GameManager = null) -> void:
	game = p_game

func _state() -> Dictionary: return game.base.farm

static func fresh_state() -> Dictionary:
	return {"plots": [], "kitchen": [], "next_job": 1, "meal": "", "mailed": ""}

static func meal_text(meal: String) -> String:
	var m: Dictionary = MEALS.get(meal, {})
	var parts: Array[String] = []
	if m.has("hp_pct"): parts.append("生命上限 +%d%%" % roundi(float(m.hp_pct) * 100))
	if m.has("regen_pct"): parts.append("回复 +%d%%" % roundi(float(m.regen_pct) * 100))
	if m.has("atk"): parts.append("攻击 +%d%%" % roundi(float(m.atk) * 100))
	if m.has("aspd"): parts.append("攻速 +%d%%" % roundi(float(m.aspd) * 100))
	return "，".join(parts)

## The squad lines a tier brings (cumulative).
static func squad_text(meal: String) -> String:
	var tier := int(MEALS.get(meal, {}).get("tier", 0))
	var parts: Array[String] = []
	if tier >= SQUAD_STEP_DOWN_TIER: parts.append("小队价格倍率 −%d%%" % roundi(SQUAD_STEP * 100))
	if tier >= SQUAD_CHANCE_TIER: parts.append("小队出现率 %d%%" % roundi(SQUAD_CHANCE * 100))
	if tier >= SQUAD_USES_TIER: parts.append("小队服务 %d 次" % SQUAD_USES)
	return "，".join(parts)

# --- 农业部 -------------------------------------------------------------------------------

func basins() -> int:
	return mini(BASINS, game.base.facility_level("farm") * BASINS_PER_LEVEL)

## Basin `i` ({} empty, else {crop, at}); grows the list to the built basins.
func plot(i: int) -> Dictionary:
	var plots: Array = _state().plots
	while plots.size() < basins(): plots.append({})
	return plots[i] if i >= 0 and i < plots.size() else {}

func grow_seconds(crop: String) -> int:
	return int(CROPS[crop].hours) * 3600

## 0–1 grown; 1 is ripe (and stays ripe: nothing withers).
func growth(i: int) -> float:
	var p := plot(i)
	if p.is_empty(): return 0.0
	return clampf(float(BaseState.now() - int(p.at)) / float(grow_seconds(str(p.crop))), 0.0, 1.0)

func ripe(i: int) -> bool:
	return not plot(i).is_empty() and growth(i) >= 1.0

func seconds_left(i: int) -> int:
	var p := plot(i)
	return 0 if p.is_empty() else maxi(0, int(p.at) + grow_seconds(str(p.crop)) - BaseState.now())

## "" when `crop` can be sown in basin `i` now.
func sow_refusal(i: int, crop: String) -> String:
	if not CROPS.has(crop): return "无效"
	if i < 0 or i >= basins(): return "需要农业部升级"
	if not plot(i).is_empty(): return "已种植"
	var c: Dictionary = CROPS[crop]
	if c.has("seed"):
		if game.exchange.rank("rhine") < FactionSpecials.rank_needed(str(c.seed)) and game.material_count(str(c.seed)) <= 0:
			return "需要莱茵生命关系 R%d" % FactionSpecials.rank_needed(str(c.seed))
		return game.materials_refusal({c.seed: 1})
	if game.gold < int(c.seed_lmd): return "龙门币不足"
	return ""

func sow(i: int, crop: String) -> bool:
	if not game.in_base or not sow_refusal(i, crop).is_empty(): return false
	var c: Dictionary = CROPS[crop]
	if c.has("seed"): game.consume_materials({c.seed: 1})
	else: game.gold -= int(c.seed_lmd)
	_state().plots[i] = {"crop": crop, "at": BaseState.now()}
	game.story_note("sowed")
	game.farm_changed()
	return true

## Sows `crop` in every empty basin it can; returns how many.
func sow_all(crop: String) -> int:
	var n := 0
	for i in range(basins()):
		if plot(i).is_empty() and sow(i, crop): n += 1
	return n

## Takes a ripe basin's crop into the warehouse; returns how many units.
func harvest(i: int) -> int:
	if not game.in_base or not ripe(i): return 0
	var crop := str(plot(i).crop)
	var count := int(CROPS[crop].yield)
	_state().plots[i] = {}
	_store(crop, count)
	if crop in GLOWING: game.broadcast("PRTS：莱茵生命生态科提醒，闪耀作物收获后仍会发光一段时间，请放在阴凉处。")
	game.farm_changed()
	return count

func harvest_all() -> int:
	var n := 0
	for i in range(basins()):
		if ripe(i): n += harvest(i)
	return n

func ripe_count() -> int:
	var n := 0
	for i in range(basins()):
		if ripe(i): n += 1
	return n

## Into the warehouse shelf, then staging, then a crate at receiving.
func _store(material: String, count: int) -> void:
	var left := count
	while left > 0:
		var stack := MaterialCatalog.create(material, mini(left, MaterialCatalog.stack_size(material)))
		left -= stack.quantity
		if game.base.store(stack).is_empty(): game.base.receive(stack)

# --- 食堂 --------------------------------------------------------------------------------

func kitchen_slots() -> int:
	var level := game.base.facility_level("canteen")
	return 0 if level <= 0 else (2 if level >= KITCHEN_SLOTS_LEVEL else 1)

func jobs() -> Array: return _state().kitchen

func cook_refusal(meal: String, count: int = 1) -> String:
	if not RECIPES.has(meal) or count <= 0: return "无效"
	if game.base.facility_level("canteen") < int(RECIPES[meal].level): return "需要食堂 Lv%d" % int(RECIPES[meal].level)
	if jobs().size() >= kitchen_slots(): return "队列已满"
	var cost := {}
	for id in RECIPES[meal]["in"]: cost[id] = int(RECIPES[meal]["in"][id]) * count
	return game.materials_refusal(cost)

## Queues `count` of `meal` in a free slot; it is ready after their minutes.
func cook(meal: String, count: int = 1) -> bool:
	if not game.in_base or not cook_refusal(meal, count).is_empty(): return false
	var cost := {}
	for id in RECIPES[meal]["in"]: cost[id] = int(RECIPES[meal]["in"][id]) * count
	game.consume_materials(cost)
	var now := BaseState.now()
	var due := now + int(RECIPES[meal].minutes) * 60 * count
	_state().kitchen.append({"id": int(_state().next_job), "output": meal, "count": count, "start": now, "due": due})
	_state().next_job = int(_state().next_job) + 1
	game.save_base()
	return true

## Finished dishes into the warehouse; returns them.
func tick() -> Array:
	var done: Array = []
	var now := BaseState.now()
	for job in jobs().duplicate():
		if int(job.due) <= now:
			jobs().erase(job)
			_store(str(job.output), int(job.count))
			done.append(job)
	return done

# --- Eating -----------------------------------------------------------------------------

func meal() -> String: return str(_state().get("meal", ""))
func mailed() -> String: return str(_state().get("mailed", ""))

func eat_refusal(meal_id: String) -> String:
	if not MEALS.has(meal_id): return "无效"
	if game.base.facility_level("canteen") < 1: return "需要食堂"
	return game.materials_refusal({meal_id: 1})

## Eats one before the next contract; one already eaten is replaced.
func eat(meal_id: String) -> bool:
	if not game.in_base or not eat_refusal(meal_id).is_empty(): return false
	game.consume_materials({meal_id: 1})
	_state().meal = meal_id
	game.story_note("meal")
	game.save_base()
	return true

func mail_refusal(meal_id: String) -> String:
	if not MEALS.has(meal_id): return "无效"
	if game.base.facility_level("canteen") < 1: return "需要食堂"
	if game.exchange.rank("penguin") < MAIL_RANK: return "需要企鹅物流关系 R%d" % MAIL_RANK
	if not mailed().is_empty(): return "已有寄出的补给"
	if game.gold < MAIL_LMD: return "龙门币不足"
	return game.materials_refusal({meal_id: 1})

## 企鹅物流 carries one to the next Rhodes squad met, for its 补给 service.
func mail(meal_id: String) -> bool:
	if not game.in_base or not mail_refusal(meal_id).is_empty(): return false
	game.consume_materials({meal_id: 1})
	game.gold -= MAIL_LMD
	_state().mailed = meal_id
	game.save_base()
	return true

## At departure: the meal eaten goes with her and the plate is cleared.
func take_for_run() -> String:
	var m := meal()
	_state().meal = ""
	return m

static func load_state(saved: Variant) -> Dictionary:
	var out := fresh_state()
	if not saved is Dictionary: return out
	for p in saved.get("plots", []):
		out.plots.append({"crop": str(p.crop), "at": int(p.at)} if p is Dictionary and CROPS.has(str(p.get("crop", ""))) else {})
	for j in saved.get("kitchen", []):
		if j is Dictionary and RECIPES.has(str(j.get("output", ""))):
			out.kitchen.append({"id": int(j.get("id", 0)), "output": str(j.output), "count": maxi(1, int(j.get("count", 1))), "start": int(j.get("start", 0)), "due": int(j.get("due", 0))})
	out.next_job = maxi(1, int(saved.get("next_job", 1)))
	out.meal = str(saved.get("meal", "")) if MEALS.has(str(saved.get("meal", ""))) else ""
	out.mailed = str(saved.get("mailed", "")) if MEALS.has(str(saved.get("mailed", ""))) else ""
	return out
