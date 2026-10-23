"""Read saved deliverables back and validate the delivery contract independently."""
from pathlib import Path
from collections import deque
import json, sys, hashlib
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[4]
BATCH=ROOT/'art/characters/crew/batch_CR3_v1'
STAGE=ROOT/'art/characters/story/batch_ST1_v2/stage2'

def component_areas(mask):
    mask=mask.copy();areas=[]
    while mask.any():
        y,x=np.argwhere(mask)[0];q=deque([(int(y),int(x))]);mask[y,x]=False;area=0
        while q:
            y,x=q.popleft();area+=1
            for yy,xx in [(y-1,x),(y+1,x),(y,x-1),(y,x+1)]:
                if 0<=yy<mask.shape[0] and 0<=xx<mask.shape[1] and mask[yy,xx]:
                    mask[yy,xx]=False;q.append((yy,xx))
        areas.append(area)
    return sorted(areas,reverse=True)

def main():
    manifest=json.loads((BATCH/'manifest.json').read_text())
    assert len(manifest['sheets'])==4
    expected={(ident,kind) for ident in ['dobermann','kaltsit'] for kind in ['walk','idle']}
    assert {(s['id'],s['kind']) for s in manifest['sheets']}==expected
    checks=[]
    for sheet in manifest['sheets']:
        assert sheet['rows']==8 and sheet['cell']==256
        cols=4 if sheet['kind']=='walk' else 2;assert sheet['cols']==cols
        im=Image.open(BATCH/sheet['file']);assert im.mode=='RGBA' and im.size==(cols*256,2048)
        a=np.array(im)
        for r in range(8):
            for c in range(cols):
                cell=a[r*256:(r+1)*256,c*256:(c+1)*256]
                mask=cell[:,:,3]>=128;ys,xs=np.where(mask)
                assert len(xs)>0 and xs.min()>=8 and xs.max()<248 and ys.min()>=8 and ys.max()<=239
                # A second large disconnected figure fragment catches row
                # contamination even when the sheet dimensions are correct.
                areas=component_areas(mask)
                assert len(areas)<2 or areas[1]<areas[0]*.08,(sheet['file'],r,c,areas[:3])
                checks.append({'file':sheet['file'],'row':r,'col':c,'major_components':sum(x>=areas[0]*.08 for x in areas)})
            if sheet['kind']=='idle':
                left=a[r*256:(r+1)*256,:256];right=a[r*256:(r+1)*256,256:512]
                assert np.array_equal(left[192:],right[192:])
                assert np.array_equal(left[:152],right[8:160])
    for ident in ['dobermann','kaltsit']:
        im=Image.open(ROOT/f'art/ui/portraits/npc_{ident}.png');a=np.array(im)
        assert im.mode=='RGBA' and im.size==(120,240)
        assert set(np.unique(a[:,:,3]))=={0,255}
        assert im.getchannel('A').getbbox()[3]==240
    sys.path.insert(0,str(ROOT/'godot_assets'))
    from prepare_crew_atlas import sources
    discovered=sources()
    assert all(set(discovered[ident])>={'walk','idle'} for ident in ['dobermann','kaltsit'])
    report={'result':'PASS','cells_checked':len(checks),'breath_pairs':16,'portrait_files':2,
        'manifest_discovery':'Both characters found by prepare_crew_atlas.sources(); no runtime bake run.',
        'checks':checks,'not_proven':['art acceptance','Godot import','in-game animation playback','UI display']}
    (STAGE/'validation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('PASS: saved PNGs, 96 cell fragments, 16 breath pairs, portraits, runtime manifest discovery')

if __name__=='__main__':main()
