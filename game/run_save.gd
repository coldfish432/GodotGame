class_name RunSave
extends RefCounted

## 局内存档 (用户 2026-10-24: 局内保存并退出，读档仍在局内，本层原地继续).
## A floor is not written out piece by piece: it is built again from what it
## was built from (the run as it stood on entering it, GameManager's RNG
## streams at that moment (rng_states) and the base fields its rolls read), then what changed since is
## laid over it — the run's numbers, her, the fog, what was killed or taken
## (by the order the floor's pieces were made in, `floor_id`), the boxes'
## contents, the ground loot, the caches, chests and enemies that came later.
## Enemies of the floor still standing are back where they started, whole; a
## boss fight starts over.

const VERSION := 1

## GameManager's run fields, written with var_to_str (typed arrays, vectors).
const GAME_KEYS := ["region_id", "floor_number", "start_floor", "market_field", "route_map", "route_node", "route_kind", "route_trail", "route_peek", "route_exit_map", "route_threat_cut", "floor_kits", "post_gifted", "next_floor_mods", "floor_mods", "event_done", "campfire_used", "witness_marked", "_floor_relics", "route_history", "contract", "contract_vaults",
	"bounty_killed", "recruit_met", "lost_floor", "cargo_delivered", "_contract_announced", "builds", "relic_floors", "run_kills", "run_sets_seen", "reroll_count",
	"pressure", "run_meal", "squad_uses", "guide_floor", "_run_seed", "in_camp", "in_event",
	"_random_extraction_available", "encounter", "encounter_used", "squad_mult", "post_faction", "trader_rerolls", "_trader_met",
	"_encounter_greeted", "camp_closure_stock", "first_run_ore", "_buff_taken", "vault_opened", "outpost_cleared", "_device_offers",
	"drop_share", "_extra_ordinary", "_herd_count", "_tracked_warned", "_patrol_warned", "_next_patrol_entry", "prts_log",
	"_seen_encounter", "_seen_exit", "_slow_heal_left", "_slow_heal_rate", "_suppress_timer", "_potion_heal_factor", "_announced_tier"]
const THREAT_KEYS := ["value", "fill_seconds", "wave"]
const FEATURE_KEYS := ["values", "announced", "kits", "reckon_wait", "reckonings", "camp_cleansed", "camp_debt_paid", "depth_step"]
const POTION_KEYS := ["cold_half", "debt_block", "quiet", "shield_left", "shield_amount", "regen_share", "regen_left", "regen_lock", "emergency_used", "_pending", "contam_block", "contam_after"]
## Her numbers that last a floor or the contract (cooldowns start over).
const PLAYER_KEYS := ["stamina", "shield", "cold", "hexes", "_buff_max_hp_bonus", "_buff_damage_bonus", "wave_count", "death_cling_used",
	"elite_kills", "altar_stacks", "_low_hp_ward_used_this_floor", "death_full_block", "hurt_stacks", "blocks_left", "segment_time",
	"wolf_waves", "shadow_kill_stacks"]
## The base fields a floor's rolls read and its building changes.
const BASE_KEYS := ["first_extract_given", "recruit_clues", "recruit_found", "roster"]

static func pack(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = var_to_str(object.get(key))
	return out

static func unpack(object: Object, data: Dictionary, keys: Array) -> void:
	for key in keys:
		if data.has(key): object.set(key, str_to_var(str(data[key])))

# --- The run -------------------------------------------------------------------------------

static func run_data(game: GameManager) -> Dictionary:
	var stock: Array = []
	for slot in game.trader_stock:
		var entry: Dictionary = slot.duplicate()
		if entry.get("item") is Item: entry["item"] = (entry.item as Item).to_data()
		stock.append(var_to_str(entry))
	var sold := {}
	for shop in game.buyback:
		sold[shop] = []
		for slot in game.buyback[shop]:
			var entry: Dictionary = slot.duplicate()
			entry["item"] = (entry.item as Item).to_data()
			sold[shop].append(var_to_str(entry))
	return {"game": pack(game, GAME_KEYS), "threat": pack(game.threat, THREAT_KEYS), "features": pack(game.features, FEATURE_KEYS),
		"potions": pack(game.potion_fx, POTION_KEYS), "trader": stock, "buyback": sold}

static func apply_run(game: GameManager, data: Dictionary) -> void:
	unpack(game, data.get("game", {}), GAME_KEYS)
	unpack(game.threat, data.get("threat", {}), THREAT_KEYS)
	unpack(game.features, data.get("features", {}), FEATURE_KEYS)
	unpack(game.potion_fx, data.get("potions", {}), POTION_KEYS)
	game.trader_stock.clear()
	for text in data.get("trader", []):
		var entry: Dictionary = str_to_var(str(text))
		if entry.get("item") is Dictionary: entry["item"] = Item.from_data(entry.item)
		game.trader_stock.append(entry)
	game.buyback.clear()
	for shop in data.get("buyback", {}):
		game.buyback[shop] = []
		for text in data.buyback[shop]:
			var entry: Dictionary = str_to_var(str(text))
			entry["item"] = Item.from_data(entry.item)
			game.buyback[shop].append(entry)
	game.player._recompute_stats()

static func base_inputs(base: BaseState) -> Dictionary:
	return pack(base, BASE_KEYS)

static func set_base_inputs(base: BaseState, data: Dictionary) -> void:
	unpack(base, data, BASE_KEYS)

static func player_data(player: Player) -> Dictionary:
	var out := pack(player, PLAYER_KEYS)
	out["hp"] = player.hp
	out["at"] = var_to_str(player.global_position)
	return out

static func apply_player(game: GameManager, data: Dictionary) -> void:
	var player := game.player
	unpack(player, data, PLAYER_KEYS)
	player._recompute_stats()
	player.set_condition(game.base.injured, game.current_contamination())
	player.hp = float(data.get("hp", player.max_hp))
	if data.has("at"): player.teleport(str_to_var(str(data.at)))

# --- The floor -----------------------------------------------------------------------------

## The pieces a floor is built with, numbered in the order they were made.
static func tracked(node: Node) -> bool:
	return node is Enemy or node is GuardPost or node is LootContainer or node is RelicCache or node is FieldTrap or node is TracePoint or node is FirePit or node is ShowerPoint

static func floor_pieces(game: GameManager) -> Array[Node]:
	var out: Array[Node] = []
	var nodes: Array[Node] = game.get_children()
	if is_instance_valid(game.world_map._generated_root): nodes.append_array(game.world_map._generated_root.get_children())
	for node in nodes:
		if tracked(node) and not node.is_queued_for_deletion(): out.append(node)
	return out

## Numbers the floor's pieces just after it is built; returns what was made,
## to tell a rebuilt floor from a different one.
static func tag_floor(game: GameManager) -> Array:
	var made := []
	var pieces := floor_pieces(game)
	for i in range(pieces.size()):
		pieces[i].set_meta("floor_id", i)
		made.append(signature(pieces[i]))
	return made

static func signature(node: Node3D) -> String:
	var at := node.global_position
	return "%s@%d,%d" % [node.get_class() if node.get_script() == null else node.get_script().get_global_name(), roundi(at.x * 10.0), roundi(at.z * 10.0)]

static func floor_data(game: GameManager) -> Dictionary:
	var present := {}
	var boxes := {}
	var traps := {}
	var fires := {}
	var caches := {}
	var showers := {}
	var new_boxes: Array = []
	var new_caches: Array = []
	var enemies: Array = []
	for node in floor_pieces(game):
		var id := int(node.get_meta("floor_id", -1))
		if node is Enemy and (node as Enemy)._dead: continue
		if id >= 0: present[id] = true
		if node is LootContainer:
			var box := node as LootContainer
			if id >= 0: boxes[id] = box_data(box)
			else: new_boxes.append({"at": var_to_str(box.global_position), "kind": box.kind, "vault": box.vault, "box": box_data(box)})
		elif node is RelicCache:
			var cache := node as RelicCache
			var data := {"sealed": cache.sealed, "offers": var_to_str(cache.offers)}
			if id >= 0: caches[id] = data
			else:
				data.merge({"at": var_to_str(cache.global_position), "source": cache.source})
				new_caches.append(data)
		elif node is FieldTrap and id >= 0: traps[id] = (node as FieldTrap).spent
		elif node is FirePit and id >= 0: fires[id] = (node as FirePit).burn_left
		elif node is ShowerPoint and id >= 0: showers[id] = (node as ShowerPoint).used
		elif node is Enemy and id < 0 and not node is Boss and not node is Civilian and (node as Enemy).mimic_kind.is_empty():
			var enemy := node as Enemy
			enemies.append({"at": var_to_str(enemy.global_position), "type": enemy.enemy_type, "elite": enemy.elite, "ranged": enemy.ranged,
				"max": enemy.max_health, "hp": enemy.health, "atk": enemy.atk, "def": enemy.defense, "patrol": enemy.patrol_wave,
				"called": enemy.called_in, "guardian": game._vault_guardians.has(enemy), "reckoning": enemy.is_in_group("reckoning")})
	var loot: Array = []
	for node in game.get_children():
		var drop := node as Loot
		if drop == null or drop.item == null or drop.is_queued_for_deletion(): continue
		loot.append({"at": var_to_str(drop._rest if drop._fly > 0.0 else drop.global_position), "item": drop.item.to_data(), "sealed": drop.sealed})
	return {"made": game._floor_made, "present": present.keys(), "boxes": boxes, "traps": traps, "fires": fires, "showers": showers,
		"caches": caches, "new_boxes": new_boxes, "new_caches": new_caches, "enemies": enemies, "loot": loot,
		"fog": Marshalls.raw_to_base64(game.fog._revealed), "fog_count": game.fog._revealed_count}

static func box_data(box: LootContainer) -> Dictionary:
	return {"opened": box.opened, "sealed": box.sealed, "found": box._found,
		"pending": box._pending.map(func(item: Item): return item.to_data()),
		"storage": box.storage.items.map(func(item: Item): return item.to_data())}

static func apply_box(box: LootContainer, data: Dictionary) -> void:
	box.opened = bool(data.get("opened", false))
	box.sealed = bool(data.get("sealed", false))
	box._found = int(data.get("found", 0))
	box._pending.clear()
	for entry in data.get("pending", []): box._pending.append(Item.from_data(entry))
	box.storage.items.clear()
	for entry in data.get("storage", []):
		var item := Item.from_data(entry)
		if not box.storage.place(item, item.grid_x, item.grid_y): box.storage.try_add(item)
	box._search = -1.0
	box._refresh()

## Lays `data` over the floor just rebuilt. False (and the floor as built)
## when the rebuilt floor is not the one that was saved.
static func apply_floor(game: GameManager, data: Dictionary) -> bool:
	var fog: PackedByteArray = Marshalls.base64_to_raw(str(data.get("fog", "")))
	if fog.size() == game.fog._revealed.size():
		game.fog._revealed = fog
		game.fog._revealed_count = int(data.get("fog_count", 0))
	if data.get("made", []) != game._floor_made: return false
	var present := {}
	for id in data.get("present", []): present[int(id)] = true
	var boxes: Dictionary = data.get("boxes", {})
	var traps: Dictionary = data.get("traps", {})
	var fires: Dictionary = data.get("fires", {})
	var showers: Dictionary = data.get("showers", {})
	var caches: Dictionary = data.get("caches", {})
	for node in floor_pieces(game):
		var id := int(node.get_meta("floor_id", -1))
		var key := str(id)
		if not present.has(id):
			_take_away(game, node)
			continue
		if node is LootContainer and boxes.has(key): apply_box(node, boxes[key])
		elif node is FieldTrap and bool(traps.get(key, false)): (node as FieldTrap).mark_spent()
		elif node is FirePit and fires.has(key):
			(node as FirePit).burn_left = float(fires[key])
			(node as FirePit)._set_lit(float(fires[key]) > 0.0)
		elif node is ShowerPoint and bool(showers.get(key, false)): (node as ShowerPoint).use()
		elif node is RelicCache and caches.has(key):
			(node as RelicCache).sealed = bool(caches[key].sealed)
			(node as RelicCache).offers.assign(str_to_var(str(caches[key].offers)))
	# What came after the floor was built.
	if game.vault_opened and game.world_map.vault_seal != null: game.world_map.vault_seal.open()
	if game.outpost_cleared and is_instance_valid(game.arena): game.arena.open_exit()
	for entry in data.get("new_boxes", []):
		var box := LootContainer.new()
		box.game = game
		box.kind = str(entry.kind)
		box.vault = bool(entry.vault)
		game.add_child(box)
		box.global_position = str_to_var(str(entry.at))
		apply_box(box, entry.box)
		if box.sealed: box.add_to_group("sealed_loot")
	for entry in data.get("new_caches", []):
		var cache := game._spawn_relic_cache(str_to_var(str(entry.at)), str(entry.source), bool(entry.sealed))
		cache.offers.assign(str_to_var(str(entry.offers)))
	for entry in data.get("enemies", []):
		var enemy := game._spawn_enemy(str_to_var(str(entry.at)), bool(entry.elite), bool(entry.ranged), str(entry.type))
		if int(entry.patrol) > 0: enemy.configure_patrol(int(entry.patrol))
		enemy.called_in = bool(entry.called)
		enemy.max_health = float(entry.max)
		enemy.health = float(entry.hp)
		enemy.atk = float(entry.atk)
		enemy.defense = float(entry.def)
		if bool(entry.reckoning): enemy.add_to_group("reckoning")
		if bool(entry.guardian): game._vault_guardians.append(enemy)
	for entry in data.get("loot", []):
		var drop := Loot.new()
		drop.game = game
		drop.item = Item.from_data(entry.item)
		drop.sealed = bool(entry.get("sealed", false))
		game.add_child(drop)
		drop.global_position = str_to_var(str(entry.at))
		# Insured gear she dropped is this very item now, so taking it back counts.
		for i in range(game._insured_left_behind.size()):
			if game._insured_left_behind[i].uid == drop.item.uid: game._insured_left_behind[i] = drop.item
	return true

## A piece killed or taken before the save: gone, with nothing paid for it again.
static func _take_away(game: GameManager, node: Node) -> void:
	if node == game._car and is_instance_valid(game._car_block): game._car_block.queue_free()
	if node is Enemy:
		game._outpost_squad.erase(node)
		game._vault_guardians.erase(node)
		if node == game._bounty: game._bounty = null
		if node == game.outpost_boss: game.outpost_boss = null
	if node == game.trace_point: game.trace_point = null
	if node is FieldTrap: game.traps.erase(node)
	if node is FirePit: game.fires.erase(node)
	if node == game.shower: game.shower = null
	node.get_parent().remove_child(node)
	node.queue_free()
