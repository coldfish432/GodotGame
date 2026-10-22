"""Audit source grids, real pre-crop bounds, bake pixels and protected identities."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
FIELD=ROOT.parent
sys.path.insert(0,str(FIELD))
import bake_n2 as bake

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    jobs=json.loads((ROOT/'generation_records.json').read_text())['jobs']
    original=Image.Image.alpha_composite
    captures=[]
    def traced(self,other,dest=(0,0),source=(0,0)):
        if self.size==(64,64):
            alpha=np.array(other)[:,:,3]>0
            ys,xs=np.where(alpha)
            dx,dy=dest
            outside=(xs+dx<0)|(ys+dy<0)|(xs+dx>=64)|(ys+dy>=64)
            captures.append({'unclipped_size':other.size,'dest':dest,'discarded_opaque_pixels':int(outside.sum()),'uncropped_bbox':[int(xs.min()+dx),int(ys.min()+dy),int(xs.max()+dx+1),int(ys.max()+dy+1)] if len(xs) else None})
        return original(self,other,dest,source)
    Image.Image.alpha_composite=traced
    boards=[];issues=[];feet=[];cells_total=0
    for j in jobs:
        id,kind,rows=j['id'],j['kind'],j['rows']
        path=ROOT/f'{id}_{kind}.png'
        src=Image.open(path).convert('RGBA')
        assert src.size==(2048,256*rows)
        action=Image.open(ROOT/f'{id}_action.png').convert('RGBA')
        box=bake.figure_box(np.array(action.crop((0,0,256,256))))
        scale=bake.b1_reference_scale(action.crop((0,0,256,256)),bake.EXTRA_HEIGHTS[id],bake.QUANTIZE[id])
        runtime=Image.open(ROOT/f'{id}_{kind}_64.png').convert('RGBA')
        assert runtime.size==(512,rows*64)
        assert set(np.unique(np.array(runtime)[:,:,3]))<={0,255}
        preview=Image.open(ROOT/f'{id}_{kind}_64_x6.png').convert('RGBA')
        assert preview.tobytes()==runtime.resize((3072,rows*384),Image.Resampling.NEAREST).tobytes()
        frames=[]
        if kind=='action':
            idle=runtime.crop((0,0,64,64)).getbbox()
            assert idle[3]-idle[1]==bake.EXTRA_HEIGHTS[id],(id,idle)
        for r in range(rows):
            for c in range(8):
                cell=src.crop((c*256,r*256,(c+1)*256,(r+1)*256))
                captures.clear()
                expected=bake.bake_cell(cell,scale,bake.QUANTIZE[id],fit_within_cell=True)
                actual=runtime.crop((c*64,r*64,(c+1)*64,(r+1)*64))
                assert expected.tobytes()==actual.tobytes(),(id,kind,r,c)
                assert captures and actual.getbbox()
                q=captures[-1]
                q.update({'row':r+1,'col':c+1,'native_bbox':actual.getbbox()})
                frames.append(q);cells_total+=1
                if q['discarded_opaque_pixels']>0:issues.append({'id':id,'kind':kind,**q})
                if q['native_bbox'][3]>53:feet.append({'id':id,'kind':kind,**q})
        boards.append({'id':id,'kind':kind,'rows':rows,'scale':scale,'quantizer':'FASTOCTREE','source_sha256':sha(path),'runtime_sha256':sha(ROOT/f'{id}_{kind}_64.png'),'frames':frames})
    Image.Image.alpha_composite=original
    protected=[]
    old=json.loads((FIELD/'batch_B1_v1/manifest.json').read_text())
    for e in old['figures']:
        for key,hashkey in [('source','source_sha256'),('native_cell','native_cell_sha256')]:
            assert sha(FIELD/'batch_B1_v1'/e[key])==e[hashkey]
        protected.append(e['id'])
    new=json.loads((FIELD/'batch_B1_v2/provenance.json').read_text())
    for e in new['sources']:assert sha(FIELD/'batch_B1_v2'/e['file'])==e['sha256']
    report={'static_checks':'PASS' if not issues else 'FAIL_PRE_CROP_CLIPPING','boards':len(boards),'cells':cells_total,'source_grids':'8 columns,256px square cells, correct row counts','native_alpha':'binary','previews':'exact x6 nearest','official_bake_pixel_equality':'PASS for every cell','walk_scale_from_action':'PASS same first action cell used for both kinds','protected_v1_and_v2_sources':'PASS all recorded hashes unchanged','pre_crop_clipping':issues,'foot_baseline_findings':feet,'bake_script_sha256':sha(FIELD/'bake_n2.py'),'approved_package_bake_sha256':sha(FIELD/'B1_stage2_inputs/bake_n2.py'),'visual_acceptance':'PENDING user; technical checks do not establish direction, anatomy, same physical size, prop continuity or pose quality','godot_import_and_playback':'NOT TESTED','boards_detail':boards}
    report['bake_patch']='B1-only x placement clamp for fitting asymmetric silhouettes; oversized poses raise ValueError; non-B1 default unchanged. See pipeline/bake_n2_original.py and bake_patch.diff.'
    (ROOT/'qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['static_checks','boards','cells']},indent=2))
    print('CLIPPED',len(issues),'FOOT_FINDINGS',len(feet))
    for q in issues:print(q['id'],q['kind'],q['row'],q['col'],q['discarded_opaque_pixels'],q['unclipped_size'])

if __name__=='__main__':main()
