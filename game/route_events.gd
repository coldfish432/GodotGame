class_name RouteEvents
extends RefCounted

## 不期而遇 (肉鸽路线图策划案 v0.2 §5): a card with the event's name, one line
## (用户 2026-10-24: 事件卡加台词 — the only narration on any card) and two or
## three choices written as cost → gain. Only one with a fight (`fight`) has a
## map (用户 2026-10-24: 不期而遇无敌人的事件不加载地图); the rest are the card alone. Each choice's `do` is carried out by
## GameManager.event_choose; `bars` are 赤金 at tier 1, scaled by the floor's
## income index. The lines are this game's own, not the original's.

const EVENTS := {
	"broken_device": {"name": "废弃的强化装置", "speaker": "PRTS", "line": "装置仍有残余能量。接入时会有反馈电流，博士。",
		"options": [{"cost": "生命 −25%", "gain": "藏品三选一（中/高）", "do": "hurt_relic"}]},
	"wounded": {"name": "受伤的感染者", "speaker": "感染者", "line": "……别走，求你，我只要一点药。",
		"options": [{"cost": "标准急救剂 ×1", "gain": "%s 关系 +10", "do": "give_potion"}, {"cost": "赤金 −%d", "bars": 2, "gain": "下一层必有踪迹", "do": "pay_trace"}]},
	"wreck": {"name": "补给箱残骸", "speaker": "PRTS", "line": "检测到完整的补给箱。附近有武装人员的热源。", "fight": true,
		"options": [{"cost": "战斗 · 精英 ×3", "gain": "急救剂 ×3", "do": "fight_potions"}]},
	"gambler": {"name": "赌徒", "speaker": "赌徒", "line": "一把定输赢。你敢不敢？",
		"options": [{"cost": "赤金 −%d", "bars": 3, "gain": "50%%：赤金 +%d", "win": 8, "do": "gamble"}]},
	"signal": {"name": "来历不明的信号", "speaker": "PRTS", "line": "信号源在下一层。它可能是诱饵。",
		"options": [{"cost": "下一层威胁值 60% 起", "gain": "下一层藏品箱 +1", "do": "signal"}]},
	"locker": {"name": "封存的装备柜", "speaker": "PRTS", "line": "柜子只接受等价交换。",
		"options": [{"cost": "交出 %s", "gain": "同部位 · 稀有度 +1", "do": "locker"}]},
	"relay": {"name": "PRTS 中继站", "speaker": "PRTS", "line": "中继站可以连回本舰。需要接入吗，博士？",
		"options": [{"cost": "—", "gain": "路线视野 +2", "do": "peek"}, {"cost": "赤金 −%d", "bars": 2, "gain": "撤离点上小地图", "do": "exit_map"}]},
	"smuggler": {"name": "走私者的暗格", "speaker": "走私者", "line": "保单？在这里可不值钱。拿来换点实在的。",
		"options": [{"cost": "取消投保 · %s", "gain": "赤金 +%d", "win": 5, "do": "uninsure"}]},
	"echo": {"name": "旧日回响", "speaker": "？？？", "line": "你丢下的东西，会以别的样子回来。",
		"options": [{"cost": "失去藏品 · %s", "gain": "藏品二选一（高）", "do": "echo"}]},
	"beacon": {"name": "罗德岛补给信标", "speaker": "可露希尔", "line": "博士，付得起运费的话，货马上就到。",
		"options": [{"cost": "赤金 −%d", "bars": 2, "gain": "标准急救剂 ×2", "do": "buy_potions"}, {"cost": "赤金 −%d", "bars": 4, "gain": "下一层改为临时休整", "do": "buy_rest"}]},
	"remnant": {"name": "整合运动的残部", "speaker": "整合运动士兵", "line": "这里是我们的地盘。罗德岛的人，滚出去。", "region": "mine", "fight": true,
		"options": [{"cost": "战斗 · 精英 ×2 + 6", "gain": "整合运动物资", "do": "fight_reunion"}]},
	"surge": {"name": "源石活性异常", "speaker": "PRTS", "line": "周围源石活性急剧上升。敌人同样会受影响。", "region": "mine",
		"options": [{"cost": "污染 +20", "gain": "下一层敌人生命 −30%", "do": "surge"}]},
	"checkpoint": {"name": "近卫局检查站", "speaker": "近卫局警员", "line": "例行检查。证件，或者别的什么。", "region": "city", "fight": true,
		"options": [{"cost": "赤金 −%d", "bars": 3, "gain": "本区段威胁值累计 −30%", "do": "bribe"}, {"cost": "战斗 · 精英 ×1 + 4", "gain": "装备箱", "do": "fight_guard"}]},
	"traveller": {"name": "雪地里的旅人", "speaker": "旅人", "line": "火……分我一点燃料吧，我会记住你的。", "region": "snow",
		"options": [{"cost": "燃料 ×1", "gain": "喀兰贸易 关系 +10 · 自热罐头 ×1", "do": "give_fuel"}]},
	"invitation": {"name": "一封匿名请柬", "speaker": "信使", "line": "家族向您问好。请柬上的酒会，您最好别缺席。", "region": "siracusa",
		"options": [{"cost": "血债 +20", "gain": "家族装备箱", "do": "invitation"}]},
	"witness": {"name": "雨夜目击者", "speaker": "目击者", "line": "我什么都没看见……除非你付钱。", "region": "siracusa",
		"options": [{"cost": "赤金 −%d", "bars": 2, "gain": "下一层灭迹人位置", "do": "witness"}]},
}

## The region's home faction for 受伤的感染者.
const HOME_FACTION := {"mine": "ursus", "city": "lungmen", "snow": "sami", "siracusa": "penguin"}

## Event fights (§5.1): life and attack over the floor's own enemies.
const FIGHT_HP := 1.5
const FIGHT_ATK := 1.3

## The ids that can come up in `region`: the shared ones and its own.
static func pool(region: String) -> Array:
	var out: Array = []
	for id in EVENTS:
		var own := str(EVENTS[id].get("region", ""))
		if own.is_empty() or own == region: out.append(id)
	return out

static func fights(id: String) -> bool:
	return bool(info(id).get("fight", false))

static func info(id: String) -> Dictionary:
	return EVENTS.get(id, {})

## 赤金 at tier 1 scaled to the floor (rounded, at least one).
static func scaled_bars(bars: int, floor_number: int) -> int:
	return maxi(1, roundi(bars * Economy.income_index(Economy.tier_of(floor_number))))
