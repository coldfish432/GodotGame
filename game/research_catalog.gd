class_name ResearchCatalog
extends RefCounted

## 科研部 (龙门币平衡与科研部策划案_v1_1.md §5, 科研树状化策划案_v1_0.md): a
## tree of 71 permanent nodes over seven departments and joint research,
## each with its own name and prerequisites across departments; timed
## projects charged per sortie; endless lines. The combat nodes (科研树状化
## 策划案 §4.2) add to the Doctor's stats in their own multiplier zone,
## +89% overall at most (tools/research_model.py).

## Opens once 科研部 is built (Lv1); Lv2 gives the second research slot.
const OPEN_LEVEL := 1
const SECOND_SLOT_LEVEL := 2

const DEPARTMENTS := ["logistics", "medical", "engineering", "intel", "field", "commerce", "personnel"]
## Departments as the tree lays them out: the seven, then the joint research.
const BANDS := ["logistics", "medical", "engineering", "intel", "field", "commerce", "personnel", "joint"]
const DEPARTMENT_NAMES := {"logistics": "后勤部", "medical": "医疗部", "engineering": "工程部", "intel": "情报部",
	"field": "外勤部", "commerce": "商务部", "personnel": "人事部", "joint": "联合研究"}
const DEPARTMENT_COLORS := {"logistics": Color("0098dc"), "medical": Color("dfe4e6"), "engineering": Color("e0782a"),
	"intel": Color("5fd0d8"), "field": Color("8fc31f"), "commerce": Color("c48cff"), "personnel": Color("f5c000"),
	"joint": Color("ff6a6a")}

## By tier (1–7): price, hours, the deepest camp needed, materials (§5.5;
## 科研树状化策划案 §3 for Ⅶ, whose two nodes carry their own prices).
const TIER_PRICE := [56000, 140000, 280000, 616000, 1260000, 2520000, 5600000]
const TIER_HOURS := [1, 2, 4, 8, 16, 24, 36]
const TIER_CAMP := [0, 10, 20, 40, 60, 80, 90]
const TIER_MATERIALS := [
	{"电路板": 2, "继电器": 2},
	{"微型电机": 1, "电路板": 3, "装置": 2},
	{"微型电机": 2, "改量装置": 2, "密封泡沫": 3},
	{"工具套装": 1, "全新装置": 2, "车用蓄电池": 1},
	{"工具套装": 2, "模组数据块": 1, "车用蓄电池": 2},
	{"模组数据块": 2, "工具套装": 2, "燃料罐": 2},
	{"模组数据块": 3, "工具套装": 3, "燃料罐": 3, "玄纹墨": 3},
]
## Combat nodes cost this much more than the same tier's economy node.
const COMBAT_PREMIUM := 1.5
const JOINT_PRICE := 6720000

## id -> [name, tier, effect key, shown effect, prerequisites, combat stats,
## price override (0: by tier), hours override (0: by tier)]. A
## prerequisite is a node id or a base condition "@key" (REQUIREMENT_NAMES).
## The economy nodes keep their v1.1 ids, so saves carry over; 工程部's two
## late reforge nodes keep theirs at Ⅶ.
const NODES := {
	"logistics_1": ["订单速递", 1, "order_slot", "订单板 +1 栏", [], {}],
	"logistics_2": ["第二加工线", 2, "workshop_slot", "加工部队列 +1", ["logistics_1"], {}],
	"logistics_3": ["立体货架", 3, "rack_cells", "仓库容量 +20%", ["logistics_1", "@racks_3"], {}],
	"logistics_4": ["流水线优化", 4, "workshop_speed", "加工时长 −25%", ["logistics_2", "engineering_1"], {}],
	"logistics_5": ["大宗贸易协议", 5, "bulk_orders", "大宗订单栏 +1 · 补单 6 → 4 小时", ["logistics_3", "field_1"], {}],
	"logistics_6": ["自动分拣系统", 6, "auto_sort", "撤离后背包物品自动入库", ["logistics_4", "logistics_5", "intel_3", "@drone"], {}],
	"medical_1": ["药房扩编", 1, "free_potion", "免费药剂 3 → 4 瓶", [], {}],
	"medical_2": ["重症监护", 2, "injury_fee", "重伤治疗费 −50%", ["medical_1"], {}],
	"medical_3": ["巡回医疗", 3, "stay_care", "医疗驻留费用 −20% · 关系 +20%", ["medical_2", "field_1", "@stayed"], {}],
	"medical_4": ["环境防护", 4, "feature_cut", "地图特色累计 −10%", ["medical_2", "intel_1"], {}],
	"medical_5": ["高浓度配方", 5, "potion_grade", "免费药剂 +1 档", ["medical_1", "logistics_2"], {}],
	"medical_6": ["源石隔离病房", 6, "isolation_ward", "污染阶梯 60/90 → 70/100", ["medical_4", "medical_5", "engineering_3"], {}],
	"engineering_1": ["精密校具", 1, "refresh_fee", "重铸 · 校准 −15%", [], {}],
	"engineering_2": ["制式换代计划", 2, "rhodes_blue", "制式换代：白 → 蓝", ["engineering_1", "logistics_1"], {}],
	"engineering_3": ["精调工艺", 3, "tune_step", "精调递增 1.5 → 1.3", ["engineering_1", "intel_2"], {}],
	"engineering_4": ["精英制式装备", 4, "rhodes_gold", "制式换代：蓝 → 金", ["engineering_2", "logistics_2", "intel_2"], {}],
	"engineering_5": ["词条锚定", 7, "prefix_lock", "重铸锁定 1 条前缀", ["engineering_3", "intel_4", "engineering_c6", "@lungmen_r5"], {}, 5600000, 36],
	"engineering_6": ["平行重铸", 7, "reforge_pick", "重铸 2 选 1", ["engineering_5", "joint_eye", "logistics_6"], {}, 8400000, 48],
	"intel_1": ["痕迹增强滤镜", 1, "glow_range", "密室线索 · 踪迹幽光 +50%", [], {}],
	"intel_2": ["装备鉴定协议", 2, "appraisal", "装备鉴定：范围位置", ["intel_1"], {}],
	"intel_3": ["PRTS 层级预报", 3, "floor_report", "进层播报兴趣点 · 精英", ["intel_1"], {}],
	"intel_4": ["跨档识别", 4, "tier_mark", "跨档标记", ["intel_2", "engineering_1"], {}],
	"intel_5": ["信标追踪", 5, "exit_map", "撤离点上小地图", ["intel_3", "field_3"], {}],
	"intel_6": ["地层回波测绘", 6, "vault_map", "密室范围上小地图", ["intel_5", "personnel_3"], {}],
	"field_1": ["合同中介网", 1, "offer_slot", "合同可选 3 → 4", [], {}],
	"field_2": ["调度优先权", 2, "offer_reroll", "每次回港免费重抽 1 张合同", ["field_1"], {}],
	"field_3": ["营地联络站", 3, "deposit_fee", "营地寄存手续费 20% → 10%", ["field_1", "@camp_upgrade"], {}],
	"field_4": ["加固安全袋", 4, "safe_row", "安全袋 +1 行", ["field_3", "logistics_3", "@safe_2"], {}],
	"field_5": ["商队情报", 5, "trader_odds", "坎诺特出现率 +50% · 刷新 −1 赤金", ["field_2", "commerce_2", "intel_3"], {}],
	"field_6": ["联合课题组", 6, "project_slot", "第 3 个课题位", ["field_4", "field_5", "personnel_3"], {}],
	"commerce_1": ["远端结算", 1, "remote_fee", "远端手续费 −1%", ["@exchange"], {}],
	"commerce_2": ["赤金对冲", 2, "closure_spread", "赤金差价 3% → 2%", ["commerce_1"], {}],
	"commerce_3": ["长期合作协议", 3, "relation_drift", "关系回落 −30%", ["commerce_1", "field_2"], {}],
	"commerce_4": ["航线补给优化", 4, "voyage_supply", "航行物资 −15%", ["commerce_3", "logistics_2"], {}],
	"commerce_5": ["信用评级", 5, "loan_terms", "贷款额度 ×1.5 · 利率 −1%", ["commerce_2", "commerce_3"], {}],
	"commerce_6": ["期货直送", 6, "forward_dock", "远期交割直接入仓 · 免运费", ["commerce_4", "commerce_5", "logistics_4"], {}],
	"personnel_1": ["作战记录归档", 1, "feed_fee", "喂作战记录 −20%", ["@roster_3"], {}],
	"personnel_2": ["技能再训练", 2, "respec_fee", "技能重置 −50%", ["personnel_1"], {}],
	"personnel_3": ["踪迹档案", 3, "trace_odds", "踪迹点 20% → 25%", ["personnel_1", "intel_1"], {}],
	"personnel_4": ["后备轮训", 4, "bench_exp", "后备经验 20%", ["personnel_2", "medical_2"], {}],
	"personnel_5": ["晋升评审", 5, "promotion_fee", "精英化费用 −25%", ["personnel_4", "field_2"], {}],
	"personnel_6": ["全员轮训", 6, "bench_exp_2", "后备经验 20% → 40%", ["personnel_4", "personnel_5", "medical_5"], {}],
	# Combat (科研树状化策划案 §4.2). Stat keys: hp / atk / def are shares of
	# the final value; res, crit, crit_dmg are flat; aspd is 攻速 points;
	# skill_pct, skill_cd_pct, elite_pct, dmg_reduce, evasion, heal_pct,
	# move_pct, stamina_regen_pct, dash_cost_pct as CombatStats; potion_stack
	# adds to a flask cell.
	"medical_c1": ["战地包扎", 1, "", "药剂回复 +4%", ["medical_1"], {"heal_pct": 0.04}],
	"medical_c2": ["体能训练", 2, "", "生命 +1.5%", ["medical_c1", "field_c1"], {"hp": 0.015}],
	"medical_c3": ["源石抗性血清", 3, "", "法术抗性 +3", ["medical_c2", "medical_2"], {"res": 3.0}],
	"medical_c4": ["强化体质", 4, "", "生命 +3%", ["medical_c2", "medical_2", "personnel_c1"], {"hp": 0.03}],
	"medical_c5": ["应急再生", 5, "", "药剂回复 +8%", ["medical_c4", "medical_c3", "medical_4"], {"heal_pct": 0.08}],
	"medical_c6": ["极限耐受", 6, "", "生命 +5%", ["medical_c5", "medical_3"], {"hp": 0.05}],
	"engineering_c1": ["武器校准", 1, "", "攻击 · 法术 +1%", ["engineering_1"], {"atk": 0.01}],
	"engineering_c2": ["装甲涂层", 2, "", "防御 +6%", ["engineering_c1", "logistics_2"], {"def": 0.06}],
	"engineering_c3": ["刃口淬火", 3, "", "攻击 · 法术 +1.5%", ["engineering_c1", "engineering_2", "intel_c1"], {"atk": 0.015}],
	"engineering_c4": ["复合插板", 4, "", "防御 +10%", ["engineering_c2", "engineering_c3", "medical_c2"], {"def": 0.10}],
	"engineering_c5": ["源石刻印", 5, "", "攻击 · 法术 +5%", ["engineering_c3", "intel_c3", "engineering_4"], {"atk": 0.05}],
	"engineering_c6": ["全向防护层", 6, "", "整体减伤 +3%", ["engineering_c4", "engineering_c5", "field_c5"], {"dmg_reduce": 0.03}],
	"intel_c1": ["弱点图谱", 2, "", "对精英 · 首领伤害 +2%", ["intel_1", "engineering_1"], {"elite_pct": 0.02}],
	"intel_c2": ["要害训练", 3, "", "暴击率 +2%", ["intel_c1", "personnel_c1"], {"crit": 0.02}],
	"intel_c3": ["弱点测绘", 4, "", "对精英 · 首领伤害 +4%", ["intel_c1", "intel_3"], {"elite_pct": 0.04}],
	"intel_c4": ["致命点", 5, "", "暴击伤害 +15%", ["intel_c2", "intel_c3", "personnel_c2"], {"crit_dmg": 0.15}],
	"field_c1": ["越野训练", 1, "", "移速 +2%", ["field_1"], {"move_pct": 0.02}],
	"field_c2": ["体力调配", 2, "", "体力回复 +8%", ["field_c1", "medical_c1"], {"stamina_regen_pct": 0.08}],
	"field_c3": ["闪避训练", 3, "", "闪避 +1%", ["field_c2", "personnel_c1"], {"evasion": 0.01}],
	"field_c4": ["战术翻滚", 4, "", "闪避体力 −15% · 移速 +2%", ["field_c3", "medical_c2"], {"dash_cost_pct": -0.15, "move_pct": 0.02}],
	"field_c5": ["野外生存", 5, "", "整体减伤 +2.5%", ["field_c3", "medical_c4", "field_3"], {"dmg_reduce": 0.025}],
	"personnel_c1": ["协同训练", 2, "", "攻速 +1", ["personnel_1", "field_c1"], {"aspd": 1.0}],
	"personnel_c2": ["技能研讨", 3, "", "技能伤害 +4%", ["personnel_c1", "personnel_2"], {"skill_pct": 0.04}],
	"personnel_c3": ["连携演练", 4, "", "攻速 +2.5", ["personnel_c1", "field_c2", "field_3"], {"aspd": 2.5}],
	"personnel_c4": ["战术推演", 5, "", "技能伤害 +6% · 技能冷却 −5%", ["personnel_c2", "personnel_c3", "intel_c3"], {"skill_pct": 0.06, "skill_cd_pct": -0.05}],
	"logistics_c1": ["随身药包", 3, "", "药剂每格 +1", ["logistics_2", "medical_c1"], {"potion_stack": 1.0}],
	"joint_elite": ["罗德岛精锐计划", 6, "", "攻击 · 法术 +5% · 生命 +5%", ["medical_c5", "engineering_c5", "personnel_c4"], {"atk": 0.05, "hp": 0.05}, JOINT_PRICE],
	"joint_net": ["战地医疗网络", 6, "", "药剂回复 +10% · 整体减伤 +3%", ["medical_c5", "logistics_c1", "field_c5"], {"heal_pct": 0.10, "dmg_reduce": 0.03}, JOINT_PRICE],
	"joint_eye": ["全域态势", 6, "", "暴击率 +3% · 对精英 · 首领伤害 +5%", ["intel_c4", "personnel_c4", "intel_5"], {"crit": 0.03, "elite_pct": 0.05}, JOINT_PRICE],
}

## Base conditions -> shown text (data only).
const REQUIREMENT_NAMES := {"racks_3": "仓储部 Lv3", "drone": "仓储部 Lv4", "stayed": "医疗驻留", "camp_upgrade": "营地升级",
	"safe_2": "安全袋扩容二", "exchange": "交易所", "roster_3": "名册 3 人", "lungmen_r5": "龙门商会 R5"}

## Timed projects (§5.7): id -> [name, size, shown effect]. Signed for
## PROJECT_SORTIES sorties, charged at every departure.
const PROJECT_SORTIES := 3
const PROJECT_SLOTS := 2
const PROJECT_BASE := {"S": 11000, "M": 22000, "L": 39000}
const PROJECTS := {
	"dust": ["源石尘抑制", "S", "地图特色累计 −20%"],
	"scan": ["低频扫描", "S", "踪迹点 20% → 30%"],
	"refine": ["赤金精炼", "S", "敌人赤金 +20%"],
	"records": ["作战记录整理", "S", "作战记录掉落 +30%"],
	"threat": ["威胁抑制", "M", "威胁值累计 −15%"],
	"appraise": ["鉴定协议", "M", "波动指数 ×0.85"],
	"vaults": ["密室测绘", "M", "密室出现率 ×1.5"],
	"traps": ["陷阱预警", "M", "陷阱不涨威胁值"],
	"deep": ["深层勘测", "L", "掉落阶梯 +1 阶"],
	"supply": ["战地补给", "L", "出发 +2 瓶标准急救剂"],
	"trader": ["商队联络", "L", "坎诺特必定出现一次"],
	"extract": ["撤离保障", "L", "每 10 层必有随机撤离点"],
}

## Endless lines (§5.8): id -> [name, per level, cap text]. Level k costs
## ENDLESS_BASE × ENDLESS_GROWTH^(k − 1), up to ENDLESS_CAP.
const ENDLESS_BASE := 140000
const ENDLESS_GROWTH := 1.25
const ENDLESS_CAP := 30
const ENDLESS := {
	"contract": ["合同报酬", 0.01],
	"workshop": ["加工时长", -0.01],
	"projects": ["课题费用", -0.005],
	"voyage": ["航行时长", -0.01],
	"threat": ["威胁值累计", -0.005],
	"feed": ["喂作战记录费用", -0.01],
}

## The economy node of `department` that held tier `tier` in v1.1
## ("logistics_1" … "personnel_6"; the research hologram's grid).
static func node_id(department: String, tier: int) -> String:
	return "%s_%d" % [department, tier]

static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for id in NODES: out.append(str(id))
	return out

static func valid(id: String) -> bool: return NODES.has(id)

static func department_of(id: String) -> String: return id.rsplit("_", true, 1)[0]
static func tier_of(id: String) -> int: return int(NODES[id][1])
static func name_of(id: String) -> String: return str(NODES[id][0])

## The node's effect key ("rack_cells"; "" for a combat node).
static func key_of(id: String) -> String: return str(NODES[id][2])
static func effect_text(id: String) -> String: return str(NODES[id][3])
static func prerequisites(id: String) -> Array: return NODES[id][4]
static func stats_of(id: String) -> Dictionary: return NODES[id][5]
static func is_combat(id: String) -> bool: return not stats_of(id).is_empty()

## The node ids among its prerequisites, and the base conditions ("racks_3").
static func prerequisite_nodes(id: String) -> Array[String]:
	var out: Array[String] = []
	for p in prerequisites(id):
		if not str(p).begins_with("@"): out.append(str(p))
	return out

static func conditions(id: String) -> Array[String]:
	var out: Array[String] = []
	for p in prerequisites(id):
		if str(p).begins_with("@"): out.append(str(p).substr(1))
	return out

## Nodes that list `id` among their prerequisites.
static func unlocks(id: String) -> Array[String]:
	var out: Array[String] = []
	for other in NODES:
		if id in (NODES[other][4] as Array): out.append(str(other))
	return out

## The node id of an effect key ("" if unknown).
static func id_of_key(key: String) -> String:
	for id in NODES:
		if str(NODES[id][2]) == key: return str(id)
	return ""

static func price(id: String) -> int:
	var row: Array = NODES[id]
	if row.size() > 6 and int(row[6]) > 0: return int(row[6])
	var base := int(TIER_PRICE[tier_of(id) - 1])
	return roundi(base * COMBAT_PREMIUM) if is_combat(id) else base

static func hours(id: String) -> int:
	var row: Array = NODES[id]
	if row.size() > 7 and int(row[7]) > 0: return int(row[7])
	return int(TIER_HOURS[tier_of(id) - 1])

static func camp_needed(id: String) -> int: return int(TIER_CAMP[tier_of(id) - 1])
static func materials(id: String) -> Dictionary: return TIER_MATERIALS[tier_of(id) - 1]

## The nodes of a tree band (a department, or "joint"), by tier then id.
static func band_nodes(band: String) -> Array[String]:
	var out: Array[String] = []
	for id in NODES:
		if department_of(str(id)) == band: out.append(str(id))
	out.sort_custom(func(a: String, b: String) -> bool: return tier_of(a) < tier_of(b) or (tier_of(a) == tier_of(b) and a < b))
	return out

static func endless_price(level: int) -> int:
	return roundi(ENDLESS_BASE * pow(ENDLESS_GROWTH, level) / 1000.0) * 1000

## Price of one sortie of `project` departing at `tier`, before the endless discount.
static func project_price(project: String, tier: int) -> int:
	return Economy.tiered(int(PROJECT_BASE[str(PROJECTS[project][1])]), tier)
