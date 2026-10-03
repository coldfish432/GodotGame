E = {'暴徒 thug':(1400,440,100,0,'p'),'弩手 crossbow':(1100,440,60,0,'p'),'源石虫 slug':(800,344,0,0,'p'),
 '拳刃武士 brawler':(1300,392,220,0,'p'),'弩手组长 leader(每箭)':(1300,368,150,0,'p'),'冰原战士 ice_warrior':(1600,520,220,0,'p'),
 '冰原猎人 ice_hunter':(1100,560,60,20,'p'),'精英 elite':(3600,560,300,30,'a')}
def phys(a,d): return max(a-d,a*0.1)
def arts(a,r): return a*max(1-r/100,0.1)
INT=0.42; COMBO=[1,1,1.3]
builds = {
 '白板': dict(atk=600,arts=360,crit=0,cdmg=1.5,aspd=100,df=200,res=10,hp=2400,pierce=0),
 '锋刃4(中期)': dict(atk=600*1.15+60,arts=360,crit=0.15+0.05,cdmg=1.8,aspd=100,df=200,res=10,hp=2400*0.92,pierce=0.4),
 '坚壁4(中期)': dict(atk=600,arts=360,crit=0,cdmg=1.5,aspd=100,df=(200+70+30)*1.35,res=25,hp=2400,pierce=0),
}
def ttk(b,n,depth):
    hp,atk,df,res,k=E[n]; hp*=1+(depth-1)*0.12+(0.45 if '冰原' in n else 0)
    d=df*(1-b['pierce'])
    per=sum(phys(b['atk']*c,d) for c in COMBO)/3
    per=per*(1-b['crit'])+b['crit']*sum(phys(b['atk']*c*b['cdmg'],d) for c in COMBO)/3
    return hp/per, hp/per*INT*100/b['aspd']
def hit(b,n,depth,pr):
    hp,atk,df,res,k=E[n]; raw=atk*(1+(depth-1)*0.02)*(1+pr/160)
    d=phys(raw,b['df']) if k=='p' else arts(raw,b['res'])
    return d, b['hp']/d
for depth,pr in [(1,0),(3,30),(6,70)]:
    print(f'\n深度 {depth} · 警戒 {pr}')
    print('| 敌人 | HP | 白板 命中数/秒 | 锋刃4 命中数/秒 | 敌方一击（白板） | 致死次数 白板 / 坚壁4 |')
    print('|---|---|---|---|---|---|')
    for n in E:
        hp=E[n][0]*(1+(depth-1)*0.12+(0.45 if '冰原' in n else 0))
        a=ttk(builds['白板'],n,depth); b=ttk(builds['锋刃4(中期)'],n,depth)
        h=hit(builds['白板'],n,depth,pr); t=hit(builds['坚壁4(中期)'],n,depth,pr)
        print(f'| {n} | {hp:.0f} | {a[0]:.1f} / {a[1]:.1f}s | {b[0]:.1f} / {b[1]:.1f}s | {h[0]:.0f} | {h[1]:.1f} / {t[1]:.1f} |')
