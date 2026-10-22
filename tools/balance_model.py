"""Combat balance model (用户 2026-10-20: 详细计算数值并调整，所有干员和敌人).

Plain arithmetic over the numbers in the code — no Godot needed:
    python tools/balance_model.py            the compound rules (复利数值改造清单, in the code)
    python tools/balance_model.py --old      the linear rules before them
    python tools/balance_model.py --old --new  数值平衡案 v1.0's linear proposal
Prints markdown tables that 数值平衡案_v1_0.md quotes.

The model:
- a "matched" Doctor on floor F: a fine (blue) weapon, armour and trinket
  of that floor, typical gear ATK% and attribute points for that depth;
- enemies scaled by the spawn rules (HP, ATK per depth, 警戒 per floor);
- each operator's basic attack (her combo, interval and riders) and her
  Space amortised over its cooldown, at skill rank 1 / 精英 0.
"""
import sys

NEW = "--new" in sys.argv
COMPOUND = "--old" not in sys.argv

# --- Rules from the code ------------------------------------------------------------
BASE = dict(hp=2400, atk=600, arts=360, df=200, res=10)
WEAPON_ATK, ARMOR_HP, ARMOR_DEF, TRINKET_ARTS = 40, 360, 20, 30
FLOOR = 0.10
INTERVAL = 0.7

def power(floor, rarity=1, factor=1.05):
    return (1.5 + 0.3 * floor) * (1 + 0.3 * rarity) * factor

def phys(raw, df, k=None):
    if COMPOUND: return raw * (k or K_NOW) / ((k or K_NOW) + max(df, 0))
    return max(raw - max(df, 0), raw * FLOOR)

# --- 复利数值改造清单 (game/scaling.gd) ------------------------------------------------
GROWTH, TIER_GROWTH, POWER_BASE, K0 = 1.04, 1.48, 3.1, 600.0
K_NOW = K0
def g(floor): return GROWTH ** (floor - 1)
def tier_of(floor): return min(10, (floor - 1) // 10 + 1)
def tier_base(t): return TIER_GROWTH ** (t - 1)
BLUE_TYPICAL = 0.94          # a blue's usual roll (清单 B: about 94% of the base)
def compound_doctor(floor):
    global K_NOW
    K_NOW = K0 * g(floor)
    p = POWER_BASE * tier_base(tier_of(floor)) * BLUE_TYPICAL * 1.05
    # Attribute points: 119 by about floor 61 (清单 J), half 技巧, half 体魄.
    points = min(119.0, 2 + floor * 1.95)
    tec = phy = points / 2
    atk = (150 + 220 * p) * (1 + 0.12 + 0.0028 * tec)
    hp = (600 + 1300 * p) * (1 + 0.04 + 0.0035 * phy)
    df = (50 + 80 * p) * (1 + 0.0035 * phy)
    res = 10 + (5 if floor >= 40 else 0) + 4
    return dict(atk=atk, hp=hp, df=df, res=res, arts=(150 + 110 * p) * 1.0)
def arts(raw, res): return raw * max(1 - min(res, 80) / 100, FLOOR)

# Enemy scaling: current code / proposal.
if NEW or COMPOUND:
    HP_PER_DEPTH, ATK_PER_DEPTH, DEF_PER_DEPTH = 0.05, 0.022, 0.006
    PRESSURE_MAX = 100.0
else:
    HP_PER_DEPTH, ATK_PER_DEPTH, DEF_PER_DEPTH = 0.12, 0.02, 0.0
    PRESSURE_MAX = 1e9
PRESSURE_DIVISOR = 160.0
AMIYA_REFUND = 0.5 if NEW or COMPOUND else 1.0
HELL_HALF_ATK, HELL_FULL_ATK = (0.3, 0.4) if NEW or COMPOUND else (0.4, 0.6)

def pressure(floor, route=0.0):
    return min(PRESSURE_MAX, max(0.0, 3.5 * (floor - 1) + route))

# --- The matched Doctor -------------------------------------------------------------
def doctor(floor):
    if COMPOUND: return compound_doctor(floor)
    p = power(floor)
    # Attribute points: about one every two floors early, all 41 by floor 80;
    # half in 技巧 (ATK), half in 体魄 (HP/DEF).
    points = min(41.0, 2 + floor * 0.5)
    tec = phy = points / 2
    # Gear ATK%: weapon implicit 4% + an affix or prefix about 8% on average.
    atk = (BASE["atk"] + WEAPON_ATK * p + 5 * tec) * 1.12
    hp = (BASE["hp"] + ARMOR_HP * p + 24 * phy) * 1.04
    df = BASE["df"] + ARMOR_DEF * p + 2 * phy
    res = BASE["res"] + (5 if floor >= 30 else 0) + 4
    return dict(atk=atk, hp=hp, df=df, res=res, arts=BASE["arts"] + TRINKET_ARTS * p)

# --- Enemies -------------------------------------------------------------------------
# name: hp, atk, def, res, kind, attack damage ×, cycle seconds
ENEMIES = {
    "暴徒 thug": (1400, 440, 100, 0, "p", 1.0, 2.15),
    "拳刃武士 brawler": (1300, 392, 220, 0, "p", 1.0, 1.8),
    "术师 caster": (900, 420, 50, 30, "a", 1.0, 3.0),
    "精英 elite": (3600, 560, 300, 30, "a", 1.0, 3.1),
    "破城手 breacher": (4000, 580, 380, 10, "p", 1.3, 3.3),
    "家族汽车 car": (4200, 640, 480, 15, "p", 1.8, 4.8),
}

def enemy(name, floor):
    hp, atk, df, res, kind, mult, cycle = ENEMIES[name]
    d = floor - 1
    if COMPOUND:
        return dict(hp=hp * g(floor), atk=atk * g(floor), df=df * g(floor), res=res, kind=kind, mult=mult, cycle=cycle)
    return dict(hp=hp * (1 + HP_PER_DEPTH * d), atk=atk * (1 + ATK_PER_DEPTH * d),
                df=df * (1 + DEF_PER_DEPTH * d), res=res, kind=kind, mult=mult, cycle=cycle)

# --- Operators -----------------------------------------------------------------------
# Each returns (damage per second on one target, on a pack of three) from her
# basic attack plus her Space amortised, against enemy `e`.
def hit(atk, scale, kind, e, pierce=0.0):
    raw = atk * scale
    return phys(raw, e["df"] * (1 - pierce)) if kind == "p" else arts(raw, e["res"])

OPS = {}
def op(name, combo, interval, kind, reach, role):
    def deco(fn):
        OPS[name] = dict(combo=combo, interval=interval, kind=kind, reach=reach, role=role, extra=fn)
        return fn
    return deco

def C(name):
    return CUR[name] if not (NEW or COMPOUND) else PROPOSED.get(name, CUR[name])

# Combos and intervals: current code, then the proposal's changes.
CUR = {
    "lappland": [1.0, 1.0, 1.3], "amiya": [1.0, 1.1, 1.3], "hellagur": [1.35, 1.35, 1.75],
    "hoshiguma": [1.0, 1.0, 1.4], "texas": [0.8, 0.8, 1.1], "rosa": [0.8, 0.8, 1.3],
    "typhon": [1.0, 1.0, 1.0], "lin": [0.65, 0.65, 1.05], "santalla": [0.75, 0.75, 1.0],
}
PROPOSED = {
    "amiya": [0.95, 1.0, 1.2],
    "hellagur": [1.3, 1.3, 1.65],
}

def basic(name, d, e, pack):
    o = OPS[name]
    combo = C(name)
    per = []
    for i, s in enumerate(combo):
        one = hit(d["atk"], s, o["kind"], e)
        many = one
        per.append((one, many))
    return per

def run(floor, e_name):
    d = doctor(floor)
    e = enemy(e_name, floor)
    rows = {}
    for name, o in OPS.items():
        combo = C(name)
        period = INTERVAL * o["interval"]
        single = sum(hit(d["atk"], s, o["kind"], e) for s in combo) / 3 / period
        pack = single
        s_add, p_add = o["extra"](d, e, combo, period)
        rows[name] = (single + s_add, pack + p_add, o)
    return d, e, rows

# Riders and skills, each returning (+single dps, +pack-of-3 dps on top of the
# single-target basic).
@op("lappland", None, 1.0, "p", 3.4, "近战输出")
def _(d, e, combo, period):
    # Third cut crosses to a second enemy at 0.6; every fourth swing throws
    # the wave (arts 1.5, pierces the pack); 日晷 +30% ATK 8 of 16 s.
    wave = arts(d["arts"] * 1.5, e["res"]) / (4 * period)
    cross = hit(d["atk"], 0.6, "p", e) / (3 * period)
    base = sum(hit(d["atk"], s, "p", e) for s in combo) / 3 / period
    sundial = base * 0.30 * 8 / 16
    return wave + sundial, wave * 3 + cross + sundial  # the wave pierces all three

@op("amiya", None, 1.0, "a", 3.4, "近战输出")
def _(d, e, combo, period):
    # 绝影: 4 strikes of 1.0 arts; 8 s cooldown, REFUND s back per landed hit.
    cycle = 8.0 / (1 + AMIYA_REFUND / period)
    shadow = 4 * hit(d["atk"], 1.0, "a", e) / cycle
    return shadow, shadow  # bounces over the pack: same total

@op("hellagur", None, 1.35, "p", 3.4, "近战输出·续航")
def _(d, e, combo, period):
    base = sum(hit(d["atk"], s, "p", e) for s in combo) / 3 / period
    # Moon phases, one press per 6 s: 新月 an extra 1.75 hit; 弦月 6 s +40% ATK
    # and double cuts (×2.1 per swing); 满月 6 s +60% and up to 3 targets.
    newmoon = hit(d["atk"], 1.75, "p", e) / 18
    half = (hit(d["atk"] * (1 + HELL_HALF_ATK), 1.05, "p", e) * 2 / period - base) * 6 / 18
    full = (base * (1 + HELL_FULL_ATK) - base) * 6 / 18
    pierce = hit(d["atk"], combo[2], "p", e) / (3 * period)
    full_pack = (base * (1 + HELL_FULL_ATK) * 3 - base) * 6 / 18
    return newmoon + half + full, newmoon + half + full_pack + pierce * 2

@op("hoshiguma", None, 1.0, "p", 3.4, "重装")
def _(d, e, combo, period):
    # 力之锯: 4 s rooted, 0.6 every 0.3 s on the fan; no basic meanwhile.
    saw = (hit(d["atk"], 0.6, "p", e) / 0.3 * 4 - sum(hit(d["atk"], s, "p", e) for s in combo) / 3 / period * 4) / 12
    saw_pack = (hit(d["atk"], 0.6, "p", e) / 0.3 * 4 * 3 - sum(hit(d["atk"], s, "p", e) for s in combo) / 3 / period * 4) / 12
    return saw, saw_pack

@op("texas", None, 0.8, "p", 3.4, "先锋")
def _(d, e, combo, period):
    rain = 2 * hit(d["atk"], 1.4 * 1.1, "a", e) / 10
    return rain, rain * 3

@op("rosa", None, 1.25, "p", 7.0, "远程物理")
def _(d, e, combo, period):
    # 深入骨髓 on heavies (def ≥ 400 or elites): ignore 20% def, +20%.
    heavy = e["df"] >= 400 or e["hp"] >= 3000
    extra = 0.0
    if heavy:
        extra = sum(phys(d["atk"] * s * 1.2, e["df"] * 0.8) - hit(d["atk"], s, "p", e) for s in combo) / 3 / period
    # 雪崩击: one harpoon 1.0 + pin 0.3/s × 4 s per 12 s on one; four on a pack.
    harpoon = (hit(d["atk"], 1.0, "p", e) + 4 * hit(d["atk"], 0.3, "p", e)) / 12
    pierce = hit(d["atk"], combo[2], "p", e) / (3 * period)
    return extra + harpoon, extra + harpoon * 3 + pierce * 2

@op("typhon", None, 1.4, "p", 7.5, "远程物理")
def _(d, e, combo, period):
    # 锐如兽牙: up to 25% of DEF ignored after 5 shots on one target;
    # 重如沼泥 +40% on the first arrow (ignored over a long fight).
    fang = (phys(d["atk"] * combo[0], e["df"] * 0.75) - hit(d["atk"], combo[0], "p", e)) / period
    # 永恒狩猎: 5 rounds of 3 × 0.6 instead of 5 arrows, per 14 s.
    hunt = (15 * hit(d["atk"], 0.6, "p", e) - 5 * hit(d["atk"], combo[0], "p", e)) / 14
    return fang + hunt, fang + hunt

@op("lin", None, 1.15, "a", 6.0, "远程法术·范围")
def _(d, e, combo, period):
    base = sum(hit(d["atk"], s, "a", e) for s in combo) / 3 / period
    surge = base * 0.5 * 7 / 18
    # Every array hits the whole pack (radius 1.5, the third 3.2).
    return surge, base * 2 + surge * 3

@op("santalla", None, 1.0, "a", 6.5, "远程法术·范围")
def _(d, e, combo, period):
    splash = hit(d["atk"], combo[2] * 0.5, "a", e) / (3 * period)
    # 女巫之泪: an icicle every 0.35 s for 10 s per 20 s; about a quarter land on a
    # lone target, most land somewhere on a pack.
    tears = 29 * hit(d["atk"], 0.6, "a", e) / 20
    return tears * 0.25, splash * 2 + tears * 0.9

def dps_table(floor, e_name):
    d, e, rows = run(floor, e_name)
    return d, e, rows

if __name__ == "__main__":
    tag = "调整后" if NEW else "现状"
    print(f"## {tag}\n")
    print(f"敌人成长：生命 +{HP_PER_DEPTH:.1%}/层，攻击 +{ATK_PER_DEPTH:.1%}/层，防御 +{DEF_PER_DEPTH:.1%}/层，警戒上限 {'无' if PRESSURE_MAX > 1e8 else int(PRESSURE_MAX)}\n")
    print("### 博士（同层蓝装）\n")
    print("| 层 | 攻击力 | 生命 | 防御 | 法抗 |")
    print("|---|---|---|---|---|")
    for f in (1, 10, 30, 50, 100):
        d = doctor(f)
        print(f"| {f} | {d['atk']:.0f} | {d['hp']:.0f} | {d['df']:.0f} | {d['res']:.0f} |")
    print("\n### 敌人：拉普兰德几刀打死 / 它一击占博士生命 / 几下打死博士\n")
    print("| 层 | " + " | ".join(ENEMIES) + " |")
    print("|---|" + "---|" * len(ENEMIES))
    for f in (1, 10, 30, 50, 100):
        d = doctor(f)
        cells = []
        for n in ENEMIES:
            e = enemy(n, f)
            per = sum(hit(d["atk"], s, "p", e) for s in CUR["lappland"]) / 3
            raw = e["atk"] * e["mult"] * (1 + pressure(f) / PRESSURE_DIVISOR)
            taken = phys(raw, d["df"]) if e["kind"] == "p" else arts(raw, d["res"])
            cells.append(f"{e['hp'] / per:.1f} 刀 / {taken / d['hp']:.0%} / {d['hp'] / taken:.1f}")
        print(f"| {f} | " + " | ".join(cells) + " |")
    print("\n### 干员每秒伤害（攻击力倍数，第 10 层，对 拳刃武士 / 术师 / 精英；单体 · 三人一堆）\n")
    print("| 干员 | 定位 | 射程 | 三段倍率 | 间隔 | 武士 单体 | 武士 群 | 术师 单体 | 精英 单体 | 相对拉普兰德（单体平均） |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    ref = None
    out = []
    for name, o in OPS.items():
        vals = []
        for n in ("拳刃武士 brawler", "术师 caster", "精英 elite"):
            d, e, rows = run(10, n)
            vals.append(rows[name][:2])
        atk = doctor(10)["atk"]
        mean = sum(v[0] for v in vals) / 3
        if name == "lappland": ref = mean
        out.append((name, o, vals, mean, atk))
    for name, o, vals, mean, atk in out:
        combo = C(name)
        print(f"| {name} | {o['role']} | {o['reach']} | {' / '.join(f'{c:g}' for c in combo)} | {INTERVAL * o['interval']:.2f} | "
              f"{vals[0][0] / atk:.2f} | {vals[0][1] / atk:.2f} | {vals[1][0] / atk:.2f} | {vals[2][0] / atk:.2f} | {mean / ref:.0%} |")

# --- Every enemy: how long Lappland takes and what a duel costs ---------------------
# id: name, hp, atk, def, res, kind, damage ×, cycle (windup + interval), hits a cycle,
# elite, ranged (from game/enemy_attacks.gd).
ALL = [
    ("thug", "暴徒", 1400, 440, 100, 0, "p", 1.0, 2.15, 1, 0, 0),
    ("crossbow", "弩手", 1100, 440, 60, 0, "p", 1.0, 2.8, 1, 0, 1),
    ("slug", "源石虫", 800, 344, 0, 0, "p", 1.0, 1.95, 1, 0, 0),
    ("brawler", "拳刃武士", 1300, 392, 220, 0, "p", 1.0, 1.8, 1, 0, 0),
    ("crossbow_leader", "弩手组长", 1300, 368, 150, 0, "p", 1.0, 2.9, 3, 0, 1),
    ("ice_warrior", "冰原战士", 1600, 520, 220, 0, "p", 1.0, 2.5, 1, 0, 0),
    ("ice_hunter", "冰原猎人", 1100, 560, 60, 20, "p", 1.0, 4.1, 1, 0, 1),
    ("caster", "术师", 900, 420, 50, 30, "a", 1.0, 3.0, 1, 0, 1),
    ("shield", "机动盾兵", 1800, 380, 260, 0, "p", 0.8, 2.5, 1, 0, 0),
    ("slug_volatile", "高能源石虫", 700, 344, 0, 0, "p", 0.7, 2.0, 1, 0, 0),
    ("picket", "感染者纠察官", 1700, 460, 150, 10, "p", 1.0, 2.1, 1, 0, 0),
    ("greytail", "灰尾", 1300, 400, 180, 0, "p", 0.8, 1.8, 1, 0, 0),
    ("thrower", "燃烧瓶投掷者", 950, 380, 60, 0, "a", 0.8, 3.4, 1, 0, 1),
    ("taint_husk", "染污躯壳", 1500, 480, 160, 0, "p", 1.1, 2.3, 1, 0, 0),
    ("distorted_caster", "歪曲施法者", 1000, 500, 60, 40, "a", 1.1, 3.1, 1, 0, 1),
    ("shell_vine", "巨壳藤蔓", 2200, 460, 200, 20, "p", 1.0, 1.9, 1, 0, 0),
    ("rock_hornbeast", "岩角兽", 2000, 420, 250, 0, "p", 1.0, 3.0, 1, 0, 0),
    ("fallen_snowpriest", "陷落雪祀", 1800, 520, 120, 40, "a", 1.1, 3.6, 1, 0, 1),
    ("family_soldier", "家族士兵", 1300, 420, 120, 10, "p", 0.8, 1.9, 1, 0, 0),
    ("family_intimidator", "家族恫吓者", 2600, 480, 420, 10, "p", 1.2, 3.1, 1, 0, 0),
    ("family_crossbow", "家族弩手", 1100, 420, 100, 10, "p", 0.6, 3.0, 2, 0, 1),
    ("family_caster", "家族术师", 1000, 440, 120, 40, "a", 0.7, 3.3, 2, 0, 1),
    ("elite", "精英重击", 3600, 560, 300, 30, "a", 1.0, 3.1, 1, 1, 0),
    ("armed", "武装人员", 3600, 560, 320, 20, "p", 1.4, 3.1, 1, 1, 0),
    ("greytail_lord", "灰尾香主", 3400, 540, 260, 20, "a", 1.3, 3.0, 1, 1, 0),
    ("bully", "欺凌者", 3800, 600, 320, 10, "p", 1.5, 3.8, 1, 1, 0),
    ("avenger", "寻仇者", 3400, 520, 240, 20, "p", 0.8, 3.0, 2, 1, 0),
    ("breacher", "粉碎攻坚手", 4000, 580, 380, 10, "p", 1.3, 3.3, 1, 1, 0),
    ("shattered_champion", "木裂战士", 3800, 600, 280, 30, "p", 1.0, 2.9, 2, 1, 0),
    ("family_capo", "家族角头", 3600, 560, 320, 25, "a", 1.4, 3.2, 1, 1, 0),
    ("family_eraser", "家族灭迹人", 3800, 640, 360, 45, "p", 1.6, 2.55, 1, 1, 0),
    ("family_car", "家族专用轿车", 4200, 640, 480, 15, "p", 1.8, 4.8, 1, 1, 0),
]

# The proposal's per-enemy changes: id -> {field: value}.
ENEMY_CHANGES = {
    "family_crossbow": {"mult": 0.8},
    "family_intimidator": {"hp": 2200, "mult": 1.0},
    "shell_vine": {"hp": 1900},
    "family_eraser": {"hp": 3400, "mult": 1.3},
    "family_car": {"hp": 3800, "mult": 1.5},
    "shattered_champion": {"mult": 0.85},
}

def duel(row, floor):
    _, name, hp, atk, df, res, kind, mult, cycle, hits, elite, ranged = row
    if NEW or COMPOUND:
        ch = ENEMY_CHANGES.get(row[0], {})
        hp, mult = ch.get("hp", hp), ch.get("mult", mult)
    d = doctor(floor)
    dep = floor - 1
    if COMPOUND:
        hp *= g(floor)
        df *= g(floor)
        atk *= g(floor) / (1 + ATK_PER_DEPTH * dep)   # the line below applies the linear one
    else:
        hp *= 1 + HP_PER_DEPTH * dep
        df *= 1 + DEF_PER_DEPTH * dep
    per = sum(phys(d["atk"] * s, df) for s in CUR["lappland"]) / 3
    ttk = hp / per * INTERVAL
    raw = atk * (1 + ATK_PER_DEPTH * dep) * mult * (1 + pressure(floor) / PRESSURE_DIVISOR)
    taken = phys(raw, d["df"]) if kind == "p" else arts(raw, d["res"])
    dps = taken * hits / cycle / d["hp"]
    return ttk, taken / d["hp"], dps, dps * ttk

def enemy_table(floor):
    print(f"\n### 全部敌人（第 {floor} 层，同层蓝装拉普兰德单挑，不闪避）\n")
    print("| 敌人 | 精英 | 远程 | 击杀秒数 | 一击 | 每秒掉血 | 单挑掉血 |")
    print("|---|---|---|---|---|---|---|")
    for row in ALL:
        ttk, one, dps, cost = duel(row, floor)
        print(f"| {row[1]} | {'是' if row[10] else ''} | {'是' if row[11] else ''} | {ttk:.1f} | {one:.0%} | {dps:.1%} | {cost:.0%} |")

if __name__ == "__main__" and "--enemies" in sys.argv:
    enemy_table(int(sys.argv[sys.argv.index("--enemies") + 1]))
