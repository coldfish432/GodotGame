class_name StrategyCatalog
extends RefCounted

## 罗德岛运营与资产管理策划案 §4.2: the ten templates. No person's name in
## the game (用户 2026-11-13); the homework each comes from is only in the plan.
## unlock: "start", "lv3" (交易所 Lv3), "lv4" (交易所 Lv4 or 科研 量化交易).
## universe: what it trades. params: name -> [default, min, max, step].

const TEMPLATES := {
	"S1": {"name": "成长估值", "unlock": "lv3", "universe": "stocks", "period": "1d",
		"params": {"peg_buy": [1.0, 0.3, 2.0, 0.1], "peg_sell": [2.0, 1.0, 4.0, 0.1]}},
	"S2": {"name": "价值质量聚类", "unlock": "lv4", "universe": "stocks", "period": "1d",
		"params": {"k": [4, 2, 4, 1]}},
	"S3": {"name": "护城河长持", "unlock": "lv3", "universe": "stocks", "period": "1d",
		"params": {"n": [9, 6, 12, 1]}},
	"S4": {"name": "配对回归", "unlock": "lv4", "universe": "pair", "period": "1h",
		"params": {"window": [60, 30, 120, 10], "c": [2.0, 1.0, 3.0, 0.1]}},
	"S5": {"name": "突破追势", "unlock": "lv3", "universe": "any", "period": "1h",
		"params": {"n": [20, 10, 40, 1], "adds": [3, 0, 3, 1]}},
	"S6": {"name": "多周期共振", "unlock": "lv4", "universe": "any", "period": "15m",
		"params": {"rsi_low": [30, 15, 45, 1], "rsi_high": [70, 55, 85, 1]}},
	"S7": {"name": "量价弹簧", "unlock": "lv4", "universe": "any", "period": "1h",
		"params": {"range": [40, 20, 80, 5], "vol": [1.5, 1.0, 3.0, 0.1]}},
	"S8": {"name": "定投", "unlock": "start", "universe": "one", "period": "15m",
		"params": {"hours": [6, 1, 48, 1], "amount": [5000, 1000, 100000, 1000]}},
	"S9": {"name": "网格", "unlock": "lv3", "universe": "one", "period": "15m",
		"params": {"low": [0.9, 0.5, 1.0, 0.01], "high": [1.1, 1.0, 2.0, 0.01], "levels": [10, 4, 30, 1]}},
	"S10": {"name": "套息", "unlock": "start", "universe": "fx", "period": "1h",
		"params": {"stop": [0.03, 0.01, 0.1, 0.005]}},
}
const ORDER: Array[String] = ["S8", "S10", "S1", "S3", "S5", "S9", "S2", "S4", "S6", "S7"]
## §4.1: Lv3 one slot, Lv4 two, 量化交易 one more.
const SLOTS_LV3 := 1
const SLOTS_LV4 := 2
const MAX_SLOTS := 3
## A day of what a strategy holds (§2.5 策略托管费).
const CUSTODY := 0.0005
const FEE := 0.003
const BACKTESTS_A_DAY := 10
const MAX_GROSS := 2.0
const MIN_TRADE := 500.0

## 用户 2026-11-14 "鼠标悬停在策略名称时显示具体介绍": the rule of each (§4.2, no names).
const DESCS := {
	"S1": "增长调整市盈率（PEG）不高于买入 PEG 且净现金为正时买入；PEG 高于卖出 PEG 或企业转为周期反转时卖出。",
	"S2": "每个交易日按价值分 × 质量分把上市企业聚成若干簇，做多均分最高的一簇，做空均分最低的一簇。",
	"S3": "护城河 12 条达标数不低于门槛时买入长持；跌到门槛减 3 以下卖出；每期季报后复查。",
	"S4": "两个标的协整才开仓：价差偏离均值超过偏离阈值进场，回到 0.1σ 以内平仓；连续 3 天不协整自动平仓。",
	"S5": "突破前若干根 K 线的最高价、且在 MA50 和 MA200 之上时买入；跌破前若干根的最低价离场；可分档加仓，止损随之上移。",
	"S6": "日线 EMA15 / EMA200 定方向，1 小时 MACD 定动能，15 分钟 RSI 找回调点；三者同向才进场。",
	"S7": "区间内跌破下沿又收回且放量时买入；放量突破上沿时加仓；回落进区间离场；止损设在弹簧那根 K 线的最低价下方。",
	"S8": "每隔固定小时数买入固定金额。",
	"S9": "在下沿到上沿之间等距挂买卖单，跌了买、涨了卖。",
	"S10": "持有利率高的外币吃利差；汇率不利超过止损就平仓。",
}
const UNIVERSE_NAMES := {"stocks": "全部上市企业", "pair": "两个标的", "any": "任选一个标的", "one": "一个标的", "fx": "外币"}
const UNLOCK_NAMES := {"start": "开局", "lv3": "交易所 Lv3", "lv4": "交易所 Lv4 或 量化交易"}

static func desc(id: String) -> String:
	return str(DESCS.get(id, ""))

## The form's names for the params (用户 2026-11-14: 界面整理); "tpl:key" first.
const PARAM_NAMES := {
	"peg_buy": "买入 PEG", "peg_sell": "卖出 PEG", "k": "聚类数", "S3:n": "护城河门槛", "S5:n": "突破周期",
	"window": "回看根数", "c": "偏离阈值", "adds": "加仓次数", "rsi_low": "RSI 下限", "rsi_high": "RSI 上限",
	"range": "区间根数", "vol": "放量倍数", "hours": "间隔", "amount": "每次金额", "low": "下沿",
	"high": "上沿", "levels": "格数", "stop": "止损",
}
const PARAM_UNITS := {"hours": "小时", "amount": "龙门币", "low": "× 现价", "high": "× 现价", "c": "σ", "vol": "×"}
## Shown and typed as a percent.
const PARAM_PCT := ["stop"]

static func param_name(tpl: String, key: String) -> String:
	return str(PARAM_NAMES.get(tpl + ":" + key, PARAM_NAMES.get(key, key)))

static func param_unit(key: String) -> String:
	return str(PARAM_UNITS.get(key, ""))

static func param_is_pct(key: String) -> bool:
	return key in PARAM_PCT

## The places a step needs: 1 → 0, 0.1 → 1, 0.005 → 3.
static func decimals(step: float) -> int:
	for d in range(0, 5):
		if is_equal_approx(step * pow(10.0, d), roundf(step * pow(10.0, d))): return d
	return 4

static func info(id: String) -> Dictionary:
	return TEMPLATES.get(id, {})

static func name_of(id: String) -> String:
	return str(TEMPLATES.get(id, {}).get("name", id))

static func defaults(id: String) -> Dictionary:
	var out := {}
	var p: Dictionary = info(id).get("params", {})
	for k in p: out[k] = p[k][0]
	return out
