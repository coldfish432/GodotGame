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
	await _search_and_recover()
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
	var offers: Array = game.contract_offers("mine")
	var kinds := offers.map(func(o): return o.type)
	check("the desk offers three contracts of different kinds", offers.size() == 3 and kinds.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2] and kinds[0] != kinds[2], kinds)
	check("every offer reads as a goal and a bonus", offers.all(func(o): return not FieldCatalog.contract_goal(o, "mine", 1).is_empty() and not FieldCatalog.contract_bonus_text(o).is_empty()))
	var recover := FieldCatalog.roll_contracts("snow", game.rng).filter(func(o): return o.type == "recover")
	for o in recover: check("a recover target is a common drop of that region's enemies", FieldCatalog.RECOVER_TARGETS.snow.any(func(t): return t[0] == o.material))
	var data := game.base.to_data()
	var copy := BaseState.new()
	copy.load_data(data, {})
	check("offers are saved with the base", copy.contract_offers.has("mine") and (copy.contract_offers.mine as Array).size() == 3)

func _deep() -> void:
	game._pending_contract = {"type": "deep", "steps": 4}
	await game.start_contract("mine")
	await step(2)
	check("the chosen contract is the running one", game.contract.type == "deep" and game._pending_contract.is_empty())
	check("deep: reach LG-05 from LG-01", game.contract_progress().goal.contains("05") and game.contract_progress().have == 0 and game.contract_progress().need == 4)
	game.floor_number = 4
	await game.advance(0)
	await step(2)
	check("deep: done on reaching the floor, and announced", game.contract_progress().done and game._contract_announced and game.prts_log.any(func(l): return "合同目标完成" in str(l)))
	var before := game.gold
	game.settle(true)
	await step(2)
	var view: Dictionary = game.settlement_view
	check("deep: extraction pays the pay fixed when it was taken (v1.1 §2.2)", view.contract.done and game.gold - before == view.reward and view.reward > 0 and view.contract.bonus.contains("龙门币"), [view.reward, view.contract])
	check("after settling the region's offers are rolled again", not game.base.contract_offers.has("mine") or (game.base.contract_offers.mine as Array).size() == 3)
	check("no contract runs at the base", game.contract.is_empty())

func _search_and_recover() -> void:
	game._pending_contract = {"type": "search", "vaults": 2}  # cards ask for 1 now; 2 checks the count
	await game.start_contract("city")
	await step(2)
	game._open_vault()
	check("search: one vault counts 1 / 2", game.contract_progress().have == 1 and not game.contract_progress().done)
	game.vault_opened = false
	game._open_vault()
	check("search: two vaults complete it", game.contract_progress().done)
	game.player.hp = -1.0
	await step(3)
	check("death pays no objective bonus", not game.settlement_view.contract.done)

	game._pending_contract = {"type": "recover", "material": "糖", "count": 2}
	await game.start_contract("city")
	await step(2)
	game.inventory.try_add(MaterialCatalog.create("糖", 1))
	await step(1)
	check("recover: counts what she carries (1 / 2)", game.contract_progress().have == 1 and not game.contract_progress().done)
	game.safe_bag.try_add(MaterialCatalog.create("糖", 1))
	await step(1)
	check("recover: the safe bag counts too", game.contract_progress().done)
	var gold := game.gold
	game.settle(true)
	await step(2)
	check("recover: extraction pays the contract, no more money", game.settlement_view.contract.done and game.gold - gold == game.settlement_view.reward)

func _hunt() -> void:
	game._pending_contract = {"type": "hunt", "offset": 3}
	await game.start_contract("snow")
	await step(2)
	check("hunt: no bounty before its floor", game._bounty == null and not game.is_bounty_floor())
	game.floor_number = 3
	await game.advance(0)
	await step(2)
	var bounty := game._bounty
	check("hunt: the bounty waits on LG-04, marked as a boss", game.floor_number == 4 and is_instance_valid(bounty) and bounty.boss and bounty.elite)
	kill(bounty)
	await step(2)
	check("hunt: killing it completes the objective", game.bounty_killed and game.contract_progress().done)
	var dropped := get_nodes_in_group("loot").filter(func(n): return n.item != null and n.item.rarity == Item.PURPLE and n.item.is_equippable())
	check("hunt: the bounty drops the rare piece on the spot (no settlement gift)", not dropped.is_empty())
	game.settle(true)
	await step(2)
