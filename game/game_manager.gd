class_name GameManager
extends Node3D

## Authoritative contract state, containers, build choices, settlement and base saves.
## Whole systems live in RefCounted Gm* modules held as members (cam, saves,
## look, pointer, medical, map_features, routes, traders, camp_shop,
## facilities); the forwarders and properties here keep their old names.

const CAMERA_OFFSET := Vector3(0.0, 16.0, -10.0)
const CAMERA_FOLLOW_SPEED := 10.0
## The follow camera can be zoomed and turned round her (用户 2026-10-20, after
## Grim Dawn): the wheel zooms between the limits, a key turns it 45°, the
## middle button dragged turns it freely, one key brings back the default
## view. The tilt goes from 50° to 70° (用户 2026-10-20: 有限俯角), a key a
## step or the middle button dragged up and down; the sprites, drawn for 58°,
## are kept on their feet at any of it (GmCamera._keep_sprites_upright).
const CAMERA_PITCH := 1.0121970114513341  # atan2(16, 10), the 58° the art is drawn for
const CAMERA_PITCH_MIN := deg_to_rad(50.0)
const CAMERA_PITCH_MAX := deg_to_rad(70.0)
const CAMERA_TILT_STEP := deg_to_rad(5.0)
const CAMERA_SIZE := 24.0
const CAMERA_SIZE_MIN := 14.0
const CAMERA_SIZE_MAX := 32.0
const CAMERA_ZOOM_STEP := 2.0
const CAMERA_TURN_STEP := PI / 4.0
const CAMERA_DRAG_TURN := 0.012  # radians per world-viewport pixel
const CAMERA_EASE := 12.0
const ENEMY_PICK_MASK := 4  # matches Enemy.PICK_LAYER

@export var fixed_map_seed: int = 0

## Setting it moves the floor-bound numbers along (复利数值改造清单 A, E): the
## physical K and the relic texts' 档位系数.
var floor_number: int = 1:
	set(value):
		floor_number = value
		CombatStats.physical_k = Scaling.physical_k(value)
		RelicCatalog.set_floor(value)
## Flasks are pack items that stack (药剂进背包, 用户 2026-10-05 / 10-17): this is
## how many she carries, pack and safe bag. Setting it replaces them with that
## many 标准急救剂 in the pack (tests and debug use).
var potions: int:
	get: return potion_count()
	set(value): medical._set_standard_potions(value)
## The AI driver's flask (GmMedical._use_potion): the first of these she carries.
const POTION_ORDER := ["A", "B", "C"]
## The 特供 and regional flasks' timers and side effects (药剂与商人界面策划案 §2–§3).
var potion_fx := PotionEffects.new()
## 地图特色 on this contract (地图特色策划案_v1_0.md): 源石污染, 血债, 寒冷.
var features := FeatureMeter.new()
## Contamination taken on this contract so far (§4.1); it is the 地图特色 meter's.
var run_contamination: float:
	get: return float(features.values.contamination)
	set(v): features.values.contamination = v
## Flasks, contamination and the pharmacy (GmMedical).
var medical := GmMedical.new(self)
var _slow_heal_left: float:
	get: return medical._slow_heal_left
	set(value): medical._slow_heal_left = value
var _slow_heal_rate: float:
	get: return medical._slow_heal_rate
	set(value): medical._slow_heal_rate = value
var _suppress_timer: float:
	get: return medical._suppress_timer
	set(value): medical._suppress_timer = value
var _potion_heal_factor: float:
	get: return medical._potion_heal_factor
	set(value): medical._potion_heal_factor = value
var _auto_drinking: bool:
	get: return medical._auto_drinking
	set(value): medical._auto_drinking = value
var _auto_potion_gap: float:
	get: return medical._auto_potion_gap
	set(value): medical._auto_potion_gap = value
const AUTO_POTION_GAP := GmMedical.AUTO_POTION_GAP
var _announced_tier: int:
	get: return medical._announced_tier
	set(value): medical._announced_tier = value
## 龙门币, the account balance (经济修订案: the only out-of-run money).
var gold: int = Economy.STARTING_LMD
var message: String = ""
var message_timer: float = 5.0

var inventory := ItemContainer.new(10, 6)
var safe_bag := ItemContainer.new(2, 2)
## Everything stored at the base: the warehouse shelves, the PRTS mail, the
## insurance on its way back.
var base := BaseState.new()
## The exchange (势力与交易所策划案_v0_7.md): the live market, the Doctor's
## account and 加工部. The market keeps its own file next to the save.
var market := MarketState.new()
var exchange := Exchange.new()
var workshop := Workshop.new()
## 科研部 (龙门币平衡与科研部策划案_v1_1.md §5); its state is on base.research.
var research := Research.new(self)
## Rhodes Island on Terra: voyages, medical stays, bulk orders (沙盘航行策划案_v1_0.md).
var voyage := VoyageState.new()
## 可露希尔's 代售 (交易所交易包修订案 §5).
var consign := Consignment.new()
## 农业部 and 食堂 on the second deck (势力特供策划案_v0_2 §三–§六); state on base.farm.
var provisions := Provisions.new(self)
## The 补给 eaten for this contract ("" none), and how many services this
## floor's Rhodes squad has given.
var run_meal := ""
var squad_uses := 0
## The floor a 残党向导 was used on (−1 none): its vault and trace show on the map.
var guide_floor := -1
## Which deck of the base she is on (1 the hall's, 2 the farm's and canteen's).
var deck := 1
## Tests fix the market's dice; 0 rolls them.
var fixed_market_seed := 0
var _market_save_left := 60.0
var _workshop_check := 0.0
const MARKET_SAVE_SECONDS := 60.0
## A black swan's headline, shown at the base until it is closed (§5.5: 弹窗).
var swan_popup := ""
## The warehouse proper: personal storage on the shelves, and what its 整理箱
## hold (整理箱与收藏品策划案 v0.2 §2.1). A copy: move items through BaseState.
var stash: Array[Item]:
	get: return base.stock()

var player: Player
var world_map: ContinuousWorldMap
## The floor's weather drawn on the ground (FieldWeather; a child of world_map).
var field_weather: FieldWeather
## The full-screen status look (StatusPost).
var status_post: StatusPost
## The buff / debuff rings on her and the enemies (StatusRings).
var status_rings: StatusRings
const VAULT_GRIT := preload("res://effects/vault_grit.tscn")
var base_map: BaseMap
var warehouse_view: WarehouseView
var medical_view: MedicalView
## The construction sites and the parts each facility level puts in the base.
var works: BaseWorks
var markers: BaseMarkers
var _status_bar: Label
## Where she appears on returning: the hall after extraction, the medical
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
var _vault_guardians: Array[Enemy] = []
## The outpost floor's squad (§6 B2); its routes stay shut until all of it falls.
var _outpost_squad: Array[Enemy] = []
var outpost_cleared := true
## The outpost's boss (every 20th floor) or warden (the 10th between), Boss与守卫者策划案.
var outpost_boss: Boss
## The bosses' set pieces (BossShow.of makes it on first use).
var boss_show: BossShow
## A boss floor's arena (Boss战场地策划案): gate, cover, the region's device.
var arena: BossArena
var _buff_taken: bool = false
## Who stands at this floor's encounter spot: "" / "squad" / "trader" /
## "closure" (a camp) / "post", and
## whether the squad's one service has been used (保全系统修订案 §2).
var encounter := ""
var encounter_used := false
## This squad's price multiplier, one of FieldCatalog.SQUAD_PRICE_STEPS.
var squad_mult := 1.0
var _random_extraction_available: bool = false
var _run_seed: int = 0
@export var start_at_base := true
@export var save_enabled := true:
	set(value):
		# A queued save lands before saving is switched off.
		if saves.queued and not value: _flush_queued_save()
		save_enabled = value
var save_path := "user://field_contract_v1.json":
	set(value):
		# A queued save lands in the file it was made for.
		if saves.queued and value != save_path: _flush_queued_save()
		save_path = value
## The save file, its coalesced writes and the writer lock (GmSave).
var saves := GmSave.new(self)
var menu: FieldMenu
var region_id := "mine"
var in_base := true
var transitioning := false
var modal := ""
var pressure := 0.0
## 威胁值 (ThreatMeter): fills by itself on a floor, a full meter sends a patrol.
var threat := ThreatMeter.new()
## 肉鸽路线图 (RouteMap, 肉鸽路线图策划案 v0.2): this block's map, where she
## stands on it ((-1, 0) before its first column: a camp) and the kind of the
## floor she is on.
var route_map: Dictionary = {}
var route_node := Vector2i(-1, 0)
var route_kind := "entry"
## The row walked in each column of this block so far (-1 where she started deeper).
var route_trail: Array = []
## Tests: fight floors only besides the contract's marks (RouteMap ctx.plain).
var route_plain := false
## PRTS 中继站 (不期而遇): two more columns seen for the rest of the block; the
## block's extraction on the minimap; 近卫局检查站: the block's meter 30% slower.
var route_peek := false
var route_exit_map := false
var route_threat_cut := false
## The 崇敬 goods used on entering this floor (势力声望解锁策划案 §三): id -> 1, or 2
## once 残党暗号 has turned its patrol away.
var floor_kits := {}
## 崇拜 at this floor's post: its gift is handed over once.
var post_gifted := false
const ROUTE_THREAT_CUT := 0.7
## What an event or a 临时休整 left for the next floor ("threat", "cache",
## "trace", "weak", "witness", "calm"), and what this floor was entered with.
var next_floor_mods := {}
var floor_mods := {}
## The exchange's news on this region (地区货币与地区互动事件策划案 §2): read
## when the contract starts and again on each floor, kept for the floor
## (MarketState.field_mods: {mult, add, titles}).
var market_field := {}
## 不期而遇: this floor's event settled. 临时休整: its campfire used.
var event_done := false
var campfire_used := false
## 赤金 carried in the pack and safe bag: the in-run money (经济修订案 §1).
## Setting it replaces the bars she carries (tests and debug use).
var run_gold: int:
	get: return gold_bars()
	set(value): _set_gold_bars(value)
## The floor this contract started on (1, or a camp later), for the contract reward.
var start_floor := 1
## In a camp between two floors (撤离与营地修订案): no fight, 可露希尔, extraction.
var in_camp := false
## On a 不期而遇 with no fight (用户 2026-10-24: 不期而遇无敌人的事件不加载地图):
## the floor is its card alone, then the route map, like a camp's counter.
var in_event := false
## The start point picked at the dispatch desk (0 = floor 1, else a camp).
var _pending_start_camp := 0
## The contract's objective (局内节奏与目标策划案 §6 B1), chosen at the dispatch
## desk, and its progress on this run.
var contract := {}
var _pending_contract := {}
var contract_vaults := 0
var bounty_killed := false
var _bounty: Enemy
## 寻访合同 (干员寻访策划案 §2.2): she has been reached and spoken to.
var recruit_met := false
## 运送合同 (沙盘航行策划案 §5.3): the crate is handed over, and where.
var cargo_delivered := false
var handover_node: Node3D
## Her figure on her floor, and the guard round her.
var recruit_node: Node3D
var _recruit_post: GuardPost
## 失散干员 (失散干员与主线流程策划案 v0.2 §5): the floor each of this region's
## missing operators is on this contract (rolled at the start), and the one
## standing on this floor with the squad round her.
var lost_floor := {}
var lost_node: Node3D
var lost_id := ""
var _lost_post: GuardPost
var _lost_warned := false
var _contract_announced := false
var builds: Array[String] = []
## The floor each relic was taken on (登天斧 fades from there: 藏品数值修订案 §3.1).
var relic_floors := {}
## This contract's kills by kind (normal / elite / leader / boss): kill EXP is
## paid on the spot, 作战记录 by count at settlement (精英化案 §4.2).
var run_kills := {}
## Insured gear she let go of on this contract (dropped on a floor). Whatever of
## it she does not carry out at settlement comes back like insured gear lost on
## a death (用户 2026-10-15: 只要局内没带出的都会送回).
var _insured_left_behind: Array[Item] = []
## Set ids found this contract: their other pieces drop twice as often (装备扩充 §1.1).
var run_sets_seen := {}
## The offer currently on screen. The device's offer is kept in _device_offers
## and each relic cache keeps its own, so reopening never rerolls.
var build_offers: Array[Dictionary] = []
var offer_source := "device"
var _device_offers: Array[Dictionary] = []
var _active_cache: RelicCache
var reroll_count := 0
## Ground pickup filter (装备与背包界面调研 §5.10, Grim Dawn style), set in the
## settings (用户 2026-11-02): the lowest rarity (an index on Item's ladder),
## how many prefixes, and the lowest grade every prefix must reach. Equipment
## that fails it shows no name plate until Alt is held; materials,
## exclusives, 传说 and money always pass.
const LOOT_RARITY_NAMES := ["全部", "优秀以上", "精良以上", "稀有以上", "史诗以上"]
const LOOT_PREFIX_NAMES := ["不限", "有前缀", "双前缀"]
## Grade colours as PrefixCatalog.GRADE_COLORS: green 0, blue 1, purple 2.
const LOOT_GRADE_NAMES := ["不限", "绿色以上", "蓝色以上", "紫色以上"]
var settlement: Array[Dictionary] = []
## Dice per system, so a draw in one never moves another's: the run's seed
## and its events; the floor's population (who, where, encounters, traps,
## features); drops and offers; the traders' and shops' stock; the base
## (orders, contracts, workshop, insurance, voyage, exchange); the bosses'
## moves. `rng` is left for the rest.
var rng := RandomNumberGenerator.new()
var rng_run := RandomNumberGenerator.new()
var rng_floor := RandomNumberGenerator.new()
var rng_loot := RandomNumberGenerator.new()
var rng_trade := RandomNumberGenerator.new()
var rng_base := RandomNumberGenerator.new()
var rng_combat := RandomNumberGenerator.new()
const RNG_STREAMS := ["rng", "rng_run", "rng_floor", "rng_loot", "rng_trade", "rng_base", "rng_combat"]
## How far apart the streams start from one seed (seed_rng, an older save).
const RNG_STREAM_STEP := 7919
var _settled := true
var sound: FieldAudio
var music: GameMusic
## The left button's state and the pointer's rays (GmPointer).
var pointer := GmPointer.new(self)
## The attack arrow is showing.
var attack_cursor_on := false
var _pointer_position := Vector2.ZERO
var _has_pointer_position := false
## The follow camera's rig (GmCamera): follow, pixel snap, shake, cut-away.
var cam := GmCamera.new(self)
## The camera's turn round the vertical (0 = the default view from the south)
## and its orthographic size, each easing to where the player set it.
var camera_yaw := 0.0
var camera_yaw_goal := 0.0
var camera_size_goal := CAMERA_SIZE
var camera_pitch := CAMERA_PITCH
var camera_pitch_goal := CAMERA_PITCH

## Opens or closes the base's station overview (BaseHud), remembered in the settings.
func toggle_station_panel() -> void:
	SystemScreens.set_setting("station_panel", not bool(SystemScreens.settings.get("station_panel", false)))

func _ready() -> void:
	_build_scene()
	if save_enabled: await saves.claim()
	_load_save()
	if not app_mode.is_empty():
		# Deferred: the main scene may still be adding its children.
		_open_app.call_deferred()
	elif not _resume.is_empty():
		await resume_run()
	elif start_at_base:
		show_base()
	else:
		await start_contract(region_id)
	booting = false

## Input, audio, camera, both maps, the player, the base's views and the HUD.
func _build_scene() -> void:
	# The kits load on threads while the base is built (首次构建 3.8 s → ~1 s).
	for region in ["base", "city", "siracusa", "mine", "snow"]: TerraceDressing.warm_kits(region)
	_setup_input()
	AttackCursor.apply(false)
	randomize_rng()
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
	if is_instance_valid(base_map.crew): base_map.crew.base = base
	# The warehouse's four reveal moments, one sound each (CHANGE-BRIEF: event sounds).
	if base_map.warehouse_reveal:
		var reveal := base_map.warehouse_reveal
		reveal.bank_lit.connect(func(_bank: int): sound.play("lights_on"))
		reveal.hatch_opening.connect(func(_shelf: int): sound.play("hatch"))
		reveal.shelf_rising.connect(func(_shelf: int): sound.play("shelf"))
		reveal.lights_out.connect(func(): sound.play("lights_off"))
	_build_player()
	base_map.player = player
	base_map.set_market(market)
	warehouse_view = WarehouseView.new()
	base_map.add_child(warehouse_view)
	warehouse_view.setup(self, base_map)
	medical_view = MedicalView.new()
	base_map.add_child(medical_view)
	medical_view.setup(self, base_map)
	works = BaseWorks.new()
	base_map.add_child(works)
	works.setup(self, base_map)
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

## The market, then the save (when saving is on), then the market's catch-up.
func _load_save() -> void:
	_init_market()
	if save_enabled:
		load_base()
		# A new save has no file to load: she is still the Player's default, not
		# the save's operator (Amiya on a new save).
		if player.operator_id != base.operator:
			player.set_operator(base.operator)
			refresh_look()
	_catch_up_market()

func _setup_input() -> void:
	# Every function the player can rebind (Keybinds, 用户 2026-10-10: 主键＋副键,
	# hotbar slots and dedicated skill/flask keys, mouse side buttons too).
	Keybinds.apply()
	# Esc always pauses, so the menu (and the keys page) can never be lost.
	if not InputMap.has_action("toggle_pause"):
		InputMap.add_action("toggle_pause")
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("toggle_pause", esc)

## A hotbar slot, or a content's dedicated key, was pressed: do what it holds.
func perform_hotbar_action(action: String) -> void:
	match action:
		"dash": player._dash_buffered = true
		"shadow": if player.has_skill(): player.cast_skill(_skill_aim())
		_:
			if Hotbar.ACTIONS.has(action) and Hotbar.ACTIONS[action].has("potion"): use_potion_type(Hotbar.ACTIONS[action].potion)

## The Space skill's aim (绝影, a recruit's skill): the enemy under the
## cursor, else the ground point.
func _skill_aim() -> Vector3:
	var enemy := _get_enemy_under_pointer()
	return enemy.global_position if is_instance_valid(enemy) else _get_pointer_ground()

## The field runs. A box's window does not stop it (用户 2026-10-13: 开容器时改为
## 不是暂停的): enemies keep coming while she searches, and she cannot move
## or fight until she closes it (or a hit closes it for her).
func simulation_active() -> bool:
	return not in_base and not transitioning and (modal.is_empty() or (modal == "inventory" and is_instance_valid(looting)))

## She is at a box's window: the field runs, her hands are busy.
func hands_busy() -> bool:
	return is_instance_valid(looting) or (is_instance_valid(boss_show) and boss_show.locked())

## Walking around Rhodes Island between contracts: movement only, no combat.
func base_walk_active() -> bool:
	return in_base and not transitioning and modal.is_empty()

func _input(event: InputEvent) -> void:
	# SubViewportContainer forwards positions in this viewport's coordinates.
	# Preserve event coordinates for picking, including injected/replayed input.
	if event is InputEventMouse:
		_pointer_position = event.position
		_has_pointer_position = true
	cam.drag_input(event)

## The wheel and the drag start only where no panel took the press.
func _unhandled_input(event: InputEvent) -> void:
	cam.unhandled_input(event)

func camera_control_active() -> bool:
	return simulation_active() or base_walk_active()

## One wheel notch closer (-1) or further out (1).
func zoom_camera(steps: int) -> void:
	cam.zoom(steps)

## Steeper (positive radians) or lower, within the limits.
func tilt_camera(radians: float) -> void:
	cam.tilt(radians)

## Turn to the next 45° mark on that side (1 or -1).
func turn_camera(side: int) -> void:
	cam.turn(side)

func reset_camera_view() -> void:
	cam.reset_view()

## Where the camera sits from the point it looks at, tilted and turned with the view.
func camera_offset() -> Vector3:
	return cam.offset()

## Seconds until the base next looks for insurance that is due.
var _insurance_check := 0.0
const INSURANCE_CHECK_SECONDS := 5.0

## The cave's cut-away eases over this many seconds (GmCamera.ease_cutaway).
const CUT_EASE := 0.25

func _process(delta: float) -> void:
	message_timer -= delta
	if saves.claiming: return
	if not app_mode.is_empty():
		_app_process(delta)
		return
	saves.lock_tick(delta)
	if not is_instance_valid(player):
		return
	# At home she is whole: what she wears raises her life to its full cap, and
	# the C window shows it so (用户 2026-11-04: 角色界面显示当前干员穿着装备后的数值).
	if in_base and not transitioning and player.hp < player.max_hp: player.hp = player.max_hp
	_tick_insurance_clock(delta)
	_tick_market(delta)
	# A key just taken for a hotbar slot (pause → 快捷栏) does nothing else.
	var binding_key := is_instance_valid(menu) and (menu.hotbar_capture >= 0 or menu.hotbar_capture_frame == Engine.get_process_frames())
	var pointed: Enemy = _get_enemy_under_pointer() if simulation_active() and not hands_busy() and not binding_key else null
	_update_pointer_cursor(pointed)
	if binding_key: return
	_panel_keys()
	cam.keys()
	# A hit while she searches shuts the box's window, so she can answer it.
	if is_instance_valid(looting) and (not looting.is_inside_tree() or player.hp < _loot_hp - 0.5): close_modal()
	if simulation_active() and hands_busy(): _tick_toasts(delta)
	if simulation_active() and not hands_busy(): _field_keys(pointed, delta)
	elif base_walk_active(): _base_keys()
	_update_base_prompt()
	_follow_player_view(delta)
	cam.process(delta)

## The panel keys, Esc, the PRTS terminal (base) and P's quick pack (base).
func _panel_keys() -> void:
	for entry in PANEL_KEYS:
		if Input.is_action_just_pressed(entry[0]): toggle_panel(entry[1])
	if Input.is_action_just_pressed("toggle_pause"): go_back()
	if in_base and Input.is_action_just_pressed("toggle_prts") and not get_tree().root.gui_get_focus_owner() is LineEdit:
		if modal == "station" and is_instance_valid(menu) and menu._station == "prts": close_modal()
		elif modal.is_empty() and base_walk_active(): open_station("prts")
	_announce_mail()
	if in_base and Input.is_action_just_pressed("quick_pack") and is_instance_valid(menu) and menu.quick_pack_here() and not get_tree().root.gui_get_focus_owner() is LineEdit: menu.open_quick_pack()

## The field's pointer, pickups, toasts, hotbar, potion and skill keys, E and stash.
func _field_keys(pointed: Enemy, delta: float) -> void:
	_handle_pointer_input(pointed, delta)
	_tick_pickup()
	_tick_toasts(delta)
	# The eight hotbar slots, then the dedicated keys (dash is read by Player).
	_press_hotbar(false)
	for type in POTION_ORDER:
		if Input.is_action_just_pressed("potion_" + type): use_potion_type(type)
	if Input.is_action_just_pressed("operator_skill") and player.has_skill(): player.cast_skill(_skill_aim())
	if Input.is_action_just_pressed("interact"): _interact()
	if Input.is_action_just_pressed("stash_item"): _move_last_item_to_safe_bag()

## Walking the base: the pointer, the dash slot, E, the watch widget and the station panel.
func _base_keys() -> void:
	_handle_base_pointer()
	# She dodges at the base too (用户 2026-10-23); the other slots wait for the field.
	_press_hotbar(true)
	if Input.is_action_just_pressed("interact"): _base_interact()
	if Input.is_action_just_pressed("toggle_watch") and is_instance_valid(watch_widget):
		if exchange.unlocked(): watch_widget.set_meta("on", not watch_widget.get_meta("on", false))
		else: set_message(EXCHANGE_LOCKED)
	if Input.is_action_just_pressed("toggle_stations"): toggle_station_panel()
	for entry in BaseHotkeys.STATIONS:
		if Input.is_action_just_pressed(BaseHotkeys.action(entry[0])) and base_walk_active():
			use_base_hotkey(entry[0])
			break

## The snowfall, the player glow, the field tint and the cave cut-away follow her.
func _follow_player_view(delta: float) -> void:
	# The snowfall rides above her view (TerraceDressing.weather).
	if is_instance_valid(world_map) and is_instance_valid(world_map.terrace_dressing) and is_instance_valid(world_map.terrace_dressing.weather) and world_map.terrace_dressing.weather.is_inside_tree() and is_instance_valid(player) and player.is_inside_tree():
		world_map.terrace_dressing.weather.global_position = player.global_position + Vector3(0, 11, 4).rotated(Vector3.UP, camera_yaw)
	# The floor's weather on the ground (GPU粒子特效推广策划案 §5): one per floor.
	if not in_base and is_instance_valid(world_map) and world_map.is_inside_tree() and (not is_instance_valid(field_weather) or field_weather.map != world_map):
		field_weather = FieldWeather.create(self, world_map)
	# The full-screen status look (§7 P5), made once.
	if not is_instance_valid(status_post): status_post = StatusPost.create(self)
	if not is_instance_valid(status_rings): status_rings = StatusRings.create(self)
	# The glow that follows her through the field (FieldLight).
	if is_instance_valid(player):
		RenderingServer.global_shader_parameter_set("field_player", player.global_position + Vector3.DOWN * 0.7)
		FieldLight.focus = player.global_position
		look.tint_in_field()
		cam.ease_cutaway(delta)

## The panel keys _process reads, in this order.
const PANEL_KEYS := [["toggle_inventory", "inventory"], ["toggle_operator", "training"], ["toggle_relics", "relics"], ["toggle_map", "map"], ["toggle_journal", "journal"]]

## The hotbar slots pressed this frame do what they hold (`dash_only`: the
## base's, where only a dash slot works).
func _press_hotbar(dash_only: bool) -> void:
	var slots := Hotbar.slots()
	for i in range(Hotbar.SLOTS):
		if dash_only and slots[i].action != "dash": continue
		if Input.is_action_just_pressed(Hotbar.input_of(i)): perform_hotbar_action(slots[i].action)

## Where the camera looks: the player, kept inside the base's walls while at home.
func camera_target() -> Vector3:
	if in_base and is_instance_valid(base_map) and base_map.visible:
		return base_map.clamp_camera(player.global_position, camera.size / CAMERA_SIZE if is_instance_valid(camera) else 1.0, camera_yaw, sin(CAMERA_PITCH) / sin(camera_pitch))
	if is_instance_valid(boss_show):
		var looked: Variant = boss_show.focus()
		if looked != null: return looked
	return player.global_position

## Any container channel in progress is broken off (a dodge, 用户 2026-10-10).
func cancel_channels(reason: String) -> void:
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var container := node as LootContainer
		if container != null and container.is_channeling(): container.cancel(reason)

## Pick who deploys next (base only, 阿米娅攻击动作与特效设计案 §十).
func choose_operator(id: String) -> void:
	if not in_base or not id in base.deployable(): return
	_swap_gear(player.operator_id, id)
	base.operator = id
	player.set_operator(id)
	shed_unusable_weapon()
	player._recompute_stats()
	player.hp = player.max_hp
	refresh_look()
	save_base()

## 干员独立装备修订案 v1.0: the leaving operator's set goes to her name, the
## coming one puts on her own. Rhodes standard pieces go back (they are
## issued to whoever deploys, for one contract).
func _swap_gear(from: String, to: String) -> void:
	if from == to: return
	var kept := {}
	for category in player.equipped.keys():
		var piece: Item = player.equipped[category]
		if piece == null: continue
		if GearCatalog.bound(piece): continue
		kept[category] = piece
	for category in player.equipped.keys(): player.unequip(category)
	if not kept.is_empty(): base.gear_sets[from] = kept
	else: base.gear_sets.erase(from)
	var own: Dictionary = base.gear_sets.get(to, {})
	base.gear_sets.erase(to)
	for category in own: player.equip(own[category])

## A stand-in for `id` in her own set, for the C window to read (用户
## 2026-11-04: 已解锁的可在干员界面切换查看). Not in the tree; the deployed
## operator is the Player herself.
var _view: Player
func operator_view(id: String) -> Player:
	if id == player.operator_id or not Operators.valid(id): return player
	if is_instance_valid(_view): _view.free()
	_view = Player.new()
	_view.game = self
	_view.operator_id = id
	_view.kit = OperatorKit.make(id, _view)
	for category in base.gear_of(id): _view.equipped[category] = base.gear_of(id)[category]
	_view._recompute_stats()
	_view.hp = _view.max_hp
	return _view

## Who walks the base (用户 2026-10-15: 基地里行走的人玩家可选择): the
## 基地形象 setting when it names a character with sheets, else whoever
## deploys next. In the field it is always the deployed operator.
func base_look() -> String:
	var id := str(SystemScreens.settings.get("base_look", ""))
	return id if LapplandAnimator3D.has_sheets(id) and (id == "doctor" or base.recruited(id)) else base.operator

func refresh_look() -> void:
	if not is_instance_valid(player) or base == null: return
	player.set_look(base_look() if in_base else player.operator_id)
	_place_roster()

## The operators who have joined stand about the hall (干员寻访策划案 §2.3), all
## but the one walking it; the spots run along the hall's open middle.
const ROSTER_SPOTS := [Vector2(46, -40), Vector2(82, -40), Vector2(40, -34), Vector2(88, -34), Vector2(52, -46), Vector2(76, -46), Vector2(34, -42), Vector2(94, -42)]
var _roster_figures: Node3D

func _place_roster() -> void:
	if not is_instance_valid(base_map): return
	if is_instance_valid(_roster_figures): _roster_figures.queue_free()
	_roster_figures = Node3D.new()
	_roster_figures.name = "Roster"
	base_map.add_child(_roster_figures)
	var walker := base_look()
	var k := 0
	for id in base.roster:
		if id == walker or not LapplandAnimator3D.CHARACTERS.has(id) or k >= ROSTER_SPOTS.size(): continue
		var figure := _operator_figure(id)
		_roster_figures.add_child(figure)
		figure.position = base_map.to_world(ROSTER_SPOTS[k].x, ROSTER_SPOTS[k].y, BaseMap.PLAYER_Y)
		figure.set_meta("operator", id)
		k += 1

# --- 干员养成 (精英化与加点策划案_v0_2.md) --------------------------------------

## Crafts at the training page (§3.2, PRTS recipes).
const CRAFTS := {
	"双芯片": {"materials": {"芯片组": 2, "芯片助剂": 1}},
	"技巧概要·卷2": {"materials": {"技巧概要·卷1": 3}},
	"技巧概要·卷3": {"materials": {"技巧概要·卷2": 3}},
}

func progress() -> OperatorProgress:
	return base.progress_for(player.operator_id)

## The operator the C window shows ("" for the deployed one) and her growth
## (干员独立装备修订案 §三): its points, ranks, records and promotion act on her.
var view_operator := ""
func viewed_id() -> String:
	return view_operator if Operators.valid(view_operator) and base.recruited(view_operator) else player.operator_id

func viewed_progress() -> OperatorProgress:
	return base.progress_for(viewed_id())

## Experience from a kill, paid on the spot to whoever is deployed.
func award_kill(enemy: Enemy) -> void:
	var kind := "normal"
	if enemy == _bounty: kind = "boss"
	elif enemy is Boss and (enemy as Boss).rank == "boss": kind = "region_boss"
	elif enemy.boss: kind = "leader"
	elif enemy.elite: kind = "elite"
	run_kills[kind] = int(run_kills.get(kind, 0)) + 1
	var exp := Progression.kill_exp(kind, floor_number)
	if enemy is Boss: exp = Progression.boss_exp((enemy as Boss).rank, (enemy as Boss).tier, floor_number)
	exp = roundi(exp * player.exp_gain_multiplier)
	if progress().add_exp(exp) > 0:
		player._recompute_stats()
		sound.play("charge")
	# 人事部 4/6 阶: the benched operators learn a share of it.
	var share := research.bench_share()
	if share > 0.0:
		for id in base.roster:
			if id != player.operator_id: base.progress_for(id).add_exp(roundi(exp * share))

## Feeds `count` 作战记录 of `record` to the operator the C window shows (base
## only): each costs record_price 龙门币; stops at the level cap or when the
## money runs out.
func feed_record(record: String, count: int) -> int:
	if not in_base or not Progression.RECORD_EXP.has(record): return 0
	var p := viewed_progress()
	var used := 0
	while used < count and int(base.records.get(record, 0)) > 0 and not p.at_cap():
		var exp := int(Progression.RECORD_EXP[record])
		var price := record_price(record)
		if gold < price: break
		gold -= price
		base.records[record] = int(base.records[record]) - 1
		p.add_exp(exp)
		used += 1
	if used > 0:
		player._recompute_stats()
		save_base()
	return used

## 龙门币 for one record (人事部 1 阶 and the endless line take their shares off).
func record_price(record: String) -> int:
	return ceili(int(Progression.RECORD_EXP[record]) * Progression.LMD_PER_EXP * research.feed_factor())

## The promotion's 龙门币 (人事部 5 阶: −25%).
func promotion_lmd() -> int:
	var lmd := int(viewed_progress().promotion_cost().get("lmd", 0))
	return roundi(lmd * 0.75) if base.researched("promotion_fee") else lmd

## Resetting `points` skill points at `elite` (人事部 2 阶: −50%).
func respec_price(points: int, elite: int) -> int:
	var cost := Progression.respec_cost(points, elite)
	return cost / 2 if base.researched("respec_fee") else cost

func promotion_refusal() -> String:
	var p := viewed_progress()
	var block := p.promotion_block()
	if not block.is_empty(): return block
	var cost := p.promotion_cost()
	if gold < promotion_lmd(): return "龙门币不足"
	return materials_refusal(cost.materials)

func promote_operator() -> bool:
	if not in_base or not promotion_refusal().is_empty(): return false
	var cost := viewed_progress().promotion_cost()
	gold -= promotion_lmd()
	consume_materials(cost.materials)
	viewed_progress().promote()
	player._recompute_stats()
	player.hp = player.max_hp
	save_base()
	return true

func add_attribute_point(key: String) -> bool:
	if not viewed_progress().add_attribute(key): return false
	player._recompute_stats()
	save_base(not in_base)
	return true

## One rank of a node; 专精 also takes its materials (base only).
func add_skill_rank(node_id: String) -> bool:
	var p := viewed_progress()
	var data := SkillTrees.node(viewed_id(), node_id)
	var materials := SkillTrees.rank_materials(data, p.rank(node_id))
	if not materials.is_empty() and (not in_base or not materials_refusal(materials).is_empty()): return false
	if not p.add_rank(node_id): return false
	if not materials.is_empty(): consume_materials(materials)
	player._recompute_stats()
	save_base(not in_base)
	return true

func set_transmuter(group: String, node_id: String) -> bool:
	if not viewed_progress().set_transmuter(group, node_id): return false
	save_base(not in_base)
	return true

func respec_skills() -> bool:
	var p := viewed_progress()
	var cost := respec_price(p.refundable_points(), p.elite)
	if not in_base or p.refundable_points() <= 0 or gold < cost: return false
	gold -= cost
	p.reset_skills()
	player._recompute_stats()
	save_base()
	return true

func module_refusal() -> String:
	var p := viewed_progress()
	var block := p.module_block()
	if not block.is_empty(): return block
	var cost: Dictionary = SkillTrees.MODULE_COST[p.module_level]
	if gold < int(cost.lmd): return "龙门币不足"
	return materials_refusal(cost.materials)

func upgrade_module() -> bool:
	if not in_base or not module_refusal().is_empty(): return false
	var cost: Dictionary = SkillTrees.MODULE_COST[viewed_progress().module_level]
	gold -= int(cost.lmd)
	consume_materials(cost.materials)
	viewed_progress().upgrade_module()
	player._recompute_stats()
	save_base()
	return true

func craft(recipe: String) -> bool:
	if not in_base or not CRAFTS.has(recipe): return false
	var materials: Dictionary = CRAFTS[recipe].materials
	if not materials_refusal(materials).is_empty(): return false
	consume_materials(materials)
	var made := MaterialCatalog.create(recipe, 1)
	if base.store(made).is_empty(): base.receive(made)
	save_base()
	return true

## A patch of hurting ground (装备扩充策划案 §7): fire, a fused blast.
func spawn_hazard(at: Vector3, radius: float, fuse: float, lasting: float, damage: float, kind: String, hurts_enemies: bool, source: Enemy) -> GroundHazard:
	var hazard := GroundHazard.new()
	hazard.radius = radius
	hazard.fuse = fuse
	hazard.lasting = lasting
	hazard.damage = damage
	hazard.kind = kind
	hazard.hurts_enemies = hurts_enemies
	hazard.source = source
	add_child(hazard)
	hazard.global_position = Vector3(at.x, ground_y(at), at.z)
	return hazard

## A boss's blow shakes the camera (GmCamera.start_impact_shake).
func start_impact_shake(pixels: float, frames: int) -> void:
	cam.start_impact_shake(pixels, frames)

func _physics_process(delta: float) -> void:
	if simulation_active() and is_instance_valid(player):
		fog.reveal(player.global_position)
		_announce_discoveries()
		_tick_medical(delta)
		_tick_features(delta)
		_tick_contract()
		_tick_extraction(delta)
		for trap in traps:
			if is_instance_valid(trap): trap.check(player)
		if player.hp <= 0: _on_player_died()
		else: _tick_auto_potion(delta)
	if threat_rising() and not boss_fight(): _tick_threat(delta)

func show_base() -> void:
	in_base = true
	buyback.clear()
	modal = ""
	pointer.gate = true
	player.clear_move_target()
	_inventory_panel.hide()
	menu.hide()
	base_map.set_active(true)
	apply_scene_look(true)
	show_ship()
	research.tick()
	show_research()
	base_map.set_farm(provisions)
	refresh_look()
	deck = 1
	base_map.set_deck(1)
	player.teleport(base_map.spawn_point(base_spawn))
	camera.global_position = camera_target() + camera_offset()

## What she is standing at, if anything: one of the base stations
## (WarehouseView.target_at has no spots of its own any more).
func nearby_station() -> Dictionary:
	if not in_base or not is_instance_valid(base_map): return {}
	var spot := warehouse_view.target_at(player.global_position) if is_instance_valid(warehouse_view) else {}
	if not spot.is_empty(): return spot
	return base_map.station_near(player.global_position)

func _base_interact() -> void:
	var station := nearby_station()
	if station.is_empty():
		set_message("走到发光的站点旁按 E：调度台接单、后勤柜台投保、仓管台、整备台、医疗前台。")
		return
	open_interactable(station)

## What E does at `station` (a BaseMap.interactables entry).
func open_interactable(station: Dictionary) -> void:
	match station.kind:
		"build_site": open_build_site(str(station.facility))
		"hub":
			if base.hub_built(): open_station("construction")
			else: open_build_site("hub")
		_: open_station(station.kind)

## 主基地快捷栏 (BaseHotkeys): a station's key or its slot on the bar opens it
## as E there would; a locked one only says what it waits for. True when it opened.
func use_base_hotkey(id: String) -> bool:
	if not base_walk_active() or not is_instance_valid(base_map): return false
	var refusal := BaseHotkeys.refusal(self, id)
	if not refusal.is_empty():
		set_message(refusal)
		return false
	var station := base_map.station(BaseHotkeys.station_id(self, id))
	if station.is_empty(): return false
	open_interactable(station)
	return true

## A facility's construction site: its upgrades on the spot, connected or not.
func open_build_site(facility: String) -> void:
	if not in_base or transitioning or not BaseCatalog.FACILITIES.has(facility): return
	open_modal("station")
	menu.show_build_site(facility)
	if is_instance_valid(tutorial_spotlight): tutorial_spotlight.screen_opened("build_site")

func open_station(kind: String) -> void:
	if not in_base or transitioning: return
	if kind == "personnel": story_note("personnel")
	if kind == "report" and base.report_unread:
		base.report_unread = false
		save_base()
	open_modal("station")
	menu.show_station(kind)
	if is_instance_valid(tutorial_spotlight): tutorial_spotlight.screen_opened(kind)

func _handle_base_pointer() -> void:
	pointer.base_step()

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
	# The base watch window (§6.4) and the black-swan popup (§5.5).
	watch_widget = MarketWidgets.WatchWidget.new()
	watch_widget.game = self
	watch_widget.position = Vector2(968, 52)
	watch_widget.size = Vector2(300, 160)
	watch_widget.visible = false
	layer.add_child(watch_widget)
	_swan_panel = PanelContainer.new()
	_swan_panel.add_theme_stylebox_override("panel", AK.box(Color(0.06, 0.04, 0.04, 0.95), AK.RED, 2, 16))
	_swan_panel.position = Vector2(340, 250)
	_swan_panel.custom_minimum_size = Vector2(600, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.add_child(AK.label("PRTS 快讯 · 黑天鹅", 14, AK.RED))
	_swan_label = AK.label("", 20, AK.FG)
	_swan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_swan_label)
	var close := AK.button("知道了", "blue", 14)
	close.pressed.connect(close_swan_popup)
	column.add_child(close)
	_swan_panel.add_child(column)
	_swan_panel.visible = false
	layer.add_child(_swan_panel)

var watch_widget: Control
var _swan_panel: PanelContainer
var _swan_label: Label

func _update_base_prompt() -> void:
	if not is_instance_valid(_base_prompt): return
	_base_prompt.visible = base_walk_active()
	if is_instance_valid(watch_widget): watch_widget.visible = _base_prompt.visible and watch_widget.get_meta("on", false) and exchange.unlocked()
	if is_instance_valid(_swan_panel):
		_swan_panel.visible = in_base and not transitioning and not swan_popup.is_empty() and (modal.is_empty() or modal == "station")
		_swan_label.text = swan_popup
	if is_instance_valid(_status_bar):
		_status_bar.visible = _base_prompt.visible
		_status_bar.text = base_status_text()
		_status_bar.reset_size()
		_status_bar.position = Vector2(1268 - _status_bar.size.x, 12)
	if not _base_prompt.visible: return
	# The E itself is BaseHud's (AK.draw_key_prompt), at her feet.
	var lines: Array[String] = []
	if message_timer > 0 and not message.is_empty(): lines.append(message)
	_base_prompt.text = "
".join(lines)

func start_contract(region: String, start_camp: int = 0) -> void:
	if transitioning or not in_base or not FieldCatalog.REGIONS.has(region): return
	_reset_run_state(region)
	# From an unlocked camp the contract begins in that camp (§3); the reward
	# counts the floors walked from the one after it.
	var from_camp := start_camp > 0 and base.camp_unlocked(region, start_camp)
	if from_camp: floor_number = start_camp
	start_floor = floor_number + (1 if from_camp else 0)
	var test_floor := boss_test_floor()
	if test_floor > 0:
		from_camp = false
		floor_number = test_floor
		start_floor = test_floor
	var project_paid := _take_contract(region)
	await _begin_loading()
	_kit_out_for_run()
	_announce_contract(project_paid)
	_open_route(from_camp, test_floor)
	_ready_squad()
	if from_camp:
		await _enter_camp()
		return
	_floor_dice()
	_build_world()
	_place_at_entry(test_floor)
	await _await_navigation_sync()
	_wave_dice()
	_spawn_wave()
	_floor_built()
	_end_loading()
	transitioning = false
	set_message("合同开始：%s。" % FieldCatalog.REGIONS[region_id].name)

## Leaves the base and clears everything a previous run left behind.
func _reset_run_state(region: String) -> void:
	story_note("contract")
	first_run_ore = 0
	region_id = region
	in_base = false
	buyback.clear()
	refresh_look()
	_settled = false
	transitioning = true
	close_modal()
	base_map.set_active(false)
	apply_scene_look(false)
	settlement.clear()
	builds.clear()
	relic_floors.clear()
	build_offers.clear()
	reroll_count = 0
	run_kills = {}
	_insured_left_behind.clear()
	run_sets_seen = {}
	player._recompute_stats()
	floor_number = 1
	pressure = 0
	threat.reset()
	features.reset()
	map_features._take_kits(region)
	# 纠察队 heard of the infected Rhodes treated at Chernobog (沙盘航行策划案 §4.4).
	threat.value = ThreatMeter.FULL * voyage.threat_start(region)
	_tracked_warned = -1
	route_kind = "entry"
	route_map = {}
	next_floor_mods = {}
	floor_mods = {}
	in_camp = false
	in_event = false

## Takes the pending (or first offered) contract, fixes its pay, charges the
## signed projects and rolls the run's seed. Returns the projects' cost.
func _take_contract(region: String) -> int:
	contract = _pending_contract.duplicate() if not _pending_contract.is_empty() else (contract_offers(region)[0] as Dictionary).duplicate()
	_pending_contract = {}
	# Taking it fixes the pay (v1.1 §2.2); the endless 合同报酬 line adds its share.
	contract.reward = roundi(Economy.contract_reward(contract, start_floor) * research.contract_bonus() / 10000.0) * 100
	market_field = market.field_mods(region)
	contract.reward = roundi(contract.reward * field_mult("reward") / 100.0) * 100
	_field_feature_start(region)
	# Signed projects are paid now, at this start's tier, and are on for this contract.
	var project_paid := research.charge_departure(start_floor)
	research.apply_run(true)
	_trader_met = false
	contract_vaults = 0
	bounty_killed = false
	_bounty = null
	recruit_met = false
	_roll_lost(region)
	cargo_delivered = false
	_contract_announced = false
	_run_seed = fixed_map_seed if fixed_map_seed else rng_run.randi()
	return project_paid

## Medical state, the meal, free potions and 战地补给 for this run.
func _kit_out_for_run() -> void:
	medical._apply_medical_state()
	guide_floor = -1
	_apply_meal(provisions.take_for_run())
	medical._issue_free_potions()
	if research.on("supply"):   # 课题 战地补给
		for i in range(2): inventory.add_stack(BaseCatalog.create_potion("A", Economy.tier_of(start_floor)))

## A fresh PRTS log opening with the contract, its goal and the field's state.
func _announce_contract(project_paid: int) -> void:
	prts_log.clear()
	prts_toasts.clear()
	broadcast("合同开始：%s。" % FieldCatalog.REGIONS[region_id].name)
	broadcast("合同目标：%s。" % FieldCatalog.contract_goal(contract, region_id, start_floor))
	if not field_titles().is_empty(): broadcast("PRTS 态势：" + "、".join(PackedStringArray(field_titles())))
	if project_paid > 0: broadcast("课题经费 %s 龙门币：%s。" % [Economy.format(project_paid), "、".join(base.research.run.map(func(p): return str(ResearchCatalog.PROJECTS[p][0])))])
	broadcast("PRTS：博士，%s已就位。" % Operators.info(player.operator_id).name)

## The route history's first entry; outside a camp, the first route block and
## the entry node.
func _open_route(from_camp: bool, test_floor: int) -> void:
	route_history = [{"floor": start_floor, "name": "小队营地" if from_camp else RouteMap.kind_name("entry")}]
	if not from_camp:
		_roll_route_block(RouteMap.block_of(floor_number))
		route_node = Vector2i(RouteMap.col_of(floor_number), 0)
		routes._walk_trail()
		route_kind = str(RouteMap.node_at(route_map, route_node).get("kind", "entry"))
		if test_floor > 0: route_history[0].name = RouteMap.kind_name(route_kind)

## What she carries now counts as carried in; she sets out whole, and the base saves.
func _ready_squad() -> void:
	for item in carried_items():
		item.carried_in = true
	player.hp = player.max_hp
	player.stamina = 100
	save_base(true)

## She stands at the entry (or by the test boss), the camera on her.
func _place_at_entry(test_floor: int) -> void:
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	if test_floor > 0: player.teleport(_boss_test_spot())
	camera.global_position = player.global_position + camera_offset()

## Debug builds only: DOWNFALL_BOSS_FLOOR=20 starts every contract on that
## floor, next to its boss (20, 40 …) or warden (10, 30 …). 0 when unset.
static func boss_test_floor() -> int:
	if not OS.is_debug_build(): return 0
	var n := OS.get_environment("DOWNFALL_BOSS_FLOOR").to_int()
	return n if n > 0 and n % FieldCatalog.CAMP_INTERVAL == FieldCatalog.OUTPOST_PLACE % FieldCatalog.CAMP_INTERVAL else 0

## Outside the arena gate on a boss floor; a dozen metres short of the warden
## otherwise. At the entry's height above the ground, or she sinks into it.
func _boss_test_spot() -> Vector3:
	var lift := Vector3.UP * ContinuousWorldMap.ENTRY_POSITION.y
	if world_map.arena_centre != Vector3.INF:
		return world_map.nearest_walkable(world_map.arena_entry - Vector3(0, 0, 4.0) + lift)
	var guard := world_map.route_guard_position
	var back := ContinuousWorldMap.ENTRY_POSITION - guard
	back.y = 0.0
	return world_map.nearest_walkable(Vector3(guard.x, 0.0, guard.z) + back.normalized() * 12.0 + lift)

func _clear_field() -> void:
	looting = null
	for child in get_children():
		if child is Enemy or child is GuardPost or child is Loot or child is LootContainer or child is RelicCache or child is SwordWave or child is CombatVfx or child is EnemyAttackVfx or child is EnemyProjectile or child is MeshInstance3D or child is GroundHazard:
			remove_child(child)
			child.queue_free()
	_vault_guardians.clear()
	_outpost_squad.clear()
	outpost_boss = null
	if is_instance_valid(number_layer):
		for label in number_layer.get_children(): label.queue_free()

func _build_world() -> void:
	_clear_field()
	_buff_taken = false
	_floor_relics.clear()
	witness_marked = bool(floor_mods.get("witness", false))
	vault_opened = false
	_vault_guardians.clear()
	traps.clear()
	trace_point = null
	# A blow's dust or splash still playing (BossVfx lives on the manager, not the floor).
	for fx in get_tree().get_nodes_in_group("boss_vfx"): fx.queue_free()
	fires.clear()
	shower = null
	shower_progress = -1.0
	_roll_encounter()
	# A boss floor is its arena and nothing else (Boss战场地策划案 Q5): no 坎诺特, no squad.
	var boss_floor := BossCatalog.is_boss_floor(floor_number) and is_outpost_floor()
	if boss_floor: encounter = ""
	world_map.boss_layout = boss_floor
	world_map.compact_layout = not boss_floor and bool(RouteMap.info(route_kind).get("compact", false))
	world_map.route_vault = route_kind == "vault"
	world_map.route_marks = routes._route_mark_colours()
	world_map.encounter_kind = encounter
	event_node = null
	event_done = false
	campfire_used = false
	rest_fire = null
	dire_foe = null
	_wish_posts.clear()
	_event_guards.clear()
	build_offers.clear()
	_device_offers.clear()
	_active_cache = null
	_roll_random_extraction()
	_seen_encounter = false
	_seen_exit = false
	extract_progress = -1.0
	pressure = difficulty()
	player.reset_floor_state()
	world_map.region_id = region_id
	world_map.extraction_available = is_extraction_floor()
	world_map.generate(_floor_seed(), floor_number)
	arena = null
	if world_map.boss_layout and world_map.arena_centre != Vector3.INF:
		arena = BossArena.new()
		world_map._generated_root.add_child(arena)
		arena.setup(self)
		# Its gate and cover are walls to the navigation too.
		world_map._build_navigation_mesh()
	# The fog covers this floor's own bounds (each floor rolls its size).
	fog.setup(world_map.SPINE_MIN, world_map.SPINE_MAX)
	fog.hidden = world_map.vault_hidden
	outpost_cleared = not is_outpost_floor()
	# The region (and Siracusa's weather) decides the floor's light (S3).
	apply_scene_look(false)

## Every stream from its own random start.
func randomize_rng() -> void:
	var dice := RandomNumberGenerator.new()
	dice.randomize()
	for stream in RNG_STREAMS: (get(stream) as RandomNumberGenerator).seed = dice.randi() | (dice.randi() << 32)

## One fixed seed for all (tests): `rng` takes it, each other stream its own step on.
func seed_rng(value: int) -> void:
	for i in RNG_STREAMS.size(): (get(RNG_STREAMS[i]) as RandomNumberGenerator).seed = value + i * RNG_STREAM_STEP

## Each stream's state as text, for the saves (JSON keeps no 64-bit ints).
func rng_states() -> Dictionary:
	var out := {}
	for stream in RNG_STREAMS: out[stream] = str((get(stream) as RandomNumberGenerator).state)
	return out

## Puts saved states back. An older save kept one state: `rng` takes it and
## each other stream starts from it a step on.
func set_rng_states(saved: Variant) -> void:
	if saved is Dictionary:
		for stream in RNG_STREAMS:
			if (saved as Dictionary).has(stream): (get(stream) as RandomNumberGenerator).state = int(str(saved[stream]))
		return
	var old := int(str(saved))
	rng.state = old
	for i in range(1, RNG_STREAMS.size()): (get(RNG_STREAMS[i]) as RandomNumberGenerator).seed = old + i * RNG_STREAM_STEP

func _floor_seed() -> int:
	return _run_seed + floor_number * 7919 + (104729 if in_camp else 0)

## 局内存档 (RunSave): a floor is built again from the dice it was built with.
## On entering one, the run as it stands and GameManager's dice are kept
## (`replay` empty); rebuilding a saved one, its dice are put back. The global
## dice (shuffles, a box's tilt) are fixed for the build too.
var _floor_entry := {}
## What the floor was built with, in order (RunSave.tag_floor).
var _floor_made: Array = []
## A saved run to go on with, read by load_base.
var _resume := {}

func _floor_dice(replay: Dictionary = {}) -> void:
	if replay.is_empty():
		var before: Array = field_titles()
		market_field = market.field_mods(region_id)
		# PRTS names the news working on this floor when it changes (§2.3).
		var fresh: Array = field_titles().filter(func(x): return not before.has(x))
		if not fresh.is_empty(): broadcast("PRTS 态势：" + "、".join(PackedStringArray(fresh)))
		_use_floor_kits()
		_floor_entry = {"run": RunSave.run_data(self), "base": RunSave.base_inputs(base), "rng": rng_states()}
	else: set_rng_states(replay.rng)
	_apply_field_economy()
	seed(_floor_seed())

## The 崇敬 goods for this map in the pack or safe bag: one of each is used up
## as she steps onto the floor (势力声望解锁策划案 §三; the wrong map uses none).
func _use_floor_kits() -> void:
	floor_kits = {}
	post_gifted = false
	if in_base or in_camp: return
	for id in FactionRewards.GOODS:
		if str(FactionRewards.GOODS[id][1]) != region_id: continue
		for bag in [inventory, safe_bag]:
			var held: Item = null
			for item in bag.items:
				if item.material_id == id: held = item
			if held == null: continue
			if held.quantity > 1: held.set_quantity(held.quantity - 1)
			else: bag.remove(held)
			floor_kits[id] = 1
			broadcast("PRTS：%s已使用。" % id)
			break

func floor_kit_on(id: String) -> bool:
	return floor_kits.has(id)

# --- The exchange's news in the field (地区货币策划案 §2) ---------------------------------

## This floor's multiplier for `key` (1 when nothing touches it), within 0.8–1.2.
func field_mult(key: String) -> float:
	return float(market_field.get("mult", {}).get(key, 1.0))

func field_add(key: String) -> float:
	return float(market_field.get("add", {}).get(key, 0.0))

## The headlines working on this region now (调度台, PRTS).
func field_titles() -> Array:
	return market_field.get("titles", [])

## 可露希尔's rate in the field follows the news (camp_fx); research sets the base.
func _apply_field_economy() -> void:
	research.apply_globals()
	if not in_base: Economy.closure_spread *= field_mult("camp_fx")

## The region's feature starts higher or lower (起点, feature_add).
func _field_feature_start(region: String) -> void:
	var kind := FeatureCatalog.feature_of(region)
	var amount := field_add("feature_add")
	if kind.is_empty() or amount == 0.0: return
	if amount > 0.0: features.add(kind, amount)
	else: features.reduce(kind, -amount)

## Who the news sends in (enemy:<tag>): its kinds by role. A tag above 1 swaps
## that share of picks to its kinds, below 1 rerolls that share of its own.
const FIELD_ENEMY_TAGS := {
	"family": {"normal": ["family_soldier", "family_intimidator"], "ranged": ["family_crossbow", "family_caster"], "elite": ["family_capo"]},
	"reunion": {"normal": ["thug"], "ranged": ["caster"], "elite": ["avenger"]},
	"ursus_army": {"normal": ["shield", "picket"], "ranged": ["crossbow"], "elite": ["armed"]},
}
const FIELD_SWAP := 1.0

func _field_enemy(type: String, role: String, pool: Array) -> String:
	for tag in FIELD_ENEMY_TAGS:
		var m := field_mult("enemy:" + tag)
		if m == 1.0: continue
		var kinds: Array = FIELD_ENEMY_TAGS[tag].get(role, [])
		if kinds.is_empty(): continue
		if m > 1.0 and rng_floor.randf() < (m - 1.0) * FIELD_SWAP: return str(kinds[rng_floor.randi() % kinds.size()])
		if m < 1.0 and type in kinds and rng_floor.randf() < (1.0 - m) * FIELD_SWAP: return str(pool[rng_floor.randi_range(0, pool.size() - 1)])
	return type

## A post's faction by the news (post:<faction>): the odds across them.
func _field_post_mult(posts: Array) -> float:
	if posts.is_empty(): return 1.0
	var total := 0.0
	for f in posts: total += field_mult("post:" + str(f)) * float(FactionRewards.POST_ODDS[exchange.rank(str(f))])
	return total / posts.size()

## Before the floor's enemies: navigation settles over a few frames between.
func _wave_dice(replay: Dictionary = {}) -> void:
	if replay.is_empty(): _floor_entry["wave"] = rng_states()
	else: set_rng_states(replay.wave)
	seed(_floor_seed() + 1)

func _floor_built() -> void:
	_floor_made = RunSave.tag_floor(self)
	randomize()

## 加载界面 (用户 2026-10-23: 点了就立刻切到加载界面并读条): the real game
## shows the loading screen and lets it draw before the floor is built, and the
## map's stages move its bar. Tests have no SystemScreens and build at once.
func _begin_loading() -> void:
	if not is_instance_valid(system_screens) or not system_screens.is_inside_tree(): return
	# The card shows this floor's upper or lower city before it is built.
	if region_id == "city": world_map.city_variant = ContinuousWorldMap.city_variant_of(_floor_seed())
	system_screens.begin_loading()
	world_map.progress_hook = system_screens.step_loading
	for i in range(2): await get_tree().process_frame

func _end_loading() -> void:
	world_map.progress_hook = Callable()

## The top bar's place: the region, and in Lungmen this floor's upper or lower
## city (the camps and the base have neither).
func place_name() -> String:
	var variant: String = world_map.city_variant if is_instance_valid(world_map) and not in_base and not in_camp else ""
	return FieldCatalog.place_name(region_id, variant)

## The 10th floor of each block, just before the camp, is the outpost (§6 B2).
func is_outpost_floor() -> bool:
	# The camp after it keeps its floor number; it is not the outpost again.
	return not in_camp and (floor_number - 1) % FieldCatalog.CAMP_INTERVAL + 1 == FieldCatalog.OUTPOST_PLACE

## The fixed extraction is in the camps now; a floor only ever has a random one.
func is_extraction_floor() -> bool:
	return _random_extraction_available

## The random extraction (肉鸽路线图策划案 v0.2 §6.2, 用户 2026-10-24: 4~6必刷一个
## 撤离节点): the node carrying the block's beacon has it. The first one she
## ever reaches is floor 5's (BaseState.first_extract_given, RouteMap first_exit).
func _roll_random_extraction() -> void:
	# A camp's extraction is the fixed one, not the block's beacon.
	if in_camp:
		_random_extraction_available = true
		return
	_random_extraction_available = bool(RouteMap.node_at(route_map, route_node).get("exit", false))
	if _random_extraction_available and RouteMap.block_of(floor_number) == 0: base.first_extract_given = true

func is_buff_available() -> bool: return not _buff_taken
## On a fight floor the squad comes this share as often as before the route map
## (30% -> 20%), a post half as often (40% -> 20%).
const ROUTE_SQUAD_SHARE := 2.0 / 3.0
const ROUTE_POST_SHARE := 0.5
## Who stands at this floor's encounter spot (保全系统修订案 §2).
## 坎诺特 only at 诡异行商, the squad always at 临时休整, a post always at
## 势力据点; on a fight floor the squad and a post less often than before the
## route map (肉鸽路线图策划案 v0.2 §6.3).
func _roll_encounter() -> void:
	var node := RouteMap.node_at(route_map, route_node)
	var roll := rng_floor.randf()
	encounter = ""
	match route_kind:
		"trader": encounter = "trader"
		"rest": encounter = "squad"
		"camp": encounter = "closure"
		"event", "relic": pass
		_: if roll < squad_chance() * ROUTE_SQUAD_SHARE: encounter = "squad"
	if encounter == "trader": _trader_met = true
	# A faction's post (势力与交易所策划案 §12) takes some of the empty spots.
	post_faction = ""
	var posts: Array = FactionCatalog.POSTS.get(region_id, [])
	if route_kind == "post" and not posts.is_empty():
		encounter = "post"
		post_faction = str(node.get("faction", ""))
		if not posts.has(post_faction): post_faction = posts[rng_floor.randi() % posts.size()]
	elif encounter.is_empty() and not route_kind in ["event", "relic", "trader", "rest", "camp"]:
		var chance := POST_CHANCE * ROUTE_POST_SHARE * (2.0 if posts.any(func(f): return market.post_boosted(f)) else 1.0) * _field_post_mult(posts)
		if voyage.post_boost(region_id): chance *= VoyageCatalog.POST_BOOST
		if not posts.is_empty() and rng_floor.randf() < chance:
			encounter = "post"
			post_faction = posts[rng_floor.randi() % posts.size()]
			for f in posts:
				if market.post_boosted(f): post_faction = f
	encounter_used = false
	trader_stock.clear()
	buyback.clear()
	trader_rerolls = 0
	_encounter_greeted = false
	squad_mult = FieldCatalog.SQUAD_PRICE_STEPS[rng_floor.randi() % FieldCatalog.SQUAD_PRICE_STEPS.size()]
	squad_uses = 0
	# 食堂补给 from 2: the squad's price one step lower.
	if facilities.meal_tier() >= Provisions.SQUAD_STEP_DOWN_TIER: squad_mult = snappedf(squad_mult - Provisions.SQUAD_STEP, 0.01)

## Who stands at the encounter spot, by name.
func encounter_name() -> String:
	match encounter:
		"trader": return "坎诺特"
		"post": return FactionCatalog.name_of(post_faction) + "据点"
	return "罗德岛小队"

## E in the field: the first thing in reach, in this order, takes it.
func _interact() -> void:
	if not simulation_active() or hands_busy(): return
	# 失散干员: once her squad is down, E by her is hers before any box or cache
	# the fight left at her feet.
	if _lost_nearby() and lost_guard_cleared():
		_meet_lost()
		return
	if _interact_boxes(): return
	if _vault_nearby():
		CombatVfx.spawn(self, world_map.vault_seal.wall_centre() + Vector3(0, 0.8, 0), world_map.vault_seal.inward(), "spark")
		# The wall gives: grit and dust thrown out towards her (GPU粒子特效推广策划案 §7 P4).
		var wall := world_map.vault_seal.wall_centre()
		var grit := OneShotFx.spawn(VAULT_GRIT, self, Vector3(wall.x, ground_y(wall), wall.z), 2)
		if grit != null and is_instance_valid(player):
			var out := player.global_position - wall
			out.y = 0.0
			if out.length_squared() > 0.01: grit.global_basis = Basis.looking_at(-out.normalized())
		_open_vault()
		return
	var fire := near_fire()
	if _recruit_nearby():
		_meet_recruit()
	elif _lost_nearby():
		_meet_lost()
	elif routes._event_nearby():
		routes._open_event()
	elif routes._campfire_nearby():
		routes._use_campfire()
	elif fire != null and not pack_fuels().is_empty():
		map_features._open_fuel(fire)
	elif is_instance_valid(shower) and not shower.used and near(shower):
		_start_shower()
	elif _handover_nearby():
		_hand_over_cargo()
	elif is_instance_valid(trace_point) and near(trace_point):
		_take_trace()
	elif is_instance_valid(arena) and not arena.mine_near(player.global_position).is_empty():
		arena.arm_mine(arena.mine_near(player.global_position))
	elif near(world_map.buff_device_node) and not _buff_taken:
		_offer_builds()
	elif near(world_map.encounter_node) and not encounter.is_empty() and (encounter in ["trader", "post"] or not encounter_used or squad_extras()):
		_open_encounter()
	else:
		_interact_route_gate()

## A loot box or relic cache in reach: opens it, or says why it is sealed.
## True when E was spent on one. Ground loot is taken by clicking its name
## (request_pickup), not with E.
func _interact_boxes() -> bool:
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box.game != self or player.global_position.distance_to(box.global_position) > LootContainer.REACH: continue
		if box.sealed:
			notice("%s仍被封印：先击败全部守卫者。" % box.title())
			return true
		if box.looted(): continue
		if box.begin_open():
			open_loot(box)
			return true
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game != self or not near(cache): continue
		if cache.sealed:
			notice("密室藏品仍被封印：先击败全部守卫者。" if cache.source == "vault" else "藏品仍被封印：先击败守卫。")
		else:
			open_relic_offer(cache.source, cache)
		return true
	return false

## A route exit in reach opens the route map, unless the outpost's boss still
## holds the entry or the first contract must extract by beacon.
func _interact_route_gate() -> void:
	for i in range(world_map.route_nodes.size()):
		if near(world_map.route_nodes[i]):
			if not outpost_cleared:
				notice("据点头目还在：入口封锁中。")
				return
			if first_run_lock():
				notice("PRTS：博士，首次外勤请先从撤离信标撤离。")
				return
			open_modal("route")
			menu.show_routes(i)
			return

## 密室 (密室与陷阱修订案_v1 §2.1, 用户 2026-10-17): found by eye, opened by
## breaking its 暗墙 (VaultSeal) with blows or by E at its mouth. Inside, the rare loot; on
## VAULT_GUARDED of them a guard of one elite and VAULT_GUARD_NORMALS more,
## and then the chests stay sealed until it is down.
const VAULT_GUARDED := 0.5
## On a 暗墙密室 floor (肉鸽路线图策划案 v0.2 §4.1).
const VAULT_GUARDED_ROUTE := 0.75
const VAULT_GUARD_NORMALS := 2
## 1 / 0 overrides the guard roll (tests).
var force_vault_guard := -1

## A melee swing from `from` toward `direction`: a sealed vault's wall in
## reach takes the blow. True when one landed.
func strike_vault_wall(from: Vector3, direction: Vector3) -> bool:
	var seal: VaultSeal = world_map.vault_seal if is_instance_valid(world_map) else null
	if seal == null or not seal.in_reach(from, direction): return false
	CombatVfx.spawn(self, seal.wall_centre() + Vector3(0, 0.8, 0), direction, "spark")
	if seal.strike(): _open_vault()
	return true

## At a sealed vault's mouth, where E opens it.
func _vault_nearby() -> bool:
	var seal: VaultSeal = world_map.vault_seal if not in_base and is_instance_valid(world_map) else null
	return seal != null and not vault_opened and seal.near(player.global_position)

func _open_vault() -> void:
	if vault_opened or world_map.vault_seal == null: return
	vault_opened = true
	contract_vaults += 1
	world_map.vault_seal.open()
	var guarded := rng_floor.randf() < (VAULT_GUARDED_ROUTE if route_kind == "vault" else VAULT_GUARDED) if force_vault_guard < 0 else force_vault_guard == 1
	if guarded:
		_vault_guardians.append(_spawn_enemy(world_map.vault_position, true, false))
		for i in range(VAULT_GUARD_NORMALS):
			var side := Vector3(cos(TAU * i / VAULT_GUARD_NORMALS), 0, sin(TAU * i / VAULT_GUARD_NORMALS)) * 1.6
			_vault_guardians.append(_spawn_enemy(world_map.vault_position + side, false, false))
	_spawn_relic_cache(world_map.vault_position, "vault", guarded)
	var vault_kinds := ["vault_weapon", "vault_gear", "vault_base"]
	for i in range(3):
		var chest := LootContainer.new()
		chest.game = self
		chest.kind = vault_kinds[i]
		chest.vault = true
		chest.sealed = guarded
		add_child(chest)
		chest.global_position = world_map.vault_position + Vector3(cos(TAU * i / 3.0) * 2.6, 0.0, sin(TAU * i / 3.0) * 2.6)
		if guarded: chest.add_to_group("sealed_loot")
	set_message("密室" if not guarded else "密室：守卫者 %d" % _vault_guardians.size())
	broadcast("PRTS：博士，墙后是一间密室。")

## 用户 2026-10-22: 第一次外勤必须从随机撤离点撤离，用教程限制. Until she has
## extracted once, a floor with a random extraction lets her go no deeper —
## while the guide is on, in the real game.
func first_run_lock() -> bool:
	return not base.extracted_once and is_extraction_floor() and not in_camp and is_instance_valid(system_screens) and (TutorialSpotlight.tips_on() or not TutorialCard.finished())

## 主线引导 (Story): one more of `event` (a crate opened, an order filled…).
func story_note(event: String) -> void:
	Story.note(base.story, event)

func region_open(region: String) -> bool:
	return Story.region_open(base.story, region)

func near(node: Node3D) -> bool:
	return is_instance_valid(node) and node.visible and player.global_position.distance_to(node.global_position) < 2.8

## On along line `route` of the ones leading from this node (out of a camp,
## to the first column's node `route`); the end of a block leads into its camp.
func advance(route: int) -> void:
	if in_base or transitioning or route < 0: return
	_ensure_route()
	# The end of a block of ten leads into its camp first (§1).
	if not in_camp and floor_number % FieldCatalog.CAMP_INTERVAL == 0:
		close_modal()
		await _enter_camp()
		return
	var rows := RouteMap.next_rows(route_map, route_node)
	if rows.is_empty(): return
	in_camp = false
	in_event = false
	await _advance_floor(int(rows[mini(route, rows.size() - 1)]))

## Kept for the callers outside (GmRoute).
func route_choices() -> Array: return routes.route_choices()
func _route_mults(mult: Dictionary) -> Dictionary: return routes._route_mults(mult)
func _roll_route_block(block: int) -> void: routes._roll_route_block(block)
func _ensure_route() -> void: routes._ensure_route()
func route_sight() -> int: return routes.route_sight()
func route_exit_floor() -> int: return routes.route_exit_floor()
func route_deep() -> bool: return routes.route_deep()
func event_id() -> String: return routes.event_id()
func event_options() -> Array: return routes.event_options()
func event_choose(index: int) -> bool: return routes.event_choose(index)

func _advance_floor(row: int) -> void:
	transitioning = true
	close_modal()
	route_node = Vector2i(route_node.x + 1, row)
	routes._walk_trail()
	route_kind = str(RouteMap.node_at(route_map, route_node).get("kind", "supply"))
	floor_number += 1
	threat.next_floor()
	floor_mods = next_floor_mods
	next_floor_mods = {}
	# 临时休整: the meter is not carried on (§6.4); an event's signal starts it high.
	if bool(floor_mods.get("calm", false)): threat.value = 0.0
	if floor_mods.has("threat"): threat.value = maxf(threat.value, ThreatMeter.FULL * float(floor_mods.threat))
	if route_kind == "rest": next_floor_mods["calm"] = true
	_tracked_warned = -1
	route_history.append({"floor": floor_number, "name": RouteMap.kind_name(route_kind)})
	if route_kind == "event" and not RouteEvents.fights(event_id()):
		_enter_event_room()
		return
	await _begin_loading()
	_floor_dice()
	_build_world()
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await _await_navigation_sync()
	_wave_dice()
	_spawn_wave()
	_floor_built()
	_end_loading()
	transitioning = false
	# What an event handed her that the pack had no room for lands at her feet.
	for item in routes._event_spill: drop_at_feet(item)
	routes._event_spill.clear()
	set_message("进入第 %d 层 · %s；上一层已无法返回。" % [floor_number, RouteMap.kind_name(route_kind)])
	broadcast("进入 %s · %s。" % [AK.floor_code(region_id, floor_number), RouteMap.kind_name(route_kind)])
	if is_outpost_floor(): broadcast(_outpost_line())
	if is_bounty_floor(): broadcast("悬赏目标在本层。")
	if base.researched("floor_report"):   # 情报部 3 阶
		broadcast("PRTS：本层兴趣点 %d，精英 %d。" % [world_map.cache_positions.size(), floor_enemies().filter(func(e): return e.elite).size()])

## A 不期而遇 with no fight: no map, its card at once; what the last floor left
## for the next one waits for the floor after (肉鸽路线图策划案 v0.2 §5.1).
func _enter_event_room() -> void:
	_clear_field()
	world_map._clear_generated_map()
	player.clear_move_target()
	in_event = true
	event_done = false
	event_node = null
	# The last floor's pieces are gone with it.
	traps.clear()
	fires.clear()
	shower = null
	trace_point = null
	rest_fire = null
	dire_foe = null
	_buff_taken = false
	_device_offers.clear()
	_floor_relics.clear()
	for key in floor_mods:
		if key != "calm": next_floor_mods[key] = floor_mods[key]
	transitioning = false
	save_base(true)
	open_modal("event")
	menu.show_event()
	set_message("进入第 %d 层 · %s；上一层已无法返回。" % [floor_number, RouteMap.kind_name(route_kind)])
	broadcast("进入 %s · %s。" % [AK.floor_code(region_id, floor_number), RouteMap.kind_name(route_kind)])

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
	if stored.size() < (2 if source == "echo" else 3):
		notice("本地区可选藏品不足三件：装置休眠。已有藏品跨区段保留。")
		return
	offer_source = source
	_active_cache = cache
	build_offers = stored
	open_modal("build")
	menu.show_builds()

func _roll_relics(source: String) -> Array[Dictionary]:
	# 罗德岛战术电台: one more option. 旧日回响 offers two.
	return RelicCatalog.roll_offers(region_id, builds, source, rng_loot, (2 if source == "echo" else 3) + int(player.f("radio")))

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
			relic_floors[id] = floor_number
			_floor_relics.append(id)
			if is_instance_valid(_active_cache):
				# 得偿所愿: taking one closes the other two.
				if _active_cache.source == "wish":
					for entry in _wish_posts:
						if is_instance_valid(entry[0]) and entry[0] != _active_cache: entry[0].claim()
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

## `at` is used as it is when `placed` (a spot already on walkable ground).
func _spawn_relic_cache(at: Vector3, source: String, sealed: bool, placed := false) -> RelicCache:
	var cache := RelicCache.new()
	cache.game = self
	cache.source = source
	cache.sealed = sealed
	add_child(cache)
	cache.global_position = at if placed else world_map.nearest_walkable(at)
	cache.global_position.y = ground_y(cache.global_position)
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

## 合同深入系数 (Scaling.contract_hp / contract_atk): 1 in the base.
func contract_life() -> float:
	return 1.0 if in_base else Scaling.contract_hp(Scaling.contract_floors(floor_number, start_floor))

func contract_attack() -> float:
	return 1.0 if in_base else Scaling.contract_atk(Scaling.contract_floors(floor_number, start_floor))

## Relic effects on enemy attack (开裂的束缚带 … 死仇时代的恨意).
func enemy_attack_multiplier() -> float:
	return maxf(0.3, 1.0 + player.f("enemy_atk")) if is_instance_valid(player) else 1.0

func pressure_multiplier() -> float:
	return maxf(0.1, 1.0 + float(player.stats.get("pressure_pct", 0.0)))

## The box whose window is open beside the pack (LootContainer), or null,
## and her life when it opened (a hit closes it).
var looting: LootContainer
var _loot_hp := 0.0

## E on a box: the pack opens with the box's grid beside it, and the search
## runs while it stays open (用户 2026-10-13).
func open_loot(box: LootContainer) -> void:
	if is_instance_valid(_inventory_panel): _inventory_panel.hide()
	if is_instance_valid(field_panels): field_panels.hide_all()
	looting = box
	_loot_hp = player.hp
	open_modal("inventory")
	if is_instance_valid(_inventory_panel): _inventory_panel.open()

## Everything found so far out of the box into the pack, as far as it fits.
func take_all(box: LootContainer) -> void:
	if not is_instance_valid(box): return
	var left := 0
	for item in box.storage.items.duplicate():
		if not box.storage.transfer_to(item, inventory): left += 1
	if left > 0: notice("背包空间不足，%d 件物品留在容器里。" % left)
	save_base(true)

func _stop_looting() -> void:
	if is_instance_valid(looting): looting.cancel("closed")
	looting = null

func open_modal(kind: String) -> void:
	if kind != "inventory": _stop_looting()
	modal = kind
	player.clear_move_target()
	player.clear_target()

func close_modal() -> void:
	# The terminal is the exchange and nothing else: closing it goes back to it.
	if app_mode == "exchange" and is_instance_valid(menu):
		menu.show_station("exchange")
		return
	_stop_looting()
	modal = ""
	BaseScreens.open_box = null
	pointer.gate = true
	if is_instance_valid(menu): menu.hide()
	if is_instance_valid(_inventory_panel): _inventory_panel.hide()
	if is_instance_valid(field_panels): field_panels.hide_all()
	# A 不期而遇 with no map: whatever closes leaves the route map up.
	if in_event and not transitioning and not in_base:
		modal = "route"
		if is_instance_valid(menu): menu.show_routes(0)

# --- HUD support (界面策划案 v1.1 §3) ----------------------------------------

## PRTS broadcasts, newest last: [time, text]. System events only — no combat,
## no pickups (用户 2026-10-06).
var prts_log: Array = []
var _seen_encounter := false
var _seen_exit := false
## The panels the HUD buttons and the I / C / R / M / J / Esc keys open.
const PANELS := ["inventory", "training", "relics", "map", "journal", "pause"]

## `keep`: into the PRTS inbox too (a letter's own notice is the letter itself).
func broadcast(text: String, keep := true) -> void:
	prts_log.append([Time.get_time_string_from_system(), text])
	if prts_log.size() > 40: prts_log.pop_front()
	prts_said_at = Time.get_ticks_msec()
	if not keep: return
	base.prts_history.append([Time.get_datetime_string_from_system(false, true).substr(5), text, BaseState.now()])
	if base.prts_history.size() > BaseState.HISTORY_MAX: base.prts_history.pop_front()

## When PRTS last spoke: the hall's log shows for a while after, then fades
## (用户 2026-11-04: 左下角的prts也不常驻，有消息跳出).
var prts_said_at := -100000

## What went to the PRTS mail since the last check is announced once.
func _announce_mail() -> void:
	if base.mailed.is_empty(): return
	var names: Array = base.mailed.map(func(it: Item): return it.item_name)
	base.mailed.clear()
	var shown := "、".join(names.slice(0, 3)) + ("等 %d 件" % names.size() if names.size() > 3 else "")
	broadcast("PRTS：仓库空间不足，%s已存入 PRTS 邮件。" % shown, false)

## A letter's piece into the warehouse, else the pack (PrtsScreen).
func claim_mail_item(item: Item) -> bool:
	if not in_base or not base.mail_has(item): return false
	if base.claim_mail(item):
		save_base()
		return true
	if inventory.can_take(item):
		base.take_from_mail(item)
		inventory.try_add(item)
		save_base()
		return true
	notice("仓库和背包都放不下：%s 仍在邮件里。" % item.item_name)
	return false

## Every letter's pieces that fit, into the warehouse. Returns how many.
func claim_all_mail() -> int:
	var n := 0
	for letter in base.mail.duplicate():
		for item in (letter.items as Array).duplicate():
			if base.claim_mail(item): n += 1
	if n > 0: save_base()
	if base.mail_count() > 0: notice("仓库空间不足：%d 件仍在邮件里。" % base.mail_count())
	return n

## PRTS in the field keeps only what the player must know (用户 2026-10-10:
## 局内 prts 只保留提示必要信息，如背包已满无法拾取，教程类不提示): an action
## that failed or is blocked. Each is a toast at the top centre; events go to
## the log only, and the old centre message is not drawn in the field.
var prts_toasts: Array = []
const TOAST_SECONDS := 4.0
const TOAST_MAX := 3

## A necessary notice: shown as a PRTS toast in the field, and over the pack
## while it is open (its window covers the toasts: notice_serial counts them).
var notice_serial := 0
var last_notice := ""

func notice(text: String) -> void:
	notice_serial += 1
	last_notice = text
	set_message(text)
	if in_base: return
	# The open pack shows the notice above itself; one popup, not two.
	if is_instance_valid(_inventory_panel) and _inventory_panel.visible: return
	prts_toasts.append({"text": text, "age": 0.0, "life": TOAST_SECONDS})
	while prts_toasts.size() > TOAST_MAX: prts_toasts.pop_front()

## Toasts age only while the field runs, so a menu never eats one.
func _tick_toasts(delta: float) -> void:
	for toast in prts_toasts: toast.age += delta
	prts_toasts = prts_toasts.filter(func(t): return t.age < t.life)

## Opens a panel, or closes it when it is the one open. Panels replace each
## other; anything else on screen (a shop, a choice) keeps them shut.
func toggle_panel(kind: String) -> void:
	if transitioning or not kind in PANELS: return
	# At the base only C works, opening 干员养成 over the walk (用户 2026-10-25).
	if kind != "pause" and in_base:
		if kind != "training" or app_mode != "": return
		if modal == kind: close_modal()
		elif modal.is_empty() and not get_tree().root.gui_get_focus_owner() is LineEdit: open_training()
		return
	if modal == kind:
		close_modal()
		return
	if not (modal.is_empty() or modal in PANELS or (in_event and modal in ["route", "event"])): return
	if is_instance_valid(_inventory_panel): _inventory_panel.hide()
	if is_instance_valid(field_panels): field_panels.hide_all()
	open_modal(kind)
	match kind:
		"inventory": _inventory_panel.open()
		"training":
			view_operator = ""
			menu.show_training(true)
		"pause": menu.show_pause()
		_: field_panels.open(kind)

## Esc (用户 2026-10-06): back one level — a dialog, a sub-page, a window, a
## screen — and with nothing open, the pause menu with its settings.
func go_back() -> void:
	if transitioning: return
	if is_instance_valid(tutorial_spotlight) and tutorial_spotlight.go_back(): return
	if is_instance_valid(story_card) and story_card.go_back(): return
	var focus := get_tree().root.gui_get_focus_owner()
	if focus is LineEdit:
		focus.release_focus()
		return
	if is_instance_valid(system_screens) and system_screens.go_back(): return
	if is_instance_valid(menu) and menu.close_quick_pack(): return
	if BaseScreens.close_case(): return
	match modal:
		"":
			toggle_panel("pause")
		"title":
			pass
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
		broadcast("PRTS：博士，附近发现%s。" % encounter_name())
	if not _seen_exit and is_extraction_floor() and is_instance_valid(world_map.exit_node) and fog.is_point_revealed(world_map.exit_node.position):
		_seen_exit = true
		broadcast("PRTS：博士，本层发现撤离点。")

const DEPT_COLOURS := {"工程部": Color("f5c000"), "医疗部": Color("8fc31f"), "后勤部": Color("0098dc"), "加工部": Color("e0782a")}

## The tracker's rows (orders only): open orders for this region or any, with
## how many matching units she carries.
func order_progress() -> Array:
	var rows: Array = []
	var board: OrderBoard = base.orders
	var carried: Array[Item] = []
	var carried_read := false
	for slot in range(board.slots.size()):
		var order = board.slots[slot]
		if order == null or order.state != "open": continue
		var t: Dictionary = BaseCatalog.ORDERS[order.id]
		var where := str(t.get("region", ""))
		if not where.is_empty() and where != region_id: continue
		var have := 0
		if not carried_read:
			carried = carried_items()
			carried_read = true
		for item in carried:
			if board.matches(slot, item): have += item.quantity if item.is_stackable() else 1
		var what := BaseCatalog.order_text(order.id).split("：")[1] if "：" in BaseCatalog.order_text(order.id) else BaseCatalog.order_text(order.id)
		what = what.split(" ×")[0].split("（")[0]
		rows.append({"dept": t.dept, "colour": DEPT_COLOURS.get(t.dept, Color.WHITE), "color": DEPT_COLOURS.get(t.dept, Color.WHITE), "what": what, "have": have, "need": board.remaining(slot),
			"slot": slot, "mult": t.get("mult", 1.0)})
	return rows

## What E would do right here, for the prompt near her ("" for nothing).
func interaction_prompt() -> String:
	if not simulation_active() or hands_busy(): return ""
	if _lost_nearby() and lost_guard_cleared(): return LostCatalog.name_of(lost_id)
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game == self and near(cache): return "密室藏品" if cache.source == "vault" else "战斗缴获"
	if _vault_nearby(): return "密室"
	if _recruit_nearby(): return Operators.display_name(str(contract.operator))
	if _lost_nearby(): return LostCatalog.name_of(lost_id)
	if routes._event_nearby(): return RouteEvents.info(event_id()).get("name", "不期而遇")
	if routes._campfire_nearby(): return "营火"
	if near_fire() != null and not pack_fuels().is_empty(): return "火堆"
	if is_instance_valid(shower) and not shower.used and near(shower) and shower_progress < 0.0: return "净化喷淋"
	if _handover_nearby(): return FactionCatalog.name_of(str(contract.faction))
	if is_instance_valid(trace_point) and near(trace_point): return "踪迹"
	if is_instance_valid(arena) and not arena.mine_near(player.global_position).is_empty(): return "干扰地雷"
	if near(world_map.buff_device_node) and not _buff_taken: return "强化装置"
	if near(world_map.encounter_node) and not encounter.is_empty() and (encounter in ["trader", "post"] or not encounter_used or squad_extras()):
		return encounter_name()
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
	if GearCatalog.bound(item): return "罗德岛制式"
	if service == "insure" and item.insured: return "已投保"
	if gold_bars() < squad_price(item): return "赤金不足"
	return ""

## Insures one item she carries: if she does not bring it out it comes back
## after INSURANCE_DELAY_SECONDS of real time (_queue_insured). One service per squad.
func squad_insure(item: Item) -> bool:
	if not squad_refusal(item, "insure").is_empty(): return false
	spend_gold_bars(squad_price(item))
	item.insured = true
	_use_squad()
	save_base(true)
	set_message("罗德岛小队：%s 已投保。" % item.item_name)
	return true

## Sends one item home now: it is gone from her, into the warehouse (the PRTS
## mail when it is full). An insured item keeps its insurance: it was not lost.
func squad_send_home(item: Item) -> bool:
	if not squad_refusal(item, "send").is_empty(): return false
	spend_gold_bars(squad_price(item))
	inventory.remove(item)
	safe_bag.remove(item)
	if player.equipped.get(item.category) == item: player.unequip(item.category)
	item.carried_in = false
	base.receive_to_staging(item)
	_use_squad()
	save_base(true)
	set_message("罗德岛小队：%s 已送回基地仓库。" % item.item_name)
	return true

func carried_items() -> Array[Item]:
	var items: Array[Item] = []
	var seen := {}
	for item in inventory.items + safe_bag.items + player.equipped.values():
		if item != null and not seen.has(item):
			seen[item] = true
			items.append(item)
	return items

func count_effect(effect: String) -> int:
	# carried_items' count without building it: each matching item once.
	var count := 0
	var seen := {}
	for list in [inventory.items, safe_bag.items, player.equipped.values()]:
		for item in list:
			if item != null and item.effect == effect and not seen.has(item):
				seen[item] = true
				count += 1
	return count

func _extract() -> void:
	if not in_base and not transitioning and is_extraction_floor(): settle(true)

## Seconds stood in the extraction zone so far, -1 while she is outside it.
var extract_progress := -1.0

func in_extraction_zone() -> bool:
	if not is_extraction_floor() or not is_instance_valid(world_map.exit_node) or not is_instance_valid(player): return false
	var at := world_map.exit_node.global_position
	return Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() <= FieldCatalog.EXTRACT_RADIUS

## Standing in the zone extracts after EXTRACT_SECONDS; a hit does not break it,
## stepping out starts it over.
func _tick_extraction(delta: float) -> void:
	if not in_extraction_zone():
		extract_progress = -1.0
		return
	extract_progress = maxf(extract_progress, 0.0) + delta
	if extract_progress >= FieldCatalog.EXTRACT_SECONDS:
		extract_progress = -1.0
		_extract()

func _on_player_died() -> void:
	if in_base or _settled: return
	# In a boss fight its winning pose comes first (Boss演出策划案_v0_2 §1.2).
	if BossShow.enabled and boss_fight():
		var show := BossShow.of(self)
		if show.playing == "victory": return
		show.victory(outpost_boss, func(): if not _settled: settle(false))
		return
	settle(false)

## Ends the contract (extracted or fallen): sorts what she carried, clears the
## run, pays the contract and goes home to the settlement screen.
func settle(extracted: bool) -> void:
	if _settled: return
	_settled = true
	var in_camp_before_settle := _settle_leave_field(extracted)
	# What comes back: what she brought out stays in her bags (the settlement's
	# 仓库 page puts it away); 作战记录 go to their counters, insured losses are
	# queued to come home.
	var brought_records := {}
	var still_equipped: Array[Item] = []
	# 企鹅物流 VIP 卡: a 企鹅专递单 with every way out (势力声望解锁策划案 §三).
	if extracted and FactionRewards.badge_on(self, "penguin"): base.receive(MaterialCatalog.create(SPECIAL_SLIP, 1))
	# Insurance whose time has come arrives first (保全系统修订案 §3).
	var returned := base.tick_insurance()
	var progress := contract_progress()
	_settle_open_view(extracted, in_camp_before_settle, returned)
	var on_her := carried_items()
	var new_finds := _settle_sort_carried(extracted, on_her, brought_records, still_equipped)
	_settle_insured_left(on_her)
	_settle_clear_run(extracted, brought_records)
	_settle_reset_player(still_equipped)
	var reward := _settle_contract_pay(extracted, progress)
	# 可露希尔's loan charges once a settlement; an overdue one takes the reward first (§10).
	var repaid := exchange.on_settlement(reward)
	_settle_return_home(extracted, new_finds, reward, returned, repaid)

## The field's run state goes; true when she settled from a camp.
func _settle_leave_field(extracted: bool) -> bool:
	market_field = {}
	research.apply_globals()
	# The first retreat: what was kept and what comes back (TutorialSpotlight).
	if not extracted and is_instance_valid(tutorial_spotlight): tutorial_spotlight.request("death")
	base.story.fell = not extracted
	if extracted:
		base.extracted_once = true
		if region_id != "mine": story_note("away")
	_apply_meal("")
	transitioning = true
	var in_camp_before_settle := in_camp
	in_camp = false
	in_event = false
	settlement.clear()
	music.end_run(extracted)
	return in_camp_before_settle

## The settlement screen's header; the item lists are filled by _settle_sort_carried.
func _settle_open_view(extracted: bool, in_camp_before_settle: bool, returned: Array) -> void:
	settlement_view = {"extracted": extracted, "region": region_id, "start": start_floor, "depth": floor_number,
		"pack_size": Vector2i(inventory.width, inventory.height), "pack_pages": range(inventory.page_count()).map(func(i): return inventory.page_size(i)), "safe_size": Vector2i(safe_bag.width, safe_bag.height),
		"pack": [], "safe": [], "worn": [], "reward": 0, "returned": returned.size(), "gold": 0, "orders": 0,
		"plate": camp_label(floor_number) if in_camp_before_settle else AK.floor_code(region_id, floor_number),
		"time": Time.get_time_string_from_system().left(5)}

## Gives every carried item its reason (kept, bound, insured, lost), files it in
## settlement and settlement_view, and fills `brought_records` and
## `still_equipped`. Returns how many new finds came home.
func _settle_sort_carried(extracted: bool, on_her: Array, brought_records: Dictionary, still_equipped: Array[Item]) -> int:
	var new_finds := 0
	for item in on_her:
		var where := "safe" if safe_bag.items.has(item) else ("worn" if player.equipped.values().has(item) else "pack")
		var reason := "遗失"
		# Rhodes standard gear goes back to logistics either way (制式保底修订).
		if GearCatalog.bound(item): reason = "制式收回"
		elif extracted: reason = "撤离带回"
		elif safe_bag.items.has(item): reason = "安全袋保全"
		elif item.insured: reason = "投保送回"
		var entry := {"uid": item.uid, "name": item.item_name, "reason": reason}
		var kept := reason in ["撤离带回", "安全袋保全"]
		# 仓库修订: what she brings out stays in her bags (settlement's 仓库 page
		# puts it away); only 作战记录 go to their counters.
		var stays_on_her := kept and not Progression.RECORD_EXP.has(item.material_id)
		if stays_on_her and not item.carried_in: new_finds += 1
		if stays_on_her and player.equipped.get(item.category) == item: still_equipped.append(item)
		if not stays_on_her:
			inventory.remove(item)
			safe_bag.remove(item)
		if reason == "投保送回": _queue_insured(item)
		if kept:
			# Brought out: the insurance stays for the next contract (用户 2026-10-15:
			# 投保后带出的不消保，只有被找回一次才消).
			item.carried_in = false
			# 作战记录 brought out go to 人事部's counters, not a crate (v1.1 §2.1).
			if Progression.RECORD_EXP.has(item.material_id) and not stays_on_her:
				base.add_records({item.material_id: item.quantity})
				brought_records[item.material_id] = int(brought_records.get(item.material_id, 0)) + item.quantity
		settlement.append(entry)
		var shown := {"item": item, "reason": reason, "x": item.grid_x, "y": item.grid_y, "page": inventory.page_of(item) if where == "pack" else 0, "w": item.width, "h": item.height}
		settlement_view[where].append(shown)
		if kept and item.material_id == Economy.GOLD_ID: settlement_view.gold += item.quantity
		if kept:
			for slot in range(base.orders.slots.size()):
				if base.orders.slots[slot] != null and base.orders.slots[slot].state == "open" and base.orders.matches(slot, item):
					settlement_view.orders += 1
					break
	return new_finds

## Insured gear she dropped on a floor and did not pick up again.
func _settle_insured_left(on_her: Array) -> void:
	for item in _insured_left_behind:
		if on_her.has(item) or not item.insured: continue
		_queue_insured(item)
		settlement.append({"uid": item.uid, "name": item.item_name, "reason": "投保送回"})
	_insured_left_behind.clear()

## The run's builds, kills and orders end; voyage, medical and research settle.
func _settle_clear_run(extracted: bool, brought_records: Dictionary) -> void:
	builds.clear()
	relic_floors.clear()
	build_offers.clear()
	_device_offers.clear()
	# 作战记录 are field drops now: only what came home counts (v1.1 §2.1).
	settlement_view.records = brought_records
	settlement_view.kills = run_kills.duplicate()
	run_kills = {}
	run_sets_seen = {}
	base.orders.refill(rng_base, region_id)
	# Bulk orders: crates handed over pay now; a crate lost with the pack reopens its order.
	voyage.on_settle()
	voyage.contract_done(region_id)
	base.settle_medical(not extracted, Economy.tier_of(floor_number))
	if not extracted: medical.auto_treat_after_fall()
	research.settle()
	research.apply_run(false)
	base.contract_reroll = base.researched("offer_reroll")
	# 后勤部 6 阶: the pack's finds go straight into the warehouse where it has room.
	if base.researched("auto_sort"):
		for item in inventory.items.duplicate():
			if not GearCatalog.bound(item): store_item(item, true)

## Home again she is whole: field conditions cleared, her kept gear back on.
func _settle_reset_player(still_equipped: Array[Item]) -> void:
	features.reset()
	player.cold = 0.0
	_slow_heal_left = 0.0
	_suppress_timer = 0.0
	player.condition_hp_penalty = 0.0
	player.regen_blocked = false
	player.reset_stats()
	for item in still_equipped: player.equip(item)
	player.hp = player.max_hp

## The contract's pay (0 unless extracted with the objective done), added to
## gold; the contract and its offer are used up.
func _settle_contract_pay(extracted: bool, progress: Dictionary) -> int:
	# 赤金 came home as items with everything else; the contract itself pays
	# 龙门币 for every floor travelled, and nothing on death (经济修订案 §3).
	# The pay fixed when the contract was taken, on extraction with the objective
	# done; nothing else is granted here — the field's gains are what came home
	# (v1.1 §2.1–2.2). The rare piece of a hunt dropped from the bounty itself.
	var achieved: bool = extracted and progress.get("done", false)
	var reward: int = int(contract.get("reward", 0)) if achieved else 0
	settlement_view.contract = {"goal": progress.get("goal", ""), "done": achieved, "bonus": contract_pay_text(contract) if achieved else ""}
	if achieved:
		if str(contract.type) == "recruit":
			base.recruit(str(contract.operator))
	if not contract.is_empty(): base.contract_offers.erase(region_id)
	contract = {}
	gold += reward
	settlement_view.reward = reward
	return reward

## The field is torn down and she is back at the base, with the settlement screen.
func _settle_return_home(extracted: bool, new_finds: int, reward: int, returned: Array, repaid: int) -> void:
	_clear_field()
	world_map._clear_generated_map()
	floor_number = 1
	in_base = true
	transitioning = false
	save_base()
	set_message("%s：带回 %d 件新物品。%s%s" % ["合同交付" if extracted else "罗德岛小队归来", new_finds,
		"合同报酬 %s 龙门币。" % Economy.format(reward) if reward > 0 else "", "投保物品送回 %d 件。" % returned.size() if not returned.is_empty() else ""])
	base_spawn = "arrival" if extracted else "death"
	show_base()
	var who := str(Operators.info(player.operator_id).name)
	broadcast("PRTS：博士与%s已完成撤离。" % who if extracted else "PRTS：罗德岛小队已接回博士与%s。" % who)
	if repaid > 0: broadcast("贷款逾期：合同报酬先还款 %s 龙门币。" % Economy.format(repaid))
	_tick_workshop()
	if show_settlement_screen:
		open_modal("settlement")
		menu.settle_tab = 0
		menu.show_settlement()

# --- The standalone terminal and ticker (交易终端与盯盘小窗策划案_v1_0.md) ----------

## "" (the game), "exchange" (A: the terminal, trades) or "ticker" (B: looks
## only). Set by the main scene from the command line before _ready.
var app_mode := ""
## One writer per save (§3); null in tests that do not save.
var save_lock: SaveLock = null
## Until _ready has claimed and loaded the save and shown the base (the
## loading screen stays up over it).
var booting := true
var ticker: Control = null
const MARKET_SAVE_FOLLOWED := 5.0
## How long the game waits for a terminal or ticker writer to step down.
const RELEASE_WAIT := 5.0
const TOAST_KINDS := ["alert", "warning", "liquidation", "fill", "default", "arrival", "delivery"]

func writer() -> bool:
	return save_lock == null or save_lock.holder

func save_lock_saved() -> void:
	if save_lock != null: save_lock.saved()

## Why the terminal may not trade now, "" when it may (§0-3).
func trade_block() -> String:
	if app_mode.is_empty(): return ""
	if app_mode == "ticker": return "只读"
	if not writer(): return "只读 · 游戏中" if str(save_lock.current().get("mode", "")) == "game" else "只读"
	if saves.saved_active: return "只读 · 局内"
	return ""

func _refresh_app() -> void:
	if app_mode == "exchange" and is_instance_valid(menu) and menu.visible and modal == "station": menu._refresh()
	if is_instance_valid(ticker): ticker.queue_redraw()

func _open_app() -> void:
	if is_instance_valid(_hud): _hud.hide()
	if is_instance_valid(watch_widget): watch_widget.hide()
	if app_mode == "exchange":
		open_modal("station")
		menu.show_station("exchange")
	else:
		ticker = TickerView.new()
		ticker.game = self
		var layer := CanvasLayer.new()
		layer.layer = 40
		(ui_root if is_instance_valid(ui_root) else self).add_child(layer)
		layer.add_child(ticker)

## The terminal and ticker: the market and the lock, nothing of the world.
func _app_process(delta: float) -> void:
	saves.lock_tick(delta)
	_tick_market(delta)

## A Windows notification for the account's events (§4): from the writer
## only, and from the game only while its window is not in front.
func _toast(text: String, kind: String) -> void:
	if not kind in TOAST_KINDS or not save_enabled or not writer() or DisplayServer.get_name() == "headless": return
	if app_mode.is_empty() and DisplayServer.window_is_focused(): return
	Toast.show("罗德岛交易终端", text)

## The command line that opens the terminal ("exchange") or the ticker.
static func app_args(mode: String) -> PackedStringArray:
	var args := PackedStringArray()
	if OS.has_feature("editor"): args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--" + mode])
	return args

## 用户 2026-10-24: 未解锁时，小窗也改为不可开启，提示先解锁.
const EXCHANGE_LOCKED := "先解锁交易所"

func launch_app(mode: String) -> void:
	if mode == "ticker" and not exchange.unlocked():
		set_message(EXCHANGE_LOCKED)
		return
	OS.create_process(OS.get_executable_path(), app_args(mode))

# --- The exchange (势力与交易所策划案_v0_7.md) ------------------------------------

## The faction at this floor's post, when the encounter is one.
var post_faction := ""
const POST_CHANCE := 0.4
## 整合运动残党's goods, per carried stack (a sixth of raw ore).
const CONTAMINATION_PER_DIRTY := 0.01

func market_path() -> String:
	return save_path + ".market"

func _init_market() -> void:
	market.on_news = _on_market_news
	exchange.notify = _on_exchange_notice
	var loaded := save_enabled and market.load_file(market_path())
	if not loaded: market.start(BaseState.now(), fixed_market_seed)
	exchange.setup(self, market)
	voyage.setup(self)
	consign.setup(self)
	voyage.notify = func(text: String): _on_exchange_notice(text, "voyage")
	Economy.fx = market.fx_rate()

## After a load the market catches up on the time the game was shut (用户:
## 不暂停，读档时模拟 k 线); PRTS sums up what happened meanwhile.
func _catch_up_market() -> void:
	exchange.migrate_packs()
	_migrate_trade_crates()
	var gap := BaseState.now() - market.t
	var before := exchange.account_value()
	exchange.counters.clear()
	market.advance_to(BaseState.now())
	_tick_workshop()
	facilities._tick_kitchen()
	if not research.tick().is_empty(): save_base()
	voyage.tick(BaseState.now())
	# Before the exchange is built PRTS has nothing of it to report (用户 2026-10-24).
	if gap < 600 or not exchange.unlocked(): return
	var c := exchange.counters
	var hours := gap / 3600.0
	var text := "离线 %s：挂单成交 %d，强制了结 %d，违约 %d，送达 %d，账户总值 %s%s 龙门币。" % [
		("%.1f 小时" % hours) if hours < 48 else ("%d 天" % roundi(hours / 24)), int(c.get("fill", 0)), int(c.get("liquidation", 0)),
		int(c.get("default", 0)), int(c.get("arrival", 0)) + int(c.get("delivery", 0)), "+" if exchange.account_value() >= before else "−",
		Economy.format(roundi(absf(exchange.account_value() - before)))]
	broadcast("PRTS：" + text)
	set_message(text)

func _tick_market(delta: float) -> void:
	market.advance_to(BaseState.now())
	_workshop_check -= delta
	if app_mode.is_empty() and _workshop_check <= 0.0:
		_workshop_check = 5.0
		if in_base:
			_tick_workshop()
			facilities._tick_kitchen()
		if in_base and not research.tick().is_empty(): save_base()
		var before := voyage.to_data().hash()
		voyage.tick(BaseState.now())
		if voyage.to_data().hash() != before: save_base(not in_base)
		if in_base and is_instance_valid(base_map):
			show_ship()
			show_research()
			base_map.set_farm(provisions)
	if save_enabled and writer():
		_market_save_left -= delta
		if _market_save_left <= 0.0:
			# Followed by a terminal or ticker: every few seconds (交易终端策划案 §3.2).
			_market_save_left = MARKET_SAVE_FOLLOWED if saves.followed else MARKET_SAVE_SECONDS
			market.save_file(market_path())
			save_lock_saved()

## News reaches the Doctor through PRTS: the log everywhere, a line at the base
## for flash offers, and the one popup for a black swan (§5.5).
func _on_market_news(headline: Dictionary, event: Dictionary) -> void:
	if not event.is_empty(): exchange.on_event(event, headline.get("picks", {}))
	# The market moves all the same; its news reaches her once the exchange is built (用户 2026-10-24).
	if not exchange.unlocked(): return
	var line := "PRTS 快讯：" + str(headline.title)
	broadcast(line)
	if str(headline.kind) == "swan":
		if in_base: swan_popup = str(headline.title)
		else: swan_popup = str(headline.title)  # shown when she is back
	elif in_base and str(headline.kind) == "flash": set_message(line)

## Account events (§12): in the field PRTS reports them, at the base a line.
## Price alerts are the Doctor's own and only show at the base.
func _on_exchange_notice(text: String, kind: String) -> void:
	_toast(text, kind)
	if not app_mode.is_empty(): return
	if kind == "alert" and not in_base: return
	broadcast("PRTS：" + text)
	if in_base: set_message(text)

func close_swan_popup() -> void:
	swan_popup = ""

## The Doctor's money changer at 可露希尔 (§1.3), base or camp.
func closure_convert(to_gold: bool, amount: float) -> bool:
	if not (in_base or in_camp): return false
	if not exchange.convert(to_gold, amount, true): return false
	save_base(not in_base)
	return true

## The research tree's hologram in 科研部 shows what is done and running.
func show_research() -> void:
	if is_instance_valid(base_map): base_map.set_research(base.research.done, base.research.active.map(func(e): return str(e.id)))

## The little ship on the sand table: at anchor, or along its leg.
func show_ship() -> void:
	if voyage.is_sailing(): base_map.set_ship_between(str(voyage.sailing.from), str(voyage.sailing.to), voyage.progress(BaseState.now()))
	else: base_map.set_ship_at(base.ship_at)

# --- 沙盘 (沙盘航行策划案_v1_0.md) --------------------------------------------------------

func sail(to: String, mode: String, fuel := false) -> bool:
	if not in_base or not voyage.sail(to, mode, BaseState.now(), fuel): return false
	story_note("sailed")
	show_ship()
	save_base()
	return true

func set_stay(kind: String, on: bool) -> bool:
	if not in_base or not voyage.set_stay(kind, on, BaseState.now()): return false
	save_base()
	return true

func submit_bulk(id: int) -> bool:
	if not in_base or not voyage.submit(id, BaseState.now()): return false
	save_base()
	return true

func pack_bulk(id: int) -> bool:
	if not in_base or not voyage.pack(id): return false
	save_base()
	set_message("大宗货箱已入库。")
	return true

func open_exchange() -> void:
	if not in_base or transitioning: return
	open_modal("station")
	menu.show_station("exchange")

# --- 加工部 (§2) -----------------------------------------------------------------

func workshop_refusal(output: String, count: int) -> String:
	if count <= 0 or Packs.is_pack(output) or Workshop.recipe(output).is_empty(): return "没有这个配方"
	var lost := dept_refusal("workshop")
	if not lost.is_empty(): return lost
	if workshop.busy() >= workshop_slots(): return "加工队列已满"
	var cost := Workshop.cost_of(output, count)
	var missing := materials_refusal(cost)
	if not missing.is_empty(): return missing
	if gold < int(Workshop.recipe(output).lmd) * count: return "龙门币不足"
	return ""

## Queue slots: Workshop.slots by rank, one more with 后勤部 2 阶 and one with
## the 乌萨斯 badge.
func workshop_slots() -> int:
	return Workshop.slots(base.facility_level("workshop")) + (1 if base.researched("workshop_slot") else 0) + (1 if FactionRewards.badge_on(self, "ursus") else 0)

func workshop_start(output: String, count: int) -> bool:
	if not in_base or not workshop_refusal(output, count).is_empty(): return false
	consume_materials(Workshop.cost_of(output, count))
	gold -= int(Workshop.recipe(output).lmd) * count
	workshop.start(output, count, BaseState.now(), rng_base, research.workshop_time_factor())
	save_base()
	set_message("加工部：%s ×%d 开始加工。" % [output, count])
	return true

# --- Trade packs (交易所交易包修订案 §3–§4) ----------------------------------------------

## Why `count` packs of `pack` cannot be made now ("" = they can): the queue,
## the 龙门币, and enough on the shelves (`quick`: one-key packing's picks).
func pack_refusal(pack: String, count: int, quick: bool = true) -> String:
	if not Packs.is_pack(pack) or count <= 0: return "没有这个包"
	var lost := dept_refusal("workshop")
	if not lost.is_empty(): return lost
	if workshop.busy() >= workshop_slots(): return "加工队列已满"
	if gold < Packs.PACK_LMD * count: return "龙门币不足"
	if Packs.max_packs(pack, stash, quick) < count: return "货不够"
	return ""

## One-key packing (§3.4): picks from the shelves, cheapest first, each pack
## closed by the unit that spills least; the packs queue at the 加工部.
func pack_quick(pack: String, count: int) -> bool:
	if not in_base or not pack_refusal(pack, count).is_empty(): return false
	var plan := Packs.auto_pick(pack, stash, count)
	return _pack_take(pack, int(plan.packs), plan.take)

## Packing by hand (§3.1): the chosen pieces fill packs in the order chosen;
## a pack's spill is lost, what does not fill a last pack stays on the shelf.
func pack_manual(pack: String, chosen: Array) -> bool:
	if not in_base or not Packs.is_pack(pack): return false
	var take := {}
	var made := 0
	var acc := 0
	var run: Array = []
	for item: Item in chosen:
		if not stash.has(item) or not Packs.packable(item) or FactionCatalog.category_of(item) != Packs.category_of(pack): continue
		run.append(item)
		acc += Packs.points(item)
		if acc >= Packs.face(pack):
			made += 1
			acc = 0
			for x: Item in run: take[x] = Packs.units(x)
			run.clear()
	if made <= 0 or workshop.busy() >= workshop_slots() or gold < Packs.PACK_LMD * made or not dept_refusal("workshop").is_empty(): return false
	return _pack_take(pack, made, take)

func _pack_take(pack: String, made: int, take: Dictionary) -> bool:
	if made <= 0: return false
	for item: Item in take:
		var n := int(take[item])
		if item.is_stackable() and n < item.quantity: item.set_quantity(item.quantity - n)
		else: _hand_over(item)
	gold -= Packs.PACK_LMD * made
	workshop.start(pack, made, BaseState.now(), rng_base, research.workshop_time_factor())
	save_base()
	set_message("加工部：%s ×%d 开始打包。" % [pack, made])
	return true

## Points to spend opening one `pack` now: its face and the category's leftover.
func open_points(pack: String) -> int:
	return Packs.face(pack) + int(workshop.points.get(Packs.category_of(pack), 0))

## Why `pick` cannot come out of one `pack` ("" = it can).
func unpack_refusal(pack: String, pick: Dictionary) -> String:
	if not Packs.can_open(pack): return "拆不开"
	if material_count(pack) <= 0: return "没有这个包"
	var cost := Packs.pick_cost(pack, pick)
	if cost < 0: return "清单里没有"
	if cost > open_points(pack): return "点数不足"
	return ""

## Opens one pack at the warehouse console (§4): the pick goes to the warehouse, the
## points left wait for the next pack of the category.
func unpack(pack: String, pick: Dictionary) -> bool:
	if not in_base or not unpack_refusal(pack, pick).is_empty(): return false
	var left := open_points(pack) - Packs.pick_cost(pack, pick)
	consume_materials({pack: 1})
	workshop.points[Packs.category_of(pack)] = left
	for id in pick:
		var n := int(pick[id])
		while n > 0:
			var stack := MaterialCatalog.create(id, mini(n, MaterialCatalog.stack_size(id)))
			n -= stack.quantity
			base.receive(stack)
	save_base()
	set_message("%s 已拆开，物品已入库。" % pack)
	return true

## Buys shelf entry `i` of the 代售 open here (§5): bars or 龙门币, into the
## pack (when it is full: the warehouse at the base, her feet in the field).
func consign_buy(i: int) -> bool:
	var anchor := consign.anchor_here()
	if anchor.is_empty() or not consign.buy_refusal(anchor, i).is_empty(): return false
	var entry: Dictionary = consign.goods(anchor)[i]
	var cur := Consignment.currency(anchor)
	var cost := Consignment.whole(cur, consign.buy_quote(anchor, entry), true)
	if cur == "gold":
		if not _pay_gold(cost): return false
	else:
		if gold < cost: return false
		gold -= cost
	entry.sold = true
	var item := Item.from_data(entry.item)
	if str(entry.kind) == "special":
		exchange.special_bought(item.material_id)
		item = FactionRewards.as_goods(item.material_id, item.quantity)
	if inventory.add_stack(item) > 0:
		if in_base: base.receive(item)
		else: drop_at_feet(item)
	save_base(not in_base)
	return true

## What she pays for `item` here, whole ("" when she does not take it).
func consign_offer(item: Item) -> String:
	var anchor := consign.anchor_here()
	if anchor.is_empty() or not Consignment.takes(item): return ""
	var cur := Consignment.currency(anchor)
	var paid := Consignment.whole(cur, consign.sell_quote(anchor, item), false)
	return (str(paid) if cur == "gold" else Economy.format(paid)) if paid > 0 else ""

## Sells a carried `item` through her (§5.4).
func consign_sell(item: Item) -> bool:
	var anchor := consign.anchor_here()
	if anchor.is_empty() or not Consignment.takes(item) or not (inventory.items.has(item) or safe_bag.items.has(item)): return false
	var cur := Consignment.currency(anchor)
	var paid := Consignment.whole(cur, consign.sell_quote(anchor, item), false)
	var shown := consign_offer(item)
	if paid <= 0 or not _hand_over(item): return false
	traders._record_sale("consign:" + anchor, item, paid, "lmd" if cur == "lmd" else "gold", shown)
	if cur == "lmd": gold += paid
	elif not in_base: give_gold_bars(paid)
	else:
		var left := paid
		while left > 0:
			var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)))
			left -= stack.quantity
			base.receive(stack)
	save_base(not in_base)
	return true

## The old trade crates become packs where they lie (§7.3).
func _migrate_trade_crates() -> void:
	var items: Array[Item] = base.all_items()
	items.append_array(inventory.items)
	items.append_array(safe_bag.items)
	for item in items:
		if not Packs.LEGACY.has(item.material_id): continue
		var pack := MaterialCatalog.create(str(Packs.LEGACY[item.material_id]), item.quantity)
		item.item_name = pack.item_name
		item.material_id = pack.material_id
		item.max_stack = pack.max_stack
		item.unit_value = pack.unit_value
		item.description = pack.description
		item.set_quantity(item.quantity)

## Finished jobs go into the warehouse (the PRTS mail when it is full).
func _tick_workshop() -> void:
	var done := workshop.finished(BaseState.now())
	if done.is_empty(): return
	for job in done:
		var made := {str(job.output): int(job.count)}
		for by in job.get("byproducts", {}): made[by] = int(made.get(by, 0)) + int(job.byproducts[by])
		# A Rhodes piece queued before it was issued free gives back what it cost.
		if Workshop.RETIRED_GEAR.has(str(job.output)):
			var r: Dictionary = Workshop.RETIRED_GEAR[job.output]
			made.erase(str(job.output))
			for id in r["in"]: made[id] = int(made.get(id, 0)) + int(r["in"][id]) * int(job.count)
			gold += int(r.lmd) * int(job.count)
		for id in made:
			var left := int(made[id])
			while left > 0:
				var stack := MaterialCatalog.create(id, mini(left, MaterialCatalog.stack_size(id)))
				left -= stack.quantity
				base.receive(stack)
		story_note("crafted")
		broadcast("PRTS：加工部完成 %s ×%d%s。" % [job.output, int(job.count), "，附带副产物" if not job.get("byproducts", {}).is_empty() else ""])
	if in_base: set_message("加工部完成 %d 项，已入库。" % done.size())
	save_base(not in_base)

# --- Field posts (§12) -----------------------------------------------------------

## A post buys what its faction likes, face to face (no remote fee).
func post_sell(item: Item) -> bool:
	if encounter != "post" or post_faction.is_empty() or in_base: return false
	if not (inventory.items.has(item) or safe_bag.items.has(item)): return false
	var q := exchange.quote_sell(item, post_faction, false)
	var before: Dictionary = exchange.relations.duplicate()
	if not exchange.sell_item(item, post_faction, false): return false
	# Buying it back takes back what the sale did to the market and the relations.
	var undo := {"faction": post_faction, "market": str(q.get("market", "")), "value": float(Economy.price(item)), "relations": {}}
	for f in exchange.relations:
		var delta := int(exchange.relations[f]) - int(before.get(f, 0))
		if delta != 0: undo.relations[f] = delta
	if str(q.currency) == "gold": traders._record_sale("post:" + post_faction, item, Exchange.field_bars(float(q.net)), "gold", str(Exchange.field_bars(float(q.net))), undo)
	else: traders._record_sale("post:" + post_faction, item, float(q.net), str(q.currency), Economy.format(roundi(float(q.net))), undo)
	save_base(true)
	return true

## Buying at a post (§12): paid in carried 赤金 or from the account, into the
## pack (at her feet when it is full).
## 整合运动残党's originium is "dirty" (§3): it raises contamination while carried.
func post_buy(material: String, count: int) -> bool:
	if encounter != "post" or post_faction.is_empty() or in_base or count <= 0 or exchange.cold(post_faction): return false
	var q := exchange.quote_buy(post_faction, material)
	if not q.ok: return false
	var cost := float(Exchange.field_bars(float(q.unit) * count, true)) if str(q.currency) == "gold" else float(q.unit) * count
	if str(q.currency) == "gold":
		if not spend_gold_bars(int(cost)): return false
	elif not exchange.pay(str(q.currency), cost): return false
	var left := count
	while left > 0:
		var stack := MaterialCatalog.create(material, mini(left, MaterialCatalog.stack_size(material)), region_id)
		left -= stack.quantity
		if post_faction == "reunion":
			stack.effect = "dirty"
			stack.description += " 来路不明，携带时污染缓慢上升。"
		if inventory.add_stack(stack) > 0: drop_at_feet(stack)
	exchange.add_relation(post_faction, clampi(roundi(Exchange.lmd_eq(str(q.currency), cost) / 5000.0), 1, 10))
	exchange.special_bought(material)
	save_base(true)
	return true

## 崇拜 (势力声望解锁策划案 §四): the post hands over its gift once a floor.
func _post_gift() -> void:
	if post_gifted or post_faction.is_empty() or exchange.rank(post_faction) < Exchange.RANK_AT.size() - 1: return
	var gift: Array = FactionRewards.POST_GIFT.get(post_faction, [])
	if gift.is_empty(): return
	post_gifted = true
	var stack := MaterialCatalog.create(str(gift[0]), int(gift[1]), region_id)
	if inventory.add_stack(stack) > 0: drop_at_feet(stack)
	set_message("%s送来 %s ×%d" % [FactionCatalog.name_of(post_faction), str(gift[0]), int(gift[1])])

## The post's own flask (药剂与商人界面策划案 §3): its type, or "".
func post_potion() -> String:
	return str(BaseCatalog.REGIONAL.get(post_faction, ""))

## Why it cannot be bought now ("" = it can).
func post_potion_refusal() -> String:
	var type := post_potion()
	if type.is_empty(): return "不出售"
	if exchange.cold(post_faction): return "需要关系 %s" % Exchange.rank_name(1)
	var p: Dictionary = BaseCatalog.POTIONS[type]
	if p.has("barter"):
		for id in p.barter:
			if material_count(id) < int(p.barter[id]): return "需要 %s ×%d" % [id, int(p.barter[id])]
	elif gold_bars() < int(p.bars): return "赤金不足"
	if not inventory.can_take(BaseCatalog.create_potion(type, Economy.tier_of(floor_number))): return "背包已满"
	return ""

## One of the post's flask into the pack, for 赤金 or (萨米) in trade.
func post_buy_potion() -> bool:
	if encounter != "post" or in_base or not post_potion_refusal().is_empty(): return false
	var type := post_potion()
	var p: Dictionary = BaseCatalog.POTIONS[type]
	if p.has("barter"): consume_materials(p.barter)
	elif not spend_gold_bars(int(p.bars)): return false
	inventory.add_stack(BaseCatalog.create_potion(type, Economy.tier_of(floor_number)))
	save_base(true)
	return true

func barter_count(give: Item, want: String) -> int:
	if exchange.cold(post_faction) or exchange.rank(post_faction) < FactionSpecials.rank_needed(want): return 0
	var q := exchange.quote_sell(give, post_faction, false)
	if not q.ok: return 0
	var unit := float(exchange.material_spot(post_faction, want, false)) * (1.0 + 0.08 + 0.1 * sin(float(market.barter_seed + want.hash())))
	return floori(float(q.net) / maxf(unit, 0.01))

func barter(give: Item, want: String) -> bool:
	if encounter != "post" or post_faction != "sami": return false
	var n := barter_count(give, want)
	if n <= 0 or not (inventory.items.has(give) or safe_bag.items.has(give)): return false
	_hand_over(give)
	var left := n
	while left > 0:
		var stack := MaterialCatalog.create(want, mini(left, MaterialCatalog.stack_size(want)), region_id)
		left -= stack.quantity
		if inventory.add_stack(stack) > 0:
			drop_at_feet(stack)
	exchange.add_relation("sami", 2)
	save_base(true)
	return true

## Puts an item on the ground beside her (a full pack at a barter).
func drop_at_feet(item: Item) -> void:
	_drop_at(player.global_position, [{"item": item}], 1.2)

# --- 坎诺特 and 购回 (坎诺特商店策划案; GmTrader) -------------------------------------

## 坎诺特's shop and 购回 (GmTrader).
var traders := GmTrader.new(self)
var trader_stock: Array[Dictionary]:
	get: return traders.trader_stock
	set(value): traders.trader_stock = value
var trader_rerolls: int:
	get: return traders.trader_rerolls
	set(value): traders.trader_rerolls = value
var _trader_met: bool:
	get: return traders._trader_met
	set(value): traders._trader_met = value
var _encounter_greeted: bool:
	get: return traders._encounter_greeted
	set(value): traders._encounter_greeted = value
var buyback: Dictionary:
	get: return traders.buyback
	set(value): traders.buyback = value

## Opens whoever stands at this floor's encounter spot: 可露希尔 (a camp),
## 坎诺特, a post or the squad.
func _open_encounter() -> void:
	if not _encounter_greeted:
		_encounter_greeted = true
		var bonus := roundi(player.f("node_gold"))
		if bonus > 0:
			_give_gold_bars(bonus)
			set_message("遇到%s：赤金 +%d" % [encounter_name(), bonus])
	if encounter == "post": _post_gift()
	if encounter == "closure":
		open_modal("camp")
		menu.show_camp()
	elif encounter == "trader":
		if trader_stock.is_empty(): _roll_trader_stock()
		open_modal("trader")
		menu.show_trader()
	elif encounter == "post":
		open_modal("post")
		menu.show_post()
	else:
		open_modal("squad")
		menu.show_squad()

## Kept for the callers outside (GmTrader).
func _trader_discount(price: int) -> int: return traders._trader_discount(price)
func _roll_trader_stock() -> void: traders._roll_trader_stock()
func trader_reroll_cost() -> int: return traders.trader_reroll_cost()
func trader_reroll() -> bool: return traders.trader_reroll()
func trader_buy_refusal(slot: int) -> String: return traders.trader_buy_refusal(slot)
func trader_buy(slot: int) -> bool: return traders.trader_buy(slot)
func trader_offer(item: Item) -> int: return traders.trader_offer(item)
func trader_sell(item: Item) -> bool: return traders.trader_sell(item)
func buyback_list(shop: String) -> Array: return traders.buyback_list(shop)
func buyback_refusal(shop: String, index: int) -> String: return traders.buyback_refusal(shop, index)
func buy_back(shop: String, index: int) -> bool: return traders.buy_back(shop, index)

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
## It is a small calm map of its own (用户 2026-10-31: 营地层也要有地图):
## 可露希尔 at the encounter spot (E opens her counter), the extraction beacon,
## and the route markers to the next block's first floors.
func _enter_camp() -> void:
	transitioning = true
	story_note("camp")
	in_camp = true
	in_event = false
	camp_shop._roll_camp_closure()
	broadcast("PRTS：前进据点已确认，博士。")
	player.clear_move_target()
	base.unlock_camp(region_id, floor_number)
	# The next block's map, from before its first column (§3.4).
	_roll_route_block(floor_number / FieldCatalog.CAMP_INTERVAL)
	route_node = Vector2i(-1, 0)
	features.enter_camp()
	player.cold = 0.0
	# 营地里污染照涨，升级后不涨: a flat dose for the time spent there.
	if not base.camp_upgraded:
		run_contamination += contamination_rate() * FieldCatalog.CAMP_EXPOSURE_SECONDS
	# Calm: the meter is not carried in, and not into the next block's first floor.
	threat.value = 0.0
	floor_mods = {}
	await _build_camp()
	save_base(true)
	set_message("抵达营地 %d|%d。" % [floor_number, floor_number + 1])
	broadcast("抵达营地 %d|%d。" % [floor_number, floor_number + 1])

## The camp's map, on arrival or when a run saved in a camp is picked up again.
func _build_camp() -> void:
	route_kind = "camp"
	await _begin_loading()
	_floor_dice()
	_build_world()
	# Safe ground, mapped from the start.
	fog.reveal_all()
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	camera.global_position = player.global_position + camera_offset()
	await _await_navigation_sync()
	_wave_dice()
	_spawn_wave()
	_floor_built()
	_end_loading()
	transitioning = false

## Extract from the camp (the fixed extraction).
func camp_extract() -> void:
	if in_camp and not transitioning: settle(true)

## On from the camp: the next block's map to pick its first floor from, or
## straight on when it has only one.
func leave_camp() -> void:
	if not in_camp or transitioning: return
	if route_choices().size() <= 1:
		await advance(0)
		return
	open_modal("route")
	menu.show_routes(0)

## The route map's back button: on a map-less 不期而遇, back to its card while
## it is undecided; anywhere else the map just closes.
func close_routes() -> void:
	if in_event:
		if not event_done:
			open_modal("event")
			menu.show_event()
	else: close_modal()

## 可露希尔's counter in the camps and at the base (GmCamp).
var camp_shop := GmCamp.new(self)
var camp_closure_stock: Dictionary:
	get: return camp_shop.camp_closure_stock
	set(value): camp_shop.camp_closure_stock = value

## Kept for the callers outside (GmCamp).
func camp_label(depth: int) -> String: return camp_shop.camp_label(depth)
func gold_available() -> int: return camp_shop.gold_available()
func _pay_gold(bars: int) -> bool: return camp_shop._pay_gold(bars)
func closure_potion_price(type: String) -> int: return camp_shop.closure_potion_price(type)
func _closure_lmd(type: String) -> float: return camp_shop._closure_lmd(type)
func closure_goods() -> Array: return camp_shop.closure_goods()
func closure_stock_left(type: String) -> int: return camp_shop.closure_stock_left(type)
func closure_potion_tier() -> int: return camp_shop.closure_potion_tier()
func closure_potion_bundle(type: String) -> int: return camp_shop.closure_potion_bundle(type)
func closure_buy_potion(type: String) -> bool: return camp_shop.closure_buy_potion(type)
func deposit_fee(item: Item) -> int: return camp_shop.deposit_fee(item)
func deposit_refusal(item: Item) -> String: return camp_shop.deposit_refusal(item)
func deposit_item(item: Item) -> bool: return camp_shop.deposit_item(item)
func sell_gold_bars(bars: int) -> bool: return camp_shop.sell_gold_bars(bars)
func camp_upgrade_refusal() -> String: return camp_shop.camp_upgrade_refusal()
func buy_camp_upgrade() -> bool: return camp_shop.buy_camp_upgrade()

## The departure tier of the deepest camp in any region (1 with none):
## camp 10 starts floor 11, tier 2.
func deepest_tier() -> int:
	var deepest := 0
	for region in base.camps: deepest = maxi(deepest, int(base.camps[region]))
	return Economy.tier_of(deepest + 1)

## Hidden difficulty (§4, after 贪婪洞窟's per-floor tables): a curve by floor plus
## the chosen route's modifier for this floor only. Never shown as a number.
func difficulty() -> float:
	var d := minf(EnemyAttacks.PRESSURE_DEPTH_MAX, FieldCatalog.DIFFICULTY_PER_FLOOR * (floor_number - 1)) + float(routes.route_node_info().danger)
	return maxf(0.0, d * pressure_multiplier())

func passes_pickup_filter(item: Item) -> bool:
	if item == null or not item.is_equippable() or not item.exclusive_region.is_empty() or item.is_legend(): return true
	var s := SystemScreens.settings
	if item.rarity < int(s.get("loot_rarity", 0)): return false
	if item.prefixes.size() < int(s.get("loot_prefixes", 0)): return false
	var grade := int(s.get("loot_prefix_grade", 0))
	if grade > 0:
		if item.prefixes.is_empty(): return false
		for entry in item.prefixes:
			if PrefixCatalog.grade_of(entry) < grade - 1: return false
	return true

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
	save_base_soon(not in_base)
	if sorted: set_message("背包已整理。")
	else: notice("整理失败：当前摆放已是最紧凑，物品未移动。")
	return sorted

## Drag and drop (装备与背包界面调研 §5.4): `from` is a container, or null for
## an equipped item; the target is a cell of `to`.
func move_item(item: Item, from: ItemContainer, to: ItemContainer, x: int, y: int, page: int = 0) -> bool:
	if item == null or to == null: return false
	if from == to: return to.reposition(item, x, y, page)
	if from == null:
		if player.equipped.get(item.category) != item or not to.place(item, x, y, page): return false
		player.unequip(item.category)
	else:
		if not from.items.has(item) or not to.can_place(item, x, y, page): return false
		from.remove(item)
		to.place(item, x, y, page)
	save_base_soon(not in_base)
	return true

## Onto a page of the pack, its first free spot (a drop on the page's tab).
## `from` is a container, or null for an equipped item.
func move_to_pack_page(item: Item, from: ItemContainer, page: int) -> bool:
	if item == null: return false
	if from == inventory:
		if not inventory.move_to_page(item, page): return false
	elif from == null:
		if player.equipped.get(item.category) != item or not inventory.try_add_on(item, page): return false
		player.unequip(item.category)
	else:
		if not from.items.has(item): return false
		from.remove(item)
		if not inventory.try_add_on(item, page):
			from.items.append(item)
			return false
	save_base_soon(not in_base)
	return true

## Ctrl+click: pack ↔ safe bag.
func quick_move(item: Item, from: ItemContainer) -> bool:
	var to := safe_bag if from == inventory else inventory
	return transfer_item(item, from, to)

## Container sizes from the base's expansion levels.
func apply_container_sizes() -> void:
	var safe: Vector2i = BaseCatalog.SAFE_SIZES[base.safe_level]
	if base.researched("safe_row"): safe.y += 1   # 外勤部 4 阶
	inventory.set_pages(BaseCatalog.PACK_PAGES[base.pack_level])
	safe_bag.resize(safe.x, safe.y)

## Units of a PRTS material in the warehouse, pack and safe bag (掉落物策划案 §7.1).
func material_count(id: String) -> int:
	var total := inventory.count_material(id) + safe_bag.count_material(id)
	# The shelves and their boxes in place, without copying them (stash).
	for item in base.shelf:
		if item.material_id == id: total += item.quantity
		if item.is_case():
			for inner in item.contents.items:
				if inner.material_id == id: total += inner.quantity
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

## Gold, facility level and materials together, for the terminal buttons.
func upgrade_refusal(kind: String) -> String:
	var lost := dept_refusal("outfit")
	if not lost.is_empty(): return lost
	var refusal := base.upgrade_refusal(kind, gold)
	return refusal if not refusal.is_empty() else materials_refusal(upgrade_cost(kind))

func buy_pack_upgrade() -> bool:
	if not upgrade_refusal("pack").is_empty(): return false
	consume_materials(upgrade_cost("pack"))
	gold -= int(BaseCatalog.PACK_PRICES[base.pack_level + 1])
	base.pack_level += 1
	apply_container_sizes()
	save_base()
	set_message("背包扩容到 %d 页。" % inventory.page_count())
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
			save_base_soon(true)
			sound.play("loot")
			set_message("拾取 %s ×%d" % [item.display_name(), before])
			return true
		if left < before:
			save_base_soon(true)
			sound.play("loot")
			notice("背包只装下 %d 个 %s，剩余 %d 个留在地上。" % [before - left, item.item_name, left])
			return false
		notice("背包空间不足：%s ×%d 仍留在地上。" % [item.item_name, left])
		return false
	if inventory.try_add(item):
		if item.named_kind() == "set": run_sets_seen[str(SpecialGear.GEAR[item.special].set_id)] = true
		save_base_soon(true)
		sound.play("loot")
		set_message("拾取 %s（%d×%d）" % [item.display_name(), item.width, item.height])
		return true
	notice("背包空间不足：%s 仍留在地上。" % item.item_name)
	return false

func _move_last_item_to_safe_bag() -> void:
	if not inventory.is_empty(): transfer_item(inventory.items.back(), inventory, safe_bag)

func transfer_item(item: Item, from: ItemContainer, to: ItemContainer) -> bool:
	if not from.transfer_to(item, to):
		notice("空间不足，物品留在原处；物品不能旋转。")
		return false
	save_base_soon(not in_base)
	set_message("已转移：%s" % item.item_name)
	return true

func equip_from(item: Item, from: ItemContainer) -> bool:
	if not from.items.has(item) or not item.is_equippable(): return false
	var refusal := player.equip_refusal(item)
	if not refusal.is_empty():
		notice("装备需求未达标：%s。" % refusal)
		return false
	var old_pos := Vector2i(item.grid_x, item.grid_y)
	from.remove(item)
	var previous: Item = player.equipped.get(item.category)
	# At the base a Rhodes piece is worn or handed back.
	if in_base and GearCatalog.bound(previous):
		player.unequip(previous.category)
		previous = null
	if previous != null and not from.try_add(previous):
		item.grid_x = old_pos.x
		item.grid_y = old_pos.y
		from.items.append(item)
		notice("换装空间不足，物品均已保留。")
		return false
	player.equip(item)
	save_base_soon(not in_base)
	return true

func unequip_to_pack(item: Item) -> bool:
	if item == null or player.equipped.get(item.category) != item: return false
	if in_base and GearCatalog.bound(item):
		return_rhodes(item)
		save_base_soon()
		return true
	if not inventory.try_add(item): return false
	player.unequip(item.category)
	save_base_soon(not in_base)
	return true

func drop_item(item: Item, from: ItemContainer) -> bool:
	if in_base or item == null or not from.items.has(item): return false
	from.remove(item)
	if item.insured and not _insured_left_behind.has(item): _insured_left_behind.append(item)
	save_base_soon(true)
	var loot := Loot.new()
	loot.game = self
	loot.item = item
	loot.pickup_delay = 2.0
	loot.from = player.global_position + Vector3.UP * 0.6
	add_child(loot)
	loot.global_position = player.global_position + Vector3(1.5, 0, 0)
	return true

## Off the shelf into the pack, to take on the next contract.
func bring_item(item: Item) -> bool:
	# A 整理箱 never leaves the warehouse (整理箱与收藏品策划案 v0.2 §0-3).
	if not in_base or item.is_case() or not stash.has(item): return false
	# A cell can hold more than a bag stack: one bag stack comes off it.
	var piece := base.bag_piece(item)
	var box := base.case_of(item)
	if piece == item: base.take_from_shelf(item)
	if not inventory.try_add(piece):
		if piece == item and box != null: box.contents.add_stack(item)
		elif piece == item: base.put_back(item)
		else: item.set_quantity(item.quantity + piece.quantity)
		notice("背包空间不足：%s 仍在仓库。" % item.item_name)
		return false
	save_base()
	return true

## 整备台: off the shelf straight onto her; what she wore goes to its shelf (or the pack).
func equip_from_stash(item: Item) -> bool:
	if not in_base or not stash.has(item) or not item.is_equippable(): return false
	var refusal := player.equip_refusal(item)
	if not refusal.is_empty():
		notice("装备需求未达标：%s。" % refusal)
		return false
	base.take_from_shelf(item)
	var previous: Item = player.unequip(item.category)
	if GearCatalog.bound(previous): previous = null
	if previous != null and base.store(previous).is_empty() and not inventory.try_add(previous):
		player.equip(previous)
		base.put_back(item, "shelf")
		notice("仓库和背包都满了：%s 仍在货架上。" % item.item_name)
		return false
	player.equip(item)
	story_note("bench_equip")
	save_base()
	return true

## From the loadout into the warehouse (仓库修订: at the 仓管台, the workbench
## or settlement's 仓库 page). `quiet` skips the save and the full message,
## for 一键入库 doing many at once.
func store_item(item: Item, quiet := false) -> bool:
	if not in_base or not carried_items().has(item): return false
	if GearCatalog.bound(item):
		return_rhodes(item)
		if not quiet: save_base()
		return true
	if base.store_target(item).is_empty():
		if not quiet: set_message("仓库空间不足（%d/%d）：%s 留在身上。" % [base.shelf_count(), base.capacity(), item.item_name])
		return false
	inventory.remove(item)
	safe_bag.remove(item)
	if player.equipped.get(item.category) == item: player.unequip(item.category)
	base.store(item)
	story_note("shelve")
	if not quiet: save_base()
	return true

# --- 整理箱 (整理箱与收藏品策划案 v0.2 §2) ------------------------------------------

## Whether `item`, wherever it is at the base, can go into `box` now.
func can_box(box: Item, item: Item) -> bool:
	if not in_base or box == null or not box.is_case() or item == box or not base.shelf.has(box): return false
	if GearCatalog.bound(item) or base.case_of(item) == box: return false
	if not (stash.has(item) or carried_items().has(item)): return false
	return Collectibles.accepts(box.case_kind, item) and box.contents.can_take(item)

## Into `box` from the shelves, another box, the bags or her body.
func box_item(box: Item, item: Item) -> bool:
	if not can_box(box, item): return false
	if stash.has(item): base.take_from_shelf(item)
	else:
		inventory.remove(item)
		safe_bag.remove(item)
		if player.equipped.get(item.category) == item: player.unequip(item.category)
	Collectibles.put(box, item)
	save_base()
	return true

## Out of its box onto the shelves at `cell` (the first free one when it does not fit there).
func unbox_item(item: Item, cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var box := base.case_of(item)
	if not in_base or box == null: return false
	if cell.x < 0 or not base.shelf_fits(item, cell.x, cell.y): cell = base.shelf_spot(item)
	if cell.x < 0:
		notice("仓库空间不足：%s 仍在整理箱里。" % item.item_name)
		return false
	box.contents.remove(item)
	base.shelf.append(item)
	item.grid_x = cell.x
	item.grid_y = cell.y
	save_base()
	return true

## The box of `kind` one level below `tier` that a trade would upgrade (the
## fullest), null when there is none or `tier` is 1.
func case_to_upgrade(kind: String, tier: int) -> Item:
	var best: Item = null
	for box in base.shelf:
		if box.is_case() and box.case_kind == kind and box.case_tier == tier - 1:
			if best == null or box.contents.items.size() > best.contents.items.size(): best = box
	return best

## The cheapest collectible at or above `rarity` in the warehouse or the bags.
func _collectible_for(rarity: int) -> Item:
	var best: Item = null
	for item in stash + inventory.items + safe_bag.items:
		if item.is_collectible() and item.rarity >= rarity and (best == null or item.value < best.value): best = item
	return best

## "" when 可露希尔 would trade a `kind` box of `tier` now, else what is missing.
func case_refusal(kind: String, tier: int) -> String:
	if not in_base or not kind in Collectibles.CASE_KINDS or tier < 1 or tier > Collectibles.TIERS: return "无法兑换"
	var recipe: Dictionary = Collectibles.RECIPES[tier]
	var cost := recipe.duplicate()
	cost.erase("collectible")
	var missing := materials_refusal(cost)
	if tier > 1 and case_to_upgrade(kind, tier) == null: return "缺少" + Collectibles.case_name(kind, tier - 1)
	if recipe.has("collectible") and _collectible_for(int(recipe.collectible)) == null: return "缺少%s收藏品" % Item.RARITY_NAMES[int(recipe.collectible)]
	if not missing.is_empty(): return missing
	if tier == 1 and not base.shelf_has_room(): return "仓库已满"
	return ""

## 可露希尔's trade (§2.3): level 1 new; above that the box one level down
## becomes this one where it lies, its contents kept.
func trade_case(kind: String, tier: int) -> bool:
	if not case_refusal(kind, tier).is_empty(): return false
	var recipe: Dictionary = Collectibles.RECIPES[tier]
	var cost := recipe.duplicate()
	cost.erase("collectible")
	consume_materials(cost)
	if recipe.has("collectible"): _hand_over(_collectible_for(int(recipe.collectible)))
	var made := Collectibles.create_case(kind, tier)
	var old := case_to_upgrade(kind, tier) if tier > 1 else null
	if old != null:
		for item in old.contents.items.duplicate():
			old.contents.remove(item)
			if not made.contents.place(item, item.grid_x, item.grid_y): made.contents.add_stack(item)
		made.grid_x = old.grid_x
		made.grid_y = old.grid_y
		base.shelf.erase(old)
		base.receive(made, true)
	else:
		base.receive(made)
	save_base()
	return true

## 收藏品礼包 (§3.1): collectibles packed at 加工部, given to a faction for relation.
const GIFT_PACK := "gift_pack"
const GIFT_RELATION_PER := 1000.0
const GIFT_HOME_BONUS := 1.5
## Whose home each region is: their own region's pieces count GIFT_HOME_BONUS times.
const GIFT_HOMES := {"city": ["lungmen", "rat", "penguin"], "mine": ["ursus", "reunion"], "snow": ["sami"]}

static func is_gift(item: Item) -> bool:
	return item != null and item.effect == GIFT_PACK and item.contents != null

## The collectibles that may go into a gift: in the warehouse or the bags.
func giftable() -> Array[Item]:
	var out: Array[Item] = []
	for item in stash + inventory.items + safe_bag.items:
		if item.is_collectible(): out.append(item)
	return out

## Packs `pieces` into one 收藏品礼包 in the warehouse; null if any cannot go.
func make_gift(pieces: Array) -> Item:
	if not in_base or pieces.is_empty() or not pieces.all(func(it): return giftable().has(it)) or not base.shelf_has_room(): return null
	var gift := Item.create("收藏品礼包", Item.Category.MATERIAL, 2, 2)
	gift.effect = GIFT_PACK
	gift.rarity = 0
	gift.value = 0
	gift.contents = ItemContainer.new(10, 10)
	for piece: Item in pieces:
		_hand_over(piece)
		gift.contents.try_add(piece)
		gift.value += piece.value
		gift.rarity = maxi(gift.rarity, piece.rarity)
	base.receive(gift)
	save_base()
	return gift

## What giving `gift` to `faction` adds to the relation (at least 1).
func gift_gain(gift: Item, faction: String) -> int:
	if not is_gift(gift): return 0
	var worth := 0.0
	for piece in gift.contents.items:
		worth += Economy.price(piece) * (GIFT_HOME_BONUS if faction in GIFT_HOMES.get(piece.origin_region, []) else 1.0)
	return maxi(1, roundi(worth / GIFT_RELATION_PER))

## The gift in the warehouse or the bags worth most to `faction`, null when none.
func best_gift(faction: String) -> Item:
	var best: Item = null
	for item in stash + inventory.items + safe_bag.items:
		if is_gift(item) and (best == null or gift_gain(item, faction) > gift_gain(best, faction)): best = item
	return best

func give_gift(gift: Item, faction: String) -> bool:
	if not in_base or not is_gift(gift) or not FactionCatalog.FACTIONS.has(faction) or not _hand_over(gift): return false
	exchange.add_relation(faction, gift_gain(gift, faction))
	save_base()
	return true

## 投保台 (§4): insurance off, no refund.
func uninsure(item: Item) -> bool:
	if not in_base or item == null or not item.insured or not (stash.has(item) or carried_items().has(item)): return false
	item.insured = false
	save_base()
	return true

## 一键入库: the pack and the safe bag into the warehouse, as far as it has
## room (what she wears stays on). Returns how many went in.
func store_all_carried() -> int:
	var stored := 0
	for item in inventory.items.duplicate() + safe_bag.items.duplicate():
		if store_item(item, true): stored += 1
	save_base()
	var left := inventory.items.size() + safe_bag.items.size()
	if stored > 0 or left > 0: set_message("已入库 %d 件%s。" % [stored, "" if left == 0 else "，仓库已满，%d 件留在身上" % left])
	return stored

## At the base, insured gear arrives in the warehouse when its time comes, whether
## or not a contract is running out there (用户 2026-10-15: 时钟计时).
func _tick_insurance_clock(delta: float) -> void:
	_insurance_check -= delta
	if not in_base or _insurance_check > 0.0: return
	_insurance_check = INSURANCE_CHECK_SECONDS
	var arrived := base.tick_insurance()
	if arrived.is_empty(): return
	save_base()
	set_message("投保物品送回 %d 件，已入库。" % arrived.size())
	if is_instance_valid(tutorial_spotlight): tutorial_spotlight.request("insured_back")

## Insured gear that did not come out: back INSURANCE_DELAY_SECONDS later, and
## the insurance is used up by that one return. Returns the wait in seconds.
func _queue_insured(item: Item) -> int:
	var wait := rng_base.randi_range(FieldCatalog.INSURANCE_DELAY_SECONDS.x, FieldCatalog.INSURANCE_DELAY_SECONDS.y)
	# 加急专递单 in the warehouse: one a piece, half the wait (势力声望解锁策划案 §三).
	if base.stock().any(func(i): return i.material_id == FactionRewards.EXPRESS) and base.take_material(FactionRewards.EXPRESS, 1):
		wait = roundi(wait * FactionRewards.EXPRESS_WAIT)
	item.insured = false
	item.carried_in = false
	base.queue_insured(item, wait)
	return wait

## Base insurance before leaving: the item's 交付价 in 龙门币 (保全系统修订案 §6).
func insurance_price(item: Item) -> int:
	return Economy.price(item)

## 重铸 / 校准 / 精调 at the base workbench only (装备前缀策划案 §2.5, §2.8).
## 用户 2026-10-25: 精调换成装置，每种稀有度的材料和龙门币的花费不同 — one
## row per rarity (普通 → 传说, 装备前缀策划案 §11): 校准 climbs the 异铁 line
## into 研磨石, 精调 the 装置 line, and 精调 costs half as much again for every
## 精调 the piece has had.
const REFRESH_LMD := {
	"reforge": [600, 1200, 2500, 5000, 10000, 20000],
	"calibrate": [800, 1600, 3200, 6400, 12800, 25600],
	"tune": [1000, 2000, 4000, 8000, 16000, 32000]}
const REFRESH_MATERIALS := {
	"reforge": [{}, {}, {}, {}, {}, {}],
	"calibrate": [{"异铁碎片": 2}, {"异铁": 1}, {"异铁组": 1}, {"研磨石": 1}, {"研磨石": 2}, {"研磨石": 2, "化合切削液": 1}],
	"tune": [{"破损装置": 2}, {"装置": 1}, {"装置": 2}, {"全新装置": 1}, {"全新装置": 2}, {"改量装置": 1}]}
## 定向重铸's base: a share of the delivery price, at least REFRESH_MIN_LMD.
const REFRESH_MIN_LMD := 300
const REFRESH_SHARE := 0.93
const TUNE_STEP := 1.5

static func refresh_materials(kind: String, item: Item) -> Dictionary:
	return REFRESH_MATERIALS[kind][clampi(item.rarity, 0, Item.RARITY_MAX)]

func refresh_cost(kind: String, item: Item) -> int:
	var base_cost: int = REFRESH_LMD[kind][clampi(item.rarity, 0, Item.RARITY_MAX)]
	if kind == "tune": return roundi(base_cost * pow(research.tune_step(), item.tune_count))
	var cost := base_cost * research.refresh_factor()
	if kind == "reforge":
		if reforge_keep >= 0 and base.researched("prefix_lock"): cost *= 2.0   # 工程部 5 阶
		if base.researched("reforge_pick"): cost *= 1.5                        # 工程部 6 阶
	return roundi(cost)

## 工程部 5 阶: the prefix 重铸 keeps (-1: none). Cleared after every 重铸.
var reforge_keep := -1
## 工程部 6 阶: {"item": Item, "options": [prefixes, prefixes]} waiting for her pick.
var reforge_choice := {}

## Picks one of the two 重铸 results waiting on `item`.
func choose_reforge(index: int) -> bool:
	if reforge_choice.is_empty() or index < 0 or index >= (reforge_choice.options as Array).size(): return false
	var item: Item = reforge_choice.item
	item.prefixes = (reforge_choice.options[index] as Array).duplicate(true)
	PrefixCatalog.refresh_value(item)
	reforge_choice = {}
	player._recompute_stats()
	player.hp = minf(player.hp, player.max_hp)
	save_base()
	return true

## "" when it can be done now, else why not.
func refresh_refusal(kind: String, item: Item) -> String:
	if not in_base or not PrefixCatalog.eligible_item(item): return "无法改造"
	if kind != "reforge" and PrefixCatalog.rollable_lines(item).is_empty(): return "无法改造"
	if gold < refresh_cost(kind, item): return "龙门币不足"
	return materials_refusal(refresh_materials(kind, item))

## `line` (精调 only) is one of PrefixCatalog.rollable_lines(item).
func refresh_gear(kind: String, item: Item, line: Array = []) -> bool:
	if not refresh_refusal(kind, item).is_empty(): return false
	if kind == "tune" and not PrefixCatalog.rollable_lines(item).has(line): return false
	gold -= refresh_cost(kind, item)
	consume_materials(refresh_materials(kind, item))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match kind:
		"reforge":
			var keep := reforge_keep if base.researched("prefix_lock") else -1
			reforge_keep = -1
			if base.researched("reforge_pick"):
				var before: Array = item.prefixes.duplicate(true)
				var options: Array = []
				for i in range(2):
					PrefixCatalog.reforge(item, rng, keep)
					options.append(item.prefixes.duplicate(true))
					item.prefixes = before.duplicate(true)
				PrefixCatalog.refresh_value(item)
				reforge_choice = {"item": item, "options": options}
			else: PrefixCatalog.reforge(item, rng, keep)
		"calibrate": PrefixCatalog.calibrate(item, rng)
		"tune":
			PrefixCatalog.reroll_line(item, line, rng)
			item.tune_count += 1
	player._recompute_stats()
	player.hp = minf(player.hp, player.max_hp)
	save_base()
	return true

## 定向重铸 (前缀放大与特效阶等案 §3, 用户 2026-10-21): turns a piece's prefix
## into one of the families she wears. Only with the ship at 龙门 (炎国) and
## 龙门商会 at its top rank, for 龙门币 and a 玄纹墨 sold there. It may fail:
## the piece stays as it was and nothing comes back; every failure raises the
## next try's odds along an S curve until it is certain.
const DIRECTED_ANCHOR := "龙门"
const DIRECTED_FACTION := "lungmen"
const DIRECTED_MATERIAL := "玄纹墨"
const DIRECTED_LMD := 3.0
const DIRECTED_BASE := 0.40
const DIRECTED_MID := 3.0
const DIRECTED_CERTAIN := 8

## The odds after `fails` failures in a row: 40% at first, 100% from the eighth.
static func directed_chance(fails: int) -> float:
	if fails >= DIRECTED_CERTAIN: return 1.0
	var s := func(n: float) -> float: return 1.0 / (1.0 + exp(-(n - DIRECTED_MID)))
	var share: float = (s.call(float(fails)) - s.call(0.0)) / (s.call(float(DIRECTED_CERTAIN)) - s.call(0.0))
	return DIRECTED_BASE + (1.0 - DIRECTED_BASE) * share

func directed_cost(item: Item) -> int:
	return roundi(maxi(REFRESH_MIN_LMD, ceili(Economy.price(item) * REFRESH_SHARE)) * DIRECTED_LMD)

## "" when 定向重铸 of `item` into `family` can be done now, else why not.
func directed_refusal(item: Item, family: String) -> String:
	if not in_base or not PrefixCatalog.eligible_item(item) or not PrefixFamilies.FAMILIES.has(family): return "无法改造"
	if base.ship_at != DIRECTED_ANCHOR or not voyage.sailing.is_empty(): return "需要停靠龙门"
	if exchange.rank(DIRECTED_FACTION) < Exchange.RANK_AT.size() - 1: return "需要龙门商会关系 %s" % Exchange.rank_name(Exchange.RANK_AT.size() - 1)
	if not player.families.worn.has(family): return "未装备该族"
	for entry in item.prefixes:
		if PrefixFamilies.family_of(str(entry.id)) == family: return "已是该族"
	if gold < directed_cost(item): return "龙门币不足"
	return materials_refusal({DIRECTED_MATERIAL: 1})

## Returns "" when refused, else "success" or "fail".
func directed_reforge(item: Item, family: String, rng: RandomNumberGenerator = null) -> String:
	if not directed_refusal(item, family).is_empty(): return ""
	gold -= directed_cost(item)
	consume_materials({DIRECTED_MATERIAL: 1})
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result := "fail"
	if rng.randf() < directed_chance(base.directed_fails):
		base.directed_fails = 0
		result = "success"
		var id := ""
		for p in PrefixFamilies.FAMILIES[family].prefixes:
			if str(p[3]) == PrefixCatalog.slot_kind(item): id = str(p[0])
		# The family takes the first prefix's place; a second one stays unless
		# it is a family of the same kind.
		var rest: Array = item.prefixes.slice(1).filter(func(e): return str(PrefixCatalog.get_entry(str(e.id)).group) != "fam_" + family)
		item.prefixes = [PrefixCatalog.roll_entry(id, rng)] + rest
		PrefixCatalog.refresh_value(item)
	else:
		base.directed_fails += 1
	player._recompute_stats()
	player.hp = minf(player.hp, player.max_hp)
	save_base()
	return result

# --- 势力特供 (势力特供策划案_v0_2 §二, 用户 2026-10-22) -------------------------------

const SPECIAL_FUEL := "高能燃料"
const SPECIAL_EARS := "下城区耳目"
const SPECIAL_FLUX := "高纯源岩助熔剂"
const SPECIAL_MOSS := "萨米冰原苔"
const SPECIAL_PATENT := "骑士工坊专利授权"
const SPECIAL_SLIP := "企鹅专递单"
const SPECIAL_GUIDE := "残党向导"

## 下城区耳目 on a headline still 待证实: whether it is true, before it is settled.
func peek_refusal(headline: Dictionary) -> String:
	if not in_base: return "只在基地"
	if not trade_block().is_empty(): return trade_block()
	if str(headline.get("status", "")) != "待证实" or headline.has("peek") or _rumor_of(headline).is_empty(): return "无法查证"
	return materials_refusal({SPECIAL_EARS: 1})

func peek_rumor(headline: Dictionary) -> bool:
	if not peek_refusal(headline).is_empty(): return false
	consume_materials({SPECIAL_EARS: 1})
	headline["peek"] = "属实" if bool(_rumor_of(headline).rumor.truth) else "不实"
	save_base()
	return true

func _rumor_of(headline: Dictionary) -> Dictionary:
	for e in market.effects:
		if str(e.id) == str(headline.get("id", "")) and e.has("rumor") and not bool(e.rumor.get("verified", false)): return e
	return {}

## 高纯源岩助熔剂 on a 加工部 job: its byproducts doubled (one drawn if it had
## none), the rest of its time × 0.7. Once a job.
func flux_refusal(job: Dictionary) -> String:
	if not in_base or not workshop.jobs.has(job): return "无效"
	if job.get("flux", false): return "已使用"
	return materials_refusal({SPECIAL_FLUX: 1})

func use_flux(job: Dictionary) -> bool:
	if not flux_refusal(job).is_empty(): return false
	consume_materials({SPECIAL_FLUX: 1})
	job["flux"] = true
	if Workshop.RECIPES.has(str(job.output)):
		var by: Dictionary = job.get("byproducts", {})
		if by.is_empty(): by[Workshop.BYPRODUCTS[rng_base.randi() % Workshop.BYPRODUCTS.size()]] = 1
		for id in by: by[id] = int(by[id]) * FactionSpecials.FLUX_BYPRODUCTS
		job["byproducts"] = by
	var now := BaseState.now()
	job["due"] = now + roundi(maxi(0, int(job.due) - now) * FactionSpecials.FLUX_TIME)
	save_base()
	set_message("加工部：%s 加入助熔剂。" % job.output)
	return true

## 骑士工坊专利授权 on running research: the rest of its time halved. Once a project.
func patent_refusal(id: String) -> String:
	if not in_base or not research.is_running(id): return "无效"
	for e in research.active():
		if str(e.id) == id and e.get("patent", false): return "已使用"
	return materials_refusal({SPECIAL_PATENT: 1})

func use_patent(id: String) -> bool:
	if not patent_refusal(id).is_empty(): return false
	consume_materials({SPECIAL_PATENT: 1})
	var now := BaseState.now()
	for e in research.active():
		if str(e.id) == id:
			e["patent"] = true
			e["end"] = now + roundi(maxi(0, int(e.end) - now) * FactionSpecials.PATENT_TIME)
	research.tick()
	save_base()
	return true

## 萨米冰原苔: every injured operator cured, free, every lasting ill cleared.
func moss_refusal() -> String:
	if not in_base: return "只在基地"
	if base.injured_operators().is_empty(): return "无人负伤"
	return materials_refusal({SPECIAL_MOSS: 1})

func moss_cure() -> bool:
	if not moss_refusal().is_empty(): return false
	consume_materials({SPECIAL_MOSS: 1})
	base.injuries.clear()
	save_base()
	set_message("萨米冰原苔：所有干员已痊愈。")
	return true

## 企鹅专递单, from 企鹅物流's desk at the exchange.
func slip_refusal() -> String:
	if not in_base: return "只在基地"
	if not trade_block().is_empty(): return trade_block()
	if exchange.rank("penguin") < FactionSpecials.rank_needed(SPECIAL_SLIP): return "需要关系 %s" % Exchange.rank_name(FactionSpecials.rank_needed(SPECIAL_SLIP))
	if gold < slip_price(): return "龙门币不足"
	return ""

## Off its door rank (势力声望解锁策划案 §2.2).
func slip_price() -> int:
	return roundi(FactionSpecials.SLIP_PRICE * exchange.special_mult("penguin", SPECIAL_SLIP))

## 企鹅物流's 加急专递单 at the same desk (势力声望解锁策划案 §三): from 崇敬.
func express_price() -> int:
	return roundi(FactionRewards.EXPRESS_PRICE * exchange.special_mult("penguin", FactionRewards.EXPRESS))

func express_refusal() -> String:
	if not in_base: return "只在基地"
	if not trade_block().is_empty(): return trade_block()
	if exchange.rank("penguin") < FactionRewards.GOODS_RANK: return "需要关系 %s" % Exchange.rank_name(FactionRewards.GOODS_RANK)
	if gold < express_price(): return "龙门币不足"
	return ""

func buy_express() -> bool:
	if not express_refusal().is_empty(): return false
	gold -= express_price()
	exchange._deliver_goods(FactionRewards.EXPRESS, 1)
	exchange.add_relation("penguin", 1)
	set_message("加急专递单已入库。")
	return true

func buy_slip() -> bool:
	if not slip_refusal().is_empty(): return false
	gold -= slip_price()
	exchange._deliver_goods(SPECIAL_SLIP, 1)
	exchange.add_relation("penguin", 1)
	set_message("企鹅专递单已入库。")
	return true

func carried_count(material: String) -> int:
	return inventory.count_material(material) + safe_bag.count_material(material)

## Takes `count` of a material from the pack and safe bag only (in the field
## the warehouse is out of reach).
func _spend_carried(material: String, count: int) -> bool:
	if carried_count(material) < count: return false
	var need := count
	for pool in [inventory.items, safe_bag.items]:
		for item: Item in pool.duplicate():
			if need <= 0: break
			if item.material_id != material: continue
			var used := mini(need, item.quantity)
			need -= used
			if used < item.quantity: item.set_quantity(item.quantity - used)
			else: _hand_over(item)
	return true

## 企鹅专递单 at a Rhodes squad or a camp: any number of things she carries go
## home, onto the warehouse shelves; what they cannot hold, to the PRTS mail.
func parcel_refusal() -> String:
	if in_base: return "只在局内"
	if carried_count(SPECIAL_SLIP) <= 0: return "需要企鹅专递单"
	if not in_camp and not (encounter == "squad" and near(world_map.encounter_node)): return "需要罗德岛小队或营地"
	return ""

## What a slip can send: the pack and the safe bag (not what she wears, nor the slips).
func parcel_items() -> Array[Item]:
	var out: Array[Item] = []
	for item in inventory.items + safe_bag.items:
		if item.material_id != SPECIAL_SLIP: out.append(item)
	return out

## Sends `items`; returns how many went where (BaseState.store's place, or
## "receiving" for BaseState.receive).
func parcel_send(items: Array) -> Dictionary:
	var out := {"shelf": 0, "staging": 0, "receiving": 0}
	if not parcel_refusal().is_empty() or items.is_empty(): return out
	var sending: Array[Item] = []
	for item in items:
		if item is Item and parcel_items().has(item) and not sending.has(item): sending.append(item)
	if sending.is_empty(): return out
	_spend_carried(SPECIAL_SLIP, 1)
	for item in sending:
		inventory.remove(item)
		safe_bag.remove(item)
		item.carried_in = false
		var where := base.store(item)
		if where.is_empty():
			base.receive(item)
			where = "receiving"
		out[where] = int(out[where]) + 1
	exchange.add_relation("penguin", 1)
	save_base(true)
	set_message("企鹅专递：%d 件已送回仓库。" % sending.size())
	return out

## 残党向导 in the field: this floor's vault and trace show on the map.
func guide_refusal() -> String:
	if in_base or in_camp: return "只在局内"
	if guide_floor == floor_number: return "本层已使用"
	if carried_count(SPECIAL_GUIDE) <= 0: return "需要残党向导"
	return ""

func use_guide() -> bool:
	if not guide_refusal().is_empty(): return false
	_spend_carried(SPECIAL_GUIDE, 1)
	guide_floor = floor_number
	broadcast("PRTS：残党向导标出了本层的密室和踪迹。")
	return true

func guide_active() -> bool:
	return not in_base and guide_floor == floor_number

## Items that do something when used from the pack in the field.
func usable_special(item: Item) -> bool:
	return item != null and item.material_id == SPECIAL_GUIDE and not in_base

# --- 第二层、订单与设施 (势力特供策划案_v0_2 §三–§六; GmFacilities) ----------------------

## The farm and canteen, the order board and the facilities (GmFacilities).
var facilities := GmFacilities.new(self)
func farm_changed() -> void: facilities.farm_changed()
func _apply_meal(meal_id: String) -> void: facilities._apply_meal(meal_id)
func ride_lift(to_deck: int) -> void: facilities.ride_lift(to_deck)
func deliverable_items() -> Array[Item]: return facilities.deliverable_items()
func _hand_over(item: Item) -> bool: return facilities._hand_over(item)
func deliver_to_order(slot: int, item: Item) -> bool: return facilities.deliver_to_order(slot, item)
func abandon_order(slot: int) -> bool: return facilities.abandon_order(slot)
func reroll_order(slot: int) -> bool: return facilities.reroll_order(slot)
func facility_refusal(id: String, remote := false) -> String: return facilities.facility_refusal(id, remote)
func dept_refusal(dept: String) -> String: return facilities.dept_refusal(dept)
func gate_refusal(id: String) -> String: return facilities.gate_refusal(id)
func connect_refusal(id: String) -> String: return facilities.connect_refusal(id)
func connect_facility(id: String) -> bool: return facilities.connect_facility(id)
func facility_cost(id: String) -> Dictionary: return facilities.facility_cost(id)
func construction_ready() -> int: return facilities.construction_ready()
func upgrade_facility(id: String, remote := false) -> bool: return facilities.upgrade_facility(id, remote)
func station_needs_attention(id: String) -> bool: return facilities.station_needs_attention(id)

func squad_chance() -> float:
	return Provisions.SQUAD_CHANCE if facilities.meal_tier() >= Provisions.SQUAD_CHANCE_TIER else FieldCatalog.SQUAD_CHANCE

func squad_max_uses() -> int:
	return Provisions.SQUAD_USES if facilities.meal_tier() >= Provisions.SQUAD_USES_TIER else 1

func squad_uses_left() -> int:
	return maxi(0, squad_max_uses() - squad_uses)

func _use_squad() -> void:
	squad_uses += 1
	encounter_used = squad_uses >= squad_max_uses()

## The squad's services past its paid ones: 企鹅专递 and the 补给 mailed to it.
func squad_extras() -> bool:
	return encounter == "squad" and (carried_count(SPECIAL_SLIP) > 0 or not provisions.mailed().is_empty())

func squad_supply_refusal() -> String:
	if in_base or encounter != "squad" or not near(world_map.encounter_node): return "小队不在附近"
	if provisions.mailed().is_empty(): return "没有寄来的补给"
	return ""

## The 补给 企鹅物流 carried out, eaten here: it replaces the one from the canteen.
func squad_supply() -> bool:
	if not squad_supply_refusal().is_empty(): return false
	var meal_id := provisions.mailed()
	base.farm.mailed = ""
	_apply_meal(meal_id)
	save_base(true)
	set_message("罗德岛小队：%s，%s。" % [meal_id, Provisions.meal_text(meal_id)])
	return true

func insure(item: Item) -> bool:
	if not in_base or not carried_items().has(item) or not item.is_equippable() or item.insured or GearCatalog.bound(item) or gold < insurance_price(item): return false
	gold -= insurance_price(item)
	item.insured = true
	story_note("insure")
	save_base()
	return true

# --- Departure (§5.3) ----------------------------------------------------------

## Reasons to stop and look before leaving; empty when there are none.
func departure_warnings() -> Array[String]:
	var out: Array[String] = []
	if base.injured: out.append("生命上限 −%d%%（重伤）" % roundi(base.hp_penalty() * 100))
	return out

## Opens 干员养成 over whatever is showing; Esc / back returns to `back`.
func open_training(back: Callable = Callable()) -> void:
	if transitioning: return
	if is_instance_valid(_inventory_panel): _inventory_panel.hide()
	open_modal("training")
	view_operator = ""
	menu.show_training(not in_base)
	menu.back_to = back if back.is_valid() else Callable()

## What the contract buttons call: leaves at once, or shows the departure card
## first when there is something to look at.
func request_contract(region: String, start_camp: int = 0) -> void:
	if not in_base or transitioning: return
	_pending_start_camp = start_camp
	if departure_warnings().is_empty() and not map_features.kits_in_stock(region):
		start_contract(region, start_camp)
		return
	open_modal("station")
	menu.show_departure(region)

## The base's top bar (§5.1): gold, and an injury when present.
func base_status_text() -> String:
	var parts: Array[String] = ["龙门币 %s" % Economy.format(gold)]
	var injured := base.injured_operators()
	if not injured.is_empty(): parts.append("重伤 " + "、".join(injured.map(func(id): return Operators.display_name(id))))
	return "   ".join(parts)

# --- Medical (§4; GmMedical) -------------------------------------------------

func carried_potions() -> Array[Item]: return medical.carried_potions()
func potion_count(type: String = "") -> int: return medical.potion_count(type)
func _use_potion() -> void: medical._use_potion()
func use_potion_type(type: String) -> bool: return medical.use_potion_type(type)
func drink(item: Item) -> bool: return medical.drink(item)
func _tick_auto_potion(delta: float) -> void: medical._tick_auto_potion(delta)
func current_contamination() -> float: return medical.current_contamination()
func contamination_rate() -> float: return medical.contamination_rate()
func field_feature_rate(map: String) -> float: return medical.field_feature_rate(map)
func contamination_visible() -> bool: return medical.contamination_visible()
func _tick_medical(delta: float) -> void: medical._tick_medical(delta)
func buy_potion(type: String) -> bool: return medical.buy_potion(type)
func potion_price(type: String) -> int: return medical.potion_price(type)
func injury_price(id: String) -> int: return medical.injury_price(id)
func treat_injury(id: String = "") -> bool: return medical.treat_injury(id)

## Fills a freshly built floor, in a fixed order (in-run resume replays it
## from the saved rng states): enemies, herd, 强化装置, points of interest,
## lamps, the floor's set pieces, traps and trace, glow, car, fires, shower.
func _spawn_wave() -> void:
	if world_map.boss_layout:
		_spawn_boss_floor()
		return
	var profile := FieldCatalog.depth_profile(floor_number)
	# 用户 2026-10-23: 根据层数增加外勤敌人数量，但要保持掉落不过于波动 — one
	# more ordinary enemy every DEPTH_ENEMY_STEP floors; their loot is thinned
	# so the floor's total stays where it was (drop_share).
	var deeper := depth_enemies(floor_number)
	_extra_ordinary = deeper
	var info := routes.route_node_info()
	var calm := bool(info.get("calm", false))
	_spawn_ordinary(info, profile, deeper)
	_spawn_herd(calm)
	_place_buff_post(info)
	var kinds := _plan_poi_kinds(info)
	_spawn_pois(kinds, calm)
	var work_lights := _poi_work_lights()
	_spawn_floor_content(calm)
	_light_floor(work_lights)
	if not calm and not world_map.roadblock.is_empty() and floor_number % FieldCatalog.CAMP_INTERVAL != 0: _spawn_car()
	_spawn_fires()
	map_features._spawn_shower()
	if route_kind == "rest": routes._spawn_rest_pieces()
	threat.plan_floor(region_id, floor_enemies().size())

## The ordinary enemies, defending their own origin along the main route.
## Search encounters have their own budget, so no region leaves reward spurs
## bare. 用户 2026-10-17: 增加敌人数量 — 9 + the route node's and the depth
## profile's share. They stand on the odd route points (an even one can be a
## bridge deck); once there are more enemies than points, they share them in
## groups, spread evenly along the route.
func _spawn_ordinary(info: Dictionary, profile: Dictionary, deeper: int) -> void:
	var count: int = roundi((9 + int(info.enemies) + int(profile.enemies) + deeper) * float(info.get("mult", 1.0)))
	var extra_elites: int = int(profile.elites) + int(info.get("elites", 0))
	var slots := maxi(1, world_map.main_path.size() / 2)
	var at_slot := {}
	for i in range(count):
		var elite := (i % 3 == 2 if region_id == "snow" else i == count - 1) or (route_deep() and i == count - 2)
		if not elite and extra_elites > 0 and i % 3 == 1:
			elite = true
			extra_elites -= 1
		# The news (elite): a share more, or fewer, of them elites.
		var elite_news := field_mult("elite")
		if elite_news > 1.0 and not elite and rng_floor.randf() < (elite_news - 1.0) * 0.5: elite = true
		elif elite_news < 1.0 and elite and i != count - 1 and rng_floor.randf() < (1.0 - elite_news) * 2.0: elite = false
		var ranged := not elite and (i % 2 == 1 if region_id == "snow" else i % 4 == 2)
		var slot := i if count <= slots else i * slots / count
		var point: Vector2 = world_map.main_path[mini(1 + slot * 2, world_map.main_path.size() - 1)]
		var shared: int = at_slot.get(slot, 0)
		at_slot[slot] = shared + 1
		if shared > 0: point += Vector2.from_angle(shared * 2.1) * 1.4
		var type := ""
		if region_id == "mine" and not elite and i % 6 in [1, 2, 3]:
			# Three slugs share one encounter pocket.
			type = "slug"
			point = world_map.main_path[mini(3 + (i / 6) * 12, world_map.main_path.size() - 1)] + Vector2((i % 6 - 2) * 1.0, 0)
		elif region_id == "mine" and not elite and i % 6 == 4: type = "crossbow"
		else: type = _pick_enemy_type(elite, ranged)
		_spawn_enemy(Vector3(point.x, 0, point.y), elite, ranged, type)

## 萨米: a herd of 岩角兽 grazing off the route half the time (装备扩充 §2.1).
func _spawn_herd(calm: bool) -> void:
	if region_id == "snow" and not calm and world_map.main_path.size() > 8 and rng_floor.randf() < 0.5:
		_herd_count += 1
		var spot: Vector2 = world_map.main_path[world_map.main_path.size() / 2]
		for h in range(rng_floor.randi_range(3, 5)):
			var beast := _spawn_enemy(Vector3(spot.x + (h % 3 - 1) * 1.4, 0, spot.y + (h / 3) * 1.4 + 2.0), false, false, "rock_hornbeast")
			beast.herd = _herd_count

## The 强化装置 and its guard. 临时休整 and 诡异行商 (用户 2026-10-31) have no
## device and nobody standing guard (§4.1).
func _place_buff_post(info: Dictionary) -> void:
	if info.get("no_device", false):
		_buff_taken = true
		if is_instance_valid(world_map.buff_device_node): world_map.buff_device_node.visible = false
	else: _spawn_guard_post(world_map.buff_position, "强化装置", false)

## The kind of every point of interest, one per cache position (掉落物策划案
## §4.1): 得偿所愿's two more points first, then the kit points last.
func _plan_poi_kinds(info: Dictionary) -> Array[String]:
	# 得偿所愿: two more points of interest (§4.1).
	if int(info.get("pois", 0)) > 0: routes._add_wish_points(int(info.pois))
	# 矿场勘探图 and 下城区黑市名录 (势力声望解锁策划案 §三): their points go last.
	var kit_kinds: Array[String] = []
	if floor_kit_on("矿场勘探图"):
		for k in range(FactionRewards.SURVEY_VEINS): kit_kinds.append("ore_vein")
	if floor_kit_on("下城区黑市名录"): kit_kinds.append("safe")
	if not kit_kinds.is_empty(): routes._add_wish_points(kit_kinds.size())
	# Every authored supply pocket pays off, including the optional loop.
	var places: Array = world_map.cache_positions.map(func(at: Vector3) -> String: return world_map.district_at(Vector2(at.x, at.z)))
	var kinds := LootTables.plan_points(region_id, world_map.cache_positions.size(), rng_floor, places)
	for k in range(kit_kinds.size()): kinds[kinds.size() - kit_kinds.size() + k] = kit_kinds[k]
	return kinds

## A box at every cache position, with its guards, mimic and pile.
func _spawn_pois(kinds: Array[String], calm: bool) -> void:
	# 叙拉古: a family mansion's court keeps its safe, guarded at the gate
	# (叙拉古方案 §3.2: 死路藏宝，门口有守卫).
	var mansions: Array[bool] = []
	for i in range(world_map.cache_positions.size()):
		var at: Vector3 = world_map.cache_positions[i]
		mansions.append(world_map.is_mansion(world_map.room_at(Vector2(at.x, at.z))))
		if mansions[i]: kinds[i] = "safe"
	var mimic_placed := false
	for i in range(world_map.cache_positions.size()):
		var box := LootContainer.new()
		box.game = self
		box.kind = kinds[i]
		# 用户 2026-10-14: 兴趣点旁边随机刷新守卫 — two to six (2026-10-23), a big
		# squad now and then led by an elite (and paying for it).
		var guards: int = POI_GUARDS[LootTables._pick_weighted(POI_GUARD_WEIGHTS, rng_floor)] if not calm else 0
		if region_id == "snow" and kinds[i] == "camp": guards = maxi(guards, 2)
		if mansions[i]: guards = maxi(guards, 2)
		box.guarded = guards > 0 and (route_deep() or rng_floor.randf() < (0.45 if guards >= 5 else 0.12))
		# 巨壳藤蔓 waits inside one weapon or tool box now and then (萨米).
		if region_id == "snow" and not mimic_placed and kinds[i] in ["weapon_box", "tool_box"] and rng_floor.randf() < 0.25:
			box.mimic = true
			mimic_placed = true
		box.variant = _poi_variant(kinds[i], world_map.cache_positions[i])
		add_child(box)
		box.global_position = world_map.cache_positions[i]
		if rng_floor.randf() < PILE_CHANCE: _spawn_pile(box)
		# 陷落雪祀 guards the tundra camps.
		if guards > 0:
			_spawn_guard_post(box.global_position, box.title(), box.guarded, "fallen_snowpriest" if region_id == "snow" and kinds[i] == "camp" else "", guards)

## A work light at every search point, so the eye is drawn to them in the
## dark (地图表现调研 §2: light leads; 兴趣点策划案_v1.md §4).
func _poi_work_lights() -> Array[Dictionary]:
	var work_lights: Array[Dictionary] = []
	for at in world_map.cache_positions:
		work_lights.append({"at": at + Vector3.UP * 1.2, "color": Color(0.75, 0.6, 0.38), "radius": 4.5})
	return work_lights

## Sentinels, wanderers, the floor's own set pieces (outpost, route node,
## bounty, recruit, lost operator, handover), then traps and the trace.
func _spawn_floor_content(calm: bool) -> void:
	if not calm and route_kind != "trader": _spawn_sentinels()
	if not calm: _spawn_wanderers()
	_set_drop_share()
	if is_outpost_floor(): _spawn_outpost()
	routes._spawn_route_content()
	if is_bounty_floor() and not is_instance_valid(_bounty) and not routes._bounty_on_map(): _spawn_bounty()
	if is_recruit_floor(): _spawn_recruit()
	if not lost_here().is_empty(): _spawn_lost()
	if is_handover_floor(): _spawn_handover()
	if floor_number % FieldCatalog.CAMP_INTERVAL != 0:
		if not calm: _spawn_traps()
		_spawn_trace()

## The faint glow (用户 2026-10-17: 幽幽的光) of a trace and of a sealed vault's
## edge, and a camp's lamps, handed to the dressing with the work lights.
func _light_floor(work_lights: Array[Dictionary]) -> void:
	if is_instance_valid(trace_point):
		var wide := 1.5 if RecruitCatalog.is_big(trace_point.key) else 1.0
		work_lights.append({"at": trace_point.global_position + Vector3.UP * 0.8, "color": trace_point.glow * TracePoint.GLOW_GAIN, "radius": TracePoint.GLOW_RADIUS * wide * research.glow_factor()})
	if world_map.vault_seal != null:
		var lamp: Dictionary = world_map.vault_seal.glow_lamp()
		lamp.radius = float(lamp.radius) * research.glow_factor()   # 情报部 1 阶
		work_lights.append(lamp)
	if route_kind == "camp": work_lights.append_array(routes._spawn_camp_pieces())
	if is_instance_valid(world_map.terrace_dressing): world_map.terrace_dressing.add_lamps(work_lights)

# --- The route map's floors and 不期而遇 (肉鸽路线图策划案 v0.2 §4–§5; GmRoute) ---------

## The route map's choices, its nodes' content and the 不期而遇 (GmRoute).
var routes := GmRoute.new(self)
var event_node: Node3D:
	get: return routes.event_node
	set(value): routes.event_node = value
var rest_fire: FirePit:
	get: return routes.rest_fire
	set(value): routes.rest_fire = value
var dire_foe: Enemy:
	get: return routes.dire_foe
	set(value): routes.dire_foe = value
var _wish_posts: Array:
	get: return routes._wish_posts
	set(value): routes._wish_posts = value
var _event_guards: Array[Enemy]:
	get: return routes._event_guards
	set(value): routes._event_guards = value
var _floor_relics: Array:
	get: return routes._floor_relics
	set(value): routes._floor_relics = value
var witness_marked: bool:
	get: return routes.witness_marked
	set(value): routes.witness_marked = value

## A boss floor (Boss战场地策划案 Q5): the boss in its arena and nothing else —
## no enemies, posts, boxes, traps or traces in the other rooms. A contract's
## own target on this floor (寻访, 交付, 悬赏) still comes.
func _spawn_boss_floor() -> void:
	if is_instance_valid(world_map.buff_device_node): world_map.buff_device_node.visible = false
	_buff_taken = true
	_spawn_outpost()
	if is_instance_valid(arena): arena.spawn_civilians()
	if is_bounty_floor(): _spawn_bounty()
	if is_recruit_floor(): _spawn_recruit()
	if not lost_here().is_empty(): _spawn_lost()
	if is_handover_floor(): _spawn_handover()
	_spawn_fires()
	map_features._spawn_shower()
	threat.plan_floor(region_id, floor_enemies().size())

## This floor's enemies still standing (not the grazing herds).
func floor_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return e.game == self and not e._dead and not e.attack_profile.get("neutral", false))

# --- 地图特色 (地图特色策划案_v1_0.md) ----------------------------------------------

## 地图特色: kits, fires, the shower, supplies (GmFeatures).
var map_features := GmFeatures.new(self)
const SEALED_ORE := GmFeatures.SEALED_ORE
var fires: Array[FirePit]:
	get: return map_features.fires
	set(value): map_features.fires = value
var shower: ShowerPoint:
	get: return map_features.shower
	set(value): map_features.shower = value
var shower_progress: float:
	get: return map_features.shower_progress
	set(value): map_features.shower_progress = value
var fuel_fire: FirePit:
	get: return map_features.fuel_fire
	set(value): map_features.fuel_fire = value
var force_shower: bool:
	get: return map_features.force_shower
	set(value): map_features.force_shower = value

## Kept for the callers outside (GmFeatures).
func chosen_kits(region: String) -> Array[String]: return map_features.chosen_kits(region)
func toggle_kit(id: String, region: String) -> void: map_features.toggle_kit(id, region)
func kit_on(id: String, region: String) -> bool: return map_features.kit_on(id, region)
func kit_refusal(id: String) -> String: return map_features.kit_refusal(id)
func buy_kit(id: String) -> bool: return map_features.buy_kit(id)
func shown_features() -> Array[String]: return map_features.shown_features()
func feature_value(kind: String) -> float: return map_features.feature_value(kind)
func feature_rate(kind: String) -> float: return map_features.feature_rate(kind)
func cold_rate() -> float: return map_features.cold_rate()
func warm_fire() -> FirePit: return map_features.warm_fire()
func _tick_features(delta: float) -> void: map_features._tick_features(delta)
func _spawn_fires() -> void: map_features._spawn_fires()
func near_fire() -> FirePit: return map_features.near_fire()
func pack_fuels() -> Dictionary: return map_features.pack_fuels()
func burn_fuel(id: String, fire: FirePit = null) -> bool: return map_features.burn_fuel(id, fire)
func _start_shower() -> void: map_features._start_shower()
func use_supply(item: Item) -> bool: return map_features.use_supply(item)
func seal_with_sealer(ore: Item) -> bool: return map_features.seal_with_sealer(ore)
func supply_price(id: String) -> int: return map_features.supply_price(id)
func supply_item(id: String) -> Item: return map_features.supply_item(id)
func closure_buy_supply(id: String) -> bool: return map_features.closure_buy_supply(id)
func camp_cleanse_refusal() -> String: return map_features.camp_cleanse_refusal()
func camp_cleanse() -> bool: return map_features.camp_cleanse()
func camp_debt_refusal() -> String: return map_features.camp_debt_refusal()
func camp_pay_debt() -> bool: return map_features.camp_pay_debt()
func feud_damage(enemy: Enemy) -> float: return map_features.feud_damage(enemy)
func feud_sight(enemy: Enemy) -> float: return map_features.feud_sight(enemy)

# --- 威胁值 (ThreatMeter, 用户 2026-10-14) ------------------------------------------

## Whether the meter fills right now: on a floor while the field runs, and
## while 坎诺特's shop is open; never in a camp, on a calm node or a map-less
## 不期而遇, or near the Rhodes squad.
func threat_rising() -> bool:
	if in_base or in_camp or in_event or transitioning or _settled or not is_instance_valid(player): return false
	if not simulation_active() and modal != "trader": return false
	if bool(routes.route_node_info().get("calm", false)): return false
	return not near_squad()

func near_squad() -> bool:
	return encounter == "squad" and is_instance_valid(world_map.encounter_node) and world_map.encounter_node.visible 		and player.global_position.distance_to(world_map.encounter_node.global_position) < ThreatMeter.SQUAD_CALM_RADIUS

## The wave a "being tracked" line was given for (博士主角叙事修订案 §4).
var _tracked_warned := -1

func _tick_threat(delta: float) -> void:
	var boost := (1.0 + ThreatMeter.SENTINEL_BOOST * alerted_sentinels()) * field_mult("threat") * research.threat_factor() * potion_fx.threat_mult() * player.families.threat_mult() * (ROUTE_THREAT_CUT if route_threat_cut else 1.0) * (FactionRewards.PASS_THREAT if floor_kit_on("近卫局通行证") else 1.0)
	if threat.add(threat.per_second() * boost * delta):
		_spawn_patrol()
	elif player.families.tier("stealth") >= 4 and threat.ratio() >= STEALTH_WARN_AT and _patrol_warned != threat.wave:
		# 潜伏 (4) 预警: where the next patrol will come in from.
		_patrol_warned = threat.wave
		_next_patrol_entry = _patrol_entry()
		broadcast("PRTS：博士，巡逻队即将从%s方进入。" % _direction_name(_next_patrol_entry - player.global_position))
	elif threat.ratio() >= ThreatMeter.TRACKED_AT and _tracked_warned != threat.wave:
		_tracked_warned = threat.wave
		broadcast("PRTS：博士，信号正在被追踪。")

## Sentinels with their "!" up right now.
func alerted_sentinels() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("sentinels"):
		if e.game == self and e.alerted(): n += 1
	return n

## A 萨卡兹哨兵 has seen her and runs.
func on_sentinel_spotted(_sentinel: Enemy) -> void:
	broadcast("PRTS：萨卡兹哨兵发现了博士的踪迹。")

## The next patrol onto this floor: stronger with every wave here.
func _spawn_patrol() -> void:
	threat.wave += 1
	if int(floor_kits.get("残党暗号", 0)) == 1:
		floor_kits["残党暗号"] = 2
		broadcast("PRTS：残党的暗号起了作用，这一队巡逻没有进来。")
		return
	_spawn_squad(threat.wave, false)
	broadcast("PRTS：博士，搜捕巡逻队进入本层。")

## 清算 (地图特色策划案 §4.4): 叙拉古's 血债 at 90 sends the families, their own
## count of reckonings making them stronger as patrols grow; they take their share.
func _spawn_reckoning() -> void:
	features.reckoning_sent()
	_spawn_squad(features.reckonings, true)
	broadcast("PRTS：博士，清算时刻。家族的人进入本层。")

## A patrol of wave `wave`: PATROL_SIZE, an elite from PATROL_ELITE_FROM on;
## a reckoning brings a 家族灭迹人 too.
func _spawn_squad(wave: int, reckoning_squad: bool) -> void:
	var at := _patrol_entry() if _next_patrol_entry == Vector3.INF or reckoning_squad else _next_patrol_entry
	if not reckoning_squad: _next_patrol_entry = Vector3.INF
	var power := ThreatMeter.strength(wave)
	var with_elite := wave >= ThreatMeter.PATROL_ELITE_FROM
	var size := ThreatMeter.PATROL_SIZE + (1 if with_elite else 0)
	for i in range(size):
		var elite := with_elite and i == 0
		var ranged := not elite and i == size - 1
		var offset := Vector3(float(i % 2) * 1.4 - 0.7, 0.0, float(i / 2) * 1.4 - 0.7)
		var enemy := _spawn_enemy(at + offset, elite, ranged, _pick_enemy_type(elite, ranged))
		enemy.configure_patrol(wave)
		enemy.max_health *= power.x
		enemy.health = enemy.max_health
		enemy.atk *= power.y
		if reckoning_squad: enemy.add_to_group("reckoning")
	# Every reckoning brings one 家族灭迹人, who leaves the patrol and closes in
	# on her unseen (叙拉古敌人设计案 §三第 6 条).
	if reckoning_squad:
		var eraser := _spawn_enemy(at + Vector3(1.6, 0.0, 1.6), true, false, "family_eraser")
		eraser.configure_patrol(wave)
		eraser.max_health *= power.x
		eraser.health = eraser.max_health
		eraser.atk *= power.y
		eraser.add_to_group("reckoning")

## 用户 2026-10-14: 增加游荡敌人. A few small groups on the floor from the
## start, walking waypoint to waypoint (Enemy.configure_wander) and chasing
## whatever they see: never the first rooms, so the entry is quiet.
## 用户 2026-10-17: 3–5 groups (was 2–4); 用户 2026-10-23: 更多巡逻敌人, 5–8.
const WANDER_GROUPS := Vector2i(5, 8)

## Enemies by depth (用户 2026-10-23): one more on the main route every
## DEPTH_ENEMY_STEP floors (up to DEPTH_ENEMY_MAX), one more wandering group
## every DEPTH_WANDER_STEP (up to DEPTH_WANDER_MAX); ordinary ones only.
const DEPTH_ENEMY_STEP := 10
const DEPTH_ENEMY_MAX := 6
const DEPTH_WANDER_STEP := 20
const DEPTH_WANDER_MAX := 3
## The ordinary enemies this floor has over the old count, and the share of
## ordinary kills that roll loot so the floor's total holds (spawn_enemy_drops).
var _extra_ordinary := 0
var drop_share := 1.0

static func depth_enemies(depth: int) -> int:
	return mini(DEPTH_ENEMY_MAX, (maxi(depth, 1) - 1) / DEPTH_ENEMY_STEP)

static func depth_wanderers(depth: int) -> int:
	return mini(DEPTH_WANDER_MAX, (maxi(depth, 1) - 1) / DEPTH_WANDER_STEP)

func _set_drop_share() -> void:
	var ordinary := floor_enemies().filter(func(e: Enemy) -> bool: return not e.elite and not e.boss).size()
	drop_share = clampf(1.0 - float(_extra_ordinary) / maxf(1.0, float(ordinary)), 0.3, 1.0) if ordinary > 0 else 1.0
## Guards at a point of interest and their odds (用户 2026-10-23: 守卫改为 2~6 人):
## two to six, the small squads likelier (was 0–3 at 15/20/35/30).
const POI_GUARDS := [2, 3, 4, 5, 6]
const POI_GUARD_WEIGHTS := [25.0, 25.0, 20.0, 15.0, 15.0]
## The old squads' average guards a point (0–3 at 15/20/35/30): 1.8.
const OLD_GUARDS_MEAN := 1.8

## The share of ordinary guards that drop anything: the old average over the new.
static func guard_drop_share() -> float:
	var total := 0.0
	var weight := 0.0
	for i in range(POI_GUARDS.size()):
		total += float(POI_GUARDS[i]) * float(POI_GUARD_WEIGHTS[i])
		weight += float(POI_GUARD_WEIGHTS[i])
	return clampf(OLD_GUARDS_MEAN / (total / weight), 0.0, 1.0)
const WANDER_CLEAR := 30.0

func _spawn_wanderers() -> void:
	var path: PackedVector2Array = world_map.main_path
	if path.size() < 6: return
	var spots: Array[Vector2] = []
	for p in path:
		if p.distance_to(Vector2(ContinuousWorldMap.ENTRY_POSITION.x, ContinuousWorldMap.ENTRY_POSITION.z)) >= WANDER_CLEAR: spots.append(p)
	if spots.is_empty(): return
	var rid := world_map.navigation_map_rid()
	var groups := rng_floor.randi_range(WANDER_GROUPS.x, WANDER_GROUPS.y)
	var extra_groups := depth_wanderers(floor_number)
	groups += extra_groups
	while groups > 0 and not spots.is_empty():
		var at: Vector2 = spots.pop_at(rng_floor.randi_range(0, spots.size() - 1))
		# Only ground she can walk to from the entry (not a deck over the road).
		var start := world_map.nearest_walkable(Vector3(at.x, 0.0, at.y))
		var walk := NavigationServer3D.map_get_path(rid, ContinuousWorldMap.ENTRY_POSITION, start, true)
		if walk.size() < 2 or walk[walk.size() - 1].distance_to(start) > 1.5: continue
		groups -= 1
		var size := 1 if rng_floor.randf() < 0.3 else 2
		if groups < extra_groups: _extra_ordinary += size
		for k in range(size):
			var ranged := k == 1 and region_id != "mine"
			var point := start if k == 0 else world_map.nearest_walkable(start + Vector3(1.4, 0.0, 0.0))
			var enemy := _spawn_enemy(point, false, ranged, _pick_enemy_type(false, ranged))
			enemy.configure_wander()

## 潜伏 (4): the warning goes out at this share of the meter, once a wave.
const STEALTH_WARN_AT := 0.85
var _patrol_warned := -1
var _next_patrol_entry := Vector3.INF

## "东北" for a ground offset, as the camera faces north by default.
func _direction_name(offset: Vector3) -> String:
	var angle := fposmod(rad_to_deg(atan2(offset.x, -offset.z)), 360.0)
	return ["北", "东北", "东", "东南", "南", "西南", "西", "西北"][int(roundf(angle / 45.0)) % 8]

## 隔离 (前缀放大与特效阶等案 §3): contamination down by `amount`.
func cleanse_contamination(amount: float) -> void:
	run_contamination = maxf(0.0, current_contamination() - amount)

## How near her a hunting patrol aims, and how far she may move off that
## point before it aims again (Enemy._wander).
const PATROL_NEAR := Vector2(2.0, 7.0)
const PATROL_RETARGET := 10.0

## A main-path point SPAWN_MIN–SPAWN_MAX from her, clear of the exit, the
## encounter spot and the route markers; else the farthest clear one.
func _patrol_entry() -> Vector3:
	var keep_clear: Array[Node3D] = [world_map.exit_node, world_map.encounter_node]
	keep_clear.append_array(world_map.route_nodes)
	var fits: Array[Vector3] = []
	var farthest := player.global_position
	var far := -1.0
	for p in world_map.main_path:
		var at := Vector3(p.x, 0.0, p.y)
		var clear := true
		for node in keep_clear:
			if is_instance_valid(node) and Vector2(node.global_position.x - at.x, node.global_position.z - at.z).length() < 6.0: clear = false
		if not clear: continue
		var d := Vector2(at.x - player.global_position.x, at.z - player.global_position.z).length()
		if d >= ThreatMeter.SPAWN_MIN and d <= ThreatMeter.SPAWN_MAX: fits.append(at)
		if d > far:
			far = d
			farthest = at
	return fits[rng_floor.randi() % fits.size()] if not fits.is_empty() else farthest

## Where a wanderer walks next: anywhere on the main path or at a search
## point. A patrol hunting her (用户 2026-10-24: 巡逻队寻路改为朝玩家方向)
## heads for the ground a few metres round where she is now.
func patrol_waypoint(_from: Vector3, toward_player: bool = false) -> Vector3:
	if toward_player and is_instance_valid(player):
		var off := Vector2.from_angle(rng_floor.randf() * TAU) * rng_floor.randf_range(PATROL_NEAR.x, PATROL_NEAR.y)
		return world_map.nearest_walkable(player.global_position + Vector3(off.x, 0.0, off.y))
	var count := world_map.main_path.size() + world_map.cache_positions.size()
	if count == 0: return _from
	var pick := rng_floor.randi() % count
	if pick < world_map.main_path.size():
		var p: Vector2 = world_map.main_path[pick]
		return world_map.nearest_walkable(Vector3(p.x, 0.0, p.y))
	return world_map.nearest_walkable(world_map.cache_positions[pick - world_map.main_path.size()])

## 萨卡兹哨兵 keep watch beside the main path: at most one a floor, on
## SENTINEL_CHANCE of floors (用户 2026-10-14: 刷新少一点，每一层限定最多一个).
## Patrols never bring one: they draw from the region pools only.
func _spawn_sentinels() -> void:
	var path: PackedVector2Array = world_map.main_path
	if path.size() < 8 or rng_floor.randf() >= ThreatMeter.SENTINEL_CHANCE: return
	var index := clampi(int(path.size() * rng_floor.randf_range(0.3, 0.65)), 2, path.size() - 2)
	var along := (path[index + 1] - path[index - 1]).normalized()
	var side := Vector2(-along.y, along.x) * 2.0
	_spawn_enemy(Vector3(path[index].x + side.x, 0.0, path[index].y + side.y), false, true, "sentinel")

## 物品堆 (用户 2026-10-24): now and then a point of interest has more of its
## kind round it, PILE_EXTRA of them a few metres off, on its own level.
const PILE_CHANCE := 0.05
const PILE_EXTRA := Vector2i(3, 5)
const PILE_REACH := Vector2(1.8, 4.5)
const PILE_GAP := 1.6

func _spawn_pile(first: LootContainer) -> void:
	var at := first.global_position
	var lift := at.y - ground_y(at)
	var placed: Array[Vector3] = [at]
	var want := rng_floor.randi_range(PILE_EXTRA.x, PILE_EXTRA.y)
	for probe in range(want * 24):
		if placed.size() > want: break
		var off := Vector2.from_angle(rng_floor.randf() * TAU) * rng_floor.randf_range(PILE_REACH.x, PILE_REACH.y)
		var spot := world_map.nearest_walkable(Vector3(at.x + off.x, 0.0, at.z + off.y))
		var flat := Vector2(spot.x, spot.z)
		if flat.distance_to(Vector2(at.x, at.z)) > PILE_REACH.y + 0.5 or not world_map._is_open(flat.x, flat.y, -0.8): continue
		if absf(ground_y(spot) - ground_y(at)) > 0.6: continue
		if placed.any(func(p: Vector3) -> bool: return Vector2(p.x, p.z).distance_to(flat) < PILE_GAP): continue
		var box := LootContainer.new()
		box.game = self
		box.kind = first.kind
		box.variant = first.variant
		box.guarded = first.guarded
		add_child(box)
		box.global_position = Vector3(spot.x, ground_y(spot) + lift, spot.z)
		placed.append(box.global_position)

## A mine search point dressed for where it stands (兴趣点策划案_v1.md §3): the
## loot is the kind's own, only the look and the name follow the place.
func _poi_variant(kind: String, at: Vector3) -> String:
	if region_id != "mine" or not is_instance_valid(world_map.terrace_dressing): return ""
	var dressing: TerraceDressing = world_map.terrace_dressing
	var flat := Vector2(at.x, at.z)
	var near := func(points: Array, reach: float) -> bool:
		for t in points:
			if Vector2(t.origin.x, t.origin.z).distance_to(flat) < reach: return true
		return false
	match kind:
		"ore_vein": if near.call(dressing.rail_pieces, 4.0): return "ore_cart"
		"tool_box": if near.call(dressing.frame_posts, 6.0) or near.call(dressing.post_points, 5.0): return "miner_locker"
		"electronics": if near.call(dressing.headframe_points, 10.0): return "winch_box"
		"medical":
			for niche in world_map.niche_centres:
				if niche.distance_to(flat) < 6.0: return "miner_pack"
	return ""

## The outpost holds the ground just before the route markers (Boss与守卫者策划案
## §3.1): the 20th floors the region's boss alone, the 10th between a warden
## with its OUTPOST_GUARDS guards.
func _spawn_outpost() -> void:
	var spot := Vector2(world_map.route_guard_position.x, world_map.route_guard_position.z)
	var at := Vector3(spot.x, 0, spot.y)
	if BossCatalog.is_boss_floor(floor_number):
		outpost_boss = _spawn_boss(str(BossCatalog.BOSSES.get(region_id, "patriot")), BossCatalog.boss_tier(floor_number), at)
		_outpost_squad.append(outpost_boss)
		return
	outpost_boss = _spawn_boss(str(BossCatalog.WARDENS.get(region_id, "crownslayer")), BossCatalog.warden_tier(floor_number), at)
	_outpost_squad.append(outpost_boss)
	for i in range(FieldCatalog.OUTPOST_GUARDS):
		var side := -1.0 if i % 2 == 0 else 1.0
		var guard := _spawn_enemy(Vector3(spot.x + side * 1.8, 0, spot.y + 1.2), false, i == 1 and region_id != "mine")
		_outpost_squad.append(guard)
		outpost_boss.guards.append(guard)

## A boss or warden `id` of `tier` at `at`, with the floor's depth and the relics on it.
func _spawn_boss(id: String, tier: int, at: Vector3) -> Boss:
	var figure := Boss.new()
	add_child(figure)
	figure.global_position = world_map.nearest_walkable(at) + Vector3.UP * 0.65
	figure.global_position.y = ground_y(figure.global_position) + Enemy.GROUND_LIFT
	figure.setup_boss(self, id, tier)
	var growth := Scaling.floor_growth(floor_number)
	figure.max_health *= growth * (1.0 + (EnemyAttacks.SNOW_HP_BONUS if region_id == "snow" else 0.0))
	figure.max_health *= enemy_life_multiplier(player.f("enemy_hp")) * contract_life()
	figure.atk *= growth * contract_attack()
	figure.defense *= growth
	figure.finish_setup()
	figure.died.connect(_on_enemy_died)
	return figure

## Fighting the floor's region boss right now (the threat meter waits, Q5).
func boss_fight() -> bool:
	return is_instance_valid(outpost_boss) and outpost_boss.in_fight()

func on_boss_engaged(figure: Boss) -> void:
	sound.play("stun_hum")
	if BossShow.enabled: BossShow.of(self).intro(figure)
	broadcast("PRTS：博士，%s。" % BossCatalog.display_name(figure.figure_id))

func on_boss_reset(_figure: Boss) -> void:
	broadcast("PRTS：博士，目标脱离接触，已恢复。")

## What PRTS says on entering an outpost floor.
func _outpost_line() -> String:
	if BossCatalog.is_boss_floor(floor_number):
		return "PRTS：前方是%s的战场。击破之后，入口才会开放。" % BossCatalog.display_name(str(BossCatalog.BOSSES.get(region_id, "")))
	return "PRTS：%s守在入口前。击破守卫者，入口才会开放。" % BossCatalog.display_name(str(BossCatalog.WARDENS.get(region_id, "")))

## The first fall of this region's boss at this tier is recorded (§10).
func _first_boss_fall() -> void:
	base.boss_falls["%s:%d" % [region_id, BossCatalog.boss_tier(floor_number)]] = true

## A warden's clearing: WARDEN_EXCLUSIVE for one of the region's enemy exclusives.
func _warden_exclusive(at: Vector3) -> void:
	if rng_loot.randf() >= BossCatalog.WARDEN_EXCLUSIVE: return
	var ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "exclusive" and str(SpecialGear.GEAR[id].region) == region_id)
	if ids.is_empty(): return
	var item := SpecialGear.create(ids[rng_loot.randi() % ids.size()], floor_number, rng_loot, true)
	item.origin_region = region_id
	_drop_at(at, [{"item": item}], 0.7)

## The hunt contract's bounty: an elite with HUNT_HP life on its floor, marked.
func is_bounty_floor() -> bool:
	return not in_camp and str(contract.get("type", "")) == "hunt" and not bounty_killed and floor_number == start_floor + int(contract.offset)

func _spawn_bounty() -> void:
	var path: Array = world_map.main_path
	var spot: Vector2 = path[path.size() / 2]
	_bounty = _spawn_enemy(Vector3(spot.x, 0, spot.y), true, false)
	_bounty.boss = true
	_bounty.max_health *= FieldCatalog.HUNT_HP
	_bounty.health = _bounty.max_health

## The dispatch desk's offers for `region`, rolled when missing, and after
## them a 寻访合同 for each operator of the region whose traces are all in
## (§2.2: 排在 3 张普通卡之外，完成之前一直在).
func contract_offers(region: String) -> Array:
	if not base.contract_offers.has(region) or (base.contract_offers[region] as Array).size() < FieldCatalog.CONTRACT_OFFERS:
		base.contract_offers[region] = FieldCatalog.roll_contracts(region, rng_base)
	# 外勤部 1 阶: the fourth kind as well.
	var held: Array = base.contract_offers[region]
	while base.researched("offer_slot") and held.size() < contract_offer_count():
		var kinds := held.map(func(c): return str(c.type))
		for extra in FieldCatalog.roll_contracts(region, rng_base):
			if not str(extra.type) in kinds:
				held.append(extra)
				break
	# The first contract is fixed (主线 苏醒): 切尔诺伯格 · 回收 源岩.
	if region == "mine" and Story.count(base.story, "contract") == 0 and Story.is_on():
		var first: Dictionary = (base.contract_offers[region] as Array)[0]
		if str(first.get("type", "")) != "recover" or str(first.get("material", "")) != "源岩":
			(base.contract_offers[region] as Array)[0] = {"type": "recover", "material": "源岩", "count": 6}
	# The pay's random share goes with the offer (v1.1 §2.2).
	for offer: Dictionary in base.contract_offers[region]:
		if not offer.has("roll"): offer.roll = snappedf(rng_base.randf_range(Economy.CONTRACT_ROLL.x, Economy.CONTRACT_ROLL.y), 0.01)
	var offers: Array = (base.contract_offers[region] as Array).duplicate()
	for id in RecruitCatalog.in_region(region):
		if base.recruit_ready(id): offers.append(RecruitCatalog.contract_for(id))
	offers.append_array(voyage.delivery_offers(region))
	return offers

## Ordinary offers at the dispatch desk: 3, 4 with 外勤部 1 阶.
func contract_offer_count() -> int:
	return FieldCatalog.CONTRACT_OFFERS + (1 if base.researched("offer_slot") else 0)

## 外勤部 2 阶: swaps ordinary offer `index` of `region` for a fresh one of another
## kind, once per return.
func reroll_contract(region: String, index: int) -> bool:
	if not in_base or not base.contract_reroll or not base.contract_offers.has(region): return false
	var held: Array = base.contract_offers[region]
	if index < 0 or index >= held.size(): return false
	var kinds := []
	for i in range(held.size()):
		if i != index: kinds.append(str(held[i].type))
	# A roll can come back with only kinds already held; try a few.
	for attempt in range(8):
		for fresh in FieldCatalog.roll_contracts(region, rng_base):
			if str(fresh.type) in kinds: continue
			fresh.roll = snappedf(rng_base.randf_range(Economy.CONTRACT_ROLL.x, Economy.CONTRACT_ROLL.y), 0.01)
			held[index] = fresh
			base.contract_reroll = false
			save_base()
			return true
	return false

## What a contract pays, as its card and the settlement show it: the pay fixed
## when it was taken, or what it would be from `start_floor` (v1.1 §2.2).
func contract_pay_text(c: Dictionary, start_floor: int = -1) -> String:
	if not Economy.pays_contract_reward(c): return FieldCatalog.contract_bonus_text(c)
	var pay: int = int(c.reward) if c.has("reward") else roundi(Economy.contract_reward(c, maxi(start_floor, 1)) * research.contract_bonus() / 10000.0) * 100
	var parts: Array[String] = ["%s 龙门币" % Economy.format(pay)]
	if str(c.type) == "hunt": parts.append("稀有装备 ×1")
	return " · ".join(parts)

# --- 叙拉古 (叙拉古敌人设计案 §三, §四.1) -----------------------------------------

## 血债 from a fall (用户 2026-10-16: 血债杀人涨): its own weight, and CAPO_DEBT
## for every 家族角头 within CAPO_DEBT_RADIUS (itself included). The
## reckoning's own patrols add nothing, or one would call the next.
func _siracusa_death(enemy: Enemy) -> void:
	if enemy.attack_profile.get("roadblock", false): _wreck_car(enemy)
	if enemy.patrol_wave > 0: return
	var debt := float(enemy.attack_profile.get("debt", 0.0))
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == null or other.game != self or other.enemy_type != "family_capo": continue
		if other._dead and other != enemy: continue
		if other.global_position.distance_to(enemy.global_position) <= EnemyAttacks.CAPO_DEBT_RADIUS: debt += EnemyAttacks.CAPO_DEBT
	if debt > 0.0: add_debt(debt)

## 血债 (地图特色策划案 §4.2): a fall, a 家族术师's 煽动, at the old weights
## times DEBT_SCALE; faster deeper, with the voyage's feud (沙盘航行策划案) and
## the crest worn, slower with the broker's letter.
func add_debt(amount: float) -> void:
	if region_id != "siracusa" or potion_fx.debt_block > 0.0: return
	var mult := FeatureCatalog.DEBT_SCALE * features.growth_mult("debt", floor_number) * voyage.debt_mult(region_id) * field_feature_rate("siracusa")
	if player.equipped_effect("saluzzo_crest"): mult *= 1.0 + FeatureCatalog.CREST_DEBT
	features.add("debt", amount * mult * (player.elements.feature_mult("debt") if is_instance_valid(player) and player.elements != null else 1.0))

## 清算时刻: a reckoning is still standing on this 叙拉古 floor.
func reckoning() -> bool:
	if region_id != "siracusa": return false
	if is_instance_valid(outpost_boss) and outpost_boss.reckoning_active(): return true
	return get_tree().get_nodes_in_group("reckoning").any(func(e): return e.game == self and not e._dead)

## 家族专用轿车 in its lane's mouth (§三第 7 条), and the body that stops her
## there; both go when it is broken.
var _car: Enemy
var _car_block: StaticBody3D

func _spawn_car() -> void:
	var block: Dictionary = world_map.roadblock
	var at: Vector2 = block.at
	var along: Vector2 = block.along
	_car = _spawn_enemy(Vector3(at.x, 0, at.y), true, false, "family_car")
	_car.home_position = _car.global_position
	# Nose to the piazza it guards.
	_car.nose = -Vector3(along.x, 0.0, along.y)
	_car._face(_car.nose, 1.0)
	_car_block = StaticBody3D.new()
	_car_block.name = "CarBlock"
	_car_block.add_to_group("world_obstacle")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.6, 4.4)
	shape.shape = box
	_car_block.add_child(shape)
	world_map._generated_root.add_child(_car_block)
	var x := Vector3(along.y, 0.0, -along.x)
	_car_block.global_transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(at.x, ground_y(Vector3(at.x, 0, at.y)) + 0.8, at.y))

## Broken: the lane opens at once; broken from close by, CAR_SOLDIERS soldiers get out.
func _wreck_car(car: Enemy) -> void:
	if is_instance_valid(_car_block): _car_block.queue_free()
	_car_block = null
	if player.global_position.distance_to(car.global_position) > EnemyAttacks.CAR_DROP_REACH: return
	for i in range(EnemyAttacks.CAR_SOLDIERS):
		var offset := Vector3(cos(i * TAU / 3.0), 0.0, sin(i * TAU / 3.0)) * 1.6
		_spawn_enemy(car.global_position + offset, false, false, "family_soldier")
	broadcast("PRTS：车里还有人！")

# --- 陷阱 (密室与陷阱修订案_v1 §2.2) ------------------------------------------------

## This floor's traps (FieldTrap), each one spent when sprung.
var traps: Array[FieldTrap] = []
const TRAPS := Vector2i(4, 7)
## On a floor with a vault, at least this share of them lie within VAULT_TRAP_REACH
## of its wall, on the near side: where traps crowd, look for a wall.
const VAULT_TRAP_SHARE := 0.5
const VAULT_TRAP_REACH := 12.0

func _spawn_traps() -> void:
	traps.clear()
	var count := rng_floor.randi_range(TRAPS.x, TRAPS.y)
	var near_vault := ceili(count * VAULT_TRAP_SHARE) if world_map.has_vault else 0
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < count and tries < count * 30:
		tries += 1
		var at: Vector3
		if placed.size() < near_vault:
			var mouth: Vector2 = world_map.vault_mouth
			var inward: Vector2 = world_map.vault_inward
			var spot := mouth - inward * rng_floor.randf_range(1.5, VAULT_TRAP_REACH) + Vector2(-inward.y, inward.x) * rng_floor.randf_range(-5.0, 5.0)
			at = world_map.nearest_walkable(Vector3(spot.x, 0, spot.y))
			if Vector2(at.x, at.z).distance_to(mouth) > VAULT_TRAP_REACH: continue
		else:
			var path: PackedVector2Array = world_map.main_path
			var room: Vector2 = path[rng_floor.randi_range(1, path.size() - 1)]
			at = world_map.nearest_walkable(Vector3(room.x + rng_floor.randf_range(-7, 7), 0, room.y + rng_floor.randf_range(-7, 7)))
		if not _trap_spot_ok(at, placed): continue
		placed.append(at)
		var trap := FieldTrap.new()
		trap.name = "Trap"
		trap.setup(self, "heavy" if rng_floor.randf() < 0.4 else "light", region_id)
		world_map._generated_root.add_child(trap)
		trap.global_position = Vector3(at.x, ground_y(at), at.z)
		traps.append(trap)

func _trap_spot_ok(at: Vector3, placed: Array[Vector3]) -> bool:
	var flat := Vector2(at.x, at.z)
	if world_map.vault_hidden(flat): return false
	if flat.distance_to(Vector2(ContinuousWorldMap.ENTRY_POSITION.x, ContinuousWorldMap.ENTRY_POSITION.z)) < 8.0: return false
	for other in placed:
		if other.distance_to(at) < 3.0: return false
	var marks: Array = [world_map.buff_position, world_map.encounter_position, world_map.route_guard_position]
	marks.append_array(world_map.cache_positions)
	if is_instance_valid(world_map.exit_node): marks.append(world_map.exit_node.position)
	for node in world_map.route_nodes: marks.append(node.position)
	if is_instance_valid(recruit_node): marks.append(recruit_node.global_position)
	if is_instance_valid(lost_node): marks.append(lost_node.global_position)
	if is_instance_valid(handover_node): marks.append(handover_node.global_position)
	for child in get_children():
		if child is GuardPost: marks.append((child as GuardPost).global_position)
	for mark in marks:
		if Vector2((mark as Vector3).x, (mark as Vector3).z).distance_to(flat) < 4.0: return false
	return true

## A trap went off under her: the 威胁值 rises (用户 2026-10-17: 挂钩).
func trap_sprung(amount: float) -> void:
	if research.on("traps"): return   # 课题 陷阱预警
	if threat.add(amount): _spawn_patrol()

# --- 踪迹点 and 寻访点 (干员寻访策划案 §2, §13) ------------------------------------

## This floor's trace, if one was left: at a dead end, for one of the region's
## operators still being sought; fewer on floors shallow for her operator.
var trace_point: TracePoint
## Leave one whatever the roll (tests and captures).
var force_trace := false

func _spawn_trace() -> void:
	trace_point = null
	var sought := _sought_here()
	if sought.is_empty(): return
	var p := progress()
	var suited := RecruitCatalog.suited_floor(p.elite, p.level) if p != null else 1
	var sure := force_trace or route_kind == "fate" or bool(floor_mods.get("trace", false))
	if not sure and rng_floor.randf() >= RecruitCatalog.trace_chance(floor_number, suited) * research.trace_factor(): return
	var ends: Array[Vector2] = []
	ends.append_array(world_map.niche_centres)
	for centre in world_map.branch_centres: ends.append(Vector2(centre.x, centre.y))
	ends.append_array(world_map.loop_centres)
	ends.shuffle()
	for end in ends:
		var at := world_map.nearest_walkable(Vector3(end.x + rng_floor.randf_range(-2, 2), 0, end.y + rng_floor.randf_range(-2, 2)))
		if not _trap_spot_ok(at, []): continue
		var keys: Array[String] = RecruitCatalog.TRACE_BIG if rng_floor.randf() < RecruitCatalog.BIG_SHARE else RecruitCatalog.TRACE_SMALL
		trace_point = TracePoint.new()
		trace_point.setup(sought[rng_floor.randi() % sought.size()], self, keys[rng_floor.randi() % keys.size()])
		world_map._generated_root.add_child(trace_point)
		trace_point.global_position = Vector3(at.x, ground_y(at), at.z)
		return

func _take_trace() -> void:
	var id := trace_point.operator
	var key := trace_point.key
	trace_point.collect(player)
	trace_point = null
	var before := base.clues(id)
	var repeat := base.found_before(id, key)
	var gain := base.add_trace(id, key)
	var have := base.clues(id)
	if gain == 0:
		broadcast("PRTS：博士，这条踪迹之前已经记录过了。")
	elif before == 0:
		broadcast("PRTS：博士，%s附近有人留下了踪迹。" % RecruitCatalog.RECRUITS[id].place)
	elif have >= RecruitCatalog.CLUES_NEEDED:
		broadcast("PRTS：博士，%s的行踪已经确认。调度台可以接寻访合同了。" % Operators.display_name(id))
	elif repeat:
		broadcast("PRTS：博士，这条踪迹记录过，但又多了些细节。")
	set_message("踪迹 · %s %d/%d" % [Operators.display_name(id), have, RecruitCatalog.CLUES_NEEDED])

## The operators of this region still being sought.
func _sought_here() -> Array[String]:
	var sought: Array[String] = []
	for id in RecruitCatalog.in_region(region_id):
		if not base.recruited(id) and base.clues(id) < RecruitCatalog.CLUES_NEEDED: sought.append(id)
	return sought

## A trace of one of this region's operators still being sought (§13): PRTS
## speaks up at the first and when they are all in.
func _find_clue(id: String = "") -> void:
	if id.is_empty():
		var sought := _sought_here()
		if sought.is_empty(): return
		id = sought[rng_loot.randi() % sought.size()]
	var first := base.add_clue(id)
	var have := base.clues(id)
	if first: broadcast("PRTS：博士，%s附近有人留下了踪迹。" % RecruitCatalog.RECRUITS[id].place)
	elif have >= RecruitCatalog.CLUES_NEEDED: broadcast("PRTS：博士，%s的行踪已经确认。调度台可以接寻访合同了。" % Operators.display_name(id))
	set_message("踪迹 · %s %d/%d" % [Operators.display_name(id), have, RecruitCatalog.CLUES_NEEDED])

func is_recruit_floor() -> bool:
	return not in_camp and str(contract.get("type", "")) == "recruit" and not recruit_met and floor_number == start_floor + int(contract.offset)

## Her 寻访点 (§2.2): she stands in her idle on the trunk two thirds of the way
## in, with a squad round her led by an elite; she can be spoken to once it is down.
func _spawn_recruit() -> void:
	var id := str(contract.operator)
	var path: Array = world_map.main_path
	var spot: Vector2 = path[clampi(path.size() * 2 / 3, 0, path.size() - 1)]
	var at := world_map.nearest_walkable(Vector3(spot.x, 0, spot.y))
	recruit_node = _operator_figure(id)
	world_map._generated_root.add_child(recruit_node)
	recruit_node.global_position = Vector3(at.x, ground_y(at) + ContinuousWorldMap.ENTRY_POSITION.y, at.z)
	_recruit_post = _spawn_guard_post(at, Operators.display_name(id), true, "", RecruitCatalog.GUARDS)

## An operator standing in her idle, facing the camera (her S idle row).
static func _operator_figure(id: String) -> Node3D:
	var idle: Texture2D = LapplandAnimator3D.sheet(id, "idle")
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", LapplandAnimator3D.IDLE_FPS)
	frames.set_animation_loop("default", true)
	for column in range(2):
		var atlas := AtlasTexture.new()
		atlas.atlas = idle
		atlas.region = Rect2(column * LapplandAnimator3D.CELL_TEXELS, 0, LapplandAnimator3D.CELL_TEXELS, LapplandAnimator3D.CELL_TEXELS)
		frames.add_frame("default", atlas)
	var sprite := AnimatedSprite3D.new()
	sprite.name = "Recruit_" + id
	sprite.sprite_frames = frames
	sprite.pixel_size = LapplandAnimator3D.PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.position.y = LapplandAnimator3D.CELL_TEXELS * LapplandAnimator3D.PIXEL_SIZE * 0.5 - LapplandAnimator3D.FOOT_DROP
	var holder := Node3D.new()
	holder.name = "RecruitPoint"
	holder.add_child(sprite)
	sprite.play("default")
	return holder

## The squad round her is down.
func recruit_guard_cleared() -> bool:
	if _recruit_post == null or not is_instance_valid(_recruit_post): return true
	for enemy in _recruit_post.guards:
		if is_instance_valid(enemy) and not enemy._dead: return false
	return true

func _recruit_nearby() -> bool:
	return not recruit_met and is_instance_valid(recruit_node) and near(recruit_node)

func _meet_recruit() -> void:
	if not recruit_guard_cleared():
		notice("先击退她身边的敌人。")
		return
	recruit_met = true
	var name := Operators.display_name(str(contract.operator))
	set_message("寻访 · %s 同意随行" % name)
	broadcast("PRTS：%s同意随博士返回罗德岛。撤离后完成入职。" % name)

# --- 失散干员 (失散干员与主线流程策划案 v0.2 §5) ------------------------------------

## Each of the region's missing operators gets her floor for this contract:
## her base floor ±2, rolled afresh every time (用户 2026-11-01: 每次外勤重掷).
func _roll_lost(region: String) -> void:
	lost_floor = {}
	for id in LostCatalog.in_region(region):
		if base.lost_back(id): continue
		var f := LostCatalog.roll(id, start_floor, rng_base)
		if f > 0: lost_floor[id] = f

## Who is on this floor ("" for nobody, or once she is back).
func lost_here() -> String:
	if in_camp: return ""
	for id in lost_floor:
		if int(lost_floor[id]) == floor_number and not base.lost_back(str(id)): return str(id)
	return ""

## She stands far along the trunk, a squad round her; the minimap shows her
## from the start, and PRTS speaks up as the floor opens.
func _spawn_lost() -> void:
	lost_id = lost_here()
	_lost_warned = false
	var at := _lost_spot()
	lost_node = _operator_figure(LostCatalog.figure_id(lost_id))
	lost_node.name = "LostPoint"
	world_map._generated_root.add_child(lost_node)
	lost_node.global_position = Vector3(at.x, ground_y(at) + ContinuousWorldMap.ENTRY_POSITION.y, at.z)
	_lost_post = _spawn_guard_post(at, LostCatalog.name_of(lost_id), true, "", LostCatalog.GUARDS)
	broadcast("PRTS：博士，本层检测到%s的识别信号。" % LostCatalog.name_of(lost_id))
	if is_instance_valid(tutorial_spotlight): tutorial_spotlight.request("lost_signal", Hud.MAP_RECT)

## Far along the trunk (17/20 of the way), on open ground: clear of boxes and
## veins, the exit, the way down and other posts, so E by her is hers alone.
const LOST_CLEAR := 6.0
func _lost_spot() -> Vector3:
	var path: Array = world_map.main_path
	var last := path.size() - 1
	var home := clampi(path.size() * 17 / 20, 0, last)
	var marks: Array = [world_map.buff_position, world_map.encounter_position, world_map.route_guard_position]
	marks.append_array(world_map.cache_positions)
	if is_instance_valid(world_map.exit_node): marks.append(world_map.exit_node.position)
	for node in world_map.route_nodes: marks.append(node.position)
	if is_instance_valid(recruit_node): marks.append(recruit_node.global_position)
	for group in ["loot_containers", "relic_caches", "fire_pits"]:
		for node in get_tree().get_nodes_in_group(group): marks.append((node as Node3D).global_position)
	for child in get_children():
		if child is GuardPost: marks.append((child as GuardPost).global_position)
	for offset in range(0, path.size()):
		for i in [home - offset, home + offset]:
			if i < path.size() / 2 or i > last: continue
			var at := world_map.nearest_walkable(Vector3(path[i].x, 0, path[i].y))
			var flat := Vector2(at.x, at.z)
			if marks.all(func(m): return m == null or Vector2((m as Vector3).x, (m as Vector3).z).distance_to(flat) >= LOST_CLEAR): return at
	return world_map.nearest_walkable(Vector3(path[home].x, 0, path[home].y))

func lost_guard_cleared() -> bool:
	if _lost_post == null or not is_instance_valid(_lost_post): return true
	for enemy in _lost_post.guards:
		if is_instance_valid(enemy) and not enemy._dead: return false
	return true

func _lost_nearby() -> bool:
	return not lost_id.is_empty() and not base.lost_back(lost_id) and is_instance_valid(lost_node) and near(lost_node)

## E by her: once the squad is down she is back on board at once (§5.2) —
## a retreat later this contract does not undo it.
func _meet_lost() -> void:
	if not lost_guard_cleared():
		if not _lost_warned: broadcast("PRTS：先清理周围的敌人，博士。")
		_lost_warned = true
		return
	var id := lost_id
	base.find_lost(id)
	lost_node.queue_free()
	lost_node = null
	save_base(true)
	broadcast("PRTS：罗德岛小队已接应%s。" % LostCatalog.name_of(id))
	set_message("%s 已归队" % LostCatalog.name_of(id))
	if is_instance_valid(story_card): story_card.talk_lost(id)
	if is_instance_valid(tutorial_spotlight): tutorial_spotlight.request("lost_joined")

func is_handover_floor() -> bool:
	return not in_camp and str(contract.get("type", "")) == "deliver" and not cargo_delivered and floor_number == int(contract.floor)

const HANDOVER_MODEL := "res://art/kit/base_cargo_cart.glb"

## The faction's people and their cart, halfway along the trunk (§5.3).
func _spawn_handover() -> void:
	var path: Array = world_map.main_path
	var spot: Vector2 = path[clampi(path.size() / 2, 0, path.size() - 1)]
	var at := world_map.nearest_walkable(Vector3(spot.x, 0, spot.y))
	handover_node = world_map._set_piece("交接点 · E", at, Color("c48cff"), HANDOVER_MODEL)

func _handover_nearby() -> bool:
	return is_handover_floor() and is_instance_valid(handover_node) and near(handover_node)

## The contract's crate in her pack, or null.
func carried_cargo() -> Item:
	var o := voyage.order(int(contract.get("order", 0)))
	var crate := voyage.cargo_item(o) if not o.is_empty() else null
	return crate if crate != null and carried_items().has(crate) else null

func _hand_over_cargo() -> void:
	var crate := carried_cargo()
	if crate == null:
		notice("背包里没有这张订单的大宗货箱。")
		return
	inventory.remove(crate)
	safe_bag.remove(crate)
	cargo_delivered = true
	voyage.handed_over(int(contract.order))
	set_message("运送完成 · %s" % FactionCatalog.name_of(str(contract.faction)))
	broadcast("PRTS：大宗货箱已交给%s的接头人。" % FactionCatalog.name_of(str(contract.faction)))

## {goal, have, need, done} for the running contract, or {} without one.
func contract_progress() -> Dictionary:
	if contract.is_empty(): return {}
	var have := 0
	var need := 1
	match str(contract.type):
		"deep":
			need = int(contract.steps)
			have = clampi(floor_number - start_floor, 0, need)
		"recover":
			need = int(contract.count)
			have = inventory.count_material(contract.material) + safe_bag.count_material(contract.material)
		"hunt": have = 1 if bounty_killed else 0
		"recruit": have = 1 if recruit_met else 0
		"deliver": have = 1 if cargo_delivered else 0
		"search":
			need = int(contract.vaults)
			have = contract_vaults
	return {"goal": FieldCatalog.contract_goal(contract, region_id, start_floor), "have": have, "need": need, "done": have >= need}

func _tick_contract() -> void:
	if contract.is_empty() or _contract_announced: return
	var progress := contract_progress()
	if not progress.done: return
	_contract_announced = true
	set_message("合同目标完成：%s" % progress.goal)
	broadcast("合同目标完成：%s。" % progress.goal)

## One rare (purple) piece of this region's gear: the hunt bounty's, and now
## and then a patrol's.
func _rare_gear() -> Item:
	var category: int = GearSlots.roll(rng_loot)
	var id := GearCatalog.pick(category, region_id, floor_number, "vault", "", rng_loot)
	return LootTables.roll_equipment(category, GearCatalog.BASES[id].name, region_id, floor_number, Item.PURPLE, rng_loot)

## How far a boss's loot sprays, and its chests stand, from where it fell.
const BOSS_SPRAY := 2.4
const BOSS_CHEST_OFF := 3.4

func _clear_outpost(at: Vector3) -> void:
	outpost_cleared = true
	var chest := LootContainer.new()
	chest.game = self
	chest.kind = "vault_gear"
	chest.vault = true
	add_child(chest)
	var region_boss := BossCatalog.is_boss_floor(floor_number)
	var off := BOSS_CHEST_OFF if region_boss and BossShow.enabled else 1.5
	chest.global_position = world_map.nearest_walkable(at + Vector3(off, 0, 0))
	# A boss gives BOSS_CHESTS chests (Boss与守卫者策划案 §10); its own kill already left a boss-grade cache.
	if region_boss:
		for i in range(BossCatalog.BOSS_CHESTS - 1):
			var more := LootContainer.new()
			more.game = self
			more.kind = "vault_gear"
			more.vault = true
			add_child(more)
			more.global_position = world_map.nearest_walkable(at + Vector3(off, 0, 1.6 * (i + 1)))
		_first_boss_fall()
		if BossShow.enabled:
			for node in get_children():
				if node is LootContainer and (node as LootContainer).vault and node.global_position.distance_to(at) < BOSS_CHEST_OFF + 4.0:
					BossShow.of(self).chest_rise(node)
	else:
		_warden_exclusive(at)
		_spawn_relic_cache(world_map.nearest_walkable(at - Vector3(1.5, 0, 0)), "vault", false)
	if is_instance_valid(arena): arena.open_exit()
	set_message("据点已击破：入口解封。")
	broadcast("据点已击破，深入入口解封。")

func _spawn_enemy(position: Vector3, elite: bool, ranged: bool, type: String = "") -> Enemy:
	var enemy := Enemy.new()
	add_child(enemy)
	# Asked-for positions are not always walkable — a caller offsetting from the
	# player can easily land in rock — and an enemy has no collider to stop it
	# standing there, so the spawn is pulled onto real ground first.
	enemy.global_position = world_map.nearest_walkable(position) + Vector3.UP * 0.65
	enemy.global_position.y = ground_y(enemy.global_position) + Enemy.GROUND_LIFT # Navigation voxel height is not the actor's ground height.
	enemy.setup(self, elite, ranged, type)
	# Scaling.floor_growth for life, attack and defence alike (复利数值改造清单 A).
	var growth := Scaling.floor_growth(floor_number)
	enemy.max_health *= growth * (1.0 + (EnemyAttacks.SNOW_HP_BONUS if region_id == "snow" else 0.0))
	enemy.max_health *= enemy_life_multiplier(player.f("enemy_hp")) * contract_life()
	enemy.health = enemy.max_health
	enemy.atk *= growth * contract_attack()
	enemy.defense *= growth
	# The floor's node multiplies life and attack (RouteMap "stat", e.g. 深部污染).
	var stat := float(routes.route_node_info().get("stat", 1.0)) if not in_base and not in_camp else 1.0
	# 源石活性异常 (不期而遇): the next floor's enemies with less life.
	enemy.max_health *= stat * float(floor_mods.get("weak", 1.0))
	enemy.health = enemy.max_health
	enemy.atk *= stat
	enemy.died.connect(_on_enemy_died)
	return enemy

## Herds spawned so far; each beast carries its herd's number.
var _herd_count := 0
## An ordinary slot's enemy from the region pool (EnemyAttacks.REGION_POOLS).
func _pick_enemy_type(elite: bool, ranged: bool) -> String:
	var pools: Dictionary = EnemyAttacks.REGION_POOLS.get(region_id, {})
	var role := "elite" if elite else ("ranged" if ranged else "normal")
	var pool: Array = pools.get(role, [])
	if pool.is_empty(): return ""
	var type := str(pool[rng_floor.randi_range(0, pool.size() - 1)])
	if not market_field.is_empty(): type = _field_enemy(type, role, pool)
	return type

## How far from its point a guard stands: anywhere between.
const GUARD_REACH := Vector2(2.0, 5.6)

func _spawn_guard_post(anchor: Vector3, title: String, elite_guard: bool = false, first_type: String = "", count: int = 2) -> GuardPost:
	var post := GuardPost.new()
	post.game = self
	post.title = title
	post.planned = count
	post.position = Vector3(anchor.x, ground_y(anchor), anchor.z)
	add_child(post)
	var stations: Array[Vector3] = []
	var rid := world_map.navigation_map_rid()
	var from := NavigationServer3D.map_get_closest_point(rid, Vector3(anchor.x, ground_y(anchor), anchor.z))
	# Separated stations the guards can walk to from the point: first with
	# room to stand, then (a crowded point) anywhere open. Reachability is read
	# off the navmesh, so no ring can put a guard over a cliff in a pocket.
	for strict in [true, false]:
		for index in range(count - stations.size()):
			for probe in range(160):
				# 用户 2026-10-24: 守卫站位随机 — any side, any distance, not a ring.
				var angle := rng_floor.randf() * TAU
				var ring := rng_floor.randf_range(GUARD_REACH.x, GUARD_REACH.y)
				var offset := Vector2.from_angle(angle) * ring
				var candidate := Vector3(anchor.x + offset.x, 0.0, anchor.z + offset.y)
				candidate.y = ground_y(candidate) + Enemy.GROUND_LIFT
				var flat := Vector2(candidate.x, candidate.z)
				if strict and not world_map._has_clearance(flat): continue
				if not strict and not world_map._is_open(flat.x, flat.y, -0.8): continue
				var crowded := false
				for other in stations:
					if candidate.distance_to(other) < 2.0: crowded = true
				if crowded: continue
				var closest := NavigationServer3D.map_get_closest_point(rid, candidate)
				if Vector2(closest.x, closest.z).distance_to(flat) > 0.5: continue
				var path := NavigationServer3D.map_get_path(rid, from, closest, true)
				if path.size() < 2 or path[-1].distance_to(closest) > 0.6: continue
				var walk := 0.0
				for k in range(1, path.size()): walk += path[k - 1].distance_to(path[k])
				if walk > ring * 2.2 + 1.0: continue
				stations.append(candidate)
				break
		if stations.size() >= count: break
	for i in range(stations.size()):
		var elite := elite_guard and i == 0
		# Every third a ranged one in a big squad (none in the mine).
		var ranged := not elite and i % 3 == 1 and region_id != "mine"
		post.add_guard(_spawn_enemy(stations[i], elite, ranged, first_type if i == 0 else ""))
	return post

## Whether this kill drops a combat cache (RelicCatalog.CACHE_CHANCE).
func rolls_relic_cache(enemy: Enemy) -> bool:
	return rng_loot.randf() < float(RelicCatalog.CACHE_CHANCE[RelicCatalog.cache_kind(enemy)])

func _on_enemy_died(_enemy: Enemy) -> void:
	if not in_base: award_kill(_enemy)
	if not in_base and region_id == "siracusa": _siracusa_death(_enemy)
	player.on_kill(_enemy)
	if _enemy == _bounty:
		bounty_killed = true
		_bounty = null
	if _enemy == dire_foe:
		dire_foe = null
		routes._dire_spoils(_enemy.global_position)
	if _enemy in _event_guards:
		_event_guards.erase(_enemy)
		if _event_guards.is_empty() and not routes._event_prize.is_empty():
			_drop_at(_enemy.global_position, routes._event_prize, 0.9)
			routes._event_prize = []
	for entry in _wish_posts:
		var guards: Array = entry[1]
		if not guards.has(_enemy): continue
		guards.erase(_enemy)
		# A floor read back from a save holds no fallen guards (RunSave).
		guards = guards.filter(func(e): return is_instance_valid(e) and not e._dead and not e.is_queued_for_deletion())
		entry[1] = guards
		if guards.is_empty() and is_instance_valid(entry[0]):
			entry[0].sealed = false
			set_message("得偿所愿：一个藏品箱的封印解除。")
	if _enemy in _outpost_squad:
		_outpost_squad.erase(_enemy)
		if _outpost_squad.is_empty() and not outpost_cleared: _clear_outpost(_enemy.global_position)
	# A vault guardian still counts for its vault, whether or not it dropped a cache.
	# Patrols do not count toward combat caches (用户 2026-10-14).
	if not in_base and _enemy.patrol_wave == 0 and not _enemy.called_in and rolls_relic_cache(_enemy):
		_spawn_relic_cache(_drop_spot(_enemy.global_position, Vector2(0.0, 1.2)), "cache", false, true)
		set_message("战斗缴获：附近出现了藏品箱，靠近按 E 选择一件藏品。")
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
	# Depth works through LootTables.stair (掉落阶梯); the route adds its own reward.
	var reward := float(routes.route_node_info().reward)
	return {"region": region_id, "depth": floor_number, "reward": reward, "rng": rng_loot, "pity": base.loot_pity, "set_seen": run_sets_seen,
		"drop_pct": player.drop_rate_bonus if is_instance_valid(player) else 0.0, "field": market_field.get("mult", {})}

func _roll_named_item() -> Item: return FieldCatalog.exclusive(region_id)

func spawn_enemy_drops(enemy: Enemy) -> void:
	_drop_heal_orbs(enemy)
	# What a boss calls in mid-fight carries nothing (用户 2026-10-20).
	if enemy.called_in: return
	# A patrol carries nothing ordinary: now and then one rare piece (ThreatMeter).
	if enemy.patrol_wave > 0:
		if rng_loot.randf() < ThreatMeter.rare_chance(enemy.patrol_wave, enemy.elite):
			_drop_at(enemy.global_position, [{"item": _rare_gear()}], 0.7)
		return
	# Deeper floors field more ordinary enemies, each a little leaner, so the
	# floor's loot stays steady (drop_share); the bounty always pays.
	if not enemy.elite and not enemy.boss and enemy != _bounty and drop_share < 1.0 and rng_loot.randf() > drop_share: return
	# 用户 2026-10-24: 压低守卫掉落 — twice the guards a point (2–6) carry what the
	# old 0–3 did between them.
	if not enemy.elite and not enemy.boss and enemy.behavior == Enemy.Behavior.GUARD and rng_loot.randf() > guard_drop_share(): return
	_drop_records(enemy)
	# The hunt's bounty carries the contract's rare piece (v1.1 §2.1: no settlement gifts).
	if enemy == _bounty and str(contract.get("type", "")) == "hunt":
		_drop_at(enemy.global_position, [{"item": _rare_gear()}], 0.9)
	var ctx := loot_ctx()
	ctx["boss"] = enemy.boss
	# A region boss drops its own nine pieces more often the deeper it is; a
	# warden rolls a region exclusive on clearing instead (§10).
	if enemy is Boss:
		var figure := enemy as Boss
		ctx["exclusive_chance"] = BossCatalog.exclusive_chance(figure.tier) if figure.rank == "boss" else 0.0
		if figure.rank == "warden": ctx["set_chance"] = BossCatalog.WARDEN_SET
	var drops := LootTables.enemy_drops(enemy.enemy_type, enemy.elite, enemy.behavior == Enemy.Behavior.GUARD, ctx)
	# 巨壳藤蔓 was the box: it gives the box's contents and one more share.
	if not enemy.mimic_kind.is_empty():
		drops.append_array(LootTables.container_drops(enemy.mimic_kind, ctx, true))
		drops.append_array(LootTables.container_drops(enemy.mimic_kind, ctx, false))
	var owed := orirock_owed()
	if owed > 0: drops.append({"item": MaterialCatalog.create(FIRST_RUN_ORE, owed, region_id)})
	# A boss's loot sprays out round where it fell (Boss演出策划案_v0_2 §1.2), clear of its husk.
	_drop_at(enemy.global_position, drops, BOSS_SPRAY if enemy is Boss and BossShow.enabled else 0.7)

## 作战记录 as loot (龙门币平衡与科研部策划案 v1.1 §2.1), the old settlement's
## expectation: one basic per RECORD_NORMAL_ODDS⁻¹ ordinary kills, 初级 from
## every elite, 中级 from every leader, 高级 from bosses, wardens and bounties.
## The 作战记录整理 project adds its share as a chance of one more.
const RECORD_NORMAL_ODDS := 0.1

func _drop_records(enemy: Enemy) -> void:
	if in_base or enemy.attack_profile.get("neutral", false): return
	var record := ""
	if enemy is Boss or enemy == _bounty: record = "高级作战记录"
	elif enemy.boss: record = "中级作战记录"
	elif enemy.elite: record = "初级作战记录"
	elif rng_loot.randf() < RECORD_NORMAL_ODDS: record = "基础作战记录"
	if record.is_empty(): return
	var count := 1 + (1 if rng_loot.randf() < research.record_bonus() else 0)
	_drop_at(enemy.global_position, [{"item": MaterialCatalog.create(record, count, region_id)}], 0.8)

## Healing orbs out of a fallen enemy (LootTables.HEAL_ORBS); none from the
## grazing herds.
func _drop_heal_orbs(enemy: Enemy) -> void:
	if in_base or enemy.attack_profile.get("neutral", false): return
	var roll: Dictionary = LootTables.HEAL_ORBS[LootTables.source_of(enemy.elite, enemy.behavior == Enemy.Behavior.GUARD)]
	if rng_loot.randf() >= float(roll.chance): return
	for i in range(int(roll.count)):
		var orb := HealOrb.new()
		orb.game = self
		orb.fraction = float(roll.heal)
		orb.from = enemy.global_position + Vector3.UP * 0.6
		var at := _drop_spot(enemy.global_position)
		at.y = ground_y(at)
		add_child(orb)
		orb.global_position = at

## Where something a fallen enemy leaves lands: `reach` metres from it (0 at
## the near end tries the spot itself first), on ground that needs no moving.
## nearest_walkable pulls a spot on a ramp, in a corridor or by a prop into the
## nearest room, up to 12 m off: heal orbs flew there and relic caches stood
## there (用户 2026-10-31: 治疗球会飞走). With no such spot round it, where it fell.
func _drop_spot(fell_at: Vector3, reach := Vector2(0.6, 1.2)) -> Vector3:
	if not is_instance_valid(world_map): return fell_at
	if reach.x <= 0.0:
		var kept := world_map.nearest_walkable(fell_at)
		if Vector2(kept.x - fell_at.x, kept.z - fell_at.z).length() < 0.05: return fell_at
	var turn := rng_loot.randf() * TAU
	for k in range(8):
		var angle := turn + TAU * k / 8.0
		var at := fell_at + Vector3(cos(angle), 0.0, sin(angle)) * rng_loot.randf_range(maxf(reach.x, 0.3), reach.y)
		var kept := world_map.nearest_walkable(at)
		if Vector2(kept.x - at.x, kept.z - at.z).length() < 0.05: return at
	return fell_at

## What an opened box holds, rolled once as items (the per-item search lays
## them out and reveals them), or null when it was a 巨壳藤蔓 that woke instead.
func container_contents(box: LootContainer) -> Variant:
	if box.mimic:
		_wake_mimic(box)
		return null
	sound.play("loot")
	var items: Array[Item] = []
	for drop in LootTables.container_drops(box.kind, loot_ctx(), box.guarded):
		var item := _drop_item(drop)
		if item != null: items.append(item)
	return items

## One searched item out of `box`, into the cell it was laid out in (or any
## free one if she put something there meanwhile); on the ground beside it
## only when the grid is full.
func drop_found(box: LootContainer, item: Item, index: int, total: int) -> void:
	var x := item.grid_x
	var y := item.grid_y
	if not (x >= 0 and box.storage.place(item, x, y)) and not box.storage.try_add(item):
		var angle := TAU * float(index) / maxf(float(total), 1.0) + box.global_position.x
		_drop_at(box.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.2, [{"item": item}], 0.0)
	if index == total: save_base(true)

## A loot-table drop as the item it is: 赤金 for the old reward units, or null
## when they round to nothing.
func _drop_item(drop: Dictionary) -> Item:
	if drop.has("item"): return drop.item
	var bars := Economy.bars_from_reward(float(drop.gold) * player.gold_gain_multiplier * player.elements.gold_mult() * research.gold_factor() * field_mult("gold_drop"), rng_loot)
	if drop.get("single", false): bars = mini(bars, 1)   # a point of interest's 赤金
	return MaterialCatalog.create(Economy.GOLD_ID, bars, region_id) if bars > 0 else null

func _wake_mimic(box: LootContainer) -> void:
	box.mimic = false
	var vine := _spawn_enemy(box.global_position + Vector3(0.8, 0, 0.8), false, false, "shell_vine")
	vine.mimic_kind = box.kind
	vine.begin_chase()
	vine.stun_timer = 0.3
	EnemyAttackVfx.spawn(self, box.global_position + Vector3.UP * 0.4, Vector3(0.8, 0, 0.8).normalized(), "vine_burst")
	box.queue_free()

func on_container_opened(box: LootContainer) -> void:
	if box.mimic:
		box.mimic = false
		var vine := _spawn_enemy(box.global_position + Vector3(0.8, 0, 0.8), false, false, "shell_vine")
		vine.mimic_kind = box.kind
		vine.begin_chase()
		# The lid gapes and the vines lash out for 0.3 s before it gives chase.
		vine.stun_timer = 0.3
		EnemyAttackVfx.spawn(self, box.global_position + Vector3.UP * 0.4, Vector3(0.8, 0, 0.8).normalized(), "vine_burst")
		box.queue_free()
		return
	var drops := LootTables.container_drops(box.kind, loot_ctx(), box.guarded)
	_drop_at(box.global_position, drops, 1.3)
	sound.play("loot")
	save_base(true)

## The first run's 源岩 (用户 2026-10-22: 第一次外勤保证前 5 层至少掉出 6 个源岩，
## 让固定的第一份回收合同一定能完成): while she has never extracted and runs the
## fixed 回收 源岩 contract from CH-01, every 源岩 dropped is counted, and the
## first kill on a floor tops it up to FIRST_RUN_ORE_BY[floor] — front-loaded,
## so floors she clears quickly or skips still leave her the six by floor 5.
const FIRST_RUN_ORE := "源岩"
const FIRST_RUN_ORE_BY := {1: 3, 2: 6, 3: 6, 4: 6, 5: 6}
var first_run_ore := 0

func orirock_owed() -> int:
	if in_base or base.extracted_once or start_floor != 1 or not FIRST_RUN_ORE_BY.has(floor_number): return 0
	if str(contract.get("type", "")) != "recover" or str(contract.get("material", "")) != FIRST_RUN_ORE: return 0
	return maxi(0, int(FIRST_RUN_ORE_BY[floor_number]) - first_run_ore)

## Scatters drops ({"item"} / {"gold"}) in a ring around `position`.
func _drop_at(position: Vector3, drops: Array, radius: float) -> void:
	var start := rng_loot.randf() * TAU
	for i in range(drops.size()):
		var drop: Dictionary = drops[i]
		var loot := Loot.new()
		loot.game = self
		if drop.has("item"):
			loot.item = drop.item
			if not in_base and (drop.item as Item).item_name == FIRST_RUN_ORE: first_run_ore += (drop.item as Item).quantity
		else:
			# The loot tables still speak in old reward units; they land as 赤金.
			var bars := Economy.bars_from_reward(float(drop.gold) * player.gold_gain_multiplier * player.elements.gold_mult() * research.gold_factor() * field_mult("gold_drop"), rng_loot)
			if drop.get("single", false): bars = mini(bars, 1)   # a point of interest's 赤金
			if bars <= 0:
				loot.free()
				continue
			loot.item = MaterialCatalog.create(Economy.GOLD_ID, bars, region_id)
		loot.pickup_delay = 0.35
		loot.from = position + Vector3.UP * 0.6
		add_child(loot)
		var offset := Vector3.ZERO
		if drops.size() > 1 or radius > 1.0:
			var angle := start + TAU * i / maxf(drops.size(), 1)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * radius * rng_loot.randf_range(0.8, 1.2)
		loot.global_position = position + offset + Vector3.UP * 0.1

## Gives `bars` 赤金 (raised by gold-gain effects such as 友谊之证) into the
## pack; what does not fit lands at her feet. Returns how many were given.
func add_gold(bars: int) -> int:
	var given := roundi(bars * player.gold_gain_multiplier * player.elements.gold_mult())
	if given <= 0: return 0
	var left := given
	while left > 0:
		var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)), region_id if not in_base else "")
		left -= stack.quantity
		var rest := inventory.add_stack(stack)
		if rest > 0 and not in_base: _drop_at(player.global_position, [{"item": stack}], 0.8)
	set_message("获得赤金 ×%d" % given)
	return given

## Pays `bars` 赤金 into the pack as they are (a trade, no gold-gain effects);
## what does not fit lands at her feet.
func give_gold_bars(bars: int) -> void:
	var left := bars
	while left > 0:
		var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)), region_id)
		left -= stack.quantity
		if inventory.add_stack(stack) > 0: drop_at_feet(stack)

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

## Hot paths (pickups, bag moves, flasks): one write at the end of the frame,
## with the last call's arguments, as if that call had saved then.
func save_base_soon(active_contract: bool = false, run: Dictionary = {}) -> void:
	saves.save_soon(active_contract, run)

## save_base_soon's deferred write.
func _flush_queued_save() -> void:
	saves.flush()

func save_base(active_contract: bool = false, run: Dictionary = {}) -> void:
	saves.write(active_contract, run)

## A weapon the deployed operator cannot wield (§2.4) goes back to the
## warehouse (the PRTS mail when the shelves are full); true if one was moved.
func shed_unusable_weapon() -> bool:
	var weapon: Item = player.equipped.get(Item.Category.WEAPON)
	if weapon == null or GearCatalog.can_wield(player.operator_id, weapon): return false
	# A Rhodes weapon is swapped for the one she can wield.
	if GearCatalog.bound(weapon):
		return_rhodes(weapon)
		var choices := GearCatalog.rhodes_choices(Item.Category.WEAPON, player.operator_id)
		if not choices.is_empty(): player.equip(GearCatalog.make_rhodes(str(choices[0]), base.rhodes_rarity, player.operator_id))
		return true
	if base.store(weapon).is_empty() and not base.receive(weapon): return false
	player.unequip(Item.Category.WEAPON)
	notice("%s无法使用%s，已放回仓库。" % [Operators.display_name(player.operator_id), weapon.item_name])
	return true

## Rhodes standard gear (制式保底修订, 用户 2026-10-23): free at the workbench
## into a slot for this contract, at BaseState.rhodes_rarity. What she wore
## there goes to its shelf (or the pack); a Rhodes piece is simply replaced.
func issue_rhodes(id: String) -> bool:
	if not in_base or not GearCatalog.is_rhodes(id): return false
	var piece := GearCatalog.make_rhodes(id, base.rhodes_rarity, player.operator_id)
	if not player.equip_refusal(piece).is_empty(): return false
	var previous: Item = player.equipped.get(piece.category)
	if previous != null and not GearCatalog.bound(previous):
		if base.store(previous).is_empty() and not inventory.try_add(previous):
			notice("仓库和背包都满了：%s 留在身上。" % previous.item_name)
			return false
	player.unequip(piece.category)
	player.equip(piece)
	save_base()
	return true

## Every empty slot gets its first Rhodes choice. Returns how many were issued.
func fill_rhodes() -> int:
	if not in_base: return 0
	var issued := 0
	for slot in Item.SLOTS:
		if player.equipped.get(slot) != null: continue
		var choices := GearCatalog.rhodes_choices(slot, player.operator_id)
		if not choices.is_empty() and issue_rhodes(str(choices[0])): issued += 1
	return issued

## A Rhodes piece goes back to logistics: off her and out of her bags.
func return_rhodes(item: Item) -> void:
	if not GearCatalog.bound(item): return
	inventory.remove(item)
	safe_bag.remove(item)
	if player.equipped.get(item.category) == item: player.unequip(item.category)

## The worn Rhodes pieces again at today's rarity (制式换代, an old save's
## pieces); Rhodes pieces in the bags are handed back.
func refresh_rhodes() -> void:
	for item in inventory.items.duplicate() + safe_bag.items.duplicate():
		if GearCatalog.bound(item): return_rhodes(item)
	for slot in Item.SLOTS:
		var worn: Item = player.equipped.get(slot)
		if GearCatalog.bound(worn):
			player.equip(GearCatalog.make_rhodes(worn.base_id, base.rhodes_rarity, player.operator_id))

func load_base() -> void:
	saves.read()

# --- 局内存档 (用户 2026-10-24: 局内保存并退出，读档仍在局内) -----------------------

func can_save_run() -> bool:
	return save_enabled and app_mode.is_empty() and not in_base and not _settled and not transitioning and player.hp > 0.0

func run_snapshot() -> Dictionary:
	var data := {"version": RunSave.VERSION, "now": RunSave.run_data(self), "player": RunSave.player_data(player), "rng": rng_states()}
	if not in_camp and not in_event:
		data["entry"] = _floor_entry
		data["floor"] = RunSave.floor_data(self)
	return data

## Written into the save; the contract stays open (RunSave).
func save_run() -> bool:
	if not can_save_run(): return false
	close_modal()
	save_base(true, run_snapshot())
	return true

## 保存并退出: written, then back to the title.
func save_and_quit() -> void:
	if not save_run() or not is_instance_valid(system_screens): return
	SystemScreens.pending_slot = -1
	# Deferred: the scene leaves the tree at once, and this is still running.
	get_tree().reload_current_scene.call_deferred()

## A saved run picked up again: the floor rebuilt from its dice, then what
## changed on it since laid over it (RunSave.apply_floor).
func resume_run() -> void:
	var saved := _resume
	_resume = {}
	var now: Dictionary = saved.get("now", {})
	var her: Dictionary = (saved.get("player", {}) as Dictionary).duplicate()
	in_base = false
	_settled = false
	transitioning = true
	close_modal()
	base_map.set_active(false)
	research.apply_run(true)
	# Used up: should the game stop before the next save, the contract is
	# settled on loading as before.
	save_base(true)
	if str_to_var(str(now.get("game", {}).get("in_camp", "false"))) == true:
		_resume_mapless(now, her)
		await _build_camp()
		RunSave.apply_run(self, now)
		RunSave.apply_player(self, her)
		set_message("继续合同：%s。" % camp_label(floor_number))
		return
	# A map-less 不期而遇: its card again, or the route map once it is settled.
	if str_to_var(str(now.get("game", {}).get("in_event", "false"))) == true:
		_resume_mapless(now, her)
		RunSave.apply_player(self, her)
		transitioning = false
		if event_done:
			modal = "route"
			menu.show_routes(0)
		else:
			open_modal("event")
			menu.show_event()
		return
	var entry: Dictionary = saved.get("entry", {})
	if entry.has("run"): RunSave.apply_run(self, entry.run)
	else: RunSave.apply_run(self, now)
	refresh_look()
	apply_scene_look(false)
	var base_now := RunSave.base_inputs(base)
	if entry.has("base"): RunSave.set_base_inputs(base, entry.base)
	await _begin_loading()
	_floor_dice(entry if entry.has("rng") else {})
	_build_world()
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await _await_navigation_sync()
	_wave_dice(entry if entry.has("wave") else {})
	_spawn_wave()
	_floor_built()
	if entry.has("rng"): _floor_entry = entry
	RunSave.set_base_inputs(base, base_now)
	RunSave.apply_run(self, now)
	set_rng_states(saved.get("rng", rng_states()))
	if not RunSave.apply_floor(self, saved.get("floor", {})): notice("本层未能按存档复原，已重新布置。")
	RunSave.apply_player(self, her)
	camera.global_position = player.global_position + camera_offset()
	_end_loading()
	transitioning = false
	set_message("继续合同：%s。" % AK.floor_code(region_id, floor_number))

## A camp or a map-less 不期而遇 resumed: the run's state and the field's
## look, her place on a map dropped.
func _resume_mapless(now: Dictionary, her: Dictionary) -> void:
	RunSave.apply_run(self, now)
	refresh_look()
	apply_scene_look(false)
	her.erase("at")

func _configure_camera_and_light() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	var initial_target: Vector3 = ContinuousWorldMap.ENTRY_POSITION
	camera.global_position = initial_target + camera_offset()
	camera.look_at(initial_target, Vector3.UP)
	camera.current = true

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_energy = GmLook.FIELD_SUN
	sun.shadow_enabled = true
	add_child(sun)

	look.build(camera)

# --- The scene's look (场景渲染统一改造案_v1 §4.4; GmLook) --------------------------
const OUTLINE_SHADER := GmLook.OUTLINE_SHADER
const BASE_SUN := GmLook.BASE_SUN
const FIELD_LOOK := GmLook.FIELD_LOOK
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var outline_pass: MeshInstance3D
## The environments, the sun's settings and her own light (GmLook).
var look := GmLook.new(self)

## 罗德岛舰内: cool, even, the lamps and screens carrying the light.
static func base_environment() -> Environment:
	return GmLook.base_environment()

static func field_environment(look_key: String) -> Environment:
	return GmLook.field_environment(look_key)

## Swaps the environment, the sun, the outline and her own light for the base
## or the field (the region read off the floor just built).
func apply_scene_look(base_look: bool) -> void:
	look.apply(base_look)

func _build_player() -> void:
	player = Player.new()
	player.message_requested.connect(set_message)
	player.died.connect(_on_player_died)
	add_child(player)
	player.global_position = ContinuousWorldMap.ENTRY_POSITION

var tutorial_card: TutorialCard
var tutorial_spotlight: TutorialSpotlight
var story_card: StoryCard

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
	tutorial_card = TutorialCard.new()
	tutorial_card.game = self
	layer.add_child(tutorial_card)
	# Over the HUD and the menus' layer, so the dim covers everything but the ring.
	var tips := CanvasLayer.new()
	tips.layer = 6
	(ui_root if is_instance_valid(ui_root) else self).add_child(tips)
	story_card = StoryCard.new()
	story_card.game = self
	tips.add_child(story_card)
	tutorial_spotlight = TutorialSpotlight.new()
	tutorial_spotlight.game = self
	tips.add_child(tutorial_spotlight)

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

func _handle_pointer_input(pointed_enemy: Enemy, delta: float = 0.0) -> void:
	pointer_step(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), false, pointed_enemy, delta)

## One frame of the field's mouse: `left` is the button held now. Right is
## an ordinary bindable key now (用户 2026-10-20, Keybinds), not a move; the
## `right` argument is kept for old callers and ignored.
func pointer_step(left: bool, right: bool, pointed_enemy: Enemy, delta: float) -> void:
	pointer.step(left, pointed_enemy, delta)

## The attack arrow while the pointer is on an enemy's hit box in the running
## field (not over the hotbar, a ground item's name plate or a drag), else
## the default pointer.
func _update_pointer_cursor(pointed_enemy: Enemy) -> void:
	var on := is_instance_valid(pointed_enemy) and not pointed_enemy._dead and not get_viewport().gui_is_dragging()
	if on and is_instance_valid(_hud):
		var at := pointer_ui()
		on = _hud.hotbar_slot_at(at) < -1 and _hud.picker_slot < 0 and not is_instance_valid(_hud.loot_label_at(at))
	if on == attack_cursor_on: return
	attack_cursor_on = on
	AttackCursor.apply(on)

func _exit_tree() -> void:
	_flush_queued_save()
	if save_lock != null: save_lock.leave()
	# The C window's stand-in was never in the tree.
	if is_instance_valid(_view): _view.free()
	if attack_cursor_on:
		attack_cursor_on = false
		AttackCursor.apply(false)
	release_static_caches()

## Textures, meshes and shaders kept in static vars are otherwise freed with
## their scripts, after the renderer has shut down, which crashed the release
## build on quit (用户 2026-10-23: 先修退出崩溃). They fill again on demand.
static func release_static_caches() -> void:
	for cache: Dictionary in [BarrierFx._cells, BossVfx._band_shaders, BossVfx._textures, BossVfx._splat_shaders,
			BaseMap._kit_meshes, TerraceDressing._kit_cache, AttackCursor._textures, ItemIcons._cache, PaperDoll._silhouettes,
			RelicIcons._cache, ResearchTreeView._cards, ResearchTreeView._bands, GroundHazard._circles, Loot._ground_cache,
			OperatorKit._textures, FieldArt._frames, EnemyAttackVfx._shared, CombatVfx._meshes, BossVfx._burst_quads, BossVfx._burst_materials, Loot._looks,
			AK._button_styles, InventoryPanel._tile_styles]:
		cache.clear()
	AttackCursor.release()
	GpuFx.release()
	BossVfx._soft = null
	BossVfx._shaft_shader = null
	Enemy._silence_tex = null
	Enemy._incite_tex = null
	InventoryPanel._portrait = null
	LapplandAnimator3D._contact = null

## Which hotbar slot the pointer is over for a drop from the pack (Hud.hotbar_slot_under).
## `at` is the pointer in UI-canvas coordinates. A panel dragging an item
## passes its own: the field's pointer is not refreshed while the GUI holds a
## drag, so it still points wherever the drag began.
func hotbar_drop_slot(at: Variant = null) -> int:
	if not is_instance_valid(_hud): return -2
	var point: Vector2 = pointer_ui() if at == null else _hud.get_global_transform_with_canvas().affine_inverse() * (at as Vector2)
	return _hud.hotbar_slot_under(point)

## An item dropped on hotbar slot `slot` (用户 2026-10-24: 移到快捷键不是丢弃):
## a flask binds its kind there; anything else stays where it was.
func bind_to_hotbar(item: Item, slot: int) -> void:
	if item == null or slot < 0 or not item.is_potion(): return
	var action := "potion_%s" % item.potion_type
	if not Hotbar.ACTIONS.has(action) or (slot == Hotbar.AUTO and not Hotbar.AUTO_CHOICES.has(action)): return
	Hotbar.set_action(slot, action)
	set_message("快捷栏：%s" % Hotbar.CHOICE_NAMES.get(action, item.item_name))

## The pointer in HUD (UI viewport) coordinates, where the name plates are drawn.
func pointer_ui() -> Vector2:
	var viewport := get_viewport()
	var at := _pointer_in(viewport)
	var world_size := viewport.get_visible_rect().size
	var ui_viewport := number_layer.get_viewport() if is_instance_valid(number_layer) else viewport
	return at * (ui_viewport.get_visible_rect().size / world_size if world_size.x > 0 else Vector2.ONE)

## The ground item she is walking to take, or null.
var pickup_target: Loot
## How close she must be to take it.
const PICKUP_REACH := 1.25

## Walk to `loot` and take it on arrival (a click on its name plate).
func request_pickup(loot: Loot) -> void:
	if not is_instance_valid(loot) or loot.game != self or loot.is_search_point: return
	if loot.sealed:
		notice("战利品仍被封印：先击败全部守卫者。")
		return
	player.clear_target()
	pickup_target = loot
	player.set_move_target(loot.global_position)

## Each frame in the field: take the requested item once she is beside it;
## drop the request if another order replaced the walk.
func _tick_pickup() -> void:
	if not is_instance_valid(pickup_target) or pickup_target.is_queued_for_deletion():
		pickup_target = null
		return
	var offset := pickup_target.global_position - player.global_position
	if Vector2(offset.x, offset.z).length() <= PICKUP_REACH:
		if pickup_target.landed() and pickup_target.pickup_delay <= 0.0:
			player.clear_move_target()
			pickup_target.collect()
			pickup_target = null
		return
	if not player._has_move_target: pickup_target = null

## One query for line of sight; only the ends change (the pointer's: GmPointer).
var _sight_query: PhysicsRayQueryParameters3D

## Where the pointer is on `viewport`: the last mouse event's position
## (injected and replayed input included), else the mouse's.
func _pointer_in(viewport: Viewport) -> Vector2:
	return _pointer_position if _has_pointer_position else viewport.get_mouse_position()

func _get_enemy_under_pointer() -> Enemy:
	return pointer.enemy_under()

func _get_pointer_ground() -> Vector3:
	return pointer.ground_point()

## Ground height under x/z: the field's terraces, or the base's flat floor.
## `at.y` tells a bridge's deck from the road under it.
func ground_y(at: Vector3) -> float:
	if in_base or not is_instance_valid(world_map): return 0.0
	return world_map.ground_height(Vector2(at.x, at.z), at.y)

func spawn_warning_area(position: Vector3, radius: float, lifetime: float, unstoppable: bool = false) -> CombatMarker:
	var warning := CombatMarker.create("circle", Vector2(radius, 0.0), lifetime, unstoppable)
	add_child(warning)
	warning.global_position = Vector3(position.x, ground_y(position) + 0.04, position.z)
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
	var map := world_map.navigation_map_rid()
	NavigationServer3D.map_force_update(map)
	# On a loaded frame the new mesh can still be missing after those ticks,
	# and then every spawn finds no walkable ground (test_guards: whole floors
	# with no guards or wanderers). Wait until the map answers near the entry.
	for i in range(60):
		var near := NavigationServer3D.map_get_closest_point(map, ContinuousWorldMap.ENTRY_POSITION)
		if near != Vector3.ZERO and near.distance_to(ContinuousWorldMap.ENTRY_POSITION) < 4.0: break
		await get_tree().physics_frame
		await get_tree().process_frame
		NavigationServer3D.map_force_update(map)

## A strip `width` wide running `length` from `origin` toward `target`
## (新敌人攻击案 §六第 2 条: each attack gives its own size).
func spawn_warning_lane(origin: Vector3, target: Vector3, lifetime: float, width: float = 1.6, length: float = -1.0, unstoppable: bool = false) -> CombatMarker:
	var direction := target - origin
	direction.y = 0
	if direction.length_squared() < 0.01: return null
	if length <= 0.0: length = direction.length()
	var marker := CombatMarker.create("lane", Vector2(width, length), lifetime, unstoppable)
	add_child(marker)
	marker.global_position = origin + direction.normalized() * length * 0.5
	marker.global_position.y = ground_y(marker.global_position) + 0.05
	marker.basis = Basis.looking_at(direction.normalized())
	return marker

func line_of_sight(origin: Vector3, target: Vector3) -> bool:
	origin.y = maxf(ground_y(origin) + 0.7, origin.y)
	target.y = maxf(ground_y(target) + 0.7, target.y)
	if _sight_query == null: _sight_query = PhysicsRayQueryParameters3D.create(origin, target, 1)
	_sight_query.from = origin
	_sight_query.to = target
	return get_world_3d().direct_space_state.intersect_ray(_sight_query).is_empty()
