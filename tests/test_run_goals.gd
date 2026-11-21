extends SceneTree

## 局内节奏与目标策划案 §6 (用户 2026-10-08): the outpost floor before each camp
## (B2) and the contract objectives chosen at the dispatch desk (B1). Live
## contamination and out-of-combat regeneration (D, A2) are in test_medical.

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
	# The set pieces (BossShow) have their own suite; these check the fight itself.
	BossShow.enabled = false
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4242
	root.add_child(game)
	# A vault on every floor here: the vault checks need one (密室与陷阱修订案 §2.1).
	game.world_map.force_vault = 1
	await step(8)
	await _outpost()
	await _offers()
	await _deep()
	await _recover()
	await _several()
	await _hunt()
	print("RUN GOALS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")

# --- B2 营地前哨 ------------------------------------------------------------------

func _outpost() -> void:
	await game.start_contract("city")
	await step(2)
	check("an ordinary floor is not an outpost", not game.is_outpost_floor() and game.outpost_cleared)
	game.floor_number = 9
	await game.advance(0)
	await step(2)
	var squad: Array[Enemy] = game._outpost_squad.duplicate()
	check("floor 10 is the outpost before the camp", game.floor_number == 10 and game.is_outpost_floor() and not game.outpost_cleared)
	check("a leader and two guards hold it", squad.size() == 1 + FieldCatalog.OUTPOST_GUARDS and squad[0].boss and squad[0].elite)
	check("the leader has the boss bar and mark", squad[0].is_in_group("enemies") and squad[0].boss)
	# No text over markers (用户 2026-10-13: 不要中文label了，只提示e即可).
	check("the route markers carry no 3D label", game.world_map.route_nodes.all(func(n): return n.get_children().all(func(c): return not c is Label3D)))
	game.player.teleport(game.world_map.route_nodes[0].global_position)
	await step(2)
	game._interact()
	check("the routes stay shut while it holds", game.modal != "route")
	kill(squad[0])
	await step(2)
	check("the guards alone still hold it", not game.outpost_cleared)
	for enemy in squad: kill(enemy)
	await step(3)
	check("the whole squad down opens the routes", game.outpost_cleared)
	var vault_caches := get_nodes_in_group_of("relic_caches").filter(func(c): return c.source == "vault" and not c.sealed)
	var chests := get_nodes_in_group_of("loot_containers").filter(func(c): return c.vault and c.kind == "vault_gear" and not c.sealed)
	check("it leaves a gear chest and a vault-grade relic offer", vault_caches.size() >= 1 and chests.size() >= 1)
	game.player.teleport(game.world_map.route_nodes[0].global_position)
	await step(2)
	game._interact()
	check("then the routes open", game.modal == "route")
	game.close_modal()
	game.settle(true)
	await step(2)

func get_nodes_in_group_of(group: String) -> Array:
	return game.get_tree().get_nodes_in_group(group).filter(func(n): return n.get("game") == game)

# --- B1 合同目标 ------------------------------------------------------------------

func _offers() -> void:
	# 合同板 (合同板修订案_v0_1.md): the departments post, she takes several.
	game.base.board = ContractBoard.new()
	var cards: Array = game.board_cards()
	var depts := {}
	for c in cards: depts[c.dept] = int(depts.get(c.dept, 0)) + 1
	check("the board fills from 外勤部 / 工程部 / 医疗部 / 后勤部", depts.has("外勤部") and depts.has("工程部") and depts.has("医疗部") and depts.has("后勤部"), depts)
	check("only the kinds kept (用户: 深入、猎杀、回收和交付、运送)", cards.all(func(c): return str(c.type) in ["deep", "hunt", "recover", "order", "deliver"]))
	check("cards are posted only for open regions", cards.all(func(c): return str(c.get("region", "")) == "" or game.region_open(str(c.region))), cards.map(func(c): return c.get("region", "")))
	check("every card reads as a goal and a pay", cards.all(func(c): return not game.contract_what(c).is_empty() and not game.contract_pay_text(c, 1).is_empty()))
	var recover := cards.filter(func(o): return o.type == "recover")
	for o in recover: check("a recover target is a common drop of that region's enemies", FieldCatalog.RECOVER_TARGETS[o.region].any(func(t): return t[0] == o.material) and int(o.gold) > 0)
	var data := game.base.to_data()
	var copy := BaseState.new()
	copy.load_data(data, {})
	check("the board is saved with the base", copy.board.posted.size() == game.base.board.posted.size() and copy.board.serial == game.base.board.serial)
	# Taking: three at once, one of each run kind per region.
	game.set_contract({})
	var deep: Dictionary = {"type": "deep", "region": "mine", "steps": 4, "roll": 1.0, "uid": 9001, "dept": "外勤部", "age": 0}
	var deep2: Dictionary = {"type": "deep", "region": "mine", "steps": 6, "roll": 1.0, "uid": 9002, "dept": "外勤部", "age": 0}
	game.base.board.posted.append_array([deep, deep2])
	check("a posted card can be taken", game.take_contract(deep) and game.base.board.find_posted(9001).is_empty() and not game.base.board.find_active(9001).is_empty())
	check("a second 深入 in the same region cannot", game.contract_refusal(deep2) == "同地区已有同类合同" and not game.take_contract(deep2))
	game.base.board.add_active({"type": "order", "id": "eng_carbon"}, "工程部")
	game.base.board.add_active({"type": "order", "id": "log_trinkets"}, "后勤部")
	check("three taken: the cap is reached", game.contract_refusal({"type": "hunt", "region": "mine", "offset": 3}) == "承接已满")
	check("放弃 frees a place", game.abandon_contract(int(game.base.board.active[2].uid)) and game.contract_refusal({"type": "hunt", "region": "mine", "offset": 3}).is_empty())
	# After a settlement the untaken cards age; after two they are replaced.
	var board := game.base.board
	var old_uids: Array = board.posted.map(func(c): return int(c.uid))
	board.after_settlement(game.rng_base, game.board_ctx(), "mine")
	check("one settlement: untaken cards stay", old_uids.all(func(u): return not board.find_posted(u).is_empty() or u == 9002))
	board.after_settlement(game.rng_base, game.board_ctx(), "mine")
	check("two settlements: they are replaced, and the slots full again", old_uids.all(func(u): return board.find_posted(u).is_empty()) and board.posted.size() >= 8, board.posted.size())
	check("taken cards stay taken", not board.find_active(9001).is_empty())
	game.set_contract({})

func _deep() -> void:
	game.set_contract({"type": "deep", "steps": 4})
	await game.start_contract("mine")
	await step(2)
	check("the taken card is the running one", game.run_contracts.size() == 1 and game.run_contracts[0].type == "deep")
	check("deep: reach LG-05 from LG-01", game.contract_progress()[0].goal.contains("05") and game.contract_progress()[0].have == 0 and game.contract_progress()[0].need == 4)
	game.floor_number = 4
	await game.advance(0)
	await step(2)
	check("deep: done on reaching the floor, and announced", game.contract_progress()[0].done and not game._contracts_announced.is_empty() and game.prts_log.any(func(l): return "合同目标完成" in str(l)))
	var before := game.gold
	game.settle(true)
	await step(2)
	var view: Dictionary = game.settlement_view
	check("deep: extraction pays the pay fixed when it was taken (v1.1 §2.2)", view.contracts[0].done and game.gold - before == view.reward and view.reward > 0 and view.contracts[0].bonus.contains("龙门币"), [view.reward, view.contracts])
	check("a finished card leaves the board", game.base.board.run_cards("mine").is_empty())
	check("no contract runs at the base", game.run_contracts.is_empty())

func _recover() -> void:
	# 回收 is handed over at the base now (合同板修订案 §2.2: 累计型).
	game.set_contract({"type": "recover", "region": "city", "material": "糖", "count": 2, "gold": 5000, "dept": "医疗部"})
	var card: Dictionary = game.base.board.active[0]
	await game.start_contract("city")
	await step(2)
	check("recover: no run card, it is a delivery", game.run_contracts.is_empty() and game.order_progress().size() == 1)
	game.inventory.try_add(MaterialCatalog.create("糖", 1))
	await step(1)
	check("recover: the tracker counts what she carries (1 / 2)", game.order_progress()[0].have == 1 and game.order_progress()[0].need == 2)
	game.settle(true)
	await step(2)
	check("recover: still taken after the run", not game.base.board.find_active(int(card.uid)).is_empty())
	var sugar := MaterialCatalog.create("糖", 2)
	game.base.receive(sugar)
	var gold := game.gold
	check("recover: handed over at the base pays its fixed sum", game.deliver_to_order(int(card.uid), sugar) and game.gold - gold == 5000 and game.base.board.find_active(int(card.uid)).is_empty(), game.gold - gold)

func _several() -> void:
	# Several cards in one run, each paid on its own; one undone stays taken.
	game.set_contract({"type": "deep", "region": "snow", "steps": 4, "roll": 1.0})
	game.base.board.add_active({"type": "hunt", "region": "snow", "offset": 5, "roll": 1.0}, "外勤部")
	game.base.board.add_active({"type": "deep", "region": "city", "steps": 4, "roll": 1.0}, "外勤部")
	await game.start_contract("snow")
	await step(2)
	check("two cards go to 萨米, the 龙门 one waits", game.run_contracts.size() == 2 and game.run_contracts.all(func(c): return c.region == "snow"))
	check("the tracker has a row each", game.contract_progress().size() == 2)
	game.floor_number = 4
	await game.advance(0)
	await step(2)
	var gold := game.gold
	game.settle(true)
	await step(2)
	var view: Dictionary = game.settlement_view
	check("settlement lists both: depth done, the hunt not", view.contracts.size() == 2 and view.contracts[0].done and not view.contracts[1].done, view.contracts)
	check("only the done one pays", game.gold - gold == view.reward and view.reward == game.run_card_pay({"type": "deep", "steps": 4, "roll": 1.0}, 1))
	var left: Array = game.base.board.active.map(func(c): return "%s:%s" % [c.type, c.region])
	check("the hunt and the 龙门 depth stay taken", left.has("hunt:snow") and left.has("deep:city") and not left.has("deep:snow"), left)
	# A fall pays nothing and keeps the cards.
	await game.start_contract("snow")
	await step(2)
	game.player.hp = -1.0
	await step(3)
	check("death pays no objective and keeps the card", not game.settlement_view.contracts[0].done and game.base.board.active.any(func(c): return c.type == "hunt"))
	game.set_contract({})

func _hunt() -> void:
	game.set_contract({"type": "hunt", "offset": 3})
	await game.start_contract("snow")
	await step(2)
	check("hunt: no bounty before its floor", game._bounty == null and not game.is_bounty_floor())
	game.floor_number = 3
	game._ensure_route()
	# The bounty is LG-04's 险路恶敌 on the route map (肉鸽路线图策划案 v0.2 §6.1): walk the line to it.
	var col: Array = game.route_map.cols[3]
	var row: int = range(col.size()).filter(func(r): return col[r].mark == "bounty")[0]
	check("hunt: LG-04 has a 险路恶敌 marked for it", col[row].kind == "elite")
	var lines: Array = game.route_map.edges[2][game.route_node.y]
	if not lines.has(row):
		lines.append(row)
		lines.sort()
	await game.advance(lines.find(row))
	await step(2)
	var bounty := game._bounty
	check("hunt: the bounty waits on LG-04, marked as a boss", game.floor_number == 4 and is_instance_valid(bounty) and bounty.boss and bounty.elite and bounty == game.dire_foe)
	kill(bounty)
	await step(2)
	check("hunt: killing it completes the objective", game.bounty_killed and game.contract_progress()[0].done)
	var dropped := get_nodes_in_group("loot").filter(func(n): return n.item != null and n.item.rarity == Item.PURPLE and n.item.is_equippable())
	check("hunt: the bounty drops the rare piece on the spot (no settlement gift)", not dropped.is_empty())
	game.settle(true)
	await step(2)
