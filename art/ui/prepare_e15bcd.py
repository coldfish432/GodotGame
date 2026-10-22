from pathlib import Path
import re,json,shutil,hashlib
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[2]
I=R/'art/items';W=R/'art/ui/work_E15bcd_v1';W.mkdir(exist_ok=True)
text=(I/'E15_slot_split_brief_v1.md').read_text(encoding='utf-8')
refids=['inspector_armor','city_x13','bone_lamellar','snow_x15','snow_x14','rhodes_field_uniform','rhodes_protective_vest']
refs=W/'refs';refs.mkdir(exist_ok=True)
for id in refids:
    src=I/'runtime'/(id+'.png');assert src.exists(),src
    shutil.copy2(src,refs/src.name)
    im=Image.open(src).convert('RGBA');im.resize((im.width*8,im.height*8),Image.Resampling.NEAREST).save(refs/(id+'_8x.png'))
shutil.copy2(I/'batch_E15a_v1/overview.png',refs/'accepted_E15a_overview.png')
shutil.copy2(I/'E15a_accepted_go_E15bcd.md',W/'acceptance_snapshot.md')
shutil.copy2(I/'E15_slot_split_brief_v1.md',W/'brief_snapshot.md')
jobs=[]
cloth_ids={'city_head_1','city_hands_1','city_hands_2','city_legs_1','city_legs_2','city_legs_3','city_legs_4','city_feet_1','snow_head_2','snow_hands_2','snow_hands_3','snow_legs_1','snow_legs_2','snow_legs_3','snow_legs_4','rhodes_hands','rhodes_legs'}
for prefix,batch in [('city','E15b'),('snow','E15c'),('rhodes','E15d')]:
    B=W/('batch_'+batch+'_v1');(B/'sources').mkdir(parents=True,exist_ok=True);(B/'refs').mkdir(exist_ok=True)
    for p in refs.iterdir():shutil.copy2(p,B/'refs'/p.name)
    for p in ['brief_snapshot.md','acceptance_snapshot.md']:shutil.copy2(W/p,B/p)
    for line in text.splitlines():
        if not line.startswith('| '+prefix+'_'):continue
        cols=[c.strip() for c in line.strip('|').split('|')]
        id,slot,name=cols[:3];layer=int(cols[3]) if prefix!='rhodes' else None;desc=cols[4] if prefix!='rhodes' else cols[3]
        matchref={'city_head_4':'inspector_armor','city_legs_4':'city_x13','snow_head_3':'snow_x15','snow_hands_4':'bone_lamellar','snow_legs_4':'bone_lamellar'}.get(id)
        if prefix=='rhodes':matchref='rhodes_field_uniform'
        jobs.append(dict(id=id,slot=slot.lower(),name=name,layer=layer,description=desc,batch=batch,cloth=id in cloth_ids,matchref=matchref,size=32 if slot.lower()=='ring' else 72))
    (B/'edits.json').write_text('[]',encoding='utf-8')
    (B/'refs/.gdignore').write_text('');(B/'sources/.gdignore').write_text('')
(W/'jobs.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2),encoding='utf-8')
protected=[p for p in (I/'runtime').glob('*.png')]+[p for p in (I/'batch_E15a_v1').rglob('*') if p.is_file() and '__pycache__' not in p.parts]
(W/'protected_hashes.json').write_text(json.dumps({str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected},indent=2),encoding='utf-8')
sheet=Image.new('RGB',(4*320,2*360),'#2c2e30');d=ImageDraw.Draw(sheet)
for n,id in enumerate(refids):
    im=Image.open(refs/(id+'.png')).convert('RGBA');im=im.resize((288,288),Image.Resampling.NEAREST);x=(n%4)*320;y=(n//4)*360;sheet.paste(im,(x+16,y),im);d.text((x+12,y+306),id,fill='white')
sheet.save(W/'reference_chests.png')
print(json.dumps(jobs,ensure_ascii=False))
