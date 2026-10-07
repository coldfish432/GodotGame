class_name GameManager
extends Node3D

## Authoritative contract state, containers, build choices, settlement and base saves.

const CAMERA_OFFSET := Vector3(0.0, 16.0, -10.0)
const CAMERA_FOLLOW_SPEED := 10.0
const ENEMY_PICK_MASK := 4  # matches Enemy.PICK_LAYER

@export var fixed_map_seed: int = 0

var floor_number: int = 1
## Flasks are pack items that take a cell (药剂进背包, 用户 2026-10-05): this is
## how many she carries, pack and safe bag. Setting it replaces them with that
## many 标准急救剂 in the pack (tests and debug use).
var potions: int:
	get: return carried_potions().size()
	set(value): _set_standard_potions(value)
## Q drinks the first of these she carries (标准急救剂 first).
const POTION_ORDER := ["A", "B", "C"]
## Contamination taken on this contract so far (§4.1); added to the base's at settlement.
var run_contamination := 0.0
var _slow_heal_left := 0.0       # 缓释凝胶: health still to come
var _slow_heal_rate := 0.0
var _suppress_timer := 0.0       # 抑制喷剂: contamination accrues at half rate meanwhile
var _potion_heal_factor := 1.0   # contamination tier at departure
var _announced_tier := 0
## 龙门币, the account balance (经济修订案: the only out-of-run money).
var gold: int = Economy.STARTING_LMD
var message: String = ""
var message_timer: float = 5.0

var inventory := ItemContainer.new(10, 6)
var safe_bag := ItemContainer.new(2, 2)
## Everything stored at the base: receiving crates, staging, the shelves.
var base := BaseState.new()
## The warehouse proper: personal storage on the shelves.
var stash: Array[Item]:
	get: return base.shelf

var player: Player
var world_map: ContinuousWorldMap
var base_map: BaseMap
var warehouse_view: WarehouseView
var medical_view: MedicalView
var markers: BaseMarkers
var _status_bar: Label
## Where Lappland appears on returning: the hall after extraction, the medical
## recovery bed after the recovery team brings her back.
var base_spawn := "arrival"
var _base_prompt: Label
var camera: Camera3D

# When set (by the pixel-art display rig — see game/pixel_display.gd), the
# HUD/inventory panel attach here instead of under `self`, so they render
# at full resolution outside the low-res, pixelated 3D SubViewport GameManager
# itself lives in. Standalone use (tests, or any scene that just does
# GameManager.new() directly) leaves this null and gets the UI as a normal
# child, same as before this existed.
var ui_root: Node = null

var _hud: Hud
var field_panels: FieldPanels
## The bag as it came out of the last contract, for the settlement screen.
var settlement_view: Dictionary = {}
var show_settlement_screen := true
var system_screens: SystemScreens
## The floors of this contract, for the route map: [{floor, name}].
var route_history: Array = []
## Full-resolution overlay for combat numbers (DamageNumber).
var number_layer: Control
var _inventory_panel: InventoryPanel
var fog := FieldFog.new()
var vault_opened: bool = false
var _mechanisms_done: Dictionary = {}
var _vault_guardians: Array[Enemy] = []
var _buff_taken: bool = false
## Who stands at this floor's encounter spot: "" / "squad" / "trader", and
## whether the squad's one service has been used (保全系统修订案 §2).
var encounter := ""
var encounter_used := false
## This squad's price multiplier, one of FieldCatalog.SQUAD_PRICE_STEPS.
var squad_mult := 1.0
var _random_extraction_available: bool = false
var _run_seed: int = 0
@export var start_at_base := true
@export var save_enabled := true
var save_path := "user://field_contract_v1.json"
var menu: FieldMenu
var region_id := "mine"
var in_base := true
var transitioning := false
var modal := ""
var pressure := 0.0
var route_index := 0
## 赤金 carried in the pack and safe bag: the in-run money (经济修订案 §1).
## Setting it replaces the bars she carries (tests and debug use).
var run_gold: int:
	get: return gold_bars()
	set(value): _set_gold_bars(value)
## The floor this contract started on (1, or a camp later), for the contract reward.
var start_floor := 1
## In a camp between two floors (撤离与营地修订案): no fight, 可露希尔, extraction.
var in_camp := false
## The route chosen at the end of the floor before a camp, taken on leaving it.
var _camp_route := 0
## This block of ten already had its random extraction.
var _block_random_found := false
## The start point picked at the dispatch desk (0 = floor 1, else a camp).
var _pending_start_camp := 0
var builds: Array[String] = []
## The offer currently on screen. The device's offer is kept in _device_offers
## and each relic cache keeps its own, so reopening never rerolls.
var build_offers: Array[Dictionary] = []
var offer_source := "device"
var _device_offers: Array[Dictionary] = []
var _active_cache: RelicCache
var reroll_count := 0
## Threat defeated this segment and whether its combat cache has appeared (§8.2).
var segment_threat := 0
var _cache_spawned := false
## Ground pickup filter (装备与背包界面调研 §5.10, Grim Dawn style): 0 picks up
## everything, 1 equipment of 精良 and up, 2 only 稀有. Materials, exclusives
## and money are always picked up. Filtered drops stay; E picks one up.
var pickup_filter := 0
const PICKUP_FILTER_NAMES := ["全部", "精良以上", "仅稀有"]
var settlement: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _settled := true
var sound: FieldAudio
var music: GameMusic
var _pointer_gate := false
var _pointer_position := Vector2.ZERO
var _has_pointer_position := false
var _sword_shake_frames := 0
## The camera's smooth follow position. What is rendered is this snapped to
## whole screen pixels (see _snap_to_pixels).
var _camera_follow := Vector3.ZERO
var _camera_snapped := Vector3.INF

func _ready() -> void:
	_setup_input()
	rng.randomize()
	sound = FieldAudio.new()
	add_child(sound)
	music = GameMusic.new()
	music.game = self
	add_child(music)
	_configure_camera_and_light()
	world_map = ContinuousWorldMap.new()
	add_child(world_map)
	base_map = BaseMap.new()
	add_child(base_map)
	# The warehouse's four reveal moments, one sound each (CHANGE-BRIEF: event sounds).
	if base_map.warehouse_reveal:
		var reveal := base_map.warehouse_reveal
		reveal.bank_lit.connect(func(_bank: int): sound.play("lights_on"))
		reveal.hatch_opening.connect(func(_shelf: int): sound.play("hatch"))
		reveal.shelf_rising.connect(func(_shelf: int): sound.play("shelf"))
		reveal.lights_out.connect(func(): sound.play("lights_off"))
	_build_player()
	base_map.player = player
	warehouse_view = WarehouseView.new()
	base_map.add_child(warehouse_view)
	warehouse_view.setup(self, base_map)
	medical_view = MedicalView.new()
	base_map.add_child(medical_view)
	medical_view.setup(self, base_map)
	markers = BaseMarkers.new()
	base_map.add_child(markers)
	markers.setup(self, base_map)
	_build_hud()
	_build_inventory_panel()
	var layer := CanvasLayer.new()
	layer.layer = 5
	(ui_root if is_instance_valid(ui_root) else self).add_child(layer)
	menu = FieldMenu.new()
	menu.game = self
	layer.add_child(menu)
	_build_base_prompt(layer)
	if save_enabled:
		load_base()
	if start_at_base:
		show_base()
	else:
		await start_contract(region_id)

func _setup_input() -> void:
	var bindings := {"dash": KEY_SHIFT, "use_potion": KEY_Q,
		"interact": KEY_E, "stash_item": KEY_B, "toggle_inventory": KEY_I,
		"toggle_operator": KEY_C, "toggle_relics": KEY_R, "toggle_map": KEY_M, "toggle_journal": KEY_J, "toggle_pause": KEY_ESCAPE}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)
	# Walking by keys (用户 2026-10-06): WASD and the arrows, beside click-to-move.
	var walk := {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT]}
	for action in walk:
		if InputMap.has_action(action): continue
		InputMap.add_action(action, 0.2)
		for key in walk[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func simulation_active() -> bool:
	return not in_base and not transitioning and modal.is_empty()

## Walking around Rhodes Island between contracts: movement only, no combat.
func base_walk_active() -> bool:
	return in_base and not transitioning and modal.is_empty()

func _input(event: InputEvent) -> void:
	# SubViewportContainer forwards positions in this viewport's coordinates.
	# Preserve event coordinates for picking, including injected/replayed input.
	if event is InputEventMouse:
		_pointer_position = event.position
		_has_pointer_position = true

func _process(delta: float) -> void:
	message_timer -= delta
	if not is_instance_valid(player):
		return
	if Input.is_action_just_pressed("toggle_inventory") or Input.is_action_just_pressed("toggle_operator"): toggle_panel("inventory")
	for entry in [["toggle_relics", "relics"], ["toggle_map", "map"], ["toggle_journal", "journal"]]:
		if Input.is_action_just_pressed(entry[0]): toggle_panel(entry[1])
	if Input.is_action_just_pressed("toggle_pause"): go_back()
	if simulation_active():
		var enemy := _get_enemy_under_pointer()
		_handle_pointer_input(enemy)
		if Input.is_action_just_pressed("use_potion"): _use_potion()
		if Input.is_action_just_pressed("interact"): _interact()
		if Input.is_action_just_pressed("stash_item"): _move_last_item_to_safe_bag()
	elif base_walk_active():
		_handle_base_pointer()
		if Input.is_action_just_pressed("interact"): _base_interact()
	_update_base_prompt()
	if is_instance_valid(camera):
		# Anything that placed the camera directly (spawns, captures) restarts the follow from there.
		if not camera.global_position.is_equal_approx(_camera_snapped): _camera_follow = camera.global_position
		_camera_follow = _camera_follow.lerp(camera_target() + CAMERA_OFFSET, minf(1, CAMERA_FOLLOW_SPEED * delta))
		_camera_snapped = _snap_to_pixels(_camera_follow)
		camera.global_position = _camera_snapped

		camera.h_offset = 0.0
		if _sword_shake_frames > 0 and simulation_active():
			camera.h_offset = (1.0 if _sword_shake_frames == 2 else -1.0) * camera.size / get_viewport().get_visible_rect().size.y
			_sword_shake_frames -= 1

## The world renders at a low resolution and is scaled up with nearest-neighbour
## filtering, and every floor, prop and sprite rounds to that pixel grid on its
## own. With the camera at a fractional pixel offset, each of them crosses to
## the next pixel at a different moment as the camera moves, so props nudge a
## pixel against the floor and each other: the scene wobbles while it scrolls.
## Moving the camera only in whole screen pixels (across and up the screen;
## depth does not matter for an orthographic view) keeps every object's
## rounding fixed, so the scene moves as one piece.
func _snap_to_pixels(position: Vector3) -> Vector3:
	var viewport_height := get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0: return position
	var pixel := camera.size / viewport_height
	var basis := camera.global_basis
	var across := roundf(position.dot(basis.x) / pixel) * pixel
	var up := roundf(position.dot(basis.y) / pixel) * pixel
	return basis.x * across + basis.y * up + basis.z * position.dot(basis.z)

## Where the camera looks: the player, kept inside the base's walls while at home.
func camera_target() -> Vector3:
	if in_base and is_instance_valid(base_map) and base_map.visible:
		return base_map.clamp_camera(player.global_position)
	return player.global_position

func start_sword_shake() -> void:
	_sword_shake_frames = 2

func _physics_process(delta: float) -> void:
	if simulation_active() and is_instance_valid(player):
		fog.reveal(player.global_position)
		_announce_discoveries()
		_tick_medical(delta)
		player.hp -= count_effect("raw_ore") * FieldCatalog.RAW_ORE_DRAIN * delta
		if player.hp <= 0: _on_player_died()

func show_base() -> void:
	in_base = true
	modal = ""
	_pointer_gate = true
	player.clear_move_target()
	_inventory_panel.hide()
	menu.hide()
	base_map.set_active(true)
	player.teleport(base_map.spawn_point(base_spawn))
	camera.global_position = camera_target() + CAMERA_OFFSET

## What Lappland is standing at, if anything: a warehouse spot (crate, zone,
## staging) or one of the base stations.
func nearby_station() -> Dictionary:
	if not in_base or not is_instance_valid(base_map): return {}
	var spot := warehouse_view.target_at(player.global_position) if is_instance_valid(warehouse_view) else {}
	if not spot.is_empty(): return spot
	return base_map.station_near(player.global_position)

func _base_interact() -> void:
	var station := nearby_station()
	if station.is_empty():
		if base.hand: set_message("手上拿着 %s：走到%s区的地面框里按 E 上架，或放进暂存区。" % [base.hand.item_name, BaseCatalog.CATEGORY_NAMES[base.hand.category]])
		else: set_message("走到发光的站点旁按 E：调度台接单、后勤柜台投保、仓管台、收货区货箱、整备台、医疗前台。")
		return
	match station.kind:
		"crate": inspect_crate(station.item)
		"zone": shelve_carried(station.category)
		"putback": put_back_carried()
		"staging":
			if base.hand: stage_carried()
			else:
				open_modal("station")
				menu.show_staging()
		_: open_station(station.kind)

func open_station(kind: String) -> void:
	if not in_base or transitioning: return
	if kind == "report" and base.report_unread:
		base.report_unread = false
		save_base()
	if kind == "stash" and base.unseen_unlocks:
		base.unseen_unlocks = false
		save_base()
	open_modal("station")
	menu.show_station(kind)

func _handle_base_pointer() -> void:
	if _pointer_gate:
		_pointer_gate = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		player.set_move_target(_get_pointer_ground())

func _build_base_prompt(layer: CanvasLayer) -> void:
	_base_prompt = Label.new()
	_base_prompt.add_theme_font_override("font", AK.cn())
	_base_prompt.add_theme_font_size_override("font_size", 16)
	_base_prompt.add_theme_color_override("font_color", AK.FG)
	_base_prompt.add_theme_color_override("font_outline_color", Color("0b0c0d"))
	_base_prompt.add_theme_constant_override("outline_size", 6)
	_base_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_base_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_base_prompt.offset_left = -400
	_base_prompt.offset_right = 400
	_base_prompt.offset_top = 560
	_base_prompt.offset_bottom = 610
	_base_prompt.visible = false
	layer.add_child(_base_prompt)
	# The base top bar (界面策划案 #12): a dark plate, white data, AK fonts.
	_status_bar = Label.new()
	_status_bar.add_theme_font_override("font", AK.cn())
	_status_bar.add_theme_font_size_override("font_size", 15)
	_status_bar.add_theme_color_override("font_color", AK.FG)
	var plate := AK.box(Color(0, 0, 0, 0.6), Color.TRANSPARENT, 0, 8)
	plate.content_margin_left = 14
	plate.content_margin_right = 14
	_status_bar.add_theme_stylebox_override("normal", plate)
	_status_bar.position = Vector2(700, 12)
	_status_bar.visible = false
	layer.add_child(_status_bar)

func _update_base_prompt() -> void:
	if not is_instance_valid(_base_prompt): return
	_base_prompt.visible = base_walk_active()
	if is_instance_valid(_status_bar):
		_status_bar.visible = _base_prompt.visible
		_status_bar.text = base_status_text()
		_status_bar.reset_size()
		_status_bar.position = Vector2(1268 - _status_bar.size.x, 12)
	if not _base_prompt.visible: return
	var station := nearby_station()
	var lines: Array[String] = []
	if not station.is_empty(): lines.append("E  " + station.label)
	if message_timer > 0 and not message.is_empty(): lines.append(message)
	_base_prompt.text = "
".join(lines)

func start_contract(region: String, start_camp: int = 0) -> void:
	if transitioning or not in_base or not FieldCatalog.REGIONS.has(region): return
	region_id = region
	in_base = false
	_settled = false
	transitioning = true
	close_modal()
	base_map.set_active(false)
	settlement.clear()
	builds.clear()
	build_offers.clear()
	reroll_count = 0
	player._recompute_stats()
	floor_number = 1
	pressure = 0
	route_index = 0
	in_camp = false
	_block_random_found = false
	# From an unlocked camp the contract begins in that camp (§3); the reward
	# counts the floors walked from the one after it.
	var from_camp := start_camp > 0 and base.camp_unlocked(region, start_camp)
	if from_camp: floor_number = start_camp
	start_floor = floor_number + (1 if from_camp else 0)
	_run_seed = fixed_map_seed if fixed_map_seed else rng.randi()
	_apply_medical_state()
	# Whatever she is carrying around the warehouse stays at the base.
	if base.return_hand(): set_message("手上的物品已放回原处。")
	_issue_free_potions()
	prts_log.clear()
	broadcast("合同开始：%s。" % FieldCatalog.REGIONS[region_id].name)
	route_history = [{"floor": start_floor, "name": "营地" if from_camp else "入口"}]
	for item in carried_items():
		item.carried_in = true
	player.hp = player.max_hp
	player.stamina = 100
	save_base(true)
	if from_camp:
		transitioning = false
		_enter_camp()
		return
	_build_world()
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	camera.global_position = player.global_position + CAMERA_OFFSET
	await _await_navigation_sync()
	_spawn_wave()
	transitioning = false
	set_message("合同开始：%s。" % FieldCatalog.REGIONS[region_id].name)

func _clear_field() -> void:
	for child in get_children():
		if child is Enemy or child is GuardPost or child is Loot or child is LootContainer or child is RelicCache or child is SwordWave or child is CombatVfx or child is EnemyAttackVfx or child is EnemyProjectile or child is MeshInstance3D:
			remove_child(child)
			child.queue_free()
	_vault_guardians.clear()
	if is_instance_valid(number_layer):
		for label in number_layer.get_children(): label.queue_free()

func _build_world() -> void:
	_clear_field()
	_buff_taken = false
	vault_opened = false
	_mechanisms_done.clear()
	_vault_guardians.clear()
	fog.setup(ContinuousWorldMap.SPINE_MIN, ContinuousWorldMap.SPINE_MAX)
	_roll_encounter()
	world_map.encounter_kind = encounter
	build_offers.clear()
	_device_offers.clear()
	_active_cache = null
	segment_threat = 0
	_cache_spawned = false
	_roll_random_extraction()
	_seen_encounter = false
	_seen_exit = false
	pressure = difficulty()
	player.reset_floor_state()
	world_map.region_id = region_id
	world_map.extraction_available = is_extraction_floor()
	world_map.generate(_run_seed + floor_number * 7919, floor_number)

## The fixed extraction is in the camps now; a floor only ever has a random one.
func is_extraction_floor() -> bool:
	return _random_extraction_available

## At most one random extraction per block of ten, on floor 4, 5 or 6, each with
## exactly 1/6 (撤离与营地修订案 §2).
func _roll_random_extraction() -> void:
	var place := (floor_number - 1) % FieldCatalog.CAMP_INTERVAL + 1
	if place == 1: _block_random_found = false
	_random_extraction_available = false
	if _block_random_found or not FieldCatalog.RANDOM_EXTRACTION_ODDS.has(place): return
	if rng.randf() < float(FieldCatalog.RANDOM_EXTRACTION_ODDS[place]):
		_random_extraction_available = true
		_block_random_found = true

func is_buff_available() -> bool: return not _buff_taken
## Who stands at this floor's encounter spot (保全系统修订案 §2).
func _roll_encounter() -> void:
	var roll := rng.randf()
	encounter = "squad" if roll < FieldCatalog.SQUAD_CHANCE else ("trader" if roll < FieldCatalog.SQUAD_CHANCE + FieldCatalog.TRADER_CHANCE else "")
	encounter_used = false
	trader_stock.clear()
	trader_rerolls = 0
	_encounter_greeted = false
	squad_mult = FieldCatalog.SQUAD_PRICE_STEPS[rng.randi() % FieldCatalog.SQUAD_PRICE_STEPS.size()]

func is_encounter_available() -> bool: return not encounter.is_empty() and not encounter_used

func _interact() -> void:
	if not simulation_active(): return
	for node in get_tree().get_nodes_in_group("loot"):
		var loot := node as Loot
		# Only what the pickup filter left behind; everything else is picked
		# up by walking over it, so E stays free for caches and devices.
		if loot.game == self and loot.item != null and not loot.sealed and not loot.is_search_point and not passes_pickup_filter(loot.item) and player.global_position.distance_to(loot.global_position) < 2.0:
			if try_collect(loot.item): loot.queue_free()
			return
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box.game != self or box.opened or player.global_position.distance_to(box.global_position) > LootContainer.REACH: continue
		if box.sealed:
			set_message("%s仍被封印：先击败全部守卫者。" % box.title())
			return
		if box.begin_open():
			set_message("正在开启%s……（走开或受击会打断）" % box.title())
			return
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game != self or not near(cache): continue
		if cache.sealed:
			set_message("密室藏品仍被封印：先击败全部守卫者。")
		else:
			open_relic_offer(cache.source, cache)
		return
	if near(world_map.buff_device_node) and not _buff_taken:
		_offer_builds()
	elif near(world_map.encounter_node) and not encounter.is_empty() and (encounter == "trader" or not encounter_used):
		_open_encounter()
	elif near(world_map.exit_node) and is_extraction_floor():
		_extract()
	elif _trigger_nearby_mechanism():
		return
	else:
		for i in range(world_map.route_nodes.size()):
			if near(world_map.route_nodes[i]):
				open_modal("route")
				menu.show_routes(i)
				return
		pass

## The sealed-vault loop, adapted from 贪婪洞窟 2's 机关密室: every mechanism on
## the segment has to be triggered before the vault opens, which is what turns
## the detours from a string of independent "is there loot down there" gambles
## into one goal the player is partway through. See 贪婪洞窟地图设计调研.md §3.1.
func _trigger_nearby_mechanism() -> bool:
	for i in range(world_map.mechanism_nodes.size()):
		var node: Node3D = world_map.mechanism_nodes[i]
		if not near(node) or _mechanisms_done.has(i): continue
		_mechanisms_done[i] = true
		(node.material_override as StandardMaterial3D).albedo_color = Color("55627a")
		if _mechanisms_done.size() >= world_map.mechanism_nodes.size():
			_open_vault()
		else:
			set_message("机关 %d / %d" % [_mechanisms_done.size(), world_map.mechanism_nodes.size()])
			broadcast("机关 %d / %d。" % [_mechanisms_done.size(), world_map.mechanism_nodes.size()])
		return true
	return false

func _open_vault() -> void:
	if vault_opened or not is_instance_valid(world_map.vault_node): return
	vault_opened = true
	(world_map.vault_node.material_override as StandardMaterial3D).albedo_color = Color("ffe9a8")
	if region_id == "mine":
		for side in [-1, 1]:
			_vault_guardians.append(_spawn_enemy(world_map.vault_position + Vector3(side * 1.3, 0, 0), false, false, "thug"))
	else:
		_vault_guardians.append(_spawn_enemy(world_map.vault_position, true, false))
	_spawn_relic_cache(world_map.vault_position, "vault", true)
	var vault_kinds := ["vault_weapon", "vault_gear", "vault_base"]
	for i in range(3):
		var chest := LootContainer.new()
		chest.game = self
		chest.kind = vault_kinds[i]
		chest.vault = true
		chest.sealed = true
		add_child(chest)
		chest.global_position = world_map.vault_position + Vector3(cos(TAU * i / 3.0) * 2.6, 0.0, sin(TAU * i / 3.0) * 2.6)
		chest.add_to_group("sealed_loot")
	set_message("密室开启：守卫者 %d" % _vault_guardians.size())
	broadcast("密室开启，守卫者 %d 名。" % _vault_guardians.size())

func near(node: Node3D) -> bool:
	return is_instance_valid(node) and node.visible and player.global_position.distance_to(node.global_position) < 2.8

func advance(route: int) -> void:
	if in_base or in_camp or transitioning or route < 0 or route >= FieldCatalog.ROUTES.size(): return
	# The end of a block of ten leads into its camp first (§1).
	if floor_number % FieldCatalog.CAMP_INTERVAL == 0:
		close_modal()
		_camp_route = route
		_enter_camp()
		return
	await _advance_floor(route)

func _advance_floor(route: int) -> void:
	transitioning = true
	close_modal()
	route_index = route
	floor_number += 1
	route_history.append({"floor": floor_number, "name": FieldCatalog.ROUTES[route].name})
	_build_world()
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await _await_navigation_sync()
	_spawn_wave()
	transitioning = false
	set_message("进入第 %d 层 · %s；上一层已无法返回。" % [floor_number, FieldCatalog.ROUTES[route].name])
	broadcast("进入 %s · %s。" % [AK.floor_code(region_id, floor_number), FieldCatalog.ROUTES[route].name])

func _offer_builds() -> void:
	open_relic_offer("device")

## Shows the offer of the device (cache == null) or of a relic cache, rolling
## it the first time only. Fewer than three relics left leaves it dormant.
func open_relic_offer(source: String, cache: RelicCache = null) -> void:
	var stored: Array[Dictionary] = _device_offers if cache == null else cache.offers
	if stored.is_empty():
		stored = _roll_relics(source)
		if cache == null: _device_offers = stored
		else: cache.offers = stored
	if stored.size() < 3:
		set_message("本地区可选藏品不足三件：装置休眠。已有藏品跨区段保留。")
		return
	offer_source = source
	_active_cache = cache
	build_offers = stored
	open_modal("build")
	menu.show_builds()

func _roll_relics(source: String) -> Array[Dictionary]:
	# 罗德岛战术电台: one more option.
	return RelicCatalog.roll_offers(region_id, builds, source, rng, 3 + int(player.f("radio")))

func reroll_cost() -> int:
	return RelicCatalog.REROLL_BASE + RelicCatalog.REROLL_STEP * reroll_count

## Pays in 赤金 from the pack, the same money she could carry home.
func reroll_offers() -> bool:
	if modal != "build" or gold_bars() < reroll_cost(): return false
	if offer_source == "device" and _buff_taken: return false
	var rolled := _roll_relics(offer_source)
	if rolled.size() < 3: return false
	spend_gold_bars(reroll_cost())
	reroll_count += 1
	if is_instance_valid(_active_cache): _active_cache.offers = rolled
	else: _device_offers = rolled
	build_offers = rolled
	menu.show_builds()
	return true

func choose_build(id: String) -> bool:
	if modal != "build" or builds.has(id): return false
	if not is_instance_valid(_active_cache) and _buff_taken: return false
	for offer in build_offers:
		if offer.id == id:
			var enemy_hp_before := player.f("enemy_hp")
			builds.append(id)
			if is_instance_valid(_active_cache):
				_active_cache.claim()
				_active_cache = null
			else:
				_buff_taken = true
			sound.play("build")
			player._recompute_stats()
			_rescale_enemy_life(enemy_hp_before, player.f("enemy_hp"))
			close_modal()
			set_message("获得藏品 %s — %s" % [offer.name, offer.effect])
			return true
	return false

func _spawn_relic_cache(at: Vector3, source: String, sealed: bool) -> RelicCache:
	var cache := RelicCache.new()
	cache.game = self
	cache.source = source
	cache.sealed = sealed
	add_child(cache)
	cache.global_position = world_map.nearest_walkable(at)
	cache.global_position.y = 0.0
	return cache

## "黑夜呢喃" / 《大静谧》 also shrink enemies already standing in the segment.
func _rescale_enemy_life(before: float, after: float) -> void:
	if is_equal_approx(before, after): return
	var factor := enemy_life_multiplier(after) / enemy_life_multiplier(before)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.game != self or enemy._dead: continue
		enemy.max_health *= factor
		enemy.health *= factor

static func enemy_life_multiplier(enemy_hp: float) -> float:
	return maxf(0.3, 1.0 + enemy_hp)

## Relic effects on enemy attack (开裂的束缚带 … 死仇时代的恨意).
func enemy_attack_multiplier() -> float:
	return maxf(0.3, 1.0 + player.f("enemy_atk")) if is_instance_valid(player) else 1.0

func pressure_multiplier() -> float:
	return maxf(0.1, 1.0 + float(player.stats.get("pressure_pct", 0.0)))

func open_modal(kind: String) -> void:
	modal = kind
	player.clear_move_target()
	player.clear_target()

func close_modal() -> void:
	modal = ""
	_pointer_gate = true
	if is_instance_valid(menu): menu.hide()
	if is_instance_valid(_inventory_panel): _inventory_panel.hide()
	if is_instance_valid(field_panels): field_panels.hide_all()
	# In a camp nothing is underneath: back to the camp's own screen.
	if in_camp and not transitioning and not in_base:
		modal = "camp"
		if is_instance_valid(menu): menu.show_camp()

# --- HUD support (界面策划案 v1.1 §3) ----------------------------------------

## PRTS broadcasts, newest last: [time, text]. System events only — no combat,
## no pickups (用户 2026-10-06).
var prts_log: Array = []
var _seen_encounter := false
var _seen_exit := false
## The panels the HUD buttons and the I / C / R / M / J / Esc keys open.
const PANELS := ["inventory", "relics", "map", "journal", "pause"]

func broadcast(text: String) -> void:
	prts_log.append([Time.get_time_string_from_system(), text])
	if prts_log.size() > 40: prts_log.pop_front()

## Opens a panel, or closes it when it is the one open. Panels replace each
## other; anything else on screen (a shop, a choice) keeps them shut.
func toggle_panel(kind: String) -> void:
	if transitioning or not kind in PANELS: return
	if kind != "pause" and in_base: return
	if modal == kind:
		close_modal()
		return
	if not (modal.is_empty() or modal in PANELS or (in_camp and modal == "camp")): return
	if is_instance_valid(_inventory_panel): _inventory_panel.hide()
	if is_instance_valid(field_panels): field_panels.hide_all()
	open_modal(kind)
	match kind:
		"inventory": _inventory_panel.open()
		"pause": menu.show_pause()
		_: field_panels.open(kind)

## Esc (用户 2026-10-06): back one level — a dialog, a sub-page, a window, a
## screen — and with nothing open, the pause menu with its settings.
func go_back() -> void:
	if transitioning: return
	var focus := get_tree().root.gui_get_focus_owner()
	if focus is LineEdit:
		focus.release_focus()
		return
	if is_instance_valid(system_screens) and system_screens.go_back(): return
	if is_instance_valid(_inventory_panel) and is_instance_valid(_inventory_panel._confirm) and _inventory_panel._confirm.visible:
		_inventory_panel._confirm.hide()
		return
	match modal:
		"":
			toggle_panel("pause")
		"title":
			pass
		"camp":
			# The camp screen is where she stands; Esc pauses over it.
			toggle_panel("pause")
		_:
			if is_instance_valid(menu) and menu.back_to.is_valid():
				var back := menu.back_to
				menu.back_to = Callable()
				back.call()
			else:
				close_modal()

## Field mapping: things found get a PRTS line once (the fog decides "found").
func _announce_discoveries() -> void:
	if not _seen_encounter and is_instance_valid(world_map.encounter_node) and world_map.encounter_node.visible and fog.is_point_revealed(world_map.encounter_node.position):
		_seen_encounter = true
		broadcast("附近发现%s。" % ("坎诺特" if encounter == "trader" else "罗德岛小队"))
	if not _seen_exit and is_extraction_floor() and is_instance_valid(world_map.exit_node) and fog.is_point_revealed(world_map.exit_node.position):
		_seen_exit = true
		broadcast("本层发现撤离点。")

const DEPT_COLOURS := {"工程部": Color("f5c000"), "医疗部": Color("8fc31f"), "后勤部": Color("0098dc")}

## The tracker's rows (orders only): open orders for this region or any, with
## how many matching units she carries.
func order_progress() -> Array:
	var rows: Array = []
	var board: OrderBoard = base.orders
	for slot in range(board.slots.size()):
		var order = board.slots[slot]
		if order == null or order.state != "open": continue
		var t: Dictionary = BaseCatalog.ORDERS[order.id]
		var where := str(t.get("region", ""))
		if not where.is_empty() and where != region_id: continue
		var have := 0
		for item in carried_items():
			if board.matches(slot, item): have += item.quantity if item.is_stackable() else 1
		var what := BaseCatalog.order_text(order.id).split("：")[1] if "：" in BaseCatalog.order_text(order.id) else BaseCatalog.order_text(order.id)
		what = what.split(" ×")[0].split("（")[0]
		rows.append({"dept": t.dept, "colour": DEPT_COLOURS.get(t.dept, Color.WHITE), "color": DEPT_COLOURS.get(t.dept, Color.WHITE), "what": what, "have": have, "need": board.remaining(slot),
			"slot": slot, "mult": t.get("mult", 1.0), "prestige": t.get("prestige", 0)})
	return rows

## What E would do right here, for the prompt near her ("" for nothing).
func interaction_prompt() -> String:
	if not simulation_active(): return ""
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game == self and near(cache): return "密室藏品" if cache.source == "vault" else "战斗缴获"
	if near(world_map.buff_device_node) and not _buff_taken: return "强化装置"
	if near(world_map.encounter_node) and not encounter.is_empty() and (encounter == "trader" or not encounter_used):
		return "坎诺特" if encounter == "trader" else "罗德岛小队"
	if near(world_map.exit_node) and is_extraction_floor(): return "撤离"
	for i in range(world_map.mechanism_nodes.size()):
		if near(world_map.mechanism_nodes[i]) and not _mechanisms_done.has(i): return "机关"
	for node in world_map.route_nodes:
		if near(node): return "深入"
	return ""

# --- The Rhodes squad (保全系统修订案 §2–4) -----------------------------------

## Its price for `item` in 赤金: 物品价值 × this squad's multiplier ÷ 10, rounded up.
func squad_price(item: Item) -> int:
	return maxi(1, ceili(item.value * squad_mult / 10.0)) if item != null else 0

## Why the squad will not take `item` for this service now ("" when it will).
func squad_refusal(item: Item, service: String) -> String:
	if in_base or encounter != "squad" or encounter_used or not near(world_map.encounter_node): return "小队不在附近"
	if item == null or not carried_items().has(item) or not item.is_equippable(): return "只收装备"
	if service == "insure" and item.insured: return "已投保"
	if service == "send" and not base.staging_has_room(): return "暂存区已满"
	if gold_bars() < squad_price(item): return "赤金不足"
	return ""

## Insures one item she carries: if she dies on this contract it comes back,
## 1–3 contracts later. One service per squad.
func squad_insure(item: Item) -> bool:
	if not squad_refusal(item, "insure").is_empty(): return false
	spend_gold_bars(squad_price(item))
	item.insured = true
	encounter_used = true
	save_base(true)
	set_message("罗德岛小队：%s 已投保。" % item.item_name)
	return true

## Sends one item home now: it is gone from her and waits in staging. An
## insured item can be sent too; its insurance lapses.
func squad_send_home(item: Item) -> bool:
	if not squad_refusal(item, "send").is_empty(): return false
	spend_gold_bars(squad_price(item))
	inventory.remove(item)
	safe_bag.remove(item)
	if player.equipped.get(item.category) == item: player.unequip(item.category)
	item.insured = false
	item.carried_in = false
	base.receive_to_staging(item)
	encounter_used = true
	save_base(true)
	set_message("罗德岛小队：%s 已送回基地暂存区。" % item.item_name)
	return true

func carried_items() -> Array[Item]:
	var items: Array[Item] = []
	for item in inventory.items + safe_bag.items + player.equipped.values():
		if item != null and not items.has(item): items.append(item)
	return items

func count_effect(effect: String) -> int:
	var count := 0
	for item in carried_items():
		if item.effect == effect: count += 1
	return count

func _extract() -> void:
	if not in_base and not transitioning and is_extraction_floor(): settle(true)

func _on_player_died() -> void:
	if not in_base and not _settled: settle(false)

func settle(extracted: bool) -> void:
	if _settled: return
	_settled = true
	transitioning = true
	var in_camp_before_settle := in_camp
	in_camp = false
	settlement.clear()
	music.end_run(extracted)
	# What comes back: gear she set out with stays on her (equipped, packed or
	# in the safe bag) — she already knows it, so it skips the crates. Anything
	# found on this contract arrives as a sealed crate at receiving.
	var new_finds := 0
	var still_equipped: Array[Item] = []
	# Insurance from earlier deaths counts down first (保全系统修订案 §3), so what
	# is insured on this contract waits its full 1–3 contracts.
	var returned := base.tick_insurance()
	settlement_view = {"extracted": extracted, "region": region_id, "start": start_floor, "depth": floor_number,
		"pack_size": Vector2i(inventory.width, inventory.height), "safe_size": Vector2i(safe_bag.width, safe_bag.height),
		"pack": [], "safe": [], "worn": [], "reward": 0, "returned": returned.size(), "gold": 0, "orders": 0,
		"plate": camp_label(floor_number) if in_camp_before_settle else AK.floor_code(region_id, floor_number),
		"time": Time.get_time_string_from_system().left(5), "contamination_before": roundi(base.contamination)}
	for item in carried_items():
		var where := "safe" if safe_bag.items.has(item) else ("worn" if player.equipped.values().has(item) else "pack")
		var reason := "遗失"
		if extracted: reason = "撤离带回"
		elif safe_bag.items.has(item): reason = "安全袋保全"
		elif item.insured: reason = "投保送回"
		var entry := {"uid": item.uid, "name": item.item_name, "reason": reason}
		var kept := reason in ["撤离带回", "安全袋保全"]
		var stays_on_her := kept and item.carried_in
		if stays_on_her and player.equipped.get(item.category) == item: still_equipped.append(item)
		if not stays_on_her:
			inventory.remove(item)
			safe_bag.remove(item)
		if reason == "投保送回":
			var wait := rng.randi_range(FieldCatalog.INSURANCE_DELAY.x, FieldCatalog.INSURANCE_DELAY.y)
			item.insured = false
			item.carried_in = false
			base.queue_insured(item, wait)
			entry["contracts"] = wait
		if kept:
			# Insurance only covers a death; extracting lets it lapse unrefunded.
			item.insured = false
			item.carried_in = false
			if not stays_on_her and base.receive(item): new_finds += 1
		settlement.append(entry)
		var shown := {"item": item, "reason": reason, "x": item.grid_x, "y": item.grid_y, "w": item.width, "h": item.height}
		settlement_view[where].append(shown)
		if kept and item.material_id == Economy.GOLD_ID: settlement_view.gold += item.quantity
		if kept:
			for slot in range(base.orders.slots.size()):
				if base.orders.slots[slot] != null and base.orders.slots[slot].state == "open" and base.orders.matches(slot, item):
					settlement_view.orders += 1
					break
	builds.clear()
	build_offers.clear()
	_device_offers.clear()
	if extracted: _grant(0, BaseCatalog.PRESTIGE_EXTRACTION)
	base.orders.refill(rng, region_id)
	base.settle_medical(run_contamination, not extracted)
	settlement_view.contamination_after = roundi(base.contamination)
	base.reroll_available = base.rank() >= BaseCatalog.REROLL_RANK
	# The drone empties staging onto the shelves at every return (§3.4a).
	if base.drone: base.sort_staging()
	run_contamination = 0.0
	_slow_heal_left = 0.0
	_suppress_timer = 0.0
	player.condition_hp_penalty = 0.0
	player.regen_blocked = false
	player.reset_stats()
	for item in still_equipped: player.equip(item)
	player.hp = player.max_hp
	# 赤金 came home as items with everything else; the contract itself pays
	# 龙门币 for every floor travelled, and nothing on death (经济修订案 §3).
	var reward := Economy.contract_reward(floor_number - start_floor + 1, rng) if extracted else 0
	gold += reward
	settlement_view.reward = reward
	_clear_field()
	world_map._clear_generated_map()
	floor_number = 1
	in_base = true
	transitioning = false
	save_base()
	set_message("%s：%d 件新物品已送到仓储区收货区。%s%s" % ["合同交付" if extracted else "回收队归来", new_finds,
		"合同报酬 %s 龙门币。" % Economy.format(reward) if reward > 0 else "", "投保物品送回 %d 件。" % returned.size() if not returned.is_empty() else ""])
	base_spawn = "arrival" if extracted else "death"
	show_base()
	broadcast("拉普兰德已完成撤离。" if extracted else "回收队已带回拉普兰德。")
	if new_finds > 0: broadcast("收货区货箱有 %d 件新物品待开箱。" % new_finds)
	if show_settlement_screen:
		open_modal("settlement")
		menu.show_settlement()

# --- 坎诺特 (坎诺特商店策划案) ---------------------------------------------------

## His stock this floor: eight slots, {"kind": "relic"/"item", "relic": Dictionary,
## "item": Item, "price": 赤金, "sold": bool}. Rolled when he is first met.
var trader_stock: Array[Dictionary] = []
var trader_rerolls := 0
## 幸运硬币 / 假面舞会面具 pay once per encounter, on first meeting.
var _encounter_greeted := false

## Opens the squad or 坎诺特 at this floor's encounter spot.
func _open_encounter() -> void:
	if not _encounter_greeted:
		_encounter_greeted = true
		var bonus := roundi(player.f("node_gold"))
		if bonus > 0:
			_give_gold_bars(bonus)
			set_message("遇到%s：赤金 +%d" % ["坎诺特" if encounter == "trader" else "罗德岛小队", bonus])
	if encounter == "trader":
		if trader_stock.is_empty(): _roll_trader_stock()
		open_modal("trader")
		menu.show_trader()
	else:
		open_modal("squad")
		menu.show_squad()

## 锈蚀的铁锤 halves what he asks (商店中购买道具所需源石锭-50%).
func _trader_discount(price: int) -> int:
	return maxi(1, ceili(price * (1.0 - minf(0.9, player.f("shop_discount")))))

## Eight slots (§2): two relics, three of the region's gear, two flasks, one
## special slot (25% special gear, else more gear).
func _roll_trader_stock() -> void:
	trader_stock.clear()
	var relics := RelicCatalog.roll_offers(region_id, builds, "device", rng, FieldCatalog.TRADER_RELICS)
	for relic in relics:
		trader_stock.append({"kind": "relic", "relic": relic, "price": _trader_discount(int(FieldCatalog.TRADER_RELIC_PRICES[relic.rarity])), "sold": false})
	for i in range(FieldCatalog.TRADER_GEAR):
		trader_stock.append(_trader_gear_slot(_roll_trader_gear()))
	for i in range(FieldCatalog.TRADER_POTIONS):
		var roll := rng.randf()
		var type := "A" if roll < 0.5 else ("B" if roll < 0.85 else "C")
		trader_stock.append({"kind": "item", "item": BaseCatalog.create_potion(type), "price": _trader_discount(int(FieldCatalog.TRADER_POTION_PRICES[type])), "sold": false})
	var special := SpecialGear.roll(region_id, floor_number, rng) if rng.randf() < FieldCatalog.TRADER_SPECIAL_CHANCE else _roll_trader_gear()
	trader_stock.append(_trader_gear_slot(special))

func _roll_trader_gear() -> Item:
	for attempt in range(40):
		var item := FieldCatalog.roll_item(region_id, floor_number, rng, 0.0)
		if item.is_equippable() and item.exclusive_region.is_empty() and item.special.is_empty(): return item
	return FieldCatalog.roll_item(region_id, floor_number, rng, 0.0)

func _trader_gear_slot(item: Item) -> Dictionary:
	return {"kind": "item", "item": item, "price": _trader_discount(maxi(1, ceili(item.value * FieldCatalog.TRADER_GEAR_MARKUP / 10.0))), "sold": false}

func trader_reroll_cost() -> int:
	return FieldCatalog.TRADER_REROLL_BASE + FieldCatalog.TRADER_REROLL_STEP * trader_rerolls

func trader_reroll() -> bool:
	if encounter != "trader" or gold_bars() < trader_reroll_cost(): return false
	spend_gold_bars(trader_reroll_cost())
	trader_rerolls += 1
	_roll_trader_stock()
	return true

func trader_buy_refusal(slot: int) -> String:
	if encounter != "trader" or slot < 0 or slot >= trader_stock.size(): return "没有这件"
	var entry: Dictionary = trader_stock[slot]
	if entry.sold: return "已售出"
	if gold_bars() < int(entry.price): return "赤金不足"
	if entry.kind == "relic" and builds.has(entry.relic.id): return "已拥有"
	if entry.kind == "item" and not inventory.can_fit(entry.item): return "背包放不下"
	return ""

func trader_buy(slot: int) -> bool:
	if not trader_buy_refusal(slot).is_empty(): return false
	var entry: Dictionary = trader_stock[slot]
	spend_gold_bars(int(entry.price))
	entry.sold = true
	if entry.kind == "relic":
		var enemy_hp_before := player.f("enemy_hp")
		builds.append(entry.relic.id)
		player._recompute_stats()
		_rescale_enemy_life(enemy_hp_before, player.f("enemy_hp"))
		set_message("获得藏品 %s — %s" % [entry.relic.name, entry.relic.effect])
	else:
		inventory.try_add(entry.item)
		set_message("买下 %s" % entry.item.display_name())
	save_base(true)
	return true

## What he pays for `item` in 赤金 (§3: 交付价 × 50%), or 0 when he will not buy it:
## gear and materials only — no flasks, no 原矿, nothing insured, no 赤金.
func trader_offer(item: Item) -> int:
	if item == null or item.is_potion() or item.insured or item.effect == "raw_ore" or item.material_id == Economy.GOLD_ID: return 0
	return maxi(1, floori(item.value * FieldCatalog.TRADER_BUYBACK / 10.0))

func trader_sell(item: Item) -> bool:
	if encounter != "trader" or not carried_items().has(item) or trader_offer(item) <= 0: return false
	var pay := trader_offer(item)
	inventory.remove(item)
	safe_bag.remove(item)
	if player.equipped.get(item.category) == item: player.unequip(item.category)
	_give_gold_bars(pay)
	save_base(true)
	set_message("卖给坎诺特：%s，赤金 +%d" % [item.display_name(), pay])
	return true

## Bars straight into the pack (no gold-gain bonus); what does not fit drops.
func _give_gold_bars(bars: int) -> void:
	var left := bars
	while left > 0:
		var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)), region_id)
		left -= stack.quantity
		if inventory.add_stack(stack) > 0 and not in_base: _drop_at(player.global_position, [{"item": stack}], 0.8)

# --- Camps (撤离与营地修订案 §1–3) ---------------------------------------------

## A camp sits after every CAMP_INTERVAL floors (10|11, 20|21 …): no enemies,
## the fixed extraction, and 可露希尔. Reaching one unlocks it for this region.
func _enter_camp() -> void:
	in_camp = true
	_clear_field()
	world_map._clear_generated_map()
	player.clear_move_target()
	base.unlock_camp(region_id, floor_number)
	# 营地里污染照涨，升级后不涨: a flat dose for the time spent there.
	if not base.camp_upgraded:
		run_contamination += contamination_rate() * FieldCatalog.CAMP_EXPOSURE_SECONDS
	save_base(true)
	open_modal("camp")
	menu.show_camp()
	set_message("抵达营地 %d|%d。" % [floor_number, floor_number + 1])
	broadcast("抵达营地 %d|%d。" % [floor_number, floor_number + 1])

## Extract from the camp (the fixed extraction).
func camp_extract() -> void:
	if in_camp and not transitioning: settle(true)

## On from the camp to the next floor, by the route chosen at the end of the last.
func leave_camp() -> void:
	if not in_camp or transitioning: return
	in_camp = false
	await _advance_floor(_camp_route)

func camp_label(depth: int) -> String:
	return "营地 %d|%d" % [depth, depth + 1]

## 赤金 she can pay with here: what she carries in a camp, the base's storage too at home.
func gold_available() -> int:
	return material_count(Economy.GOLD_ID) if in_base else gold_bars()

func _pay_gold(bars: int) -> bool:
	if in_base: return consume_materials({Economy.GOLD_ID: bars}) if bars > 0 else true
	return spend_gold_bars(bars)

## 可露希尔's price for a flask in 赤金: the pharmacy's 龙门币 price, rounded up
## to whole 赤金 (撤离与营地修订案 §0: 同价). -1 while the rank does not allow it.
func closure_potion_price(type: String) -> int:
	var p: Dictionary = BaseCatalog.POTIONS[type]
	if base.rank() < int(p.rank): return -1
	var lmd: int = BaseCatalog.POTION_A_PRICE if type == "A" else int(p.price)
	return maxi(1, ceili(float(lmd) / Economy.GOLD_BAR_LMD))

## A flask from 可露希尔, into the pack (in a camp, or at her base counter).
func closure_buy_potion(type: String) -> bool:
	if not (in_camp or in_base) or not BaseCatalog.POTIONS.has(type): return false
	var price := closure_potion_price(type)
	if price < 0 or gold_available() < price: return false
	var flask := BaseCatalog.create_potion(type)
	if not inventory.try_add(flask):
		set_message("背包空间不足：药剂要占一格。")
		return false
	_pay_gold(price)
	save_base(not in_base)
	return true

## 寄存 (§3): materials only, no special (regional) ones and no flasks; the fee is
## 20% of the 交付价, in 赤金, rounded up, at least one.
func deposit_fee(item: Item) -> int:
	return maxi(1, ceili(Economy.price(item) * FieldCatalog.DEPOSIT_FEE / float(Economy.GOLD_BAR_LMD))) if item != null else 0

func deposit_refusal(item: Item) -> String:
	if not in_camp: return "不在营地"
	if item == null or not (inventory.items.has(item) or safe_bag.items.has(item)): return "不在背包里"
	if item.category != Item.Category.MATERIAL or item.is_potion(): return "只收材料"
	if not item.exclusive_region.is_empty() or not item.effect.is_empty(): return "特殊材料不能寄存"
	if not base.staging_has_room(): return "暂存区已满"
	var others := gold_bars() - (item.quantity if item.material_id == Economy.GOLD_ID else 0)
	if others < deposit_fee(item): return "赤金不足"
	return ""

func deposit_item(item: Item) -> bool:
	if not deposit_refusal(item).is_empty(): return false
	var fee := deposit_fee(item)
	inventory.remove(item)
	safe_bag.remove(item)
	spend_gold_bars(fee)
	item.carried_in = false
	base.receive_to_staging(item)
	save_base(true)
	set_message("已寄存 %s：送到基地暂存区。" % item.display_name())
	return true

## 可露希尔 buys 赤金 for 龙门币 (经济修订案 §0).
func sell_gold_bars(bars: int) -> bool:
	if not (in_camp or in_base) or bars <= 0 or gold_available() < bars: return false
	_pay_gold(bars)
	gold += bars * Economy.GOLD_BAR_LMD
	save_base(not in_base)
	set_message("卖出赤金 ×%d：龙门币 +%s" % [bars, Economy.format(bars * Economy.GOLD_BAR_LMD)])
	return true

## The camp upgrade (基地建设, not per region): camps stop adding contamination.
func camp_upgrade_refusal() -> String:
	if base.camp_upgraded: return "已升级"
	if gold < BaseCatalog.CAMP_UPGRADE_PRICE: return "龙门币不足"
	return materials_refusal(BaseCatalog.CAMP_UPGRADE_MATERIALS)

func buy_camp_upgrade() -> bool:
	if not in_base or not camp_upgrade_refusal().is_empty(): return false
	consume_materials(BaseCatalog.CAMP_UPGRADE_MATERIALS)
	gold -= BaseCatalog.CAMP_UPGRADE_PRICE
	base.camp_upgraded = true
	save_base()
	set_message("营地升级完成：在营地停留不再累积污染。")
	return true

## Hidden difficulty (§4, after 贪婪洞窟's per-floor tables): a curve by floor plus
## the chosen route's modifier for this floor only. Never shown as a number.
func difficulty() -> float:
	var d := FieldCatalog.DIFFICULTY_PER_FLOOR * (floor_number - 1) + float(FieldCatalog.ROUTES[route_index].danger)
	return maxf(0.0, d * pressure_multiplier())

func passes_pickup_filter(item: Item) -> bool:
	if item == null or not item.is_equippable() or not item.exclusive_region.is_empty(): return true
	return item.rarity >= pickup_filter

func cycle_pickup_filter() -> void:
	pickup_filter = (pickup_filter + 1) % PICKUP_FILTER_NAMES.size()
	save_base(not in_base)
	set_message("拾取过滤：%s（被过滤的装备留在地上，靠近按 E 拾取；按住 Alt 显示地面物品名）" % PICKUP_FILTER_NAMES[pickup_filter])

## What happens to `item` if she dies right now (策划案 §6 settlement order).
func death_outcome(item: Item) -> String:
	if in_base: return ""
	if safe_bag.items.has(item): return "保留（安全袋）"
	if item.insured: return "送回（投保）"
	return "丢失"

## Value at stake (装备与背包界面调研 §5.9): what she carries, what is certain
## to come back on death, what insurance is expected to return, what is lost.
func value_summary() -> Dictionary:
	var summary := {"carried": 0, "safe": 0, "insured": 0, "kept": 0, "lost": 0}
	for item in carried_items():
		summary.carried += item.value
		var outcome := death_outcome(item)
		if outcome.begins_with("保留"):
			summary.safe += item.value
			summary.kept += item.value
		elif outcome.begins_with("送回"): summary.insured += item.value
		else: summary.lost += item.value
	return summary

## Repacks the pack (the safe bag is never touched).
func sort_pack() -> bool:
	var sorted := inventory.sort_items()
	save_base(not in_base)
	set_message("背包已整理。" if sorted else "整理失败：当前摆放已是最紧凑，物品未移动。")
	return sorted

## Drag and drop (装备与背包界面调研 §5.4): `from` is a container, or null for
## an equipped item; the target is a cell of `to`.
func move_item(item: Item, from: ItemContainer, to: ItemContainer, x: int, y: int) -> bool:
	if item == null or to == null: return false
	if from == to: return to.reposition(item, x, y)
	if from == null:
		if player.equipped.get(item.category) != item or not to.place(item, x, y): return false
		player.unequip(item.category)
	else:
		if not from.items.has(item) or not to.can_place(item, x, y): return false
		from.remove(item)
		to.place(item, x, y)
	save_base(not in_base)
	return true

## Ctrl+click: pack ↔ safe bag.
func quick_move(item: Item, from: ItemContainer) -> bool:
	var to := safe_bag if from == inventory else inventory
	return transfer_item(item, from, to)

## Container sizes from the base's expansion levels.
func apply_container_sizes() -> void:
	var pack: Vector2i = BaseCatalog.PACK_SIZES[base.pack_level]
	var safe: Vector2i = BaseCatalog.SAFE_SIZES[base.safe_level]
	inventory.resize(pack.x, pack.y)
	safe_bag.resize(safe.x, safe.y)

## Units of a PRTS material in the warehouse, pack and safe bag (掉落物策划案 §7.1).
func material_count(id: String) -> int:
	var total := inventory.count_material(id) + safe_bag.count_material(id)
	for item in stash:
		if item.material_id == id: total += item.quantity
	return total

## "" when every material of `cost` is there, else what is missing.
func materials_refusal(cost: Dictionary) -> String:
	var missing: Array[String] = []
	for id in cost:
		var short := int(cost[id]) - material_count(id)
		if short > 0: missing.append("%s×%d" % [id, short])
	return "" if missing.is_empty() else "缺少 " + "、".join(missing)

## Takes `cost` out, from the warehouse first, then the safe bag, then the pack.
func consume_materials(cost: Dictionary) -> bool:
	if not materials_refusal(cost).is_empty(): return false
	for id in cost:
		var need := int(cost[id])
		for source in ["stash", "safe", "pack"]:
			var pool: Array = stash if source == "stash" else (safe_bag.items if source == "safe" else inventory.items)
			for item: Item in pool.duplicate():
				if need <= 0: break
				if item.material_id != id: continue
				var used := mini(need, item.quantity)
				need -= used
				if used < item.quantity: item.set_quantity(item.quantity - used)
				else: _hand_over(item)
	return true

func upgrade_cost(kind: String) -> Dictionary:
	var level := (base.pack_level if kind == "pack" else base.safe_level) + 1
	var table: Array = BaseCatalog.PACK_MATERIALS if kind == "pack" else BaseCatalog.SAFE_MATERIALS
	return table[level] if level < table.size() else {}

## Gold, rank and materials together, for the terminal buttons.
func upgrade_refusal(kind: String) -> String:
	var refusal := base.upgrade_refusal(kind, gold)
	return refusal if not refusal.is_empty() else materials_refusal(upgrade_cost(kind))

func rack_cost(category: int) -> Dictionary:
	var slot := base.next_rack_slot(category)
	return BaseCatalog.RACK_MATERIALS[slot] if slot >= 0 else {}

func rack_refusal(category: int) -> String:
	var refusal := base.rack_refusal(category, gold)
	return refusal if not refusal.is_empty() else materials_refusal(rack_cost(category))

func drone_refusal() -> String:
	if base.drone: return "已就位"
	if base.rank() < BaseCatalog.DRONE_RANK: return "需要声望 R%d" % BaseCatalog.DRONE_RANK
	if gold < BaseCatalog.DRONE_PRICE: return "龙门币不足"
	return materials_refusal(BaseCatalog.DRONE_MATERIALS)

func buy_pack_upgrade() -> bool:
	if not upgrade_refusal("pack").is_empty(): return false
	consume_materials(upgrade_cost("pack"))
	gold -= int(BaseCatalog.PACK_PRICES[base.pack_level + 1])
	base.pack_level += 1
	apply_container_sizes()
	save_base()
	set_message("背包扩容到 %d×%d。" % [inventory.width, inventory.height])
	return true

func buy_safe_upgrade() -> bool:
	if not upgrade_refusal("safe").is_empty(): return false
	consume_materials(upgrade_cost("safe"))
	gold -= int(BaseCatalog.SAFE_PRICES[base.safe_level + 1])
	base.safe_level += 1
	apply_container_sizes()
	save_base()
	set_message("安全袋扩容到 %d×%d。" % [safe_bag.width, safe_bag.height])
	return true

## Every material in the pack and safe bag back to the warehouse at once
## (装备与背包界面调研 §5.13, Grim Dawn's one-click materials button).
func store_all_materials() -> int:
	var stored := 0
	for item in carried_items():
		if not item.is_equippable() and store_item(item): stored += 1
	if stored > 0: set_message("已存回 %d 件材料。" % stored)
	return stored

func try_collect(item: Item) -> bool:
	if item.is_stackable():
		var before := item.quantity
		var left := inventory.add_stack(item)
		if left == 0:
			save_base(true)
			sound.play("loot")
			set_message("拾取 %s ×%d" % [item.display_name(), before])
			return true
		if left < before:
			save_base(true)
			sound.play("loot")
			set_message("背包只装下 %d 个 %s，剩余 %d 个留在地上。" % [before - left, item.item_name, left])
			return false
		set_message("背包空间不足：%s ×%d 仍留在地上。" % [item.item_name, left])
		return false
	if inventory.try_add(item):
		save_base(true)
		sound.play("loot")
		set_message("拾取 %s（%d×%d）" % [item.display_name(), item.width, item.height])
		return true
	set_message("背包空间不足：%s 仍留在地上。" % item.item_name)
	return false

func _move_last_item_to_safe_bag() -> void:
	if not inventory.is_empty(): transfer_item(inventory.items.back(), inventory, safe_bag)

func transfer_item(item: Item, from: ItemContainer, to: ItemContainer) -> bool:
	if not from.transfer_to(item, to):
		set_message("空间不足，物品留在原处；物品不能旋转。")
		return false
	save_base(not in_base)
	set_message("已转移：%s" % item.item_name)
	return true

func equip_from(item: Item, from: ItemContainer) -> bool:
	if not from.items.has(item) or not item.is_equippable(): return false
	var old_pos := Vector2i(item.grid_x, item.grid_y)
	from.remove(item)
	var previous: Item = player.equipped.get(item.category)
	if previous != null and not from.try_add(previous):
		item.grid_x = old_pos.x
		item.grid_y = old_pos.y
		from.items.append(item)
		set_message("换装空间不足，物品均已保留。")
		return false
	player.equip(item)
	save_base(not in_base)
	return true

func unequip_to_pack(item: Item) -> bool:
	if item == null or player.equipped.get(item.category) != item or not inventory.try_add(item): return false
	player.unequip(item.category)
	save_base(not in_base)
	return true

func drop_item(item: Item, from: ItemContainer) -> bool:
	if in_base or item == null or not from.items.has(item): return false
	from.remove(item)
	save_base(true)
	var loot := Loot.new()
	loot.game = self
	loot.item = item
	loot.pickup_delay = 2.0
	add_child(loot)
	loot.global_position = player.global_position + Vector3(1.5, 0, 0)
	return true

## Off the shelf into the pack, to take on the next contract.
func bring_item(item: Item) -> bool:
	if not in_base or not base.take_from_shelf(item): return false
	if not inventory.try_add(item):
		base.put_back(item, "shelf")
		set_message("背包空间不足：%s 仍在货架上。" % item.item_name)
		return false
	save_base()
	return true

## From the loadout back to the base: its shelf, or staging when the shelf is full.
func store_item(item: Item) -> bool:
	if not in_base or not carried_items().has(item): return false
	if base.store_target(item).is_empty():
		set_message("%s区和暂存区都满了：%s 留在身上。" % [BaseCatalog.CATEGORY_NAMES[item.category], item.item_name])
		return false
	inventory.remove(item)
	safe_bag.remove(item)
	if player.equipped.get(item.category) == item: player.unequip(item.category)
	if base.store(item) == "staging": set_message("%s区已满：%s 放进了暂存区。" % [BaseCatalog.CATEGORY_NAMES[item.category], item.item_name])
	save_base()
	return true

# Receiving, carrying and staging (基地玩法策划案 §3.3–3.4a). The warehouse
# spots that call these come from WarehouseView.target_at().

## At a crate: open it if sealed, then show what is inside.
func inspect_crate(item: Item) -> void:
	if not in_base: return
	if base.location_of(item) == "crate_sealed":
		base.open_crate(item)
		sound.play("loot")
		save_base()
	if base.location_of(item) != "crate_open": return
	open_modal("station")
	menu.show_item_card(item)

## From an opened crate or staging into her hands.
func pick_up_item(item: Item) -> bool:
	if not in_base: return false
	if base.hand:
		set_message("先放下手上的 %s。" % base.hand.item_name)
		return false
	if not base.pick_up(item): return false
	save_base()
	set_message("拿起 %s：去%s区上架。" % [item.item_name, BaseCatalog.CATEGORY_NAMES[item.category]])
	return true

func shelve_carried(category: int) -> bool:
	if not in_base or base.hand == null: return false
	var refusal := base.shelve_hand_refusal(category)
	if not refusal.is_empty():
		set_message(refusal)
		return false
	var item := base.hand
	base.shelve_hand(category)
	save_base()
	set_message("已上架：%s（%s区 %d/%d）" % [item.item_name, BaseCatalog.CATEGORY_NAMES[category], base.shelf_count(category), base.capacity(category)])
	return true

func stage_carried() -> bool:
	if not in_base or base.hand == null: return false
	var item := base.hand
	if not base.stage_hand():
		set_message("暂存区已满（%d/%d）。" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY])
		return false
	save_base()
	set_message("%s 放进了暂存区（%d/%d）。" % [item.item_name, base.staging.size(), BaseCatalog.STAGING_CAPACITY])
	return true

func put_back_carried() -> bool:
	if not in_base or base.hand == null: return false
	var item := base.hand
	base.return_hand()
	save_base()
	set_message("%s 放回了%s。" % [item.item_name, "暂存区" if base.location_of(item) == "staging" else "货箱"])
	return true

func open_crate(item: Item) -> bool:
	if not in_base or not base.open_crate(item): return false
	save_base()
	return true

func shelve_item(item: Item) -> bool:
	if not in_base: return false
	var refusal := base.shelve_refusal(item)
	if not refusal.is_empty():
		set_message(refusal)
		return false
	base.shelve(item)
	save_base()
	return true

func stage_item(item: Item) -> bool:
	if not in_base or not base.stage(item):
		if in_base and not base.staging_has_room(): set_message("暂存区已满（%d/%d）。" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY])
		return false
	save_base()
	return true

## Taking an item out of staging straight into the pack (only at staging).
func unstage_to_pack(item: Item) -> bool:
	if not in_base or not base.unstage(item): return false
	if not inventory.try_add(item):
		base.put_back(item, "staging")
		set_message("背包空间不足：%s 仍在暂存区。" % item.item_name)
		return false
	save_base()
	return true

## Base insurance before leaving: the item's 交付价 in 龙门币 (保全系统修订案 §6).
func insurance_price(item: Item) -> int:
	return Economy.price(item)

func insure(item: Item) -> bool:
	if not in_base or not carried_items().has(item) or not item.is_equippable() or item.insured or gold < insurance_price(item): return false
	gold -= insurance_price(item)
	item.insured = true
	save_base()
	return true

# Delivery (§3.8): only from the warehouse proper (the shelves) or the pack and
# safe bag. Not from crates, her hands, staging, or what she has equipped.
func deliverable_items() -> Array[Item]:
	var out: Array[Item] = []
	out.append_array(stash)
	out.append_array(inventory.items)
	out.append_array(safe_bag.items)
	return out

func _hand_over(item: Item) -> bool:
	if base.take_from_shelf(item): return true
	if inventory.items.has(item): inventory.remove(item)
	elif safe_bag.items.has(item): safe_bag.remove(item)
	else: return false
	return true

## Plain delivery for money, outside any order.
func sell(item: Item) -> bool:
	if not in_base or not deliverable_items().has(item) or not _hand_over(item): return false
	gold += Economy.price(item)
	save_base()
	return true

func deliver_to_order(slot: int, item: Item) -> bool:
	if not in_base or not deliverable_items().has(item) or not base.orders.matches(slot, item): return false
	var result := base.orders.deliver(slot, item)
	# A stack bigger than the order needs stays where it was, smaller.
	if item.is_stackable() and int(result.used) < item.quantity: item.set_quantity(item.quantity - int(result.used))
	else: _hand_over(item)
	var text := BaseCatalog.order_text(base.orders.slots[slot].id)
	if result.done:
		_grant(result.gold, result.prestige)
		set_message("订单完成：%s  ·  龙门币 +%s  ·  声望 +%d" % [text, Economy.format(result.gold), result.prestige])
	else: set_message("已交付 %s ×%d：%s 还差 %d" % [item.item_name, int(result.used), text, base.orders.remaining(slot)])
	save_base()
	return true

func abandon_order(slot: int) -> bool:
	if not in_base or not base.orders.abandon(slot): return false
	set_message("已放弃订单：下次结算后补上新订单。")
	save_base()
	return true

func _grant(money: int, prestige: int) -> void:
	gold += money
	var new_rank := base.add_prestige(prestige)
	if new_rank > 0: set_message("声望提升到 R%d：%s。" % [new_rank, BaseCatalog.RANK_UNLOCKS[new_rank]])

func reroll_order(slot: int) -> bool:
	if not in_base or not base.reroll_available or not base.orders.reroll(slot, rng): return false
	base.reroll_available = false
	set_message("订单已刷新。")
	save_base()
	return true

# --- Expansion and the drone (§3.5, §3.6) --------------------------------------

func build_rack(category: int) -> bool:
	if not in_base: return false
	var refusal := rack_refusal(category)
	if not refusal.is_empty():
		set_message(refusal)
		return false
	consume_materials(rack_cost(category))
	var slot := base.build_rack(category)
	gold -= int(BaseCatalog.RACK_PRICES[slot])
	save_base()
	set_message("%s区新货架已就位：容量 %d。" % [BaseCatalog.CATEGORY_NAMES[category], base.capacity(category)])
	return true

func buy_drone() -> bool:
	if not in_base or not drone_refusal().is_empty(): return false
	consume_materials(BaseCatalog.DRONE_MATERIALS)
	gold -= BaseCatalog.DRONE_PRICE
	base.drone = true
	save_base()
	set_message("工程部的搬运无人机到位：在货箱前可以全部开箱并归类。")
	return true

## Opens every crate and puts everything that fits on its shelf (§3.5); the
## reveal plays as a list in the menu and the drone flies the deliveries.
func sort_everything() -> Dictionary:
	if not in_base or not base.drone: return {}
	var result := base.sort_all()
	var zones: Array = []
	for item: Item in result.shelved:
		if not zones.has(item.category): zones.append(item.category)
	zones.sort()
	if is_instance_valid(warehouse_view): warehouse_view.fly_drone(zones)
	save_base()
	if not result.revealed.is_empty() or not result.shelved.is_empty():
		open_modal("station")
		menu.show_sort_result(result)
	else: set_message("没有需要开箱或归类的物品。")
	return result

## Stations with something to do get a yellow marker (§5.2).
func station_needs_attention(id: String) -> bool:
	match id:
		"receiving_bays": return base.sealed_count() > 0
		"outbound": return is_instance_valid(warehouse_view) and warehouse_view.orders_fillable()
		"reception": return base.report_unread or base.injured
		"decon": return base.contamination_tier() >= 1
		"stash": return base.unseen_unlocks
	return false

# --- Departure (§5.3) ----------------------------------------------------------

## Reasons to stop and look before leaving; empty when there are none.
func departure_warnings() -> Array[String]:
	var out: Array[String] = []
	if base.injured or base.contamination_tier() >= 1:
		var parts: Array[String] = []
		if base.injured: parts.append("重伤 −%d%%" % roundi(BaseCatalog.INJURY_HP_PENALTY * 100))
		var tier := base.contamination_tier()
		if tier >= 1: parts.append("污染%s −%d%%" % [BaseCatalog.CONTAMINATION_TIER_NAMES[tier], roundi(float(BaseCatalog.CONTAMINATION_TIERS[tier][1]) * 100)])
		out.append("生命上限 −%d%%（%s，合计上限 −%d%%）" % [roundi(base.hp_penalty() * 100), "，".join(parts), roundi(BaseCatalog.HP_PENALTY_CAP * 100)])
	if base.hand: out.append("手上的 %s 会放回原处" % base.hand.item_name)
	var sealed := base.sealed_count()
	var staging_full := base.staging.size() >= BaseCatalog.STAGING_CAPACITY * BaseCatalog.STAGING_WARNING
	if sealed > 0 or staging_full:
		var parts: Array[String] = []
		if sealed > 0: parts.append("收货区仍有 %d 只未开货箱" % sealed)
		if staging_full: parts.append("暂存区 %d/%d" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY])
		out.append("，".join(parts) + "（不影响出发）")
	return out

## What the contract buttons call: leaves at once, or shows the departure card
## first when there is something to look at.
func request_contract(region: String, start_camp: int = 0) -> void:
	if not in_base or transitioning: return
	_pending_start_camp = start_camp
	if departure_warnings().is_empty():
		start_contract(region, start_camp)
		return
	open_modal("station")
	menu.show_departure(region)

## The base's top bar (§5.1): gold, prestige, and contamination and injury when present.
func base_status_text() -> String:
	var rank := base.rank()
	var parts: Array[String] = ["龙门币 %s" % Economy.format(gold)]
	parts.append("声望 R%d · %d%s" % [rank, base.prestige, "" if rank >= BaseCatalog.PRESTIGE_RANKS.size() else "/%d" % BaseCatalog.PRESTIGE_RANKS[rank]])
	if base.contamination >= 1.0: parts.append("污染 %d %s" % [roundi(base.contamination), BaseCatalog.CONTAMINATION_TIER_NAMES[base.contamination_tier()]])
	if base.injured: parts.append("重伤")
	return "   ".join(parts)

func carried_potions() -> Array[Item]:
	var out: Array[Item] = []
	for container in [inventory, safe_bag]:
		for item: Item in container.items:
			if item.is_potion(): out.append(item)
	return out

func _set_standard_potions(count: int) -> void:
	for item in carried_potions():
		inventory.remove(item)
		safe_bag.remove(item)
	for i in range(maxi(count, 0)):
		if not inventory.try_add(BaseCatalog.create_potion("A")): break

## The free 标准急救剂 for this contract go into the pack (what does not fit stays
## issued for next time).
func _issue_free_potions() -> void:
	while base.free_potions > 0 and inventory.try_add(BaseCatalog.create_potion("A")):
		base.free_potions -= 1

## Q: the first flask by POTION_ORDER, from the pack before the safe bag. At
## full health only the inhibitor is worth drinking (it also cleanses).
func _use_potion() -> void:
	var carried := carried_potions()
	if carried.is_empty(): return
	var pick: Item = null
	for type in POTION_ORDER:
		for item in carried:
			if item.potion_type == type:
				pick = item
				break
		if pick != null: break
	if player.hp >= player.max_hp and pick.potion_type != "C":
		var inhibitor := carried.filter(func(x): return x.potion_type == "C")
		if inhibitor.is_empty(): return
		pick = inhibitor[0]
	drink(pick)

## Drinks one flask she carries (Q, or right click in the pack).
func drink(item: Item) -> bool:
	if in_base or item == null or not item.is_potion() or not carried_items().has(item): return false
	inventory.remove(item)
	safe_bag.remove(item)
	var type := item.potion_type
	var amount: float = {"A": BaseCatalog.POTION_A_HEAL, "B": BaseCatalog.POTION_B_HEAL, "C": BaseCatalog.POTION_C_HEAL}[type]
	if builds.has("ore_heart"): amount *= 0.5
	if builds.has("bloodthirst"): amount *= 0.7
	if builds.has("safe_salvage"):
		amount *= 1.0 + 0.25 * safe_bag.items.filter(func(x): return not x.is_equippable()).size()
	amount *= _potion_heal_factor * player.potion_heal_multiplier
	match type:
		"B":
			# A new gel replaces what was left of the last one.
			_slow_heal_left = amount
			_slow_heal_rate = amount / BaseCatalog.POTION_B_SECONDS
			set_message("缓释凝胶：%.0f 秒内回复 %d 生命" % [BaseCatalog.POTION_B_SECONDS, roundi(amount)])
		"C":
			player.heal(amount, true)
			run_contamination -= BaseCatalog.POTION_C_CLEANSE
			_suppress_timer = BaseCatalog.POTION_C_SUPPRESS_SECONDS
			set_message("抑制喷剂：回复 %d 生命，污染 −%d，%d 秒内累积减半" % [roundi(amount), int(BaseCatalog.POTION_C_CLEANSE), int(BaseCatalog.POTION_C_SUPPRESS_SECONDS)])
		_:
			player.heal(amount, true)
			set_message("标准急救剂：回复 %d 生命" % roundi(amount))
	save_base(true)
	return true

# --- Medical (§4) ------------------------------------------------------------

## Contamination right now: the base's, plus this contract's dose so far.
func current_contamination() -> float:
	return clampf(base.contamination + run_contamination, 0.0, BaseCatalog.CONTAMINATION_MAX)

## Contamination per second at this moment of a contract.
func contamination_rate() -> float:
	if in_base: return 0.0
	var rate := 0.0
	if region_id == "mine": rate += BaseCatalog.CONTAMINATION_MINE
	if route_index == 2: rate += BaseCatalog.CONTAMINATION_DEEP_ROUTE
	rate += count_effect("raw_ore") * BaseCatalog.CONTAMINATION_PER_ORE
	if _suppress_timer > 0.0: rate *= 0.5
	return rate * maxf(0.0, 1.0 + float(player.stats.get("contam_pct", 0.0)))

## Shown on the field HUD only when it is moving or could: the mine, the deep
## route, or ore in the pack.
func contamination_visible() -> bool:
	return not in_base and (region_id == "mine" or route_index == 2 or count_effect("raw_ore") > 0)

## At departure: injury and contamination set max HP, potion healing and
## self-regeneration for the whole contract; the pharmacy fills the belt.
## Item affixes and builds change how many flasks fit: standard flasks fill
## extra room, and losses come off the end (the bought fourth bottle first).
func _apply_medical_state() -> void:
	var tier: Array = BaseCatalog.CONTAMINATION_TIERS[base.contamination_tier()]
	player.condition_hp_penalty = base.hp_penalty()
	player.regen_blocked = bool(tier[3])
	_potion_heal_factor = 1.0 - float(tier[2])
	player._recompute_stats()
	run_contamination = 0.0
	_suppress_timer = 0.0
	_slow_heal_left = 0.0
	_announced_tier = base.contamination_tier()

func _tick_medical(delta: float) -> void:
	if _slow_heal_left > 0.0:
		var heal_step := minf(_slow_heal_left, _slow_heal_rate * delta)
		_slow_heal_left -= heal_step
		player.heal(heal_step)
	_suppress_timer = maxf(0.0, _suppress_timer - delta)
	run_contamination += contamination_rate() * delta
	var tier := BaseCatalog.contamination_tier(current_contamination())
	if tier > _announced_tier and tier > 0:
		set_message("污染升到 %d（%s）：下次出发会带减益，回基地后可在医疗部处理。" % [roundi(current_contamination()), BaseCatalog.CONTAMINATION_TIER_NAMES[tier]])
	_announced_tier = maxi(_announced_tier, tier)

## Pharmacy (药剂进背包): one flask straight into the pack for the next contract.
## 标准急救剂 are free while this contract's free issue lasts.
func buy_potion(type: String) -> bool:
	if not in_base or not BaseCatalog.POTIONS.has(type): return false
	var price := base.potion_price(type)
	if price < 0 or gold < price: return false
	var flask := BaseCatalog.create_potion(type)
	if not inventory.try_add(flask):
		set_message("背包空间不足：药剂要占一格。")
		return false
	gold -= price
	if type == "A" and price == 0: base.free_potions -= 1
	save_base()
	return true

func treat_injury() -> bool:
	if not in_base or not base.injured or gold < BaseCatalog.INJURY_TREATMENT: return false
	gold -= BaseCatalog.INJURY_TREATMENT
	base.injured = false
	save_base()
	set_message("重伤已治愈。")
	return true

## Lowers contamination to `target` for 1.5 per point (at least 10).
func decontaminate(target: int) -> bool:
	var points := ceili(base.contamination) - maxi(target, 0)
	var price := BaseCatalog.decon_price(points)
	if not in_base or points <= 0 or gold < price: return false
	gold -= price
	base.contamination = float(maxi(target, 0))
	save_base()
	set_message("污染处理完成：现在 %d（%s）。" % [maxi(target, 0), BaseCatalog.CONTAMINATION_TIER_NAMES[base.contamination_tier()]])
	return true

func _spawn_wave() -> void:
	# Ordinary enemies defend their own origin along the main route. Search
	# encounters have their own budget, so no region leaves reward spurs bare.
	# Scaled with the route: the segment is about twice the ground it used to
	# be, so holding the old budget would have thinned encounters out rather
	# than made the map feel bigger. Density stays roughly where it was.
	var profile := FieldCatalog.depth_profile(floor_number)
	var count: int = 6 + route_index * 2 + int(profile.enemies)
	var extra_elites: int = int(profile.elites)
	for i in range(count):
		var elite := (i % 3 == 2 if region_id == "snow" else i == count - 1) or (route_index == 2 and i == count - 2)
		if not elite and extra_elites > 0 and i % 3 == 1:
			elite = true
			extra_elites -= 1
		var ranged := not elite and (i % 2 == 1 if region_id == "snow" else i % 4 == 2)
		var point: Vector2 = world_map.main_path[mini(1 + i * 2, world_map.main_path.size() - 1)]
		var type := ""
		if region_id == "mine":
			elite = false
			# Three slugs share one encounter pocket; elite slots stay ordinary.
			if i % 6 in [1, 2, 3]:
				type = "slug"
				point = world_map.main_path[mini(3 + (i / 6) * 12, world_map.main_path.size() - 1)] + Vector2((i % 6 - 2) * 1.0, 0)
			elif i % 6 == 4: type = "crossbow"
		_spawn_enemy(Vector3(point.x, 0, point.y), elite, ranged, type)
	_spawn_guard_post(world_map.buff_position, "强化装置", false)
	# Every authored supply pocket pays off, including the optional loop.
	# Each is a typed point of interest (掉落物策划案 §4.1).
	var kinds := LootTables.plan_points(region_id, world_map.cache_positions.size(), rng)
	for i in range(world_map.cache_positions.size()):
		var box := LootContainer.new()
		box.game = self
		box.kind = kinds[i]
		box.guarded = route_index == 2 or (region_id == "snow" and i % 3 == 0)
		add_child(box)
		box.global_position = world_map.cache_positions[i]
		_spawn_guard_post(box.global_position, box.title(), box.guarded)

func _spawn_enemy(position: Vector3, elite: bool, ranged: bool, type: String = "") -> Enemy:
	var enemy := Enemy.new()
	add_child(enemy)
	# Asked-for positions are not always walkable — a caller offsetting from the
	# player can easily land in rock — and an enemy has no collider to stop it
	# standing there, so the spawn is pulled onto real ground first.
	enemy.global_position = world_map.nearest_walkable(position) + Vector3.UP * 0.65
	enemy.global_position.y = 0.65 # Navigation voxel height is not the actor's ground height.
	enemy.setup(self, elite, ranged, type)
	var depth := floor_number - 1
	enemy.max_health *= 1.0 + depth * EnemyAttacks.HP_PER_DEPTH + (EnemyAttacks.SNOW_HP_BONUS if region_id == "snow" else 0.0)
	enemy.max_health *= enemy_life_multiplier(player.f("enemy_hp"))
	enemy.health = enemy.max_health
	enemy.atk *= 1.0 + depth * EnemyAttacks.ATK_PER_DEPTH
	enemy.died.connect(_on_enemy_died)
	return enemy

func _spawn_guard_post(anchor: Vector3, title: String, elite_guard: bool = false) -> GuardPost:
	var post := GuardPost.new()
	post.game = self
	post.title = title
	post.position = Vector3(anchor.x, 0, anchor.z)
	add_child(post)
	var stations: Array[Vector3] = []
	# Search a ring for two separated, reachable stations around the point.
	for index in range(2):
		for probe in range(32):
			var angle := PI * index + TAU * float(probe) / 32
			var offset := Vector2.from_angle(angle) * 2.7
			var candidate := Vector3(anchor.x + offset.x, 0.65, anchor.z + offset.y)
			if not world_map._has_clearance(Vector2(candidate.x, candidate.z)): continue
			if not stations.is_empty() and candidate.distance_to(stations[0]) < 2.0: continue
			var closest := NavigationServer3D.map_get_closest_point(world_map.navigation_map_rid(), candidate)
			closest.y = candidate.y
			if closest.distance_to(candidate) > 0.5: continue
			stations.append(candidate)
			break
	for i in range(stations.size()):
		var elite := elite_guard and i == 0
		var ranged := not elite and i == 1 and region_id != "mine"
		post.add_guard(_spawn_enemy(stations[i], elite, ranged))
	return post

func _on_enemy_died(_enemy: Enemy) -> void:
	player.on_kill(_enemy)
	segment_threat += RelicCatalog.ELITE_THREAT if _enemy.elite else 1
	if not _cache_spawned and segment_threat >= RelicCatalog.CACHE_THREAT and not in_base and not _enemy in _vault_guardians:
		_cache_spawned = true
		_spawn_relic_cache(_enemy.global_position, "cache", false)
		set_message("战斗缴获：附近出现了藏品箱，靠近按 E 选择一件藏品。")
		return
	if _enemy in _vault_guardians:
		_vault_guardians.erase(_enemy)
		if _vault_guardians.is_empty():
			for node in get_tree().get_nodes_in_group("sealed_loot"):
				if node.has_method("unseal"): node.unseal()
				else: node.set("sealed", false)
			for node in get_tree().get_nodes_in_group("relic_caches"): node.set("sealed", false)
			set_message("守卫者全部倒下：密室的封印解除。")
		else: set_message("密室仍有 %d 名守卫者，宝箱尚未解封。" % _vault_guardians.size())
		return

## What the loot tables need (掉落物策划案 §3–5). The pity counters live on
## the base so they carry across contracts.
func loot_ctx() -> Dictionary:
	var reward := float(FieldCatalog.ROUTES[route_index].reward) + float(FieldCatalog.depth_profile(floor_number).reward)
	return {"region": region_id, "depth": floor_number, "reward": reward, "rng": rng, "pity": base.loot_pity}

func _roll_named_item() -> Item: return FieldCatalog.exclusive(region_id)

func spawn_enemy_drops(enemy: Enemy) -> void:
	_drop_at(enemy.global_position, LootTables.enemy_drops(enemy.enemy_type, enemy.elite, enemy.behavior == Enemy.Behavior.GUARD, loot_ctx()), 0.7)

func on_container_opened(box: LootContainer) -> void:
	var drops := LootTables.container_drops(box.kind, loot_ctx(), box.guarded)
	_drop_at(box.global_position, drops, 1.3)
	sound.play("loot")
	set_message("%s已开启：%d 份物资散落在周围。" % [box.title(), drops.size()])
	save_base(true)

## Scatters drops ({"item"} / {"gold"}) in a ring around `position`.
func _drop_at(position: Vector3, drops: Array, radius: float) -> void:
	var start := rng.randf() * TAU
	for i in range(drops.size()):
		var drop: Dictionary = drops[i]
		var loot := Loot.new()
		loot.game = self
		if drop.has("item"): loot.item = drop.item
		else:
			# The loot tables still speak in old reward units; they land as 赤金.
			var bars := Economy.bars_from_reward(float(drop.gold) * player.gold_gain_multiplier, rng)
			if bars <= 0:
				loot.free()
				continue
			loot.item = MaterialCatalog.create(Economy.GOLD_ID, bars, region_id)
		loot.pickup_delay = 0.35
		add_child(loot)
		var offset := Vector3.ZERO
		if drops.size() > 1 or radius > 1.0:
			var angle := start + TAU * i / maxf(drops.size(), 1)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * radius * rng.randf_range(0.8, 1.2)
		loot.global_position = position + offset + Vector3.UP * 0.1

## Gives `bars` 赤金 (raised by gold-gain effects such as 友谊之证) into the
## pack; what does not fit lands at her feet. Returns how many were given.
func add_gold(bars: int) -> int:
	var given := roundi(bars * player.gold_gain_multiplier)
	if given <= 0: return 0
	var left := given
	while left > 0:
		var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)), region_id if not in_base else "")
		left -= stack.quantity
		var rest := inventory.add_stack(stack)
		if rest > 0 and not in_base: _drop_at(player.global_position, [{"item": stack}], 0.8)
	set_message("获得赤金 ×%d" % given)
	return given

## 赤金 carried, pack and safe bag together.
func gold_bars() -> int:
	return inventory.count_material(Economy.GOLD_ID) + safe_bag.count_material(Economy.GOLD_ID)

## Takes `bars` 赤金, from the pack first, then the safe bag. False (and nothing
## taken) when she does not carry that many.
func spend_gold_bars(bars: int) -> bool:
	if bars <= 0: return true
	if gold_bars() < bars: return false
	var need := bars
	for container in [inventory, safe_bag]:
		for item: Item in container.items.duplicate():
			if need <= 0: break
			if item.material_id != Economy.GOLD_ID: continue
			var used := mini(need, item.quantity)
			need -= used
			if used < item.quantity: item.set_quantity(item.quantity - used)
			else: container.remove(item)
	return true

func _set_gold_bars(bars: int) -> void:
	for container in [inventory, safe_bag]:
		for item: Item in container.items.duplicate():
			if item.material_id == Economy.GOLD_ID: container.remove(item)
	var left := maxi(bars, 0)
	while left > 0:
		var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)))
		left -= stack.quantity
		if inventory.add_stack(stack) > 0: break

func save_base(active_contract: bool = false) -> void:
	if not save_enabled: return
	var loadout: Array = []
	for item in carried_items():
		var entry := item.to_data()
		entry["place"] = "safe" if safe_bag.items.has(item) else ("equipped" if player.equipped.values().has(item) else "pack")
		loadout.append(entry)
	var data := {"version": 3, "gold": gold, "base": base.to_data(), "loadout": loadout,
		"active_contract": active_contract, "settlement": settlement, "rng_state": str(rng.state), "pickup_filter": pickup_filter}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		set_message("存档写入失败：当前会话仍可继续。")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(save_path): DirAccess.copy_absolute(save_path, save_path + ".bak")
	if DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		set_message("存档替换失败，旧存档保留。")

func load_base() -> void:
	if not FileAccess.file_exists(save_path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or not int(parsed.get("version", 0)) in [1, 2, 3]:
		if FileAccess.file_exists(save_path + ".bak"):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".bak"))
		if not parsed is Dictionary or not int(parsed.get("version", 0)) in [1, 2, 3]:
			set_message("无法读取存档；原文件保留，请检查备份。")
			save_enabled = false
			return
	# Before version 3 the balance was 资金; it is 龙门币 now, ×100 (经济修订案 §3).
	gold = int(parsed.get("gold", 60)) * (1 if int(parsed.get("version", 1)) >= 3 else Economy.LMD_PER_VALUE)
	pickup_filter = clampi(int(parsed.get("pickup_filter", 0)), 0, PICKUP_FILTER_NAMES.size() - 1)
	var seen := {}
	# Version 1 kept one flat warehouse list; it goes onto the shelves, overflow to staging.
	if int(parsed.get("version", 1)) == 1: base.migrate_v1(parsed.get("stash", []), seen)
	else: base.load_data(parsed.get("base", {}), seen)
	inventory.items.clear()
	safe_bag.items.clear()
	apply_container_sizes()
	player.reset_stats()
	for data in parsed.get("loadout", []):
		var item := Item.from_data(data)
		if seen.has(item.uid): continue
		seen[item.uid] = true
		match data.get("place", "pack"):
			"equipped": player.equip(item)
			"safe": safe_bag.try_add(item)
			_: inventory.try_add(item)
	settlement.assign(parsed.get("settlement", []))
	if bool(parsed.get("active_contract", false)):
		rng.state = int(parsed.get("rng_state", "1"))
		_settled = false
		settle(false)
		set_message("检测到中断合同：按阵亡规则回收出发物品，保险结果不会反复重掷。")

func _configure_camera_and_light() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	var initial_target: Vector3 = ContinuousWorldMap.ENTRY_POSITION
	camera.global_position = initial_target + CAMERA_OFFSET
	camera.look_at(initial_target, Vector3.UP)
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = environment
	add_child(env)

func _build_player() -> void:
	player = Player.new()
	player.message_requested.connect(set_message)
	player.died.connect(_on_player_died)
	add_child(player)
	player.global_position = ContinuousWorldMap.ENTRY_POSITION

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	(ui_root if is_instance_valid(ui_root) else self).add_child(layer)
	number_layer = Control.new()
	number_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	number_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(number_layer)
	_hud = Hud.new()
	_hud.game = self
	layer.add_child(_hud)
	var base_hud := BaseHud.new()
	base_hud.game = self
	layer.add_child(base_hud)

func _build_inventory_panel() -> void:
	var layer := CanvasLayer.new()
	(ui_root if is_instance_valid(ui_root) else self).add_child(layer)
	_inventory_panel = InventoryPanel.new()
	_inventory_panel.game = self
	_inventory_panel.visible = false
	layer.add_child(_inventory_panel)
	field_panels = FieldPanels.new()
	field_panels.game = self
	layer.add_child(field_panels)

func _handle_pointer_input(pointed_enemy: Enemy) -> void:
	if _pointer_gate:
		_pointer_gate = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		player.clear_target()
		player.set_move_target(_get_pointer_ground())

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return

	# Left on an enemy locks it: she closes to her weapon's reach and attacks it
	# (Player._follow_target). One click is enough; holding keeps it.
	if is_instance_valid(pointed_enemy):
		player.lock_target(pointed_enemy)
		return

	# Left on the ground drops the lock. A blade swings at the air there (and
	# lands on an enemy in reach in front); a ranged weapon walks there instead.
	player.clear_target()
	if player.is_ranged_weapon():
		player.set_move_target(_get_pointer_ground())
		return
	player.clear_move_target()
	player.attack_direction(_get_pointer_ground() - player.global_position)

func _get_enemy_under_pointer() -> Enemy:
	var viewport := get_viewport()
	if viewport == null or not is_instance_valid(camera):
		return null
	var mouse_pos := _pointer_position if _has_pointer_position else viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = ENEMY_PICK_MASK
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Node = result.get("collider")
	if collider == null:
		return null
	return collider.get_parent() as Enemy

func _get_pointer_ground() -> Vector3:
	var viewport := get_viewport()
	if viewport == null or not is_instance_valid(camera):
		return player.global_position
	var mouse_pos := _pointer_position if _has_pointer_position else viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return player.global_position
	var t := -from.y / dir.y
	if t < 0.0:
		return player.global_position
	return from + dir * t

func _create_relic(item_name: String, modifiers: Array[ItemModifier]) -> Item:
	var item := Item.create(item_name, Item.Category.TRINKET, 1, 1, 0.0)
	item.modifiers = modifiers
	return item

func spawn_warning_area(position: Vector3, radius: float, lifetime: float) -> CombatMarker:
	var warning := CombatMarker.new()
	warning.life = lifetime
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	warning.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.render_priority = 20
	mat.albedo_color = Color(1.0, 0.03, 0.03, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.03, 0.03)
	warning.material_override = mat
	add_child(warning)
	warning.global_position = position + Vector3.UP * 0.04
	return warning

func launch_enemy_projectile(origin: Vector3, target_position: Vector3, damage: float, kind: String = "arrow", max_range: float = 12.0) -> EnemyProjectile:
	var direction := target_position - origin
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return null
	var projectile := EnemyProjectile.new()
	projectile.direction = direction.normalized()
	projectile.damage = damage
	projectile.kind = kind
	projectile.max_range = max_range
	projectile.game = self
	add_child(projectile)
	projectile.global_position = origin
	return projectile

## Where a world point shows up in the UI layer. The world may render in a
## smaller viewport that is scaled up (pixel_display.gd); the UI is not.
func screen_point(world: Vector3) -> Vector2:
	if not is_instance_valid(camera): return Vector2.ZERO
	var world_size := get_viewport().get_visible_rect().size
	var ui_viewport := number_layer.get_viewport() if is_instance_valid(number_layer) else get_viewport()
	var scale := ui_viewport.get_visible_rect().size / world_size if world_size.x > 0 else Vector2.ONE
	return camera.unproject_position(world) * scale

func set_message(text: String) -> void:
	message = text
	message_timer = 3.5

func _await_navigation_sync() -> void:
	# Let deferred geometry parsing and the navigation server both run.
	# Several physics ticks can occur before a process frame at high time scale.
	for i in range(5):
		await get_tree().physics_frame
		await get_tree().process_frame
	# Guard placement immediately queries the new mesh. Flush the queued
	# region swap instead of sampling the previous map.
	NavigationServer3D.map_force_update(world_map.navigation_map_rid())

func spawn_warning_lane(origin: Vector3, target: Vector3, lifetime: float) -> CombatMarker:
	var direction := target - origin
	direction.y = 0
	if direction.length_squared() < 0.01: return null
	var marker := CombatMarker.new()
	marker.life = lifetime
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.6, 0.035, 16)
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.render_priority = 20
	material.albedo_color = Color(1, 0.03, 0.03, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	add_child(marker)
	marker.global_position = origin + direction.normalized() * 8
	marker.global_position.y = 0.05
	marker.basis = Basis.looking_at(direction.normalized())
	return marker

func line_of_sight(origin: Vector3, target: Vector3) -> bool:
	origin.y = maxf(0.7, origin.y)
	target.y = maxf(0.7, target.y)
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
