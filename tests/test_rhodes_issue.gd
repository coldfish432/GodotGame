extends SceneTree
## 制式保底修订 (用户 2026-10-23): Rhodes standard gear is issued free at the
## workbench into any slot, bound to the contract — no selling, packing,
## insuring or refitting — and taken back when it ends, home or not.
var game: GameManager
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or str(detail).is_empty() else "  [%s]" % str(detail)))
	if not passed: failures += 1

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.rng.seed = 91
	_issue()
	_bound()
	_own_gear()
	await _contracts()
	_old_save()
	print("RHODES ISSUE RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func _worn_bound() -> Array:
	return game.player.equipped.values().filter(func(it): return GearCatalog.bound(it))

func _kept_anywhere() -> Array:
	return (game.base.all_items() + game.inventory.items + game.safe_bag.items).filter(func(it): return GearCatalog.bound(it))

func _issue() -> void:
	game.player.reset_stats()
	check("bare: no Rhodes set is waiting in the warehouse", _kept_anywhere().is_empty())
	check("补齐空槽 fills all eight slots", game.fill_rhodes() == 8 and _worn_bound().size() == 8, _worn_bound().size())
	check("…white, tier Ⅰ", _worn_bound().all(func(it): return it.rarity == 0 and it.grade == 1))
	check("nothing left to fill", game.fill_rhodes() == 0)
	check("a slot's other choice replaces the piece", game.issue_rhodes("rhodes_vest") and game.player.equipped[Item.Category.CHEST].base_id == "rhodes_vest" and _kept_anywhere().is_empty())
	check("a weapon she cannot wield is refused", not game.issue_rhodes("rhodes_staff"))
	game.base.rhodes_rarity = 2
	game.refresh_rhodes()
	check("after 制式换代 the worn set turns gold", _worn_bound().all(func(it): return it.rarity == 2))
	game.base.rhodes_rarity = 0
	game.refresh_rhodes()

func _bound() -> void:
	var weapon: Item = game.player.equipped[Item.Category.WEAPON]
	check("not for sale, delivery or orders", not game.can_sell(weapon) and game.trader_offer(weapon) == 0
		and range(game.base.orders.slots.size()).all(func(slot): return not game.base.orders.matches(slot, weapon)))
	check("not insured, packed, consigned or refitted", not game.insure(weapon) and not weapon.insured and not Packs.packable(weapon)
		and not Consignment.takes(weapon) and game.refresh_refusal("reforge", weapon) == "无法改造")
	check("unworn at the base it is handed back", game.unequip_to_pack(weapon) and game.player.equipped.get(Item.Category.WEAPON) == null and _kept_anywhere().is_empty())
	game.issue_rhodes("rhodes_sword")
	var head: Item = game.player.equipped[Item.Category.HEAD]
	check("stored at the base it is handed back too", game.store_item(head) and game.player.equipped.get(Item.Category.HEAD) == null and _kept_anywhere().is_empty())
	game.fill_rhodes()

func _own_gear() -> void:
	var own := LootTables.roll_equipment(Item.Category.WEAPON, "矿区制式刀", "mine", 4, 1, game.rng)
	game.base.store(own)
	check("her own weapon replaces the Rhodes one, which is not stored", game.equip_from_stash(own) and game.player.equipped[Item.Category.WEAPON] == own and _kept_anywhere().is_empty())
	check("…and a Rhodes weapon sends hers back to the shelf", game.issue_rhodes("rhodes_dual_blades") and game.stash.has(own))
	game.equip_from_stash(own)

func _contracts() -> void:
	var own: Item = game.player.equipped[Item.Category.WEAPON]
	game._pending_contract = {"type": "deep", "steps": 4, "roll": 1.0}
	await game.start_contract("mine")
	await step(2)
	# One piece in the pack, one in the safe bag: neither is kept.
	var chest: Item = game.player.equipped[Item.Category.CHEST]
	game.unequip_to_pack(chest)
	var ring: Item = game.player.equipped[Item.Category.RING]
	game.player.unequip(Item.Category.RING)
	game.safe_bag.try_add(ring)
	check("in the field a Rhodes piece can go into the pack", game.inventory.items.has(chest) and game.safe_bag.items.has(ring))
	game._clear_field()
	game.settle(true)
	await step(2)
	check("extracted: every Rhodes piece is taken back", _worn_bound().is_empty() and _kept_anywhere().is_empty(), _kept_anywhere().map(func(it): return it.item_name))
	check("…her own weapon stays on her", game.player.equipped.get(Item.Category.WEAPON) == own)
	check("…and the settlement says so", game.settlement.filter(func(e): return e.reason == "制式收回").size() == 7, game.settlement.map(func(e): return e.reason))
	game.fill_rhodes()
	game._pending_contract = {"type": "deep", "steps": 4, "roll": 1.0}
	await game.start_contract("mine")
	await step(2)
	var head: Item = game.player.equipped[Item.Category.HEAD]
	game.player.unequip(Item.Category.HEAD)
	game.safe_bag.try_add(head)
	game._clear_field()
	game.settle(false)
	await step(2)
	check("fallen: taken back, the safe bag too", _worn_bound().is_empty() and _kept_anywhere().is_empty())

func _old_save() -> void:
	game.base.shelf.append(GearCatalog.make_rhodes("rhodes_badge"))
	game.base.shelf.append(GearCatalog.make_rhodes("rhodes_medkit"))  # 仓库修订: old staging folds into the warehouse
	game.base.receive(GearCatalog.make_rhodes("rhodes_beacon"))
	check("an old save's Rhodes pieces leave the warehouse", game.base.purge_bound() == 3 and _kept_anywhere().is_empty())
	var job := {"id": 99, "output": "罗德岛制式剑", "count": 1, "due": 0, "byproducts": {}}
	game.workshop.jobs.append(job)
	var gold := game.gold
	game._tick_workshop()
	check("a Rhodes job queued before gives its cost back", game.gold - gold == int(Workshop.RETIRED_GEAR["罗德岛制式剑"].lmd)
		and game.base.all_items().any(func(it): return it.material_id == "异铁组") and _kept_anywhere().is_empty())
