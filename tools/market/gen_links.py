"""Generates game/market/market_links.gd: the story lines (links_data.py),
the cross-links and the world-state factors (交易所事件表_v1_4.md §14–§15).

Run: python tools/market/gen_links.py
"""
# The web (用户 2026-10-16: 能织成网吗): cross-arc links, then the factor layer.
import os
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'links_data.py'), encoding='utf-8').read()
cross = '''
arc("跨线", {
    # Ursus unrest feeds Lungmen, Columbia's arms trade and Sami.
    "U7": [F("S16", 0.3, 12, 72), B("C9", 1.5, 168), B("L17", 1.5, 168)],
    "U13": [B("L33", 1.5, 168), B("X21", 1.3, 168)],
    "U19": [F("L4", 0.2, 12, 48), B("U12", 1.3, 72)],
    "U21": [F("K16", 0.2, 12, 48)],
    "U6": [B("U13", 2.0, 336), B("V10", 2.0, 336), B("K17", 1.5, 168)],
    # Catastrophes reach every region.
    "X7": [F("L4", 0.3, 6, 48), F("U12", 0.2, 12, 72), F("C6", 0.2, 24, 96), B("L10", 1.5, 168)],
    "X2": [B("K2", 1.5, 48), B("U21", 1.5, 48), B("S14", 1.5, 48)],
    "X18": [F("L21", 0.3, 12, 48), F("C20", 0.2, 12, 48)],
    "X25": [F("U27", 0.1, 24, 168), F("L34", 0.1, 24, 168)],
    "S20": [F("U21", 0.4, 12, 72), B("X25", 2.0, 336), F("C27", 0.3, 24, 96)],
    "S5": [B("U12", 1.5, 168), F("K16", 0.2, 24, 96)],
    # Medicine runs from Oripathy to Rhine Lab to Sami.
    "X21": [F("C2", 0.3, 12, 72), F("S9", 0.2, 24, 96)],
    "C25": [B("V12", 1.5, 168), B("L33", 1.3, 168)],
    "S3": [B("C6", 1.3, 72)],
    "L33": [B("U23", 1.3, 168)],
    # Arms: Columbia, Victoria, Kazimierz and Ursus feed each other.
    "C16": [B("Z9", 1.5, 168), B("U14", 1.3, 168)],
    "Z9": [B("C16", 1.3, 168)],
    "V18": [F("U14", 0.3, 24, 96), F("Z18", 0.2, 48, 168), B("L28", 1.5, 168)],
    "L28": [B("C9", 1.3, 168)],
    # Money: panics travel.
    "L9": [F("K15", 0.2, 12, 72), F("V2", 0.3, 6, 48), B("K21", 1.5, 168)],
    "K21": [F("L9", 0.1, 12, 72), B("V5", 1.5, 168)],
    "Z26": [F("K18", 0.2, 12, 72), B("X9", 2.0, 168)],
    "X9": [F("Z12", 0.3, 6, 48), F("K15", 0.2, 12, 72), B("L9", 1.5, 168)],
    "C8": [B("K18", 1.5, 168), B("X9", 1.5, 168)],
    "V15": [B("L9", 1.3, 168)],
    "V13": [B("V15", 0.5, 168)],
    # Logistics.
    "L4": [B("C11", 1.3, 72), B("C22", 1.3, 72)],
    "C11": [F("L21", 0.2, 12, 48), B("Z3", 1.2, 72)],
    "K2": [B("C11", 1.2, 72)],
    # Kazimierz and Kjerag business.
    "K5": [B("Z14", 1.5, 168), B("Z8", 1.5, 168)],
    "Z25": [B("K9", 1.2, 168)],
    "K9": [B("V9", 1.3, 168)],
    # Lungmen's underworld and Siracusa.
    "V11": [F("L18", 0.3, 12, 72)],
    "L22": [B("Z22", 1.3, 168), B("U19", 1.2, 168)],
    "Z22": [B("L19", 1.3, 72)],
    # Energy and mines.
    "X8": [B("U17", 2.0, 336), B("C21", 1.5, 168)],
    "C21": [B("U8", 1.3, 168)],
    "V10": [B("X8", 1.3, 336)],
    # Every loose end tied in.
    "C4": [B("L9", 1.3, 72), B("V2", 1.3, 72)],
    "S1": [B("S12", 1.5, 168), B("S15", 1.5, 168)],
    "S8": [B("S18", 1.5, 168), F("S12", 0.3, 24, 96)],
    "V3": [B("Z25", 1.2, 168), F("V15", 0.2, 24, 96)],
    "L3": [F("L15", 0.3, 6, 24, "true"), F("L2", 0.3, 6, 24, "true")],
    "L5": [B("L21", 2.0, 168), B("L4", 1.5, 168), B("L17", 1.3, 168)],
    "K6": [F("K21", 0.2, 6, 48), F("L9", 0.2, 6, 48), B("X9", 2.0, 168)],
    "S2": [F("S15", 0.3, 24, 96), B("S7", 1.3, 72)],
    "Z2": [F("Z25", 0.4, 12, 72, "true"), F("Z7", 0.3, 12, 48, "false")],
    "Z5": [F("Z22", 0.3, 12, 72), B("Z12", 1.5, 72)],
    "L11": [F("L13", 0.3, 24, 96, "true"), B("L32", 1.3, 72)],
    "C15": [F("C26", 0.4, 24, 120), B("L4", 1.2, 72)],
    "C26": [B("Z1", 1.0, 0), B("V14", 1.2, 168)],
    "U9": [F("U22", 0.4, 24, 96), B("L22", 1.3, 168)],
    "U22": [B("L19", 1.2, 168), B("U16", 1.3, 168)],
    "U16": [F("U10", 0.3, 12, 48), B("C9", 1.2, 168)],
    "Z11": [F("Z24", 0.4, 48, 168), B("C25", 1.3, 168)],
    "V8": [B("V17", 0.5, 168), B("Z3", 0.8, 168)],
    "V17": [F("V8", 0.4, 24, 96), B("X9", 1.5, 168)],
    "C29": [F("C20", 0.4, 6, 48), F("X5", 0.2, 24, 96), B("C8", 2.0, 168)],
    "K14": [B("K20", 1.5, 168), B("K15", 1.2, 168)],
    "S15": [B("S6", 1.5, 168)],
    "S17": [F("S3", 0.3, 24, 96, "false"), B("C6", 1.2, 168)],
    "S18": [F("S8", 0.2, 24, 96), B("K13", 1.2, 168)],
    "X19": [F("L20", 0.3, 12, 48, "true"), F("U19", 0.2, 12, 48, "true"), B("V18", 1.2, 168)],
})
'''
marker = '# Drop placeholder entries that point nowhere.'
src = src.replace(marker, cross + '\n' + marker)
# Factors and affinities go into the generated file too.
src = src.replace("lines.append('## Story lines, for the event table and the tests.')", '''lines.append(FACTOR_CODE)
lines.append('## Story lines, for the event table and the tests.')''')
src = src.replace("open(r'D:\\CSYE 7370\\downfall-godot\\game\\market\\market_links.gd'", "open(r'D:\\CSYE 7370\\downfall-godot\\game\\market\\market_links.gd'")
FACTOR_CODE = r'''
## The world state (态势) that ties every event to every other (用户: 织成网).
## Each event leans on a few factors (affinity), worked out from its region,
## title and the goods it moves, with OVERRIDES where words mislead. Firing
## an event pushes its factors (calming events push them down); every draw
## weighs an event by exp(affinity · tanh(factors)), capped. Factors fade back
## to 0 and push less the higher they already are, so the web cannot run away.
const FACTORS := {
	"lungmen_order": "龙门治安", "reunion": "整合运动", "ursus": "乌萨斯动荡", "kjerag": "谢拉格政局",
	"kazimierz": "卡西米尔紧张", "sami": "北地威胁", "catastrophe": "天灾活跃", "originium": "源石紧张",
	"arms": "军备", "medicine": "医药需求", "logistics": "物流紧张", "panic": "金融恐慌",
}
const FACTOR_HALF_HOURS := 24.0
const FACTOR_RANGE := Vector2(-3.0, 6.0)
## Loose on purpose (用户: 不用过于考虑平衡): manias and panics feed themselves.
const WEIGHT_RANGE := Vector2(0.3, 4.0)
## How hard the world state leans the odds (too high and one crisis locks in).
const LEAN_GAIN := 1.0
const PUSH := {"breaking": 0.35, "rumor": 0.18, "announce": 0.25, "swan": 1.5}
const REGION_FACTOR := {"龙门": ["lungmen_order", 0.5], "炎": ["lungmen_order", 0.3], "乌萨斯": ["ursus", 0.6], "谢拉格": ["kjerag", 0.6],
	"卡西米尔": ["kazimierz", 0.6], "萨米": ["sami", 0.6], "泰拉": ["catastrophe", 0.4]}
const KEYWORDS := [
	[["整合运动", "感染者", "游击队", "起义", "残党"], "reunion", 0.8],  # i18n: skip
	[["天灾", "雪崩", "暴风雪", "寒潮", "寒灾", "火山", "尘暴", "虫群", "结晶"], "catastrophe", 0.7],  # i18n: skip
	[["邪魔", "坍缩", "雪祀", "陷落"], "sami", 0.7],  # i18n: skip
	[["军", "兵", "武装", "装备", "护具"], "arms", 0.6],  # i18n: skip
	[["矿", "源石"], "originium", 0.6],  # i18n: skip
	[["医", "药", "矿石病", "保险", "草药"], "medicine", 0.6],  # i18n: skip
	[["物流", "运力", "商路", "中转站", "港", "铁路", "车队", "航线", "迁徙", "信使"], "logistics", 0.6],  # i18n: skip
	[["停电", "挤兑", "暴跌", "危机", "破裂", "失灵", "封锁", "战争", "汇率", "金券", "赤金", "撤资"], "panic", 0.7],  # i18n: skip
	[["骑士", "监正会", "商业联合会", "锦标赛", "特锦赛", "梅什科", "红松"], "kazimierz", 0.6],  # i18n: skip
	[["鼠王", "贫民窟", "走私", "近卫局", "督察组", "火并", "影卫", "下城区"], "lungmen_order", 0.8],  # i18n: skip
	[["三族", "初雪", "蔓珠院", "喀兰", "雪山大典", "布朗陶", "佩尔罗契", "谢拉格政变"], "kjerag", 0.6],  # i18n: skip
]
## Events that calm their factors down when they fire.
const CALMING := ["解除", "和解", "丰收", "复工", "新线路", "启用", "合作", "协调", "回流", "逐出", "放宽", "突破", "开市"]  # i18n: skip
const CATEGORY_FACTOR := {"originium": "originium", "medical": "medicine", "weapon": "arms", "armor": "arms", "contraband": "lungmen_order"}
const OVERRIDES := {
	"L1": {"panic": 0.2}, "X1": {"catastrophe": 0.6}, "X17": {"catastrophe": 0.6}, "C4": {"panic": 0.5}, "C14": {"panic": 0.5},
	"V16": {"panic": 0.4}, "K19": {"kjerag": 0.4, "panic": -0.3}, "L12": {"logistics": 0.5}, "L26": {"logistics": 0.5},
}

static var _affinity := {}

## {factor: weight} of event `id`.
static func affinity(id: String) -> Dictionary:
	if _affinity.has(id): return _affinity[id]
	var ev: Dictionary = MarketEvents.EVENTS.get(id, {})
	var out := {}
	var add := func(f: String, w: float): out[f] = maxf(float(out.get(f, 0.0)), w)
	var region: Array = REGION_FACTOR.get(str(ev.get("region", "")), [])
	if not region.is_empty(): add.call(region[0], float(region[1]))
	var title := str(ev.get("title", ""))
	for entry in KEYWORDS:
		for word in entry[0]:
			if title.contains(word):
				add.call(entry[1], float(entry[2]))
				break
	for spec in ev.get("effects", []):
		var sel := str(spec.sel)
		var category := sel.get_slice(":", 1) if sel.contains(":") else ""
		if CATEGORY_FACTOR.has(category): add.call(CATEGORY_FACTOR[category], 0.4)
		if sel == "fx" and float(spec.get("jump", 0.0)) > 0.0: add.call("panic", 0.3)
		if spec.has("halt_hours"): add.call("panic", 0.3)
	if float(ev.get("penguin_fee", 1.0)) > 1.0: add.call("logistics", 0.5)
	if str(ev.get("kind", "")) == "swan": add.call("panic", 0.5)
	for f in OVERRIDES.get(id, {}): out[f] = float(OVERRIDES[id][f])
	_affinity[id] = out
	return out

static var _drift := {}

## What the ordinary flow of news pushes each factor by per second, on average
## (base odds, no leaning). The world state counts surprises: this is taken
## off every step, so it sits near 0 until events really cluster.
static func drift(breaking_per_day: float, rumor_per_day: float) -> Dictionary:
	if not _drift.is_empty(): return _drift
	for kind in [["breaking", breaking_per_day], ["rumor", rumor_per_day]]:
		var pool := MarketEvents.of_kind(kind[0])
		var total := 0.0
		for id in pool: total += float(MarketEvents.EVENTS[id].weight)
		for id in pool:
			var share := float(MarketEvents.EVENTS[id].weight) / maxf(total, 1.0)
			var aff := affinity(id)
			for f in aff:
				var per_day := float(kind[1]) * share * float(PUSH[kind[0]]) * float(aff[f]) * push_sign(id) * FOLLOW_SHARE
				_drift[f] = float(_drift.get(f, 0.0)) + per_day / 86400.0
	return _drift

## Follow-ups, announcements and confirmations add about this much on top.
const FOLLOW_SHARE := 1.15

## +1 for events that raise tension, −1 for the calming ones.
static func push_sign(id: String) -> float:
	var title := str(MarketEvents.EVENTS.get(id, {}).get("title", ""))
	for word in CALMING:
		if title.contains(word): return -1.0
	return 1.0
'''
src = src.replace("open(r'D:\\CSYE 7370\\downfall-godot\\game\\market\\market_links.gd', 'w'", "FACTOR_CODE = %r\nopen(r'D:\\CSYE 7370\\downfall-godot\\game\\market\\market_links.gd', 'w'" % FACTOR_CODE, 1) if False else src
exec(compile(src.replace("lines.append(FACTOR_CODE)", "lines.append(%r)" % FACTOR_CODE), 'links', 'exec'))
