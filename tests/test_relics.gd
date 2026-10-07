extends SceneTree

## The general ItemModifier system (stat percentages + the one trigger
## effect) that named weapons/relics layer on top of the flat "power"
## formula — see entities/player.gd's _recompute_stats() and
## game/game_manager.gd's _roll_named_item(). Plain loot (tested in
## test_economy.gd) never touches this; these are only relevant once an
## item carries ItemModifiers.

const Game = preload("res://game/game_manager.gd")
const ItemScript = preload("res://inventory/item.gd")
const ModScript = preload("res://inventory/item_modifier.gd")

var game: Node3D
var results: Array[Dictionary] = []
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(id: String, passed: bool, observation: Dictionary) -> void:
	results.append({"id": id, "status": "PASS" if passed else "FAIL", "observed": observation})
	if not passed:
		failures += 1
	print(JSON.stringify(results.back()))

func make_relic(item_name: String, modifiers: Array) -> Item:
	var item: Item = ItemScript.create(item_name, ItemScript.Category.TRINKET, 1, 1, 0.0)
	var typed: Array[ItemModifier] = []
	for m in modifiers:
		typed.append(m)
	item.modifiers = typed
	return item

func run() -> void:
	game = Game.new()
	game.start_at_base = false
	game.save_enabled = false
	root.add_child(game)
	await step(6)
	var anchor: Vector3 = ContinuousWorldMap.ENTRY_POSITION
	game.player.teleport(anchor)

	# --- Stat-percentage modifiers stack on top of the base values.
	var base_max_hp: float = game.player.max_hp
	var base_move_speed: float = game.player.move_speed
	var carapace := make_relic("测试甲壳", [
		ModScript.stat_mod(ModScript.Stat.MAX_HP_PCT, 0.30),
		ModScript.stat_mod(ModScript.Stat.MOVE_SPEED_PCT, -0.15),
	])
	game.player.equip(carapace)
	check("stat-pct-modifiers-apply-on-equip", is_equal_approx(game.player.max_hp, base_max_hp * 1.30) and is_equal_approx(game.player.move_speed, base_move_speed * 0.85),
		{"max_hp": game.player.max_hp, "expected_max_hp": base_max_hp * 1.30, "move_speed": game.player.move_speed})
	game.player.unequip(Item.Category.TRINKET)
	check("stat-pct-modifiers-revert-on-unequip", is_equal_approx(game.player.max_hp, base_max_hp) and is_equal_approx(game.player.move_speed, base_move_speed),
		{"max_hp": game.player.max_hp, "move_speed": game.player.move_speed})

	# --- Gold-gain modifier affects GameManager.add_gold, not just Player state.
	var collector := make_relic("测试收集者", [ModScript.stat_mod(ModScript.Stat.GOLD_GAIN_PCT, 0.50)])
	game.player.equip(collector)
	var gold_before: int = game.run_gold
	game.add_gold(10)
	check("gold-gain-modifier-applies-in-add-gold", game.run_gold == gold_before + 15,
		{"gold_before": gold_before, "gold_after": game.run_gold})
	game.player.unequip(Item.Category.TRINKET)

	# --- The old flask-capacity stat now scales flask healing (药剂进背包: flasks
	# are pack items, there is no belt to shrink). Each point is ±20%.
	check("flask-healing-starts-at-100%", is_equal_approx(game.player.potion_heal_multiplier, 1.0), {"multiplier": game.player.potion_heal_multiplier})
	var capacity_drain := make_relic("测试负重", [ModScript.stat_mod(ModScript.Stat.POTION_CAPACITY_FLAT, -1.0)])
	game.player.equip(capacity_drain)
	await step(2)
	check("flask-stat-minus-one-cuts-healing-20%", is_equal_approx(game.player.potion_heal_multiplier, 0.8), {"multiplier": game.player.potion_heal_multiplier})
	game.player.unequip(Item.Category.TRINKET)
	await step(2)
	check("flask-healing-reverts-on-unequip", is_equal_approx(game.player.potion_heal_multiplier, 1.0), {"multiplier": game.player.potion_heal_multiplier})

	# --- Blade-cooldown modifier changes the derived cooldown Player.attack() uses.
	var base_blade_cooldown: float = game.player.blade_cooldown
	var haste := make_relic("测试战意", [ModScript.stat_mod(ModScript.Stat.BLADE_COOLDOWN_PCT, -0.30)])
	game.player.equip(haste)
	check("blade-cooldown-modifier-applies", is_equal_approx(game.player.blade_cooldown, base_blade_cooldown * 0.70),
		{"blade_cooldown": game.player.blade_cooldown, "expected": base_blade_cooldown * 0.70})
	game.player.unequip(Item.Category.TRINKET)

	# --- The low-hp-shield trigger: blocks exactly one lethal-feeling hit
	# per floor, then stops, then becomes available again on a floor change.
	var full: float = game.player.max_hp
	game.player.hp = full
	var ward := make_relic("测试结界", [ModScript.trigger_mod(ModScript.Trigger.LOW_HP_SHIELD_ONCE_PER_FLOOR)])
	game.player.equip(ward)
	game.player.take_damage(full * 0.8, "true")  # would drop to 20% < 30% threshold
	check("ward-blocks-a-hit-that-would-drop-below-30-percent", is_equal_approx(game.player.hp, full),
		{"hp": game.player.hp})
	game.player.take_damage(full * 0.8, "true")  # second such hit this floor — ward already spent
	check("ward-does-not-block-a-second-hit-same-floor", game.player.hp < full,
		{"hp": game.player.hp})

	game.player.hp = full
	game._build_world()  # any floor rebuild resets the once-per-floor flag
	game.player.take_damage(full * 0.8, "true")
	check("ward-is-available-again-after-a-floor-change", is_equal_approx(game.player.hp, full),
		{"hp": game.player.hp})
	game.player.unequip(Item.Category.TRINKET)
	game.player.hp = game.player.max_hp

	# --- The rare named-item/relic roll table produces valid items across
	# all of its branches without crashing.
	var seen_categories := {}
	var all_valid := true
	for i in range(200):
		game.region_id = ["mine", "city", "snow"][i % 3]
		var item: Item = game._roll_named_item()
		if item == null or item.item_name == "":
			all_valid = false
			break
		seen_categories[item.category] = true
	check("named-item-rolls-are-always-valid", all_valid, {"all_valid": all_valid})
	check("named-item-rolls-cover-multiple-categories", seen_categories.size() >= 2,
		{"categories_seen": seen_categories.size()})

	var report := {
		"scope": "downfall-godot relic/modifier tests (stat-pct modifiers, gold-gain, potion capacity, blade cooldown, once-per-floor trigger, named-item roll table)",
		"engine": Engine.get_version_info().string,
		"created_at": Time.get_datetime_string_from_system(true),
		"results": results,
		"failures": failures,
	}
	var evidence_dir := ProjectSettings.globalize_path("res://../evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var file := FileAccess.open(evidence_dir + "/downfall-test-relics-" + str(Time.get_unix_time_from_system()) + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("DOWNFALL TEST_RELICS: %d checks / %d failures" % [results.size(), failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
