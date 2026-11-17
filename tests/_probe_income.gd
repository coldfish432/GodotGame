extends SceneTree

## Temporary income probe (用户 2026-11-13: 重跑收入探针). Builds real floors through
## the game's own path (start_contract, then _advance_floor to the depth), counts
## what stands on them, and rolls every enemy's and point's loot ROLLS times with
## the live tables, priced with Economy.price. One region per process:
##   DOWNFALL_PROBE_REGION=mine godot --headless --path . --script res://tests/_probe_income.gd
## Prints one "PROBE {json}" line per floor. Not in run_all.

const DEPTHS := [5, 25, 45, 65, 85]
const SEEDS := [101, 202, 303]
const ROLLS := 20

var game: GameManager

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func run() -> void:
	var region := OS.get_environment("DOWNFALL_PROBE_REGION")
	if region.is_empty(): region = "mine"
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_step"] = TutorialCard.STEPS.size()
	SystemScreens.settings["tutorial_tips"] = false
	SystemScreens.settings["story_guide"] = false
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	game.route_plain = true
	for s in SEEDS:
		for depth in DEPTHS:
			await probe_floor(region, s, depth)
	quit(0)

func probe_floor(region: String, map_seed: int, depth: int) -> void:
	game.fixed_map_seed = map_seed * 100 + depth
	game.seed_rng(map_seed * 1000 + depth)
	if game.in_base:
		await game.start_contract(region)
		await step(5)
	game._run_seed = map_seed * 7777
	game.floor_number = depth - 1
	game._advance_floor(game.route_node.y)
	while game.transitioning: await step(1)
	await step(5)
	var enemies: Array = game.floor_enemies()
	var boxes: Array = []
	for node in game.get_children():
		if node is LootContainer: boxes.append(node)
	var mat_q := {}          # material id → [quantity summed over rolls, max_stack, unit value]
	var gear_value := 0.0
	var gear_cells := 0.0
	var other_value := 0.0
	var other_cells := 0.0
	var gold_units := 0.0
	var gear_by_slot := {}   # category → [value, cells]
	var elites := 0
	var guards := 0
	for e in enemies:
		if e.elite: elites += 1
		if e.behavior == Enemy.Behavior.GUARD: guards += 1
	var mat_value := 0.0
	var mat_cells := 0.0
	var mat_all := {}
	for r in range(ROLLS):
		mat_q.clear()
		var drops: Array = []
		for e in enemies:
			if e.patrol_wave > 0 or e.called_in: continue
			if not e.elite and not e.boss and game.drop_share < 1.0 and game.rng_loot.randf() > game.drop_share: continue
			if not e.elite and not e.boss and e.behavior == Enemy.Behavior.GUARD and game.rng_loot.randf() > GameManager.guard_drop_share(): continue
			var ctx := game.loot_ctx()
			ctx["boss"] = e.boss
			drops.append_array(LootTables.enemy_drops(e.enemy_type, e.elite, e.behavior == Enemy.Behavior.GUARD, ctx))
		for b in boxes:
			drops.append_array(LootTables.container_drops(b.kind, game.loot_ctx(), b.guarded))
			if b.mimic: drops.append_array(LootTables.container_drops(b.kind, game.loot_ctx(), false))
		for d in drops:
			if not d.has("item"):
				var units := float(d.gold)
				if d.get("single", false): units = minf(units, Economy.OLD_REWARD_PER_BAR)
				gold_units += units
				continue
			var item: Item = d.item
			if item == null: continue
			if item.material_id == Economy.GOLD_ID or item.item_name == Economy.GOLD_ID:
				gold_units += item.quantity * Economy.OLD_REWARD_PER_BAR
			elif not item.material_id.is_empty():
				var key := item.material_id
				if not mat_q.has(key): mat_q[key] = [0, maxi(item.max_stack, 1), item.unit_value]
				mat_q[key][0] += item.quantity
				mat_value += Economy.price(item)
			elif item.is_equippable():
				var v := float(Economy.price(item))
				var c := float(item.width * item.height)
				gear_value += v
				gear_cells += c
				var cat: String = Item.CATEGORY_NAMES[item.category]
				if not gear_by_slot.has(cat): gear_by_slot[cat] = [0.0, 0.0, 0]
				gear_by_slot[cat][0] += v
				gear_by_slot[cat][1] += c
				gear_by_slot[cat][2] += 1
			else:
				other_value += Economy.price(item)
				other_cells += item.width * item.height
		for key in mat_q: mat_cells += ceilf(float(mat_q[key][0]) / float(mat_q[key][1]))
		for key in mat_q:
			if not mat_all.has(key): mat_all[key] = [0.0, mat_q[key][1], mat_q[key][2] * Economy.LMD_PER_VALUE]
			mat_all[key][0] += float(mat_q[key][0]) / ROLLS
	for cat in gear_by_slot:
		for i in range(3): gear_by_slot[cat][i] = gear_by_slot[cat][i] / ROLLS
	var out := {
		"region": region, "seed": map_seed, "depth": game.floor_number, "route": game.route_kind,
		"pois": boxes.size(), "enemies": enemies.size(), "elites": elites, "guards": guards, "drop_share": game.drop_share,
		"mat": mat_value / ROLLS, "mat_cells": mat_cells / ROLLS, "gear": gear_value / ROLLS, "gear_cells": gear_cells / ROLLS,
		"other": other_value / ROLLS, "other_cells": other_cells / ROLLS, "bars": gold_units / ROLLS / Economy.OLD_REWARD_PER_BAR,
		"slots": gear_by_slot, "mats": mat_all,
	}
	print("PROBE " + JSON.stringify(out))
	await step(2)

