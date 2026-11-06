"""Pack image_gen figurine renders; no procedural painting or creative image edits."""
from pathlib import Path
import argparse,hashlib,json,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).parent
PROJECT=ROOT.parents[3]
ITEMS=json.loads((ROOT/'items.json').read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def checker(d,box,step=16):
 x0,y0,x1,y1=box
 for y in range(y0,y1,step):
  for x in range(x0,x1,step):
   color='#30363f' if ((x-x0)//step+(y-y0)//step)%2 else '#242b33'
   d.rectangle((x,y,min(x+step-1,x1-1),min(y+step-1,y1-1)),fill=color)
def package():
 meta=json.loads((ROOT/'generation.json').read_text(encoding='utf-8-sig'))
 (ROOT/'icons').mkdir(exist_ok=True);checks=[];issues=[]
 registry=(PROJECT/'ui/item_icons.gd').read_text(encoding='utf-8-sig')
 for item in ITEMS:
  ident=item['id'];m=meta[ident];source=Path(m['source_path']);local=ROOT/'sources'/(ident+'.png')
  if m['initial_source_path']!=str(source):
   rejected=ROOT/'sources'/'rejected';rejected.mkdir(exist_ok=True)
   shutil.copy2(m['initial_source_path'],rejected/(ident+'_initial.png'))
  # Copy selected generation intact, including alpha.
  shutil.copy2(source,local)
  im=Image.open(local).convert('RGBA');a=im.getchannel('A');extrema=a.getextrema()
  if extrema[0]!=0:issues.append({'id':ident,'problem':'source background has no fully clear alpha'})
  assert extrema[0]==0,ident+': must repair background with image_gen'
  box=a.point(lambda v:255 if v>32 else 0).getbbox();assert box
  source_size=list(im.size)
  near_edge=box[0]<2 or box[1]<2 or box[2]>im.width-2 or box[3]>im.height-2
  if near_edge:issues.append({'id':ident,'problem':'source silhouette touches image edge; inspect for clipping','bbox':list(box)})
  # Deterministic alpha trim + proportional resampling, never stretch or redraw.
  im=im.crop(box);scale=min(452/im.width,944/im.height)
  size=(max(1,round(im.width*scale)),max(1,round(im.height*scale)))
  im=im.convert('RGBa').resize(size,Image.Resampling.LANCZOS).convert('RGBA')
  out=Image.new('RGBA',(512,1024));out.alpha_composite(im,((512-im.width)//2,994-im.height))
  path=ROOT/'icons'/(ident+'.png');out.save(path)
  alpha=out.getchannel('A');bbox=alpha.getbbox()
  assert bbox and bbox[0]>=29 and bbox[1]>=49 and bbox[2]<=483 and bbox[3]<=995
  assert f'"{ident}"' in registry
  checks.append(dict(id=ident,name=item['name'],size=[512,1024],mode='RGBA',bbox=list(bbox),alpha_min=alpha.getextrema()[0],source_size=source_size,source_bbox=list(box),source_near_edge=near_edge,sha256=sha(path),source_sha256=sha(local),registry_match=True,status='PASS'))
 report=dict(total=18,passed=len(checks),static_status='PASS',generation='built-in image_gen',source_issues=issues,runtime_validation='NOT_RUN',art_acceptance='PENDING_FINAL_USER_REVIEW',identity_approval='User approved initial 18-character rough lineup before HD generation',checks=checks)
 (ROOT/'qa_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 previews();print(json.dumps({'passed':len(checks),'source_issues':issues}))
def previews():
 font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',21);small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',16)
 hd=Image.new('RGB',(1800,1860),'#141b24');d=ImageDraw.Draw(hd)
 hover=Image.new('RGB',(1200,1020),'#141b24');h=ImageDraw.Draw(hover)
 tiny=Image.new('RGB',(1200,450),'#141b24');t=ImageDraw.Draw(tiny)
 colors={'green':'#68b978','blue':'#58a9dd','purple':'#b78ade','red':'#f16b73'}
 for k,item in enumerate(ITEMS):
  row,col=divmod(k,6);ident=item['id'];im=Image.open(ROOT/'icons'/(ident+'.png')).convert('RGBA')
  x,y=col*300,row*620;checker(d,(x+10,y+12,x+290,y+558));thumb=im.resize((256,512),Image.Resampling.LANCZOS)
  hd.paste(thumb,(x+22,y+24),thumb);d.text((x+14,y+566),f"{k+1:02d} {item['name']}",font=font,fill='white');d.text((x+14,y+595),ident,font=small,fill='#b8c4d4')
  x,y=col*200,row*340;checker(h,(x+10,y+10,x+190,y+282),12);thumb=im.resize((120,240),Image.Resampling.LANCZOS)
  hover.paste(thumb,(x+40,y+24),thumb);h.text((x+10,y+292),item['name'],font=font,fill='white')
  x,y=col*200,row*150;checker(t,(x+10,y+8,x+190,y+108),8);thumb=im.resize((32,64),Image.Resampling.LANCZOS)
  tiny.paste(thumb,(x+84,y+24),thumb);t.text((x+10,y+118),item['name'],font=font,fill='white')
 hd.save(ROOT/'contact_sheet_hd.png');hover.save(ROOT/'contact_sheet_120px.png');tiny.save(ROOT/'contact_sheet_32x64.png')
def deliver():
 report=json.loads((ROOT/'qa_report.json').read_text(encoding='utf-8'));assert report['passed']==18
 assert not report['source_issues'],'Resolve source clipping/background issues before delivery'
 runtime=PROJECT/'art/items/runtime';baseline_path=ROOT/'runtime_baseline.json'
 if not baseline_path.exists():
  baseline={p.name:sha(p) for p in runtime.glob('*.png')};baseline_path.write_text(json.dumps(baseline,indent=2),encoding='utf-8')
 else:baseline=json.loads(baseline_path.read_text())
 for item in ITEMS:
  p=ROOT/'icons'/(item['id']+'.png');target=runtime/p.name
  if target.exists() and sha(target)!=sha(p):raise RuntimeError('Refusing to replace different existing PNG '+str(target))
  shutil.copy2(p,target)
 targets={i['id']+'.png' for i in ITEMS}
 assert all(sha(runtime/name)==digest for name,digest in baseline.items() if name not in targets)
 assert all(sha(runtime/(i['id']+'.png'))==sha(ROOT/'icons'/(i['id']+'.png')) for i in ITEMS)
 report['delivery']={'runtime_count':18,'hash_match':True,'existing_unrelated_pngs_preserved':True}
 (ROOT/'qa_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print('18 runtime PNGs delivered; hashes match; unrelated PNGs unchanged.')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--deliver',action='store_true');args=p.parse_args()
 if args.deliver:deliver()
 else:package()
