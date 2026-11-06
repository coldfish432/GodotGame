extends SceneTree

## Damage numbers (用户 2026-11-02): every hit in its damage type's colour, a
## crit too (larger, with "!"), damage taken as well; hits on one target
## stack on the same spot as separate numbers, never summed.

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func step(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func numbers(game: GameManager) -> Array:
	return game.number_layer.get_children().filter(func(n): return n is DamageNumber and not n.is_queued_for_deletion())

func colour(label: DamageNumber) -> Color:
	return label.get_theme_color("font_color")

func run() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	await game.start_contract("city")
	var p := game.player
	game.set_process(false)
	p.set_physics_process(false)
	game._clear_field()
	await step(2)
	var enemy := game._spawn_enemy(p.global_position + Vector3(3, 0, 0), false, false)
	enemy.set_physics_process(false)
	enemy.max_health = 1e9
	enemy.health = 1e9
	await step(1)
	for n in numbers(game): n.free()

	enemy.take_hit(100.0, "phys", true)
	enemy.take_hit(100.0, "arts", false)
	enemy.take_hit(100.0, "burn", true)
	var shown := numbers(game)
	check("three hits, three numbers", shown.size() == 3, shown.size())
	if shown.size() == 3:
		check("a physical crit stays physical white", colour(shown[0]) == DamageNumber.COLORS.phys and shown[0].text.ends_with("!"), colour(shown[0]))
		check("arts is violet", colour(shown[1]) == DamageNumber.COLORS.arts, colour(shown[1]))
		check("a burn crit stays burn", colour(shown[2]) == DamageNumber.COLORS.burn, colour(shown[2]))
		check("a crit is larger", shown[0].get_theme_font_size("font_size") > shown[1].get_theme_font_size("font_size"))
		check("hits on one target share one spot", shown[0].world_point == shown[1].world_point and shown[1].world_point == shown[2].world_point, shown.map(func(n): return n.world_point))
		check("each keeps its own value", shown.all(func(n): return n.text.trim_suffix("!") != "300"))
	for n in numbers(game): n.free()

	p.invuln_timer = 0.0
	p.stats.evasion_arts = -1.0
	p.take_damage(50.0, "arts")
	shown = numbers(game)
	check("damage taken shows in its type's colour", shown.size() == 1 and colour(shown[0]) == DamageNumber.COLORS.arts, shown.map(func(n): return colour(n)))

	print("DAMAGE NUMBERS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
