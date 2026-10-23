class_name GameManager
extends Node3D

## Authoritative contract state, containers, build choices, settlement and base saves.

const CAMERA_OFFSET := Vector3(0.0, 16.0, -10.0)
const CAMERA_FOLLOW_SPEED := 10.0
## The follow camera can be zoomed and turned round her (用户 2026-10-20, after
## Grim Dawn): the wheel zooms between the limits, a key turns it 45°, the
## middle button dragged turns it freely, one key brings back the default
## view. The tilt goes from 50° to 70° (用户 2026-10-20: 有限俯角), a key a
## step or the middle button dragged up and down; the sprites, drawn for 58°,
## are kept on their feet at any of it (_keep_sprites_upright).
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
	set(value): _set_standard_potions(value)
## Q drinks the first of these she carries (标准急救剂 first).
const POTION_ORDER := ["A", "B", "C"]
## The 特供 and regional flasks' timers and side effects (药剂与商人界面策划案 §2–§3).
var potion_fx := PotionEffects.new()
## 地图特色 on this contract (地图特色策划案_v1_0.md): 源石污染, 血债, 寒冷.
var features := FeatureMeter.new()
## Contamination taken on this contract so far (§4.1); it is the 地图特色 meter's.
var run_contamination: float:
	get: return float(features.values.contamination)
	set(v): features.values.contamination = v
var _slow_heal_left := 0.0       # 缓释凝胶: health still to come
var _slow_heal_rate := 0.0
var _suppress_timer := 0.0       # 抑制喷剂: contamination accrues at half rate meanwhile
var _potion_heal_factor := 1.0   # contamination tier at departure
## The auto-potion slot (Hotbar.AUTO): on below the low threshold, off at the high one.
var _auto_drinking := false
var _auto_potion_gap := 0.0
const AUTO_POTION_GAP := 0.5     # between two flasks of one run of drinking
var _announced_tier := 0
## 龙门币, the account balance (经济修订案: the only out-of-run money).
var gold: int = Economy.STARTING_LMD
var message: String = ""
var message_timer: float = 5.0

var inventory := ItemContainer.new(10, 6)
var safe_bag := ItemContainer.new(2, 2)
## Everything stored at the base: receiving crates, staging, the shelves.
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
## The warehouse proper: personal storage on the shelves.
var stash: Array[Item]:
	get: return base.shelf

var player: Player
var world_map: ContinuousWorldMap
var base_map: BaseMap
var warehouse_view: WarehouseView
var medical_view: MedicalView
## The construction sites and the parts each facility level puts in the base.
var works: BaseWorks
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
var _vault_guardians: Array[Enemy] = []
## The outpost floor's squad (§6 B2); its routes stay shut until all of it falls.
var _outpost_squad: Array[Enemy] = []
var outpost_cleared := true
## The outpost's boss (every 20th floor) or warden (the 10th between), Boss与守卫者策划案.
var outpost_boss: Boss
## A boss floor's arena (Boss战场地策划案): gate, cover, the region's device.
var arena: BossArena
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
## 威胁值 (ThreatMeter): fills by itself on a floor, a full meter sends a patrol.
var threat := ThreatMeter.new()
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
var _contract_announced := false
var builds: Array[String] = []
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
var _left_was_down := false
## A left press that began on an enemy (用户 2026-10-14: 长按敌人连续攻击):
## held past HOLD_ATTACK_TIME, she keeps at it while it is held, with the
## cursor on it or off it, and stops on release. A shorter click keeps the
## lock as before.
var _held_on_enemy := false
var _left_held_time := 0.0
## The name plate the held left press is on (or came from), and where the
## cursor last was over it; off by PLATE_LEAVE_PX, the press attacks again.
var _plate_held: Loot = null
var _plate_from := Vector2.ZERO
const PLATE_LEAVE_PX := 10.0
const HOLD_ATTACK_TIME := 0.25
## The attack arrow is showing.
var attack_cursor_on := false
var _pointer_position := Vector2.ZERO
var _has_pointer_position := false
## The camera's smooth follow position. What is rendered is this snapped to
## whole screen pixels (see _snap_to_pixels).
var _camera_follow := Vector3.ZERO
var _camera_snapped := Vector3.INF
## The camera's turn round the vertical (0 = the default view from the south)
## and its orthographic size, each easing to where the player set it.
var camera_yaw := 0.0
var camera_yaw_goal := 0.0
var camera_size_goal := CAMERA_SIZE
var camera_pitch := CAMERA_PITCH
var camera_pitch_goal := CAMERA_PITCH
## The tilt the sprites were last set for.
var _sprites_pitch := CAMERA_PITCH
var _camera_dragging := false

## Opens or closes the base's station overview (BaseHud), remembered in the settings.
func toggle_station_panel() -> void:
	SystemScreens.set_setting("station_panel", not bool(SystemScreens.settings.get("station_panel", false)))

func _ready() -> void:
	_setup_input()
	AttackCursor.apply(false)
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
	_init_market()
	if save_enabled:
		load_base()
		if issue_kits() > 0: save_base()
	_catch_up_market()
	if start_at_base:
		show_base()
	else:
		await start_contract(region_id)

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
	return is_instance_valid(looting)

## Walking around Rhodes Island between contracts: movement only, no combat.
func base_walk_active() -> bool:
	return in_base and not transitioning and modal.is_empty()

func _input(event: InputEvent) -> void:
	# SubViewportContainer forwards positions in this viewport's coordinates.
	# Preserve event coordinates for picking, including injected/replayed input.
	if event is InputEventMouse:
		_pointer_position = event.position
		_has_pointer_position = true
	if _camera_dragging and event is InputEventMouseMotion:
		camera_yaw_goal -= event.relative.x * CAMERA_DRAG_TURN
		tilt_camera(event.relative.y * CAMERA_DRAG_TURN)

## The wheel and the drag start only where no panel took the press.
func _unhandled_input(event: InputEvent) -> void:
	if not camera_control_active(): return
	if event.is_action_pressed("camera_zoom_in"): zoom_camera(-1)
	elif event.is_action_pressed("camera_zoom_out"): zoom_camera(1)
	elif event.is_action_pressed("camera_drag"): _camera_dragging = true

func camera_control_active() -> bool:
	return simulation_active() or base_walk_active()

## One wheel notch closer (-1) or further out (1).
func zoom_camera(steps: int) -> void:
	camera_size_goal = clampf(camera_size_goal + steps * CAMERA_ZOOM_STEP, CAMERA_SIZE_MIN, CAMERA_SIZE_MAX)

## Steeper (positive radians) or lower, within the limits.
func tilt_camera(radians: float) -> void:
	camera_pitch_goal = clampf(camera_pitch_goal + radians, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)

## Turn to the next 45° mark on that side (1 or -1).
func turn_camera(side: int) -> void:
	var mark := camera_yaw_goal / CAMERA_TURN_STEP
	camera_yaw_goal = (floorf(mark + 0.001) + 1.0 if side > 0 else ceilf(mark - 0.001) - 1.0) * CAMERA_TURN_STEP

func reset_camera_view() -> void:
	# The short way round to the default view.
	camera_yaw_goal = camera_yaw - wrapf(camera_yaw, -PI, PI)
	camera_size_goal = CAMERA_SIZE
	camera_pitch_goal = CAMERA_PITCH

## Where the camera sits from the point it looks at, tilted and turned with the view.
func camera_offset() -> Vector3:
	var reach := CAMERA_OFFSET.length()
	return Vector3(0.0, reach * sin(camera_pitch), -reach * cos(camera_pitch)).rotated(Vector3.UP, camera_yaw)

## A billboard shows its height above the ground cos(tilt) as tall on screen,
## so at another tilt than 58° its image would float above its feet or sink
## below them. Each sprite in "upright_sprites" is moved on its image by that
## difference (its height measured once, its own ground under it); each
## upright figure in "upright_figures" (BILLBOARD_FIXED_Y) is stretched by
## 1 / cos(tilt) to draw the same pixels.
func _keep_sprites_upright() -> void:
	if is_equal_approx(camera_pitch, CAMERA_PITCH) and is_equal_approx(_sprites_pitch, CAMERA_PITCH): return
	_sprites_pitch = camera_pitch
	var rise := cos(CAMERA_PITCH) - cos(camera_pitch)
	BaseMap.pivot_screen_px = BaseMap.SORT_PIVOT_Y * cos(camera_pitch) * 15.0
	for node in get_tree().get_nodes_in_group("upright_sprites"):
		var sprite := node as SpriteBase3D
		if sprite == null or not sprite.is_inside_tree(): continue
		if not sprite.has_meta("upright_height"): sprite.set_meta("upright_height", sprite.global_position.y - ground_y(sprite.global_position))
		var shift: float = float(sprite.get_meta("upright_height")) * rise / sprite.pixel_size
		sprite.offset.y += shift - float(sprite.get_meta("upright_shift", 0.0))
		sprite.set_meta("upright_shift", shift)
	for node in get_tree().get_nodes_in_group("upright_figures"):
		(node as Node3D).scale.y = 1.0 / cos(camera_pitch)

func _camera_keys() -> void:
	if Input.is_action_just_pressed("camera_turn_left"): turn_camera(1)
	if Input.is_action_just_pressed("camera_turn_right"): turn_camera(-1)
	if Input.is_action_just_pressed("camera_reset"): reset_camera_view()
	if Input.is_action_just_pressed("camera_tilt_up"): tilt_camera(CAMERA_TILT_STEP)
	if Input.is_action_just_pressed("camera_tilt_down"): tilt_camera(-CAMERA_TILT_STEP)

## Seconds until the base next looks for insurance that is due.
var _insurance_check := 0.0
const INSURANCE_CHECK_SECONDS := 5.0

## The cave's cut-away round her (cutaway.gdshaderinc field_cut): opens over
## CUT_EASE seconds while rock stands between her and the camera, closes as
## gently once it does not (用户 2026-10-21: 挡视野时突然消失).
const CUT_EASE := 0.25
var _cut_amount := 0.0

func _ease_cutaway(delta: float) -> void:
	var want := 0.0
	if not in_base and is_instance_valid(world_map) and is_instance_valid(world_map.terrace_dressing):
		var away := Vector2(camera_offset().x, camera_offset().z)
		if away.length() > 0.01 and world_map.terrace_dressing.rock_before(player.global_position, away.normalized(), camera_pitch): want = 1.0
	var next := move_toward(_cut_amount, want, delta / CUT_EASE)
	if next == _cut_amount: return
	_cut_amount = next
	RenderingServer.global_shader_parameter_set("field_cut", _cut_amount)

func _process(delta: float) -> void:
	message_timer -= delta
	if not is_instance_valid(player):
		return
	_tick_insurance_clock(delta)
	_tick_market(delta)
	# A key just taken for a hotbar slot (pause → 快捷栏) does nothing else.
	var binding_key := is_instance_valid(menu) and (menu.hotbar_capture >= 0 or menu.hotbar_capture_frame == Engine.get_process_frames())
	var pointed: Enemy = _get_enemy_under_pointer() if simulation_active() and not hands_busy() and not binding_key else null
	_update_pointer_cursor(pointed)
	if binding_key: return
	if Input.is_action_just_pressed("toggle_inventory"): toggle_panel("inventory")
	if Input.is_action_just_pressed("toggle_operator"): toggle_panel("training")
	for entry in [["toggle_relics", "relics"], ["toggle_map", "map"], ["toggle_journal", "journal"]]:
		if Input.is_action_just_pressed(entry[0]): toggle_panel(entry[1])
	if Input.is_action_just_pressed("toggle_pause"): go_back()
	if in_base and Input.is_action_just_pressed("quick_pack") and is_instance_valid(menu) and menu.quick_pack_here() and not get_tree().root.gui_get_focus_owner() is LineEdit: menu.open_quick_pack()
	if camera_control_active(): _camera_keys()
	if _camera_dragging and not Input.is_action_pressed("camera_drag"): _camera_dragging = false
	# A hit while she searches shuts the box's window, so she can answer it.
	if hands_busy() and (not looting.is_inside_tree() or player.hp < _loot_hp - 0.5): close_modal()
	if simulation_active() and hands_busy(): _tick_toasts(delta)
	if simulation_active() and not hands_busy():
		_handle_pointer_input(pointed, delta)
		_tick_pickup()
		_tick_toasts(delta)
		# The eight hotbar slots, then the dedicated keys (dash is read by Player).
		var slots := Hotbar.slots()
		for i in range(Hotbar.SLOTS):
			if Input.is_action_just_pressed(Hotbar.input_of(i)): perform_hotbar_action(slots[i].action)
		for type in POTION_ORDER:
			if Input.is_action_just_pressed("potion_" + type): use_potion_type(type)
		if Input.is_action_just_pressed("operator_skill") and player.has_skill(): player.cast_skill(_skill_aim())
		if Input.is_action_just_pressed("interact"): _interact()
		if Input.is_action_just_pressed("stash_item"): _move_last_item_to_safe_bag()
	elif base_walk_active():
		_handle_base_pointer()
		if Input.is_action_just_pressed("interact"): _base_interact()
		if Input.is_action_just_pressed("toggle_watch") and is_instance_valid(watch_widget): watch_widget.set_meta("on", not watch_widget.get_meta("on", false))
		if Input.is_action_just_pressed("toggle_stations"): toggle_station_panel()
	_update_base_prompt()
	# The snowfall rides above her view (TerraceDressing.weather).
	if is_instance_valid(world_map) and is_instance_valid(world_map.terrace_dressing) and is_instance_valid(world_map.terrace_dressing.weather) and world_map.terrace_dressing.weather.is_inside_tree() and is_instance_valid(player) and player.is_inside_tree():
		world_map.terrace_dressing.weather.global_position = player.global_position + Vector3(0, 11, 4).rotated(Vector3.UP, camera_yaw)
	# The glow that follows her through the field (FieldLight).
	if is_instance_valid(player):
		RenderingServer.global_shader_parameter_set("field_player", player.global_position + Vector3.DOWN * 0.7)
		FieldLight.focus = player.global_position
		_tint_in_field()
		_ease_cutaway(delta)
	if is_instance_valid(camera):
		# Anything that placed the camera directly (spawns, captures) restarts the follow from there.
		if not camera.global_position.is_equal_approx(_camera_snapped): _camera_follow = camera.global_position - camera_offset()
		var blend := minf(1, CAMERA_EASE * delta)
		camera_yaw = lerpf(camera_yaw, camera_yaw_goal, blend) if absf(camera_yaw_goal - camera_yaw) > 0.0005 else camera_yaw_goal
		camera.size = lerpf(camera.size, camera_size_goal, blend) if absf(camera_size_goal - camera.size) > 0.005 else camera_size_goal
		camera_pitch = lerpf(camera_pitch, camera_pitch_goal, blend) if absf(camera_pitch_goal - camera_pitch) > 0.0005 else camera_pitch_goal
		_keep_sprites_upright()
		camera.global_basis = Basis.looking_at(-camera_offset(), Vector3.UP)
		# She stays in the middle while the view turns: the follow eases the
		# point looked at, the offset turns round it.
		_camera_follow = _camera_follow.lerp(camera_target(), minf(1, CAMERA_FOLLOW_SPEED * delta))
		_camera_snapped = _snap_to_pixels(_camera_follow + camera_offset())
		camera.global_position = _camera_snapped

		camera.h_offset = 0.0
		camera.v_offset = 0.0
		# A boss's heavy blow (BossVfx): a few pixels, dying away, both ways.
		if _impact_frames > 0 and simulation_active():
			var texel := camera.size / get_viewport().get_visible_rect().size.y
			var k := float(_impact_frames) / float(maxi(1, _impact_total))
			camera.h_offset += (1.0 if _impact_frames % 2 else -1.0) * _impact_pixels * k * texel
			camera.v_offset = (1.0 if (_impact_frames / 2) % 2 else -1.0) * _impact_pixels * 0.6 * k * texel
			_impact_frames -= 1

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
		return base_map.clamp_camera(player.global_position, camera.size / CAMERA_SIZE if is_instance_valid(camera) else 1.0, camera_yaw, sin(CAMERA_PITCH) / sin(camera_pitch))
	return player.global_position

## Any container channel in progress is broken off (a dodge, 用户 2026-10-10).
func cancel_channels(reason: String) -> void:
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var container := node as LootContainer
		if container != null and container.is_channeling(): container.cancel(reason)

## Pick who deploys next (base only, 阿米娅攻击动作与特效设计案 §十).
func choose_operator(id: String) -> void:
	if not in_base or not id in base.deployable(): return
	base.operator = id
	player.set_operator(id)
	shed_unusable_weapon()
	player._recompute_stats()
	player.hp = player.max_hp
	refresh_look()
	save_base()

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
	"近卫双芯片": {"materials": {"近卫芯片组": 2, "芯片助剂": 1}},
	"技巧概要·卷2": {"materials": {"技巧概要·卷1": 3}},
	"技巧概要·卷3": {"materials": {"技巧概要·卷2": 3}},
}

func progress() -> OperatorProgress:
	return base.progress_for(player.operator_id)

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
	# 人事部Ⅳ/Ⅵ: the benched operators learn a share of it.
	var share := research.bench_share()
	if share > 0.0:
		for id in base.roster:
			if id != player.operator_id: base.progress_for(id).add_exp(roundi(exp * share))

## Feeds `count` 作战记录 of `record` to the current operator (base only):
## stops at the level cap, and pays 0.5 龙门币 per point of experience.
func feed_record(record: String, count: int) -> int:
	if not in_base or not Progression.RECORD_EXP.has(record): return 0
	var p := progress()
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

## 龙门币 for one record (人事部Ⅰ and the endless line take their shares off).
func record_price(record: String) -> int:
	return ceili(int(Progression.RECORD_EXP[record]) * Progression.LMD_PER_EXP * research.feed_factor())

## The promotion's 龙门币 (人事部Ⅴ: −25%).
func promotion_lmd() -> int:
	var lmd := int(progress().promotion_cost().get("lmd", 0))
	return roundi(lmd * 0.75) if base.researched("promotion_fee") else lmd

## Resetting `points` skill points at `elite` (人事部Ⅱ: −50%).
func respec_price(points: int, elite: int) -> int:
	var cost := Progression.respec_cost(points, elite)
	return cost / 2 if base.researched("respec_fee") else cost

func promotion_refusal() -> String:
	var p := progress()
	var block := p.promotion_block()
	if not block.is_empty(): return block
	var cost := p.promotion_cost()
	if gold < promotion_lmd(): return "龙门币不足"
	return materials_refusal(cost.materials)

func promote_operator() -> bool:
	if not in_base or not promotion_refusal().is_empty(): return false
	var cost := progress().promotion_cost()
	gold -= promotion_lmd()
	consume_materials(cost.materials)
	progress().promote()
	player._recompute_stats()
	player.hp = player.max_hp
	save_base()
	return true

func add_attribute_point(key: String) -> bool:
	if not progress().add_attribute(key): return false
	player._recompute_stats()
	save_base(not in_base)
	return true

## One rank of a node; 专精 also takes its materials (base only).
func add_skill_rank(node_id: String) -> bool:
	var p := progress()
	var data := SkillTrees.node(player.operator_id, node_id)
	var materials := SkillTrees.rank_materials(data, p.rank(node_id))
	if not materials.is_empty() and (not in_base or not materials_refusal(materials).is_empty()): return false
	if not p.add_rank(node_id): return false
	if not materials.is_empty(): consume_materials(materials)
	player._recompute_stats()
	save_base(not in_base)
	return true

func set_transmuter(group: String, node_id: String) -> bool:
	if not progress().set_transmuter(group, node_id): return false
	save_base(not in_base)
	return true

func respec_skills() -> bool:
	var p := progress()
	var cost := respec_price(p.refundable_points(), p.elite)
	if not in_base or p.refundable_points() <= 0 or gold < cost: return false
	gold -= cost
	p.reset_skills()
	player._recompute_stats()
	save_base()
	return true

func module_refusal() -> String:
	var p := progress()
	var block := p.module_block()
	if not block.is_empty(): return block
	var cost: Dictionary = SkillTrees.MODULE_COST[p.module_level]
	if gold < int(cost.lmd): return "龙门币不足"
	return materials_refusal(cost.materials)

func upgrade_module() -> bool:
	if not in_base or not module_refusal().is_empty(): return false
	var cost: Dictionary = SkillTrees.MODULE_COST[progress().module_level]
	gold -= int(cost.lmd)
	consume_materials(cost.materials)
	progress().upgrade_module()
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

## (Her own blows never shake the camera, 用户 2026-10-20: 挥砍抖动也删掉.)
## A heavier shake for a boss's blow landing: `pixels` at first, over `frames`.
## A bigger one already running is not cut short.
var _impact_frames := 0
var _impact_total := 1
var _impact_pixels := 0.0
func start_impact_shake(pixels: float, frames: int) -> void:
	if _impact_frames > 0 and _impact_pixels * _impact_frames / _impact_total >= pixels: return
	_impact_pixels = pixels
	_impact_frames = frames
	_impact_total = frames

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
	modal = ""
	_pointer_gate = true
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
		"shelf_zone":
			open_modal("station")
			menu.shelf_zone = station.category
			menu.show_station("shelves")
		"putback": put_back_carried()
		"build_site": open_build_site(str(station.facility))
		"hub":
			if base.hub_built(): open_station("construction")
			else: open_build_site("hub")
		"staging":
			if base.hand: stage_carried()
			else:
				open_modal("station")
				menu.show_staging()
		_: open_station(station.kind)

## A facility's construction site: its upgrades on the spot, connected or not.
func open_build_site(facility: String) -> void:
	if not in_base or transitioning or not BaseCatalog.FACILITIES.has(facility): return
	open_modal("station")
	menu.show_build_site(facility)

func open_station(kind: String) -> void:
	if not in_base or transitioning: return
	if kind == "personnel": story_note("personnel")
	if kind == "report" and base.report_unread:
		base.report_unread = false
		save_base()
	open_modal("station")
	menu.show_station(kind)

func _handle_base_pointer() -> void:
	if _pointer_gate:
		_pointer_gate = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
	if is_instance_valid(watch_widget): watch_widget.visible = _base_prompt.visible and watch_widget.get_meta("on", false)
	if is_instance_valid(_swan_panel):
		_swan_panel.visible = in_base and not transitioning and not swan_popup.is_empty() and (modal.is_empty() or modal == "station")
		_swan_label.text = swan_popup
	if is_instance_valid(_status_bar):
		_status_bar.visible = _base_prompt.visible
		_status_bar.text = base_status_text()
		_status_bar.reset_size()
		_status_bar.position = Vector2(1268 - _status_bar.size.x, 12)
	if not _base_prompt.visible: return
	var station := nearby_station()
	var lines: Array[String] = []
	if not station.is_empty(): lines.append("E")
	if message_timer > 0 and not message.is_empty(): lines.append(message)
	_base_prompt.text = "
".join(lines)

func start_contract(region: String, start_camp: int = 0) -> void:
	if transitioning or not in_base or not FieldCatalog.REGIONS.has(region): return
	story_note("contract")
	first_run_ore = 0
	region_id = region
	in_base = false
	refresh_look()
	_settled = false
	transitioning = true
	close_modal()
	base_map.set_active(false)
	apply_scene_look(false)
	settlement.clear()
	builds.clear()
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
	_take_kits(region)
	# 纠察队 heard of the infected Rhodes treated at Chernobog (沙盘航行策划案 §4.4).
	threat.value = ThreatMeter.FULL * voyage.threat_start(region)
	_tracked_warned = -1
	route_index = 0
	in_camp = false
	_block_random_found = false
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
	contract = _pending_contract.duplicate() if not _pending_contract.is_empty() else (contract_offers(region)[0] as Dictionary).duplicate()
	_pending_contract = {}
	# Taking it fixes the pay (v1.1 §2.2); the endless 合同报酬 line adds its share.
	contract.reward = roundi(Economy.contract_reward(contract, start_floor) * research.contract_bonus() / 10000.0) * 100
	# Signed projects are paid now, at this start's tier, and are on for this contract.
	var project_paid := research.charge_departure(start_floor)
	research.apply_run(true)
	_trader_met = false
	contract_vaults = 0
	bounty_killed = false
	_bounty = null
	recruit_met = false
	cargo_delivered = false
	_contract_announced = false
	_run_seed = fixed_map_seed if fixed_map_seed else rng.randi()
	_apply_medical_state()
	guide_floor = -1
	_apply_meal(provisions.take_for_run())
	# Whatever she is carrying around the warehouse stays at the base.
	if base.return_hand(): set_message("手上的物品已放回原处。")
	_issue_free_potions()
	if research.on("supply"):   # 课题 战地补给
		for i in range(2): inventory.add_stack(BaseCatalog.create_potion("A", Economy.tier_of(start_floor)))
	prts_log.clear()
	prts_toasts.clear()
	broadcast("合同开始：%s。" % FieldCatalog.REGIONS[region_id].name)
	broadcast("合同目标：%s。" % FieldCatalog.contract_goal(contract, region_id, start_floor))
	if project_paid > 0: broadcast("课题经费 %s 龙门币：%s。" % [Economy.format(project_paid), "、".join(base.research.run.map(func(p): return str(ResearchCatalog.PROJECTS[p][0])))])
	broadcast("PRTS：博士，%s已就位。" % Operators.info(player.operator_id).name)
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
	if test_floor > 0: player.teleport(_boss_test_spot())
	camera.global_position = player.global_position + camera_offset()
	await _await_navigation_sync()
	_spawn_wave()
	transitioning = false
	set_message("合同开始：%s。" % FieldCatalog.REGIONS[region_id].name)

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
	world_map.encounter_kind = encounter
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
	world_map.generate(_run_seed + floor_number * 7919, floor_number)
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

## The top bar's place: the region, and in Lungmen this floor's upper or lower
## city (the camps and the base have neither).
func place_name() -> String:
	var variant: String = world_map.city_variant if is_instance_valid(world_map) and not in_base and not in_camp else ""
	return FieldCatalog.place_name(region_id, variant)

## The 10th floor of each block, just before the camp, is the outpost (§6 B2).
func is_outpost_floor() -> bool:
	return (floor_number - 1) % FieldCatalog.CAMP_INTERVAL + 1 == FieldCatalog.OUTPOST_PLACE

## The fixed extraction is in the camps now; a floor only ever has a random one.
func is_extraction_floor() -> bool:
	return _random_extraction_available

## At most one random extraction per block of ten, on floor 4, 5 or 6, each with
## exactly 1/6 (撤离与营地修订案 §2). The first floor 5 she ever reaches has
## one for sure (BaseState.first_extract_given).
func _roll_random_extraction() -> void:
	var place := (floor_number - 1) % FieldCatalog.CAMP_INTERVAL + 1
	if place == 1: _block_random_found = false
	_random_extraction_available = false
	if floor_number == 5 and not base.first_extract_given:
		base.first_extract_given = true
		_random_extraction_available = true
		_block_random_found = true
		return
	if _block_random_found or not FieldCatalog.RANDOM_EXTRACTION_ODDS.has(place): return
	# 课题 撤离保障: one every block, each of the three floors a third.
	var odds := float(FieldCatalog.RANDOM_EXTRACTION_ODDS[place])
	if research.on("extract"): odds = 1.0 / float(7 - place)
	if rng.randf() < odds:
		_random_extraction_available = true
		_block_random_found = true

func is_buff_available() -> bool: return not _buff_taken
## Who stands at this floor's encounter spot (保全系统修订案 §2).
func _roll_encounter() -> void:
	var roll := rng.randf()
	var trader := FieldCatalog.TRADER_CHANCE * (1.5 if base.researched("trader_odds") else 1.0)
	var squad := squad_chance()
	encounter = "squad" if roll < squad else ("trader" if roll < squad + trader else "")
	# 课题 商队联络: 坎诺特 waits on the third floor of the contract if not met before.
	if research.on("trader") and not _trader_met and floor_number - start_floor >= 2: encounter = "trader"
	if encounter == "trader": _trader_met = true
	# A faction's post (势力与交易所策划案 §12) takes some of the empty spots.
	post_faction = ""
	if encounter.is_empty():
		var posts: Array = FactionCatalog.POSTS.get(region_id, [])
		var chance := POST_CHANCE * (2.0 if posts.any(func(f): return market.post_boosted(f)) else 1.0)
		if voyage.post_boost(region_id): chance *= VoyageCatalog.POST_BOOST
		if not posts.is_empty() and rng.randf() < chance:
			encounter = "post"
			post_faction = posts[rng.randi() % posts.size()]
			for f in posts:
				if market.post_boosted(f): post_faction = f
	encounter_used = false
	trader_stock.clear()
	trader_rerolls = 0
	_encounter_greeted = false
	squad_mult = FieldCatalog.SQUAD_PRICE_STEPS[rng.randi() % FieldCatalog.SQUAD_PRICE_STEPS.size()]
	squad_uses = 0
	# 食堂补给 from Ⅱ: the squad's price one step lower.
	if meal_tier() >= Provisions.SQUAD_STEP_DOWN_TIER: squad_mult = snappedf(squad_mult - Provisions.SQUAD_STEP, 0.01)

## Who stands at the encounter spot, by name.
func encounter_name() -> String:
	match encounter:
		"trader": return "坎诺特"
		"post": return FactionCatalog.name_of(post_faction) + "据点"
	return "罗德岛小队"

func is_encounter_available() -> bool: return not encounter.is_empty() and not encounter_used

func _interact() -> void:
	if not simulation_active() or hands_busy(): return
	# Ground loot is taken by clicking its name (request_pickup), not with E.
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box.game != self or player.global_position.distance_to(box.global_position) > LootContainer.REACH: continue
		if box.sealed:
			notice("%s仍被封印：先击败全部守卫者。" % box.title())
			return
		if box.looted(): continue
		if box.begin_open():
			open_loot(box)
			return
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game != self or not near(cache): continue
		if cache.sealed:
			notice("密室藏品仍被封印：先击败全部守卫者。")
		else:
			open_relic_offer(cache.source, cache)
		return
	var fire := near_fire()
	if _recruit_nearby():
		_meet_recruit()
	elif fire != null and not pack_fuels().is_empty():
		_open_fuel(fire)
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
		pass

## 密室 (密室与陷阱修订案_v1 §2.1, 用户 2026-10-17): found by eye, opened by
## breaking its 暗墙 (VaultSeal) with blows. Inside, the rare loot; on
## VAULT_GUARDED of them a guard of one elite and VAULT_GUARD_NORMALS more,
## and then the chests stay sealed until it is down.
const VAULT_GUARDED := 0.5
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

func _open_vault() -> void:
	if vault_opened or world_map.vault_seal == null: return
	vault_opened = true
	contract_vaults += 1
	world_map.vault_seal.open()
	var guarded := rng.randf() < VAULT_GUARDED if force_vault_guard < 0 else force_vault_guard == 1
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
	return not base.extracted_once and is_extraction_floor() and is_instance_valid(system_screens) and (TutorialSpotlight.tips_on() or not TutorialCard.finished())

## 主线引导 (Story): one more of `event` (a crate opened, an order filled…).
func story_note(event: String) -> void:
	Story.note(base.story, event)

func region_open(region: String) -> bool:
	return Story.region_open(base.story, region)

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
	threat.next_floor()
	_tracked_warned = -1
	route_history.append({"floor": floor_number, "name": FieldCatalog.ROUTES[route].name})
	_build_world()
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await _await_navigation_sync()
	_spawn_wave()
	transitioning = false
	set_message("进入第 %d 层 · %s；上一层已无法返回。" % [floor_number, FieldCatalog.ROUTES[route].name])
	broadcast("进入 %s · %s。" % [AK.floor_code(region_id, floor_number), FieldCatalog.ROUTES[route].name])
	if is_outpost_floor(): broadcast(_outpost_line())
	if is_bounty_floor(): broadcast("悬赏目标在本层。")
	if base.researched("floor_report"):   # 情报部Ⅲ
		broadcast("PRTS：本层兴趣点 %d，精英 %d。" % [world_map.cache_positions.size(), floor_enemies().filter(func(e): return e.elite).size()])

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
		notice("本地区可选藏品不足三件：装置休眠。已有藏品跨区段保留。")
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
	_stop_looting()
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
const PANELS := ["inventory", "training", "relics", "map", "journal", "pause"]

func broadcast(text: String) -> void:
	prts_log.append([Time.get_time_string_from_system(), text])
	if prts_log.size() > 40: prts_log.pop_front()

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
		"training": menu.show_training(true)
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
	if is_instance_valid(_inventory_panel) and is_instance_valid(_inventory_panel._confirm) and _inventory_panel._confirm.visible:
		_inventory_panel._confirm.hide()
		return
	if is_instance_valid(menu) and menu.close_quick_pack(): return
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
			"slot": slot, "mult": t.get("mult", 1.0)})
	return rows

## What E would do right here, for the prompt near her ("" for nothing).
func interaction_prompt() -> String:
	if not simulation_active() or hands_busy(): return ""
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game == self and near(cache): return "密室藏品" if cache.source == "vault" else "战斗缴获"
	if _recruit_nearby(): return Operators.display_name(str(contract.operator))
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
	_use_squad()
	save_base(true)
	set_message("罗德岛小队：%s 已投保。" % item.item_name)
	return true

## Sends one item home now: it is gone from her and waits in staging. An
## insured item keeps its insurance: it was not lost.
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
	if not in_base and not _settled: settle(false)

func settle(extracted: bool) -> void:
	if _settled: return
	_settled = true
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
	settlement.clear()
	music.end_run(extracted)
	# What comes back: gear she set out with stays on her (equipped, packed or
	# in the safe bag) — she already knows it, so it skips the crates. Anything
	# found on this contract arrives as a sealed crate at receiving.
	var new_finds := 0
	var brought_records := {}
	var still_equipped: Array[Item] = []
	# Insurance whose time has come arrives first (保全系统修订案 §3).
	var returned := base.tick_insurance()
	var progress := contract_progress()
	settlement_view = {"extracted": extracted, "region": region_id, "start": start_floor, "depth": floor_number,
		"pack_size": Vector2i(inventory.width, inventory.height), "safe_size": Vector2i(safe_bag.width, safe_bag.height),
		"pack": [], "safe": [], "worn": [], "reward": 0, "returned": returned.size(), "gold": 0, "orders": 0,
		"plate": camp_label(floor_number) if in_camp_before_settle else AK.floor_code(region_id, floor_number),
		"time": Time.get_time_string_from_system().left(5)}
	var on_her := carried_items()
	for item in on_her:
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
		if reason == "投保送回": _queue_insured(item)
		if kept:
			# Brought out: the insurance stays for the next contract (用户 2026-10-15:
			# 投保后带出的不消保，只有被找回一次才消).
			item.carried_in = false
			# 作战记录 brought out go to 人事部's counters, not a crate (v1.1 §2.1).
			if Progression.RECORD_EXP.has(item.material_id) and not stays_on_her:
				base.add_records({item.material_id: item.quantity})
				brought_records[item.material_id] = int(brought_records.get(item.material_id, 0)) + item.quantity
			elif not stays_on_her and base.receive(item): new_finds += 1
		settlement.append(entry)
		var shown := {"item": item, "reason": reason, "x": item.grid_x, "y": item.grid_y, "w": item.width, "h": item.height}
		settlement_view[where].append(shown)
		if kept and item.material_id == Economy.GOLD_ID: settlement_view.gold += item.quantity
		if kept:
			for slot in range(base.orders.slots.size()):
				if base.orders.slots[slot] != null and base.orders.slots[slot].state == "open" and base.orders.matches(slot, item):
					settlement_view.orders += 1
					break
	# Insured gear she dropped on a floor and did not pick up again.
	for item in _insured_left_behind:
		if on_her.has(item) or not item.insured: continue
		_queue_insured(item)
		settlement.append({"uid": item.uid, "name": item.item_name, "reason": "投保送回"})
	_insured_left_behind.clear()
	builds.clear()
	build_offers.clear()
	_device_offers.clear()
	# 作战记录 are field drops now: only what came home counts (v1.1 §2.1).
	settlement_view.records = brought_records
	settlement_view.kills = run_kills.duplicate()
	run_kills = {}
	run_sets_seen = {}
	base.orders.refill(rng, region_id)
	# Bulk orders: crates handed over pay now; a crate lost with the pack reopens its order.
	voyage.on_settle()
	voyage.contract_done(region_id)
	base.settle_medical(not extracted, Economy.tier_of(floor_number))
	research.settle()
	research.apply_run(false)
	base.contract_reroll = base.researched("offer_reroll")
	base.reroll_available = base.facility_level("warehouse") >= BaseCatalog.REROLL_LEVEL
	# The drone empties staging onto the shelves at every return (§3.4a).
	if base.drone: base.sort_staging()
	# 后勤部Ⅵ: everything that came home goes straight onto the shelves.
	if base.researched("auto_sort"): base.sort_all()
	features.reset()
	player.cold = 0.0
	_slow_heal_left = 0.0
	_suppress_timer = 0.0
	player.condition_hp_penalty = 0.0
	player.regen_blocked = false
	player.reset_stats()
	for item in still_equipped: player.equip(item)
	player.hp = player.max_hp
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
			new_finds += issue_kits()
	if not contract.is_empty(): base.contract_offers.erase(region_id)
	contract = {}
	gold += reward
	settlement_view.reward = reward
	# 可露希尔's loan charges once a settlement; an overdue one takes the reward first (§10).
	var repaid := exchange.on_settlement(reward)
	_clear_field()
	world_map._clear_generated_map()
	floor_number = 1
	in_base = true
	transitioning = false
	save_base()
	set_message("%s：%d 件新物品已送到仓储区收货区。%s%s" % ["合同交付" if extracted else "罗德岛小队归来", new_finds,
		"合同报酬 %s 龙门币。" % Economy.format(reward) if reward > 0 else "", "投保物品送回 %d 件。" % returned.size() if not returned.is_empty() else ""])
	base_spawn = "arrival" if extracted else "death"
	show_base()
	var who := str(Operators.info(player.operator_id).name)
	broadcast("PRTS：博士与%s已完成撤离。" % who if extracted else "PRTS：罗德岛小队已接回博士与%s。" % who)
	if new_finds > 0: broadcast("收货区货箱有 %d 件新物品待开箱。" % new_finds)
	if repaid > 0: broadcast("贷款逾期：合同报酬先还款 %s 龙门币。" % Economy.format(repaid))
	_tick_workshop()
	if show_settlement_screen:
		open_modal("settlement")
		menu.show_settlement()

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
	_tick_kitchen()
	if not research.tick().is_empty(): save_base()
	voyage.tick(BaseState.now())
	if gap < 600: return
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
	if _workshop_check <= 0.0:
		_workshop_check = 5.0
		if in_base:
			_tick_workshop()
			_tick_kitchen()
		if in_base and not research.tick().is_empty(): save_base()
		var before := voyage.to_data().hash()
		voyage.tick(BaseState.now())
		if voyage.to_data().hash() != before: save_base(not in_base)
		if in_base and is_instance_valid(base_map):
			show_ship()
			show_research()
			base_map.set_farm(provisions)
	if save_enabled:
		_market_save_left -= delta
		if _market_save_left <= 0.0:
			_market_save_left = MARKET_SAVE_SECONDS
			market.save_file(market_path())

## News reaches the Doctor through PRTS: the log everywhere, a line at the base
## for flash offers, and the one popup for a black swan (§5.5).
func _on_market_news(headline: Dictionary, event: Dictionary) -> void:
	if not event.is_empty(): exchange.on_event(event)
	var line := "PRTS 快讯：" + str(headline.title)
	broadcast(line)
	if str(headline.kind) == "swan":
		if in_base: swan_popup = str(headline.title)
		else: swan_popup = str(headline.title)  # shown when she is back
	elif in_base and str(headline.kind) == "flash": set_message(line)

## Account events (§12): in the field PRTS reports them, at the base a line.
## Price alerts are the Doctor's own and only show at the base.
func _on_exchange_notice(text: String, kind: String) -> void:
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

## The little ship on the sand table: at anchor, or along its leg.
## The research tree's hologram in 科研部 shows what is done and running.
func show_research() -> void:
	if is_instance_valid(base_map): base_map.set_research(base.research.done, base.research.active.map(func(e): return str(e.id)))

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
	set_message("大宗货箱已送到暂存区。")
	return true

func open_exchange() -> void:
	if not in_base or transitioning: return
	open_modal("station")
	menu.show_station("exchange")

# --- 加工部 (§2) -----------------------------------------------------------------

func workshop_refusal(output: String, count: int) -> String:
	if count <= 0 or Packs.is_pack(output) or Workshop.recipe(output).is_empty(): return "没有这个配方"
	if workshop.busy() >= workshop_slots(): return "加工队列已满"
	var cost := Workshop.cost_of(output, count)
	var missing := materials_refusal(cost)
	if not missing.is_empty(): return missing
	if gold < int(Workshop.recipe(output).lmd) * count: return "龙门币不足"
	return ""

## Queue slots: Workshop.slots by rank, one more with 后勤部Ⅱ.
func workshop_slots() -> int:
	return Workshop.slots(base.facility_level("workshop")) + (1 if base.researched("workshop_slot") else 0)

func workshop_start(output: String, count: int) -> bool:
	if not in_base or not workshop_refusal(output, count).is_empty(): return false
	consume_materials(Workshop.cost_of(output, count))
	gold -= int(Workshop.recipe(output).lmd) * count
	workshop.start(output, count, BaseState.now(), rng, research.workshop_time_factor())
	save_base()
	set_message("加工部：%s ×%d 开始加工。" % [output, count])
	return true

# --- Trade packs (交易所交易包修订案 §3–§4) ----------------------------------------------

## Why `count` packs of `pack` cannot be made now ("" = they can): the queue,
## the 龙门币, and enough on the shelves (`quick`: one-key packing's picks).
func pack_refusal(pack: String, count: int, quick: bool = true) -> String:
	if not Packs.is_pack(pack) or count <= 0: return "没有这个包"
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
	if made <= 0 or workshop.busy() >= workshop_slots() or gold < Packs.PACK_LMD * made: return false
	return _pack_take(pack, made, take)

func _pack_take(pack: String, made: int, take: Dictionary) -> bool:
	if made <= 0: return false
	for item: Item in take:
		var n := int(take[item])
		if item.is_stackable() and n < item.quantity: item.set_quantity(item.quantity - n)
		else: _hand_over(item)
	gold -= Packs.PACK_LMD * made
	workshop.start(pack, made, BaseState.now(), rng, research.workshop_time_factor())
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

## Opens one pack at the warehouse console (§4): the pick goes to staging, the
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
			if not base.receive_to_staging(stack): base.receive(stack)
	save_base()
	set_message("%s 已拆开，物品在暂存区。" % pack)
	return true

## Buys shelf entry `i` of the 代售 open here (§5): bars or 龙门币, into the
## pack (at the base the receiving bay when the pack is full).
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
	if str(entry.kind) == "special": exchange.special_bought(item.material_id)
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
	if paid <= 0 or not _hand_over(item): return false
	if cur == "lmd": gold += paid
	elif not in_base: give_gold_bars(paid)
	else:
		var left := paid
		while left > 0:
			var stack := MaterialCatalog.create(Economy.GOLD_ID, mini(left, MaterialCatalog.stack_size(Economy.GOLD_ID)))
			left -= stack.quantity
			if not base.receive_to_staging(stack): base.receive(stack)
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

## Finished jobs go to staging (the receiving bay when it is full).
func _tick_workshop() -> void:
	var done := workshop.finished(BaseState.now())
	if done.is_empty(): return
	for job in done:
		var made := {str(job.output): int(job.count)}
		for by in job.get("byproducts", {}): made[by] = int(made.get(by, 0)) + int(job.byproducts[by])
		if Workshop.GEAR.has(str(job.output)):
			made.erase(str(job.output))
			for k in range(int(job.count)):
				var piece := GearCatalog.make_rhodes(str(Workshop.GEAR[job.output].base), rng, GearCatalog.rhodes_tier(research.deepest_camp()), base.rhodes_rarity)
				if not base.receive_to_staging(piece): base.receive(piece)
		for id in made:
			var left := int(made[id])
			while left > 0:
				var stack := MaterialCatalog.create(id, mini(left, MaterialCatalog.stack_size(id)))
				left -= stack.quantity
				if not base.receive_to_staging(stack): base.receive(stack)
		story_note("crafted")
		broadcast("PRTS：加工部完成 %s ×%d%s。" % [job.output, int(job.count), "，附带副产物" if not job.get("byproducts", {}).is_empty() else ""])
	if in_base: set_message("加工部完成 %d 项，已送到暂存区。" % done.size())
	save_base(not in_base)

# --- Field posts (§12) -----------------------------------------------------------

## A post buys what its faction likes, face to face (no remote fee).
func post_sell(item: Item) -> bool:
	if encounter != "post" or post_faction.is_empty() or in_base: return false
	if not (inventory.items.has(item) or safe_bag.items.has(item)): return false
	if not exchange.sell_item(item, post_faction, false): return false
	save_base(true)
	return true

## Buying at a post (§12): paid from the 赤金 account, straight into the pack.
## 整合运动残党's originium is "dirty" (§3): it raises contamination while carried.
func post_buy(material: String, count: int) -> bool:
	if encounter != "post" or post_faction.is_empty() or in_base or count <= 0: return false
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

## 萨米's barter: what `give` is worth at their bid, against `want` at their ask.
## The post's own flask (药剂与商人界面策划案 §3): its type, or "".
func post_potion() -> String:
	return str(BaseCatalog.REGIONAL.get(post_faction, ""))

## Why it cannot be bought now ("" = it can).
func post_potion_refusal() -> String:
	var type := post_potion()
	if type.is_empty(): return "不出售"
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
	if exchange.rank(post_faction) < FactionSpecials.rank_needed(want): return 0
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

# --- 坎诺特 (坎诺特商店策划案) ---------------------------------------------------

## His stock this floor: eight slots, {"kind": "relic"/"item", "relic": Dictionary,
## "item": Item, "price": 赤金, "sold": bool}. Rolled when he is first met.
var trader_stock: Array[Dictionary] = []
var trader_rerolls := 0
## 课题 商队联络: 坎诺特 already stood on this contract.
var _trader_met := false
## 幸运硬币 / 假面舞会面具 pay once per encounter, on first meeting.
var _encounter_greeted := false

## Opens the squad or 坎诺特 at this floor's encounter spot.
func _open_encounter() -> void:
	if not _encounter_greeted:
		_encounter_greeted = true
		var bonus := roundi(player.f("node_gold"))
		if bonus > 0:
			_give_gold_bars(bonus)
			set_message("遇到%s：赤金 +%d" % [encounter_name(), bonus])
	if encounter == "trader":
		if trader_stock.is_empty(): _roll_trader_stock()
		open_modal("trader")
		menu.show_trader()
	elif encounter == "post":
		open_modal("post")
		menu.show_post()
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
		# Any flask but the 强心针, the regional ones too (药剂与商人界面策划案 §1);
		# the restoratives still come up most.
		var roll := rng.randf()
		var type: String = "A" if roll < 0.35 else ("B" if roll < 0.55 else FieldCatalog.TRADER_POTION_POOL[rng.randi() % FieldCatalog.TRADER_POTION_POOL.size()])
		trader_stock.append({"kind": "item", "item": BaseCatalog.create_potion(type, Economy.tier_of(floor_number)), "price": _trader_discount(FieldCatalog.trader_potion_price(type)), "sold": false})
	var special := SpecialGear.roll(region_id, floor_number, rng) if rng.randf() < FieldCatalog.TRADER_SPECIAL_CHANCE else _roll_trader_gear()
	trader_stock.append(_trader_gear_slot(special))
	# 坎诺特 sometimes has an enemy exclusive of this region (装备扩充策划案 §1.1).
	if rng.randf() < FieldCatalog.TRADER_EXCLUSIVE_CHANCE:
		var ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "exclusive" and str(SpecialGear.GEAR[id].region) == region_id)
		if not ids.is_empty():
			var exclusive := SpecialGear.create(ids[rng.randi_range(0, ids.size() - 1)], floor_number, rng)
			exclusive.origin_region = region_id
			trader_stock[trader_stock.size() - 1] = _trader_gear_slot(exclusive)

func _roll_trader_gear() -> Item:
	for attempt in range(40):
		var item := FieldCatalog.roll_item(region_id, floor_number, rng, 0.0)
		if item.is_equippable() and item.exclusive_region.is_empty() and item.special.is_empty(): return item
	return FieldCatalog.roll_item(region_id, floor_number, rng, 0.0)

func _trader_gear_slot(item: Item) -> Dictionary:
	return {"kind": "item", "item": item, "price": _trader_discount(maxi(1, ceili(item.value * FieldCatalog.TRADER_GEAR_MARKUP / 10.0))), "sold": false}

func trader_reroll_cost() -> int:
	var cost := FieldCatalog.TRADER_REROLL_BASE + FieldCatalog.TRADER_REROLL_STEP * trader_rerolls
	return maxi(1, cost - 1) if base.researched("trader_odds") else cost

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
	if entry.kind == "item" and not inventory.can_take(entry.item): return "背包放不下"
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
		inventory.add_stack(entry.item)
		set_message("买下 %s" % entry.item.display_name())
	save_base(true)
	return true

## What he pays for `item` in 赤金 (§3: 交付价 × 50%), or 0 when he will not buy it:
## gear and materials only — no flasks, no 原矿, nothing insured, no 赤金.
func trader_offer(item: Item) -> int:
	if item == null or item.is_potion() or item.insured or item.effect in ["raw_ore", SEALED_ORE, VoyageCatalog.CARGO_EFFECT] or item.material_id == Economy.GOLD_ID: return 0
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
	story_note("camp")
	in_camp = true
	_roll_camp_closure()
	broadcast("PRTS：前进据点已确认，博士。")
	_clear_field()
	world_map._clear_generated_map()
	player.clear_move_target()
	base.unlock_camp(region_id, floor_number)
	features.enter_camp()
	player.cold = 0.0
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

## 可露希尔's flasks in 赤金 (v1.1 §2.3): 赤金 does not split, so one bar buys
## as many flasks as the pharmacy's 龙门币 price fits into the live rate, at
## least one. The tier is the camp's (or the deepest camp's at the base).
func closure_potion_price(type: String) -> int:
	var p: Dictionary = BaseCatalog.POTIONS[type]
	if base.facility_level("store") < int(p.store): return -1
	# The dearer 特供 cost as many bars as their 龙门币 price needs (at least one).
	return maxi(1, ceili(_closure_lmd(type) / maxf(1.0, Economy.bar_lmd())))

func _closure_lmd(type: String) -> float:
	return float(Economy.tiered(BaseCatalog.POTION_A_PRICE if type == "A" else int(BaseCatalog.POTIONS[type].get("price", 1000)), closure_potion_tier()))

## What 可露希尔 shows: at the base her 特供 line; in a camp A and B and the
## three 特供 this camp drew (药剂与商人界面策划案 §1).
func closure_goods() -> Array:
	if in_camp: return ["A", "B"] + camp_closure_stock.keys().filter(func(k): return not k in ["A", "B"])
	return BaseCatalog.CLOSURE_LINE.duplicate()

## Bottles of `type` she has left (-1: no limit). The base shelf refills every
## hour (BaseState.closure_left); a camp's draw is what it is.
func closure_stock_left(type: String) -> int:
	if type in ["A", "B"]: return -1
	if in_camp: return int(camp_closure_stock.get(type, 0))
	return base.closure_left(type)

## A camp's counter: A and B, and CAMP_SPECIALS of her 特供 her base store stocks.
var camp_closure_stock := {}

func _roll_camp_closure() -> void:
	camp_closure_stock = {}
	var open: Array = BaseCatalog.CLOSURE_LINE.filter(func(k): return base.facility_level("store") >= int(BaseCatalog.POTIONS[k].store))
	for i in range(mini(BaseCatalog.CAMP_SPECIALS, open.size())):
		var k: String = open[rng.randi() % open.size()]
		open.erase(k)
		camp_closure_stock[k] = int(BaseCatalog.POTIONS[k].cap)

func closure_potion_tier() -> int:
	return Economy.tier_of(floor_number + 1) if in_camp else deepest_tier()

func closure_potion_bundle(type: String) -> int:
	var bars := maxi(1, closure_potion_price(type))
	return maxi(1, floori(bars * Economy.bar_lmd() / maxf(1.0, _closure_lmd(type))))

## Flasks from 可露希尔, into the pack (in a camp, or at her base counter): one
## bar's bundle; whatever does not fit stays with her and is not charged.
func closure_buy_potion(type: String) -> bool:
	if not (in_camp or in_base) or not BaseCatalog.POTIONS.has(type): return false
	var price := closure_potion_price(type)
	if price < 0 or gold_available() < price: return false
	var stock := closure_stock_left(type)
	if stock == 0:
		notice("售罄，等可露希尔补货")
		return false
	var flask := BaseCatalog.create_potion(type, closure_potion_tier())
	var bundle := mini(closure_potion_bundle(type), flask.max_stack)
	if stock > 0: bundle = mini(bundle, stock)
	flask.set_quantity(bundle)
	var left := inventory.add_stack(flask)
	if left >= bundle:
		notice("背包空间不足：药剂要占一格。")
		return false
	if left > 0: notice("背包放不下的 %d 瓶留在了可露希尔那里。" % left)
	if stock > 0:
		if in_camp: camp_closure_stock[type] = stock - (bundle - left)
		else: base.closure_stock[type] = stock - (bundle - left)
	_pay_gold(price)
	if in_base: story_note("store_potion")
	save_base(not in_base)
	return true

## The departure tier of the deepest camp in any region (Ⅰ with none):
## camp 10 starts floor 11, tier Ⅱ.
func deepest_tier() -> int:
	var deepest := 0
	for region in base.camps: deepest = maxi(deepest, int(base.camps[region]))
	return Economy.tier_of(deepest + 1)

## 寄存 (§3): materials only, no special (regional) ones and no flasks; the fee is
## 20% of the 交付价, in 赤金, rounded up, at least one.
func deposit_fee(item: Item) -> int:
	return maxi(1, ceili(Economy.price(item) * FieldCatalog.DEPOSIT_FEE * research.deposit_fee_factor() / Economy.bar_lmd())) if item != null else 0

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

## 可露希尔 buys 赤金 for 龙门币 at the live rate less her spread (§1.3).
func sell_gold_bars(bars: int) -> bool:
	if not (in_camp or in_base) or bars <= 0 or gold_available() < bars: return false
	_pay_gold(bars)
	var paid := bars * Economy.closure_bar_price()
	gold += paid
	save_base(not in_base)
	set_message("卖出赤金 ×%d：龙门币 +%s" % [bars, Economy.format(paid)])
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
	var d := minf(EnemyAttacks.PRESSURE_DEPTH_MAX, FieldCatalog.DIFFICULTY_PER_FLOOR * (floor_number - 1)) + float(FieldCatalog.ROUTES[route_index].danger)
	return maxf(0.0, d * pressure_multiplier())

func passes_pickup_filter(item: Item) -> bool:
	if item == null or not item.is_equippable() or not item.exclusive_region.is_empty(): return true
	return item.rarity >= pickup_filter

func cycle_pickup_filter() -> void:
	pickup_filter = (pickup_filter + 1) % PICKUP_FILTER_NAMES.size()
	save_base(not in_base)
	set_message("拾取过滤：%s" % PICKUP_FILTER_NAMES[pickup_filter])

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
	if sorted: set_message("背包已整理。")
	else: notice("整理失败：当前摆放已是最紧凑，物品未移动。")
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
	if base.researched("safe_row"): safe.y += 1   # 外勤部Ⅳ
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

## Gold, facility level and materials together, for the terminal buttons.
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
	if base.facility_level("warehouse") < BaseCatalog.DRONE_LEVEL: return "需要仓储部 Lv%d" % BaseCatalog.DRONE_LEVEL
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
			notice("背包只装下 %d 个 %s，剩余 %d 个留在地上。" % [before - left, item.item_name, left])
			return false
		notice("背包空间不足：%s ×%d 仍留在地上。" % [item.item_name, left])
		return false
	if inventory.try_add(item):
		if item.named_kind() == "set": run_sets_seen[str(SpecialGear.GEAR[item.special].set_id)] = true
		save_base(true)
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
	save_base(not in_base)
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
	if previous != null and not from.try_add(previous):
		item.grid_x = old_pos.x
		item.grid_y = old_pos.y
		from.items.append(item)
		notice("换装空间不足，物品均已保留。")
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
	if item.insured and not _insured_left_behind.has(item): _insured_left_behind.append(item)
	save_base(true)
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
	if not in_base or not base.take_from_shelf(item): return false
	if not inventory.try_add(item):
		base.put_back(item, "shelf")
		notice("背包空间不足：%s 仍在货架上。" % item.item_name)
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
	if previous != null and base.store(previous).is_empty() and not inventory.try_add(previous):
		player.equip(previous)
		base.put_back(item, "shelf")
		notice("仓库和背包都满了：%s 仍在货架上。" % item.item_name)
		return false
	player.equip(item)
	story_note("bench_equip")
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
	story_note("crate")
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
	story_note("shelve")
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
	story_note("shelve")
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
		notice("背包空间不足：%s 仍在暂存区。" % item.item_name)
		return false
	save_base()
	return true

## At the base, insured gear arrives at receiving when its time comes, whether
## or not a contract is running out there (用户 2026-10-15: 时钟计时).
func _tick_insurance_clock(delta: float) -> void:
	_insurance_check -= delta
	if not in_base or _insurance_check > 0.0: return
	_insurance_check = INSURANCE_CHECK_SECONDS
	var arrived := base.tick_insurance()
	if arrived.is_empty(): return
	save_base()
	set_message("投保物品送回 %d 件，已到收货区。" % arrived.size())
	if is_instance_valid(tutorial_spotlight): tutorial_spotlight.request("insured_back")

## Insured gear that did not come out: back 2–4 hours later, and the
## insurance is used up by that one return. Returns the wait in seconds.
func _queue_insured(item: Item) -> int:
	var wait := rng.randi_range(FieldCatalog.INSURANCE_DELAY_SECONDS.x, FieldCatalog.INSURANCE_DELAY_SECONDS.y)
	item.insured = false
	item.carried_in = false
	base.queue_insured(item, wait)
	return wait

## Base insurance before leaving: the item's 交付价 in 龙门币 (保全系统修订案 §6).
func insurance_price(item: Item) -> int:
	return Economy.price(item)

## 重铸 / 校准 / 精调 at the base workbench only (装备前缀策划案 §2.5, §2.8):
## 龙门币 a third of the delivery price (at least 100), 校准 also a 研磨石,
## 精调 an 改量装置 and half as much again for every 精调 the piece has had.
const REFRESH_MATERIALS := {"reforge": {}, "calibrate": {"研磨石": 1}, "tune": {"改量装置": 1}}
const REFRESH_MIN_LMD := 100
const TUNE_STEP := 1.5

func refresh_cost(kind: String, item: Item) -> int:
	var base_cost := maxi(REFRESH_MIN_LMD, ceili(Economy.price(item) / 3.0))
	if kind == "tune": return roundi(base_cost * pow(research.tune_step(), item.tune_count))
	var cost := base_cost * research.refresh_factor()
	if kind == "reforge":
		if reforge_keep >= 0 and base.researched("prefix_lock"): cost *= 2.0   # 工程部Ⅴ
		if base.researched("reforge_pick"): cost *= 1.5                        # 工程部Ⅵ
	return roundi(cost)

## 工程部Ⅴ: the prefix 重铸 keeps (-1: none). Cleared after every 重铸.
var reforge_keep := -1
## 工程部Ⅵ: {"item": Item, "options": [prefixes, prefixes]} waiting for her pick.
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
	return materials_refusal(REFRESH_MATERIALS[kind])

## `line` (精调 only) is one of PrefixCatalog.rollable_lines(item).
func refresh_gear(kind: String, item: Item, line: Array = []) -> bool:
	if not refresh_refusal(kind, item).is_empty(): return false
	if kind == "tune" and not PrefixCatalog.rollable_lines(item).has(line): return false
	gold -= refresh_cost(kind, item)
	consume_materials(REFRESH_MATERIALS[kind])
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
	return roundi(maxi(REFRESH_MIN_LMD, ceili(Economy.price(item) / 3.0)) * DIRECTED_LMD)

## "" when 定向重铸 of `item` into `family` can be done now, else why not.
func directed_refusal(item: Item, family: String) -> String:
	if not in_base or not PrefixCatalog.eligible_item(item) or not PrefixFamilies.FAMILIES.has(family): return "无法改造"
	if base.ship_at != DIRECTED_ANCHOR or not voyage.sailing.is_empty(): return "需要停靠龙门"
	if exchange.rank(DIRECTED_FACTION) < Exchange.RANK_AT.size() - 1: return "需要龙门商会关系 R%d" % (Exchange.RANK_AT.size() - 1)
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
		if by.is_empty(): by[Workshop.BYPRODUCTS[rng.randi() % Workshop.BYPRODUCTS.size()]] = 1
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
	if exchange.rank("penguin") < FactionSpecials.rank_needed(SPECIAL_SLIP): return "需要关系 R%d" % FactionSpecials.rank_needed(SPECIAL_SLIP)
	if gold < FactionSpecials.SLIP_PRICE: return "龙门币不足"
	return ""

func buy_slip() -> bool:
	if not slip_refusal().is_empty(): return false
	gold -= FactionSpecials.SLIP_PRICE
	exchange._deliver_goods(SPECIAL_SLIP, 1)
	exchange.add_relation("penguin", 1)
	set_message("企鹅专递单已送到收货区。")
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
## home, onto the warehouse shelves; what they cannot hold, to staging.
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

## Sends `items`; returns how many went where ({shelf, staging, receiving}).
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

# --- 第二层：农业部与食堂 (势力特供策划案_v0_2 §三–§六) ---------------------------------

func farm_changed() -> void:
	save_base()
	if is_instance_valid(base_map): base_map.set_farm(provisions)

func _tick_kitchen() -> void:
	var done := provisions.tick()
	if done.is_empty(): return
	for job in done: broadcast("PRTS：食堂做好了 %s ×%d。" % [job.output, int(job.count)])
	save_base(not in_base)

## The 补给 for this contract: max HP and regeneration on the sheet, attack
## and attack speed as a lasting hex beside the flasks'. "" takes it off.
func _apply_meal(meal_id: String) -> void:
	run_meal = meal_id if Provisions.MEALS.has(meal_id) else ""
	if not is_instance_valid(player): return
	player.clear_hex("meal")
	var m: Dictionary = Provisions.MEALS.get(run_meal, {})
	var hex := {}
	for key in ["atk", "aspd"]:
		if m.has(key): hex[key] = float(m[key])
	if not hex.is_empty(): player.add_hex("meal", hex, -1.0)
	player._recompute_stats()

func meal_tier() -> int:
	return int(Provisions.MEALS.get(run_meal, {}).get("tier", 0))

func squad_chance() -> float:
	return Provisions.SQUAD_CHANCE if meal_tier() >= Provisions.SQUAD_CHANCE_TIER else FieldCatalog.SQUAD_CHANCE

func squad_max_uses() -> int:
	return Provisions.SQUAD_USES if meal_tier() >= Provisions.SQUAD_USES_TIER else 1

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

## The lift between the decks.
func ride_lift(to_deck: int) -> void:
	if not in_base or transitioning or not to_deck in [1, 2]: return
	close_modal()
	deck = to_deck
	if to_deck == 2: story_note("lift")
	base_map.set_deck(to_deck)
	player.clear_move_target()
	player.teleport(base_map.spawn_point("deck2" if to_deck == 2 else "deck_lift"))
	camera.global_position = camera_target() + camera_offset()

func insure(item: Item) -> bool:
	if not in_base or not carried_items().has(item) or not item.is_equippable() or item.insured or gold < insurance_price(item): return false
	gold -= insurance_price(item)
	item.insured = true
	story_note("insure")
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
	if not in_base or not deliverable_items().has(item) or item.effect == VoyageCatalog.CARGO_EFFECT or not _hand_over(item): return false
	gold += Economy.direct_price(item)
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
		gold += int(result.gold)
		story_note("order")
		set_message("订单完成：%s  ·  龙门币 +%s" % [text, Economy.format(result.gold)])
	else: set_message("已交付 %s ×%d：%s 还差 %d" % [item.item_name, int(result.used), text, base.orders.remaining(slot)])
	save_base()
	return true

func abandon_order(slot: int) -> bool:
	if not in_base or not base.orders.abandon(slot): return false
	set_message("已放弃订单：下次结算后补上新订单。")
	save_base()
	return true

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

func console_refusal() -> String:
	if base.console: return "已就位"
	if gold < BaseCatalog.CONSOLE_PRICE: return "龙门币不足"
	return materials_refusal(BaseCatalog.CONSOLE_MATERIALS)

func buy_console() -> bool:
	if not in_base or not console_refusal().is_empty(): return false
	consume_materials(BaseCatalog.CONSOLE_MATERIALS)
	gold -= BaseCatalog.CONSOLE_PRICE
	base.console = true
	save_base()
	set_message("仓库总控面板上线：仓管台可以查看和调取所有分区。")
	return true

func buy_drone() -> bool:
	if not in_base or not drone_refusal().is_empty(): return false
	consume_materials(BaseCatalog.DRONE_MATERIALS)
	gold -= BaseCatalog.DRONE_PRICE
	base.drone = true
	save_base()
	set_message("工程部的搬运无人机到位：在货箱前可以全部开箱并归类。")
	return true

## The facility's next level (BaseCatalog.FACILITIES): gold, then materials.
## `remote` is the 基建总控台 (or its quick button): only connected facilities.
func facility_refusal(id: String, remote := false) -> String:
	if remote and not base.is_connected_to_hub(id): return "未接入"
	var gate := gate_refusal(id)
	if not gate.is_empty(): return gate
	var refusal := base.facility_refusal(id, gold)
	return refusal if not refusal.is_empty() else materials_refusal(facility_cost(id))

## A faction relation a facility's building waits for ("" once met or built).
func gate_refusal(id: String) -> String:
	var gate: Dictionary = BaseCatalog.FACILITIES[id].get("gate", {})
	if gate.is_empty() or base.facility_level(id) >= 1: return ""
	if exchange.rank(str(gate.faction)) >= int(gate.rank): return ""
	return "需要%s关系 R%d" % [FactionCatalog.name_of(str(gate.faction)), int(gate.rank)]

func connect_refusal(id: String) -> String:
	if not id in BaseCatalog.connectable(): return "无效"
	if base.is_connected_to_hub(id): return "已接入"
	if not base.hub_built(): return "需要基建总控台"
	var gate := gate_refusal(id)
	if not gate.is_empty(): return gate
	if gold < int(BaseCatalog.CONNECT_COST.price): return "龙门币不足"
	return materials_refusal(BaseCatalog.connect_materials(id))

func connect_facility(id: String) -> bool:
	if not in_base or not connect_refusal(id).is_empty(): return false
	consume_materials(BaseCatalog.connect_materials(id))
	gold -= int(BaseCatalog.CONNECT_COST.price)
	base.connect_facility(id)
	save_base()
	set_message("%s已接入基建总控台。" % BaseCatalog.facility_name(id))
	return true

func facility_cost(id: String) -> Dictionary:
	return BaseCatalog.facility_step(id, base.facility_level(id) + 1).get("materials", {})

## The warehouse zones that build racks (one per Item.group_of).
const RACK_ZONES := [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET, Item.Category.MATERIAL]

## How many base upgrades could be bought right now from the hub (the 基建 marker).
func construction_ready() -> int:
	var n := 0
	for id in BaseCatalog.FACILITY_ORDER:
		if facility_refusal(id, true).is_empty() or connect_refusal(id).is_empty(): n += 1
	for refusal in [console_refusal(), drone_refusal(), upgrade_refusal("pack"), upgrade_refusal("safe"), camp_upgrade_refusal()]:
		if refusal.is_empty(): n += 1
	for zone in RACK_ZONES:
		if rack_refusal(zone).is_empty(): n += 1
	return n

func upgrade_facility(id: String, remote := false) -> bool:
	if not in_base or not BaseCatalog.FACILITIES.has(id) or not facility_refusal(id, remote).is_empty(): return false
	var step := BaseCatalog.facility_step(id, base.facility_level(id) + 1)
	consume_materials(step.materials)
	gold -= int(step.price)
	var level := base.raise_facility(id)
	save_base()
	set_message("%s升到 Lv%d：%s。" % [BaseCatalog.facility_name(id), level, step.opens])
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
		"reception": return base.report_unread or base.any_injured()
		"exchange": return not market.flash.is_empty() or not swan_popup.is_empty()
	return false

# --- Departure (§5.3) ----------------------------------------------------------

## Reasons to stop and look before leaving; empty when there are none.
func departure_warnings() -> Array[String]:
	var out: Array[String] = []
	if base.injured: out.append("生命上限 −%d%%（重伤）" % roundi(base.hp_penalty() * 100))
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
## Opens 干员养成 over whatever is showing; Esc / back returns to `back`.
func open_training(back: Callable = Callable()) -> void:
	if transitioning: return
	if is_instance_valid(_inventory_panel): _inventory_panel.hide()
	open_modal("training")
	menu.show_training(not in_base)
	menu.back_to = back if back.is_valid() else Callable()

func request_contract(region: String, start_camp: int = 0) -> void:
	if not in_base or transitioning: return
	_pending_start_camp = start_camp
	if departure_warnings().is_empty() and not kits_in_stock(region):
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

func carried_potions() -> Array[Item]:
	var out: Array[Item] = []
	for container in [inventory, safe_bag]:
		for item: Item in container.items:
			if item.is_potion(): out.append(item)
	return out

## Flasks carried, counting every one in a stack; "" counts all kinds.
func potion_count(type: String = "") -> int:
	var total := 0
	for item in carried_potions():
		if type == "" or item.potion_type == type: total += item.quantity
	return total

func _set_standard_potions(count: int) -> void:
	for item in carried_potions():
		inventory.remove(item)
		safe_bag.remove(item)
	for i in range(maxi(count, 0)):
		if inventory.add_stack(BaseCatalog.create_potion("A")) > 0: break

## The free 标准急救剂 for this contract go into the pack (what does not fit stays
## issued for next time).
func _issue_free_potions() -> void:
	# The departure camp's tier (复利数值改造清单 E); 医疗部Ⅴ adds one.
	var bonus := int(research.free_potion_tier_bonus()) if research != null and research.has_method("free_potion_tier_bonus") else 0
	var tier := mini(Scaling.TIER_MAX, Scaling.tier_of(start_floor) + bonus)
	while base.free_potions > 0 and inventory.add_stack(BaseCatalog.create_potion("A", tier)) == 0:
		base.free_potions -= 1

## Of the flasks she carries of `type`, the highest tier (pack before safe bag).
func _best_potion(type: String, carried: Array[Item]) -> Item:
	var pick: Item = null
	for item in carried:
		if item.potion_type == type and (pick == null or item.grade > pick.grade): pick = item
	return pick

## The best flask to drink now (AI driver): the first by POTION_ORDER, from the pack before the safe bag. At
## full health only the inhibitor is worth drinking (it also cleanses).
func _use_potion() -> void:
	var carried := carried_potions()
	if carried.is_empty(): return
	var pick: Item = null
	for type in POTION_ORDER:
		pick = _best_potion(type, carried)
		if pick != null: break
	if player.full_hp() and pick.potion_type != "C":
		pick = _best_potion("C", carried)
		if pick == null: return
	drink(pick)

## A hotbar flask slot: the first carried flask of `type`, pack before safe
## bag. Nothing happens when she has none of that kind.
func use_potion_type(type: String) -> bool:
	var pick := _best_potion(type, carried_potions())
	return drink(pick) if pick != null else false

## Drinks one flask she carries (a hotbar slot, or right click in the pack).
func drink(item: Item) -> bool:
	if in_base or item == null or not item.is_potion() or not carried_items().has(item): return false
	if player.is_controlled(): return false
	# 应急强心针 is never drunk: it fires by itself on a killing blow.
	if not PotionEffects.drinkable(item.potion_type):
		notice("应急强心针放在背包里就会生效")
		return false
	if item.quantity > 1: item.set_quantity(item.quantity - 1)
	else:
		inventory.remove(item)
		safe_bag.remove(item)
	var type := item.potion_type
	# A fixed amount for its tier, no bonus of any kind (复利数值改造清单 E);
	# only an operator's own trait (赫拉格: 30%) changes it.
	if PotionEffects.handles(type):
		set_message(potion_fx.apply(type))
		save_base(true)
		return true
	var amount := BaseCatalog.potion_heal(type, maxi(item.grade, 1)) * player.potion_heal_multiplier
	match type:
		"B":
			# A new gel replaces what was left of the last one.
			_slow_heal_left = amount
			_slow_heal_rate = amount / BaseCatalog.POTION_B_SECONDS
			set_message("缓释凝胶：%.0f 秒内回复 %d 生命" % [BaseCatalog.POTION_B_SECONDS, roundi(amount)])
		"C":
			player.heal(amount, true, false)
			run_contamination -= BaseCatalog.POTION_C_CLEANSE
			_suppress_timer = BaseCatalog.POTION_C_SUPPRESS_SECONDS
			set_message("抑制喷剂：回复 %d 生命，污染 −%d，%d 秒内累积减半" % [roundi(amount), int(BaseCatalog.POTION_C_CLEANSE), int(BaseCatalog.POTION_C_SUPPRESS_SECONDS)])
		_:
			player.heal(amount, true, false)
			set_message("标准急救剂：回复 %d 生命" % roundi(amount))
	save_base(true)
	return true

## Below the low threshold she starts drinking the auto slot's kind, one flask
## after another, until life is at or above the high one (用户 2026-10-15). A
## gel waits for the last gel to finish, since a new one replaces it.
func _tick_auto_potion(delta: float) -> void:
	_auto_potion_gap = maxf(0.0, _auto_potion_gap - delta)
	var action := Hotbar.auto_potion()
	if action == "" or in_base:
		_auto_drinking = false
		return
	var limits := Hotbar.auto_thresholds()
	var ratio := player.hp_ratio()
	if ratio < limits[0]: _auto_drinking = true
	if ratio >= limits[1] or player.full_hp(): _auto_drinking = false   # the cap may sit below the high mark
	if not _auto_drinking or _auto_potion_gap > 0.0: return
	var type: String = Hotbar.ACTIONS[action].potion
	if type == "B" and _slow_heal_left > 0.0: return
	if use_potion_type(type): _auto_potion_gap = AUTO_POTION_GAP

# --- Medical (§4) ------------------------------------------------------------

## Contamination right now: this contract's dose so far. It starts from 0 at
## every departure and is gone at settlement (用户 2026-10-15: 污染不带出局外).
func current_contamination() -> float:
	return clampf(run_contamination, 0.0, BaseCatalog.CONTAMINATION_MAX)

## Contamination per second at this moment of a contract.
func contamination_rate() -> float:
	if in_base: return 0.0
	var rate := 0.0
	if region_id == "mine": rate += BaseCatalog.CONTAMINATION_MINE
	if route_index == 2: rate += BaseCatalog.CONTAMINATION_DEEP_ROUTE
	rate += count_effect("raw_ore") * BaseCatalog.CONTAMINATION_PER_ORE
	rate += count_effect(SEALED_ORE) * FeatureCatalog.SEALED_ORE_RATE
	rate += count_effect("dirty") * CONTAMINATION_PER_DIRTY
	if _suppress_timer > 0.0: rate *= 0.5
	return rate * maxf(0.0, 1.0 + float(player.stats.get("contam_pct", 0.0))) * features.growth_mult("contamination", floor_number)

## Shown on the field HUD only when it is moving or could: the mine, the deep
## route, or ore in the pack.
func contamination_visible() -> bool:
	return not in_base and (region_id == "mine" or route_index == 2 or count_effect("raw_ore") > 0 or count_effect(SEALED_ORE) > 0)

## At departure: injury and contamination set max HP, potion healing and
## self-regeneration for the whole contract; the pharmacy fills the belt.
## Item affixes and builds change how many flasks fit: standard flasks fill
## extra room, and losses come off the end (the bought fourth bottle first).
func _apply_medical_state() -> void:
	player.regen_blocked = false
	potion_fx.game = self
	potion_fx.reset()
	run_contamination = 0.0
	player.cold = 0.0
	player.condition_hp_penalty = -1.0   # force the recompute
	player.set_condition(base.injured, current_contamination())
	_potion_heal_factor = 1.0 - BaseCatalog.contamination_potion_penalty(current_contamination())
	_suppress_timer = 0.0
	_slow_heal_left = 0.0
	_announced_tier = 0

func _tick_medical(delta: float) -> void:
	potion_fx.tick(delta)
	if _slow_heal_left > 0.0:
		var heal_step := minf(_slow_heal_left, _slow_heal_rate * delta)
		_slow_heal_left -= heal_step
		player.heal(heal_step, false, false)
	_suppress_timer = maxf(0.0, _suppress_timer - delta)
	run_contamination += contamination_rate() * delta
	# Contamination works live (§6 D): max HP, regeneration and potion healing.
	player.set_condition(base.injured, current_contamination())
	_potion_heal_factor = 1.0 - BaseCatalog.contamination_potion_penalty(current_contamination())
	var tier := BaseCatalog.contamination_tier(current_contamination())
	if tier > _announced_tier and tier > 0:
		set_message("污染升到 %d（%s）" % [roundi(current_contamination()), BaseCatalog.CONTAMINATION_TIER_NAMES[tier]])
	_announced_tier = maxi(_announced_tier, tier)

## Pharmacy (药剂进背包): one flask straight into the pack for the next contract.
## 标准急救剂 are free while this contract's free issue lasts.
func buy_potion(type: String) -> bool:
	if not in_base or not BaseCatalog.POTIONS.has(type): return false
	var price := potion_price(type)
	if price < 0 or gold < price: return false
	var flask := BaseCatalog.create_potion(type, deepest_tier())
	if inventory.add_stack(flask) > 0:
		notice("背包空间不足：药剂要占一格。")
		return false
	gold -= price
	if type == "A" and price == 0: base.free_potions -= 1
	save_base()
	return true

## The pharmacy's price at the deepest camp's tier (v1.1 §4.1); 0 while the
## free issue lasts, -1 before the rank allows it.
func potion_price(type: String) -> int:
	var price := base.potion_price(type)
	return Economy.tiered(price, deepest_tier()) if price > 0 else price

## Treatment: × the income index of the floor she fell on (v1.1 §4.1); 医疗部Ⅱ halves it.
func injury_price(id: String) -> int:
	var tier := int(base.injuries.get(id, 1)) if (base.injuries.get(id, 1) is int or base.injuries.get(id, 1) is float) else 1
	var price := Economy.tiered(BaseCatalog.INJURY_TREATMENT, tier)
	return price / 2 if base.researched("injury_fee") else price

## Treats one operator's injury (the one who deploys next by default).
func treat_injury(id: String = "") -> bool:
	if id.is_empty(): id = base.operator
	if not in_base or not base.injuries.has(id) or gold < injury_price(id): return false
	gold -= injury_price(id)
	base.injuries.erase(id)
	save_base()
	set_message("%s的重伤已治愈。" % Operators.display_name(id))
	return true

func _spawn_wave() -> void:
	if world_map.boss_layout:
		_spawn_boss_floor()
		return
	# Ordinary enemies defend their own origin along the main route. Search
	# encounters have their own budget, so no region leaves reward spurs bare.
	# Scaled with the route: the segment is about twice the ground it used to
	# be, so holding the old budget would have thinned encounters out rather
	# than made the map feel bigger. Density stays roughly where it was.
	# 用户 2026-10-17: 增加敌人数量 — 1.5× the old 6 + 2 per route step. They
	# stand on the odd route points as before (an even one can be a bridge
	# deck); once there are more enemies than points, they share them in
	# groups, spread evenly along the route.
	var profile := FieldCatalog.depth_profile(floor_number)
	var count: int = 9 + route_index * 3 + int(profile.enemies)
	var extra_elites: int = int(profile.elites)
	var slots := maxi(1, world_map.main_path.size() / 2)
	var at_slot := {}
	for i in range(count):
		var elite := (i % 3 == 2 if region_id == "snow" else i == count - 1) or (route_index == 2 and i == count - 2)
		if not elite and extra_elites > 0 and i % 3 == 1:
			elite = true
			extra_elites -= 1
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
	# 萨米: a herd of 岩角兽 grazing off the route half the time (装备扩充 §2.1).
	if region_id == "snow" and world_map.main_path.size() > 8 and rng.randf() < 0.5:
		_herd_count += 1
		var spot: Vector2 = world_map.main_path[world_map.main_path.size() / 2]
		for h in range(rng.randi_range(3, 5)):
			var beast := _spawn_enemy(Vector3(spot.x + (h % 3 - 1) * 1.4, 0, spot.y + (h / 3) * 1.4 + 2.0), false, false, "rock_hornbeast")
			beast.herd = _herd_count
	_spawn_guard_post(world_map.buff_position, "强化装置", false)
	# Every authored supply pocket pays off, including the optional loop.
	# Each is a typed point of interest (掉落物策划案 §4.1).
	var places: Array = world_map.cache_positions.map(func(at: Vector3) -> String: return world_map.district_at(Vector2(at.x, at.z)))
	var kinds := LootTables.plan_points(region_id, world_map.cache_positions.size(), rng, places)
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
		# 用户 2026-10-14: 兴趣点旁边随机刷新守卫 — none, one, two or three, the
		# third-of-a-squad now and then led by an elite (and paying for it).
		var guards: int = POI_GUARDS[LootTables._pick_weighted(POI_GUARD_WEIGHTS, rng)]
		if region_id == "snow" and kinds[i] == "camp": guards = maxi(guards, 2)
		if mansions[i]: guards = maxi(guards, 2)
		box.guarded = guards > 0 and (route_index == 2 or rng.randf() < (0.45 if guards == 3 else 0.12))
		# 巨壳藤蔓 waits inside one weapon or tool box now and then (萨米).
		if region_id == "snow" and not mimic_placed and kinds[i] in ["weapon_box", "tool_box"] and rng.randf() < 0.25:
			box.mimic = true
			mimic_placed = true
		box.variant = _poi_variant(kinds[i], world_map.cache_positions[i])
		add_child(box)
		box.global_position = world_map.cache_positions[i]
		# 陷落雪祀 guards the tundra camps.
		if guards > 0:
			_spawn_guard_post(box.global_position, box.title(), box.guarded, "fallen_snowpriest" if region_id == "snow" and kinds[i] == "camp" else "", guards)
	# A work light at every search point, so the eye is drawn to them in the
	# dark (地图表现调研 §2: light leads; 兴趣点策划案_v1.md §4).
	var work_lights: Array[Dictionary] = []
	for at in world_map.cache_positions:
		work_lights.append({"at": at + Vector3.UP * 1.2, "color": Color(0.75, 0.6, 0.38), "radius": 4.5})
	_spawn_sentinels()
	_spawn_wanderers()
	if is_outpost_floor(): _spawn_outpost()
	if is_bounty_floor(): _spawn_bounty()
	if is_recruit_floor(): _spawn_recruit()
	if is_handover_floor(): _spawn_handover()
	if floor_number % FieldCatalog.CAMP_INTERVAL != 0:
		_spawn_traps()
		_spawn_trace()
	# The faint glow (用户 2026-10-17: 幽幽的光) of a trace and of a sealed vault's
	# edge, baked with the work lights in one pass.
	if is_instance_valid(trace_point):
		var wide := 1.5 if RecruitCatalog.is_big(trace_point.key) else 1.0
		work_lights.append({"at": trace_point.global_position + Vector3.UP * 0.8, "color": trace_point.glow * TracePoint.GLOW_GAIN, "radius": TracePoint.GLOW_RADIUS * wide * research.glow_factor()})
	if world_map.vault_seal != null:
		var lamp: Dictionary = world_map.vault_seal.glow_lamp()
		lamp.radius = float(lamp.radius) * research.glow_factor()   # 情报部Ⅰ
		work_lights.append(lamp)
	if is_instance_valid(world_map.terrace_dressing): world_map.terrace_dressing.add_lamps(work_lights)
	if not world_map.roadblock.is_empty() and floor_number % FieldCatalog.CAMP_INTERVAL != 0: _spawn_car()
	_spawn_fires()
	_spawn_shower()
	threat.plan_floor(region_id, floor_enemies().size())

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
	if is_handover_floor(): _spawn_handover()
	_spawn_fires()
	_spawn_shower()
	threat.plan_floor(region_id, floor_enemies().size())

## This floor's enemies still standing (not the grazing herds).
func floor_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return e.game == self and not e._dead and not e.attack_profile.get("neutral", false))

# --- 地图特色 (地图特色策划案_v1_0.md) ----------------------------------------------

const SEALED_ORE := "sealed_ore"
## This floor's 火堆 (萨米) and 净化喷淋点 (矿区).
var fires: Array[FirePit] = []
var shower: ShowerPoint
## The shower being used: seconds held so far (−1: not), and her life when it began.
var shower_progress := -1.0
var _shower_hp := 0.0
## The fire the fuel picker is open for.
var fuel_fire: FirePit
## Base kits at departure: kit id -> false when unticked (ticked by default).
var kit_choice := {}

## Takes the base kits ticked for a contract in `region`, one per feature.
func _take_kits(region: String) -> void:
	for id in chosen_kits(region):
		var tier := base.take_kit(id)
		if tier > 0: features.kits[str(FeatureCatalog.KITS[id].feature)] = [id, tier]
	kit_choice.clear()

## The kits that would go on a contract in `region`: in stock and not
## unticked; plain and refined do not stack, the refined one wins.
func chosen_kits(region: String) -> Array[String]:
	var by_feature := {}
	for id in FeatureCatalog.kits_for(region):
		if base.kit_stock(id) <= 0 or not bool(kit_choice.get(id, true)): continue
		var feature: String = FeatureCatalog.KITS[id].feature
		if not by_feature.has(feature) or id.ends_with("_plus"): by_feature[feature] = id
	var out: Array[String] = []
	for feature in by_feature: out.append(str(by_feature[feature]))
	return out

## Ticks or unticks a kit at departure; ticking one of a kind unticks the other.
func toggle_kit(id: String, region: String) -> void:
	if not FeatureCatalog.KITS.has(id): return
	var on := not kit_on(id, region)
	kit_choice[id] = on
	var other := id.trim_suffix("_plus") if id.ends_with("_plus") else id + "_plus"
	if on: kit_choice[other] = false

func kit_on(id: String, region: String) -> bool:
	return id in chosen_kits(region)

## Whether any kit for `region` is in stock (the departure card shows them).
func kits_in_stock(region: String) -> bool:
	return FeatureCatalog.kits_for(region).any(func(id): return base.kit_stock(id) > 0)

func kit_refusal(id: String) -> String:
	var kit: Dictionary = FeatureCatalog.KITS[id]
	if base.facility_level("store") < int(kit.store): return "商店 Lv%d" % int(kit.store)
	if gold < FeatureCatalog.kit_price(id, deepest_tier()): return "龙门币不足"
	return ""

## 可露希尔 at the base sells the kits for 龙门币, at the deepest camp's tier
## (v1.1 §4.1); they wait at the base.
func buy_kit(id: String) -> bool:
	if not in_base or not FeatureCatalog.KITS.has(id) or not kit_refusal(id).is_empty(): return false
	gold -= FeatureCatalog.kit_price(id, deepest_tier())
	base.add_kit(id, deepest_tier())
	save_base()
	return true

## The meters the HUD shows: 污染 as before, 血债 in 叙拉古, 寒冷 in 萨米.
func shown_features() -> Array[String]:
	var out: Array[String] = []
	if in_base: return out
	if region_id == "siracusa": out.append("debt")
	if region_id == "snow": out.append("cold")
	if contamination_visible(): out.append("contamination")
	return out

func feature_value(kind: String) -> float:
	return current_contamination() if kind == "contamination" else features.value(kind)

## A second, now: what the HUD shows next to the value.
func feature_rate(kind: String) -> float:
	match kind:
		"contamination": return contamination_rate()
		"cold": return cold_rate()
	return 0.0

## 寒冷 a second at this moment: rising on a 萨米 floor, falling inside a lit fire.
func cold_rate() -> float:
	if in_base or in_camp or region_id != "snow": return 0.0
	if warm_fire() != null: return -FeatureCatalog.FIRE_WARM
	var rate := FeatureCatalog.COLD_RATE + (FeatureCatalog.COLD_DEEP if route_index == 2 else 0.0)
	# 埃克提尔尼尔's blizzard from tier 5 (Boss与守卫者策划案 §6).
	if boss_fight() and outpost_boss.figure_id == "eikthyrnir" and outpost_boss.tier >= 5: rate *= BossCatalog.BLIZZARD
	return rate * features.growth_mult("cold", floor_number)

## The lit fire she stands at, if any.
func warm_fire() -> FirePit:
	if not is_instance_valid(player): return null
	for fire in fires:
		if is_instance_valid(fire) and fire.lit() and fire.warms(player.global_position): return fire
	return null

func _tick_features(delta: float) -> void:
	for fire in fires:
		if is_instance_valid(fire): fire.burn(delta)
	var cold_step := cold_rate() * delta
	if cold_step >= 0.0: features.add("cold", cold_step * potion_fx.cold_mult())
	else: features.reduce("cold", -cold_step)
	player.cold = features.value("cold")
	if region_id == "siracusa" and not in_camp and features.reckoning_due(delta):
		# On a boss floor 扎罗 takes the 清算时刻 himself; no squad comes (Q6).
		if boss_fight() and outpost_boss.figure_id == "zaro":
			features.reckon_wait = FeatureCatalog.RECKONING_EVERY
			outpost_boss.begin_reckoning()
			broadcast("PRTS：博士，清算时刻。")
		else: _spawn_reckoning()
	_tick_shower(delta)
	for kind in ["debt", "cold"]:
		var reached := features.newly_reached(kind)
		if reached > 0: set_message("%s %d（%s）" % [FeatureCatalog.NAMES[kind], roundi(features.value(kind)), FeatureCatalog.TIER_NAMES[kind][reached]])
	var step := floori(maxi(floor_number - 1, 0) / FeatureCatalog.DEPTH_BLOCK)
	if step > features.depth_step:
		features.depth_step = step
		var own := FeatureCatalog.feature_of(region_id)
		if not own.is_empty(): broadcast("PRTS：博士，越往深处，%s来得越快。" % FeatureCatalog.NAMES[own])

## 火堆 (§5.3): two or three on every 萨米 floor, off the main path at a quarter,
## a half and three quarters of the way; one by a 冰原营地 (one at most) and
## one by the random extraction.
func _spawn_fires() -> void:
	fires.clear()
	if region_id != "snow": return
	# The arena's two fires, the first one lit (Boss战场地策划案 §4.3).
	if is_instance_valid(arena):
		for at in arena.fire_spots():
			var pit := FirePit.new()
			pit.name = "FirePit"
			world_map._generated_root.add_child(pit)
			pit.global_position = Vector3(at.x, ground_y(at), at.z)
			fires.append(pit)
		if not fires.is_empty(): fires[0].feed(BossCatalog.FIRE_START)
		return
	var path: PackedVector2Array = world_map.main_path
	if path.size() < 6: return
	var count := FeatureCatalog.FIRES + (1 if rng.randf() < FeatureCatalog.FIRE_EXTRA else 0)
	var shares: Array = [0.33, 0.66] if count == 2 else [0.25, 0.5, 0.75]
	var spots: Array[Vector3] = []
	for share in shares:
		var i := clampi(int(path.size() * float(share)), 1, path.size() - 2)
		var along := (path[i + 1] - path[i - 1]).normalized()
		for attempt in range(10):
			var side := Vector2(-along.y, along.x) * (1.0 if attempt % 2 == 0 else -1.0) * rng.randf_range(FeatureCatalog.FIRE_OFFSET.x, FeatureCatalog.FIRE_OFFSET.y)
			var at := world_map.nearest_walkable(Vector3(path[i].x + side.x, 0, path[i].y + side.y))
			if _fire_spot_ok(at, spots, attempt < 6):
				spots.append(at)
				break
	# At most one 冰原营地 a floor keeps a fire (用户 2026-10-19).
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box == null or box.game != self or box.kind != "camp": continue
		var at := world_map.nearest_walkable(box.global_position + Vector3(2.4, 0, 0))
		if _fire_spot_ok(at, spots, false):
			spots.append(at)
			break
	if is_extraction_floor() and is_instance_valid(world_map.exit_node):
		var at := world_map.nearest_walkable(world_map.exit_node.global_position + Vector3(0, 0, 3.0))
		if _fire_spot_ok(at, spots, false): spots.append(at)
	for at in spots:
		var fire := FirePit.new()
		fire.name = "FirePit"
		world_map._generated_root.add_child(fire)
		fire.global_position = Vector3(at.x, ground_y(at), at.z)
		fires.append(fire)

## Off the vault and apart from the other fires; `strict` also keeps it clear
## of the floor's marks and FIRE_ENEMY_CLEAR from any enemy.
func _fire_spot_ok(at: Vector3, placed: Array[Vector3], strict: bool = true) -> bool:
	var flat := Vector2(at.x, at.z)
	if world_map.vault_hidden(flat): return false
	for other in placed:
		if other.distance_to(at) < FeatureCatalog.FIRE_RADIUS * 2.0: return false
	if not strict: return true
	if not _trap_spot_ok(at, []): return false
	for enemy in floor_enemies():
		if Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(flat) < FeatureCatalog.FIRE_ENEMY_CLEAR: return false
	return true

func near_fire() -> FirePit:
	for fire in fires:
		if is_instance_valid(fire) and near(fire): return fire
	return null

## The fuels in the pack (not the safe bag): id -> count.
func pack_fuels() -> Dictionary:
	var out := {}
	for item in inventory.items:
		if FeatureCatalog.FUELS.has(item.material_id): out[item.material_id] = int(out.get(item.material_id, 0)) + item.quantity
	return out

## E at a fire: the picker of what to burn; nothing without fuel.
func _open_fuel(fire: FirePit) -> void:
	if pack_fuels().is_empty(): return
	fuel_fire = fire
	open_modal("fuel")
	menu.show_fuel()

## One piece of `id` from the pack onto the fire (用户 2026-10-19: she picks which).
func burn_fuel(id: String, fire: FirePit = null) -> bool:
	if fire == null: fire = fuel_fire
	if not is_instance_valid(fire) or not FeatureCatalog.FUELS.has(id): return false
	if fire.burn_left >= FeatureCatalog.FIRE_MAX: return false
	for item in inventory.items:
		if item.material_id != id: continue
		if item.quantity > 1: item.set_quantity(item.quantity - 1)
		else: inventory.remove(item)
		fire.feed(float(FeatureCatalog.FUELS[id]))
		return true
	return false

## 净化喷淋点 (§3.3): on SHOWER_CHANCE of mine floors, beside the main path.
func _spawn_shower() -> void:
	shower = null
	shower_progress = -1.0
	if region_id != "mine" or floor_number % FieldCatalog.CAMP_INTERVAL == 0: return
	if not force_shower and rng.randf() >= FeatureCatalog.SHOWER_CHANCE: return
	var path: PackedVector2Array = world_map.main_path
	if path.size() < 6: return
	for attempt in range(20):
		var i := rng.randi_range(2, path.size() - 3)
		var along := (path[i + 1] - path[i - 1]).normalized()
		var side := Vector2(-along.y, along.x) * (1.0 if attempt % 2 == 0 else -1.0) * rng.randf_range(3.0, 5.0)
		var at := world_map.nearest_walkable(Vector3(path[i].x + side.x, 0, path[i].y + side.y))
		if not _trap_spot_ok(at, []): continue
		shower = ShowerPoint.new()
		shower.name = "ShowerPoint"
		world_map._generated_root.add_child(shower)
		shower.global_position = Vector3(at.x, ground_y(at), at.z)
		return

## Place one whatever the roll (tests and captures).
var force_shower := false

func _start_shower() -> void:
	shower_progress = 0.0
	_shower_hp = player.hp

## Held SHOWER_SECONDS beside it: −SHOWER_CUT; a hit or a step away breaks it off.
func _tick_shower(delta: float) -> void:
	if shower_progress < 0.0: return
	if not is_instance_valid(shower) or shower.used or not near(shower) or player.hp < _shower_hp - 0.5:
		shower_progress = -1.0
		if is_instance_valid(shower): shower.spraying(false)
		return
	shower_progress += delta
	shower.spraying(true)
	if shower_progress < FeatureCatalog.SHOWER_SECONDS: return
	shower_progress = -1.0
	shower.use()
	run_contamination = maxf(0.0, current_contamination() - FeatureCatalog.SHOWER_CUT)
	set_message("污染 −%d" % int(FeatureCatalog.SHOWER_CUT))

## A field supply used from the pack (right click): the sealer seals one ore,
## the others take their feature down.
func use_supply(item: Item) -> bool:
	if in_base or not FeatureCatalog.is_supply(item) or not carried_items().has(item): return false
	var data: Dictionary = FeatureCatalog.SUPPLIES[item.material_id]
	if item.material_id == "源石矿封装器":
		var ore := _unsealed_ore()
		if ore == null: return false
		seal_ore(ore)
	else:
		var kind: String = data.feature
		features.reduce(kind, float(data.cut))
		set_message("%s −%d" % [FeatureCatalog.NAMES[kind], int(data.cut)])
	_spend_one(item)
	save_base(true)
	return true

func _spend_one(item: Item) -> void:
	if item.quantity > 1: item.set_quantity(item.quantity - 1)
	else:
		inventory.remove(item)
		safe_bag.remove(item)

func _unsealed_ore() -> Item:
	for item in carried_items():
		if item.effect == "raw_ore": return item
	return null

## Right click on a raw ore with a sealer in the pack or safe bag seals it.
func seal_with_sealer(ore: Item) -> bool:
	if in_base or ore == null or ore.effect != "raw_ore": return false
	for item in carried_items():
		if item.material_id == "源石矿封装器":
			seal_ore(ore)
			_spend_one(item)
			return true
	return false

## 简易封装的源石原矿 (用户 2026-10-19): the same ore and price, 0.01/s.
func seal_ore(ore: Item) -> void:
	ore.effect = SEALED_ORE
	ore.item_name = FeatureCatalog.SEALED_ORE_NAME
	ore.description = "简易封装：携带时每块每秒污染 +0.01。"
	set_message(FeatureCatalog.SEALED_ORE_NAME)

## 可露希尔 in a camp: the field supplies and 固体燃料 for 赤金.
func supply_price(id: String) -> int:
	return FeatureCatalog.FUEL_BARS if id == "固体燃料" else int(FeatureCatalog.SUPPLIES[id].bars)

func supply_item(id: String) -> Item:
	return MaterialCatalog.create(id, 1, region_id) if id == "固体燃料" else FeatureCatalog.create_supply(id)

func closure_buy_supply(id: String) -> bool:
	if not in_camp or not id in FeatureCatalog.CAMP_SUPPLIES: return false
	var price := supply_price(id)
	if gold_available() < price: return false
	if inventory.add_stack(supply_item(id)) > 0:
		notice("背包空间不足。")
		return false
	_pay_gold(price)
	save_base(true)
	return true

## 营地处理: contamination −CAMP_CLEANSE once a camp.
func camp_cleanse_refusal() -> String:
	if not in_camp: return "营地"
	if features.camp_cleansed: return "已处理"
	if current_contamination() <= 0.0: return "无"
	if gold_available() < FeatureCatalog.CAMP_CLEANSE_BARS: return "赤金不足"
	return ""

func camp_cleanse() -> bool:
	if not camp_cleanse_refusal().is_empty(): return false
	_pay_gold(FeatureCatalog.CAMP_CLEANSE_BARS)
	features.camp_cleansed = true
	run_contamination = maxf(0.0, current_contamination() - FeatureCatalog.CAMP_CLEANSE)
	save_base(true)
	return true

## 赔偿金: 血债 −CAMP_DEBT, one 赤金 dearer each time in the same camp.
func camp_debt_refusal() -> String:
	if not in_camp: return "营地"
	if features.value("debt") <= 0.0: return "无"
	if gold_available() < features.camp_debt_price(): return "赤金不足"
	return ""

func camp_pay_debt() -> bool:
	if not camp_debt_refusal().is_empty(): return false
	_pay_gold(features.camp_debt_price())
	features.camp_debt_paid += 1
	features.reduce("debt", FeatureCatalog.CAMP_DEBT)
	save_base(true)
	return true

## 仇家 (血债 60, §4.4): the families hit harder …
func feud_damage(enemy: Enemy) -> float:
	if region_id != "siracusa" or not FeatureCatalog.family(enemy.enemy_type) or features.tier("debt") < 1: return 1.0
	return 1.0 + FeatureCatalog.FEUD_DAMAGE

## … and see her from further.
func feud_sight(enemy: Enemy) -> float:
	if region_id != "siracusa" or not FeatureCatalog.family(enemy.enemy_type) or features.tier("debt") < 1: return potion_fx.sight_mult()
	return (1.0 + FeatureCatalog.FEUD_SIGHT) * potion_fx.sight_mult()

# --- 威胁值 (ThreatMeter, 用户 2026-10-14) ------------------------------------------

## Whether the meter fills right now: on a floor while the field runs, and
## while 坎诺特's shop is open; never in a camp or near the Rhodes squad.
func threat_rising() -> bool:
	if in_base or in_camp or transitioning or _settled or not is_instance_valid(player): return false
	if not simulation_active() and modal != "trader": return false
	return not near_squad()

func near_squad() -> bool:
	return encounter == "squad" and is_instance_valid(world_map.encounter_node) and world_map.encounter_node.visible 		and player.global_position.distance_to(world_map.encounter_node.global_position) < ThreatMeter.SQUAD_CALM_RADIUS

## The wave a "being tracked" line was given for (博士主角叙事修订案 §4).
var _tracked_warned := -1

func _tick_threat(delta: float) -> void:
	var boost := (1.0 + ThreatMeter.SENTINEL_BOOST * alerted_sentinels()) * market.threat_mult(region_id) * research.threat_factor() * potion_fx.threat_mult() * player.families.threat_mult()
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
	return get_tree().get_nodes_in_group("sentinels").filter(func(e): return e.game == self and e.alerted()).size()

## A 萨卡兹哨兵 has seen her and runs.
func on_sentinel_spotted(_sentinel: Enemy) -> void:
	broadcast("PRTS：萨卡兹哨兵发现了博士的踪迹。")

## The next patrol onto this floor: stronger with every wave here.
func _spawn_patrol() -> void:
	threat.wave += 1
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
## 用户 2026-10-17: 3–5 groups (was 2–4).
const WANDER_GROUPS := Vector2i(3, 5)
## Guards at a point of interest and their odds: 15% none, 20% one, 35% two, 30% three
## (用户 2026-10-17, was 30/20/30/20).
const POI_GUARDS := [0, 1, 2, 3]
const POI_GUARD_WEIGHTS := [15.0, 20.0, 35.0, 30.0]
const WANDER_CLEAR := 30.0

func _spawn_wanderers() -> void:
	var path: PackedVector2Array = world_map.main_path
	if path.size() < 6: return
	var spots: Array[Vector2] = []
	for p in path:
		if p.distance_to(Vector2(ContinuousWorldMap.ENTRY_POSITION.x, ContinuousWorldMap.ENTRY_POSITION.z)) >= WANDER_CLEAR: spots.append(p)
	if spots.is_empty(): return
	var rid := world_map.navigation_map_rid()
	var groups := rng.randi_range(WANDER_GROUPS.x, WANDER_GROUPS.y)
	while groups > 0 and not spots.is_empty():
		var at: Vector2 = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		# Only ground she can walk to from the entry (not a deck over the road).
		var start := world_map.nearest_walkable(Vector3(at.x, 0.0, at.y))
		var walk := NavigationServer3D.map_get_path(rid, ContinuousWorldMap.ENTRY_POSITION, start, true)
		if walk.size() < 2 or walk[walk.size() - 1].distance_to(start) > 1.5: continue
		groups -= 1
		var size := 1 if rng.randf() < 0.3 else 2
		for k in range(size):
			var ranged := k == 1 and region_id != "mine"
			var point := start if k == 0 else world_map.nearest_walkable(start + Vector3(1.4, 0.0, 0.0))
			var enemy := _spawn_enemy(point, false, ranged, _pick_enemy_type(false, ranged))
			enemy.configure_wander()

## A main-path point SPAWN_MIN–SPAWN_MAX from her, clear of the exit, the
## encounter spot and the route markers; else the farthest clear one.
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
	return fits[rng.randi() % fits.size()] if not fits.is_empty() else farthest

## Where a patrol walks next: anywhere on the main path or at a search point.
func patrol_waypoint(_from: Vector3) -> Vector3:
	var count := world_map.main_path.size() + world_map.cache_positions.size()
	if count == 0: return _from
	var pick := rng.randi() % count
	if pick < world_map.main_path.size():
		var p: Vector2 = world_map.main_path[pick]
		return world_map.nearest_walkable(Vector3(p.x, 0.0, p.y))
	return world_map.nearest_walkable(world_map.cache_positions[pick - world_map.main_path.size()])

## 萨卡兹哨兵 keep watch beside the main path: at most one a floor, on
## SENTINEL_CHANCE of floors (用户 2026-10-14: 刷新少一点，每一层限定最多一个).
## Patrols never bring one: they draw from the region pools only.
func _spawn_sentinels() -> void:
	var path: PackedVector2Array = world_map.main_path
	if path.size() < 8 or rng.randf() >= ThreatMeter.SENTINEL_CHANCE: return
	var index := clampi(int(path.size() * rng.randf_range(0.3, 0.65)), 2, path.size() - 2)
	var along := (path[index + 1] - path[index - 1]).normalized()
	var side := Vector2(-along.y, along.x) * 2.0
	_spawn_enemy(Vector3(path[index].x + side.x, 0.0, path[index].y + side.y), false, true, "sentinel")

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

## The outpost squad holds the ground just before the route markers: a leader
## (an elite with OUTPOST_BOSS_HP life and OUTPOST_BOSS_ATK attack) and its guards.
## Boss与守卫者策划案 §3.1: the 20th floors hold the region's boss alone, the
## 10th between a warden with its two guards.
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
	figure.max_health *= enemy_life_multiplier(player.f("enemy_hp"))
	figure.atk *= growth
	figure.defense *= growth
	figure.finish_setup()
	figure.died.connect(_on_enemy_died)
	return figure

## Fighting the floor's region boss right now (the threat meter waits, Q5).
func boss_fight() -> bool:
	return is_instance_valid(outpost_boss) and outpost_boss.in_fight()

func on_boss_engaged(figure: Boss) -> void:
	sound.play("stun_hum")
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
	if rng.randf() >= BossCatalog.WARDEN_EXCLUSIVE: return
	var ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "exclusive" and str(SpecialGear.GEAR[id].region) == region_id)
	if ids.is_empty(): return
	var item := SpecialGear.create(ids[rng.randi() % ids.size()], floor_number, rng, true)
	item.origin_region = region_id
	_drop_at(at, [{"item": item}], 0.7)


## The hunt contract's bounty: an elite with HUNT_HP life on its floor, marked.
func is_bounty_floor() -> bool:
	return str(contract.get("type", "")) == "hunt" and not bounty_killed and floor_number == start_floor + int(contract.offset)

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
		base.contract_offers[region] = FieldCatalog.roll_contracts(region, rng)
	# 外勤部Ⅰ: the fourth kind as well.
	var held: Array = base.contract_offers[region]
	while base.researched("offer_slot") and held.size() < contract_offer_count():
		var kinds := held.map(func(c): return str(c.type))
		for extra in FieldCatalog.roll_contracts(region, rng):
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
		if not offer.has("roll"): offer.roll = snappedf(rng.randf_range(Economy.CONTRACT_ROLL.x, Economy.CONTRACT_ROLL.y), 0.01)
	var offers: Array = (base.contract_offers[region] as Array).duplicate()
	for id in RecruitCatalog.in_region(region):
		if base.recruit_ready(id): offers.append(RecruitCatalog.contract_for(id))
	offers.append_array(voyage.delivery_offers(region))
	return offers

## Ordinary offers at the dispatch desk: 3, 4 with 外勤部Ⅰ.
func contract_offer_count() -> int:
	return FieldCatalog.CONTRACT_OFFERS + (1 if base.researched("offer_slot") else 0)

## 外勤部Ⅱ: swaps ordinary offer `index` of `region` for a fresh one of another
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
		for fresh in FieldCatalog.roll_contracts(region, rng):
			if str(fresh.type) in kinds: continue
			fresh.roll = snappedf(rng.randf_range(Economy.CONTRACT_ROLL.x, Economy.CONTRACT_ROLL.y), 0.01)
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
	var mult := FeatureCatalog.DEBT_SCALE * features.growth_mult("debt", floor_number) * voyage.debt_mult(region_id)
	if player.equipped_effect("saluzzo_crest"): mult *= 1.0 + FeatureCatalog.CREST_DEBT
	features.add("debt", amount * mult)

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

## Broken: the lane opens at once; broken from close by, three soldiers get out.
func _wreck_car(car: Enemy) -> void:
	if is_instance_valid(_car_block): _car_block.queue_free()
	_car_block = null
	if player.global_position.distance_to(car.global_position) > EnemyAttacks.CAR_DROP_REACH: return
	for i in range(EnemyAttacks.CAR_SOLDIERS):
		var offset := Vector3(cos(i * TAU / 3.0), 0.0, sin(i * TAU / 3.0)) * 1.6
		_spawn_enemy(car.global_position + offset, false, false, "family_soldier")
	broadcast("PRTS：车里还有人！")

# --- 干员寻访 (干员寻访策划案 §2) --------------------------------------------------

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
	var count := rng.randi_range(TRAPS.x, TRAPS.y)
	var near_vault := ceili(count * VAULT_TRAP_SHARE) if world_map.has_vault else 0
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < count and tries < count * 30:
		tries += 1
		var at: Vector3
		if placed.size() < near_vault:
			var mouth: Vector2 = world_map.vault_mouth
			var inward: Vector2 = world_map.vault_inward
			var spot := mouth - inward * rng.randf_range(1.5, VAULT_TRAP_REACH) + Vector2(-inward.y, inward.x) * rng.randf_range(-5.0, 5.0)
			at = world_map.nearest_walkable(Vector3(spot.x, 0, spot.y))
			if Vector2(at.x, at.z).distance_to(mouth) > VAULT_TRAP_REACH: continue
		else:
			var path: PackedVector2Array = world_map.main_path
			var room: Vector2 = path[rng.randi_range(1, path.size() - 1)]
			at = world_map.nearest_walkable(Vector3(room.x + rng.randf_range(-7, 7), 0, room.y + rng.randf_range(-7, 7)))
		if not _trap_spot_ok(at, placed): continue
		placed.append(at)
		var trap := FieldTrap.new()
		trap.name = "Trap"
		trap.setup(self, "heavy" if rng.randf() < 0.4 else "light", region_id)
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

# --- 踪迹点 (干员寻访策划案 §13) --------------------------------------------------

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
	if not force_trace and rng.randf() >= RecruitCatalog.trace_chance(floor_number, suited) * research.trace_factor(): return
	var ends: Array[Vector2] = []
	ends.append_array(world_map.niche_centres)
	for centre in world_map.branch_centres: ends.append(Vector2(centre.x, centre.y))
	ends.append_array(world_map.loop_centres)
	ends.shuffle()
	for end in ends:
		var at := world_map.nearest_walkable(Vector3(end.x + rng.randf_range(-2, 2), 0, end.y + rng.randf_range(-2, 2)))
		if not _trap_spot_ok(at, []): continue
		var keys: Array[String] = RecruitCatalog.TRACE_BIG if rng.randf() < RecruitCatalog.BIG_SHARE else RecruitCatalog.TRACE_SMALL
		trace_point = TracePoint.new()
		trace_point.setup(sought[rng.randi() % sought.size()], self, keys[rng.randi() % keys.size()])
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
		id = sought[rng.randi() % sought.size()]
	var first := base.add_clue(id)
	var have := base.clues(id)
	if first: broadcast("PRTS：博士，%s附近有人留下了踪迹。" % RecruitCatalog.RECRUITS[id].place)
	elif have >= RecruitCatalog.CLUES_NEEDED: broadcast("PRTS：博士，%s的行踪已经确认。调度台可以接寻访合同了。" % Operators.display_name(id))
	set_message("踪迹 · %s %d/%d" % [Operators.display_name(id), have, RecruitCatalog.CLUES_NEEDED])

func is_recruit_floor() -> bool:
	return str(contract.get("type", "")) == "recruit" and not recruit_met and floor_number == start_floor + int(contract.offset)

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

func is_handover_floor() -> bool:
	return str(contract.get("type", "")) == "deliver" and not cargo_delivered and floor_number == int(contract.floor)

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

## One rare piece of this region's gear, the hunt's bounty.
func _rare_gear() -> Item:
	var category: int = GearSlots.roll(rng)
	var id := GearCatalog.pick(category, region_id, floor_number, "vault", "", rng)
	return LootTables.roll_equipment(category, GearCatalog.BASES[id].name, region_id, floor_number, 2, rng)

func _clear_outpost(at: Vector3) -> void:
	outpost_cleared = true
	var chest := LootContainer.new()
	chest.game = self
	chest.kind = "vault_gear"
	chest.vault = true
	add_child(chest)
	chest.global_position = world_map.nearest_walkable(at + Vector3(1.5, 0, 0))
	var region_boss := BossCatalog.is_boss_floor(floor_number)
	# A boss gives a second chest (Boss与守卫者策划案 §10); its own kill already left a boss-grade cache.
	if region_boss:
		for i in range(BossCatalog.BOSS_CHESTS - 1):
			var more := LootContainer.new()
			more.game = self
			more.kind = "vault_gear"
			more.vault = true
			add_child(more)
			more.global_position = world_map.nearest_walkable(at + Vector3(1.5, 0, 1.6 * (i + 1)))
		_first_boss_fall()
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
	# ×1.04 a floor for life, attack and defence alike (复利数值改造清单 A).
	var growth := Scaling.floor_growth(floor_number)
	enemy.max_health *= growth * (1.0 + (EnemyAttacks.SNOW_HP_BONUS if region_id == "snow" else 0.0))
	enemy.max_health *= enemy_life_multiplier(player.f("enemy_hp"))
	enemy.health = enemy.max_health
	enemy.atk *= growth
	enemy.defense *= growth
	enemy.died.connect(_on_enemy_died)
	return enemy

## An ordinary slot's enemy from the region pool (EnemyAttacks.REGION_POOLS).
var _herd_count := 0
func _pick_enemy_type(elite: bool, ranged: bool) -> String:
	var pools: Dictionary = EnemyAttacks.REGION_POOLS.get(region_id, {})
	var pool: Array = pools.get("elite" if elite else ("ranged" if ranged else "normal"), [])
	if pool.is_empty(): return ""
	return str(pool[rng.randi_range(0, pool.size() - 1)])

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
	# Two separated stations the guards can walk to from the point: first with
	# room to stand, then (a crowded point) anywhere open. Reachability is read
	# off the navmesh, so no ring can put a guard over a cliff in a pocket.
	for strict in [true, false]:
		for index in range(count - stations.size()):
			for probe in range(160):
				var angle := TAU * float(index + stations.size()) / float(count) + TAU * float(probe % 32) / 32
				var ring: float = [2.7, 3.6, 2.0, 4.6, 5.6][probe / 32]
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
		var ranged := not elite and i == 1 and region_id != "mine"
		post.add_guard(_spawn_enemy(stations[i], elite, ranged, first_type if i == 0 else ""))
	return post

## Whether this kill drops a combat cache (RelicCatalog.CACHE_CHANCE).
func rolls_relic_cache(enemy: Enemy) -> bool:
	return rng.randf() < float(RelicCatalog.CACHE_CHANCE[RelicCatalog.cache_kind(enemy)])

func _on_enemy_died(_enemy: Enemy) -> void:
	if not in_base: award_kill(_enemy)
	if not in_base and region_id == "siracusa": _siracusa_death(_enemy)
	player.on_kill(_enemy)
	if _enemy == _bounty:
		bounty_killed = true
		_bounty = null
	if _enemy in _outpost_squad:
		_outpost_squad.erase(_enemy)
		if _outpost_squad.is_empty() and not outpost_cleared: _clear_outpost(_enemy.global_position)
	# A vault guardian still counts for its vault, whether or not it dropped a cache.
	# Patrols do not count toward combat caches (用户 2026-10-14).
	if not in_base and _enemy.patrol_wave == 0 and not _enemy.called_in and rolls_relic_cache(_enemy):
		_spawn_relic_cache(_enemy.global_position, "cache", false)
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
	var reward := float(FieldCatalog.ROUTES[route_index].reward)
	return {"region": region_id, "depth": floor_number, "reward": reward, "rng": rng, "pity": base.loot_pity, "set_seen": run_sets_seen,
		"drop_pct": player.drop_rate_bonus if is_instance_valid(player) else 0.0}

func _roll_named_item() -> Item: return FieldCatalog.exclusive(region_id)

func spawn_enemy_drops(enemy: Enemy) -> void:
	_drop_heal_orbs(enemy)
	# What a boss calls in mid-fight carries nothing (用户 2026-10-20).
	if enemy.called_in: return
	# A patrol carries nothing ordinary: now and then one rare piece (ThreatMeter).
	if enemy.patrol_wave > 0:
		if rng.randf() < ThreatMeter.rare_chance(enemy.patrol_wave, enemy.elite):
			_drop_at(enemy.global_position, [{"item": _rare_gear()}], 0.7)
		return
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
	_drop_at(enemy.global_position, drops, 0.7)

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
	elif rng.randf() < RECORD_NORMAL_ODDS: record = "基础作战记录"
	if record.is_empty(): return
	var count := 1 + (1 if rng.randf() < research.record_bonus() else 0)
	_drop_at(enemy.global_position, [{"item": MaterialCatalog.create(record, count, region_id)}], 0.8)

## Healing orbs out of a fallen enemy (LootTables.HEAL_ORBS); none from the
## grazing herds.
func _drop_heal_orbs(enemy: Enemy) -> void:
	if in_base or enemy.attack_profile.get("neutral", false): return
	var roll: Dictionary = LootTables.HEAL_ORBS[LootTables.source_of(enemy.elite, enemy.behavior == Enemy.Behavior.GUARD)]
	if rng.randf() >= float(roll.chance): return
	for i in range(int(roll.count)):
		var orb := HealOrb.new()
		orb.game = self
		orb.fraction = float(roll.heal)
		orb.from = enemy.global_position + Vector3.UP * 0.6
		var angle := rng.randf() * TAU
		var at := enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.6, 1.2)
		at = world_map.nearest_walkable(at) if is_instance_valid(world_map) else at
		at.y = ground_y(at)
		add_child(orb)
		orb.global_position = at

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
	var bars := Economy.bars_from_reward(float(drop.gold) * player.gold_gain_multiplier * research.gold_factor(), rng)
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
	var start := rng.randf() * TAU
	for i in range(drops.size()):
		var drop: Dictionary = drops[i]
		var loot := Loot.new()
		loot.game = self
		if drop.has("item"):
			loot.item = drop.item
			if not in_base and (drop.item as Item).item_name == FIRST_RUN_ORE: first_run_ore += (drop.item as Item).quantity
		else:
			# The loot tables still speak in old reward units; they land as 赤金.
			var bars := Economy.bars_from_reward(float(drop.gold) * player.gold_gain_multiplier * research.gold_factor(), rng)
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

func save_base(active_contract: bool = false) -> void:
	if not save_enabled: return
	var loadout: Array = []
	for item in carried_items():
		var entry := item.to_data()
		entry["place"] = "safe" if safe_bag.items.has(item) else ("equipped" if player.equipped.values().has(item) else "pack")
		loadout.append(entry)
	var left_behind: Array = []
	for item in _insured_left_behind:
		if not carried_items().has(item): left_behind.append(item.to_data())
	var data := {"version": 3, "gold": gold, "base": base.to_data(), "loadout": loadout, "left_behind": left_behind,
		"active_contract": active_contract, "settlement": settlement, "rng_state": str(rng.state), "pickup_filter": pickup_filter,
		"exchange": exchange.to_data(), "workshop": workshop.to_data(), "voyage": voyage.to_data(), "consign": consign.to_data()}
	market.save_file(market_path())
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		notice("存档写入失败：当前会话仍可继续。")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(save_path): DirAccess.copy_absolute(save_path, save_path + ".bak")
	if DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		notice("存档替换失败，旧存档保留。")

## A weapon the deployed operator cannot wield (§2.4) goes back to the
## warehouse (staging when the shelves are full); true if one was moved.
func shed_unusable_weapon() -> bool:
	var weapon: Item = player.equipped.get(Item.Category.WEAPON)
	if weapon == null or GearCatalog.can_wield(player.operator_id, weapon): return false
	if base.store(weapon).is_empty() and not base.receive(weapon): return false
	player.unequip(Item.Category.WEAPON)
	notice("%s无法使用%s，已放回仓库。" % [Operators.display_name(player.operator_id), weapon.item_name])
	return true

## Rhodes standard gear (装备策划案 §10, 用户 2026-10-18): every operator on
## the roster is issued one set, once, to the receiving bays. Returns the
## pieces sent.
## Rhodes standard gear (复利数值改造清单 D): each operator gets a set two tiers
## below the deepest camp's, at BaseState.rhodes_rarity; a fresh set whenever
## that tier or the rarity rises past the last one she was given.
func issue_kits() -> int:
	var deepest := 0
	for region in base.camps: deepest = maxi(deepest, int(base.camps[region]))
	var tier := GearCatalog.rhodes_tier(deepest)
	var rarity := clampi(int(base.rhodes_rarity), 0, 2)
	var sent := 0
	for id in base.roster:
		var last: Array = base.kit_issued.get(id, [])
		if last.size() >= 2 and int(last[0]) >= tier and int(last[1]) >= rarity: continue
		if last.is_empty() and id in base.kitted and tier == 1 and rarity == 0: continue
		base.kit_issued[id] = [tier, rarity]
		if not id in base.kitted: base.kitted.append(id)
		for piece in GearCatalog.rhodes_kit(rng, id, tier, rarity):
			if base.receive(piece): sent += 1
	return sent

func load_base() -> void:
	if not FileAccess.file_exists(save_path): return
	# An empty save (and backup) is no save: start fresh and keep saving.
	if FileAccess.get_file_as_string(save_path).strip_edges().is_empty() and (not FileAccess.file_exists(save_path + ".bak") or FileAccess.get_file_as_string(save_path + ".bak").strip_edges().is_empty()): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or not int(parsed.get("version", 0)) in [1, 2, 3]:
		if FileAccess.file_exists(save_path + ".bak"):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".bak"))
		if not parsed is Dictionary or not int(parsed.get("version", 0)) in [1, 2, 3]:
			notice("无法读取存档；原文件保留，请检查备份。")
			save_enabled = false
			return
	# Before version 3 the balance was 资金; it is 龙门币 now, ×100 (经济修订案 §3).
	gold = int(parsed.get("gold", 60)) * (1 if int(parsed.get("version", 1)) >= 3 else Economy.LMD_PER_VALUE)
	pickup_filter = clampi(int(parsed.get("pickup_filter", 0)), 0, PICKUP_FILTER_NAMES.size() - 1)
	var seen := {}
	# Version 1 kept one flat warehouse list; it goes onto the shelves, overflow to staging.
	if int(parsed.get("version", 1)) == 1: base.migrate_v1(parsed.get("stash", []), seen)
	else: base.load_data(parsed.get("base", {}), seen)
	exchange.load_data(parsed.get("exchange", {}))
	workshop.load_data(parsed.get("workshop", {}))
	voyage.load_data(parsed.get("voyage", {}))
	consign.load_data(parsed.get("consign", {}))
	research.apply_globals()
	player.set_operator(base.operator)
	refresh_look()
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
	shed_unusable_weapon()
	settlement.assign(parsed.get("settlement", []))
	_insured_left_behind.clear()
	for data in parsed.get("left_behind", []):
		var dropped := Item.from_data(data)
		if not seen.has(dropped.uid) and dropped.insured: _insured_left_behind.append(dropped)
	if bool(parsed.get("active_contract", false)):
		rng.state = int(parsed.get("rng_state", "1"))
		_settled = false
		settle(false)
		set_message("检测到中断合同：按撤退规则回收出发物品，保险结果不会反复重掷。")

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
	sun.light_energy = FIELD_SUN
	sun.shadow_enabled = true
	add_child(sun)

	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_field_environment = environment
	_base_environment = base_environment()
	world_environment.environment = environment
	add_child(world_environment)
	outline_pass = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	outline_pass.mesh = quad
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	outline_pass.material_override = outline_material
	outline_pass.extra_cull_margin = 16384.0
	outline_pass.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	outline_pass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline_pass.visible = false
	camera.add_child(outline_pass)

# --- The scene's look (场景渲染统一改造案_v1 §4.4) ----------------------------------
## The base is lit by its lamps (BaseMap lights), graded as one scene and
## outlined like the sprites; the field keeps its light texture until S3.
const OUTLINE_SHADER := preload("res://world/outline_post.gdshader")
const FIELD_SUN := 1.2
const BASE_SUN := 0.15
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var outline_pass: MeshInstance3D
var _field_environment: Environment
var _base_environment: Environment

## 罗德岛舰内: cool, even, the lamps and screens carrying the light.
static func base_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.025, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.72)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.tonemap_white = 8.0
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 2.2
	e.ssao_power = 1.4
	e.ssil_enabled = true
	e.ssil_intensity = 0.8
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = Color(0.32, 0.38, 0.46)
	e.fog_density = 0.004
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	return e

## Each region's field light (场景渲染统一改造案_v1 S3), keyed like FieldLight.key:
## ambient energy (its colour is FieldLight.REGIONS' ambient), the sun's colour
## and energy, the fog's colour and density, the background. Then its filter
## (改造案 v1.1: 滤镜), each optional: contrast, saturation, brightness, and
## `grade` [shadows, highlights] — the colour black and white are taken to,
## per channel (adjustment_color_correction).
const FIELD_LOOK := {
	"mine": {"ambient": 0.42, "sun": Color(0.74, 0.8, 1.0), "sun_energy": 0.22, "fog": Color(0.2, 0.22, 0.3), "fog_density": 0.006, "bg": Color(0.03, 0.03, 0.04)},
	"city": {"ambient": 0.34, "sun": Color(0.6, 0.68, 0.9), "sun_energy": 0.12, "fog": Color(0.12, 0.14, 0.2), "fog_density": 0.005, "bg": Color(0.02, 0.02, 0.035)},
	# 下城: wet and cold, a shade darker; blue shadows, warm-yellow highlights
	# so the windows and lanterns stand out.
	"city_lower": {"ambient": 0.38, "sun": Color(0.56, 0.64, 0.86), "sun_energy": 0.1, "fog": Color(0.13, 0.16, 0.22), "fog_density": 0.009, "bg": Color(0.015, 0.02, 0.03),
		"contrast": 1.1, "saturation": 0.9, "brightness": 1.0, "grade": [Color(0.0, 0.015, 0.05), Color(1.0, 0.95, 0.82)]},
	"snow": {"ambient": 0.5, "sun": Color(0.85, 0.9, 1.0), "sun_energy": 0.45, "fog": Color(0.66, 0.72, 0.82), "fog_density": 0.008, "bg": Color(0.5, 0.55, 0.62)},
	# 叙拉古 at dusk going to night (§2): the sun low and orange; violet-blue
	# shadows, amber highlights; colder again in the rain.
	"siracusa": {"ambient": 0.54, "sun": Color(1.0, 0.74, 0.56), "sun_energy": 0.12, "fog": Color(0.17, 0.17, 0.24), "fog_density": 0.007, "bg": Color(0.02, 0.02, 0.04),
		"contrast": 1.08, "saturation": 0.86, "grade": [Color(0.0, 0.005, 0.04), Color(1.0, 0.93, 0.8)]},
	"siracusa_rain": {"ambient": 0.42, "sun": Color(0.7, 0.68, 0.84), "sun_energy": 0.18, "fog": Color(0.2, 0.22, 0.3), "fog_density": 0.012, "bg": Color(0.03, 0.035, 0.05),
		"contrast": 1.08, "saturation": 0.9, "grade": [Color(0.0, 0.01, 0.05), Color(0.97, 0.95, 0.88)]},
}
var _field_environments := {}
var _player_light: OmniLight3D

static func field_environment(look_key: String) -> Environment:
	var look: Dictionary = FIELD_LOOK.get(look_key, FIELD_LOOK.city)
	var e := base_environment()
	e.background_color = look.bg
	e.ambient_light_color = FieldLight.region(look_key).ambient
	e.ambient_light_energy = look.ambient
	e.ssao_radius = 2.0
	e.ssao_intensity = 1.8
	e.ssil_intensity = 0.6
	e.fog_light_color = look.fog
	e.fog_density = look.fog_density
	e.adjustment_contrast = float(look.get("contrast", e.adjustment_contrast))
	e.adjustment_saturation = float(look.get("saturation", e.adjustment_saturation))
	e.adjustment_brightness = float(look.get("brightness", e.adjustment_brightness))
	if look.has("grade"): e.adjustment_color_correction = grade_texture(look.grade[0], look.grade[1])
	return e

## A per-channel curve from `shadows` at black to `highlights` at white,
## straight through grey between.
static func grade_texture(shadows: Color, highlights: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, shadows)
	gradient.set_color(1, highlights)
	var mid := Color(0.5, 0.5, 0.5) + (shadows + highlights - Color.WHITE) * 0.5
	mid.a = 1.0
	gradient.add_point(0.5, mid)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

## Swaps the environment, the sun, the outline and her own light for the base
## or the field (the region read off the floor just built).
func apply_scene_look(base_look: bool) -> void:
	if not is_instance_valid(world_environment): return
	sun.light_energy = BASE_SUN
	sun.light_color = Color.WHITE
	outline_pass.visible = true
	if base_look:
		world_environment.environment = _base_environment
	else:
		var look_key := FieldLight.key(world_map) if is_instance_valid(world_map) else region_id
		if not _field_environments.has(look_key): _field_environments[look_key] = field_environment(look_key)
		world_environment.environment = _field_environments[look_key]
		var look: Dictionary = FIELD_LOOK.get(look_key, FIELD_LOOK.city)
		sun.light_energy = look.sun_energy
		sun.light_color = look.sun
	_update_player_light(base_look)

## In the field her self-lit sprite takes the nearby lamps' colour and stands
## on its contact shadow, as in the base (BaseMap._tint_sprites).
const FIELD_TINT := Color(0.96, 0.97, 1.0)
func _tint_in_field() -> void:
	if in_base or player._sprite == null: return
	var dressing: TerraceDressing = world_map.terrace_dressing if is_instance_valid(world_map) else null
	var rig: FieldLight.LightRig = dressing.field_light.rig if dressing != null and dressing.field_light != null else null
	player._sprite.scene_tint = rig.tint_at(player.global_position, FIELD_TINT, 0.28) if is_instance_valid(rig) else FIELD_TINT
	if is_instance_valid(player._sprite.contact_shadow): player._sprite.contact_shadow.visible = true

## The warm glow round her in the field (FieldLight.REGIONS' "player"), now a
## light that walks with her; none in the base.
func _update_player_light(base_look: bool) -> void:
	if not is_instance_valid(player): return
	if not is_instance_valid(_player_light):
		_player_light = OmniLight3D.new()
		_player_light.name = "OwnLight"
		_player_light.omni_attenuation = 1.4
		_player_light.light_specular = 0.2
		player.add_child(_player_light)
		_player_light.position = Vector3(0, 1.6, 0)
	var region := FieldLight.region(FieldLight.key(world_map) if is_instance_valid(world_map) else region_id)
	var glow: Color = region.player
	var peak := maxf(glow.r, maxf(glow.g, glow.b))
	_player_light.visible = not base_look and peak > 0.0
	if peak > 0.0:
		_player_light.light_color = Color(glow.r / peak, glow.g / peak, glow.b / peak)
		_player_light.light_energy = peak * 2.4
		_player_light.omni_range = float(region.player_radius) * 1.2

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
	if _pointer_gate:
		_pointer_gate = left
		_held_on_enemy = false
		return

	var left_click := left and not _left_was_down
	var released := _left_was_down and not left
	_left_was_down = left
	if not left: _plate_held = null
	# Letting go of a long press on an enemy ends the attack there.
	if released and _held_on_enemy:
		_held_on_enemy = false
		if _left_held_time >= HOLD_ATTACK_TIME:
			player.clear_target()
			player.clear_move_target()
	# The hotbar (用户 2026-10-10: 在快捷栏上直接点格子换内容): a click on a slot
	# opens its picker, a click in the picker sets it, any other click closes it.
	# Clicks there never reach the field.
	if is_instance_valid(_hud):
		var at := pointer_ui()
		var over := _hud.hotbar_slot_at(at) # -2 off the bar, -1 the bar but no slot
		if left_click and _hud.picker_slot >= 0:
			var choice: Variant = _hud.picker_choice_at(at)
			var open := _hud.picker_slot
			_hud.picker_slot = -1
			if choice != null: Hotbar.set_action(open, str(choice))
			elif over >= 0 and over != open: _hud.picker_slot = over
			_pointer_gate = true # the closing click does nothing else
			return
		if over >= -1:
			if left_click and over >= 0: _hud.picker_slot = over
			return
	if not left:
		return

	# Left on a ground item's name plate: she walks over and takes it (恐怖黎明式,
	# 用户 2026-10-10). Plates sit above everything else under the cursor.
	var plate := _hud.loot_label_at(pointer_ui()) if is_instance_valid(_hud) and (left_click or not _held_on_enemy) else null
	if is_instance_valid(plate):
		if plate != _plate_held:
			request_pickup(plate)
			_plate_held = plate
		_plate_from = pointer_ui()
		return
	# A press held from a name plate (用户 2026-10-13: 左键选中拾取物品时不触发
	# 攻击): while the cursor stays put — the plate gone because the item was
	# taken — nothing swings. Moved off it, the press counts again: an enemy
	# under it is attacked, the ground walked to (用户 2026-10-15 / 10-20).
	if _plate_held != null:
		if pointer_ui().distance_to(_plate_from) < PLATE_LEAVE_PX: return
		_plate_held = null
		left_click = true

	if left_click:
		_held_on_enemy = is_instance_valid(pointed_enemy)
		_left_held_time = 0.0
	elif _held_on_enemy:
		_left_held_time += delta
	# Left on an enemy locks it: she closes to her weapon's reach and attacks it
	# (Player._follow_target), one swing per cooldown. One click is enough;
	# holding keeps it, and moves it to whichever enemy is under the cursor.
	if is_instance_valid(pointed_enemy):
		pickup_target = null
		player.lock_target(pointed_enemy)
		return
	pickup_target = null
	# A press that began on an enemy never turns into air swings or a walk:
	# off the enemy she keeps at the lock (none once it died) until release.
	if _held_on_enemy: return

	# Left on the ground drops the lock and walks there, whatever she holds
	# (用户 2026-10-20: 左键点地面改为会移动; no more air swings). On a sealed
	# vault's 暗墙 with a blade it locks the wall instead (Player.lock_wall).
	var ground := _get_pointer_ground()
	var seal: VaultSeal = world_map.vault_seal if not in_base and is_instance_valid(world_map) else null
	if left_click and seal != null and seal.aimed_at(ground) and not player.is_ranged_weapon() and not (player.kit != null and player.kit.ranged()):
		player.lock_wall()
		return
	if player.wall_target and not left_click: return
	player.clear_target()
	player.set_move_target(ground)

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
	if attack_cursor_on:
		attack_cursor_on = false
		AttackCursor.apply(false)

## The pointer in HUD (UI viewport) coordinates, where the name plates are drawn.
func pointer_ui() -> Vector2:
	var viewport := get_viewport()
	var at := _pointer_position if _has_pointer_position else viewport.get_mouse_position()
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
	# Onto the terraced ground: meet the plane at the last height found, read
	# the ground there, repeat. A steep camera settles in a few steps.
	# A bridge's deck is picked first, unless she is on the road under it:
	# then a click there means that road, not the deck overhead.
	if not in_base and is_instance_valid(world_map):
		var deck: Vector3 = world_map.deck_hit(from, dir)
		if deck != Vector3.INF:
			var bridge: Dictionary = world_map.bridge_at(Vector2(deck.x, deck.z))
			var under: bool = player.global_position.y < float(bridge.top) - world_map.BRIDGE_REACH and not world_map.bridge_at(Vector2(player.global_position.x, player.global_position.z), 6.0).is_empty()
			if not under: return deck
	var ground := player.global_position.y - 0.7 if not in_base else 0.0
	var hit := from
	for i in range(5):
		var t := (ground - from.y) / dir.y
		if t < 0.0:
			return player.global_position
		hit = from + dir * t
		var next := ground_y(hit)
		if absf(next - ground) < 0.02: break
		ground = next
	hit.y = ground_y(hit)
	return hit

## Ground height under x/z: the field's terraces, or the base's flat floor.
## `at.y` tells a bridge's deck from the road under it.
func ground_y(at: Vector3) -> float:
	if in_base or not is_instance_valid(world_map): return 0.0
	return world_map.ground_height(Vector2(at.x, at.z), at.y)

func _create_relic(item_name: String, modifiers: Array[ItemModifier]) -> Item:
	var item := Item.create(item_name, Item.Category.AMULET, 1, 1, 0.0)
	item.modifiers = modifiers
	return item

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
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
