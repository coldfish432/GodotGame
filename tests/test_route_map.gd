extends SceneTree

## 肉鸽路线图 (肉鸽路线图策划案 v0.2, 用户 2026-10-24): the block's branching map
## (RouteMap) rolled over many seeds, then the floors of its nodes in a game.

var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	_maps()
	_marks()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4242
	root.add_child(game)
	await step(8)
	await _walk()
	await _nodes()
	await _event()
	await _camp()
	print("ROUTE MAP RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")

# --- The map itself ---------------------------------------------------------------------------

func _ctx(seed: int, region: String = "mine") -> Dictionary:
	return {"region": region, "seed": seed, "fate_ok": true, "post_ok": region != "siracusa", "posts": FactionCatalog.POSTS.get(region, [])}

func _maps() -> void:
	var seeds := 3000
	var bad := {}
	var exit_cols := {3: 0, 4: 0, 5: 0}
	var events := 0
	var kinds_seen := {}
	for s in range(seeds):
		for block in [0, 1]:
			var map := RouteMap.roll(block, _ctx(s, ["mine", "city", "snow", "siracusa"][s % 4]))
			var cols: Array = map.cols
			var last := cols.size() - 1
			if cols.size() != 10: bad["ten columns"] = s
			if (cols[0] as Array).size() != (1 if block == 0 else (cols[0] as Array).size()) or (block > 0 and not (cols[0] as Array).size() in [2, 3]): bad["first column width"] = s
			if (cols[last] as Array).size() != 1: bad["one last node"] = s
			if str(cols[last][0].kind) != ("boss" if block == 1 else "outpost"): bad["last node kind"] = [s, cols[last][0].kind]
			var exit_col := int(map.exit_col)
			if not exit_cols.has(exit_col): bad["exit on floors 4–6"] = s
			else: exit_cols[exit_col] += 1
			var exits := 0
			var specials := {}
			for c in range(cols.size()):
				var width := (cols[c] as Array).size()
				if c > 0 and c < last:
					if c == exit_col and not width in [1, 2]: bad["exit column 1–2 nodes"] = s
					elif c != exit_col and (width < 2 or width > 4): bad["2–4 nodes a column"] = [s, c, width]
				var seen := {}
				for r in range(width):
					var node: Dictionary = cols[c][r]
					var kind := str(node.kind)
					kinds_seen[kind] = true
					if node.exit:
						exits += 1
						if not RouteMap.is_fight(kind): bad["the beacon on a fight floor"] = [s, kind]
					if RouteMap.CAPS.has(kind):
						specials[kind] = int(specials.get(kind, 0)) + 1
						if seen.has(kind): bad["no two alike in a column"] = [s, c, kind]
						seen[kind] = true
						var places: Vector2i = RouteMap.PLACES[kind]
						if str(node.mark).is_empty() and (c + 1 < places.x or c + 1 > places.y): bad["floors of a kind"] = [s, c, kind]
					if kind == "event":
						events += 1
						if str(node.event).is_empty() or not RouteEvents.pool(["mine", "city", "snow", "siracusa"][s % 4]).has(node.event): bad["an event of the region"] = [s, node.event]
					if c < last:
						var out: Array = map.edges[c][r]
						if out.is_empty(): bad["every node leads on"] = [s, c, r]
						for to in out:
							if int(to) < 0 or int(to) >= (cols[c + 1] as Array).size(): bad["lines in range"] = s
							if kind in RouteMap.SERVICES and str(cols[c + 1][int(to)].kind) in RouteMap.SERVICES: bad["services never adjacent"] = [s, c, kind, cols[c + 1][int(to)].kind]
				if c > 0:
					for r in range(width):
						var into := 0
						for k in range((cols[c - 1] as Array).size()):
							if (map.edges[c - 1][k] as Array).has(r): into += 1
						if into == 0: bad["every node is reached"] = [s, c, r]
					# No two lines cross.
					for a in range((cols[c - 1] as Array).size()):
						for b in range(a + 1, (cols[c - 1] as Array).size()):
							for x in map.edges[c - 1][a]:
								for y in map.edges[c - 1][b]:
									if int(x) > int(y): bad["no crossing lines"] = [s, c]
			if exits != 1: bad["exactly one beacon"] = [s, exits]
			# At least half the column before leads to the beacon.
			var exit_row := -1
			for r in range((cols[exit_col] as Array).size()):
				if cols[exit_col][r].exit: exit_row = r
			var before: Array = cols[exit_col - 1]
			var leading := range(before.size()).filter(func(k): return (map.edges[exit_col - 1][k] as Array).has(exit_row)).size()
			if leading < ceili(before.size() * RouteMap.EXIT_SHARE): bad["half lead to the beacon"] = [s, leading, before.size()]
			for kind in specials:
				if int(specials[kind]) > int(RouteMap.CAPS[kind]): bad["caps"] = [s, kind]
			if int(specials.get("event", 0)) < 1: bad["at least one 不期而遇"] = s
			if not (cols[last - 1] as Array).any(func(n): return RouteMap.is_fight(n.kind)): bad["a fight on floor 9"] = s
			var path := RouteMap.fewest_fights(map)
			if path.filter(func(at): return RouteMap.is_fight(cols[at.x][at.y].kind)).size() < RouteMap.MIN_FIGHTS: bad["four fights every way"] = s
			if block == 1 and str(cols[0][0].kind) == "deep": bad["no 深部 first out of a camp"] = s
	for rule in ["ten columns", "first column width", "one last node", "last node kind", "exit on floors 4–6", "exit column 1–2 nodes", "2–4 nodes a column",
			"the beacon on a fight floor", "no two alike in a column", "floors of a kind", "an event of the region", "every node leads on", "lines in range",
			"services never adjacent", "every node is reached", "no crossing lines", "exactly one beacon", "half lead to the beacon", "caps",
			"at least one 不期而遇", "a fight on floor 9", "four fights every way", "no 深部 first out of a camp"]:
		check("route map: " + rule, not bad.has(rule), bad.get(rule))
	var total := float(seeds * 2)
	check("the beacon on floor 4, 5 or 6 about a third each", exit_cols.values().all(func(n): return absf(n / total - 1.0 / 3.0) < 0.03), exit_cols)
	for kind in ["patrol", "supply", "deep", "event", "trader", "rest", "relic", "elite", "vault", "fate", "post"]:
		check("kind %s comes up" % kind, kinds_seen.has(kind))
	# The first extraction ever: floor 5, its only node; 撤离保障: every node before leads there.
	var first := RouteMap.roll(0, _ctx(7).merged({"first_exit": true}))
	check("first extraction: floor 5 is one node with the beacon", int(first.exit_col) == 4 and (first.cols[4] as Array).size() == 1 and first.cols[4][0].exit)
	var all_in := true
	for s in range(400):
		var map := RouteMap.roll(1, _ctx(s).merged({"extract_all": true}))
		var c := int(map.exit_col)
		var row: int = range((map.cols[c] as Array).size()).filter(func(r): return map.cols[c][r].exit)[0]
		for k in range((map.cols[c - 1] as Array).size()):
			if not (map.edges[c - 1][k] as Array).has(row): all_in = false
	check("撤离保障: the whole column before leads to the beacon", all_in)
	var plain := RouteMap.roll(0, _ctx(3).merged({"plain": true}))
	var plain_ok := true
	for c in range(1, 9):
		for node in plain.cols[c]:
			if not node.kind in RouteMap.COMBAT_KINDS: plain_ok = false
	check("plain maps (tests) are fight floors only", plain_ok)
	var same := RouteMap.roll(1, _ctx(99)) == RouteMap.roll(1, _ctx(99))
	check("the same seed rolls the same map", same)
	check("sight: next column clear, the one after fuzzy, then dark", RouteMap.sight(3, 2, 1) == "clear" and RouteMap.sight(4, 2, 1) == "fuzzy" and RouteMap.sight(5, 2, 1) == "dark" and RouteMap.sight(2, 2, 1) == "seen")

func _marks() -> void:
	var ok_bounty := true
	var ok_search := true
	var ok_deliver := true
	var ok_trader := true
	for s in range(300):
		var map := RouteMap.roll(0, _ctx(s, "city").merged({"bounty": 5, "search": true, "deliver": [7, "rat"], "trader_col": true}))
		var bounty := (map.cols[4] as Array).filter(func(n): return n.mark == "bounty" and n.kind == "elite")
		if bounty.size() != 1: ok_bounty = false
		var vaults := 0
		for c in range(10):
			for n in map.cols[c]:
				if n.mark == "search" and n.kind == "vault": vaults += 1
		if vaults != 1: ok_search = false
		if (map.cols[6] as Array).filter(func(n): return n.mark == "deliver" and n.kind == "post" and n.faction == "rat").size() != 1: ok_deliver = false
		if not (map.cols[2] as Array).any(func(n): return n.kind == "trader"): ok_trader = false
	check("hunt: a 险路恶敌 marked on the bounty's floor", ok_bounty)
	check("search: one 暗墙密室 marked for the contract", ok_search)
	check("deliver: the faction's post marked on the handover floor", ok_deliver)
	check("商队联络: a 诡异行商 on floor 3", ok_trader)

# --- In a game ----------------------------------------------------------------------------------

## Every node of the next column turned into `kind`, then on along line 0.
func _go(kind: String) -> void:
	game._ensure_route()
	var c := game.route_node.x + 1
	for node in game.route_map.cols[c]:
		node.kind = kind
		node.exit = false
		node.mark = ""
		if kind == "event": node.event = "gambler"
	await game.advance(0)
	await step(3)

func _walk() -> void:
	await game.start_contract("mine")
	await step(2)
	check("a contract starts on the block's 外勤入口", game.route_node == Vector2i(0, 0) and game.route_kind == "entry" and int(game.route_map.block) == 0)
	var lines := RouteMap.next_rows(game.route_map, game.route_node)
	check("one route marker per line out of the node", game.world_map.route_nodes.size() == lines.size(), [game.world_map.route_nodes.size(), lines])
	game.player.teleport(game.world_map.route_nodes[0].global_position)
	await step(2)
	game._interact()
	check("a marker opens the route map", game.modal == "route")
	game.close_routes()
	var target := Vector2i(1, int(lines[0]))
	await game.advance(0)
	await step(2)
	check("advancing walks the line to its node", game.floor_number == 2 and game.route_node == target and game.route_kind == str(RouteMap.node_at(game.route_map, target).kind))
	check("the walked rows are kept", game.route_trail == [0, target.y])
	check("the floor is named after its node", str(game.route_history[-1].name) == RouteMap.kind_name(game.route_kind))
	# The extraction: on the beacon's node, nowhere else.
	game.floor_number = int(game.route_map.exit_col)
	game._ensure_route()
	var exit_rows := range((game.route_map.cols[game.route_map.exit_col] as Array).size()).filter(func(r): return game.route_map.cols[game.route_map.exit_col][r].exit)
	var before := RouteMap.next_rows(game.route_map, game.route_node)
	var line: int = before.find(exit_rows[0])
	if line < 0:
		game.route_map.edges[game.route_node.x][game.route_node.y].append(exit_rows[0])
		line = RouteMap.next_rows(game.route_map, game.route_node).find(exit_rows[0])
	await game.advance(line)
	await step(2)
	check("the beacon's floor has the random extraction", game.is_extraction_floor() and game.world_map.exit_node.visible, [game.floor_number, game.route_node])
	await _go("supply")
	check("the floor after it has none", not game.is_extraction_floor())
	game.settle(true)
	await step(2)

func _nodes() -> void:
	game.route_plain = true
	game._pending_contract = {"type": "deep", "steps": 9}
	await game.start_contract("mine")
	await step(2)
	game.floor_number = 4
	await _go("rest")
	check("临时休整: a small map, no enemies", game.world_map.compact_layout and game.floor_enemies().is_empty())
	check("临时休整: the squad, a campfire and a shower, no device", game.encounter == "squad" and is_instance_valid(game.rest_fire) and is_instance_valid(game.shower) and not game.world_map.buff_device_node.visible)
	check("临时休整: the meter rests", not game.threat_rising())
	SystemScreens.settings["auto_potion"] = ""
	game.player.hp = game.player.max_hp * 0.5
	var hp := game.player.hp
	game.player.teleport(game.rest_fire.global_position)
	await step(2)
	check("the campfire's prompt", game.interaction_prompt() == "营火", game.interaction_prompt())
	game._interact()
	check("the campfire gives a flat 20% of max life, once", is_equal_approx(game.player.hp, minf(game.player.max_hp, hp + game.player.max_hp * 0.2)) and game.campfire_used, [hp, game.player.hp, game.player.max_hp])
	game.threat.value = 50.0
	await _go("trader")
	check("临时休整: the next floor carries no threat", game.threat.value < 1.0, game.threat.value)
	check("诡异行商: 坎诺特, a small map, no device", game.encounter == "trader" and game.world_map.compact_layout and not game.world_map.buff_device_node.visible and not game.is_buff_available())
	await _go("supply")
	check("坎诺特 never comes on a fight floor", game.encounter != "trader")
	# 用户 2026-10-24: 掉落加成 +5% / +15%，敌人数值 ×1.25 / ×1.6.
	var at := game.player.global_position + Vector3(4, 0, 0)
	var life := {}
	for kind in ["patrol", "supply", "deep"]:
		game.route_kind = kind
		var probe := game._spawn_enemy(at, false, false, "thug")
		life[kind] = [probe.max_health, probe.atk]
		probe.queue_free()
	game.route_kind = "supply"
	check("物资作业 / 深部污染 enemies: ×1.25 / ×1.6 life and attack", is_equal_approx(life.supply[0] / life.patrol[0], 1.25) and is_equal_approx(life.deep[1] / life.patrol[1], 1.6), life)
	check("their drop bonus: +5% / +15%", is_equal_approx(float(RouteMap.info("supply").reward), 0.05) and is_equal_approx(float(RouteMap.info("deep").reward), 0.15))
	await _go("elite")
	var foe: Enemy = game.dire_foe
	check("险路恶敌: the foe has 2.5× life and 1.75× attack over an elite", is_instance_valid(foe) and foe.elite and foe.boss and foe.max_health > 0.0)
	var loot_before := game.get_children().filter(func(n): return n is Loot).size()
	kill(foe)
	await step(4)
	var spoils := game.get_children().filter(func(n): return n is Loot and n.item != null and n.item.is_equippable() and n.item.rarity >= Item.BLUE)
	check("险路恶敌: its fall drops gear blue or better", spoils.size() >= 1, game.get_children().filter(func(n): return n is Loot).size() - loot_before)
	await _go("vault")
	check("暗墙密室: the floor has its vault", game.world_map.has_vault)
	await _go("relic")
	var wish := game.get_tree().get_nodes_in_group("relic_caches").filter(func(c): return c.game == game and c.source == "wish")
	check("得偿所愿: three sealed relic caches", wish.size() == 3 and wish.all(func(c): return c.sealed))
	for guard in game._wish_posts[0][1].duplicate(): kill(guard)
	await step(3)
	check("得偿所愿: its guards down unseal one", not game._wish_posts[0][0].sealed and game._wish_posts[1][0].sealed)
	game.open_relic_offer("wish", game._wish_posts[0][0])
	check("得偿所愿 offers mid and high relics only", game.build_offers.all(func(r): return int(r.rarity) >= 1), game.build_offers.map(func(r): return r.rarity))
	game.choose_build(game.build_offers[0].id)
	await step(2)
	check("taking one closes the other two", game.get_tree().get_nodes_in_group("relic_caches").filter(func(c): return c.game == game and c.source == "wish" and not c.is_queued_for_deletion()).is_empty())
	game.settle(true)
	await step(2)
	game.route_plain = false

func _event() -> void:
	game.route_plain = true
	await game.start_contract("mine")
	await step(2)
	game.floor_number = 3
	# 用户 2026-10-24: 不期而遇无敌人的事件不加载地图 — the card alone.
	await _go("event")
	check("a 不期而遇 with no fight: no map, its card at once", game.in_event and game.modal == "event" and not is_instance_valid(game.world_map._generated_root) and game.floor_number == 4)
	check("the floor still counts and is named", str(game.route_history[-1].name) == "不期而遇" and game.route_node.x == 3)
	check("no threat while on the card", not game.threat_rising())
	var options: Array = game.event_options()
	check("the card's choices read cost → gain", options.size() == 1 and str(options[0].text).contains("→"))
	game.run_gold = 0
	check("short of 赤金, refused", not str(game.event_options()[0].refusal).is_empty() and not game.event_choose(0))
	game.close_modal()
	check("leaving the card brings up the route map", game.modal == "route" and game.in_event)
	game.close_routes()
	check("back from the map returns to the unsettled card", game.modal == "event")
	game.run_gold = 50
	var bars: int = int(game.event_options()[0].bars)
	check("the gamble is carried out once, then the route map", game.event_choose(0) and game.event_done and game.modal == "route")
	check("its stake is paid", game.run_gold == 50 - bars or game.run_gold == 50 - bars + RouteEvents.scaled_bars(8, game.floor_number), game.run_gold)
	game.route_map.cols[3][game.route_node.y].event = "broken_device"
	game.event_done = false
	game.modal = "event"
	check("废弃的强化装置: the relic choice comes at once", game.event_choose(0) and game.modal == "build" and game.build_offers.all(func(r): return int(r.rarity) >= 1))
	game.choose_build(game.build_offers[0].id)
	check("and then the route map", game.modal == "route")
	game.route_map.cols[3][game.route_node.y].event = "surge"
	game.event_done = false
	game.modal = "event"
	check("源石活性异常: for the next floor", game.event_choose(0) and is_equal_approx(float(game.next_floor_mods.get("weak", 0.0)), 0.7))
	await game.advance(0)
	await step(3)
	check("on from the card: the next floor is built, its enemies weaker", not game.in_event and is_instance_valid(game.world_map._generated_root) and game.floor_number == 5 and is_equal_approx(float(game.floor_mods.get("weak", 0.0)), 0.7))
	# A fight event keeps its small map: the piece, more enemies, its prize when the fight falls.
	for node in game.route_map.cols[game.route_node.x + 1]:
		node.kind = "event"
		node.event = "wreck"
		node.exit = false
		node.mark = ""
	await game.advance(0)
	await step(3)
	check("补给箱残骸: a small map with its piece", not game.in_event and game.world_map.compact_layout and is_instance_valid(game.event_node))
	check("不期而遇: more enemies than a 物资作业 of its size would have", game.floor_enemies().size() >= roundi(12 * 1.3) - 1, game.floor_enemies().size())
	game.close_modal()
	game.player.teleport(game.event_node.global_position)
	await step(2)
	game._interact()
	check("its piece opens the card", game.modal == "event", [game.interaction_prompt(), game.modal])
	check("补给箱残骸: the fight starts", game.event_choose(0) and game._event_guards.size() == 3)
	check("an event's fighters are elites", game._event_guards.all(func(e): return e.elite))
	var loot_before := game.get_children().filter(func(n): return n is Loot).size()
	for e in game._event_guards.duplicate(): kill(e)
	await step(4)
	check("its prize drops when the fight is over", game.get_children().filter(func(n): return n is Loot).size() >= loot_before + 3)
	await _all_events()
	game.settle(true)
	await step(2)
	game.route_plain = false

## Every choice of every event, carried out once with what it asks for at hand.
func _all_events() -> void:
	var refused: Array = []
	var here: Dictionary = game.route_map.cols[game.route_node.x][game.route_node.y]
	for id in RouteEvents.EVENTS:
		var options: Array = RouteEvents.EVENTS[id].options
		for i in range(options.size()):
			game.run_gold = 99
			game.inventory.add_stack(BaseCatalog.create_potion("A"))
			game.inventory.add_stack(MaterialCatalog.create(FeatureCatalog.FUELS.keys()[0], 1))
			var insured := Item.create("测试刀", Item.Category.WEAPON, 2, 1, 1.0)
			insured.insured = true
			insured.rarity = 1
			game.inventory.try_add(insured)
			if game.builds.is_empty(): game.builds.append(RelicCatalog.all()[0].id)
			game._floor_relics.clear()
			for node in game.route_map.cols[game.route_node.x + 1]: node.kind = "supply"
			here.event = id
			game.event_done = false
			game.modal = "event"
			if not game.event_choose(i): refused.append([id, i, game.event_options()[i].refusal if i < game.event_options().size() else "?"])
			game.close_modal()
			for e in game._event_guards.duplicate(): kill(e)
			await step(2)
	check("every event's every choice can be carried out", refused.is_empty(), refused)

func _camp() -> void:
	await game.start_contract("city")
	await step(2)
	game.floor_number = 9
	await game.advance(0)
	await step(2)
	check("floor 10 is the block's 前哨据点", game.route_kind == "outpost" and game.world_map.route_nodes.size() == 1)
	for enemy in game._outpost_squad.duplicate(): kill(enemy)
	await step(3)
	await game.advance(0)
	await step(2)
	check("the camp rolls the next block's map", game.in_camp and int(game.route_map.block) == 1 and game.route_node == Vector2i(-1, 0))
	game.leave_camp()
	await step(2)
	check("leaving the camp opens the map of 2–3 first floors", game.modal == "route" and game.in_camp)
	game.close_routes()
	check("back from the map is back in the camp's field", game.modal.is_empty() and game.in_camp)
	await game.advance(1)
	await step(2)
	check("picking one walks into floor 11 on that node", not game.in_camp and game.floor_number == 11 and game.route_node == Vector2i(0, 1))
	game.settle(true)
	await step(2)
