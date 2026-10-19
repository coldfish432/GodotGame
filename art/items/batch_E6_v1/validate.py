"""Read-only pixel-level delivery validator; writes only validation.json."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
IDS13='family_stiletto brass_knuckles switchblade old_town_crowbar barber_razor cane_sword butcher_cleaver vineyard_billhook eraser_curved_blade lead_cane wolfhead_knuckles saluzzo_crest'.split()
IDS6='rhodes_dual_blades rhodes_sword rhodes_field_uniform rhodes_protective_vest rhodes_beacon rhodes_medkit rhodes_badge'.split()
EMIT={'rhodes_dual_blades','rhodes_protective_vest','rhodes_beacon'}
LOGOS={'rhodes_field_uniform':(58,24),'rhodes_protective_vest':(45,27),'rhodes_beacon':(12,17),'rhodes_medkit':(14,14),'rhodes_badge':(11,16)}
PALETTE6=set('0b0c0d 15181a 1f2427 2c3236 3d4448 566064 737d82 98a2a6 c3cacc a9b2b3 d4dadb eef2f2 385878 5888a8 78b8e8 6e2f14 b8531f e0782a 0f3a40 2a8a92 5fd0d8 b8f4f6 6b5a1e b89a2a f4d73c'.split())
GROUPS=[set(s.split()) for s in ['385878 5888a8 78b8e8','6e2f14 b8531f e0782a','0f3a40 2a8a92 5fd0d8 b8f4f6','6b5a1e b89a2a f4d73c']]

def validate(root):
    ids=IDS6 if root.name=='batch_E6_v1' else IDS13
    manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
    assert [e['id'] for e in manifest]==ids
    assert {p.stem[:-5] for p in root.glob('*_emit.png')}==set(ids)&EMIT
    summary=[]
    for e in manifest:
        item=e['id'];im=Image.open(root/f'{item}.png').convert('RGBA');a=np.array(im)
        expected=(72,72) if item in ['rhodes_field_uniform','rhodes_protective_vest'] else ((32,32) if item in ['saluzzo_crest','rhodes_beacon','rhodes_medkit','rhodes_badge'] else (72,32))
        assert im.size==expected
        assert set(np.unique(a[:,:,3]).tolist())=={0,255}
        mask=a[:,:,3]>0;p=a[:,:,:3];colors=np.unique(p[mask],axis=0)
        assert len(colors)<=24
        # Independent neighbour check with padding (no edge wrapping).
        pad=np.pad(a,((1,1),(1,1),(0,0)))
        same=np.zeros(mask.shape,bool)
        for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
            q=pad[1+dy:1+dy+a.shape[0],1+dx:1+dx+a.shape[1]]
            same|=(q[:,:,3]>0)&np.all(q[:,:,:3]==p,2)
        isolated=100*np.count_nonzero(mask & ~same)/np.count_nonzero(mask)
        bright=100*np.count_nonzero(mask & ((p@np.array([.2126,.7152,.0722]))>=153))/np.count_nonzero(mask)
        assert isolated<=10,(item,'isolated',isolated)
        assert bright>=15,(item,'bright',bright)
        assert abs(round(isolated,2)-e['isolated_pixel_percent'])<.001
        assert abs(round(bright,2)-e['bright_pixel_percent'])<.001
        big=np.array(Image.open(root/f'{item}_8x.png').convert('RGBA'))
        assert np.array_equal(big,np.repeat(np.repeat(a,8,0),8,1))
        assert hashlib.sha256((root/e['source']).read_bytes()).hexdigest()==e['source_sha256']
        assert hashlib.sha256((root/e['file']).read_bytes()).hexdigest()==e['file_sha256']
        if root.name=='batch_E6_v1':
            assert {bytes(c).hex() for c in colors}<=PALETTE6
            accents=[]
            for group in GROUPS:
                accents.append(sum(np.count_nonzero(mask & np.all(p==tuple(bytes.fromhex(h)),2)) for h in group)/np.count_nonzero(mask)*100)
            assert sum(accents)<=10 and max(accents)<=6,(item,'accents',accents)
            assert e['largest_flat_region_percent']<=25
        if item in LOGOS:
            logo=np.array(Image.open(root/'sources/rhodes_logo_S_9.png').convert('RGBA'))
            x,y=LOGOS[item];crop=a[y:y+9,x:x+9]
            assert np.array_equal(crop[logo[:,:,3]>0],logo[logo[:,:,3]>0]),(item,'logo')
        if item in EMIT:
            b=np.array(Image.open(root/f'{item}_emit.png').convert('RGBA'));bm=b[:,:,3]>0
            assert b.shape==a.shape and bm.any() and np.all(mask[bm])
            assert np.array_equal(b[bm],a[bm])
            allowed=GROUPS[0] if item=='rhodes_dual_blades' else GROUPS[2]
            assert {bytes(c).hex() for c in np.unique(b[:,:,:3][bm],axis=0)}<=allowed
        summary.append(dict(id=item,status='PASS',isolated_pixel_percent=round(isolated,2),bright_pixel_percent=round(bright,2)))
    sheet=Image.open(root/'contact_sheet.png');double=Image.open(root/'contact_sheet_2x.png')
    assert np.array_equal(np.array(double),np.repeat(np.repeat(np.array(sheet),2,0),2,1))
    for name in ['silhouette_check.png','generation_prompts.md','process.py','sources','README.md']:
        assert (root/name).exists(),name
    if root.name=='batch_E13_v1':
        refs=json.loads((root/'sources/lungmen_index.json').read_text(encoding='utf-8'))
        assert len(refs)==19 and 'lord_blade' in {e['id'] for e in refs}
        assert len(json.loads((root/'silhouette_sources.json').read_text(encoding='utf-8')))==30
    result=dict(status='PASS',items=len(ids),checks='Expected IDs and sizes; binary alpha; <=24 colours; isolated <=10%; bright >=15%; exact 8x and 2x; hashes; E6 palette/accent limits; exact native logos; localized matching nonempty emission; required artifacts; E13 19 Lungmen comparison inputs.',runtime='Godot import and inventory UI display not tested.',results=summary)
    (root/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(root.name,len(ids),'PASS')

if __name__=='__main__':
    roots=[HERE] if HERE.name.startswith('batch_') else [HERE/'batch_E13_v1',HERE/'batch_E6_v1']
    for root in roots:validate(root)
