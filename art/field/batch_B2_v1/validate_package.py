from pathlib import Path
import json,hashlib,sys,zipfile
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'pipeline'))
import bake_n2 as bake
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    meta=json.loads((ROOT/'manifest.json').read_text())
    native=Image.open(ROOT/'identity_64.png').convert('RGBA');a=np.array(native)
    assert native.size==(64,64)
    assert set(np.unique(a[:,:,3]))=={0,255}
    box=native.getbbox();assert box[3]-box[1]==26
    assert 0<box[0]<box[2]<64 and 0<box[1]<box[3]<64
    assert len(np.unique(a[a[:,:,3]>0,:3],axis=0))<=17
    enlarged=np.array(Image.open(ROOT/'identity_64_x6.png').convert('RGBA'))
    assert np.array_equal(enlarged,np.repeat(np.repeat(a,6,0),6,1))
    assert sha(ROOT/'sources/civilian_identity_raw.png')==meta['source_sha256']
    clean=Image.open(ROOT/'identity.png').convert('RGBA');assert clean.size==(256,256)
    # Audit the actual64px composition BEFORE any possible edge clipping.
    original=Image.Image.alpha_composite;placements=[]
    def checked(self,im,dest=(0,0),source=(0,0)):
        if self.size==(64,64) and im.getbbox():
            b=im.getbbox();x,y=dest;assert min(x+b[0],y+b[1])>=0 and max(x+b[2],y+b[3])<=64;placements.append(1)
        return original(self,im,dest,source)
    Image.Image.alpha_composite=checked
    try:replay=bake.bake_cell(clean,meta['native_bake_scale'],Image.Quantize.FASTOCTREE,fit_within_cell=True)
    finally:Image.Image.alpha_composite=original
    assert replay.tobytes()==native.tobytes() and len(placements)==1
    for name,h in meta['pipeline_hashes'].items():assert sha(ROOT/'pipeline'/name)==h
    inputdir=ROOT.parent/'B2_inputs_v1'
    if inputdir.exists():
        for name,h in meta['pipeline_hashes'].items():assert sha(inputdir/name)==h
    for name in ['identity.png','identity_vs_prts.png','identity_with_cast.png','identity_on_ground.png']:
        assert (ROOT/name).stat().st_size>0
    assert not list(ROOT.glob('civilian_action*.png')) and not list(ROOT.glob('civilian_walk*.png'))
    report={'status':'PASS','stage':1,'visible_native_height':26,'native_cell':[64,64],'source_canvas':[256,256],'pipeline_modified':False,'native_replay':'EXACT','clipped_native_pixels':0,'x6':'EXACT_NEAREST','required_identity_deliverables':4,'boards_started':False,'art_acceptance':'PENDING_USER_REVIEW','runtime_verified':False,'ground':'Offline screenshot composite; assumed1.5x and native1x overlays, not verified camera projection.'}
    (ROOT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    files=[p for p in sorted(ROOT.rglob('*')) if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ['.pyc','.b64','.import'] and p.name!='delivery_manifest.json']
    (ROOT/'delivery_manifest.json').write_text(json.dumps({p.relative_to(ROOT).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in files},indent=2),encoding='utf-8')
    files.append(ROOT/'delivery_manifest.json')
    archive=ROOT.parent.parent/'_to_sol/B2_stage1_identity_v1_review.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in files:z.write(p,'batch_B2_v1/'+p.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for p in files:assert hashlib.sha256(z.read('batch_B2_v1/'+p.relative_to(ROOT).as_posix())).hexdigest()==sha(p)
    receipt={'archive':archive.name,'bytes':archive.stat().st_size,'sha256':sha(archive),'members':len(files),'crc':'PASS','all_members_match':True}
    archive.with_suffix('.zip.qa.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print(json.dumps({'validation':report,'archive':receipt}))
if __name__=='__main__':main()
