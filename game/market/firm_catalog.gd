class_name FirmCatalog
extends RefCounted

## 罗德岛运营与资产管理策划案 v0.12 §3.2.1: the fifteen listed firms, checked
## against the official CN text (handbook_info_table, act13side). Only named
## firms list; the factions do not (企鹅物流 is both). Production numbers are
## mine (§3.8.4, 待校准): revenue a day in 龙门币 at full use, the share of it
## spent on inputs, overheads, R&D, depreciation of capital, payout.

## in / out: category -> share of the input bill / of the output sold onto
## the books. service: what drives a firm that sells no goods.
## dividend: "cash" (its currency), "none", "gold" (实物赤金), or a material family.
## tone: §3.2 growth class at the start (cycle, slow, stable, fast).
const FIRMS := {
	"blacksteel": {"name": "黑钢国际", "region": "哥伦比亚", "cur": "col", "industry": "私人安保、防务承包",
		"in": {"weapon": 0.4, "armor": 0.4, "medical": 0.2}, "out": {}, "service": "defense", "dividend": "cash", "tone": "stable",
		"revenue": 120000.0, "input": 0.35, "sga": 0.18, "rd": 0.05, "capital": 2500000.0, "payout": 0.35, "shares": 1000000.0},
	"raythean": {"name": "雷神工业", "region": "哥伦比亚", "cur": "col", "industry": "军工、作业机器人",
		"in": {"build": 0.5, "electronic": 0.5}, "out": {"weapon": 0.6, "electronic": 0.4}, "dividend": "cash", "tone": "fast",
		"revenue": 160000.0, "input": 0.4, "sga": 0.12, "rd": 0.18, "capital": 3200000.0, "payout": 0.15, "shares": 1200000.0},
	"volvotech": {"name": "沃尔沃特科钦斯基", "region": "哥伦比亚", "cur": "col", "industry": "电控设备",
		"in": {"electronic": 0.6, "build": 0.4}, "out": {"electronic": 1.0}, "dividend": "material:装置", "tone": "stable",  # i18n: skip
		"revenue": 90000.0, "input": 0.45, "sga": 0.14, "rd": 0.08, "capital": 1800000.0, "payout": 0.3, "shares": 800000.0},
	"brian": {"name": "布莱恩创生科技", "region": "哥伦比亚", "cur": "col", "industry": "源石工程研究",
		"in": {"originium": 1.0}, "out": {"elite": 0.6, "electronic": 0.4}, "dividend": "none", "tone": "fast", "volatile": true,
		"revenue": 70000.0, "input": 0.3, "sga": 0.15, "rd": 0.3, "capital": 1400000.0, "payout": 0.0, "shares": 600000.0},
	"mieszko": {"name": "梅什科工业", "region": "卡西米尔", "cur": "kaz", "industry": "重工、移动城市地块、建材",
		"in": {"build": 0.6, "fuel": 0.4}, "out": {"build": 1.0}, "dividend": "material:建材", "tone": "slow",  # i18n: skip
		"revenue": 140000.0, "input": 0.5, "sga": 0.1, "rd": 0.03, "capital": 4000000.0, "payout": 0.4, "shares": 1500000.0, "depreciation": 0.0012},
	"sunherb": {"name": "太阳草制药集团", "region": "卡西米尔", "cur": "kaz", "industry": "制药",
		"in": {"crop": 0.5, "medical": 0.5}, "out": {"medical": 1.0}, "dividend": "material:医疗", "tone": "stable",  # i18n: skip
		"revenue": 100000.0, "input": 0.35, "sga": 0.16, "rd": 0.12, "capital": 2000000.0, "payout": 0.3, "shares": 900000.0},
	"rose": {"name": "玫瑰报业联合集团", "region": "卡西米尔", "cur": "kaz", "industry": "报业、传媒",
		"in": {}, "out": {}, "service": "news", "dividend": "cash", "tone": "slow",
		"revenue": 50000.0, "input": 0.1, "sga": 0.35, "rd": 0.02, "capital": 700000.0, "payout": 0.45, "shares": 500000.0},
	"swire": {"name": "施怀雅集团", "region": "龙门", "cur": "lmd", "industry": "地产、综合财团",
		"in": {"build": 1.0}, "out": {}, "service": "rent", "dividend": "cash", "tone": "slow",
		"revenue": 180000.0, "input": 0.2, "sga": 0.12, "rd": 0.01, "capital": 6000000.0, "payout": 0.6, "shares": 2000000.0},
	"penguin": {"name": "企鹅物流", "region": "龙门", "cur": "lmd", "industry": "物流、代运",
		"in": {"fuel": 1.0}, "out": {}, "service": "freight_penguin", "dividend": "cash", "tone": "stable",
		"revenue": 80000.0, "input": 0.3, "sga": 0.2, "rd": 0.02, "capital": 1200000.0, "payout": 0.3, "shares": 700000.0},
	"fengchi": {"name": "峯驰物流", "region": "龙门", "cur": "lmd", "industry": "物流",
		"in": {"fuel": 1.0}, "out": {}, "service": "freight", "dividend": "cash", "tone": "stable",
		"revenue": 70000.0, "input": 0.32, "sga": 0.18, "rd": 0.01, "capital": 1100000.0, "payout": 0.3, "shares": 650000.0},
	"saluzzo": {"name": "萨卢佐酒业", "region": "叙拉古", "cur": "sir", "industry": "酒业",
		"in": {"crop": 1.0}, "out": {}, "service": "liquor", "dividend": "cash", "tone": "stable",
		"revenue": 60000.0, "input": 0.3, "sga": 0.2, "rd": 0.01, "capital": 900000.0, "payout": 0.4, "shares": 500000.0},
	"venezia": {"name": "威尼斯载具公司", "region": "叙拉古", "cur": "sir", "industry": "载具制造",
		"in": {"build": 0.4, "fuel": 0.3, "electronic": 0.3}, "out": {}, "service": "vehicles", "dividend": "cash", "tone": "cycle",
		"revenue": 110000.0, "input": 0.5, "sga": 0.12, "rd": 0.06, "capital": 2600000.0, "payout": 0.25, "shares": 1000000.0},
	"longitudinal": {"name": "纵贯红土公司", "region": "雷姆必拓", "cur": "gold", "industry": "远程通讯",
		"in": {"electronic": 1.0}, "out": {}, "service": "telecom", "dividend": "cash", "tone": "stable",
		"revenue": 75000.0, "input": 0.25, "sga": 0.18, "rd": 0.08, "capital": 1600000.0, "payout": 0.35, "shares": 600000.0},
	"sunvalley": {"name": "太阳谷工业", "region": "雷姆必拓", "cur": "gold", "industry": "采矿",
		"in": {"fuel": 1.0}, "out": {"originium": 0.6, "build": 0.4}, "dividend": "gold", "tone": "cycle",
		"revenue": 130000.0, "input": 0.4, "sga": 0.1, "rd": 0.02, "capital": 3500000.0, "payout": 0.35, "shares": 1100000.0, "depreciation": 0.001},
	"fastrun": {"name": "跑得快运输公司", "region": "雷姆必拓", "cur": "gold", "industry": "运输",
		"in": {"fuel": 1.0}, "out": {}, "service": "freight", "dividend": "cash", "tone": "slow",
		"revenue": 50000.0, "input": 0.35, "sga": 0.2, "rd": 0.01, "capital": 800000.0, "payout": 0.35, "shares": 450000.0},
}
const ORDER: Array[String] = ["blacksteel", "raythean", "volvotech", "brian", "mieszko", "sunherb", "rose", "swire", "penguin", "fengchi",
	"saluzzo", "venezia", "longitudinal", "sunvalley", "fastrun"]
const TONE_NAMES := {"cycle": "周期反转", "slow": "慢增长", "stable": "稳健", "fast": "快增长"}
## A firm's starting price: about 15× a year's starting earnings a share.
const START_PE := 15.0
## A firm's year, for P/E, yields and returns on capital: 8 reported quarters of
## QUARTER_DAYS (calibrated 2026-11-14). With 365 a share earned 0.003% a day,
## far under a deposit (§3.5 wants dividends at 0.03–0.10% a day); with 56 a
## share at a P/E of 15 earns about 0.12% a day, about what credit costs.
const YEAR_DAYS := 56.0
const DEPRECIATION := 0.0006

static func info(id: String) -> Dictionary:
	return FIRMS.get(id, {})

static func name_of(id: String) -> String:
	return str(FIRMS.get(id, {}).get("name", id))

static func currency(id: String) -> String:
	return str(FIRMS.get(id, {}).get("cur", "lmd"))

## The material a firm pays dividends in, by family (§3.3).
const DIVIDEND_MATERIALS := {"装置": "装置", "建材": "螺栓", "医疗": "医用耗材包"}  # i18n: skip
