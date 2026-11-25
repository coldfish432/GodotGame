extends SceneTree
## Not a test — a real-renderer clip of 元素阈值修订案 v0.1 at one depth
## (ELEM_REC=<floor>, e.g. 1 / 31 / 61 / 91): the 雪原 floor's own enemies
## (grown with the floor, contract factor of its first floor) against her in
## the gear tools/depth_model.py expects by then (the best piece's usual
## rarity in every slot), with an element build on top: 灼燃 on the weapon
## (a 龙门 deep weapon's 25% 转化 from floor 31, 附加 6% before), 侵蚀 附加 on
## the ring and the amulet (2.5% each); 雪原 resists neither. She fights for real; prints
## "MARK <frame> ..." at every ring that goes off. No captions (用户: 不要文字).
## Run with Movie Maker (30 fps, 1280×720):
##   set ELEM_REC=31
##   godot --path downfall-godot --script res://tests/record_element_depth.gd --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 30 --write-movie <dir>/frame.png

const REGION := "snow"
const FIGHT_SECONDS := 32.0
## depth_model.worn(): the usual best rarity in a slot by that floor.
const RARITY := {1: Item.GREY, 31: Item.GREEN, 61: Item.BLUE, 91: Item.PURPLE}
## 属性伤害与地区装备策划案 v1.1 §7: an affix's size × the rarity's factor.
const RARITY_FACTOR := [0.6, 0.8, 1.0, 1.2, 1.4, 1.4]

var rig: Node
var game: GameManager

func _initialize() -> void: call_deferred("run")

func step(count: int = 1) -> void:
	for i in range(count): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func screen(right: float, down: float) -> Vector3:
	var r := game.camera.global_basis.x
	r.y = 0.0
	var d := game.camera.global_basis.z
	d.y = 0.0
	return r.normalized() * right + d.normalized() * down

func add_line(item: Item, stat: ItemModifier.Stat, amount: float) -> void:
	var mod := ItemModifier.stat_mod(stat, amount)
	mod.tier = GearCatalog.IMPLICIT_TIER
	item.modifiers.append(mod)

func dress(depth: int, rarity: int) -> void:
	var p := game.player
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + depth
	for slot in p.equipped.keys(): p.unequip(slot)
	var factor: float = RARITY_FACTOR[rarity]
	for slot in Item.SLOTS:
		var item: Item = null
		if slot == Item.Category.WEAPON:
			# A 龙门 weapon she can wield: a deep one (25% 转化 to 灼燃) from floor 31.
			for id in GearCatalog.BASES:
				var b: Dictionary = GearCatalog.BASES[id]
				if str(b.region) != "city" or int(b.category) != Item.Category.WEAPON: continue
				if (int(b.tier) >= 2) != (depth >= 31): continue
				var candidate := LootTables.roll_equipment(slot, str(b.name), "city", depth, rarity, rng)
				if GearCatalog.can_wield(p.operator_id, candidate):
					item = candidate
					break
			if item != null and depth < 31: add_line(item, ItemModifier.Stat.ADD_BURN, 0.06 * factor)
		else:
			var id := GearCatalog.pick(slot, REGION, depth, "normal", "", rng)
			item = LootTables.roll_equipment(slot, str(GearCatalog.BASES[id].name), REGION, depth, rarity, rng)
			if slot in [Item.Category.RING, Item.Category.AMULET]: add_line(item, ItemModifier.Stat.ADD_CORR, 0.025 * factor)
		if item != null: p.equip(item)
	print("GEAR depth=%d rarity=%d atk=%.0f hp=%.0f add_burn=%.3f conv_burn=%.2f add_corr=%.3f weapon=%s" % [depth, rarity, p.attack_power(), p.max_hp,
		float(p.stats.get("add_burn", 0.0)), float(p.stats.get("conv_burn", 0.0)), float(p.stats.get("add_corr", 0.0)), p.equipped.get(Item.Category.WEAPON).item_name if p.equipped.has(Item.Category.WEAPON) else "-"])

func run() -> void:
	var depth := int(OS.get_environment("ELEM_REC")) if not OS.get_environment("ELEM_REC").is_empty() else 1
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["auto_potion"] = false
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 2026
	await game.start_contract(REGION)
	if depth > 1:
		game.floor_number = depth
		# advance() lands one floor past it (31 → 32: 30 is a camp); her contract
		# begins there, as from the camp below (合同深入系数 n = 1).
		game.start_floor = depth + 1
		await game.advance(0)
	await step(20)
	var p := game.player
	p.invulnerable = true
	game._clear_field()
	dress(depth, int(RARITY.get(depth, Item.BLUE)))
	await step(5)
	game.camera.size = 12
	var foes: Array[Enemy] = []
	for spot in [[-3.0, -3.0, false], [0.0, -4.0, false], [3.0, -3.0, false], [0.0, -6.5, true]]:
		var at := game.world_map.nearest_walkable(p.global_position + screen(spot[0], spot[1]))
		foes.append(game._spawn_enemy(at, spot[2], false))
	print("FLOOR %d growth=%.2f contract=%.3f T=%.0f thug-ish hp=%.0f elite hp=%.0f" % [game.floor_number, Scaling.floor_growth(game.floor_number), game.contract_life(), foes[0].gauge_threshold(), foes[0].max_health, foes[3].max_health])
	var was := {}
	var elapsed := 0.0
	while elapsed < FIGHT_SECONDS:
		await process_frame
		elapsed += 1.0 / 30.0
		var alive := foes.filter(func(e): return is_instance_valid(e) and not e._dead)
		if alive.is_empty(): break
		if not is_instance_valid(p.attack_target) or p.attack_target._dead:
			alive.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
			p.lock_target(alive[0])
		for e in alive:
			var cooling: bool = e.elements.cooling()
			if cooling and not was.get(e, false):
				print("MARK %d burst on %s: %s" % [Engine.get_frames_drawn(), e.enemy_type, e.elements.last_shares])
			was[e] = cooling
	print("END %d after %.1f s, alive %d" % [Engine.get_frames_drawn(), elapsed, foes.filter(func(e): return is_instance_valid(e) and not e._dead).size()])
	await step(20)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
