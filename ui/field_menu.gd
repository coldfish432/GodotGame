class_name FieldMenu
extends Control

var game: GameManager
var body: VBoxContainer
const INK := Color("e8edf1")
const GOLD := Color("ebbd72")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.043, 0.065, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
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
	hide()

func clear(title: String, subtitle: String) -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	show()
	text(body, "RHODES ISLAND   /   FIELD OPERATIONS", 14, GOLD)
	text(body, title, 30)
	text(body, subtitle, 16, Color("99aab8"))
	body.add_child(HSeparator.new())

func text(parent: Node, value: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
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
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

## Station kinds opened from the walkable base (see BaseMap / GameManager.open_station).
const STATIONS := {
	"contracts": ["调度台 / 外勤合同", "选择地区接下合同 · 每 3 区段固定撤离"],
	"insurance": ["后勤柜台 / 出战准备", "带入装备可投保：每件 15，阵亡回收率 60%"],
	"loadout": ["整备台 / 装备", "装备、卸下或存回仓库"],
	"stash": ["仓管台 / 仓库", "从个人仓库带入下一份合同"],
	"outbound": ["出库区 / 订单与交付", "交付个人仓库或背包里的物品：按订单换资金和声望，或直接换资金"],
	"report": ["医疗前台 / 回收报告与治疗", "上一份合同的回收明细、污染变化，以及重伤治疗"],
	"pharmacy": ["药房窗口 / 配药", "下一份合同带哪些药：标准急救剂免费，其余每瓶收费，结算后恢复为 3 瓶标准急救剂"],
	"decon": ["污染检测门 / 检测与处理", "污染跨合同保留；出发时按当时的数值决定减益"],
	"store": ["可露希尔的商店", "暂未开张"],
}
var _station := ""

## Everything on one page; kept for tools and tests that want the overview.
func show_base() -> void:
	_station = ""
	clear("罗德岛 / 外勤合同", "仓库、出战准备与投保    ·    资金 %d    ·    不设经验等级" % game.gold)
	_contracts_section()
	_loadout_section()
	_stash_section()
	_report_section()
	text(body, "操作：右键移动 · 左键攻击 · Shift 闪避 · Q 药瓶 · E 交互 · I 背包", 14)

func show_station(kind: String) -> void:
	_station = kind
	var info: Array = STATIONS.get(kind, ["罗德岛", ""])
	clear(info[0], "%s    ·    资金 %d" % [info[1], game.gold])
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
		"store": text(body, "可露希尔：“商店还在装修，开张了第一时间通知你。”", 16)
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
		style.bg_color = data.color.darkened(0.65)
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
		text(box, "构筑 / " + data.build, 14)
		var orders := game.base.orders.pointing_at(region)
		if orders > 0: text(box, "有 %d 张订单指向此地区" % orders, 14, GOLD)
		button(box, "接下合同 →", func(): game.request_contract(region))
	text(body, "每 3 区段固定撤离 · 每段另有 20% 概率发现撤离点 · 深入后不可返回", 15, GOLD)

func _loadout_section() -> void:
	text(body, "出战准备 / 带入装备可投保：每件 15，阵亡回收率 60%", 18)
	if game.carried_items().is_empty(): text(body, "未携带装备。基础双武器始终可用，可直接出发。", 15)
	for item in game.carried_items():
		var row := HBoxContainer.new()
		body.add_child(row)
		var tag := "已装备" if game.player.equipped.values().has(item) else "背包"
		text(row, "%s · %s %s" % [tag, item.display_name(), "[已投保]" if item.insured else ""], 15).tooltip_text = item.details()
		if item.is_equippable():
			button(row, "投保", func(): game.insure(item); _refresh(), item.insured or game.gold < 15)
			if game.inventory.items.has(item):
				button(row, "装备", func(): game.equip_from(item, game.inventory); game.save_base(); _refresh())
		button(row, "存回仓库", func(): game.store_item(item); _refresh())

func _stash_section() -> void:
	var base: BaseState = game.base
	var load_by_zone: Array[String] = []
	for category in range(Item.Category.size()):
		load_by_zone.append("%s %d/%d" % [BaseCatalog.CATEGORY_NAMES[category], base.shelf_count(category), base.capacity(category)])
	text(body, "个人仓库 / %s" % "  ·  ".join(load_by_zone), 18)
	_expansion_section()
	if game.stash.is_empty(): text(body, "个人仓库是空的。上架的物品可以在这里带入下一份合同；交付在出库区。", 15)
	for item in game.stash:
		var row := HBoxContainer.new()
		body.add_child(row)
		text(row, item.display_name(), 15).tooltip_text = item.details()
		button(row, "带入", func(): game.bring_item(item); _refresh())

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
		var refusal := base.rack_refusal(category, game.gold)
		var need_rank := int(BaseCatalog.RACK_RANKS[slot])
		var label := "%s区第 %d 个货架 %d" % [name, slot + 1, BaseCatalog.RACK_PRICES[slot]] + ("（R%d）" % need_rank if rank < need_rank else "")
		button(row, label, func(): game.build_rack(category); _refresh(), not refusal.is_empty())
	if base.drone: text(body, "一键分类无人机：已就位。在货箱或暂存区可以全部开箱并归类；每次回到基地会把暂存区能上架的物品送上货架。", 14, Color("99aab8"))
	else:
		button(body, "购买工程部搬运无人机 %d%s" % [BaseCatalog.DRONE_PRICE, "（R%d）" % BaseCatalog.DRONE_RANK if rank < BaseCatalog.DRONE_RANK else ""],
			func(): game.buy_drone(); _refresh(), rank < BaseCatalog.DRONE_RANK or game.gold < BaseCatalog.DRONE_PRICE)

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
	var data: Dictionary = FieldCatalog.REGIONS[region]
	var orders := game.base.orders.pointing_at(region)
	clear("接下：" + data.name, "有 %d 张订单指向此地区" % orders if orders > 0 else data.brief)
	for warning in game.departure_warnings(): text(body, warning, 16, GOLD)
	text(body, "药瓶：" + "  ".join(game.base.potion_belt().map(func(t): return BaseCatalog.POTIONS[t].name)), 15)
	var insured: Array = game.carried_items().filter(func(x): return x.insured).map(func(x): return x.item_name)
	text(body, "投保：" + ("、".join(insured) if not insured.is_empty() else "无"), 15)
	button(body, "出发", func(): game.start_contract(region))
	button(body, "返回", game.close_modal)

## What a crate held, shown when it is opened (基地玩法策划案 §3.7): pick it up
## to carry to its zone, or put it straight into staging. Closing leaves it in
## the opened crate.
func show_item_card(item: Item) -> void:
	_station = ""
	var base := game.base
	clear("开箱 / " + item.display_name(), "%s · %d×%d%s" % [BaseCatalog.CATEGORY_NAMES[item.category], item.width, item.height,
		("  ·  产地：" + FieldCatalog.REGIONS[item.origin_region].name) if FieldCatalog.REGIONS.has(item.origin_region) else ""])
	text(body, item.details(), 16)
	text(body, "交付价 %d" % item.value, 15, GOLD)
	var zone: String = BaseCatalog.CATEGORY_NAMES[item.category]
	var holding := base.hand != null
	button(body, "先放下手上的 %s" % base.hand.item_name if holding else "拿起（拿到%s区上架，%d/%d）" % [zone, base.shelf_count(item.category), base.capacity(item.category)],
		func(): game.pick_up_item(item); game.close_modal(), holding)
	button(body, "放入暂存区（%d/%d）" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY],
		func(): game.stage_item(item); game.close_modal(), not base.staging_has_room())
	if base.drone: button(body, "全部开箱并归类（无人机）", func(): game.close_modal(); game.sort_everything())
	button(body, "先留在箱里", game.close_modal)

## Staging (§3.4a): the only place its items can be taken out, either into her
## hands to shelve or straight into the pack for the next contract.
func show_staging() -> void:
	_station = ""
	var base := game.base
	clear("暂存区", "%d/%d 件  ·  不能交付；要带入或上架，须在这里拿出来" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY])
	if base.staging.is_empty(): text(body, "暂存区是空的。开箱时选择“放入暂存区”，或拿着物品在这里按 E。", 15)
	if base.drone and (base.sealed_count() > 0 or not base.staging.is_empty()):
		button(body, "全部开箱并归类（无人机）", func(): game.close_modal(); game.sort_everything())
	for item in base.staging:
		var row := HBoxContainer.new()
		body.add_child(row)
		text(row, "%s  ·  %s" % [item.display_name(), BaseCatalog.CATEGORY_NAMES[item.category]], 15).tooltip_text = item.details()
		button(row, "拿到手上", func(): game.pick_up_item(item); game.close_modal(), base.hand != null)
		button(row, "放进背包", func(): game.unstage_to_pack(item); show_staging())
	button(body, "返回", game.close_modal)

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
		var reward := ("资金 %d" % int(t.gold)) if t.has("gold") else ("资金为交付价 ×%.1f" % float(t.mult))
		var count := int(t.count)
		if order.state == "done":
			text(box, "订单栏 %d / 已完成  ·  %s" % [i + 1, BaseCatalog.order_text(order.id)], 16, Color("8fd18f"))
			continue
		text(box, "订单栏 %d / %s  ·  %d/%d  ·  %s，声望 %d" % [i + 1, BaseCatalog.order_text(order.id), order.delivered.size(), count, reward, int(t.prestige)], 18, GOLD)
		var fits := deliverable.filter(func(x): return orders.matches(i, x))
		if fits.is_empty(): text(box, "个人仓库和背包里没有符合的物品。", 14, Color("99aab8"))
		for item: Item in fits:
			var row := HBoxContainer.new()
			box.add_child(row)
			text(row, "%s  ·  %s" % [item.display_name(), "个人仓库" if game.stash.has(item) else "背包"], 15).tooltip_text = item.details()
			button(row, "交付", func(): game.deliver_to_order(i, item); _refresh())
		if base.reroll_available: button(box, "免费刷新这张订单（R3，每次结算一次）", func(): game.reroll_order(i); _refresh())
		button(box, "放弃这张订单", func(): game.abandon_order(i); _refresh())
	body.add_child(HSeparator.new())
	text(body, "直接交付 / 只换资金", 18)
	if deliverable.is_empty(): text(body, "个人仓库和背包里没有可交付的物品。暂存区的物品要先上架。", 15)
	for item in deliverable:
		var row := HBoxContainer.new()
		body.add_child(row)
		text(row, "%s  ·  %s" % [item.display_name(), "个人仓库" if game.stash.has(item) else "背包"], 15).tooltip_text = item.details()
		button(row, "交付 +%d" % item.value, func(): game.sell(item); _refresh())

## Injury and contamination, with the injury treatment (§4.2, §4.4).
func _medical_summary() -> void:
	var base: BaseState = game.base
	var report: Dictionary = base.medical_report
	if not report.is_empty():
		text(body, "上一份合同 / 污染 %d → %d%s" % [int(report.contamination_before), int(report.contamination_after),
			"  ·  阵亡，带回重伤" if report.injured else ""], 16)
	var tier := base.contamination_tier()
	text(body, "当前污染 %d（%s）  ·  下次出发生命上限 −%d%%" % [roundi(base.contamination), BaseCatalog.CONTAMINATION_TIER_NAMES[tier], roundi(base.hp_penalty() * 100)], 16, GOLD)
	if base.injured:
		text(body, "重伤：下次出发生命上限 −%d%%。不治疗的话，下一次结算后自动消失。" % roundi(BaseCatalog.INJURY_HP_PENALTY * 100), 15)
		button(body, "治疗重伤（%d 资金）" % BaseCatalog.INJURY_TREATMENT, func(): game.treat_injury(); _refresh(), game.gold < BaseCatalog.INJURY_TREATMENT)
	if tier > 0: text(body, "污染在病房区入口的检测门处理。", 14, Color("99aab8"))
	body.add_child(HSeparator.new())

## The belt for the next contract (§4.3). Swapping refunds the old flask's
## price, so only what she leaves with is paid for.
func _pharmacy_section() -> void:
	var base: BaseState = game.base
	text(body, "下次带：" + "  ".join(base.potion_belt().map(func(t): return BaseCatalog.POTIONS[t].name)), 18, GOLD)
	for slot in range(base.potions.size()):
		var row := HBoxContainer.new()
		body.add_child(row)
		text(row, "第 %d 瓶 / %s" % [slot + 1, BaseCatalog.POTIONS[base.potions[slot]].name], 15)
		for type in BaseCatalog.POTIONS:
			var price := base.potion_price(type)
			var cost := price - base.potion_price(base.potions[slot])
			var label := "换成%s" % BaseCatalog.POTIONS[type].name + ("（R%d 解锁）" % int(BaseCatalog.POTIONS[type].rank) if price < 0 else ("" if cost <= 0 else " %d" % cost))
			button(row, label, func(): game.set_potion(slot, type); _refresh(), price < 0 or type == base.potions[slot] or game.gold < cost)
	var extra := HBoxContainer.new()
	body.add_child(extra)
	if base.extra_potion.is_empty():
		text(extra, "第 4 瓶 / 本次合同限一瓶，%d 资金加药剂价" % BaseCatalog.EXTRA_POTION_PRICE, 15)
		for type in BaseCatalog.POTIONS:
			var price := base.potion_price(type)
			button(extra, "加一瓶%s %d" % [BaseCatalog.POTIONS[type].name, BaseCatalog.EXTRA_POTION_PRICE + maxi(price, 0)],
				func(): game.buy_extra_potion(type); _refresh(), price < 0 or game.gold < BaseCatalog.EXTRA_POTION_PRICE + price)
	else:
		text(extra, "第 4 瓶 / %s" % BaseCatalog.POTIONS[base.extra_potion].name, 15)
		button(extra, "退掉", func(): game.return_extra_potion(); _refresh())
	for type in BaseCatalog.POTIONS:
		text(body, "%s：%s" % [BaseCatalog.POTIONS[type].name, BaseCatalog.POTIONS[type].text], 14, Color("99aab8"))
	text(body, "构筑物或词缀减少药瓶容量时，从最后一瓶开始扣。没用掉的付费药剂结算后不退款、不保留。", 14, Color("99aab8"))

## Contamination treatment at the scan gate (§4.1).
func _decon_section() -> void:
	var base: BaseState = game.base
	text(body, game.medical_view.reading() if is_instance_valid(game.medical_view) else "污染 %d" % roundi(base.contamination), 18, GOLD)
	text(body, "每点 %.1f 资金，最少 %d。每次结算会先自然消退 %d 点。" % [BaseCatalog.DECON_PRICE_PER_POINT, BaseCatalog.DECON_MIN_PRICE, BaseCatalog.CONTAMINATION_DECAY], 15)
	var current := ceili(base.contamination)
	for target in [39, 0]:
		if current <= target: continue
		var price := BaseCatalog.decon_price(current - target)
		button(body, "降到 %d（%d 资金）" % [target, price], func(): game.decontaminate(target); _refresh(), game.gold < price)
	if current <= 0: text(body, "没有污染，不需要处理。", 15)

func _report_section(always: bool = false) -> void:
	if game.settlement.is_empty():
		if always: text(body, "暂无回收记录。", 15)
		return
	text(body, "上一份合同 / 回收明细", 18, GOLD)
	for entry in game.settlement:
		text(body, "%s  ·  %s" % [entry.name, entry.reason], 14)

const OFFER_TITLES := {"device": "强化装置", "cache": "战斗缴获", "vault": "密室藏品"}

## The relic choice (局内构筑与数值策划案 §8.5): one card per offer with its
## rarity, school, effect, what it adds to the school's resonance, and where
## in 集成战略 it came from. The current build sits underneath.
func show_builds() -> void:
	clear("%s / 选择一件构筑物" % OFFER_TITLES.get(game.offer_source, "强化装置"), "本次合同有效 · 跨区段保留 · 不占背包 · 结算后清空")
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	body.add_child(cards)
	for offer in game.build_offers:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142232")
		style.border_color = RelicCatalog.RARITY_COLORS[offer.rarity]
		style.set_border_width_all(2)
		style.border_width_top = 5
		for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, 14)
		panel.add_theme_stylebox_override("panel", style)
		cards.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		var school_label: String = RelicCatalog.school_name(offer.school)
		if offer.school == RelicCatalog.BRIDGE:
			school_label += "（%s）" % " + ".join(offer.requires.map(func(x): return RelicCatalog.school_name(x)))
		text(box, "%s · %s" % [RelicCatalog.RARITY_NAMES[offer.rarity], school_label], 14, RelicCatalog.school_color(offer.school))
		text(box, offer.name, 22, RelicCatalog.RARITY_COLORS[offer.rarity])
		text(box, offer.hook, 14, Color("99aab8"))
		text(box, offer.effect, 17)
		var hint := RelicCatalog.resonance_hint(offer.id, game.builds)
		if not hint.is_empty(): text(box, hint, 14, GOLD)
		text(box, "底本：%s — %s" % [offer.source_name, offer.adaptation], 12, Color("6f8396")).tooltip_text = offer.source_url
		button(box, "选择 " + offer.name, func(): game.choose_build(offer.id))
	var row := HBoxContainer.new()
	body.add_child(row)
	button(row, "刷新（花 %d 待交付报酬，现有 %d）" % [game.reroll_cost(), game.run_gold], func(): game.reroll_offers(), game.run_gold < game.reroll_cost())
	button(row, "稍后选择", game.close_modal)
	build_summary(body)

## Owned relics grouped by school, with each school's resonance progress.
func build_summary(parent: Node) -> void:
	parent.add_child(HSeparator.new())
	var counts := RelicCatalog.school_counts(game.builds)
	text(parent, "本次构筑 / %d 件" % game.builds.size(), 18, GOLD)
	var line: Array[String] = []
	for school in RelicCatalog.SCHOOLS:
		if counts[school] > 0: line.append("%s %d" % [RelicCatalog.school_name(school), counts[school]])
	if line.is_empty():
		text(parent, "还没有构筑物。同一体系集齐 2 件、4 件时激活共鸣。", 14, Color("99aab8"))
		return
	text(parent, "  ·  ".join(line), 15)
	for school in RelicCatalog.SCHOOLS:
		var reached := RelicCatalog.tier(counts, school)
		for step in [2, 4]:
			if reached >= step: text(parent, "%s 共鸣 %d：%s" % [RelicCatalog.school_name(school), step, RelicCatalog.SCHOOLS[school][step].text], 14, RelicCatalog.school_color(school))
	for id in game.builds:
		var relic := RelicCatalog.get_relic(id)
		if relic.is_empty(): continue
		text(parent, "%s [%s] / %s" % [relic.name, RelicCatalog.school_name(relic.school), relic.effect], 13, RelicCatalog.RARITY_COLORS[relic.rarity])

## Lappland's sheet as it stands, in 明日方舟's terms.
func stat_lines(parent: Node) -> void:
	var p := game.player
	text(parent, "生命 %d / %d%s   攻击力 %d   法术攻击力 %d   防御 %d   法抗 %d" % [roundi(p.hp), roundi(p.max_hp),
		("  护盾 %d" % roundi(p.shield)) if p.shield > 0 else "", roundi(p.attack_power()), roundi(p.arts_power()), roundi(p.defense_value()), roundi(p.resistance())], 15)
	text(parent, "攻速 %d（间隔 %.2f 秒）   暴击 %d%% × %d%%   吸血 %d%%   闪避 %d%%   生命回复 %d/秒" % [roundi(p.current_aspd()), p.current_cooldown(),
		roundi(p.crit_rate() * 100), roundi(p.crit_damage() * 100), roundi(p.lifesteal() * 100), roundi(p.evasion() * 100), roundi(p.regen_rate())], 15)

func show_gilding() -> void:
	clear("点金装置 / 指定装备", "本区段限一次 · 不提升属性 · 阵亡必定带出 · 点金后本次合同不可丢弃")
	var count := 0
	for item in game.carried_items():
		if item.is_equippable() and not item.gilded:
			count += 1
			button(body, item.display_name() + "  /  " + item.details(), func(): game.gild_item(item))
	if count == 0: text(body, "没有可点金的装备。材料不能点金。")
	button(body, "返回", game.close_modal)

func show_routes(index: int) -> void:
	clear("单向深入 / 选择去向", "深入后，上一区段的撤离点、装置和遗留物均不可返回。")
	for i in range(FieldCatalog.ROUTES.size()):
		var route: Dictionary = FieldCatalog.ROUTES[i]
		text(body, route.name + ("  ·  当前入口" if i == index else ""), 22, GOLD)
		var detail: String = route.detail
		if game.region_id == "mine": detail = detail.replace("精英增援", "敌群增援")
		text(body, "%s / 警戒 +%d" % [detail, route.pressure], 18)
		button(body, "进入 " + route.name, func(): game.advance(i))
	button(body, "留在本区段", game.close_modal)
