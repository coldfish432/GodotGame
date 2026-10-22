"""Research tree model (用户 2026-10-22: 树状科研，可以增加局内角色数值，整体战力
增幅不超过 100%，考虑投入产出比).

    python tools/research_model.py

Prints the markdown tables 科研树状化策划案_v1_0.md quotes:
- every combat node's share of 整体战力 at a representative depth,
- the totals (offence × survival), stage by stage,
- the price per +1% of each node (投入产出比).

整体战力 = 输出倍率 × 生存倍率 (both against the matched Doctor of
tools/balance_model.py at the depth given):
- 输出: final ATK, crit, attack speed, skill and elite damage;
- 生存: final HP, DEF through K/(K + DEF), RES, damage reduction, dodge,
  healing. Movement and stamina are not counted (utility).
Research multipliers sit in their own zone, applied after gear and points,
so they do not move 复利数值改造清单 C's flat/percent crossover.
"""
import math

# --- The matched Doctor (balance_model.compound_doctor) ---------------------------------
GROWTH, TIER_GROWTH, POWER_BASE, K0 = 1.04, 1.48, 3.1, 600.0
def g(f): return GROWTH ** (f - 1)
def tier_of(f): return min(10, (f - 1) // 10 + 1)
def doctor(f):
    p = POWER_BASE * TIER_GROWTH ** (tier_of(f) - 1) * 0.94 * 1.05
    pts = min(119.0, 2 + f * 1.95)
    phy = pts / 2
    hp = (600 + 1300 * p) * (1.04 + 0.0035 * phy)
    df = (50 + 80 * p) * (1 + 0.0035 * phy)
    res = 10 + (5 if f >= 40 else 0) + 4
    return dict(hp=hp, df=df, res=res, k=K0 * g(f))

# Shares the model weighs by (assumed, from play): the Doctor's own crit and
# crit damage from gear, how much of her damage is her Space, how much of
# the fighting is against elites and bosses, how much of incoming damage is
# physical, and how much of her survival comes from healing.
CRIT, CRIT_DMG = 0.20, 1.6
SKILL_SHARE, ELITE_SHARE = 0.35, 0.45
PHYS_SHARE, HEAL_SHARE = 0.65, 0.25

def offence(s):
    m = 1 + s.get("atk", 0)
    m *= (1 + (CRIT + s.get("crit", 0)) * (CRIT_DMG + s.get("crit_dmg", 0) - 1)) / (1 + CRIT * (CRIT_DMG - 1))
    m *= 1 + s.get("aspd", 0)
    m *= 1 + SKILL_SHARE * s.get("skill", 0)
    m *= 1 + ELITE_SHARE * s.get("elite", 0)
    return m

def survival(s, f):
    d = doctor(f)
    def taken(df, res):
        return PHYS_SHARE * d["k"] / (d["k"] + df) + (1 - PHYS_SHARE) * (1 - min(res, 80) / 100)
    base = d["hp"] / taken(d["df"], d["res"])
    hp = d["hp"] * (1 + s.get("hp", 0))
    ehp = hp / taken(d["df"] * (1 + s.get("def", 0)), d["res"] + s.get("res", 0))
    ehp /= (1 - s.get("reduce", 0)) * (1 - s.get("dodge", 0))
    ehp *= 1 + HEAL_SHARE * s.get("heal", 0)
    return ehp / base

# --- The tree: id, department, tier, name, effect, combat stats, prerequisites ---------
# A prerequisite is another node's id or a base condition in 「」. Every
# prerequisite sits at the same tier or lower, and nothing loops.
ECONOMY = [
    ("log_1", "后勤部", 1, "订单速递", "订单板 +1 栏", {}, []),
    ("log_2", "后勤部", 2, "第二加工线", "加工部队列 +1", {}, ["log_1"]),
    ("log_3", "后勤部", 3, "立体货架", "货架 12 → 14 格", {}, ["log_1", "「每区 3 个货架」"]),
    ("log_4", "后勤部", 4, "流水线优化", "加工时长 −25%", {}, ["log_2", "eng_1"]),
    ("log_5", "后勤部", 5, "大宗贸易协议", "大宗订单栏 +1 · 补单 6 → 4 小时", {}, ["log_3", "fld_1"]),
    ("log_6", "后勤部", 6, "自动分拣系统", "撤离后自动上架", {}, ["log_4", "log_5", "int_3", "「搬运无人机」"]),
    ("med_1", "医疗部", 1, "药房扩编", "免费药剂 3 → 4 瓶", {}, []),
    ("med_2", "医疗部", 2, "重症监护", "重伤治疗费 −50%", {}, ["med_1"]),
    ("med_3", "医疗部", 3, "巡回医疗", "医疗驻留费用 −20% · 关系 +20%", {}, ["med_2", "fld_1", "「医疗驻留过一次」"]),
    ("med_4", "医疗部", 4, "环境防护", "地图特色累计 −10%", {}, ["med_2", "int_1"]),
    ("med_5", "医疗部", 5, "高浓度配方", "免费药剂 +1 档", {}, ["med_1", "log_2"]),
    ("med_6", "医疗部", 6, "源石隔离病房", "污染阶梯 60/90 → 70/100", {}, ["med_4", "med_5", "eng_3"]),
    ("eng_1", "工程部", 1, "精密校具", "重铸 · 校准 −15%", {}, []),
    ("eng_2", "工程部", 2, "制式换代计划", "制式换代：白 → 蓝", {}, ["eng_1", "log_1"]),
    ("eng_3", "工程部", 3, "精调工艺", "精调递增 1.5 → 1.3", {}, ["eng_1", "int_2"]),
    ("eng_4", "工程部", 4, "精英制式装备", "制式换代：蓝 → 金", {}, ["eng_2", "log_2", "int_2"]),
    ("eng_7a", "工程部", 7, "词条锚定", "重铸锁定 1 条前缀", {}, ["eng_3", "int_4", "eng_c6", "「龙门商会 R5」"]),
    ("eng_7b", "工程部", 7, "平行重铸", "重铸 2 选 1", {}, ["eng_7a", "joint_eye", "log_6"]),
    ("int_1", "情报部", 1, "痕迹增强滤镜", "密室线索 · 踪迹幽光 +50%", {}, []),
    ("int_2", "情报部", 2, "装备鉴定协议", "装备鉴定：范围位置", {}, ["int_1"]),
    ("int_3", "情报部", 3, "PRTS 层级预报", "进层播报兴趣点 · 精英", {}, ["int_1"]),
    ("int_4", "情报部", 4, "跨档识别", "跨档标记", {}, ["int_2", "eng_1"]),
    ("int_5", "情报部", 5, "信标追踪", "撤离点上小地图", {}, ["int_3", "fld_3"]),
    ("int_6", "情报部", 6, "地层回波测绘", "密室范围上小地图", {}, ["int_5", "per_3"]),
    ("fld_1", "外勤部", 1, "合同中介网", "合同可选 3 → 4", {}, []),
    ("fld_2", "外勤部", 2, "调度优先权", "每次回港免费重抽 1 张合同", {}, ["fld_1"]),
    ("fld_3", "外勤部", 3, "营地联络站", "营地寄存手续费 20% → 10%", {}, ["fld_1", "「营地升级」"]),
    ("fld_4", "外勤部", 4, "加固安全袋", "安全袋 +1 行", {}, ["fld_3", "log_3", "「安全袋扩容二」"]),
    ("fld_5", "外勤部", 5, "商队情报", "坎诺特出现率 +50% · 刷新 −1 赤金", {}, ["fld_2", "com_2", "int_3"]),
    ("fld_6", "外勤部", 6, "联合课题组", "第 3 个课题位", {}, ["fld_4", "fld_5", "per_3"]),
    ("com_1", "商务部", 1, "远端结算", "远端手续费 −1%", {}, ["「交易所」"]),
    ("com_2", "商务部", 2, "赤金对冲", "赤金差价 3% → 2%", {}, ["com_1"]),
    ("com_3", "商务部", 3, "长期合作协议", "关系回落 −30%", {}, ["com_1", "fld_2"]),
    ("com_4", "商务部", 4, "航线补给优化", "航行物资 −15%", {}, ["com_3", "log_2"]),
    ("com_5", "商务部", 5, "信用评级", "贷款额度 ×1.5 · 利率 −1%", {}, ["com_2", "com_3"]),
    ("com_6", "商务部", 6, "期货直送", "远期交割直接入仓 · 免运费", {}, ["com_4", "com_5", "log_4"]),
    ("per_1", "人事部", 1, "作战记录归档", "喂作战记录 −20%", {}, ["「名册 3 人」"]),
    ("per_2", "人事部", 2, "技能再训练", "技能重置 −50%", {}, ["per_1"]),
    ("per_3", "人事部", 3, "踪迹档案", "踪迹点 20% → 25%", {}, ["per_1", "int_1"]),
    ("per_4", "人事部", 4, "后备轮训", "后备经验 20%", {}, ["per_2", "med_2"]),
    ("per_5", "人事部", 5, "晋升评审", "精英化费用 −25%", {}, ["per_4", "fld_2"]),
    ("per_6", "人事部", 6, "全员轮训", "后备经验 20% → 40%", {}, ["per_4", "per_5", "med_5"]),
]
NODES = [
    ("med_c1", "医疗部", 1, "战地包扎", "药剂回复 +4%", {"heal": 0.04}, ["med_1"]),
    ("med_c2", "医疗部", 2, "体能训练", "生命 +1.5%", {"hp": 0.015}, ["med_c1", "fld_c1"]),
    ("med_c3", "医疗部", 3, "源石抗性血清", "法术抗性 +3", {"res": 3}, ["med_c2", "med_2"]),
    ("med_c4", "医疗部", 4, "强化体质", "生命 +3%", {"hp": 0.03}, ["med_c2", "med_2", "per_c1"]),
    ("med_c5", "医疗部", 5, "应急再生", "药剂回复 +8%", {"heal": 0.08}, ["med_c4", "med_c3", "med_4"]),
    ("med_c6", "医疗部", 6, "极限耐受", "生命 +5%", {"hp": 0.05}, ["med_c5", "med_3"]),
    ("eng_c1", "工程部", 1, "武器校准", "攻击 · 法术 +1%", {"atk": 0.01}, ["eng_1"]),
    ("eng_c2", "工程部", 2, "装甲涂层", "防御 +6%", {"def": 0.06}, ["eng_c1", "log_2"]),
    ("eng_c3", "工程部", 3, "刃口淬火", "攻击 · 法术 +1.5%", {"atk": 0.015}, ["eng_c1", "eng_2", "int_c1"]),
    ("eng_c4", "工程部", 4, "复合插板", "防御 +10%", {"def": 0.10}, ["eng_c2", "eng_c3", "med_c2"]),
    ("eng_c5", "工程部", 5, "源石刻印", "攻击 · 法术 +5%", {"atk": 0.05}, ["eng_c3", "int_c3", "eng_4"]),
    ("eng_c6", "工程部", 6, "全向防护层", "整体减伤 +3%", {"reduce": 0.03}, ["eng_c4", "eng_c5", "fld_c5"]),
    ("int_c1", "情报部", 2, "弱点图谱", "对精英 · 首领伤害 +2%", {"elite": 0.02}, ["int_1", "eng_1"]),
    ("int_c2", "情报部", 3, "要害训练", "暴击率 +2%", {"crit": 0.02}, ["int_c1", "per_c1"]),
    ("int_c3", "情报部", 4, "弱点测绘", "对精英 · 首领伤害 +4%", {"elite": 0.04}, ["int_c1", "int_3"]),
    ("int_c4", "情报部", 5, "致命点", "暴击伤害 +15%", {"crit_dmg": 0.15}, ["int_c2", "int_c3", "per_c2"]),
    ("fld_c1", "外勤部", 1, "越野训练", "移速 +2%", {}, ["fld_1"]),
    ("fld_c2", "外勤部", 2, "体力调配", "体力回复 +8%", {}, ["fld_c1", "med_c1"]),
    ("fld_c3", "外勤部", 3, "闪避训练", "闪避 +1%", {"dodge": 0.01}, ["fld_c2", "per_c1"]),
    ("fld_c4", "外勤部", 4, "战术翻滚", "闪避体力 −15% · 移速 +2%", {}, ["fld_c3", "med_c2"]),
    ("fld_c5", "外勤部", 5, "野外生存", "整体减伤 +2.5%", {"reduce": 0.025}, ["fld_c3", "med_c4", "fld_3"]),
    ("per_c1", "人事部", 2, "协同训练", "攻速 +1%", {"aspd": 0.01}, ["per_1", "fld_c1"]),
    ("per_c2", "人事部", 3, "技能研讨", "技能伤害 +4%", {"skill": 0.04}, ["per_c1", "per_2"]),
    ("per_c3", "人事部", 4, "连携演练", "攻速 +2.5%", {"aspd": 0.025}, ["per_c1", "fld_c2", "fld_3"]),
    ("per_c4", "人事部", 5, "战术推演", "技能伤害 +6% · 技能冷却 −5%", {"skill": 0.09}, ["per_c2", "per_c3", "int_c3"]),
    ("log_c1", "后勤部", 3, "随身药包", "药剂携带 +1", {"heal": 0.03}, ["log_2", "med_c1"]),
    ("joint_elite", "联合", 6, "罗德岛精锐计划", "攻击 · 法术 +5% · 生命 +5%", {"atk": 0.05, "hp": 0.05}, ["med_c5", "eng_c5", "per_c4"]),
    ("joint_net", "联合", 6, "战地医疗网络", "药剂回复 +10% · 整体减伤 +3%", {"heal": 0.10, "reduce": 0.03}, ["med_c5", "log_c1", "fld_c5"]),
    ("joint_eye", "联合", 6, "全域态势", "暴击率 +3% · 对精英 · 首领伤害 +5%", {"crit": 0.03, "elite": 0.05}, ["int_c4", "per_c4", "int_5"]),
]
ALL = {n[0]: n for n in ECONOMY + NODES}
for n in ECONOMY + NODES:
    for q in n[6]:
        if q.startswith("「"): continue
        assert q in ALL, (n[0], q)
        assert ALL[q][2] <= n[2], (n[0], q, ALL[q][2], n[2])
def _acyclic(node, path=()):
    assert node not in path, ("cycle", path + (node,))
    for q in ALL[node][6]:
        if q in ALL: _acyclic(q, path + (node,))
for key in ALL: _acyclic(key)
assert len({n[3] for n in ECONOMY + NODES}) == len(ECONOMY + NODES), "names must differ"

TIER_PRICE = [20000, 50000, 100000, 220000, 450000, 900000, 0]
# Ⅶ (the two late reforge nodes): their own prices.
LATE_PRICE = {"eng_7a": 2_000_000, "eng_7b": 3_000_000}
# Combat nodes cost a premium over the same tier's economy node; joint ones more.
COMBAT_PREMIUM = 1.5
JOINT_PRICE = 2_400_000
def price(node):
    if node[0] in LATE_PRICE: return LATE_PRICE[node[0]]
    if node[1] == "联合": return JOINT_PRICE
    if node in ECONOMY: return TIER_PRICE[node[2] - 1]
    return int(TIER_PRICE[node[2] - 1] * COMBAT_PREMIUM)

def combine(nodes):
    total = {}
    for n in nodes:
        for k, v in n[5].items(): total[k] = total.get(k, 0) + v
    return total

def power(nodes, f):
    s = combine(nodes)
    return offence(s), survival(s, f)

F = 60
print(f"## 每项战斗研究（第 {F} 层的标准博士）\n")
print("| 研究 | 部门 | 阶 | 效果 | 前置 | 价格 | 整体战力 | 每 +1% 的价格 |")
print("|---|---|---|---|---|---|---|---|")
for n in NODES:
    o, d = power([n], F)
    gain = o * d - 1
    per = price(n) / (gain * 100) if gain > 0 else float("inf")
    pre = "、".join(ALL[q][3] if q in ALL else q for q in n[6])
    print(f"| {n[3]} | {n[1]} | {'ⅠⅡⅢⅣⅤⅥⅦ'[n[2]-1]} | {n[4]} | {pre} | {price(n)/1000:,.0f}k | +{gain*100:.1f}% | {'—' if per == float('inf') else f'{per/1000:,.0f}k'} |")

# Stages: research tier open by depth (camp 0/10/20/40/60/80) ~ sortie from the
# ledger (龙门币平衡与科研部策划案 v1.1 §4.3: deepest 16/28/40/46/60/69/75/85).
print("\n## 分阶段累计\n")
print("| 研究阶 | 约第几局可研究 | 累计价格 | 输出倍率 | 生存倍率 | 整体战力 |")
print("|---|---|---|---|---|---|")
SORTIE = {1: "6", 2: "8", 3: "10", 4: "16", 5: "30", 6: "60"}
for t in range(1, 7):
    have = [n for n in NODES if n[2] <= t]
    o, d = power(have, F)
    cost = sum(price(n) for n in have)
    print(f"| ≤{'ⅠⅡⅢⅣⅤⅥ'[t-1]} | {SORTIE[t]} | {cost/1e6:.2f}M | ×{o:.3f} | ×{d:.3f} | +{(o*d-1)*100:.0f}% |")

print("\n## 不同深度下的满级效果（防御的分量随 K 变化）\n")
print("| 层 | 输出倍率 | 生存倍率 | 整体战力 |")
print("|---|---|---|---|")
for f in [10, 30, 60, 90]:
    o, d = power(NODES, f)
    print(f"| {f} | ×{o:.3f} | ×{d:.3f} | +{(o*d-1)*100:.0f}% |")

# What +X% overall power is worth in depth: the floor growth is 1.04 on both
# sides, so ×P overall ≈ the gear of log(P)/(2·log 1.04) floors deeper.
o, d = power(NODES, F)
print(f"\n满级相当于提前 {math.log(o*d)/(2*math.log(GROWTH)):.1f} 层的数值；一个档位（10 层，×1.48 两边）是 ×{TIER_GROWTH**2:.2f}。")

print("\n## 经济研究\n")
print("| 研究 | 部门 | 阶 | 效果 | 前置 | 价格 |")
print("|---|---|---|---|---|---|")
for n in ECONOMY:
    pre = "、".join(ALL[q][3] if q in ALL else q for q in n[6]) or "—"
    print(f"| {n[3]} | {n[1]} | {'ⅠⅡⅢⅣⅤⅥⅦ'[n[2]-1]} | {n[4]} | {pre} | {price(n)/1000:,.0f}k |")
cross = sum(1 for n in ECONOMY + NODES for q in n[6] if q in ALL and ALL[q][1] != n[1])
links = sum(1 for n in ECONOMY + NODES for q in n[6] if q in ALL)
print(f"\n前置连线 {links} 条，其中跨部门 {cross} 条；研究 {len(ECONOMY + NODES)} 项，经济合计 {sum(price(n) for n in ECONOMY)/1e6:.2f}M。")
