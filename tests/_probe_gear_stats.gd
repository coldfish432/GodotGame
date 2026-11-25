extends SceneTree
## Not a test — gear numbers probe: a full body per rarity rolled many times at
## floor 1 / 45 / 90; her stat sheet's spread (median / p95 / max) for the
## stats that multiply damage or toughness.

const KEYS := ["atk", "atk_pct", "arts_pct", "crit", "crit_dmg", "aspd", "dmg_pct", "phys_dmg_pct", "def_ignore", "hp", "hp_pct", "def", "res", "evasion", "dmg_reduce", "lifesteal"]
const BODIES := 300
var rig: Node

func _initialize() -> void: call_deferred("run")

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	for i in range(10): await process_frame
	var game := find_game(rig)
	await game.start_contract("mine")
	var p := game.player
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for depth in [1, 45, 90]:
		for rarity in [Item.GREY, Item.GREEN, Item.BLUE, Item.PURPLE, Item.ORANGE, Item.RED]:
			var acc := {}
			var atks: Array = []
			var hps: Array = []
			var dps: Array = []
			for b in range(BODIES):
				for slot in p.equipped.keys(): p.unequip(slot)
				for slot in Item.SLOTS:
					var item: Item = null
					for tries in range(20):
						var id := GearCatalog.pick(slot, "mine", depth, "normal", "", rng)
						if id.is_empty(): continue
						item = LootTables.roll_equipment(slot, str(GearCatalog.BASES[id].name), "mine", depth, rarity, rng)
						if slot != Item.Category.WEAPON or GearCatalog.can_wield(p.operator_id, item): break
						item = null
					if item != null: p.equip(item)
				for k in KEYS:
					if not acc.has(k): acc[k] = []
					acc[k].append(float(p.stats.get(k, 0.0)))
				atks.append(p.attack_power())
				hps.append(p.max_hp)
				var c := minf(1.0, p.crit_rate())
				dps.append(p.attack_power() * (1.0 + c * (p.crit_damage() - 1.0)) * (1.0 + float(p.stats.get("aspd", 0.0)) / 100.0) * (1.0 + float(p.stats.get("dmg_pct", 0.0)) + float(p.stats.get("phys_dmg_pct", 0.0))))
			var line := "GEAR d=%d r=%d atk %s hp %s dps %s |" % [depth, rarity, spread(atks), spread(hps), spread(dps)]
			for k in KEYS:
				var v: Array = acc[k]
				v.sort()
				if v.back() > 0.0: line += " %s=%.3g/%.3g" % [k, v[v.size() / 2], v.back()]
			print(line)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()

func spread(values: Array) -> String:
	values.sort()
	return "%.0f/%.0f/%.0f" % [values[values.size() / 2], values[int(values.size() * 0.95)], values.back()]
