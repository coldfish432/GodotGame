"""Read final files independently; report technical checks, not art acceptance."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from build_crew import ROOT, IDS1, IDS2

def validate(part):
    batch=ROOT/f'batch_CR{part}_v1'
    ids=IDS1 if part==1 else IDS2
    manifest=json.loads((batch/'manifest.json').read_text(encoding='utf-8'))
    entries=manifest['sheets']
    assert len(entries)==16
    assert {(s['id'],s['kind']) for s in entries}=={(i,k) for i in ids for k in ['walk','idle']}
    frames=0
    hashes={}
    for s in entries:
        cols=4 if s['kind']=='walk' else 2
        assert (s['cols'],s['rows'],s['cell'])==(cols,8,256)
        path=batch/s['file']
        with Image.open(path) as im:
            assert im.mode=='RGBA' and im.size==(cols*256,2048)
            a=np.array(im)
            assert a[:,:,3].min()==0 and a[:,:,3].max()==255
            for r in range(8):
                for c in range(cols):
                    cell=a[r*256:(r+1)*256,c*256:(c+1)*256]
                    assert cell[:,:,3].max()>0
                    assert not cell[:8,:,3].any() and not cell[248:,:,3].any()
                    assert not cell[:,:8,3].any() and not cell[:,248:,3].any()
                    frames+=1
                if cols==2:
                    first=a[r*256:(r+1)*256,:256]
                    second=a[r*256:(r+1)*256,256:]
                    assert np.array_equal(first[192:],second[192:])
                    assert not np.array_equal(first[:160],second[:160])
                    top0=Image.fromarray(first).getbbox()[1]
                    top1=Image.fromarray(second).getbbox()[1]
                    assert top1-top0==8,(s['id'],r,top0,top1)
        hashes[s['file']]=hashlib.sha256(path.read_bytes()).hexdigest()
    preview=Image.open(batch/'preview_32.png')
    assert preview.mode=='RGBA' and preview.size==(256,32)
    report={'status':'TECHNICAL_PASS','characters':8,'sheets':16,'frames':frames,'format':'walk 1024x2048; idle 512x2048; 256px cells; real RGBA','knees_and_below':'64/64 idle frame pairs pixel-identical; cutoff local y192','idle_pairs_checked':64,'head_drop_px':8,'blind_identity_test':'PENDING independent human reviewer','foot_sole_and_body_anchor_review':'PENDING visual review; automated check normalizes foreground baseline, not anatomical landmarks','animation_playback':'NOT TESTED IN ENGINE','manual_direction_review':'See review notes and direction contact sheet; technical pass is not final art acceptance','sha256':hashes}
    (batch/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(f'CR{part} TECHNICAL_PASS: 8 characters, 16 sheets, {frames} frames, 64 identical idle lower-body pairs')

if __name__=='__main__':
    import sys
    validate(int(sys.argv[1]))
