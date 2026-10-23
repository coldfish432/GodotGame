"""Read-back checks and hash-verified E16 review archive."""
from pathlib import Path
import json,hashlib,zipfile
import numpy as np
from PIL import Image

B=Path(__file__).resolve().parent
ROOT=B.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
 manifest=json.loads((B/'manifest.json').read_text(encoding='utf-8'))
 qa=json.loads((B/'qa_report.json').read_text(encoding='utf-8'));assert qa['status']=='PASS'
 assert len(manifest['items'])==5
 emissions=[]
 for s in manifest['items']:
  p=B/s['file'];im=Image.open(p);a=np.array(im)
  assert im.mode=='RGBA' and list(im.size)==s['native_size']
  assert set(np.unique(a[:,:,3]))=={0,255}
  assert sha(p)==s['sha256'] and sha(B/s['source'])==s['source_sha256']
  big=Image.open(B/(s['id']+'_8x.png'))
  assert np.array_equal(np.array(big),np.repeat(np.repeat(a,8,0),8,1))
  if s['has_emit']:
   e=np.array(Image.open(B/s['emit_file']));m=e[:,:,3]>0
   assert e.shape==a.shape and m.any() and set(np.unique(e[:,:,3]))<={0,255}
   assert np.array_equal(e[m],a[m]) and np.all(a[:,:,3][m]==255)
   emissions.append(s['emit_file'])
 assert set(emissions)=={'rhodes_head_heavy_emit.png','rhodes_ring_monitor_emit.png'}
 assert set(p.name for p in B.glob('*_emit.png'))==set(emissions)
 protected=json.loads((B/'protected_before.json').read_text(encoding='utf-8'))
 assert all((ROOT/p).is_file() and sha(ROOT/p)==h for p,h in protected.items())
 report=dict(status='PASS',icons=5,emit_masks=2,exact_8x_copies=5,protected_files=len(protected),protected_changed=0,
  runtime_verified=False,art_accepted=False)
 dump(B/'verification_report.json',report)
 paths=[p for p in B.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.import' and p.name!='delivery_files.json']
 inventory={str(p.relative_to(B)).replace('\\','/'):sha(p) for p in sorted(paths)}
 dump(B/'delivery_files.json',inventory);paths.append(B/'delivery_files.json')
 archive=B.parent/'E16_v1_review.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
  for p in sorted(paths):z.write(p,str(Path(B.name)/p.relative_to(B)))
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for name,h in inventory.items():assert hashlib.sha256(z.read(B.name+'/'+name)).hexdigest()==h
  assert len(z.namelist())==len(paths)
 print('PASS: 5 icons, 2 emit masks, 5 exact 8x previews,',len(protected),'protected files unchanged')
 print('ZIP CRC + content hashes PASS:',len(paths),'files;',archive.stat().st_size,'bytes;',archive)

if __name__=='__main__':main()
