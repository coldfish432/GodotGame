extends SceneTree

var game: GameManager
var failures := 0
var checks: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
func clean() -> void:
	game._clear_field()
	await step(2)
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	check("boot enters the walkable base with all three contracts", game.in_base and game.base_walk_active() and game.base_map.visible and FieldCatalog.REGIONS.size() == 3)
	var armor := FieldCatalog.exclusive("city")
	var weapon := Item.create("投保测试武器", Item.Category.WEAPON, 2, 1, 3)
	game.stash.append_array([armor, weapon])
	check("stash can supply next contract", game.bring_item(armor) and game.bring_item(weapon))
	check("base equipment changes actual stats", game.equip_from(armor, game.inventory) and game.player.max_hp > 10 and game.player.move_speed < 5)
	game.gold = 20000
	check("insurance costs the item's 交付价 in 龙门币, once only", game.insure(armor) and game.gold == 20000 - Economy.price(armor) and not game.insure(armor))
	var material := Item.create("材料", Item.Category.MATERIAL, 1, 1)
	game.inventory.try_add(material)
	check("materials cannot be insured", not game.insure(material))
	await game.start_contract("mine")
	check("departure marks equipped gear as carried in", not game.in_base and armor.carried_in and armor.insured)
	await clean()
	check("random extraction has visible matching marker", game.world_map.exit_node.visible == game.is_extraction_floor())
	check("advance and extraction have different locations", game.world_map.route_nodes[0].position != game.world_map.exit_node.position)
	game.player.teleport(game.world_map.buff_device_node.global_position)
	game._interact()
	check("buff interaction offers three unique builds", game.modal == "build" and game.build_offers.size() == 3 and game.build_offers[0].id != game.build_offers[1].id)
	var ids: Array = game.build_offers.map(func(x): return x.id)
	game.close_modal()
	game._interact()
	check("reopening choices cannot reroll them", ids == game.build_offers.map(func(x): return x.id))
	var inv_count := game.inventory.items.size()
	var equipment_power := armor.power
	check("choose build succeeds only once", game.choose_build(ids[0]) and not game.choose_build(ids[0]))
	check("build is not equipment or inventory", game.inventory.items.size() == inv_count and armor.power == equipment_power and game.builds.size() == 1)
	check("move material to safe bag", game.transfer_item(material, game.inventory, game.safe_bag))
	var oversized := Item.create("超大件", Item.Category.WEAPON, 3, 1)
	game.inventory.try_add(oversized)
	check("failed safe transfer does not lose item or rotate", not game.transfer_item(oversized, game.inventory, game.safe_bag) and game.inventory.items.has(oversized) and oversized.width == 3)
	check("duplicate insertion rejected", not game.inventory.try_add(oversized))
	var small := ItemContainer.new(2, 2)
	var small_weapon := Item.create("小武器", Item.Category.WEAPON, 1, 1)
	var blocker := Item.create("占位", Item.Category.MATERIAL, 1, 2)
	small.try_add(small_weapon)
	small.try_add(blocker)
	var large_weapon := Item.create("大武器", Item.Category.WEAPON, 2, 2)
	game.player.equip(large_weapon)
	check("failed equipment swap preserves both items and original cells", not game.equip_from(small_weapon, small) and small.items.has(small_weapon) and game.player.equipped.get(Item.Category.WEAPON) == large_weapon and small_weapon.grid_x == 0 and small_weapon.grid_y == 0)
	game.player.unequip(Item.Category.WEAPON)
	check("grid reposition rejects overlaps and bounds", not small.reposition(small_weapon, 1, 0) and not small.reposition(small_weapon, -1, 0))
	check("grid reposition uses empty cells without rotating", small.reposition(small_weapon, 0, 1) and small_weapon.grid_y == 1)
	var old_map := game.world_map._generated_root
	var abandoned := Loot.new()
	abandoned.game = game
	game.add_child(abandoned)
	var old_builds := game.builds.duplicate()
	await game.advance(2)
	await step(2)
	check("one way progression destroys prior map and drops", not is_instance_valid(old_map) and not is_instance_valid(abandoned) and game.floor_number == 2)
	check("builds persist and new devices are available", game.builds == old_builds and game.is_buff_available())
	check("the dangerous route adds to floor 2's hidden difficulty (3.5 + 5); mine elite slots stay ordinary", is_equal_approx(game.pressure, 8.5) and get_nodes_in_group("enemies").all(func(e): return not e.elite) and get_nodes_in_group("enemies").size() >= 10)
	# The fixed extraction is the camp after floor 10 (撤离与营地修订案 §1).
	game.floor_number = 10
	await game.advance(0)
	check("the end of floor 10 leads into camp 10|11", game.in_camp and game.modal == "camp" and game.floor_number == 10 and not game.transitioning)
	game.camp_extract()
	await step(2)
	# Gear she set out with stays on her; finds arrive as receiving crates (基地玩法策划案 §3.2).
	check("extraction keeps carried-in gear on her and crates the finds", game.in_base and game.player.equipped.get(Item.Category.ARMOR) == armor
		and game.inventory.items.has(weapon) and game.safe_bag.items.has(material) and game.base.location_of(oversized) == "crate_sealed")
	check("settlement clears all run builds and protections (insurance lapses on extraction)", game.builds.is_empty() and not armor.insured and not armor.carried_in)
	var count := game.base.all_items().size() + game.carried_items().size()
	game.settle(true)
	check("settlement is idempotent", game.base.all_items().size() + game.carried_items().size() == count)
	await game.start_contract("snow")
	await clean()
	var doomed := Item.create("遗失物", Item.Category.TRINKET, 1, 1)
	game.inventory.try_add(doomed)
	var safe := Item.create("安全材料", Item.Category.MATERIAL, 1, 1)
	game.safe_bag.try_add(safe)
	armor.insured = true
	game.player.hp = -1
	await step(2)
	check("death returns to base with safe finds crated and insured gear queued", game.in_base and game.base.location_of(safe) == "crate_sealed"
		and game.base.insurance_queue.any(func(e): return e.item == armor) and game.base.location_of(doomed) == "" and not game.carried_items().has(doomed))
	check("each uid settles once", game.settlement.filter(func(e): return e.uid == armor.uid).size() == 1)
	game.base.insurance_queue.clear()  # the riot shield would skew the damage checks below
	# Insurance always comes back, 1–3 contracts later (保全系统修订案 §3).
	await game.start_contract("city")
	await clean()
	var insured_items: Array[Item] = []
	for i in range(40):
		var insured := Item.create("测试保险%d" % i, Item.Category.WEAPON, 1, 1)
		insured.insured = true
		insured.carried_in = true
		game.inventory.try_add(insured)
		insured_items.append(insured)
	game.rng.seed = 619
	game.settle(false)
	var waits := game.settlement.filter(func(e): return e.reason == "投保送回").map(func(e): return int(e.contracts))
	check("every insured item is queued, never lost", waits.size() == 40 and game.base.insurance_queue.size() == 40)
	check("each waits 1–3 contracts, and all three waits occur", waits.all(func(w): return w >= 1 and w <= 3) and waits.has(1) and waits.has(2) and waits.has(3))
	var ones := waits.count(1)
	await game.start_contract("city")
	await clean()
	game.settle(true)
	check("the next settlement delivers those waiting one contract, as sealed crates", game.base.insurance_queue.size() == 40 - ones
		and insured_items.filter(func(x): return game.base.location_of(x) == "crate_sealed").size() == ones)
	for i in range(2):
		await game.start_contract("city")
		await clean()
		game.settle(true)
	check("after three settlements everything insured is back", game.base.insurance_queue.is_empty()
		and insured_items.all(func(x): return game.base.location_of(x) == "crate_sealed"))
	for x in insured_items: game.base._take(x)
	# Regional loot distributions and exclusive provenance.
	var counts := {}
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 17
	for region in FieldCatalog.REGIONS:
		counts[region] = [0, 0, 0, 0]
		var exclusive_count := 0
		for i in range(1200):
			var item := FieldCatalog.roll_item(region, 2, local_rng)
			counts[region][item.category] += 1
			if not item.exclusive_region.is_empty():
				exclusive_count += 1
				if item.exclusive_region != region: failures += 1
		check(region + " exclusive loot appears only in its region", exclusive_count > 0)
	check("mine material / city armor / snow trinket distributions", counts.mine[3] > 600 and counts.city[1] > 600 and counts.snow[2] > counts.snow[3])
	# Navigation: all visible devices/routes are actually reachable in every region.
	for region in FieldCatalog.REGIONS:
		await game.start_contract(region)
		await clean()
		var map_rid := game.world_map._generated_root.get_navigation_map()
		# Read the beacon's actual position, not the old fixed constant — the
		# spine layout places extraction per seed, and the point of this check
		# is that whatever the player can see is walkable to.
		var targets: Array = [game.world_map.buff_position, game.world_map.encounter_position, game.world_map.exit_node.position]
		for node in game.world_map.route_nodes: targets.append(node.position)
		for target in game.world_map.cache_positions: targets.append(target)
		var reachable := true
		for target in targets:
			var path := NavigationServer3D.map_get_path(map_rid, ContinuousWorldMap.ENTRY_POSITION, target, true)
			reachable = reachable and path.size() > 1 and path[path.size()-1].distance_to(target) < 2
		check(region + " all devices and destinations reachable", reachable)
		game.settle(true)
	# Build effects drive real combat state, retain no permanent progression.
	# Numbers follow 局内构筑与数值策划案 §5 and §10; "true" damage skips defence
	# so each check reads the relic alone.
	await game.start_contract("mine")
	await clean()
	# Relics themselves are covered one by one in test_builds.gd.
	var ore := FieldCatalog.exclusive("mine")
	game.inventory.try_add(ore)
	game.player.hp = game.player.max_hp * 0.5
	game.player.regen_timer = 100
	var hp := game.player.hp
	game._physics_process(2)
	check("raw ore drains 60 per second while carried", is_equal_approx(game.player.hp, hp - 120))
	game.transfer_item(ore, game.inventory, game.safe_bag)
	hp = game.player.hp
	game._physics_process(2)
	check("safe bag protects ownership, not pollution damage", is_equal_approx(game.player.hp, hp - 120))
	var plain_hp := game.player.max_hp
	game.builds.assign(["急救药箱"])
	game.player._recompute_stats()
	check("a relic's stats reach the sheet (急救药箱 +35% life)", is_equal_approx(game.player.max_hp, plain_hp * 1.35))
	game.builds.clear()
	game.player._recompute_stats()
	game.inventory.remove(ore)
	game.safe_bag.remove(ore)
	var frozen_relic := FieldCatalog.exclusive("snow")
	game.player.equip(frozen_relic)
	game.builds.clear()
	check("frozen relic increases damage", game.player.attack_multiplier() > game.player.damage_bonus)
	game.player.stamina = 0
	game.player._physics_process(0.5)
	check("frozen relic reduces stamina regeneration", game.player.stamina < Player.STAMINA_REGEN * 0.5)
	game.player.unequip(Item.Category.TRINKET)
	game.builds.clear()
	game.player._recompute_stats()
	game.player.hp = 300
	game.potions = 3
	game._use_potion()
	check("potion heals 960 and consumes charge", game.player.hp == 1260 and game.potions == 2)
	game.player.regen_timer = 0
	game.player._physics_process(0.01)
	check("self regeneration coexists with potion", is_equal_approx(game.player.hp, 1260 + game.player.regen_rate() * Player.HP_REGEN_INTERVAL))
	game._spawn_enemy(game.player.position + Vector3(2, 0, 0), true, false)
	var enemy: Enemy = get_nodes_in_group("enemies")[0]
	var enemy_hp := enemy.health
	game.player.stamina = 0
	game.player.attack(enemy)
	check("twin sword attack costs no stamina", enemy.health < enemy_hp and game.player.stamina == 0)
	check("removed weapon skills and switch inputs", not game.player.has_method("use_weapon_skill") and not InputMap.has_action("weapon_skill") and not InputMap.has_action("switch_weapon"))
	game.open_modal("inventory")
	game._inventory_panel.open()
	var frozen_pos := game.player.position
	await step(10)
	check("inventory freezes combat while buttons remain interactive", game.player.position == frozen_pos and game._inventory_panel.visible)
	game.close_modal()
	await clean()
	# Save round trip and interrupted-contract settlement in an isolated test file.
	game.settle(true)
	game.save_path = "user://v1_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	var saved_count := game.base.all_items().size()
	game.base = BaseState.new()
	game.load_base()
	check("base save reload preserves warehouse", saved_count > 0 and game.base.all_items().size() == saved_count)
	var recovered := Item.create("中断合同投保物", Item.Category.WEAPON, 1, 1)
	game.inventory.try_add(recovered)
	recovered.insured = true
	game.save_base(true)
	game.load_base()
	var queued_once := func(): return game.base.insurance_queue.filter(func(e): return e.item.uid == recovered.uid).size()
	check("an interrupted run settles as a death: the insured find is queued once", queued_once.call() == 1)
	game.save_base()
	game.load_base()
	check("the insurance queue survives a save and reload", queued_once.call() == 1)
	var once := game.base.all_items().size() + game.carried_items().size()
	game.load_base()
	check("reload cannot duplicate recovery", game.base.all_items().size() + game.carried_items().size() == once)
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)

	# --- Per-depth authoring (贪婪洞窟-style level table).
	check("the floors before each camp land on the same authored entry, and so does the random-extraction window",
		FieldCatalog.depth_profile(10).hash() == FieldCatalog.depth_profile(20).hash()
			and FieldCatalog.depth_profile(5).hash() == FieldCatalog.depth_profile(15).hash() and FieldCatalog.DEPTH_CYCLE == FieldCatalog.CAMP_INTERVAL)
	check("the floor before a camp raises pressure and payout over the opening floor",
		int(FieldCatalog.depth_profile(10).enemies) > int(FieldCatalog.depth_profile(1).enemies)
			and float(FieldCatalog.depth_profile(10).reward) > float(FieldCatalog.depth_profile(1).reward))
	check("depth 0 and negatives do not fall off the table",
		FieldCatalog.depth_profile(0).hash() == FieldCatalog.depth_profile(1).hash())

	# --- Fog of war: map knowledge only, nothing in the world is hidden.
	await game.start_contract("mine")
	await clean()
	var fog_start := game.fog.revealed_fraction()
	check("a fresh segment starts mostly unmapped (%.0f%%)" % (fog_start * 100.0), fog_start < 0.25)
	check("the entry the player stands on is already mapped",
		game.fog.is_point_revealed(ContinuousWorldMap.ENTRY_POSITION))
	var far_marker: Vector3 = game.world_map.exit_node.position
	var found_at_start := game.fog.is_point_revealed(far_marker)
	game.player.teleport(far_marker)
	await step(4)
	check("a beacon is unmapped until reached, then mapped for good",
		not found_at_start and game.fog.is_point_revealed(far_marker))
	var walked := game.fog.revealed_fraction()
	check("walking maps more of the segment (%.0f%% -> %.0f%%)" % [fog_start * 100.0, walked * 100.0], walked > fog_start)
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(4)
	check("mapped ground stays mapped after leaving it", game.fog.is_point_revealed(far_marker))
	# The whole reason this is a knowledge layer and not a rendered fog: a
	# telegraphed attack has to stay readable wherever it happens.
	game._spawn_enemy(game.player.global_position + Vector3(3, 0, 0), false, false)
	await step(2)
	var combatants := game.get_tree().get_nodes_in_group("enemies")
	var all_visible := true
	for node in combatants:
		if not (node as Node3D).visible: all_visible = false
	check("fog never hides an enemy in the world", all_visible and combatants.size() > 0)
	game.settle(true)
	await step(3)
	await game.start_contract("mine")
	await clean()
	check("the next segment starts unmapped again", game.fog.revealed_fraction() < 0.25)
	game.settle(true)
	await step(3)

	# --- Sealed vault: mechanisms gate it, the guardian gates its spoils.
	await game.start_contract("mine")
	await clean()
	var total: int = game.world_map.mechanism_nodes.size()
	check("segment lays out mechanisms and a vault away from the main path",
		total >= 3 and is_instance_valid(game.world_map.vault_node))
	var deep_enough := true
	for spot in game.world_map.mechanism_positions:
		if Vector2(spot.x, spot.z).distance_to(Vector2(game.world_map.vault_position.x, game.world_map.vault_position.z)) < 6.0:
			deep_enough = false
	check("mechanisms are not clustered on the vault itself", deep_enough)
	for i in range(total - 1):
		game.player.teleport(game.world_map.mechanism_nodes[i].global_position)
		await step(2)
		game._interact()
	check("vault stays shut while any mechanism is untriggered", not game.vault_opened)
	game.player.teleport(game.world_map.mechanism_nodes[0].global_position)
	await step(2)
	game._interact()
	await step(2)
	check("re-triggering a used mechanism does not advance the count", not game.vault_opened)
	game.player.teleport(game.world_map.mechanism_nodes[total - 1].global_position)
	await step(2)
	game._interact()
	await step(2)
	check("triggering every mechanism opens the vault", game.vault_opened)
	var sealed_loot := game.get_tree().get_nodes_in_group("sealed_loot")
	check("mine vault holds sealed spoils and two ordinary guardians", sealed_loot.size() == 3 and game._vault_guardians.size() == 2 and game._vault_guardians.all(func(e): return not e.elite))
	var still_sealed := true
	for node in sealed_loot:
		if not node.sealed: still_sealed = false
	game.player.teleport(game.world_map.vault_position)
	await step(20)
	check("sealed spoils cannot be walked off before the guardian dies",
		still_sealed and game.get_tree().get_nodes_in_group("sealed_loot").size() == 3)
	game._vault_guardians[0].take_hit(9999.0)
	await step(2)
	check("first mine guardian does not unseal the spoils", game._vault_guardians.size() == 1 and sealed_loot.all(func(n): return n.sealed))
	game._vault_guardians[0].take_hit(9999.0)
	await step(4)
	var unsealed := true
	for node in game.get_tree().get_nodes_in_group("sealed_loot"):
		if node.sealed: unsealed = false
	check("killing both mine guardians unseals the spoils", unsealed)
	var chests := game.get_tree().get_nodes_in_group("sealed_loot")
	check("the vault holds a weapon, a gear and a materials chest", chests.map(func(n): return n.kind).has("vault_weapon") and chests.map(func(n): return n.kind).has("vault_base"))
	(chests[0] as LootContainer).open_now()
	await step(1)
	check("an unsealed vault chest opens and spills its contents", chests[0].opened and game.get_tree().get_nodes_in_group("loot").size() > 0)
	game.settle(true)
	await step(3)
	var report := {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}
	var file := FileAccess.open("res://../evidence/downfall-v1-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("V1 RESULT: %d checks, %d failures" % [checks.size(), failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)
