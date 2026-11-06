class_name GmFeatures
extends RefCounted

## GameManager's 地图特色 (地图特色策划案_v1_0.md): the base kits taken at
## departure, the meters the HUD shows, 寒冷 and the 萨米 fires and their fuel,
## the mine's 净化喷淋点, the field supplies and sealed ore, 可露希尔's camp
## supplies, cleanse and 赔偿金, and the 仇家 of 血债. The meters themselves are
## FeatureMeter (GameManager.features).

const SEALED_ORE := "sealed_ore"

var game: GameManager
## This floor's 火堆 (萨米) and 净化喷淋点 (矿区).
var fires: Array[FirePit] = []
var shower: ShowerPoint
## The shower being used: seconds held so far (−1: not), and her life when it began.
var shower_progress := -1.0
var _shower_hp := 0.0
## The fire the fuel picker is open for.
var fuel_fire: FirePit
## Base kits at departure: kit id -> false when unticked (ticked by default).
var kit_choice := {}
## Place one whatever the roll (tests and captures).
var force_shower := false

func _init(owner: GameManager) -> void:
	game = owner

## Takes the base kits ticked for a contract in `region`, one per feature.
func _take_kits(region: String) -> void:
	for id in chosen_kits(region):
		var tier := game.base.take_kit(id)
		if tier > 0: game.features.kits[str(FeatureCatalog.KITS[id].feature)] = [id, tier]
	kit_choice.clear()

## The kits that would go on a contract in `region`: in stock and not
## unticked; plain and refined do not stack, the refined one wins.
func chosen_kits(region: String) -> Array[String]:
	var by_feature := {}
	for id in FeatureCatalog.kits_for(region):
		if game.base.kit_stock(id) <= 0 or not bool(kit_choice.get(id, true)): continue
		var feature: String = FeatureCatalog.KITS[id].feature
		if not by_feature.has(feature) or id.ends_with("_plus"): by_feature[feature] = id
	var out: Array[String] = []
	for feature in by_feature: out.append(str(by_feature[feature]))
	return out

## Ticks or unticks a kit at departure; ticking one of a kind unticks the other.
func toggle_kit(id: String, region: String) -> void:
	if not FeatureCatalog.KITS.has(id): return
	var on := not kit_on(id, region)
	kit_choice[id] = on
	var other := id.trim_suffix("_plus") if id.ends_with("_plus") else id + "_plus"
	if on: kit_choice[other] = false

func kit_on(id: String, region: String) -> bool:
	return id in chosen_kits(region)

## Whether any kit for `region` is in stock (the departure card shows them).
func kits_in_stock(region: String) -> bool:
	return FeatureCatalog.kits_for(region).any(func(id): return game.base.kit_stock(id) > 0)

func kit_refusal(id: String) -> String:
	var kit: Dictionary = FeatureCatalog.KITS[id]
	if game.base.facility_level("store") < int(kit.store): return "商店 Lv%d" % int(kit.store)
	if game.gold < FeatureCatalog.kit_price(id, game.deepest_tier()): return "龙门币不足"
	return ""

## 可露希尔 at the base sells the kits for 龙门币, at the deepest camp's tier
## (v1.1 §4.1); they wait at the base.
func buy_kit(id: String) -> bool:
	if not game.in_base or not FeatureCatalog.KITS.has(id) or not kit_refusal(id).is_empty(): return false
	game.gold -= FeatureCatalog.kit_price(id, game.deepest_tier())
	game.base.add_kit(id, game.deepest_tier())
	game.save_base()
	return true

## The meters the HUD shows: 污染 as before, 血债 in 叙拉古, 寒冷 in 萨米.
func shown_features() -> Array[String]:
	var out: Array[String] = []
	if game.in_base: return out
	if game.region_id == "siracusa": out.append("debt")
	if game.region_id == "snow": out.append("cold")
	if game.contamination_visible(): out.append("contamination")
	return out

func feature_value(kind: String) -> float:
	return game.current_contamination() if kind == "contamination" else game.features.value(kind)

## A second, now: what the HUD shows next to the value.
func feature_rate(kind: String) -> float:
	match kind:
		"contamination": return game.contamination_rate()
		"cold": return cold_rate()
	return 0.0

## 寒冷 a second at this moment: rising on a 萨米 floor, falling inside a lit fire.
func cold_rate() -> float:
	if game.in_base or game.in_camp or game.region_id != "snow": return 0.0
	if warm_fire() != null: return -FeatureCatalog.FIRE_WARM * (FactionRewards.AMULET_FIRE if FactionRewards.badge_on(game, "sami") else 1.0)
	var rate := FeatureCatalog.COLD_RATE + (FeatureCatalog.COLD_DEEP if game.route_deep() else 0.0)
	if game.floor_kit_on("雪山向导绳"): rate *= FactionRewards.ROPE_COLD
	# 埃克提尔尼尔's blizzard from tier 5 (Boss与守卫者策划案 §6).
	if game.boss_fight() and game.outpost_boss.figure_id == "eikthyrnir" and game.outpost_boss.tier >= 5: rate *= BossCatalog.BLIZZARD
	return rate * game.field_feature_rate("snow") * game.features.growth_mult("cold", game.floor_number) * (game.player.elements.feature_mult("cold") if is_instance_valid(game.player) and game.player.elements != null else 1.0)

## The lit fire she stands at, if any.
func warm_fire() -> FirePit:
	if not is_instance_valid(game.player): return null
	for fire in fires:
		if is_instance_valid(fire) and fire.lit() and fire.warms(game.player.global_position): return fire
	return null

func _tick_features(delta: float) -> void:
	for fire in fires:
		if is_instance_valid(fire): fire.burn(delta)
	var cold_step := cold_rate() * delta
	if cold_step >= 0.0: game.features.add("cold", cold_step * game.potion_fx.cold_mult())
	else: game.features.reduce("cold", -cold_step)
	game.player.cold = game.features.value("cold")
	if game.region_id == "siracusa" and not game.in_camp and game.features.reckoning_due(delta):
		# On a boss floor 扎罗 takes the 清算时刻 himself; no squad comes (Q6).
		if game.boss_fight() and game.outpost_boss.figure_id == "zaro":
			game.features.reckon_wait = FeatureCatalog.RECKONING_EVERY
			game.outpost_boss.begin_reckoning()
			game.broadcast("PRTS：博士，清算时刻。")
		else: game._spawn_reckoning()
	_tick_shower(delta)
	for kind in ["debt", "cold"]:
		var reached := game.features.newly_reached(kind)
		if reached > 0: game.set_message("%s %d（%s）" % [FeatureCatalog.NAMES[kind], roundi(game.features.value(kind)), FeatureCatalog.TIER_NAMES[kind][reached]])
	var step := floori(maxi(game.floor_number - 1, 0) / FeatureCatalog.DEPTH_BLOCK)
	if step > game.features.depth_step:
		game.features.depth_step = step
		var own := FeatureCatalog.feature_of(game.region_id)
		if not own.is_empty(): game.broadcast("PRTS：博士，越往深处，%s来得越快。" % FeatureCatalog.NAMES[own])

## 火堆 (§5.3): FIRES (or one more, on FIRE_EXTRA of floors) off the main path,
## spread along it; one by a 冰原营地 (one at most) and one by the random
## extraction. On a boss floor, the arena's own two instead.
func _spawn_fires() -> void:
	fires.clear()
	if game.region_id != "snow": return
	# The arena's two fires, the first one lit (Boss战场地策划案 §4.3).
	if is_instance_valid(game.arena):
		for at in game.arena.fire_spots():
			var pit := FirePit.new()
			pit.name = "FirePit"
			game.world_map._generated_root.add_child(pit)
			pit.global_position = Vector3(at.x, game.ground_y(at), at.z)
			fires.append(pit)
		if not fires.is_empty(): fires[0].feed(BossCatalog.FIRE_START)
		return
	var path: PackedVector2Array = game.world_map.main_path
	if path.size() < 6: return
	var count := FeatureCatalog.FIRES + (1 if game.rng_floor.randf() < FeatureCatalog.FIRE_EXTRA else 0)
	var shares: Array = [0.33, 0.66] if count == 2 else [0.25, 0.5, 0.75]
	var spots: Array[Vector3] = []
	for share in shares:
		var i := clampi(int(path.size() * float(share)), 1, path.size() - 2)
		var along := (path[i + 1] - path[i - 1]).normalized()
		for attempt in range(10):
			var side := Vector2(-along.y, along.x) * (1.0 if attempt % 2 == 0 else -1.0) * game.rng_floor.randf_range(FeatureCatalog.FIRE_OFFSET.x, FeatureCatalog.FIRE_OFFSET.y)
			var at := game.world_map.nearest_walkable(Vector3(path[i].x + side.x, 0, path[i].y + side.y))
			if _fire_spot_ok(at, spots, attempt < 6):
				spots.append(at)
				break
	# At most one 冰原营地 a floor keeps a fire (用户 2026-10-19).
	for node in game.get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box == null or box.game != game or box.kind != "camp": continue
		var at := game.world_map.nearest_walkable(box.global_position + Vector3(2.4, 0, 0))
		if _fire_spot_ok(at, spots, false):
			spots.append(at)
			break
	if game.is_extraction_floor() and is_instance_valid(game.world_map.exit_node):
		var at := game.world_map.nearest_walkable(game.world_map.exit_node.global_position + Vector3(0, 0, 3.0))
		if _fire_spot_ok(at, spots, false): spots.append(at)
	for at in spots:
		var fire := FirePit.new()
		fire.name = "FirePit"
		game.world_map._generated_root.add_child(fire)
		fire.global_position = Vector3(at.x, game.ground_y(at), at.z)
		fires.append(fire)

## Off the vault and apart from the other fires; `strict` also keeps it clear
## of the floor's marks and FIRE_ENEMY_CLEAR from any enemy.
func _fire_spot_ok(at: Vector3, placed: Array[Vector3], strict: bool = true) -> bool:
	var flat := Vector2(at.x, at.z)
	if game.world_map.vault_hidden(flat): return false
	for other in placed:
		if other.distance_to(at) < FeatureCatalog.FIRE_RADIUS * 2.0: return false
	if not strict: return true
	if not game._trap_spot_ok(at, []): return false
	for enemy in game.floor_enemies():
		if Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(flat) < FeatureCatalog.FIRE_ENEMY_CLEAR: return false
	return true

func near_fire() -> FirePit:
	for fire in fires:
		if is_instance_valid(fire) and game.near(fire): return fire
	return null

## The fuels in the pack (not the safe bag): id -> count.
func pack_fuels() -> Dictionary:
	var out := {}
	for item in game.inventory.items:
		if FeatureCatalog.FUELS.has(item.material_id): out[item.material_id] = int(out.get(item.material_id, 0)) + item.quantity
	return out

## E at a fire: the picker of what to burn; nothing without fuel.
func _open_fuel(fire: FirePit) -> void:
	if pack_fuels().is_empty(): return
	fuel_fire = fire
	game.open_modal("fuel")
	game.menu.show_fuel()

## One piece of `id` from the pack onto the fire (用户 2026-10-19: she picks which).
func burn_fuel(id: String, fire: FirePit = null) -> bool:
	if fire == null: fire = fuel_fire
	if not is_instance_valid(fire) or not FeatureCatalog.FUELS.has(id): return false
	if fire.burn_left >= FeatureCatalog.FIRE_MAX: return false
	for item in game.inventory.items:
		if item.material_id != id: continue
		if item.quantity > 1: item.set_quantity(item.quantity - 1)
		else: game.inventory.remove(item)
		fire.feed(float(FeatureCatalog.FUELS[id]))
		return true
	return false

## 净化喷淋点 (§3.3): on SHOWER_CHANCE of mine floors, beside the main path.
func _spawn_shower() -> void:
	shower = null
	shower_progress = -1.0
	if game.region_id != "mine" or game.floor_number % FieldCatalog.CAMP_INTERVAL == 0: return
	if not force_shower and game.rng_floor.randf() >= FeatureCatalog.SHOWER_CHANCE: return
	var path: PackedVector2Array = game.world_map.main_path
	if path.size() < 6: return
	for attempt in range(20):
		var i := game.rng_floor.randi_range(2, path.size() - 3)
		var along := (path[i + 1] - path[i - 1]).normalized()
		var side := Vector2(-along.y, along.x) * (1.0 if attempt % 2 == 0 else -1.0) * game.rng_floor.randf_range(3.0, 5.0)
		var at := game.world_map.nearest_walkable(Vector3(path[i].x + side.x, 0, path[i].y + side.y))
		if not game._trap_spot_ok(at, []): continue
		shower = ShowerPoint.new()
		shower.name = "ShowerPoint"
		game.world_map._generated_root.add_child(shower)
		shower.global_position = Vector3(at.x, game.ground_y(at), at.z)
		return

func _start_shower() -> void:
	shower_progress = 0.0
	_shower_hp = game.player.hp

## Held SHOWER_SECONDS beside it: −SHOWER_CUT; a hit or a step away breaks it off.
func _tick_shower(delta: float) -> void:
	if shower_progress < 0.0: return
	if not is_instance_valid(shower) or shower.used or not game.near(shower) or game.player.hp < _shower_hp - 0.5:
		shower_progress = -1.0
		if is_instance_valid(shower): shower.spraying(false)
		return
	shower_progress += delta
	shower.spraying(true)
	if shower_progress < FeatureCatalog.SHOWER_SECONDS: return
	shower_progress = -1.0
	shower.use()
	game.run_contamination = maxf(0.0, game.current_contamination() - FeatureCatalog.SHOWER_CUT)
	game.set_message("污染 −%d" % int(FeatureCatalog.SHOWER_CUT))

## A field supply used from the pack (right click): the sealer seals one ore,
## the others take their feature down.
func use_supply(item: Item) -> bool:
	if game.in_base or not FeatureCatalog.is_supply(item) or not game.carried_items().has(item): return false
	var data: Dictionary = FeatureCatalog.SUPPLIES[item.material_id]
	if item.material_id == "源石矿封装器":
		var ore := _unsealed_ore()
		if ore == null: return false
		seal_ore(ore)
	else:
		var kind: String = data.feature
		game.features.reduce(kind, float(data.cut))
		game.set_message("%s −%d" % [FeatureCatalog.NAMES[kind], int(data.cut)])
	_spend_one(item)
	game.save_base(true)
	return true

func _spend_one(item: Item) -> void:
	if item.quantity > 1: item.set_quantity(item.quantity - 1)
	else:
		game.inventory.remove(item)
		game.safe_bag.remove(item)

func _unsealed_ore() -> Item:
	for item in game.carried_items():
		if item.effect == "raw_ore": return item
	return null

## Right click on a raw ore with a sealer in the pack or safe bag seals it.
func seal_with_sealer(ore: Item) -> bool:
	if game.in_base or ore == null or ore.effect != "raw_ore": return false
	for item in game.carried_items():
		if item.material_id == "源石矿封装器":
			seal_ore(ore)
			_spend_one(item)
			return true
	return false

## 简易封装的源石原矿 (用户 2026-10-19): the same ore and price, SEALED_ORE_RATE a second.
func seal_ore(ore: Item) -> void:
	ore.effect = SEALED_ORE
	ore.item_name = FeatureCatalog.SEALED_ORE_NAME
	ore.description = "简易封装：携带时每块每秒污染 +0.01。"
	game.set_message(FeatureCatalog.SEALED_ORE_NAME)

## 可露希尔 in a camp: the field supplies and 固体燃料 for 赤金.
func supply_price(id: String) -> int:
	return FeatureCatalog.FUEL_BARS if id == "固体燃料" else int(FeatureCatalog.SUPPLIES[id].bars)

func supply_item(id: String) -> Item:
	return MaterialCatalog.create(id, 1, game.region_id) if id == "固体燃料" else FeatureCatalog.create_supply(id)

func closure_buy_supply(id: String) -> bool:
	if not game.in_camp or not id in FeatureCatalog.CAMP_SUPPLIES: return false
	var price := supply_price(id)
	if game.gold_available() < price: return false
	if game.inventory.add_stack(supply_item(id)) > 0:
		game.notice("背包空间不足。")
		return false
	game._pay_gold(price)
	game.save_base(true)
	return true

## 营地处理: contamination −CAMP_CLEANSE once a camp.
func camp_cleanse_refusal() -> String:
	if not game.in_camp: return "营地"
	if game.features.camp_cleansed: return "已处理"
	if game.current_contamination() <= 0.0: return "无"
	if game.gold_available() < FeatureCatalog.CAMP_CLEANSE_BARS: return "赤金不足"
	return ""

func camp_cleanse() -> bool:
	if not camp_cleanse_refusal().is_empty(): return false
	game._pay_gold(FeatureCatalog.CAMP_CLEANSE_BARS)
	game.features.camp_cleansed = true
	game.run_contamination = maxf(0.0, game.current_contamination() - FeatureCatalog.CAMP_CLEANSE)
	game.save_base(true)
	return true

## 赔偿金: 血债 −CAMP_DEBT, one 赤金 dearer each time in the same camp.
func camp_debt_refusal() -> String:
	if not game.in_camp: return "营地"
	if game.features.value("debt") <= 0.0: return "无"
	if game.gold_available() < game.features.camp_debt_price(): return "赤金不足"
	return ""

func camp_pay_debt() -> bool:
	if not camp_debt_refusal().is_empty(): return false
	game._pay_gold(game.features.camp_debt_price())
	game.features.camp_debt_paid += 1
	game.features.reduce("debt", FeatureCatalog.CAMP_DEBT)
	game.save_base(true)
	return true

## 仇家 (血债 60, §4.4): the families hit harder …
func feud_damage(enemy: Enemy) -> float:
	if game.region_id != "siracusa" or not FeatureCatalog.family(enemy.enemy_type) or game.features.tier("debt") < 1: return 1.0
	return 1.0 + FeatureCatalog.FEUD_DAMAGE

## … and see her from further.
func feud_sight(enemy: Enemy) -> float:
	if game.region_id != "siracusa" or not FeatureCatalog.family(enemy.enemy_type) or game.features.tier("debt") < 1: return game.potion_fx.sight_mult()
	return (1.0 + FeatureCatalog.FEUD_SIGHT) * game.potion_fx.sight_mult()
