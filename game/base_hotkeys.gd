class_name BaseHotkeys
extends RefCounted

## 主基地快捷栏 (用户 2026-11-06: 主基地所有交互项都绑一个快捷键，并显示在下方，
## 未解锁的锁住，点击或摁快捷键时跳出解锁需求提示). One key per station of
## BaseMap.interactables (the two lifts share one, the construction sites are
## reached through the 基建总控台), each a Keybinds function "base_<id>".
## Pressing it, or its slot on the bar, does what E does standing there.
##
## A station is locked when its screen would only show what it waits for:
## the facility not built yet (交易所, 科研部, 农业部, 食堂: building them is
## itself gated by the faction relation and the department's lost operator,
## GmFacilities.facility_refusal), or its department's operator still lost
## (加工部 → 机械师, 沙盘航行 → Stormeye). The others always open.

## [station id, bar name]. The bar's order; the keys are Keybinds' "base_<id>"
## rows (group 基地站点), in the same order.
const STATIONS := [
	["dispatch", "调度台"], ["workbench", "整备台"], ["logistics", "后勤柜台"], ["stash", "仓管台"],
	["outbound", "出库区"], ["reception", "医疗前台"], ["pharmacy", "药房"], ["store", "商店"],
	["exchange", "交易所"], ["workshop", "加工站"], ["personnel", "人事部"], ["sand_table", "沙盘"],
	["research", "科研部"], ["site_hub", "基建"], ["lift", "升降梯"], ["farm", "农业部"], ["canteen", "食堂"],
]

static func ids() -> Array:
	return STATIONS.map(func(s): return s[0])

static func action(id: String) -> String:
	return "base_" + id

static func name_of(id: String) -> String:
	for s in STATIONS:
		if s[0] == id: return s[1]
	return ""

## The BaseMap station the key stands for: the lift on her own deck.
static func station_id(game: GameManager, id: String) -> String:
	if id == "lift" and game.deck == 2: return "lift2"
	return id

## "" when the station opens, else what it waits for, as one line.
static func refusal(game: GameManager, id: String) -> String:
	var needs := needs_of(game, id)
	return "" if needs.is_empty() else "%s：%s" % [name_of(id), " · ".join(needs)]

## What a locked station waits for, each condition the code checks (empty when open).
static func needs_of(game: GameManager, id: String) -> Array[String]:
	var out: Array[String] = []
	match id:
		"exchange":
			if not game.exchange.unlocked(): out = _build_needs(game, "exchange", 1)
		"research":
			if not game.research.is_open(): out = _build_needs(game, "lab", ResearchCatalog.OPEN_LEVEL)
		"farm", "canteen":
			if game.base.facility_level(id) < 1: out = _build_needs(game, id, 1)
		"workshop": _add(out, game.dept_refusal("workshop"))
		"sand_table": _add(out, game.dept_refusal("voyage"))
	return out

## A facility to be built to `level`: the relation its building waits for,
## its department's lost operator, then the level itself.
static func _build_needs(game: GameManager, facility: String, level: int) -> Array[String]:
	var out: Array[String] = []
	_add(out, game.facilities.gate_refusal(facility))
	_add(out, game.dept_refusal(facility))
	out.append("需要%s Lv%d" % [BaseCatalog.facility_name(facility), level])
	return out

static func _add(out: Array[String], need: String) -> void:
	if not need.is_empty(): out.append(need)

static func locked(game: GameManager, id: String) -> bool:
	return not needs_of(game, id).is_empty()
