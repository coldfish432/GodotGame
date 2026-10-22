"""Static revision contract checks; does not claim Godot or art acceptance."""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'pipeline'))
import bake_n2 as bake
CHANGES={'patriot_action':[8,9],'patriot_walk':[5,6,7,8],'eikthyrnir_action':[9],'zaro_action':[7,8]}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def same(a,b):return a.size==b.size and a.convert('RGBA').tobytes()==b.convert('RGBA').tobytes()
def main():
    hashes=json.loads((ROOT/'full_baseline_hashes.json').read_text())
    live=ROOT.parent/'batch_B1_v3'
    for name,h in hashes.items():
        assert sha(ROOT/'baseline'/name)==h,name
        if live.exists():assert sha(live/name)==h,('v3 mutated',name)
    reference_baker=ROOT.parent/'B1_stage2_revision_inputs'/'bake_n2.py'
    if reference_baker.exists():assert sha(reference_baker)==sha(ROOT/'pipeline/bake_n2.py')
    runtime_preserved=source_preserved=source_changed=replayed=0
    placements=[];metrics={};scales={}
    original_composite=Image.Image.alpha_composite
    def guarded(self,im,dest=(0,0),source=(0,0)):
        if self.size==(64,64) and im.getbbox():
            b=im.getbbox();x,y=dest
            assert x+b[0]>=0 and y+b[1]>=0 and x+b[2]<=64 and y+b[3]<=64,('clipped',im.size,dest,b)
            placements.append([x+b[0],y+b[1],x+b[2],y+b[3]])
        return original_composite(self,im,dest,source)
    for key,rows in CHANGES.items():
        clean=Image.open(ROOT/(key+'.png')).convert('RGBA')
        native=Image.open(ROOT/(key+'_64.png')).convert('RGBA')
        old=Image.open(ROOT/'baseline'/(key+'.png')).convert('RGBA')
        old_native=Image.open(ROOT/'baseline'/(key+'_64.png')).convert('RGBA')
        assert clean.size==old.size and clean.width==2048
        assert native.size==(512,clean.height//4)
        assert same(native.resize((native.width*6,native.height*6),Image.Resampling.NEAREST),Image.open(ROOT/(key+'_64_x6.png')))
        enemy=key.rsplit('_',1)[0]
        ref=Image.open(ROOT/(enemy+'_action.png')).convert('RGBA')
        scale=bake.b1_reference_scale(ref.crop((0,0,256,256)),bake.EXTRA_HEIGHTS[enemy],bake.QUANTIZE[enemy])
        scales[key]=scale
        metrics[key]=[]
        for r in range(clean.height//256):
            for c in range(8):
                b=(c*256,r*256,(c+1)*256,(r+1)*256)
                bn=(c*64,r*64,(c+1)*64,(r+1)*64)
                cell=clean.crop(b);native_cell=native.crop(bn)
                if r+1 in rows:
                    assert not same(cell,old.crop(b));assert cell.getbbox();source_changed+=1
                    bounds=native_cell.getbbox()
                    metrics[key].append({'row':r+1,'column':c+1,'native_bbox':bounds,'width':bounds[2]-bounds[0],'height':bounds[3]-bounds[1]})
                else:
                    assert same(cell,old.crop(b)),('source changed',key,r,c);source_preserved+=1
                    assert same(native_cell,old_native.crop(bn)),('runtime changed',key,r,c);runtime_preserved+=1
                Image.Image.alpha_composite=guarded
                try:output=bake.bake_cell(cell,scale,bake.QUANTIZE[enemy],fit_within_cell=True)
                finally:Image.Image.alpha_composite=original_composite
                assert same(output,native_cell),('bake replay',key,r,c)
                replayed+=1
    assert source_changed==72 and source_preserved==208 and runtime_preserved==208 and replayed==280
    result={'status':'PASS','baseline_files_verified':len(hashes),'source_cells_changed':source_changed,'source_cells_preserved_in_changed_boards':source_preserved,'native_cells_preserved_in_changed_boards':runtime_preserved,'official_baker_cells_replayed':replayed,'bake_placements_checked_before_compositing':len(placements),'clipped_placements':0,'exact_nearest_x6_previews':4,'baker_sha256':sha(ROOT/'pipeline/bake_n2.py'),'scales':scales,'changed_cell_metrics':metrics,'limits':['Static asset verification only; no Godot import or animation playback test.','Shape, identity and pose acceptance remains a human review.']}
    (ROOT/'qa').mkdir(exist_ok=True)
    (ROOT/'qa/validation_report.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['changed_cell_metrics','scales']}))
if __name__=='__main__':main()
