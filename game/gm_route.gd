class_name GmRoute
extends RefCounted

## GameManager's route map (肉鸽路线图策划案 v0.2): the block's map and the
## choices out of a floor, the sight and the 深部 modifiers; what a node puts
## on its floor (the camp's pieces, 得偿所愿, the dire foe and the bounty, the
## rest stop's fire) and the 不期而遇 cards with their choices (§5). The
## route's state (route_map, route_node…) stays on GameManager, where RunSave
## keeps it; moving from floor to floor (advance, _advance_floor) is
## GameManager's.

## The camp's own pieces (用户 2026-10-31: 用blender建模相关模型, tools/blender/kit/
## build_camp.py; the crates are the base's): round the middle room's sides,
## facing in, so the way through stays clear. [model, offset in room radii].
const CAMP_PIECES := [["res://art/kit/camp_tent.glb", Vector2(-0.62, 0.28)], ["res://art/kit/camp_tent.glb", Vector2(0.62, 0.22)],
	["res://art/kit/camp_floodlight.glb", Vector2(-0.58, -0.38)], ["res://art/kit/camp_floodlight.glb", Vector2(0.6, -0.34)],
	["res://art/kit/base_crate_stack.glb", Vector2(-0.72, -0.04)], ["res://art/kit/base_pallet.glb", Vector2(0.74, -0.06)],
	["res://art/kit/room_crates.glb", Vector2(0.3, 0.66)]]
const CAMP_PIECE_SCALE := 1.3
## A work light's lamp: its height and reach.
const CAMP_LAMP := {"height": 3.0, "color": Color(1.0, 0.86, 0.62), "radius": 8.0}
## 险路恶敌 (§4.1, 用户 2026-10-24: 命 ×2.5，伤害 ×1.75).
const DIRE_HP := 2.5
const DIRE_ATK := 1.75
const DIRE_GUARDS := 2
const DIRE_EXCLUSIVE := 0.25
## 临时休整's campfire (用户 2026-10-24: 回复 20% 生命上限，不受任何加成/减益影响).
const CAMPFIRE_HEAL := 0.2
const EVENT_MODEL := "res://art/kit/base_cargo_cart.glb"

var game: GameManager
## 不期而遇's piece at the encounter spot; 临时休整's campfire.
var event_node: Node3D
var rest_fire: FirePit
## 险路恶敌's foe; 得偿所愿's caches and the guards each waits on.
var dire_foe: Enemy
var _wish_posts: Array = []
## An event's fight still standing, and what it leaves when it falls.
var _event_guards: Array[Enemy] = []
var _event_prize: Array = []
## Given on a map-less 不期而遇 with no room in the pack: dropped on the next floor.
var _event_spill: Array[Item] = []
## Relics taken on this floor (旧日回响 takes an older one).
var _floor_relics: Array = []
## 雨夜目击者: this floor's 灭迹人 on the minimap.
var witness_marked := false

func _init(owner: GameManager) -> void:
	game = owner

## The rows the floor's route markers lead to (one marker each); the camp's
## one at the end of a block.
func route_choices() -> Array:
	_ensure_route()
	if not game.in_camp and game.floor_number % FieldCatalog.CAMP_INTERVAL == 0: return [0]
	return RouteMap.next_rows(game.route_map, game.route_node)

func _route_mark_colours() -> Array[Color]:
	var out: Array[Color] = []
	if not game.in_camp and game.floor_number % FieldCatalog.CAMP_INTERVAL == 0:
		out.append(AK.GREEN)
		return out
	for row in RouteMap.next_rows(game.route_map, game.route_node):
		out.append(RouteMap.info(str(RouteMap.node_at(game.route_map, Vector2i(game.route_node.x + 1, int(row))).get("kind", ""))).color)
	if out.is_empty(): out.append(AK.FG)
	return out

## The route odds with the news on top (route:<node>, 地区货币策划案 §2).
func _route_mults(mult: Dictionary) -> Dictionary:
	for key in game.market_field.get("mult", {}):
		if str(key).begins_with("route:"):
			var node := str(key).substr(6)
			mult[node] = float(mult.get(node, 1.0)) * game.field_mult(key)
	return mult

## The block's map, rolled when the block is entered (肉鸽路线图策划案 v0.2 §3.4).
func _roll_route_block(block: int) -> void:
	var posts: Array = FactionCatalog.POSTS.get(game.region_id, [])
	var ctx := {"region": game.region_id, "seed": game._run_seed, "first_exit": not game.base.first_extract_given,
		"extract_all": game.research.on("extract"), "trader_col": game.research.on("trader"),
		"mult": _route_mults({"trader": 1.5 if game.base.researched("trader_odds") else 1.0, "vault": 1.5 if game.research.on("vaults") else 1.0,
			"fate": 1.25 if game.base.researched("trace_odds") else 1.0}),
		"fate_ok": not game._sought_here().is_empty(), "post_ok": not posts.is_empty(), "posts": posts, "plain": game.route_plain,
		"ensure_post": "reunion" if posts.has("reunion") and FactionRewards.badge_on(game, "reunion") else ""}
	ctx.mult["post"] = game._field_post_mult(posts)
	match str(game.contract.get("type", "")):
		"hunt": if not game.bounty_killed: ctx["bounty"] = game.start_floor + int(game.contract.offset)
		"search": ctx["search"] = true
		"deliver": ctx["deliver"] = [int(game.contract.floor), str(game.contract.faction)]
	game.route_map = RouteMap.roll(block, ctx)
	game.route_trail = []
	game.route_peek = false
	game.route_exit_map = false
	game.route_threat_cut = false

## The map matches the floor she is on (tests and old saves set floors directly).
func _ensure_route() -> void:
	var block := RouteMap.block_of(game.floor_number + 1 if game.in_camp else game.floor_number)
	if game.route_map.is_empty() or int(game.route_map.get("block", -1)) != block:
		_roll_route_block(block)
		game.route_node = Vector2i(-1, 0) if game.in_camp else Vector2i(RouteMap.col_of(game.floor_number), 0)
		if not game.in_camp: _walk_trail()
	elif not game.in_camp and game.route_node.x != RouteMap.col_of(game.floor_number):
		game.route_node = Vector2i(RouteMap.col_of(game.floor_number), 0)
		_walk_trail()

func _walk_trail() -> void:
	while game.route_trail.size() < game.route_node.x: game.route_trail.append(-1)
	game.route_trail.resize(game.route_node.x)
	game.route_trail.append(game.route_node.y)

## Columns seen clearly ahead (科研 路线测绘 +1; PRTS 中继站 +2 for the block).
func route_sight() -> int:
	return RouteMap.SIGHT + (1 if game.base.researched("route_scan") else 0) + (2 if game.route_peek else 0)

## The floor of this block's extraction (-1 before a map).
func route_exit_floor() -> int:
	return RouteMap.floor_of(int(game.route_map.block), int(game.route_map.exit_col)) if not game.route_map.is_empty() else -1

func route_node_info() -> Dictionary:
	return RouteMap.info(game.route_kind)

## The 深部 modifiers: contamination, cold, guarded boxes, one more elite.
func route_deep() -> bool:
	return bool(route_node_info().get("deep", false))

## Places CAMP_PIECES (walk-through, as the encounter pieces are); the work
## lights' lamps are returned for the floor's light.
func _spawn_camp_pieces() -> Array[Dictionary]:
	var lamps: Array[Dictionary] = []
	var hall := game.world_map.small_hall
	if hall.z <= 0.0: return lamps
	var centre := Vector2(hall.x, hall.y)
	for piece in CAMP_PIECES:
		var at: Vector2 = centre + (piece[1] as Vector2) * hall.z
		if not game.world_map._has_clearance(at): continue
		var node := MeshInstance3D.new()
		node.name = str(piece[0]).get_file().get_basename()
		node.mesh = TerraceDressing.kit_mesh(load(piece[0]))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.world_map._generated_root.add_child(node)
		node.position = Vector3(at.x, game.world_map.ground_height(at), at.y)
		node.scale = Vector3.ONE * CAMP_PIECE_SCALE
		# Front (+Z) half to the room's middle, half to the camera (-Z).
		var inward := (centre - at).normalized() + Vector2(0.0, -1.0)
		node.rotation.y = atan2(inward.x, inward.y)
		if str(piece[0]).ends_with("camp_floodlight.glb"):
			lamps.append({"at": node.position + Vector3.UP * CAMP_LAMP.height + Vector3(inward.x, 0.0, inward.y).normalized() * 0.6, "color": CAMP_LAMP.color, "radius": CAMP_LAMP.radius})
	# Her counter lit too, so it reads in a dark mine.
	if is_instance_valid(game.world_map.encounter_node):
		lamps.append({"at": game.world_map.encounter_node.global_position + Vector3(0.0, 2.2, -1.0), "color": CAMP_LAMP.color, "radius": 5.5})
	return lamps

## The pieces of this floor's node: the event, the foe, the wish caches, an
## event's leftover cache.
func _spawn_route_content() -> void:
	var path: PackedVector2Array = game.world_map.main_path
	match game.route_kind:
		"event":
			event_node = game.world_map._set_piece("不期而遇 · E", game.world_map.encounter_position, RouteMap.info("event").color, EVENT_MODEL)
		"elite": _spawn_dire_foe()
		"relic":
			for share in [0.4, 0.6, 0.8]:
				var at := _beside_path(share, 4.0)
				var cache := game._spawn_relic_cache(at, "wish", true)
				var post := game._spawn_guard_post(cache.global_position, "得偿所愿", true, "", 3)
				_wish_posts.append([cache, post.guards.duplicate()])
	if bool(game.floor_mods.get("cache", false)) and path.size() > 2:
		game._spawn_relic_cache(_beside_path(0.5, 3.0), "cache", false)

## A walkable spot `side` metres off the main path, `share` of the way along it.
func _beside_path(share: float, side: float) -> Vector3:
	var path: PackedVector2Array = game.world_map.main_path
	var i := clampi(int(path.size() * share), 1, path.size() - 2)
	var along := (path[i + 1] - path[i - 1]).normalized()
	var off := Vector2(-along.y, along.x) * side * (1.0 if game.rng_floor.randf() < 0.5 else -1.0)
	return game.world_map.nearest_walkable(Vector3(path[i].x + off.x, 0, path[i].y + off.y))

## `count` more points of interest beside the main path (得偿所愿's, and the
## faction kits'), before the boxes are laid.
func _add_wish_points(count: int) -> void:
	for k in range(count):
		var at := _beside_path((k + 1.0) / (count + 1.0), 5.0)
		game.world_map.cache_positions.append(Vector3(at.x, game.ground_y(at) + 0.5, at.z))

func _spawn_dire_foe() -> void:
	var path: PackedVector2Array = game.world_map.main_path
	var spot: Vector2 = path[clampi(path.size() * 2 / 3, 0, path.size() - 1)]
	var at := game.world_map.nearest_walkable(Vector3(spot.x, 0, spot.y))
	dire_foe = game._spawn_enemy(at, true, false)
	dire_foe.boss = true
	dire_foe.max_health *= DIRE_HP
	dire_foe.health = dire_foe.max_health
	dire_foe.atk *= DIRE_ATK
	for i in range(DIRE_GUARDS):
		var side := Vector3(cos(TAU * i / DIRE_GUARDS), 0, sin(TAU * i / DIRE_GUARDS)) * 1.8
		game._spawn_enemy(game.world_map.nearest_walkable(at + side), false, false)
	# The hunt contract's bounty is this foe (§6.1).
	if game.is_bounty_floor(): game._bounty = dire_foe

## The bounty stands at its floor's 险路恶敌 (§6.1): a way past that node misses it.
func _bounty_on_map() -> bool:
	if game.route_map.is_empty() or RouteMap.block_of(game.floor_number) != int(game.route_map.block): return false
	return (game.route_map.cols[RouteMap.col_of(game.floor_number)] as Array).any(func(n): return str(n.mark) == "bounty")

## The foe's spoils: one piece blue or better; now and then a regional exclusive.
func _dire_spoils(at: Vector3) -> void:
	var drops: Array = [{"item": LootTables.gear_at_least(game.loot_ctx(), Item.BLUE)}]
	if game.rng_loot.randf() < DIRE_EXCLUSIVE:
		var ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "exclusive" and str(SpecialGear.GEAR[id].region) == game.region_id)
		if not ids.is_empty():
			var item := SpecialGear.create(ids[game.rng_loot.randi() % ids.size()], game.floor_number, game.rng_loot, true)
			item.origin_region = game.region_id
			drops.append({"item": item})
	game._drop_at(at, drops, 0.7)

## 临时休整: the campfire and the shower beside the squad.
func _spawn_rest_pieces() -> void:
	var centre := game.world_map.encounter_position
	var fire_at := game.world_map.nearest_walkable(centre + Vector3(-3.5, 0, 2.0))
	rest_fire = FirePit.new()
	rest_fire.name = "FirePit"
	game.world_map._generated_root.add_child(rest_fire)
	rest_fire.global_position = Vector3(fire_at.x, game.ground_y(fire_at), fire_at.z)
	rest_fire.feed(FeatureCatalog.FIRE_MAX)
	game.fires.append(rest_fire)
	var shower_at := game.world_map.nearest_walkable(centre + Vector3(3.5, 0, 2.0))
	game.shower = ShowerPoint.new()
	game.shower.name = "ShowerPoint"
	game.world_map._generated_root.add_child(game.shower)
	game.shower.global_position = Vector3(shower_at.x, game.ground_y(shower_at), shower_at.z)

func _campfire_nearby() -> bool:
	return game.route_kind == "rest" and not game.campfire_used and is_instance_valid(rest_fire) and game.near(rest_fire)

## A flat share of her life (no bonus or malus applies) and the cold gone.
func _use_campfire() -> void:
	game.campfire_used = true
	game.player.hp = minf(game.player.max_hp, game.player.hp + game.player.max_hp * CAMPFIRE_HEAL)
	game.player.cold = 0.0
	game.set_message("营火 · 生命 +%d%%" % roundi(CAMPFIRE_HEAL * 100))

func event_id() -> String:
	return str(RouteMap.node_at(game.route_map, game.route_node).get("event", ""))

func _event_nearby() -> bool:
	return game.route_kind == "event" and not game.event_done and is_instance_valid(event_node) and game.near(event_node) and not event_id().is_empty()

func _open_event() -> void:
	game.open_modal("event")
	game.menu.show_event()

## The card's choices as shown: {text, refusal}. Item names and 赤金 sums filled in.
func event_options() -> Array:
	var out: Array = []
	var ev := RouteEvents.info(event_id())
	for opt: Dictionary in ev.get("options", []):
		var cost := str(opt.cost)
		var gain := str(opt.gain)
		var bars := RouteEvents.scaled_bars(int(opt.get("bars", 0)), game.floor_number) if opt.has("bars") else 0
		if cost.contains("%d"): cost = cost % bars
		if gain.contains("%d"): gain = gain % RouteEvents.scaled_bars(int(opt.get("win", 0)), game.floor_number)
		match str(opt.do):
			"give_potion": gain = gain % FactionCatalog.name_of(str(RouteEvents.HOME_FACTION.get(game.region_id, "lungmen")))
			"locker": cost = cost % (_locker_item().item_name if _locker_item() != null else "装备")
			"uninsure": cost = cost % (_smuggled_item().item_name if _smuggled_item() != null else "装备")
			"echo": cost = cost % (str(RelicCatalog.get_relic(_echo_relic()).get("name", "藏品")) if not _echo_relic().is_empty() else "藏品")
		out.append({"text": "%s → %s" % [cost, gain], "refusal": _event_refusal(opt, bars), "do": str(opt.do), "bars": bars})
	return out

func _event_refusal(opt: Dictionary, bars: int) -> String:
	if bars > 0 and game.gold_bars() < bars: return "赤金不足"
	match str(opt.do):
		"give_potion": if _pack_potion("A") == null: return "没有标准急救剂"
		"locker": if _locker_item() == null: return "没有可交出的装备"
		"uninsure": if _smuggled_item() == null: return "没有投保装备"
		"echo": if _echo_relic().is_empty(): return "没有可失去的藏品"
		"give_fuel": if game.pack_fuels().is_empty(): return "没有燃料"
		"buy_rest": if _rest_target().is_empty(): return "下一层不能改"
	return ""

## The pack's equipment the locker would take: the least valuable piece not worn.
func _locker_item() -> Item:
	var best: Item = null
	for item in game.inventory.items:
		if item.is_equippable() and not GearCatalog.bound(item) and item.rarity < Item.RARITY_MAX and (best == null or item.value < best.value): best = item
	return best

## The insured piece the smuggler takes: the least valuable one carried.
func _smuggled_item() -> Item:
	var best: Item = null
	for item in game.carried_items():
		if item.is_equippable() and item.insured and (best == null or item.value < best.value): best = item
	return best

## The relic 旧日回响 takes: the first one not taken on this floor.
func _echo_relic() -> String:
	for id in game.builds:
		if not _floor_relics.has(id): return str(id)
	return ""

func _pack_potion(type: String) -> Item:
	for item in game.inventory.items:
		if item.potion_type == type: return item
	return null

## A fight floor of the next column to turn into 临时休整 (罗德岛补给信标).
func _rest_target() -> Dictionary:
	for row in RouteMap.next_rows(game.route_map, game.route_node):
		var node := RouteMap.node_at(game.route_map, Vector2i(game.route_node.x + 1, int(row)))
		if RouteMap.is_fight(str(node.get("kind", ""))) and not node.exit and str(node.mark).is_empty() and not str(node.kind) in ["outpost", "boss"]: return node
	return {}

## Choice `index` of the card; true when it was carried out.
func event_choose(index: int) -> bool:
	if game.modal != "event" or game.event_done: return false
	var options := event_options()
	if index < 0 or index >= options.size() or not str(options[index].refusal).is_empty(): return false
	var opt: Dictionary = options[index]
	var bars := int(opt.bars)
	if bars > 0 and not game.spend_gold_bars(bars): return false
	var at := event_node.global_position if is_instance_valid(event_node) else game.player.global_position
	var tier := Economy.tier_of(game.floor_number)
	var relic_after := ""
	match str(opt.do):
		"hurt_relic":
			game.player.hp = maxf(1.0, game.player.hp - game.player.max_hp * 0.25)
			relic_after = "event"
		"give_potion":
			var potion := _pack_potion("A")
			if potion.quantity > 1: potion.set_quantity(potion.quantity - 1)
			else: game.inventory.remove(potion)
			game.exchange.add_relation(str(RouteEvents.HOME_FACTION.get(game.region_id, "lungmen")), 10)
		"pay_trace": game.next_floor_mods["trace"] = true
		"fight_potions":
			var prize: Array = []
			for i in range(3): prize.append({"item": BaseCatalog.create_potion("A", tier)})
			_event_fight(at, 3, 0, prize)
		"gamble":
			if game.rng_run.randf() < 0.5:
				game.give_gold_bars(RouteEvents.scaled_bars(8, game.floor_number))
				game.set_message("赌徒：你赢了。")
			else: game.set_message("赌徒：运气不在你这边。")
		"signal":
			game.next_floor_mods["threat"] = 0.6
			game.next_floor_mods["cache"] = true
		"locker":
			var old := _locker_item()
			var better := LootTables.roll_equipment(old.category, old.item_name, game.region_id, game.floor_number, mini(old.rarity + 1, Item.RARITY_MAX), game.rng_loot)
			game.inventory.remove(old)
			_event_give(better)
		"peek": game.route_peek = true
		"exit_map": game.route_exit_map = true
		"uninsure":
			_smuggled_item().insured = false
			game.give_gold_bars(RouteEvents.scaled_bars(5, game.floor_number))
		"echo":
			var lost := _echo_relic()
			var before := game.player.f("enemy_hp")
			game.builds.erase(lost)
			game.player._recompute_stats()
			game._rescale_enemy_life(before, game.player.f("enemy_hp"))
			relic_after = "echo"
		"buy_potions":
			for i in range(2): _event_give(BaseCatalog.create_potion("A", tier))
		"buy_rest": _rest_target().kind = "rest"
		"fight_reunion":
			var prize: Array = []
			for entry in LootTables.container_drops("vault_base", game.loot_ctx()):
				var item: Item = entry.item
				if item.category == Item.Category.MATERIAL:
					item.effect = "dirty"
					item.description += " 来路不明，携带时污染缓慢上升。"
				prize.append(entry)
			_event_fight(at, 2, 6, prize)
		"surge":
			game.run_contamination += 20.0
			game.next_floor_mods["weak"] = 0.7
		"bribe": game.route_threat_cut = true
		"fight_guard": _event_fight(at, 1, 4, LootTables.container_drops("vault_gear", game.loot_ctx()))
		"give_fuel":
			var fuel: String = game.pack_fuels().keys()[0]
			for item in game.inventory.items:
				if item.material_id != fuel: continue
				if item.quantity > 1: item.set_quantity(item.quantity - 1)
				else: game.inventory.remove(item)
				break
			game.exchange.add_relation("karlan", 10)
			_event_give(FeatureCatalog.create_supply("自热罐头"))
		"invitation":
			game.features.add("debt", 20.0)
			for entry in LootTables.container_drops("vault_weapon", game.loot_ctx()): _event_give(entry.item)
		"witness": game.next_floor_mods["witness"] = true
	game.event_done = true
	if is_instance_valid(event_node): event_node.visible = false
	game.sound.play("build")
	game.close_modal()
	# 废弃的强化装置 / 旧日回响: the choice of relics at once.
	if not relic_after.is_empty(): game.open_relic_offer(relic_after)
	game.save_base(true)
	return true

## Into the pack; with no room, at her feet — or, with no floor under her (a
## map-less 不期而遇), on the next floor.
func _event_give(item: Item) -> void:
	if game.inventory.add_stack(item) <= 0: return
	if game.in_event: _event_spill.append(item)
	else: game.drop_at_feet(item)

## An event's fight round `at`: `elites` and `normals` stronger than the
## floor's own (RouteEvents.FIGHT_HP / FIGHT_ATK); `prize` drops when it falls.
func _event_fight(at: Vector3, elites: int, normals: int, prize: Array) -> void:
	var count := elites + normals
	for i in range(count):
		var side := Vector3(cos(TAU * i / count), 0, sin(TAU * i / count)) * (2.0 + (i % 2) * 1.2)
		var enemy := game._spawn_enemy(game.world_map.nearest_walkable(at + side), i < elites, false)
		enemy.max_health *= RouteEvents.FIGHT_HP
		enemy.health = enemy.max_health
		enemy.atk *= RouteEvents.FIGHT_ATK
		_event_guards.append(enemy)
	_event_prize = prize
	game.set_message("战斗：%d 名敌人" % count)
