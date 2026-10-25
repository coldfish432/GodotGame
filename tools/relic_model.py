"""藏品数值修订案 v1.0 的估算模型：每层拿 1–2 件藏品（三选一），算输出/生存倍率。

    python tools/relic_model.py

粗模型：战斗中各条件的触发率是假设值（UP），技能、法术、回复没建模；
“认真”按输出×生存贪心挑，“随便”随机挑，“中位”取两者几何平均。
"""
import re, random, sys, os
src=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","game","relic_catalog.gd"),encoding="utf-8").read()
R=[]
for m in re.finditer(r'_r\("(.*?)", "(\w+)", (\d), ".*?", (".*?"|"[^"]*" % _n\([\d.]+\)), (\{[^}]*\})(?:, (\{[^}]*\}))?\)', src.replace('\\"',"'")):
    name,kind,rar=m.group(1),m.group(2),int(m.group(3))
    def d(s):
        if not s: return {}
        s=s.replace("1.0 / 6.0","0.1667").replace("1.0 / 3.0","0.333")
        return {k:float(v) for k,v in re.findall(r'"(\w+)": (-?[\d.]+)',s)}
    R.append((name,kind,rar,{**d(m.group(5)),**d(m.group(6))}))
# uptime assumptions in combat
UP={"full_hp_atk":0.5,"build_atk":0.3,"hit_stack_atk":6,"wave_burst_atk":0.15,"lone_atk":0.3,"wave_stack_atk":5,"avenge":0.0,
    "hurt_aspd":0.6,"engage_aspd":0.5,"build_aspd":0.3,"hurt_stack_aspd":6,"low_hp_aspd":0.3,"critical_aspd":0.1,"full_aspd":0.2,
    "gold_aspd":6,"elite_aspd_stack":5,"crowd_guard":0.3,"crowd_dance":0.3,"altar":3}
BASE_PCT=0.4  # gear prefixes/families already in the ATK% bucket
DEF_RATIO=0.35 # avg enemy DEF/K
import math
RD={r[0]:r for r in R}
def evaluate(owned,f,prop):
    s={}
    for n in owned:
        for k,v in RD[n][3].items(): s[k]=s.get(k,0)+v
    g=lambda k:s.get(k,0.0)
    dance_ev = (0.3 if prop else 0.5)
    ev=min(0.6,g("evasion"))
    atk=BASE_PCT+g("atk_pct")
    for k in ["full_hp_atk","build_atk","wave_burst_atk","lone_atk"]: atk+=g(k)*UP[k]
    atk+=min(0.8,g("hit_stack_atk")*6)+min(0.4,g("wave_stack_atk")*min(10,f*5))
    if g("evade_atk"): atk+=g("evade_atk")*min(0.5 if prop else 1,ev*3)
    atk+=0.4*0.3*(1 if g("crowd_guard") else 0)+0.05*min(10,f*0.5)*(1 if g("altar") else 0)
    if g("axe"):
        held=f if not prop else min(f, AXE_HELD.get(tuple(owned),f))
        atk+=max(0,g("axe")-(0.1*(f-1) if not prop else 0.05*held))
    gold_stacks=min(10, f*12/(10 if prop else 5))
    aspd=g("aspd")+sum(g(k)*UP[k] for k in ["hurt_aspd","engage_aspd","build_aspd","low_hp_aspd","critical_aspd","full_aspd"])
    aspd+=min(10*g("hurt_stack_aspd"),g("hurt_stack_aspd")*6)+g("gold_aspd")*gold_stacks
    aspd+=g("elite_aspd_stack")*min(15,f*0.6)+(80*0.3 if g("crowd_dance") else 0)
    di=min(1,g("def_ignore")); mit=lambda r:1/(1+r)
    dps=(1+atk)/(1+BASE_PCT)*(100+aspd)/100*(1+g("phys_dmg_pct"))*(1+g("dmg_pct"))*mit(DEF_RATIO*(1-di))/mit(DEF_RATIO)/max(0.3,1+g("enemy_hp"))
    dps*=1+0.5*min(1,g("execute")+0.25*g("wounded_dmg"))
    hpadd=max(0.1,1+g("hp_pct")+g("elite_hp_stack")*min(15,f*0.6))
    hpmul=1.0
    for n in owned:
        if "hp_mult" in RD[n][3]: hpmul*=RD[n][3]["hp_mult"]
    ehp=hpadd*hpmul*(1+0.3*g("def_pct"))/(1-ev*0.7)/max(0.3,1+g("enemy_atk"))/(1+g("taken_pct"))*(1.15 if g("segment_shield") else 1)
    ehp*=1+0.1*g("segment_blocks")+((0.3 if not prop else 0.12) if g("death_full") else 0)+(dance_ev*0.8 if g("crowd_dance") else 0)*0.3
    if g("ranged_taken"): ehp*=1.2
    if g("drain"): ehp*=0.85
    return dps,ehp
AXE_HELD={}  # the catalog is already the revised one (藏品数值修订案 v1.0); prop=True models its rules
W=[60,30,10]
def run(F,seed,strat,prop):
    rnd=random.Random(seed); owned=[]; out=[]
    for f in range(1,F+1):
        for _ in range(1+(rnd.random()<0.25)):
            pool=[r for r in RD.values() if r[0] not in owned]; offers=[]
            for _ in range(3):
                used={o[1] for o in offers}; c=[r for r in pool if r not in offers and r[1] not in used] or [r for r in pool if r not in offers]
                x=rnd.random()*sum(W[r[2]] for r in c)
                for r in c:
                    x-=W[r[2]]
                    if x<=0: offers.append(r); break
            best=max(offers,key=lambda r:(lambda d,e:d*e)(*evaluate(owned+[r[0]],f,prop))) if strat=="greedy" else rnd.choice(offers)
            owned.append(best[0])
        out.append(evaluate(owned,f,prop))
    return out
def table(prop,F=20,N=300):
    res={}
    for strat in ["greedy","random"]:
        acc=[[0,0] for _ in range(F)]
        for sd in range(N):
            for i,(d,e) in enumerate(run(F,sd,strat,prop)): acc[i][0]+=math.log(d)/N; acc[i][1]+=math.log(e)/N
        res[strat]=[(math.exp(a),math.exp(b)) for a,b in acc]
    return res
lines=["本合同第 N 层	认真 输出/生存	随便	中位	敌人系数（s=0.5）"]
new=table(True)
for f in [1,3,5,10,15,20]:
    g=new["greedy"][f-1]; r=new["random"][f-1]
    mid=(math.sqrt(g[0]*r[0]),math.sqrt(g[1]*r[1]))
    lines.append(f"{f}	认真 {g[0]:.2f}/{g[1]:.2f}	随便 {r[0]:.2f}/{r[1]:.2f}	中位 {mid[0]:.2f}/{mid[1]:.2f}	HP×{mid[0]**.5:.3f} ATK×{mid[1]**.5:.3f}（游戏里 ×{1.045**f:.3f} / ×{1.018**f:.3f}）")
sys.stdout.reconfigure(encoding="utf-8")
print("\n".join(lines))
