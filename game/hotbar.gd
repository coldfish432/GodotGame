class_name Hotbar
extends RefCounted

## What the field hotbar's eight slots hold (用户 2026-10-10: 快捷栏常驻 n 个，
## 可以自己绑定消耗品、技能和键位). Left-click attack is fixed and not one of
## them. The player picks a slot's content by clicking it on the bar (Hud's
## picker); its keys are the Keybinds functions hotbar_1..8, so a slot can be
## on any key or mouse button, and each content also has its own dedicated
## Keybinds function (dash, operator_skill, potion_A/B/C) usable off the bar.
## Stored in settings.cfg under "hotbar" as [{action}].

const SLOTS := 8

const ACTIONS := {
	"dash": {"name": "闪避", "input": "dash", "glyph": "dodge"},
	# Her Space skill, whoever she is (绝影 for Amiya, a recruit's own); the
	# id stays "shadow" so saved bars keep it.
	"shadow": {"name": "绝影", "input": "operator_skill", "glyph": "wave", "skill": true},
	"potion_A": {"name": "标准急救剂", "input": "potion_A", "glyph": "flask", "potion": "A"},
	"potion_B": {"name": "缓释凝胶", "input": "potion_B", "glyph": "flask", "potion": "B"},
	"potion_C": {"name": "抑制喷剂", "input": "potion_C", "glyph": "flask", "potion": "C"},
	# 可露希尔特供 and the regional flasks (药剂与商人界面策划案 §5: any flask on
	# the bar; only A–C have dedicated keys). 应急强心针 is never drunk.
	"potion_D": {"name": "热能饮剂", "input": "", "glyph": "flask", "potion": "D"},
	"potion_E": {"name": "镇静合剂", "input": "", "glyph": "flask", "potion": "E"},
	"potion_F": {"name": "战术兴奋剂", "input": "", "glyph": "flask", "potion": "F"},
	"potion_G": {"name": "急行针剂", "input": "", "glyph": "flask", "potion": "G"},
	"potion_H": {"name": "源石护盾凝胶", "input": "", "glyph": "flask", "potion": "H"},
	"potion_I": {"name": "广谱解毒剂", "input": "", "glyph": "flask", "potion": "I"},
	"potion_J": {"name": "静默喷剂", "input": "", "glyph": "flask", "potion": "J"},
	"potion_K": {"name": "技艺增幅剂", "input": "", "glyph": "flask", "potion": "K"},
	"potion_rat": {"name": "黑市兴奋剂", "input": "", "glyph": "flask", "potion": "rat"},
	"potion_reunion": {"name": "自制抑制剂", "input": "", "glyph": "flask", "potion": "reunion"},
	"potion_ursus": {"name": "矿工烈酒", "input": "", "glyph": "flask", "potion": "ursus"},
	"potion_sami": {"name": "林地草药茶", "input": "", "glyph": "flask", "potion": "sami"},
}
## The picker's order; "" is an empty slot.
const CHOICES := ["", "dash", "shadow", "potion_A", "potion_B", "potion_C", "potion_D", "potion_E", "potion_F", "potion_G",
	"potion_H", "potion_I", "potion_J", "potion_K", "potion_rat", "potion_reunion", "potion_ursus", "potion_sami"]
const CHOICE_NAMES := {"": "空", "dash": "闪避", "shadow": "绝影", "potion_A": "急救剂", "potion_B": "缓释凝胶", "potion_C": "抑制喷剂",
	"potion_D": "热能饮剂", "potion_E": "镇静合剂", "potion_F": "战术兴奋剂", "potion_G": "急行针剂", "potion_H": "护盾凝胶",
	"potion_I": "解毒剂", "potion_J": "静默喷剂", "potion_K": "技艺增幅剂", "potion_rat": "黑市兴奋剂", "potion_reunion": "自制抑制剂",
	"potion_ursus": "矿工烈酒", "potion_sami": "林地草药茶"}

const DEFAULT := [
	{"action": "dash"}, {"action": "shadow"}, {"action": "potion_A"}, {"action": "potion_B"},
	{"action": "potion_C"}, {"action": ""}, {"action": ""}, {"action": ""},
]

## The eight slots as [{action}], repaired against bad saved data.
static func slots() -> Array:
	var saved: Variant = SystemScreens.settings.get("hotbar", [])
	var out: Array = []
	for i in range(SLOTS):
		var entry: Dictionary = DEFAULT[i].duplicate()
		if saved is Array and i < saved.size() and saved[i] is Dictionary:
			var action := str(saved[i].get("action", entry.action))
			if action == "" or ACTIONS.has(action): entry.action = action
		out.append(entry)
	return out

## The Keybinds function behind slot `index`.
static func input_of(index: int) -> String:
	return "hotbar_%d" % (index + 1)

## The auto-potion slot at the bar's right end (用户 2026-10-15: 快捷栏单开一个框
## 放回血药，血量低于下限自动喝，一瓶接一瓶直到超过上限). It holds a potion
## kind, not an action of its own, and is set through set_action(AUTO, …).
## The two thresholds are shares of max HP in the settings.
const AUTO := SLOTS
const AUTO_CHOICES := ["", "potion_A", "potion_B"]

static func auto_potion() -> String:
	var action := str(SystemScreens.settings.get("auto_potion", ""))
	return action if AUTO_CHOICES.has(action) else ""

## [below this she starts drinking, at or above this she stops].
static func auto_thresholds() -> Array:
	var low := clampf(float(SystemScreens.settings.get("auto_potion_low", 0.4)), 0.05, 0.95)
	var high := clampf(float(SystemScreens.settings.get("auto_potion_high", 0.9)), 0.05, 0.95)
	return [low, maxf(low, high)]

## Put `action` in slot `index`; a slot that already held it takes this
## slot's old action, so an action is never on the bar twice. The auto slot
## stands apart: what it holds can also be on the bar.
static func set_action(index: int, action: String) -> void:
	if index == AUTO:
		if AUTO_CHOICES.has(action):
			SystemScreens.settings["auto_potion"] = action
			if SystemScreens._game != null: SystemScreens.save_settings()
		return
	var data := slots()
	if index < 0 or index >= SLOTS or not (action == "" or ACTIONS.has(action)): return
	if action != "":
		for i in range(SLOTS):
			if i != index and data[i].action == action: data[i].action = data[index].action
	data[index].action = action
	_store(data)

static func reset() -> void:
	_store(DEFAULT.duplicate(true))

static func _store(data: Array) -> void:
	SystemScreens.settings["hotbar"] = data
	if SystemScreens._game != null: SystemScreens.save_settings()
