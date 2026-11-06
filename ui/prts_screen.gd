class_name PrtsScreen
extends RefCounted

## The PRTS terminal (Enter at the base; 仓库形状修订案 §七, 用户 2026-11-04:
## prts是其他游戏类似邮箱+通知的东西; 不用分两页，可以区分消息和待领取物品的消息).
## One inbox, newest first: every broadcast, and the letters holding what the
## warehouse had no room for, marked with their attachments. The letter
## picked shows its attachments on the right: a click takes a piece into the
## warehouse (the pack when the warehouse has no room); 全部收入仓库 takes all
## of every letter that fits.

const TOP := BaseScreens.TOP
const BOTTOM := BaseScreens.BOTTOM
## The letter shown on the right (an index into BaseState.mail; -1 the newest).
static var letter := -1

static func build(menu: FieldMenu) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var stage := BaseScreens.shell(menu, "PRTS", "PRTS TERMINAL", [], 0, Callable(), "PRTS")
	if letter >= base.mail.size() or letter < 0: letter = base.mail.size() - 1
	BaseScreens._section(stage, "消息", "INBOX  %d" % (base.prts_history.size() + base.mail.size()), Vector2(16, TOP + 8))
	# Broadcasts and letters together, newest first.
	var rows: Array = []
	for line in base.prts_history: rows.append({"time": int(line[2]) if line.size() > 2 else 0, "line": line})
	for i in range(base.mail.size()): rows.append({"time": int(base.mail[i].time), "letter": i})
	rows.sort_custom(func(a, b): return a.time > b.time)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(16, TOP + 40), Vector2(740, BOTTOM - TOP - 40))
	scroll.add_child(list)
	for row in rows:
		if row.has("letter"): list.add_child(_letter_row(menu, int(row.letter)))
		else: list.add_child(_line_row(row.line))
	_attachments(menu, stage)

static func _stamp(unix: int) -> String:
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(local, true).substr(5, 14)

static func _line_row(line: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var stamp := AK.label(str(line[0]), 11, AK.DIM, AK.en())
	stamp.custom_minimum_size.x = 112
	row.add_child(stamp)
	var text := AK.label(str(line[1]), 13, AK.FG)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 600
	text.remove_meta("fit_size")
	row.add_child(text)
	return row

## A letter with things to take: picked, it fills the right column.
static func _letter_row(menu: FieldMenu, i: int) -> Control:
	var base: BaseState = menu.game.base
	var l: Dictionary = base.mail[i]
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(724, 34)
	b.add_child(AK.rect(AK.PLATE if i == letter else AK.PLATE_2, Vector2.ZERO, Vector2(724, 34)))
	b.add_child(AK.rect(AK.SP, Vector2.ZERO, Vector2(4, 34)))
	AK.put(b, AK.label(_stamp(int(l.time)), 11, AK.DIM, AK.en()), Vector2(12, 10))
	AK.put(b, AK.label("%s：仓库空间不足，物品已暂存。" % l.from, 13, AK.FG), Vector2(124, 8))
	AK.put(b, AK.tag("待领取 %d" % (l.items as Array).size(), AK.SP), Vector2(620, 6))
	b.pressed.connect(func(): letter = i; build(menu))
	return b

static func _attachments(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var x := 776.0
	var room := AK.label("仓库 %d/%d" % [base.shelf_count(), base.capacity()], 12, AK.RED if base.shelf_count() >= base.capacity() else AK.FG, AK.en())
	AK.put(stage, room, Vector2(x, TOP + 10))
	if base.mail.is_empty(): return
	var all := AK.button("全部收入仓库", "yellow", 12)
	AK.put(stage, all, Vector2(1104, TOP + 4), Vector2(160, 30))
	all.pressed.connect(func():
		game.claim_all_mail()
		build(menu))
	var l: Dictionary = base.mail[letter]
	BaseScreens._section(stage, str(l.from), "ATTACHMENTS  %d" % (l.items as Array).size(), Vector2(x, TOP + 44))
	var grid := BaseScreens.FlowGrid.packed((l.items as Array).duplicate(), 12, 8, func(item: Item):
		game.claim_mail_item(item)
		build(menu))
	grid.cards = true
	TraderScreen._game = game
	AK.put(stage, grid, Vector2(x, TOP + 76))
