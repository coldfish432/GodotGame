"""Deterministic packaging/QA for 16 painted storage cases + 1 gift pack."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import argparse,hashlib,json,re,shutil
ROOT=Path(__file__).parent;PROJECT=ROOT.parents[3]
ITEMS=json.loads((ROOT/'items.json').read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def expected_sizes():
 text=(PROJECT/'game/collectibles.gd').read_text(encoding='utf-8-sig')
 line=re.search(r'const CASE_SIZES := \[([^\n]+)\]',text).group(1)
 grid=[(int(w),int(h)) for w,h in re.findall(r'Vector2i\((\d+), (\d+)\)',line)]
 return [(w*40-8,h*40-8) for w,h in grid]
def checker(d,box,step=12):
 x0,y0,x1,y1=box
 for y in range(y0,y1,step):
  for x in range(x0,x1,step):
   c='#303841' if ((x-x0)//step+(y-y0)//step)%2 else '#242b33'
   d.rectangle((x,y,min(x+step-1,x1-1),min(y+step-1,y1-1)),fill=c)
def package():
 meta=json.loads((ROOT/'generation.json').read_text(encoding='utf-8-sig'));(ROOT/'icons').mkdir(exist_ok=True)
 sizes=expected_sizes();assert sizes==[(72,72),(72,112),(112,152),(192,232)]
 catalog=(PROJECT/'game/collectibles.gd').read_text(encoding='utf-8-sig');resolver=(PROJECT/'ui/item_icons.gd').read_text(encoding='utf-8-sig')
 assert 'item.base_id = "case_%s" % kind' in catalog
 assert 'return "%s_%d" % [item.base_id, item.case_tier]' in resolver
 assert 'return "gift_pack"' in resolver
 for item in ITEMS:
  if item['id']!='gift_pack':
   assert item['id']==f"case_{item['kind']}_{item['tier']}" and f'"{item["kind"]}"' in catalog
 checks=[];issues=[]
 for item in ITEMS:
  ident=item['id'];m=meta[ident];p=Path(m['source_path']);local=ROOT/'sources'/(ident+'.png')
  if m['initial_source_path']!=str(p):
   rejected=ROOT/'sources'/'rejected';rejected.mkdir(exist_ok=True);shutil.copy2(m['initial_source_path'],rejected/(ident+'_initial.png'))
  shutil.copy2(p,local);im=Image.open(local).convert('RGBA');a=im.getchannel('A')
  assert a.getextrema()[0]==0,ident+': opaque background needs image_gen repair'
  box=a.point(lambda v:255 if v>24 else 0).getbbox();assert box
  if min(box[0],box[1],im.width-box[2],im.height-box[3])<2:issues.append({'id':ident,'problem':'source silhouette reaches edge; review clipping'})
  w,h=item['w'],item['h'];expected=(72,72) if ident=='gift_pack' else sizes[item['tier']-1];assert (w,h)==expected
  im=im.crop(box);pad=3 if max(w,h)<=112 else 5;scale=min((w-pad*2)/im.width,(h-pad*2)/im.height)
  size=(max(1,round(im.width*scale)),max(1,round(im.height*scale)))
  im=im.convert('RGBa').resize(size,Image.Resampling.LANCZOS).convert('RGBA');canvas=Image.new('RGBA',(w,h))
  canvas.alpha_composite(im,((w-im.width)//2,(h-im.height)//2));out=ROOT/'icons'/(ident+'.png');canvas.save(out)
  bbox=canvas.getchannel('A').getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<w and bbox[3]<h
  checks.append(dict(id=ident,name=item['name'],size=[w,h],mode='RGBA',bbox=list(bbox),source_bbox=list(box),transparent=True,sha256=sha(out),source_sha256=sha(local),resolver_match=True,status='PASS'))
 report=dict(total=17,passed=len(checks),static_status='PASS',source_issues=issues,art_acceptance='PENDING_USER_REVIEW',runtime_validation='NOT_RUN',checks=checks)
 (ROOT/'qa_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');previews();print(json.dumps({'passed':len(checks),'source_issues':issues}))
def previews():
 sheet=Image.new('RGB',(1088,1600),'#141b24');d=ImageDraw.Draw(sheet)
 font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16);small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',13)
 for k,item in enumerate(ITEMS):
  row,col=divmod(k,4);x,y=col*272,row*320;checker(d,(x+8,y+8,x+264,y+262))
  im=Image.open(ROOT/'icons'/(item['id']+'.png')).convert('RGBA');sheet.paste(im,(x+136-im.width//2,y+135-im.height//2),im)
  d.text((x+12,y+270),item['name']+f" {item['w']}×{item['h']}",font=font,fill='white');d.text((x+12,y+298),item['id'],font=small,fill='#b8c4d4')
 sheet.save(ROOT/'contact_sheet_native.png');sheet.resize((2176,3200),Image.Resampling.NEAREST).save(ROOT/'contact_sheet_2x.png')
def coverage():
 expected={}
 for batch in ['regional_v1','figurines_hd_v1']:
  q=json.loads((ROOT.parent/batch/'qa_report.json').read_text(encoding='utf-8'))
  for row in q['checks']:expected[row['id']]=tuple(row['size'])
 for item in ITEMS:expected[item['id']]=(item['w'],item['h'])
 assert len(expected)==67
 checks=[]
 for ident,size in expected.items():
  p=PROJECT/'art/items/runtime'/(ident+'.png')
  with Image.open(p) as im:
   assert im.size==size and im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
  checks.append({'id':ident,'size':list(size),'sha256':sha(p),'status':'PASS'})
 report={'brief':'收藏品与整理箱图标美术需求_v2.md','expected':67,'present':67,'static_status':'PASS','runtime_validation':'NOT_RUN','groups':{'regional_collectibles':32,'figurines':18,'storage_cases':16,'gift_pack':1},'checks':checks}
 (ROOT/'brief_coverage_67.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('Full brief file coverage: 67/67 PASS')
def deliver():
 q=json.loads((ROOT/'qa_report.json').read_text(encoding='utf-8'));assert q['passed']==17 and not q['source_issues']
 runtime=PROJECT/'art/items/runtime';baseline_path=ROOT/'runtime_baseline.json'
 if not baseline_path.exists():
  baseline={p.name:sha(p) for p in runtime.glob('*.png')};baseline_path.write_text(json.dumps(baseline,indent=2),encoding='utf-8')
 else:baseline=json.loads(baseline_path.read_text())
 for item in ITEMS:
  p=ROOT/'icons'/(item['id']+'.png');target=runtime/p.name
  if target.exists() and sha(target)!=sha(p):raise RuntimeError('Refusing to replace different existing icon '+str(target))
  shutil.copy2(p,target)
 targets={i['id']+'.png' for i in ITEMS}
 assert all(sha(runtime/name)==digest for name,digest in baseline.items() if name not in targets)
 assert all(sha(runtime/(i['id']+'.png'))==sha(ROOT/'icons'/(i['id']+'.png')) for i in ITEMS)
 q['delivery']={'runtime_count':17,'hash_match':True,'existing_unrelated_pngs_preserved':True}
 (ROOT/'qa_report.json').write_text(json.dumps(q,ensure_ascii=False,indent=2),encoding='utf-8');coverage();print('17 runtime PNGs delivered, hashes match, unrelated icons preserved.')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--deliver',action='store_true');args=p.parse_args()
 if args.deliver:deliver()
 else:package()
