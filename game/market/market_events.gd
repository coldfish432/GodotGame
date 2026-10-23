class_name MarketEvents
extends RefCounted

## The exchange's news (交易所事件表_v1_0.md): 55 events by region, each with
## its PRTS source in the table. Text is what PRTS says; effects are what
## MarketState applies.
##
## kind: "breaking" 突发 / "rumor" 传闻 / "announce" 公告 / "swan" 黑天鹅.
## hours: how long the effect lasts. weight: odds within its kind.
## Effect entries (all optional except sel):
##   sel      "faction:category", "faction:*", "*:category", "fx", "@:*" (the
##            event's region picked at fire time), "@:category"
##   mult     target multiplier; mult_range [a, b] = 1 ± U(a, b), sign random
##   jump     instant move (fraction); jump_range [a, b] signed the same way
##   spread / depth / vol   multipliers while it lasts
##   halt     the market stops buying from the player
##   quota    buy-quota multiplier; fee: added remote fee
##   longterm long-term mean multiplier (stays after the event ends)
## Event-level extras: penguin_fee, penguin_risk, cfd_halt (issuer), threat
## {region, mult}, post_boost (faction), rumors_low (seconds), active_all
## (faction), barter_reroll, relation {faction: delta}.
## `season`: fixed on the real calendar (see SEASONS); they never draw at random.

const KIND_NAMES := {"breaking": "突发", "rumor": "传闻", "announce": "公告", "swan": "黑天鹅"}
const HOUR := 3600.0

const BASE_EVENTS := {
	# --- 龙门 · 炎国 ---------------------------------------------------------------
	"L1": {"region": "龙门", "kind": "announce", "hours": 6, "weight": 3, "title": "龙门商会季度例会",
		"effects": [{"sel": "lungmen:*", "mult_range": [0.05, 0.15]}]},
	"L2": {"region": "龙门", "kind": "breaking", "hours": 4, "weight": 3, "title": "近卫局查缉走私",
		"effects": [{"sel": "rat:*", "spread": 2.0}, {"sel": "rat:contraband", "mult": 1.3}, {"sel": "lungmen:medical", "mult": 1.1}]},
	"L3": {"region": "龙门", "kind": "rumor", "hours": 2, "weight": 4, "title": "传闻：鼠王在收%s", "pick": "rat",
		"effects": [{"sel": "rat:%s", "mult": 1.25}]},
	"L4": {"region": "龙门", "kind": "breaking", "hours": 12, "weight": 2, "title": "企鹅物流运力紧张",
		"penguin_fee": 1.5, "penguin_risk": 0.05, "effects": []},
	"L5": {"region": "龙门", "kind": "announce", "hours": 168, "weight": 0, "title": "新春将近，备货旺季", "season": "spring",
		"penguin_fee": 1.3, "effects": [{"sel": "lungmen:build", "mult": 1.2}, {"sel": "lungmen:medical", "mult": 1.2}, {"sel": "lungmen:electronic", "mult": 1.2}]},
	"L6": {"region": "炎", "kind": "breaking", "hours": 24, "weight": 2, "title": "炎国大宗采购",
		"effects": [{"sel": "lungmen:build", "mult": 1.3}, {"sel": "fx", "jump": -0.03}]},
	"L7": {"region": "炎", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：户部官员贪腐案",
		"effects": [{"sel": "lungmen:*", "mult": 0.9}, {"sel": "fx", "jump": 0.03}]},
	"L8": {"region": "炎", "kind": "breaking", "hours": 48, "weight": 1, "title": "玉门关隘封闭",
		"effects": [{"sel": "lungmen:build", "mult": 1.1}, {"sel": "karlan:*", "spread": 1.3}, {"sel": "rhine:*", "spread": 1.3}]},
	"L9": {"region": "龙门", "kind": "swan", "hours": 72, "weight": 2, "title": "龙门币汇率剧烈波动，龙门方面入市干预",
		"effects": [{"sel": "fx", "jump": 0.25, "vol": 2.0, "mult": 1.12}]},
	"L10": {"region": "龙门", "kind": "swan", "hours": 120, "weight": 1, "title": "整合运动控制的城市正逼近龙门",
		"penguin_fee": 3.0, "effects": [{"sel": "fx", "jump": 0.30, "vol": 1.8}, {"sel": "lungmen:*", "spread": 3.0, "halt_hours": 12}, {"sel": "rat:*", "mult": 1.5}]},
	# --- 哥伦比亚 --------------------------------------------------------------------
	"C1": {"region": "哥伦比亚", "kind": "announce", "hours": 24, "weight": 3, "title": "莱茵生命科技展",
		"effects": [{"sel": "rhine:elite", "mult": 1.25}, {"sel": "rhine:electronic", "mult": 1.25}]},
	"C2": {"region": "哥伦比亚", "kind": "rumor", "hours": 6, "weight": 3, "title": "传闻：莱茵生命矿石病临床试验结果",
		"false_mult": 0.85, "effects": [{"sel": "rhine:originium", "mult": 1.4}, {"sel": "rhine:medical", "mult": 1.2}]},
	"C3": {"region": "哥伦比亚", "kind": "breaking", "hours": 48, "weight": 1, "title": "莱茵生命科室重组",
		"effects": [{"sel": "rhine:*", "vol": 1.8, "spread": 1.5}]},
	"C4": {"region": "哥伦比亚", "kind": "announce", "hours": 24, "weight": 2, "title": "哥伦比亚金券政策会议",
		"effects": [{"sel": "fx", "jump_range": [0.03, 0.08], "link": "c4"}, {"sel": "rhine:*", "mult_range": [0.05, 0.05], "link": "c4"}]},
	"C5": {"region": "哥伦比亚", "kind": "breaking", "hours": 24, "weight": 2, "title": "哥伦比亚拓荒区招募潮",
		"effects": [{"sel": "rhine:electronic", "mult": 1.2}, {"sel": "kazimierz:build", "mult": 1.1}]},
	"C6": {"region": "哥伦比亚", "kind": "breaking", "hours": 48, "weight": 2, "title": "哥伦比亚感染者医疗保险提价",
		"effects": [{"sel": "rhine:medical", "mult": 1.3}, {"sel": "sami:medical", "mult": 1.2}]},
	"C7": {"region": "汐斯塔", "kind": "announce", "hours": 72, "weight": 0, "title": "汐斯塔黑曜石音乐节", "season": "festival",
		"penguin_fee": 1.2, "effects": [{"sel": "kazimierz:build", "mult": 1.15}]},
	"C8": {"region": "哥伦比亚", "kind": "swan", "hours": 168, "weight": 1, "title": "特里蒙科技股暴跌",
		"effects": [{"sel": "rhine:*", "jump": -0.35, "longterm": 0.9, "vol": 1.6}, {"sel": "fx", "jump": 0.05}]},
	# --- 谢拉格 ----------------------------------------------------------------------
	"K1": {"region": "谢拉格", "kind": "announce", "hours": 168, "weight": 0, "title": "谢拉格雪山大典三族会谈", "season": "summit",
		"effects": [{"sel": "karlan:*", "mult_range": [0.10, 0.25]}]},
	"K2": {"region": "谢拉格", "kind": "breaking", "hours": 24, "weight": 2, "title": "图里卡姆关口雪崩",
		"effects": [{"sel": "karlan:cold", "mult": 1.4}, {"sel": "karlan:*", "quota": 0.5}]},
	"K3": {"region": "谢拉格", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：莱茵生命将在谢拉格建研究设施",
		"effects": [{"sel": "karlan:build", "mult": 1.3}, {"sel": "rhine:*", "mult": 1.1}]},
	"K4": {"region": "谢拉格", "kind": "breaking", "hours": 48, "weight": 2, "title": "外国商团启动对谢拉格的投资计划",
		"effects": [{"sel": "karlan:trinket", "mult": 1.2}, {"sel": "karlan:weapon", "mult": 1.2}]},
	"K5": {"region": "谢拉格", "kind": "announce", "hours": 72, "weight": 1, "title": "喀兰贸易与卡西米尔企业签订合作",
		"effects": [{"sel": "karlan:*", "spread": 0.7}, {"sel": "kazimierz:*", "spread": 0.7}]},
	"K6": {"region": "谢拉格", "kind": "swan", "hours": 48, "weight": 1, "title": "喀兰贸易暂停对外结算",
		"cfd_halt": "karlan", "effects": [{"sel": "karlan:*", "halt_hours": 12, "vol": 2.0}, {"sel": "fx", "jump": 0.15}]},
	# --- 乌萨斯 ----------------------------------------------------------------------
	"U1": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 3, "title": "乌萨斯西北集团军调动",
		"effects": [{"sel": "ursus:electronic", "mult": 1.3}, {"sel": "ursus:weapon", "mult": 1.2}, {"sel": "reunion:*", "spread": 1.5}]},
	"U2": {"region": "乌萨斯", "kind": "breaking", "hours": 12, "weight": 3, "title": "游击队洗劫乌萨斯感染者矿场",
		"effects": [{"sel": "ursus:originium", "mult": 1.4}, {"sel": "reunion:originium", "mult": 0.8}]},
	"U3": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 2, "title": "冻原矿场矿工出逃",
		"effects": [{"sel": "ursus:*", "quota": 0.5}, {"sel": "ursus:originium", "mult": 1.2}]},
	"U4": {"region": "乌萨斯", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：乌萨斯主和派推动关闭西北矿场",
		"effects": [{"sel": "ursus:originium", "mult": 1.5}, {"sel": "fx", "jump": 0.02}]},
	"U5": {"region": "乌萨斯", "kind": "breaking", "hours": 48, "weight": 1, "title": "乌萨斯矿区戒严，消息封锁",
		"rumors_low": 48, "effects": [{"sel": "ursus:*", "vol": 2.0, "spread": 2.0}]},
	"U6": {"region": "乌萨斯", "kind": "swan", "hours": 336, "weight": 1, "title": "乌萨斯主矿脉枯竭，远北矿区停产",
		"effects": [{"sel": "ursus:originium", "jump": 0.60, "longterm": 1.2, "vol": 1.6}, {"sel": "rhine:originium", "mult": 1.3}, {"sel": "fx", "jump": 0.06}]},
	"U7": {"region": "乌萨斯", "kind": "swan", "hours": 120, "weight": 1, "title": "整合运动残党在冻原起事",
		"post_boost": "reunion", "effects": [{"sel": "reunion:*", "mult": 0.7}, {"sel": "ursus:*", "halt_hours": 24}, {"sel": "fx", "jump": 0.05}]},
	# --- 萨米 ------------------------------------------------------------------------
	"S1": {"region": "萨米", "kind": "announce", "hours": 72, "weight": 0, "title": "萨米岩角兽迁徙季", "season": "migration",
		"effects": [{"sel": "sami:*", "mult": 0.85}]},
	"S2": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 2, "title": "萨米部族带着族树迁移",
		"barter_reroll": true, "effects": [{"sel": "sami:*", "spread": 1.5}]},
	"S3": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 2, "title": "哥伦比亚医药商队到访萨米",
		"effects": [{"sel": "sami:medical", "mult": 1.3}, {"sel": "rhine:medical", "mult": 0.9}]},
	"S4": {"region": "萨米", "kind": "breaking", "hours": 6, "weight": 1, "title": "萨米林中有外来者被当成盗猎者",
		"relation": {"sami": -5}, "effects": [{"sel": "sami:*", "halt_hours": 6}]},
	"S5": {"region": "萨米", "kind": "swan", "hours": 168, "weight": 1, "title": "北原邪魔南下",
		"threat": {"region": "snow", "mult": 1.3}, "effects": [{"sel": "sami:*", "halt_hours": 72}, {"sel": "*:cold", "mult": 1.5}]},
	# --- 卡西米尔 --------------------------------------------------------------------
	"Z1": {"region": "卡西米尔", "kind": "announce", "hours": 168, "weight": 0, "title": "卡西米尔骑士锦标赛开幕", "season": "tournament",
		"effects": [{"sel": "kazimierz:trinket", "mult": 1.25}, {"sel": "kazimierz:build", "mult": 1.15}, {"sel": "kazimierz:*", "vol": 1.5}]},
	"Z2": {"region": "卡西米尔", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：梅什科竞技证券掀起狂热",
		"effects": [{"sel": "kazimierz:*", "jump": 0.10, "mult": 0.97}]},
	"Z3": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 2, "title": "监正会与商业联合会激烈交锋",
		"effects": [{"sel": "kazimierz:*", "mult_range": [0.08, 0.08], "spread": 1.5}]},
	"Z4": {"region": "卡西米尔", "kind": "breaking", "hours": 48, "weight": 2, "title": "商业联合会加征赛事税",
		"effects": [{"sel": "kazimierz:*", "fee": 0.01}]},
	"Z5": {"region": "卡西米尔", "kind": "breaking", "hours": 12, "weight": 1, "title": "无胄盟追杀反抗体制的骑士",
		"effects": [{"sel": "kazimierz:armor", "mult": 1.2}, {"sel": "rat:weapon", "mult": 1.15}]},
	"Z6": {"region": "卡西米尔", "kind": "swan", "hours": 72, "weight": 1, "title": "特锦赛期间大骑士领大停电",
		"effects": [{"sel": "kazimierz:*", "halt_hours": 12, "jump": -0.20, "vol": 1.8}, {"sel": "fx", "jump": 0.05}]},
	# --- 维多利亚 · 萨尔贡 · 莱塔尼亚（只发新闻） -----------------------------------
	"V1": {"region": "维多利亚", "kind": "announce", "hours": 24, "weight": 2, "title": "伦蒂尼姆军事委员会发布公告",
		"effects": [{"sel": "fx", "jump_range": [0.05, 0.05], "link": "v1"}, {"sel": "karlan:*", "mult_range": [0.05, 0.05], "link": "v1"}]},
	"V2": {"region": "维多利亚", "kind": "breaking", "hours": 24, "weight": 2, "title": "维多利亚镑走弱",
		"effects": [{"sel": "fx", "jump": 0.03}, {"sel": "karlan:trinket", "mult": 1.1}]},
	"V3": {"region": "萨尔贡", "kind": "breaking", "hours": 24, "weight": 1, "title": "大巴扎宝石交易所行情火热",
		"effects": [{"sel": "kazimierz:trinket", "mult": 1.2}, {"sel": "karlan:trinket", "mult": 1.2}]},
	"V4": {"region": "莱塔尼亚", "kind": "breaking", "hours": 24, "weight": 1, "title": "莱塔尼亚杜卡特金币回流",
		"effects": [{"sel": "fx", "jump": -0.04}]},
	# --- 跨区域 ----------------------------------------------------------------------
	"X1": {"region": "泰拉", "kind": "announce", "hours": 72, "weight": 0, "title": "天灾信使月度简报：%s", "season": "bulletin", "pick_region": true,
		"effects": [{"sel": "@:cold", "mult": 1.2}, {"sel": "@:armor", "mult": 1.1}]},
	"X2": {"region": "泰拉", "kind": "breaking", "hours": 48, "weight": 3, "title": "天灾预警：%s", "pick_region": true,
		"penguin_fee": 2.0, "effects": [{"sel": "@:*", "spread": 1.5}, {"sel": "fx", "jump": 0.02}]},
	"X3": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 2, "title": "移动城市停泊：%s", "pick_faction": true,
		"effects": [{"sel": "#:*", "spread": 0.8, "active_all": true}]},
	"X4": {"region": "泰拉", "kind": "breaking", "hours": 48, "weight": 2, "title": "源石引擎能源价格上涨",
		"effects": [{"sel": "*:fuel", "mult": 1.15}, {"sel": "*:originium", "mult": 1.15}]},
	"X5": {"region": "泰拉", "kind": "breaking", "hours": 72, "weight": 2, "title": "矿石病疫情通报",
		"effects": [{"sel": "*:medical", "mult": 1.2}, {"sel": "rhine:originium", "mult": 1.2}]},
	"X6": {"region": "泰拉", "kind": "swan", "hours": 168, "weight": 1, "title": "天灾信使数据造假案曝光",
		"rumors_low": 168, "effects": [{"sel": "*:*", "spread": 1.3}, {"sel": "fx", "vol": 2.0, "jump": 0.04}]},
	"X7": {"region": "泰拉", "kind": "swan", "hours": 240, "weight": 2, "title": "天灾直击：%s", "pick_region": true,
		"effects": [{"sel": "@:*", "halt_hours": 48}, {"sel": "@:cold", "mult": 2.0}, {"sel": "@:armor", "mult": 1.5}, {"sel": "fx", "jump": 0.20}]},
	"X8": {"region": "泰拉", "kind": "swan", "hours": 336, "weight": 1, "title": "大型源石矿脉被发现",
		"effects": [{"sel": "*:originium", "jump": -0.40, "longterm": 0.85}, {"sel": "fx", "jump": -0.05}]},
	"X9": {"region": "泰拉", "kind": "swan", "hours": 168, "weight": 1, "title": "大商会周转失灵：%s", "pick_issuer": true,
		"effects": [{"sel": "#:*", "quota": 0.5, "vol": 1.5}, {"sel": "fx", "jump": 0.05}]},
}

## 事件表 v1.1 (用户 2026-10-16: 增加事件数量): 47 more, same rules. Sources
## (P / P² / 原) are in 交易所事件表_v1_3.md §11.
const MORE_EVENTS := {
	# --- 龙门 · 炎国 ---------------------------------------------------------------
	"L11": {"region": "龙门", "kind": "rumor", "hours": 6, "weight": 2, "title": "传闻：鲤氏侦探事务所查到商业间谍",
		"effects": [{"sel": "lungmen:*", "spread": 1.3, "mult": 0.97}]},
	"L12": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 2, "title": "峯驰物流压价争抢信使业务",
		"penguin_fee": 0.8, "effects": [{"sel": "lungmen:electronic", "mult": 1.05}]},
	"L13": {"region": "龙门", "kind": "announce", "hours": 12, "weight": 2, "title": "龙门商会改选理事席位",
		"effects": [{"sel": "lungmen:*", "mult_range": [0.04, 0.10], "vol": 1.3}]},
	"L14": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 2, "title": "诗怀雅家族企业扩建城区",
		"effects": [{"sel": "lungmen:build", "mult": 1.15}, {"sel": "lungmen:electronic", "mult": 1.1}]},
	"L15": {"region": "龙门", "kind": "breaking", "hours": 8, "weight": 2, "title": "近卫局清查贫民窟",
		"effects": [{"sel": "rat:*", "spread": 2.0, "halt_hours": 4}, {"sel": "rat:contraband", "mult": 1.25}]},
	"L16": {"region": "炎", "kind": "rumor", "hours": 12, "weight": 1, "title": "传闻：司岁台观测到岁兽异象",
		"effects": [{"sel": "fx", "jump": 0.03}, {"sel": "lungmen:*", "mult": 0.95}]},
	"L17": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 2, "title": "龙门中心医院扩大采购",
		"effects": [{"sel": "lungmen:medical", "mult": 1.25}]},
	"L18": {"region": "龙门", "kind": "breaking", "hours": 12, "weight": 2, "title": "叙拉古家族在龙门街头火并",
		"effects": [{"sel": "rat:weapon", "mult": 1.2}, {"sel": "lungmen:armor", "mult": 1.1}]},
	# --- 哥伦比亚 --------------------------------------------------------------------
	"C9": {"region": "哥伦比亚", "kind": "breaking", "hours": 24, "weight": 2, "title": "雷神工业拿下军工大单",
		"effects": [{"sel": "rhine:electronic", "mult": 1.15}, {"sel": "kazimierz:weapon", "mult": 1.1}]},
	"C10": {"region": "哥伦比亚", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：军方项目从莱茵生命转给特里蒙理工",
		"effects": [{"sel": "rhine:*", "mult": 0.92}]},
	"C11": {"region": "哥伦比亚", "kind": "breaking", "hours": 24, "weight": 2, "title": "哥伦比亚通往卡西米尔的商路拥堵",
		"effects": [{"sel": "kazimierz:*", "spread": 1.4}, {"sel": "rhine:*", "spread": 1.3}, {"sel": "kazimierz:build", "mult": 1.1}]},
	"C12": {"region": "汐斯塔", "kind": "breaking", "hours": 48, "weight": 1, "title": "汐斯塔重申黑曜石禁采令",
		"effects": [{"sel": "rhine:originium", "mult": 1.1}]},
	"C13": {"region": "哥伦比亚", "kind": "announce", "hours": 48, "weight": 2, "title": "莱茵生命生态科野外考察招标",
		"effects": [{"sel": "rhine:cold", "mult": 1.3}, {"sel": "sami:medical", "mult": 1.1}]},
	"C14": {"region": "哥伦比亚", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：哥伦比亚金券将收紧",
		"effects": [{"sel": "fx", "jump": -0.03}, {"sel": "rhine:*", "mult": 0.96}]},
	"C15": {"region": "哥伦比亚", "kind": "breaking", "hours": 48, "weight": 1, "title": "塞壬唱片开启巡演",
		"penguin_fee": 1.2, "effects": [{"sel": "kazimierz:build", "mult": 1.1}, {"sel": "lungmen:build", "mult": 1.1}]},
	# --- 谢拉格 ----------------------------------------------------------------------
	"K7": {"region": "谢拉格", "kind": "breaking", "hours": 24, "weight": 2, "title": "圣山禁区雪崩，谢拉格封山",
		"effects": [{"sel": "karlan:cold", "mult": 1.3}, {"sel": "karlan:*", "quota": 0.6}]},
	"K8": {"region": "谢拉格", "kind": "announce", "hours": 48, "weight": 1, "title": "喀兰贸易图里卡姆新仓储启用",
		"effects": [{"sel": "karlan:*", "spread": 0.8, "depth": 1.3}]},
	"K9": {"region": "谢拉格", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：喀兰贸易与维多利亚贵族续签投资",
		"effects": [{"sel": "karlan:*", "mult": 1.1}, {"sel": "fx", "jump": 0.01}]},
	"K10": {"region": "谢拉格", "kind": "breaking", "hours": 72, "weight": 1, "title": "图里卡姆旅游旺季",
		"effects": [{"sel": "karlan:cold", "mult": 1.15}, {"sel": "karlan:trinket", "mult": 1.1}]},
	"K11": {"region": "谢拉格", "kind": "breaking", "hours": 24, "weight": 1, "title": "三族议会争论对外开放",
		"effects": [{"sel": "karlan:*", "vol": 1.5, "mult_range": [0.03, 0.08]}]},
	# --- 乌萨斯 ----------------------------------------------------------------------
	"U8": {"region": "乌萨斯", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：乌萨斯贵族收紧矿务",
		"effects": [{"sel": "ursus:originium", "mult": 1.2}, {"sel": "reunion:originium", "mult": 1.1}]},
	"U9": {"region": "乌萨斯", "kind": "announce", "hours": 24, "weight": 2, "title": "切尔诺伯格残骸回收拍卖",
		"effects": [{"sel": "ursus:electronic", "mult": 0.85}, {"sel": "rat:electronic", "mult": 0.9}]},
	"U10": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 2, "title": "乌萨斯西北集团军拖欠军需款",
		"effects": [{"sel": "ursus:*", "quota": 0.5, "spread": 1.5}]},
	"U11": {"region": "乌萨斯", "kind": "breaking", "hours": 48, "weight": 1, "title": "乌萨斯矿区解除戒严",
		"effects": [{"sel": "ursus:*", "vol": 0.7, "spread": 0.8, "mult": 1.03}]},
	"U12": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 2, "title": "冻原暴风雪阻断补给线",
		"effects": [{"sel": "ursus:fuel", "mult": 1.4}, {"sel": "reunion:medical", "mult": 1.2}, {"sel": "reunion:fuel", "mult": 1.2}]},
	"U13": {"region": "乌萨斯", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：感染者矿工酝酿起义",
		"effects": [{"sel": "ursus:originium", "mult": 1.3}, {"sel": "reunion:*", "mult": 0.9}]},
	# --- 萨米 ------------------------------------------------------------------------
	"S6": {"region": "萨米", "kind": "announce", "hours": 24, "weight": 1, "title": "雪祀主持冬季祭典",
		"effects": [{"sel": "sami:fuel", "mult": 1.3}, {"sel": "sami:*", "halt_hours": 6}]},
	"S7": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 2, "title": "乌萨斯人越境伐木",
		"effects": [{"sel": "sami:*", "spread": 1.5}, {"sel": "*:cold", "mult": 1.1}]},
	"S8": {"region": "萨米", "kind": "breaking", "hours": 48, "weight": 2, "title": "萨米林地人猎季丰收",
		"effects": [{"sel": "sami:*", "mult": 0.85}]},
	"S9": {"region": "萨米", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：沼地人带来稀有草药",
		"effects": [{"sel": "sami:medical", "mult": 0.9}, {"sel": "rhine:medical", "mult": 1.05}]},
	"S10": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 1, "title": "盗猎者被逐出萨米林地",
		"effects": [{"sel": "sami:*", "spread": 0.8}]},
	# --- 卡西米尔 --------------------------------------------------------------------
	"Z7": {"region": "卡西米尔", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：玫瑰报业要爆赛事丑闻",
		"effects": [{"sel": "kazimierz:trinket", "mult": 0.85}, {"sel": "kazimierz:*", "vol": 1.3}]},
	"Z8": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 2, "title": "艾伦精选科技追加无人机赞助",
		"effects": [{"sel": "kazimierz:electronic", "mult": 1.2}]},
	"Z9": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 2, "title": "辉煌盾工业接下载具订单",
		"effects": [{"sel": "kazimierz:armor", "mult": 1.2}, {"sel": "kazimierz:build", "mult": 1.1}]},
	"Z10": {"region": "卡西米尔", "kind": "announce", "hours": 12, "weight": 2, "title": "红松叶彩券开奖",
		"effects": [{"sel": "kazimierz:*", "vol": 1.4, "mult_range": [0.03, 0.06]}]},
	"Z11": {"region": "卡西米尔", "kind": "breaking", "hours": 48, "weight": 1, "title": "感染者骑士参赛新规出台",
		"effects": [{"sel": "kazimierz:armor", "mult": 1.1}, {"sel": "rhine:medical", "mult": 1.05}]},
	"Z12": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 1, "title": "骑士协会抗议竞技商业化",
		"effects": [{"sel": "kazimierz:*", "spread": 1.4, "mult": 0.95}]},
	# --- 维多利亚 · 萨尔贡 · 拉特兰（只发新闻） ---------------------------------------
	"V5": {"region": "维多利亚", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：伦蒂尼姆大公爵会谈破裂",
		"effects": [{"sel": "fx", "jump": 0.03}, {"sel": "karlan:*", "mult": 0.96}]},
	"V6": {"region": "维多利亚", "kind": "breaking", "hours": 48, "weight": 1, "title": "维多利亚皇家兵工厂扩产",
		"effects": [{"sel": "karlan:weapon", "mult": 1.1}, {"sel": "kazimierz:weapon", "mult": 1.1}]},
	"V7": {"region": "萨尔贡", "kind": "rumor", "hours": 12, "weight": 1, "title": "传闻：萨尔贡金币成色引发争议",
		"effects": [{"sel": "fx", "jump": 0.02}]},
	"V8": {"region": "拉特兰", "kind": "announce", "hours": 24, "weight": 1, "title": "拉特兰中庭公证所发布商事仲裁",
		"effects": [{"sel": "kazimierz:*", "spread": 0.8}, {"sel": "karlan:*", "spread": 0.9}]},
	# --- 跨区域 ----------------------------------------------------------------------
	"X10": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 2, "title": "源石尘暴过境：%s", "pick_region": true,
		"effects": [{"sel": "@:medical", "mult": 1.15}, {"sel": "@:cold", "mult": 1.1}]},
	"X11": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 2, "title": "移动城市引擎故障：%s", "pick_faction": true,
		"effects": [{"sel": "#:*", "quota": 0.5, "spread": 1.3}, {"sel": "#:electronic", "mult": 1.2}]},
	"X12": {"region": "泰拉", "kind": "rumor", "hours": 12, "weight": 1, "title": "传闻：天灾信使联合会酝酿罢工",
		"effects": [{"sel": "fx", "jump": 0.02}, {"sel": "*:*", "spread": 1.1}]},
	"X13": {"region": "泰拉", "kind": "announce", "hours": 48, "weight": 2, "title": "各国协议限产至纯源石",
		"effects": [{"sel": "*:originium", "mult": 1.15}, {"sel": "*:fuel", "mult": 1.1}]},
	"X14": {"region": "泰拉", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：矿石病缓解药物研发突破",
		"effects": [{"sel": "rhine:medical", "mult": 1.3}, {"sel": "*:medical", "mult": 0.95}]},
	"X15": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 2, "title": "源石虫群过境：%s", "pick_region": true,
		"effects": [{"sel": "@:fuel", "mult": 1.2}, {"sel": "@:build", "mult": 1.1}]},
}

## Regions events can pick ("天灾预警：%s"): faction region → factions there.
## 事件表 v1.2 (用户 2026-10-16: 总量加到 200 个): 98 more. Sources in
## 交易所事件表_v1_3.md §12.
const EXTRA_EVENTS := {
	"L19": {"region": "龙门", "kind": "breaking", "hours": 12, "weight": 2, "title": "特别督察组突袭军械走私窝点", "effects": [{"sel": "rat:weapon", "mult": 1.3}, {"sel": "rat:*", "spread": 1.5}]},
	"L20": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 2, "title": "龙门外环剿灭行动", "effects": [{"sel": "lungmen:armor", "mult": 1.15}, {"sel": "lungmen:medical", "mult": 1.1}]},
	"L21": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 2, "title": "中转站货运积压", "penguin_fee": 1.3, "effects": [{"sel": "lungmen:*", "spread": 1.3}, {"sel": "lungmen:build", "mult": 0.9}]},
	"L22": {"region": "龙门", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：军械库东的旧仓库将拍卖", "effects": [{"sel": "lungmen:weapon", "mult": 0.85}, {"sel": "rat:weapon", "mult": 0.9}]},
	"L23": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 1, "title": "新街重建招标", "effects": [{"sel": "lungmen:build", "mult": 1.2}]},
	"L24": {"region": "龙门", "kind": "breaking", "hours": 12, "weight": 1, "title": "龙门消防署更换装备", "effects": [{"sel": "lungmen:armor", "mult": 1.1}, {"sel": "lungmen:fuel", "mult": 0.95}]},
	"L25": {"region": "龙门", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：影卫在下城区活动", "effects": [{"sel": "rat:*", "mult": 0.92, "spread": 1.4}]},
	"L26": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 1, "title": "陆龟特快开通新线路", "penguin_fee": 0.85, "effects": [{"sel": "lungmen:*", "spread": 0.9}]},
	"L27": {"region": "炎", "kind": "announce", "hours": 24, "weight": 2, "title": "炎国工部公布驰道维护预算", "effects": [{"sel": "lungmen:build", "mult_range": [0.05, 0.12]}, {"sel": "lungmen:fuel", "mult": 1.05}]},
	"L28": {"region": "炎", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：炎国兵部大批采购", "effects": [{"sel": "lungmen:weapon", "mult": 1.2}, {"sel": "lungmen:armor", "mult": 1.15}]},
	"L29": {"region": "炎", "kind": "breaking", "hours": 48, "weight": 1, "title": "玉门加强边塞防务", "effects": [{"sel": "lungmen:weapon", "mult": 1.1}]},
	"L30": {"region": "龙门", "kind": "breaking", "hours": 12, "weight": 2, "title": "企鹅物流护送任务失手", "penguin_risk": 0.06, "effects": [{"sel": "lungmen:build", "mult": 0.95}]},
	"L31": {"region": "龙门", "kind": "announce", "hours": 24, "weight": 1, "title": "龙门执政者发表施政报告", "effects": [{"sel": "lungmen:*", "mult_range": [0.03, 0.08]}, {"sel": "fx", "jump_range": [0.01, 0.03]}]},
	"L32": {"region": "龙门", "kind": "rumor", "hours": 6, "weight": 2, "title": "传闻：鼠王与近卫局私下和解", "effects": [{"sel": "rat:*", "spread": 0.7}, {"sel": "rat:contraband", "mult": 0.9}]},
	"L33": {"region": "龙门", "kind": "breaking", "hours": 24, "weight": 1, "title": "龙门感染者纠察队扩编", "effects": [{"sel": "lungmen:medical", "mult": 1.15}, {"sel": "rat:medical", "mult": 1.2}]},
	"L34": {"region": "龙门", "kind": "swan", "hours": 96, "weight": 1, "title": "龙门核心城区大停电", "effects": [{"sel": "lungmen:*", "halt_hours": 12, "jump": -0.15, "vol": 1.8}, {"sel": "rat:*", "mult": 1.3}, {"sel": "fx", "jump": 0.12}]},
	"C16": {"region": "哥伦比亚", "kind": "breaking", "hours": 24, "weight": 2, "title": "联合军工追加防务合同", "effects": [{"sel": "rhine:electronic", "mult": 1.1}, {"sel": "kazimierz:armor", "mult": 1.1}]},
	"C17": {"region": "哥伦比亚", "kind": "announce", "hours": 24, "weight": 2, "title": "莱茵生命防卫科装备发布", "effects": [{"sel": "rhine:elite", "mult": 1.15}, {"sel": "rhine:electronic", "mult": 1.1}]},
	"C18": {"region": "哥伦比亚", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：莱茵生命工程科新型源石引擎", "effects": [{"sel": "rhine:originium", "mult": 1.2}, {"sel": "*:fuel", "mult": 0.95}]},
	"C19": {"region": "哥伦比亚", "kind": "breaking", "hours": 48, "weight": 2, "title": "拓荒者合同大批到期", "effects": [{"sel": "rhine:medical", "mult": 0.9}, {"sel": "kazimierz:build", "mult": 0.95}]},
	"C20": {"region": "哥伦比亚", "kind": "breaking", "hours": 24, "weight": 1, "title": "特里蒙移动城市变更航线", "effects": [{"sel": "rhine:*", "spread": 1.3}, {"sel": "rhine:cold", "mult": 1.1}]},
	"C21": {"region": "哥伦比亚", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：企业主游说放宽源石进口", "effects": [{"sel": "rhine:originium", "mult": 0.85}, {"sel": "ursus:originium", "mult": 1.1}]},
	"C22": {"region": "玻利瓦尔", "kind": "breaking", "hours": 24, "weight": 2, "title": "玻利瓦尔商路受阻", "effects": [{"sel": "rhine:*", "spread": 1.2}, {"sel": "kazimierz:build", "mult": 1.1}]},
	"C23": {"region": "汐斯塔", "kind": "breaking", "hours": 48, "weight": 1, "title": "汐斯塔火山活动加剧", "effects": [{"sel": "rhine:originium", "mult": 1.1}, {"sel": "*:cold", "mult": 1.05}]},
	"C24": {"region": "汐斯塔", "kind": "rumor", "hours": 12, "weight": 1, "title": "传闻：汐斯塔天灾信使复查数据", "rumors_low": 6, "effects": [{"sel": "fx", "jump": 0.01}]},
	"C25": {"region": "哥伦比亚", "kind": "announce", "hours": 24, "weight": 1, "title": "哥伦比亚国会审议感染者法案", "effects": [{"sel": "rhine:medical", "mult_range": [0.08, 0.15]}]},
	"C26": {"region": "哥伦比亚", "kind": "breaking", "hours": 24, "weight": 1, "title": "塞壬唱片新专辑热卖", "effects": [{"sel": "kazimierz:build", "mult": 1.05}, {"sel": "lungmen:trinket", "mult": 1.1}]},
	"C27": {"region": "哥伦比亚", "kind": "breaking", "hours": 12, "weight": 2, "title": "莱茵生命生态科样本告急", "effects": [{"sel": "rhine:cold", "mult": 1.25}, {"sel": "rhine:medical", "mult": 1.1}]},
	"C28": {"region": "哥伦比亚", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：卡兹戴尔医疗康采恩低价抢单", "effects": [{"sel": "rhine:medical", "mult": 0.88}]},
	"C29": {"region": "哥伦比亚", "kind": "swan", "hours": 168, "weight": 1, "title": "特里蒙港区大火", "effects": [{"sel": "rhine:*", "halt_hours": 24, "jump": -0.2}, {"sel": "*:medical", "mult": 1.3}, {"sel": "fx", "jump": 0.08}]},
	"K12": {"region": "谢拉格", "kind": "breaking", "hours": 24, "weight": 2, "title": "布朗陶家族要求重议关税", "effects": [{"sel": "karlan:*", "mult": 0.95, "spread": 1.3}]},
	"K13": {"region": "谢拉格", "kind": "breaking", "hours": 24, "weight": 2, "title": "佩尔罗契家族扩大牧场出口", "effects": [{"sel": "karlan:cold", "mult": 0.85}, {"sel": "karlan:cold", "mult": 1.05}]},
	"K14": {"region": "谢拉格", "kind": "announce", "hours": 24, "weight": 1, "title": "蔓珠院举行祈福仪式", "effects": [{"sel": "karlan:*", "halt_hours": 4}, {"sel": "karlan:trinket", "mult": 1.1}]},
	"K15": {"region": "谢拉格", "kind": "rumor", "hours": 24, "weight": 2, "title": "传闻：初雪呼吁限制外资", "effects": [{"sel": "karlan:*", "mult": 0.92}, {"sel": "fx", "jump": 0.01}]},
	"K16": {"region": "谢拉格", "kind": "breaking", "hours": 48, "weight": 1, "title": "谢拉格雪地车队断粮", "effects": [{"sel": "karlan:fuel", "mult": 1.3}, {"sel": "karlan:cold", "mult": 1.2}]},
	"K17": {"region": "谢拉格", "kind": "breaking", "hours": 24, "weight": 2, "title": "喀兰贸易军工产线投产", "effects": [{"sel": "karlan:weapon", "mult": 0.9}, {"sel": "karlan:armor", "mult": 0.9}]},
	"K18": {"region": "谢拉格", "kind": "rumor", "hours": 12, "weight": 1, "title": "传闻：雷姆必拓商人撤资", "effects": [{"sel": "karlan:*", "mult": 0.93}]},
	"K19": {"region": "谢拉格", "kind": "announce", "hours": 48, "weight": 1, "title": "新经济政策第二期", "effects": [{"sel": "karlan:*", "mult_range": [0.05, 0.12], "depth": 1.2}]},
	"K20": {"region": "谢拉格", "kind": "breaking", "hours": 24, "weight": 1, "title": "耶拉冈德祭日封闭圣山", "effects": [{"sel": "karlan:cold", "mult": 1.15}, {"sel": "karlan:*", "quota": 0.7}]},
	"K21": {"region": "谢拉格", "kind": "swan", "hours": 120, "weight": 1, "title": "谢拉格政变传闻引发挤兑", "cfd_halt": "karlan", "effects": [{"sel": "karlan:*", "jump": -0.25, "vol": 2.0}, {"sel": "fx", "jump": 0.1}]},
	"U14": {"region": "乌萨斯", "kind": "breaking", "hours": 48, "weight": 2, "title": "圣骏堡追加军工拨款", "effects": [{"sel": "ursus:weapon", "mult": 1.2}, {"sel": "ursus:electronic", "mult": 1.15}]},
	"U15": {"region": "乌萨斯", "kind": "announce", "hours": 24, "weight": 2, "title": "乌萨斯议会财政听证", "effects": [{"sel": "ursus:*", "mult_range": [0.05, 0.12]}, {"sel": "fx", "jump_range": [0.01, 0.02]}]},
	"U16": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 2, "title": "冻原金属加工厂停工", "effects": [{"sel": "ursus:build", "mult": 1.25}, {"sel": "ursus:elite", "mult": 1.15}]},
	"U17": {"region": "乌萨斯", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：布列斯克远北矿区复工", "effects": [{"sel": "ursus:originium", "mult": 0.85}]},
	"U18": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 1, "title": "乌萨斯集团军换防", "effects": [{"sel": "ursus:*", "spread": 1.3}, {"sel": "reunion:*", "spread": 0.8}]},
	"U19": {"region": "乌萨斯", "kind": "breaking", "hours": 12, "weight": 2, "title": "整合运动残党袭击运输车队", "effects": [{"sel": "ursus:fuel", "mult": 1.2}, {"sel": "reunion:weapon", "mult": 0.85}]},
	"U20": {"region": "乌萨斯", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：皇帝费奥多尔签署关闭矿场令", "effects": [{"sel": "ursus:originium", "mult": 1.4}, {"sel": "reunion:originium", "mult": 1.2}]},
	"U21": {"region": "乌萨斯", "kind": "breaking", "hours": 48, "weight": 2, "title": "乌萨斯冻原寒潮", "effects": [{"sel": "ursus:fuel", "mult": 1.3}, {"sel": "*:cold", "mult": 1.1}]},
	"U22": {"region": "乌萨斯", "kind": "announce", "hours": 24, "weight": 1, "title": "切尔诺伯格残余设施拍卖", "effects": [{"sel": "ursus:build", "mult": 0.85}, {"sel": "rat:electronic", "mult": 0.9}]},
	"U23": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 1, "title": "乌萨斯感染者劳役名单扩大", "effects": [{"sel": "ursus:originium", "mult": 0.9}, {"sel": "reunion:medical", "mult": 1.25}]},
	"U24": {"region": "乌萨斯", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：贵族联合抵制主和派", "effects": [{"sel": "ursus:*", "vol": 1.4}, {"sel": "fx", "jump": 0.015}]},
	"U25": {"region": "乌萨斯", "kind": "breaking", "hours": 24, "weight": 1, "title": "乌萨斯铁路线遭雪崩阻断", "effects": [{"sel": "ursus:*", "quota": 0.5}, {"sel": "ursus:fuel", "mult": 1.15}]},
	"U26": {"region": "乌萨斯", "kind": "breaking", "hours": 12, "weight": 2, "title": "矿场监工冲突导致停产", "effects": [{"sel": "ursus:originium", "mult": 1.2}, {"sel": "reunion:originium", "mult": 1.1}]},
	"U27": {"region": "乌萨斯", "kind": "swan", "hours": 168, "weight": 1, "title": "乌萨斯对外全面封锁边境", "effects": [{"sel": "ursus:*", "halt_hours": 48, "jump": 0.3}, {"sel": "reunion:*", "mult": 1.4}, {"sel": "fx", "jump": 0.08}]},
	"S11": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 2, "title": "山地人封锁通往林地的山口", "effects": [{"sel": "sami:*", "spread": 1.5}, {"sel": "sami:fuel", "mult": 1.15}]},
	"S12": {"region": "萨米", "kind": "announce", "hours": 24, "weight": 2, "title": "低地市集开市", "effects": [{"sel": "sami:*", "spread": 0.7, "depth": 1.5}]},
	"S13": {"region": "萨米", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：陷落雪祀出现在林线", "threat": {"region": "snow", "mult": 1.15}, "effects": [{"sel": "sami:*", "mult": 0.9}, {"sel": "*:cold", "mult": 1.1}]},
	"S14": {"region": "萨米", "kind": "breaking", "hours": 48, "weight": 2, "title": "萨米寒灾", "effects": [{"sel": "sami:fuel", "mult": 1.4}, {"sel": "sami:medical", "mult": 1.2}]},
	"S15": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 1, "title": "族树开花，部族庆典", "effects": [{"sel": "sami:fuel", "mult": 1.2}, {"sel": "sami:*", "halt_hours": 4}]},
	"S16": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 2, "title": "乌萨斯军队在萨米边境集结", "effects": [{"sel": "sami:*", "spread": 1.4}, {"sel": "ursus:weapon", "mult": 1.1}]},
	"S17": {"region": "萨米", "kind": "rumor", "hours": 12, "weight": 1, "title": "传闻：哥伦比亚医药商队改道", "effects": [{"sel": "sami:medical", "mult": 0.85}, {"sel": "rhine:medical", "mult": 1.08}]},
	"S18": {"region": "萨米", "kind": "breaking", "hours": 24, "weight": 1, "title": "萨米猎人营地缺少帆布", "effects": [{"sel": "sami:build", "mult": 1.3}]},
	"S19": {"region": "萨米", "kind": "announce", "hours": 24, "weight": 1, "title": "雪祀召集各部族议事", "effects": [{"sel": "sami:*", "mult_range": [0.05, 0.12]}]},
	"S20": {"region": "萨米", "kind": "swan", "hours": 168, "weight": 1, "title": "坍缩侵入林线", "threat": {"region": "snow", "mult": 1.5}, "effects": [{"sel": "sami:*", "halt_hours": 96}, {"sel": "*:cold", "mult": 1.4}, {"sel": "fx", "jump": 0.03}]},
	"Z13": {"region": "卡西米尔", "kind": "announce", "hours": 24, "weight": 2, "title": "卡西米尔国民院预算辩论", "effects": [{"sel": "kazimierz:*", "mult_range": [0.04, 0.1]}]},
	"Z14": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 2, "title": "梅什科集团承建新赛场", "effects": [{"sel": "kazimierz:build", "mult": 1.25}, {"sel": "kazimierz:electronic", "mult": 1.1}]},
	"Z15": {"region": "卡西米尔", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：明星骑士转会", "effects": [{"sel": "kazimierz:trinket", "mult": 1.15}, {"sel": "kazimierz:*", "vol": 1.3}]},
	"Z16": {"region": "卡西米尔", "kind": "breaking", "hours": 12, "weight": 2, "title": "大嘴莫布直播口误引发抵制", "effects": [{"sel": "kazimierz:build", "mult": 0.9}]},
	"Z17": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 1, "title": "零号地块传闻曝光", "effects": [{"sel": "kazimierz:*", "spread": 1.3, "mult": 0.96}]},
	"Z18": {"region": "卡西米尔", "kind": "announce", "hours": 48, "weight": 1, "title": "骑士竞技资格赛开幕", "effects": [{"sel": "kazimierz:weapon", "mult": 1.15}, {"sel": "kazimierz:armor", "mult": 1.15}]},
	"Z19": {"region": "卡西米尔", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：商业联合会发言人换人", "effects": [{"sel": "kazimierz:*", "vol": 1.5}]},
	"Z20": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 2, "title": "监正会裁定一批骑士违规", "effects": [{"sel": "kazimierz:weapon", "mult": 0.9}, {"sel": "kazimierz:trinket", "mult": 0.95}]},
	"Z21": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 1, "title": "四城联合安保升级", "effects": [{"sel": "kazimierz:armor", "mult": 1.2}]},
	"Z22": {"region": "卡西米尔", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：红松骑士团再度现身", "effects": [{"sel": "kazimierz:*", "spread": 1.4}, {"sel": "rat:weapon", "mult": 1.1}]},
	"Z23": {"region": "卡西米尔", "kind": "breaking", "hours": 24, "weight": 1, "title": "辉煌盾工业召回一批护具", "effects": [{"sel": "kazimierz:armor", "mult": 0.85}]},
	"Z24": {"region": "卡西米尔", "kind": "breaking", "hours": 48, "weight": 1, "title": "感染者骑士获准参赛人数上调", "effects": [{"sel": "kazimierz:*", "mult": 1.04}, {"sel": "rhine:medical", "mult": 1.05}]},
	"Z25": {"region": "卡西米尔", "kind": "announce", "hours": 24, "weight": 2, "title": "梅什科竞技证券季度分红", "effects": [{"sel": "kazimierz:*", "mult_range": [0.03, 0.08], "vol": 1.2}]},
	"Z26": {"region": "卡西米尔", "kind": "swan", "hours": 120, "weight": 1, "title": "商业联合会与监正会公开决裂", "cfd_halt": "kazimierz", "effects": [{"sel": "kazimierz:*", "jump": -0.25, "vol": 2.0, "halt_hours": 12}, {"sel": "fx", "jump": 0.06}]},
	"V9": {"region": "维多利亚", "kind": "breaking", "hours": 24, "weight": 2, "title": "维多利亚贵族加码龙门投资", "effects": [{"sel": "lungmen:*", "mult": 1.04}, {"sel": "fx", "jump": -0.01}]},
	"V10": {"region": "雷姆必拓", "kind": "breaking", "hours": 48, "weight": 2, "title": "雷姆必拓矿区扩产", "effects": [{"sel": "*:originium", "mult": 0.92}, {"sel": "*:fuel", "mult": 0.95}]},
	"V11": {"region": "叙拉古", "kind": "breaking", "hours": 24, "weight": 1, "title": "叙拉古家族争夺港口", "effects": [{"sel": "rat:weapon", "mult": 1.1}, {"sel": "kazimierz:build", "mult": 0.95}]},
	"V12": {"region": "叙拉古", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：叙拉古上调感染者保险金", "effects": [{"sel": "*:medical", "mult": 1.05}]},
	"V13": {"region": "伊比利亚", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：伊比利亚沉船赤金出水", "effects": [{"sel": "fx", "jump": -0.03}]},
	"V14": {"region": "萨尔贡", "kind": "announce", "hours": 24, "weight": 1, "title": "大巴扎年度集市", "effects": [{"sel": "kazimierz:trinket", "mult": 1.1}, {"sel": "karlan:trinket", "mult": 1.1}]},
	"V15": {"region": "萨尔贡", "kind": "breaking", "hours": 24, "weight": 1, "title": "萨尔贡赤金储备外流", "effects": [{"sel": "fx", "jump": -0.02}]},
	"V16": {"region": "莱塔尼亚", "kind": "announce", "hours": 24, "weight": 1, "title": "莱塔尼亚金律公告", "effects": [{"sel": "fx", "jump_range": [0.01, 0.03]}]},
	"V17": {"region": "拉特兰", "kind": "breaking", "hours": 24, "weight": 1, "title": "拉特兰公证所冻结一批商事账户", "effects": [{"sel": "kazimierz:*", "spread": 1.2}, {"sel": "karlan:*", "spread": 1.2}]},
	"V18": {"region": "维多利亚", "kind": "swan", "hours": 120, "weight": 1, "title": "伦蒂尼姆爆发大公爵战争", "effects": [{"sel": "karlan:*", "jump": -0.15}, {"sel": "*:weapon", "mult": 1.3}, {"sel": "fx", "jump": 0.12}]},
	"X16": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 2, "title": "源石结晶期提前：%s", "pick_region": true, "effects": [{"sel": "@:originium", "mult": 1.2}]},
	"X17": {"region": "泰拉", "kind": "announce", "hours": 24, "weight": 2, "title": "天灾信使联合会季度预报", "effects": [{"sel": "*:cold", "mult_range": [0.05, 0.1]}, {"sel": "*:armor", "mult": 1.03}]},
	"X18": {"region": "泰拉", "kind": "breaking", "hours": 48, "weight": 2, "title": "移动城市大迁徙季：%s", "pick_region": true, "effects": [{"sel": "@:*", "spread": 1.3}, {"sel": "@:fuel", "mult": 1.15}]},
	"X19": {"region": "泰拉", "kind": "rumor", "hours": 12, "weight": 2, "title": "传闻：危机合约悬赏翻倍", "effects": [{"sel": "*:weapon", "mult": 1.08}, {"sel": "*:armor", "mult": 1.05}]},
	"X20": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 1, "title": "源石引擎故障潮", "effects": [{"sel": "*:electronic", "mult": 1.12}]},
	"X21": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 2, "title": "矿石病新变种通报：%s", "pick_region": true, "effects": [{"sel": "@:medical", "mult": 1.3}, {"sel": "rhine:originium", "mult": 1.1}]},
	"X22": {"region": "泰拉", "kind": "announce", "hours": 24, "weight": 1, "title": "各国协调源石运输标准", "effects": [{"sel": "*:originium", "spread": 0.85}, {"sel": "*:contraband", "mult": 0.9}]},
	"X23": {"region": "泰拉", "kind": "rumor", "hours": 24, "weight": 1, "title": "传闻：大型天灾即将形成", "rumors_low": 12, "effects": [{"sel": "*:cold", "mult": 1.1}, {"sel": "fx", "jump": 0.02}]},
	"X24": {"region": "泰拉", "kind": "breaking", "hours": 24, "weight": 2, "title": "沃伦姆德式源石刺破地表：%s", "pick_region": true, "effects": [{"sel": "@:build", "mult": 1.2}, {"sel": "@:medical", "mult": 1.1}]},
	"X25": {"region": "泰拉", "kind": "swan", "hours": 240, "weight": 1, "title": "跨国天灾链式爆发", "penguin_fee": 2.5, "effects": [{"sel": "*:*", "spread": 1.5, "vol": 1.8}, {"sel": "*:cold", "mult": 1.6}, {"sel": "fx", "jump": 0.18}]},
}

## Every event: v1.0, v1.1 and v1.2 together (200).
static var EVENTS: Dictionary = _all()

static func _all() -> Dictionary:
	var out := BASE_EVENTS.duplicate()
	out.merge(MORE_EVENTS)
	out.merge(EXTRA_EVENTS)
	return out

static func regions() -> Array:
	var seen := {}
	for id in FactionCatalog.trading():
		seen[str(FactionCatalog.FACTIONS[id].region)] = true
	return seen.keys()

static func factions_in(region: String) -> Array[String]:
	var out: Array[String] = []
	for id in FactionCatalog.trading():
		if str(FactionCatalog.FACTIONS[id].region) == region: out.append(id)
	return out

static func of_kind(kind: String) -> Array:
	return EVENTS.keys().filter(func(id): return EVENTS[id].kind == kind and int(EVENTS[id].weight) > 0)

static func pick(kind: String, rng: RandomNumberGenerator, weight_of: Callable = Callable()) -> String:
	var pool := of_kind(kind)
	var total := 0.0
	var weights: Array = []
	for id in pool:
		var w := float(EVENTS[id].weight) * (float(weight_of.call(id)) if weight_of.is_valid() else 1.0)
		weights.append(w)
		total += w
	if pool.is_empty() or total <= 0.0: return ""
	var roll := rng.randf() * total
	for i in range(pool.size()):
		roll -= weights[i]
		if roll <= 0.0: return pool[i]
	return pool[-1]

# --- The real calendar (§10: seasonal events) ----------------------------------

## 春节 dates (lunar new year), for L5's week before.
const SPRING := ["2026-02-17", "2027-02-06", "2028-01-26", "2029-02-13", "2030-02-03", "2031-01-23", "2032-02-11", "2033-01-31", "2034-02-19", "2035-02-08"]
## season -> [month list, day, hour]; "spring" is special (a week before 春节).
const SEASONS := {
	"migration": [[1, 4, 7, 10], 1, 9], "tournament": [[2, 5, 8, 11], 15, 10],
	"festival": [[3, 6, 9, 12], 25, 18], "bulletin": [[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 1, 10],
	"summit": [[12], 1, 10],
}
const SEASON_EVENTS := {"spring": "L5", "migration": "S1", "tournament": "Z1", "festival": "C7", "bulletin": "X1", "summit": "K1"}

## The seasonal starts (local unix seconds) between `from` and `to`, sorted:
## [[local_t, event_id]].
static func seasonal_between(from_local: int, to_local: int) -> Array:
	var out: Array = []
	var d0 := Time.get_datetime_dict_from_unix_time(from_local)
	var d1 := Time.get_datetime_dict_from_unix_time(to_local)
	for year in range(int(d0.year), int(d1.year) + 1):
		for season in SEASONS:
			var spec: Array = SEASONS[season]
			for month in spec[0]:
				var t := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": spec[1], "hour": spec[2], "minute": 0, "second": 0})
				if t >= from_local and t < to_local: out.append([t, SEASON_EVENTS[season]])
		for date in SPRING:
			if not str(date).begins_with(str(year)): continue
			var t := Time.get_unix_time_from_datetime_string(date + "T08:00:00") - 7 * 86400
			if t >= from_local and t < to_local: out.append([t, "L5"])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out
