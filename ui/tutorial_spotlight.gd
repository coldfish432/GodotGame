class_name TutorialSpotlight
extends Control

## First sight (用户 2026-10-22: 密室、踪迹、火堆、陷阱等玩家第一次屏幕中遇到后
## 暂停游戏蒙板高亮圈出目标并显示 prts 卡片; 局内操作、机制和基地设施都补教程).
## The first time one of these is on screen and near her — or, in the base,
## the first time she walks up to a station — the game stops (modal
## "tutorial"), the screen dims but for a ring (or a box, for a bar or a slot)
## round it, and a PRTS card beside it says what it is; 知道了 (or Esc) and on.
## Some come from events instead (low life, the first camp, a retreat, gear
## sent back): `request`, shown over whatever screen is up, with no ring when
## there is nothing to point at. Each kind once, ever
## (SystemScreens.settings.tutorial_seen); off with the 新手引导 setting. The
## base ones wait until the first contract has started (TutorialCard's
## contract step), so the first walk to the dispatch desk is not stopped at
## every station. Same look as TutorialCard. Only the real game shows it, or a
## test that sets `forced`.

## id -> [title, what PRTS says, ring radius in px]
const TIPS := {
	# --- 局内：地图上的东西 ---
	"vault": ["密室", "博士，这段墙脚有裂痕与幽光，墙后可能是一间密室。对墙体发动近战攻击即可破开；室内有稀有物资，也可能有守卫者。", 64.0],
	"sealed": ["密室守卫者", "密室里的宝箱和藏品已被封印。击败全部守卫者后才能打开，守卫者中有一名精英。", 64.0],
	"trace": ["踪迹", "检测到干员留下的踪迹。靠近后按交互键调查；同一名干员的踪迹集齐 6 条后，调度台会出现寻访合同。", 48.0],
	"recruit": ["寻访目标", "博士，寻访目标就在前方，身边有守卫。击败守卫后按交互键与她会面；成功撤离后，她才会正式加入罗德岛。", 60.0],
	"handover": ["交接点", "运送合同的交接点。背包或安全袋里带着这张订单的大宗货箱时，按交互键交付；报酬在结算时到账。", 56.0],
	"fire": ["火堆", "这里有一处火堆。点燃时站在旁边寒冷会持续下降；熄灭了就按交互键，从背包里选燃料添进去。", 56.0],
	"trap": ["陷阱", "前方地面有陷阱。踩中会受到固定伤害并提高威胁值；重型陷阱触发后有短暂引信，及时闪避可以躲开。", 40.0],
	"shower": ["净化喷淋", "净化喷淋点仍可使用。在旁边按住交互键约 3 秒，可以降低污染，仅限一次。", 52.0],
	"extraction": ["撤离信标", "已发现撤离信标。进入撤离区域并停留数秒即可撤离，携带的物品将一同带回罗德岛。", 72.0],
	"route": ["深入入口", "这是通往下一层的入口。按交互键选择路线：路线越危险，敌人越强，收获也越丰厚。", 56.0],
	"device": ["强化装置", "强化装置可以使用一次。按交互键从几件藏品中选择一件，效果持续到本次行动结束。", 56.0],
	"trader": ["坎诺特", "诡意行商坎诺特。可以用赤金购买藏品、装备与药剂，也可以把物品卖给他；货架可以付费刷新。", 56.0],
	"squad": ["罗德岛小队", "罗德岛小队在此待命。支付赤金可以为一件装备投保，或者直接把它送回基地。小队附近威胁值不会上涨。", 56.0],
	"post": ["势力据点", "这是一处势力据点。只收购该势力需要的货物，按当前价格当面成交。", 56.0],
	"cache": ["战斗缴获", "这里有一份战斗缴获。按交互键打开，从中选择一件藏品。", 48.0],
	"boss": ["区域头目", "博士，前方是头目的场地。头目倒下前出口闸门会保持关闭，请做好准备再进入。", 72.0],
	"mine": ["干扰地雷", "场地里布置有干扰地雷。站在旁边按交互键布雷，敌人踏入时会被炸伤，之后一段时间受到的伤害提高。每个只能用一次。", 44.0],
	"leader": ["头目", "检测到头目级敌对单位，威胁较高。请留意地面的攻击预警，必要时闪避。", 64.0],
	"elite": ["精英敌人", "精英敌人比普通敌人更强韧，击败后的物资也更好。", 52.0],
	"sentinel": ["萨卡兹哨兵", "萨卡兹哨兵发现博士后会发出警报，使威胁值加速上涨。建议优先将其击倒。", 52.0],
	"patrol": ["巡逻队", "威胁值涨满后，敌方会派出巡逻队搜捕博士。同一层里，后来的巡逻队会更强。", 60.0],
	"heal_orb": ["治疗球", "敌人掉落了治疗球。靠近即可吸取，立即回复生命。", 36.0],
	# --- 局内：界面与事件 ---
	"low_hp": ["生命告急", "博士，干员生命偏低。快捷栏上的急救剂可以立即回复；最右侧的自动格会在生命低于下限时自动喝药，上下限可在设置里调整。应急强心针放在背包里，会在致命一击时自动生效。", 34.0],
	"threat": ["威胁值", "敌对势力正在锁定博士的位置。屏幕上方的细条就是威胁值：停留越久涨得越快，涨满时会有巡逻队前来搜捕；进入下一层后保留一部分。", 0.0],
	"contamination": ["源石污染", "干员正在污染区中暴露。污染达到 60 时生命上限降低、自然回复减半，90 时开始持续掉血。抑制喷剂、净化喷淋和营地都可以降低污染。", 0.0],
	"cold": ["寒冷", "冰原的寒冷正在累积。达到 60 时移动和体力回复变慢，90 时攻速下降并开始掉血。站在点燃的火堆旁、使用热能饮剂或自热罐头都能驱寒。", 0.0],
	"debt": ["血债", "击杀家族成员会积累血债。达到 60 时家族敌人更凶狠，90 时会派出清算小队。中间人信物、镇静合剂和营地赔偿都可以降低血债。", 0.0],
	"camp": ["前进据点", "前进据点已确认，博士。这里没有敌人：可以在可露希尔处补给、处理污染或血债，也可以从这里撤离。到过的据点以后可以直接作为出发点。", 0.0],
	"death": ["撤退", "干员倒下，罗德岛小队已接回博士。安全袋里的物品全部保留；身上和背包里没有投保的物品遗失；投保的装备会在 2 到 4 小时后由罗德岛小队送回收货区。倒下的干员带着重伤，可在医疗前台治疗。", 0.0],
	"insured_back": ["投保送回", "罗德岛小队找回了投保的装备，已送到仓储区的收货区货箱。保险随之用掉，需要的话请在后勤柜台重新投保。", 0.0],
	# --- 基地设施（第一次走到旁边） ---
	"base_loadout": ["整备台", "整备台用于换装与改造。换装页可以把仓库里的装备穿上、把物品放进背包或安全袋带走；改造页可以重铸、校准、精调装备的前缀。", 60.0],
	"base_insurance": ["后勤柜台", "出发前可以在这里为装备投保。投保的装备若没能带回，罗德岛小队会在 2 到 4 小时后送回；保费等于装备的交付价。", 60.0],
	"base_stash": ["仓管台", "仓管台管理仓储部。建成仓库总控台后，可以在这里查看全部货架、搜索物品并直接带走。", 60.0],
	"base_crate": ["收货区", "撤离带回的物资会装成货箱送到收货区。按交互键开箱，拿起物品送去对应的上架区，或者先放进暂存区。", 52.0],
	"base_zone": ["上架区", "拿着物品走进同类别的地面框，按交互键即可上架。空手站进框里按交互键，可以查看这一区的货架、扩建货架。", 60.0],
	"base_shelf_zone": ["上架区", "拿着物品走进同类别的地面框，按交互键即可上架。空手站进框里按交互键，可以查看这一区的货架、扩建货架。", 60.0],
	"base_staging": ["暂存区", "暂存区可以临时存放物品。想带进下一份合同，就在这里把物品放进背包；加工站的产出也会送到这里。", 60.0],
	"base_outbound": ["出库区", "各部门把需要的物资写成订单挂在这里。交付货架或背包里的物品完成订单，就能获得龙门币；也可以把物品直接卖给可露希尔。", 60.0],
	"base_report": ["医疗前台", "医疗前台会给出上一份合同的回收报告。倒下的干员带有重伤、生命上限降低，在这里支付龙门币治疗。", 60.0],
	"base_pharmacy": ["药房窗口", "药房出售标准急救剂和缓释凝胶。每份合同出发时还会免费配发 3 瓶急救剂。", 56.0],
	"base_store": ["可露希尔的商店", "可露希尔的商店用赤金出售特供药剂，每小时补货。这里还可以出售赤金、换汇、贷款，以及购买减缓地图特色的随队物资。", 60.0],
	"base_exchange": ["交易所", "交易所终端可以买卖九大势力的商品，查看行情与新闻，下现货、挂单、远期和差价合约。交易所需要先建成才能使用。", 64.0],
	"base_workshop": ["加工站", "加工站用材料和龙门币加工成品，按现实时间计时，完成后送到暂存区。", 60.0],
	"base_personnel": ["人事部", "人事部记录各位干员的寻访进度：从发现踪迹到可以寻访、正式入职。", 56.0],
	"base_sand_table": ["沙盘", "沙盘上可以指挥罗德岛号航行到各地，开启医疗驻留提升当地关系，或者提交、装箱大宗订单。航行按现实时间进行。", 72.0],
	"base_research": ["科研部", "科研终端用龙门币和材料推进研究，按现实时间进行。研究可以带来各种长期加成，部分课题需要先完成前置研究。", 60.0],
	"base_hub": ["基建总控台", "基建总控台需要先建成。之后，每个设施接入总控台，就能在这里远程查看和购买它的升级。", 64.0],
	"base_build_site": ["施工点", "这里是尚未建成的设施。按交互键查看建造需要的龙门币和材料；没有接入总控台的设施也可以在现场升级。", 64.0],
	"base_lift": ["升降梯", "升降梯连接舰桥大厅与二层，二层是农业部和食堂。", 56.0],
	"base_farm": ["农业部", "农业部的水培槽可以种植作物，按现实时间生长，成熟后不会枯萎。作物可以送到食堂烹饪。", 60.0],
	"base_canteen": ["食堂", "食堂用作物烹饪补给。出发前吃一份，下一份合同中干员会获得生命、回复或攻击方面的增益。", 60.0],
}
## Seen counts within this far of her, and inside the screen by INSET px.
const SEE_RANGE := 16.0
const TRAP_RANGE := 7.0
const INSET := 48.0
const SCREEN := Vector2(1280, 720)
const CHECK_SECONDS := 0.2
const CARD_WIDTH := 300.0
const DIM := 0.72

var game: GameManager
var forced := false
## The tip up now ("" none), and where its ring is.
var showing := ""
var ring_at := Vector2.ZERO
var ring_radius := 0.0
## A box instead of a ring, for a bar or a slot (size zero: the ring).
var ring_box := Rect2()
var _check_left := 0.0
## Tips an event asked for (low life, a camp, a death…): [id, at], `at` a
## world point (Vector3), a screen point (Vector2), or null for no ring.
var _queue: Array = []
## Whether the field was stopped for it (modal "tutorial"); a tip over a
## screen that already stops it (the camp, the settlement) leaves that as is.
var _owns_modal := false
var _mask: ColorRect
var _ring: Control
var _card: PanelContainer
var _title: Label
var _text: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask = ColorRect.new()
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec2 centre;
uniform float radius;
uniform vec4 box;
uniform vec2 extent;
uniform float dim;
void fragment() {
	vec2 at = UV * extent;
	float d = distance(at, centre) - radius;
	if (box.z > 0.0) {
		vec2 q = abs(at - (box.xy + box.zw * 0.5)) - box.zw * 0.5;
		d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	}
	COLOR = vec4(0.0, 0.0, 0.0, dim * smoothstep(0.0, 8.0, d));
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_mask.material = material
	add_child(_mask)
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var plate := AK.box(AK.PLATE, AK.BLUE, 0, 12)
	plate.border_width_left = 3
	_card.add_theme_stylebox_override("panel", plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var badge := AK.label("PRTS", 11, AK.INK, AK.en())
	var badge_plate := AK.box(AK.BLUE, Color.TRANSPARENT, 0, 0)
	badge_plate.content_margin_left = 6
	badge_plate.content_margin_right = 6
	badge.add_theme_stylebox_override("normal", badge_plate)
	head.add_child(badge)
	_title = AK.label("", 15, AK.FG)
	head.add_child(_title)
	column.add_child(AK.rect(AK.LINE, Vector2.ZERO, Vector2(CARD_WIDTH - 24, 1)))
	_text = AK.label("", 13, AK.FG)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(CARD_WIDTH - 24, 0)
	# It wraps instead: English keeps the full size (AK.fit would shrink it).
	_text.remove_meta("fit_size")
	column.add_child(_text)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(foot)
	var ok := AK.button("知道了", "blue", 12)
	ok.custom_minimum_size = Vector2(88, 30)
	ok.pressed.connect(dismiss)
	foot.add_child(ok)
	add_child(_card)
	visible = false

static func tips_on() -> bool:
	return bool(SystemScreens.settings.get("tutorial_tips", true))

static func seen(id: String) -> bool:
	return str(id) in SystemScreens.settings.get("tutorial_seen", [])

func dismiss() -> void:
	if showing.is_empty(): return
	showing = ""
	visible = false
	if _owns_modal and game.modal == "tutorial": game.close_modal()
	_owns_modal = false

## Esc on a tip: it closes (GameManager.go_back asks here first).
func go_back() -> bool:
	if showing.is_empty(): return false
	dismiss()
	return true

## An event's tip, shown as soon as it can be (once, like the rest).
func request(id: String, at: Variant = null) -> void:
	if not TIPS.has(id) or seen(id) or not tips_on() or not _active(): return
	if _queue.any(func(q): return q[0] == id): return
	_queue.append([id, at])

func _active() -> bool:
	return is_instance_valid(game) and (forced or is_instance_valid(game.system_screens))

func _process(delta: float) -> void:
	if not _active():
		visible = false
		return
	if not showing.is_empty():
		# Something closed the modal under it (a test, a transition): gone too.
		if _owns_modal and game.modal != "tutorial":
			showing = ""
			visible = false
			_owns_modal = false
		return
	visible = false
	_check_left -= delta
	if _check_left > 0.0: return
	_check_left = CHECK_SECONDS
	if not tips_on() or game.transitioning: return
	for i in range(_queue.size()):
		var q: Array = _queue[i]
		# A tip with no ring goes over any screen; one with a ring waits for the field.
		if q[1] == null or (game.simulation_active() and game.modal.is_empty()):
			_queue.remove_at(i)
			if not seen(q[0]): show_tip(q[0], q[1])
			return
	_watch_events()
	if game.simulation_active() and game.modal.is_empty():
		var found := first_in_sight()
		if not found.is_empty(): show_tip(found.id, found.at)
	elif game.base_walk_active() and TutorialCard.step() > TutorialCard.index_of("contract"):
		var station := base_station()
		if not station.is_empty(): show_tip(station.id, station.at)

## What is watched rather than seen: life, the 威胁值 and the region's meter in
## the field, the first camp. Each queues its tip once.
const LOW_LIFE := 0.5
const THREAT_AT := 0.4
const FEATURE_AT := 20.0
func _watch_events() -> void:
	if game.in_base or not is_instance_valid(game.player): return
	if game.in_camp:
		request("camp")
		return
	if not game.simulation_active(): return
	var p := game.player
	if p.hp < p.max_hp * LOW_LIFE: request("low_hp", potion_slot_rect())
	if game.threat.ratio() >= THREAT_AT: request("threat", TOP_BAR)
	for kind in ["contamination", "cold", "debt"]:
		if kind in game.shown_features() and game.feature_value(kind) >= FEATURE_AT: request(kind, TOP_BAR)

## The HUD's top strip, with the 威胁值 bar under it (Hud._draw_top_bar).
const TOP_BAR := Rect2(0, 0, 640, 47)

## The bar slot holding the first-aid flask, else the auto slot.
func potion_slot_rect() -> Rect2:
	var hud: Hud = game._hud
	if not is_instance_valid(hud): return Rect2(323, 648, 634, 58)
	var bar := Hotbar.slots()
	for i in range(bar.size()):
		if str(bar[i].action).begins_with("potion_"): return hud._config_rect(i)
	return hud._config_rect(Hotbar.AUTO)

## The station she stands at, if its tip is still to come ({id, at}).
func base_station() -> Dictionary:
	var station := game.nearby_station()
	if station.is_empty(): return {}
	var id := "base_" + str(station.kind)
	if not TIPS.has(id) or seen(id): return {}
	var at: Vector3 = station.get("position", game.player.global_position)
	return {"id": id, "at": at + Vector3.UP * 0.6}

## The first tip not yet seen whose thing is on screen and near her.
func first_in_sight() -> Dictionary:
	var player_at := game.player.global_position
	for entry in candidates():
		var id: String = entry[0]
		if seen(id): continue
		var at: Vector3 = entry[1]
		var reach := TRAP_RANGE if id == "trap" else SEE_RANGE
		var flat := at - player_at
		flat.y = 0.0
		if flat.length() > reach: continue
		var point := game.screen_point(at)
		if Rect2(Vector2(INSET, INSET), SCREEN - Vector2(INSET, INSET) * 2.0).has_point(point):
			return {"id": id, "at": at}
	return {}

## [id, world position] of every kind there is on this floor now.
func candidates() -> Array:
	var out: Array = []
	var map := game.world_map
	if not is_instance_valid(map): return out
	if is_instance_valid(map.vault_seal) and not game.vault_opened: out.append(["vault", map.vault_seal.wall_centre()])
	for node in get_tree().get_nodes_in_group("sealed_loot"):
		var chest := node as LootContainer
		if chest != null and chest.game == game and chest.sealed: out.append(["sealed", chest.global_position])
	if is_instance_valid(game.recruit_node) and game.recruit_node.visible and not game.recruit_met: out.append(["recruit", game.recruit_node.global_position])
	if is_instance_valid(game.handover_node) and game.handover_node.visible and not game.cargo_delivered: out.append(["handover", game.handover_node.global_position])
	if is_instance_valid(game.arena):
		for node in get_tree().get_nodes_in_group("bosses"):
			var boss := node as Enemy
			if boss != null and boss.game == game and not boss._dead: out.append(["boss", boss.global_position + Vector3.UP * 1.0])
		for mine in game.arena.mines:
			if not mine.spent and not mine.armed and is_instance_valid(mine.node): out.append(["mine", (mine.node as Node3D).global_position])
	if is_instance_valid(game.trace_point) and game.trace_point.visible: out.append(["trace", game.trace_point.global_position])
	for node in get_tree().get_nodes_in_group("fire_pits"): out.append(["fire", (node as Node3D).global_position])
	for trap in game.traps:
		if is_instance_valid(trap) and not trap.spent: out.append(["trap", trap.global_position])
	if is_instance_valid(game.shower) and not game.shower.used: out.append(["shower", game.shower.global_position])
	if game.is_extraction_floor() and is_instance_valid(map.exit_node) and map.exit_node.visible: out.append(["extraction", map.exit_node.global_position])
	for node in map.route_nodes:
		if is_instance_valid(node) and node.visible: out.append(["route", node.global_position])
	if is_instance_valid(map.buff_device_node) and map.buff_device_node.visible and game.is_buff_available(): out.append(["device", map.buff_device_node.global_position])
	if is_instance_valid(map.encounter_node) and map.encounter_node.visible and game.encounter in ["trader", "squad", "post"]:
		out.append([game.encounter, map.encounter_node.global_position])
	for node in get_tree().get_nodes_in_group("relic_caches"):
		if (node as RelicCache).game == game: out.append(["cache", (node as Node3D).global_position])
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy._dead or enemy.game != game: continue
		var mid := enemy.global_position + Vector3.UP * 0.8
		if enemy.boss: out.append(["leader", mid])
		elif enemy.elite: out.append(["elite", mid])
		if enemy.is_in_group("sentinels"): out.append(["sentinel", mid])
		if enemy.is_in_group("patrols"): out.append(["patrol", mid])
	for node in get_tree().get_nodes_in_group("heal_orbs"): out.append(["heal_orb", (node as Node3D).global_position])
	return out

## Stops the game and shows `id`'s card beside a ring round `at`: a world
## point (Vector3), a screen point (Vector2), a screen box (Rect2), or null
## for no ring and the card in the middle.
func show_tip(id: String, at: Variant) -> void:
	var list: Array = SystemScreens.settings.get("tutorial_seen", []).duplicate()
	list.append(id)
	SystemScreens.set_setting("tutorial_seen", list)
	showing = id
	_owns_modal = game.modal.is_empty()
	if _owns_modal: game.open_modal("tutorial")
	ring_box = at.grow(6.0) if at is Rect2 else Rect2()
	ring_at = game.screen_point(at) if at is Vector3 else (at if at is Vector2 else (ring_box.get_center() if at is Rect2 else SCREEN * 0.5))
	ring_radius = float(TIPS[id][2]) if at is Vector3 or at is Vector2 else 0.0
	_title.text = TIPS[id][0]
	_text.text = TIPS[id][1]
	var material := _mask.material as ShaderMaterial
	material.set_shader_parameter("centre", ring_at)
	# No ring: the whole screen dims.
	material.set_shader_parameter("radius", ring_radius if at != null else -20.0)
	material.set_shader_parameter("box", Vector4(ring_box.position.x, ring_box.position.y, ring_box.size.x, ring_box.size.y))
	material.set_shader_parameter("extent", SCREEN)
	material.set_shader_parameter("dim", DIM)
	_card.reset_size()
	if at == null:
		_card.position = (SCREEN - _card.size) * 0.5
	elif at is Rect2:
		# Under a box at the top, over one at the bottom, lined up with it.
		var y := ring_box.end.y + 18.0 if ring_box.get_center().y < SCREEN.y * 0.5 else ring_box.position.y - 18.0 - _card.size.y
		var x := ring_box.get_center().x - _card.size.x * 0.5
		_card.position = Vector2(clampf(x, 16.0, SCREEN.x - _card.size.x - 16.0), clampf(y, 16.0, SCREEN.y - _card.size.y - 16.0))
	else:
		# Beside the ring, on the side with more room, kept on screen.
		var gap := ring_radius + 24.0
		var x := ring_at.x + gap if ring_at.x < SCREEN.x * 0.5 else ring_at.x - gap - _card.size.x
		var y := ring_at.y - _card.size.y * 0.5
		_card.position = Vector2(clampf(x, 16.0, SCREEN.x - _card.size.x - 16.0), clampf(y, 16.0, SCREEN.y - _card.size.y - 16.0))
	visible = true
	_ring.queue_redraw()

func _draw_ring() -> void:
	if showing.is_empty(): return
	if ring_box.size.x > 0.0:
		_ring.draw_rect(ring_box, AK.BLUE, false, 2.0)
		_ring.draw_rect(ring_box.grow(6.0), Color(AK.BLUE, 0.35), false, 1.0)
		return
	if ring_radius <= 0.0: return
	_ring.draw_arc(ring_at, ring_radius, 0.0, TAU, 64, AK.BLUE, 2.0, true)
	_ring.draw_arc(ring_at, ring_radius + 6.0, 0.0, TAU, 64, Color(AK.BLUE, 0.35), 1.0, true)
