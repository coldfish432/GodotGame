class_name FieldMenu
extends Control

var game: GameManager
var body: VBoxContainer
## Absolute 1280×720 layouts (EventScreens, base stations) go here instead of body.
var stage: Control
## What the current stage screen has selected (an index, an Item, a type …).
var pick: Variant = null
var camp_tab := 0
var region_pick := ""
var stash_tab := 0
var outbound_tab := 0
var pause_page := 1
var pause_confirm := false
var settings_tab := 0
## Where Esc / ‹ goes from this page when it is a sub-page (else the menu closes).
var back_to := Callable()
var _shade: ColorRect
var _margin: MarginContainer
const INK := AK.FG
const GOLD := AK.SP

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ColorRect.new()
	_shade.color = Color(0.063, 0.063, 0.063, 0.97)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 44)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	stage = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	hide()

var _screen := ""

## A new stage screen starts with nothing picked; redraws of the same keep it.
func _enter(screen: String, default: Variant) -> void:
	if _screen != screen: pick = default
	_screen = screen

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_screen = ""
		back_to = Callable()

## Starts an absolute-layout screen over a shade of `alpha`.
func stage_begin(alpha: float = 0.97) -> Control:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	_margin.hide()
	stage.show()
	_shade.color.a = alpha
	show()
	return stage

func clear(title: String, subtitle: String) -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	stage.hide()
	_margin.show()
	_shade.color.a = 0.97
	pick = null
	_screen = ""
	show()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	body.add_child(head)
	var plate := ColorRect.new()
	plate.color = AK.PAPER
	plate.custom_minimum_size = Vector2(6, 52)
	head.add_child(plate)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	head.add_child(titles)
	titles.add_child(AK.label("RHODES ISLAND · PRTS", 11, AK.MUTE, AK.en()))
	titles.add_child(AK.label(title, 28, AK.FG))
	if not subtitle.is_empty():
		var sub := AK.label(subtitle, 15, AK.MUTE)
		sub.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(sub)
	var line := ColorRect.new()
	line.color = AK.LINE
	line.custom_minimum_size.y = 1
	body.add_child(line)

func text(parent: Node, value: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", AK.cn())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func button(parent: Node, title: String, callback: Callable, disabled: bool = false) -> Button:
	var control := Button.new()
	control.focus_mode = Control.FOCUS_NONE
	control.text = title
	control.custom_minimum_size.y = 36
	control.disabled = disabled
	control.add_theme_font_override("font", AK.cn())
	control.add_theme_font_size_override("font_size", 14)
	AK.style_button(control, "blue" if title in PRIMARY else "plain")
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

## Buttons that move the game on are blue (AK confirm); everything else grey.
const PRIMARY := ["出发", "继续", "撤离", "返回罗德岛", "接下合同 →", "开始唤醒"]

## Station kinds opened from the walkable base (see BaseMap / GameManager.open_station).
const STATIONS := {
	"contracts": ["调度台 / 外勤合同", "选择地区接下合同 · 每 3 区段固定撤离"],
	"insurance": ["后勤柜台 / 出战准备", "带入装备可投保"],
	"loadout": ["整备台 / 装备", "装备、卸下或存回仓库"],
	"stash": ["仓管台 / 仓库", "从个人仓库带入下一份合同"],
	"outbound": ["出库区 / 订单与交付", "交付个人仓库或背包里的物品：按订单换龙门币和声望，或直接换龙门币"],
	"report": ["医疗前台 / 回收报告与治疗", "上一份合同的回收明细、污染变化，以及重伤治疗"],
	"pharmacy": ["药房窗口 / 配药", "下一份合同带哪些药：标准急救剂免费，其余每瓶收费，结算后恢复为 3 瓶标准急救剂"],
	"decon": ["污染检测门 / 检测与处理", "污染跨合同保留；出发时按当时的数值决定减益"],
	"store": ["可露希尔的商店", "药剂 · 收购赤金"],
}
var _station := ""
## The stash list's search text (装备与背包界面调研 §5.13); kept while the menu redraws.
var stash_query := ""

## Everything on one page; kept for tools and tests that want the overview.
func show_base() -> void:
	_station = ""
	clear("罗德岛 / 外勤合同", "龙门币 %s" % Economy.format(game.gold))
	_contracts_section()
	_loadout_section()
	_stash_section()
	_report_section()

func show_station(kind: String) -> void:
	if _station != kind: pick = null
	back_to = Callable()
	_station = kind
	_screen = "station"
	match kind:
		"contracts": BaseScreens.contracts(self); return
		"stash": BaseScreens.stash(self); return
		"outbound": BaseScreens.outbound(self); return
		"pharmacy": BaseScreens.medical(self, 0); return
		"report": BaseScreens.medical(self, 1); return
		"decon": BaseScreens.medical(self, 2); return
		"insurance", "loadout": BaseScreens.departure(self, "", kind); return
		"store": BaseScreens.store(self); return
	var info: Array = STATIONS.get(kind, ["罗德岛", ""])
	clear(info[0], "%s    ·    龙门币 %s" % [info[1], Economy.format(game.gold)])
	match kind:
		"contracts": _contracts_section()
		"insurance", "loadout": _loadout_section()
		"stash": _stash_section()
		"outbound": _outbound_section()
		"report":
			_medical_summary()
			_report_section(true)
		"pharmacy": _pharmacy_section()
		"decon": _decon_section()
		"store": _store_section()
	button(body, "返回", game.close_modal)

func _refresh() -> void:
	if _station.is_empty(): show_base()
	else: show_station(_station)

func _contracts_section() -> void:
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	body.add_child(cards)
	for region in FieldCatalog.REGIONS:
		var data: Dictionary = FieldCatalog.REGIONS[region]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = AK.PLATE_2
		style.border_color = data.color
		style.border_width_top = 3
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		panel.add_theme_stylebox_override("panel", style)
		cards.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		text(box, data.name, 20, GOLD)
		text(box, data.brief)
		text(box, data.loot)
		text(box, "专属 / " + data.exclusive, 14)
		text(box, "藏品 / " + data.build, 14)
		var orders := game.base.orders.pointing_at(region)
		if orders > 0: text(box, "订单 %d" % orders, 14, GOLD)
		button(box, "接下合同 →", func(): game.request_contract(region))
		for depth in game.base.unlocked_camps(region):
			button(box, "从%s出发" % game.camp_label(depth), func(): game.request_contract(region, depth))

func _loadout_section() -> void:
	text(body, "出战准备 / 投保", 18)
	for item in game.carried_items():
		var row := HBoxContainer.new()
		body.add_child(row)
		var tag := "已装备" if game.player.equipped.values().has(item) else "背包"
		text(row, "%s · %s %s" % [tag, item.display_name(), "[已投保]" if item.insured else ""], 15).tooltip_text = item.details()
		if item.is_equippable():
			button(row, "投保 %s 龙门币" % Economy.format(game.insurance_price(item)), func(): game.insure(item); _refresh(), item.insured or game.gold < game.insurance_price(item))
			if game.inventory.items.has(item):
				button(row, "装备", func(): game.equip_from(item, game.inventory); game.save_base(); _refresh())
		button(row, "存回仓库", func(): game.store_item(item); _refresh())
	if game.carried_items().any(func(x): return not x.is_equippable()):
		button(body, "背包与安全袋的材料全部存回仓库", func(): game.store_all_materials(); _refresh())

func _stash_section() -> void:
	var base: BaseState = game.base
	var load_by_zone: Array[String] = []
	for category in range(Item.Category.size()):
		load_by_zone.append("%s %d/%d" % [BaseCatalog.CATEGORY_NAMES[category], base.shelf_count(category), base.capacity(category)])
	text(body, "个人仓库 / %s" % "  ·  ".join(load_by_zone), 18)
	_expansion_section()
	var search := LineEdit.new()
	search.placeholder_text = "搜索仓库（名称或词缀，如“攻击力”“稀有”）"
	search.text = stash_query
	search.custom_minimum_size.x = 420
	search.text_submitted.connect(func(value: String): stash_query = value; _refresh())
	var bar := HBoxContainer.new()
	body.add_child(bar)
	bar.add_child(search)
	button(bar, "搜索", func(): stash_query = search.text; _refresh())
	if not stash_query.is_empty(): button(bar, "清除", func(): stash_query = ""; _refresh())
	if game.carried_items().any(func(x): return not x.is_equippable()):
		button(bar, "背包材料全部存回", func(): game.store_all_materials(); _refresh())
	for category in range(Item.Category.size()):
		var shown := game.stash.filter(func(x): return x.category == category and _matches(x))
		if shown.is_empty(): continue
		text(body, "%s（%d）" % [BaseCatalog.CATEGORY_NAMES[category], shown.size()], 16, GOLD)
		for item: Item in shown:
			var row := HBoxContainer.new()
			body.add_child(row)
			text(row, item.display_name(), 15, item.rarity_color()).tooltip_text = item.details()
			button(row, "带入", func(): game.bring_item(item); _refresh())

func _matches(item: Item) -> bool:
	if stash_query.strip_edges().is_empty(): return true
	var haystack := item.display_name() + " " + item.details()
	for word in stash_query.split(" ", false):
		if not word in haystack: return false
	return true

## Building racks and buying the drone (§3.5, §3.6), at the warehouse terminal.
func _expansion_section() -> void:
	var base: BaseState = game.base
	var rank := base.rank()
	text(body, "声望 R%d · %d%s" % [rank, base.prestige, "" if rank >= BaseCatalog.PRESTIGE_RANKS.size() else "  ·  R%d 解锁：%s" % [rank + 1, BaseCatalog.RANK_UNLOCKS[rank + 1]]], 15, GOLD)
	var row := HBoxContainer.new()
	body.add_child(row)
	for category in range(Item.Category.size()):
		var slot := base.next_rack_slot(category)
		var name: String = BaseCatalog.CATEGORY_NAMES[category]
		if slot < 0:
			button(row, "%s区已满配" % name, func(): pass, true)
			continue
		var refusal := game.rack_refusal(category)
		var need_rank := int(BaseCatalog.RACK_RANKS[slot])
		var cost: Dictionary = BaseCatalog.RACK_MATERIALS[slot]
		var label := "%s区第 %d 个货架 %d%s" % [name, slot + 1, BaseCatalog.RACK_PRICES[slot], "" if cost.is_empty() else " + " + BaseCatalog.cost_text(cost)] + ("（R%d）" % need_rank if rank < need_rank else "")
		button(row, label, func(): game.build_rack(category); _refresh(), not refusal.is_empty())
	var upgrades := HBoxContainer.new()
	body.add_child(upgrades)
	for kind in ["pack", "safe"]:
		var level := base.pack_level if kind == "pack" else base.safe_level
		var sizes: Array = BaseCatalog.PACK_SIZES if kind == "pack" else BaseCatalog.SAFE_SIZES
		var prices: Array = BaseCatalog.PACK_PRICES if kind == "pack" else BaseCatalog.SAFE_PRICES
		var title := "背包" if kind == "pack" else "安全袋"
		var now: Vector2i = sizes[level]
		if level + 1 >= sizes.size():
			button(upgrades, "%s %d×%d（已满配）" % [title, now.x, now.y], func(): pass, true)
			continue
		var next: Vector2i = sizes[level + 1]
		var refusal := game.upgrade_refusal(kind)
		var label := "%s扩容 %d×%d → %d×%d  %d + %s" % [title, now.x, now.y, next.x, next.y, int(prices[level + 1]), BaseCatalog.cost_text(game.upgrade_cost(kind))] + ("" if refusal.is_empty() else "（%s）" % refusal)
		button(upgrades, label, func():
			if kind == "pack": game.buy_pack_upgrade()
			else: game.buy_safe_upgrade()
			_refresh(), not refusal.is_empty())
	var camp_refusal := game.camp_upgrade_refusal()
	button(body, "营地升级 %s + %s%s" % [Economy.format(BaseCatalog.CAMP_UPGRADE_PRICE), BaseCatalog.cost_text(BaseCatalog.CAMP_UPGRADE_MATERIALS), "" if camp_refusal.is_empty() else "（%s）" % camp_refusal],
		func(): game.buy_camp_upgrade(); _refresh(), not camp_refusal.is_empty())
	if base.drone: text(body, "搬运无人机 · 已就位", 14, AK.MUTE)
	else:
		var drone_refusal := game.drone_refusal()
		button(body, "购买工程部搬运无人机 %d + %s%s" % [BaseCatalog.DRONE_PRICE, BaseCatalog.cost_text(BaseCatalog.DRONE_MATERIALS), "" if drone_refusal.is_empty() else "（%s）" % drone_refusal],
			func(): game.buy_drone(); _refresh(), not drone_refusal.is_empty())

## The drone's "open and sort everything" (§3.5): each revealed item appears in
## turn, rare and exclusive ones lingering; any key or the button shows the rest.
func show_sort_result(result: Dictionary) -> void:
	_station = ""
	clear("一键分类 / 开箱与归类", "开出 %d 件  ·  上架 %d 件  ·  放进暂存区 %d 件  ·  未能放下 %d 件" % [
		result.revealed.size(), result.shelved.size(), result.staged.size(), result.left.size()])
	var list := VBoxContainer.new()
	body.add_child(list)
	var lines: Array = []
	for item: Item in result.revealed:
		var where := "上架" if result.shelved.has(item) else ("暂存区" if result.staged.has(item) else "留在箱里")
		lines.append([item, where])
	for item: Item in result.shelved:
		if not result.revealed.has(item): lines.append([item, "暂存区 → 上架"])
	var skip := button(body, "全部显示", func(): pass)
	skip.pressed.connect(func():
		for line in lines.slice(list.get_child_count()): _reveal_line(list, line)
		skip.disabled = true)
	button(body, "关闭", game.close_modal)
	_play_reveal(list, lines, skip)

func _play_reveal(list: VBoxContainer, lines: Array, skip: Button) -> void:
	for line in lines:
		if not is_instance_valid(list) or list.get_child_count() >= lines.size(): return
		_reveal_line(list, line)
		var item: Item = line[0]
		var linger := 0.6 + (0.6 if item.rarity >= 2 or not item.exclusive_region.is_empty() else 0.0)
		await get_tree().create_timer(linger).timeout
	if is_instance_valid(skip): skip.disabled = true

func _reveal_line(list: VBoxContainer, line: Array) -> void:
	var item: Item = line[0]
	var rare := item.rarity >= 2 or not item.exclusive_region.is_empty()
	text(list, "%s  ·  %s  →  %s" % [item.display_name(), BaseCatalog.CATEGORY_NAMES[item.category], line[1]], 17 if rare else 15, GOLD if rare else INK).tooltip_text = item.details()

## The card before leaving (§5.3), shown only when there is something to look at.
func show_departure(region: String) -> void:
	_station = ""
	_enter("departure", null)
	BaseScreens.departure(self, region)

## What a crate held, shown when it is opened (基地玩法策划案 §3.7): pick it up
## to carry to its zone, or put it straight into staging. Closing leaves it in
## the opened crate.
func show_item_card(item: Item) -> void:
	_station = ""
	_enter("item_card", null)
	BaseScreens.item_card(self, item)

## Staging (§3.4a): the only place its items can be taken out, either into her
## hands to shelve or straight into the pack for the next contract.
func show_staging() -> void:
	_station = ""
	_enter("staging", null)
	BaseScreens.staging(self)

## Orders and plain delivery (§3.8). Only the warehouse proper (shelves) and the
## pack or safe bag can supply items; crates, staging and equipped gear cannot.
func _outbound_section() -> void:
	var orders: OrderBoard = game.base.orders
	var base: BaseState = game.base
	var rank := base.rank()
	var next := "" if rank >= BaseCatalog.PRESTIGE_RANKS.size() else " / 下一级 %d" % BaseCatalog.PRESTIGE_RANKS[rank]
	text(body, "声望 R%d · %d%s" % [rank, base.prestige, next], 15, GOLD)
	var deliverable := game.deliverable_items()
	for i in range(orders.slots.size()):
		var order = orders.slots[i]
		var box := VBoxContainer.new()
		body.add_child(box)
		if order == null:
			text(box, "订单栏 %d / 空，下次结算后补上" % (i + 1), 16, Color("99aab8"))
			continue
		var t: Dictionary = BaseCatalog.ORDERS[order.id]
		var reward := ("龙门币 %s" % Economy.format(int(t.gold))) if t.has("gold") else ("龙门币为交付价 ×%.1f" % float(t.mult))
		var count := int(t.count)
		if order.state == "done":
			text(box, "订单栏 %d / 已完成  ·  %s" % [i + 1, BaseCatalog.order_text(order.id)], 16, Color("8fd18f"))
			continue
		text(box, "订单栏 %d / %s  ·  %d/%d  ·  %s，声望 %d" % [i + 1, BaseCatalog.order_text(order.id), orders.delivered_count(i), count, reward, int(t.prestige)], 18, GOLD)
		var fits := deliverable.filter(func(x): return orders.matches(i, x))
		if fits.is_empty(): text(box, "个人仓库和背包里没有符合的物品。", 14, Color("99aab8"))
		for item: Item in fits:
			var row := HBoxContainer.new()
			box.add_child(row)
			text(row, "%s%s  ·  %s" % [item.display_name(), item.stack_suffix(), "个人仓库" if game.stash.has(item) else "背包"], 15).tooltip_text = item.details()
			button(row, "交付" if not item.is_stackable() else "交付 ×%d" % orders.takes(i, item), func(): game.deliver_to_order(i, item); _refresh())
		if base.reroll_available: button(box, "免费刷新这张订单（R3，每次结算一次）", func(): game.reroll_order(i); _refresh())
		button(box, "放弃这张订单", func(): game.abandon_order(i); _refresh())
	body.add_child(HSeparator.new())
	text(body, "直接交付 / 只换龙门币", 18)
	if deliverable.is_empty(): text(body, "可交付 0", 15, AK.MUTE)
	for item in deliverable:
		var row := HBoxContainer.new()
		body.add_child(row)
		text(row, "%s%s  ·  %s" % [item.display_name(), item.stack_suffix(), "个人仓库" if game.stash.has(item) else "背包"], 15).tooltip_text = item.details()
		button(row, "交付 +%s" % Economy.format(Economy.price(item)), func(): game.sell(item); _refresh())

## Injury and contamination, with the injury treatment (§4.2, §4.4).
func _medical_summary() -> void:
	var base: BaseState = game.base
	var report: Dictionary = base.medical_report
	if not report.is_empty():
		text(body, "上一份合同 / 污染 %d → %d%s" % [int(report.contamination_before), int(report.contamination_after),
			"  ·  阵亡，带回重伤" if report.injured else ""], 16)
	var tier := base.contamination_tier()
	text(body, "污染 %d（%s）  ·  生命上限 −%d%%" % [roundi(base.contamination), BaseCatalog.CONTAMINATION_TIER_NAMES[tier], roundi(base.hp_penalty() * 100)], 16, GOLD)
	if base.injured:
		text(body, "重伤  ·  生命上限 −%d%%" % roundi(BaseCatalog.INJURY_HP_PENALTY * 100), 15, AK.RED)
		button(body, "治疗重伤（%s 龙门币）" % Economy.format(BaseCatalog.INJURY_TREATMENT), func(): game.treat_injury(); _refresh(), game.gold < BaseCatalog.INJURY_TREATMENT)
	body.add_child(HSeparator.new())

## Flasks for the next contract (药剂进背包): each one bought goes straight into
## the pack and takes a cell. Three 标准急救剂 are issued free per contract.
func _pharmacy_section() -> void:
	var base: BaseState = game.base
	var carried := game.carried_potions()
	var counts := {}
	for item in carried: counts[item.potion_type] = int(counts.get(item.potion_type, 0)) + 1
	text(body, "背包药剂  " + ("  ".join(BaseCatalog.POTIONS.keys().filter(func(t): return counts.has(t)).map(func(t): return "%s ×%d" % [BaseCatalog.POTIONS[t].name, counts[t]])) if not carried.is_empty() else "无"), 18, GOLD)
	text(body, "免费急救剂 %d" % base.free_potions, 15)
	var row := HBoxContainer.new()
	body.add_child(row)
	for type in BaseCatalog.POTIONS:
		var price := base.potion_price(type)
		var label := "%s %s" % [BaseCatalog.POTIONS[type].name, ("（R%d 解锁）" % int(BaseCatalog.POTIONS[type].rank)) if price < 0 else ("免费" if price == 0 else "%s 龙门币" % Economy.format(price))]
		button(row, label, func(): game.buy_potion(type); _refresh(), price < 0 or game.gold < price)

## Contamination treatment at the scan gate (§4.1).
func _decon_section() -> void:
	var base: BaseState = game.base
	text(body, game.medical_view.reading() if is_instance_valid(game.medical_view) else "污染 %d" % roundi(base.contamination), 18, GOLD)
	var current := ceili(base.contamination)
	for target in [39, 0]:
		if current <= target: continue
		var price := BaseCatalog.decon_price(current - target)
		button(body, "降到 %d（%s 龙门币）" % [target, Economy.format(price)], func(): game.decontaminate(target); _refresh(), game.gold < price)
	if current <= 0: text(body, "污染 0", 15, AK.MUTE)

func _report_section(always: bool = false) -> void:
	if game.settlement.is_empty():
		if always: text(body, "暂无回收记录。", 15)
		return
	text(body, "上一份合同 / 回收明细", 18, GOLD)
	for entry in game.settlement:
		text(body, "%s  ·  %s" % [entry.name, entry.reason], 14)

const OFFER_TITLES := {"device": "强化装置", "cache": "战斗缴获", "vault": "密室藏品"}

## The relic choice (局内构筑与数值策划案 §8.5): one card per offer with its
## rarity, its effect here and its 集成战略 original. Owned relics sit underneath.
func show_builds() -> void:
	_enter("builds", -1)
	EventScreens.builds(self)

## The relics owned this contract, one line each.
func build_summary(parent: Node) -> void:
	parent.add_child(HSeparator.new())
	text(parent, "本次藏品 / %d 件" % game.builds.size(), 18, GOLD)
	if game.builds.is_empty():
		text(parent, "还没有藏品。强化装置、战斗缴获和密室都会给出藏品选择。", 14, Color("99aab8"))
		return
	for id in game.builds:
		var relic := RelicCatalog.get_relic(id)
		if relic.is_empty(): continue
		text(parent, "%s / %s" % [relic.name, relic.effect], 13, RelicCatalog.RARITY_COLORS[relic.rarity])

## Lappland's sheet as it stands, in 明日方舟's terms.
func stat_lines(parent: Node) -> void:
	var p := game.player
	text(parent, "生命 %d / %d%s   攻击力 %d   法术攻击力 %d   防御 %d   法抗 %d" % [roundi(p.hp), roundi(p.max_hp),
		("  护盾 %d" % roundi(p.shield)) if p.shield > 0 else "", roundi(p.attack_power()), roundi(p.arts_power()), roundi(p.defense_value()), roundi(p.resistance())], 15)
	text(parent, "攻速 %d（间隔 %.2f 秒）   暴击 %d%% × %d%%   吸血 %d%%   闪避 %d%%   生命回复 %d/秒" % [roundi(p.current_aspd()), p.current_cooldown(),
		roundi(p.crit_rate() * 100), roundi(p.crit_damage() * 100), roundi(p.lifesteal() * 100), roundi(p.evasion() * 100), roundi(p.regen_rate())], 15)

## The Rhodes squad (保全系统修订案 §2): one service — insure one piece of gear, or
## send one home to staging — priced in 赤金 by this squad's multiplier.
var squad_service := "insure"

func show_squad() -> void:
	_enter("squad", null)
	EventScreens.squad(self)

## 坎诺特 (坎诺特商店策划案 §2–3): eight slots priced in 赤金, a paid refresh, and
## what he will buy.
var trader_tab := "buy"

func show_trader() -> void:
	_enter("trader", null)
	EventScreens.trader(self)

## A camp (撤离与营地修订案 §3): 可露希尔's flasks, the 寄存 for materials, selling
## 赤金, and the way out — extraction, or on to the next floor.
func show_camp() -> void:
	_station = ""
	_enter("camp", null)
	EventScreens.camp(self)

## 可露希尔 at the base: the same counter as in the camps (用户：不区分).
func _store_section() -> void:
	text(body, "赤金 %d" % game.gold_available(), 18, GOLD)
	_closure_shop()

func _closure_shop() -> void:
	text(body, "可露希尔的商店", 18, GOLD)
	var row := HBoxContainer.new()
	body.add_child(row)
	for type in BaseCatalog.POTIONS:
		var price := game.closure_potion_price(type)
		button(row, "%s %s" % [BaseCatalog.POTIONS[type].name, "（R%d 解锁）" % int(BaseCatalog.POTIONS[type].rank) if price < 0 else "%d 赤金" % price],
			func(): game.closure_buy_potion(type); _refresh_closure(), price < 0 or game.gold_available() < price)
	var sell := HBoxContainer.new()
	body.add_child(sell)
	var have := game.gold_available()
	for n in [1, 10, have]:
		if n <= 0: continue
		button(sell, "卖出赤金 ×%d → %s 龙门币" % [n, Economy.format(n * Economy.GOLD_BAR_LMD)], func(): game.sell_gold_bars(n); _refresh_closure(), have < n)

func _refresh_closure() -> void:
	if game.in_camp: show_camp()
	elif _station == "store": BaseScreens.store(self)
	else: _refresh()

func show_routes(index: int) -> void:
	_enter("routes", index)
	EventScreens.routes(self, index)

## Esc / the II button (界面策划案 #12).
func show_pause() -> void:
	_station = ""
	pause_page = 1
	pause_confirm = false
	_enter("pause", null)
	BaseScreens.pause(self)


func show_settlement() -> void:
	_station = ""
	EventScreens.settlement(self)

## The current tab: paper, as AK marks the selected page (still not clickable).
func _tab(control: Button, current: bool) -> void:
	if not current: return
	AK.style_button(control, "paper")
	control.add_theme_stylebox_override("disabled", control.get_theme_stylebox("normal"))
	control.add_theme_color_override("font_disabled_color", AK.INK)
