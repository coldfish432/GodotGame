"""Package generated paintings for approval; never draw or downscale runtime art.

Only alpha thresholding is applied to approval PNGs. Raw imagegen sources remain
byte-for-byte unchanged. Preview resizing and labels affect review sheets only.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, math, zipfile

B=Path(__file__).resolve().parent
F=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
SM=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
ORDER=['op_lappland','op_amiya','op_hellagur','op_rosa','op_hoshiguma','op_lin','op_typhon','op_santalla','op_texas',
       'npc_closure','npc_cannot','npc_squad','npc_medic','npc_post_rat','npc_post_reunion','npc_post_ursus','npc_post_sami']
SELECT={'op_lappland':'op_lappland_framing','op_santalla':'op_santalla_framing','op_texas':'op_texas_framing',
        'op_typhon':'op_typhon_repair','npc_post_reunion':'npc_post_reunion_repair','op_lin':'op_lin_costume'}
refs={r['id']:r for r in json.loads((B/'reference_manifest.json').read_text(encoding='utf-8'))}
assert set(refs)==set(ORDER)

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def bg(w,h):
    im=Image.new('RGB',(w,h),'#202a30');d=ImageDraw.Draw(im)
    for y in range(0,h,20):
        for x in range(0,w,20):
            if (x//20+y//20)%2: d.rectangle((x,y,x+19,y+19),fill='#253039')
    return im

def fit(im,w,h):
    im=im.convert('RGBA');a=im.getchannel('A');box=a.point(lambda v:255 if v>=128 else 0).getbbox()
    if box: im=im.crop(box)
    s=min(w/im.width,h/im.height)
    return im.resize((max(1,round(im.width*s)),max(1,round(im.height*s))),Image.Resampling.LANCZOS)

def put_fit(dest,im,rect):
    x,y,w,h=rect; im=fit(im,w,h)
    dest.paste(im,(x+(w-im.width)//2,y+h-im.height),im)

out=B/'paintings';out.mkdir(exist_ok=True)
contact=bg(1800,math.ceil(len(ORDER)/6)*600);cd=ImageDraw.Draw(contact)
records=[]; checks=[]
for i,ident in enumerate(ORDER):
    raw=B/'source_paintings'/(SELECT.get(ident,ident)+'.png')
    source=Image.open(raw).convert('RGBA')
    im=source.copy();im.putalpha(source.getchannel('A').point(lambda v:255 if v>=128 else 0))
    path=out/(ident+'.png');im.save(path)
    box=im.getchannel('A').getbbox()
    assert im.size[0]>120 and im.size[1]>240
    assert set(im.getchannel('A').get_flattened_data())=={0,255}
    assert im.convert('RGB').tobytes()==source.convert('RGB').tobytes(),'RGB painting changed'
    assert sha(B/refs[ident]['reference'])==refs[ident]['reference_sha256']
    compare_ref=refs[ident].get('comparison_reference',refs[ident]['reference'])
    if 'comparison_reference_sha256' in refs[ident]:
        assert sha(B/compare_ref)==refs[ident]['comparison_reference_sha256']
    margins=[box[0],box[1],im.width-box[2],im.height-box[3]]
    check=dict(id=ident,rgba=True,binary_alpha=True,original_rgb_preserved=True,reference_hash='PASS',
               size=list(im.size),opaque_bbox=list(box),clear_margins=margins,
               edge_clear=all(n>0 for n in margins))
    checks.append(check)
    rec=dict(id=ident,name=refs[ident]['name'],stage='1_CONCEPT_REVIEW',approval='PENDING',
             file=path.relative_to(B).as_posix(),size=list(im.size),sha256=sha(path),
             source=raw.relative_to(B).as_posix(),source_sha256=sha(raw),
             alpha_processing='A>=128 ->255, else 0; RGB unchanged; raw source preserved',
             reference=refs[ident]['reference'],reference_page=refs[ident]['reference_page'],comparison_reference=compare_ref,
             representative_color=refs[ident]['representative_color'],
             future_runtime_target='art/ui/portraits/'+ident+'.png',runtime_delivered=False)
    records.append(rec)
    x=(i%6)*300;y=(i//6)*600
    put_fit(contact,im,(x+12,y+30,276,515))
    cd.rectangle((x+10,y+551,x+289,y+555),fill=rec['representative_color'])
    cd.text((x+12,y+562),rec['name'],font=F,fill='#eef3f5')

    # Every character gets a separate official-reference vs new-painting page.
    comparison=bg(1040,1120);d=ImageDraw.Draw(comparison)
    d.text((24,16),rec['name']+' · 原画审阅',font=F,fill='white')
    d.text((30,58),'官方服装参考（仅核对，不描摹）',font=SM,fill='#b8c0c4')
    d.text((565,58),'本次新绘 · 正常比例全身站姿',font=SM,fill='#b8c0c4')
    put_fit(comparison,Image.open(B/rec['comparison_reference']),(24,92,484,948))
    put_fit(comparison,im,(540,92,476,948))
    d.line((520,55,520,1048),fill='#4a5258',width=2)
    d.text((24,1065),ident+' | 原画待确认，尚未缩至 120 x 240',font=SM,fill='#b8c0c4')
    comparison.save(B/'comparisons'/(ident+'.png'))

contact.save(B/'contact_sheet.png')
# Focused pages make nine operators and eight NPCs easier to inspect separately.
for title,subset in [('UA',ORDER[:9]),('UB',ORDER[9:])]:
    sheet=bg(1500,math.ceil(len(subset)/5)*650);d=ImageDraw.Draw(sheet)
    for i,ident in enumerate(subset):
        x=(i%5)*300;y=(i//5)*650
        put_fit(sheet,Image.open(out/(ident+'.png')),(x+10,y+12,280,584))
        d.text((x+12,y+610),refs[ident]['name'],font=F,fill='white')
    sheet.save(B/(title+'_contact.png'))

manifest=dict(batch='UA_UB_v1',stage='1_CONCEPT_REVIEW',asset_count=17,operators=9,npcs=8,
              generator='Built-in image_gen; 17 original paintings plus 6 targeted edit calls',
              style_reference='refs/style_patriot.png',approval='PENDING',
              runtime_downscaling='Not performed; requires concept approval per brief',files=records)
(B/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
report=dict(result='STATIC_CHECKS_PASS' if all(c['edge_clear'] for c in checks) else 'EDGE_REVIEW_NEEDED',
            files=17,checks=checks,source_paintings_preserved=True,
            visual_review='Generated outputs and contact sheets inspected. Six targeted edits: horn count, lettering, three framing corrections, Lin costume correction against default official art.',
            limits=['User concept approval pending.','No runtime PNGs produced.','No Godot import or runtime test.',
                    'Static alpha/hash/dimension checks do not establish character identity or costume acceptance.'])
(B/'qa_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')

cards=[]
for rec in records:
    cards.append(f'<article id="{rec["id"]}"><h2>{rec["name"]} <small>{rec["id"]}</small></h2><p><a href="{rec["reference_page"]}">PRTS 参考页</a> · 代表色 <code>{rec["representative_color"]}</code></p><a href="comparisons/{rec["id"]}.png"><img loading="lazy" src="comparisons/{rec["id"]}.png" alt="{rec["name"]}参考对照"></a><p><a href="{rec["file"]}">完整原画 PNG</a></p></article>')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>UA UB 立绘原画审阅</title><style>body{background:#12191e;color:#eef3f5;margin:32px;font:16px system-ui}a{color:#6fd8e4}h1{font-size:26px}h2{font-size:22px}small{font-size:14px;color:#9aa2a8}article{border-top:1px solid #4a5258;margin-top:32px;padding-top:16px}img{width:min(1040px,100%);height:auto}p{color:#b8c0c4}</style><h1>UA 9 + UB 8 · 第一阶段立绘原画</h1><p>粗描边平涂，正常人体比例。原画待确认；未制作 120×240 游戏图。</p><p><a href="contact_sheet.png">17 人总览</a> · <a href="UA_contact.png">干员总览</a> · <a href="UB_contact.png">NPC 总览</a> · <a href="README.md">交付说明</a></p>'''+''.join(cards)+'</html>'
(B/'review.html').write_text(html,encoding='utf-8')

archive=B.parent/'UA_UB_v1_stage1_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(B.rglob('*')):
        if p.is_file() and '__pycache__' not in p.parts and p.name!='package_check.json':
            z.write(p,'batch_UA_UB_v1/'+p.relative_to(B).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    count=len(z.namelist())
(B/'package_check.json').write_text(json.dumps(dict(zip=archive.name,crc='PASS',entries=count,sha256=sha(archive)),indent=2),encoding='utf-8')
print(json.dumps(dict(result=report['result'],portraits=17,edge_warnings=[c['id'] for c in checks if not c['edge_clear']],zip=str(archive)),ensure_ascii=False))
