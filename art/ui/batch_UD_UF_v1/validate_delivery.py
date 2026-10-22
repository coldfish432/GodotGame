from pathlib import Path
from PIL import Image,ImageStat
import json,hashlib,zipfile
B=Path(__file__).resolve().parent;ROOT=B.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
expect={n:(1280,360) for n in ('load_mine','load_city','load_snow','load_siracusa')}
expect['title']=(1280,720)
potions=['potion_'+x for x in ('d','e','f','g','h','i','j','k','l','rat','reunion','ursus','sami')]
expect.update({n:(32,32) for n in potions})
m=json.loads((B/'manifest.json').read_text(encoding='utf-8'))
assert len(m['files'])==18 and {r['id'] for r in m['files']}==set(expect)
checks=[];masks=set()
for r in m['files']:
 p=ROOT/r['file'];copy=B/'delivery'/r['file'];im=Image.open(p);im.load()
 assert im.size==expect[r['id']],r['id']
 assert p.read_bytes()==copy.read_bytes()
 assert sha(p)==r['sha256'] and sha(B/r['source'])==r['source_sha256']
 im=im.convert('RGBA');pixels=list(im.get_flattened_data());alpha={v[3] for v in pixels}
 colors={v[:3] for v in pixels if v[3]}
 details=dict(id=r['id'],result='PASS',size=list(im.size),visible_colors=len(colors),delivery_copy='MATCH',source_hash='PASS')
 if r['id'] in potions:
  assert alpha=={0,255}
  assert len(colors)<=24
  box=im.getchannel('A').getbbox();assert box
  assert box[0]>=2 and box[1]>=2 and box[2]<=30 and box[3]<=30
  mask=im.getchannel('A').tobytes();assert mask not in masks;masks.add(mask)
  details.update(alpha='BINARY',opaque_bbox=list(box))
  if r['id'] not in ('potion_rat','potion_reunion','potion_ursus','potion_sami'):
   pink=sum(a==255 and rr>110 and bb>70 and gg<rr*.7 for rr,gg,bb,a in pixels)
   assert pink>=1,f'Magenta family label lost: {r["id"]}'
   details['shared_label_pixels']=pink
 else:
  assert alpha=={255}
  # Every2x2 block must be uniform after integer nearest-neighbor pixel assembly.
  for y in range(0,im.height,2):
   for x in range(0,im.width,2):
    v=im.getpixel((x,y));assert v==im.getpixel((x+1,y))==im.getpixel((x,y+1))==im.getpixel((x+1,y+1))
  gray=im.convert('L');avg=ImageStat.Stat(gray).mean[0];details['mean_luma_0_255']=round(avg,2)
  if r['id']!='title':assert avg<115,'Loading card too bright'
  else:
   assert sum(rr>gg*1.1 and gg>bb*1.1 and rr>75 for rr,gg,bb,a in pixels)>100,'Ship ochre accent lost'
   left=ImageStat.Stat(gray.crop((32,160,392,500))).mean[0]
   right=ImageStat.Stat(gray.crop((978,100,1262,610))).mean[0]
   assert left<right
   details.update(title_left_luma=round(left,2),holo_right_luma=round(right,2))
 checks.append(details)
refs=json.loads((B/'reference_manifest.json').read_text(encoding='utf-8'))
assert all(sha(B/r['file'])==r['sha256'] for r in refs)
report=dict(result='PASS',assets=18,UD=5,UF=13,checks=checks,
 visual_review='Native and enlarged potion previews, dark/blue/brown slots with stack badge, title safe areas and all four cropped loading landmarks inspected.',
 limits=['No Godot import or runtime integration tested.','Final art acceptance remains pending.','Automatic checks do not prove absence of lettering or exact lore fidelity.'])
(B/'qa_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
archive=B.parent/'UD_UF_v1_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(B.rglob('*')):
  if p.is_file() and '__pycache__' not in p.parts and p.name!='package_check.json':
   z.write(p,'batch_UD_UF_v1/'+p.relative_to(B).as_posix())
with zipfile.ZipFile(archive) as z:assert z.testzip() is None;count=len(z.namelist())
(B/'package_check.json').write_text(json.dumps(dict(result='PASS',archive=archive.name,entries=count,crc='PASS',sha256=sha(archive)),indent=2),encoding='utf-8')
print('18/18 PASS; ZIP CRC PASS:',archive)
