"""Independent native delivery checks for review replacements and ranged batch."""
from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
IDS12=['mi_fallen_snowpriest_29','mi_ice_hunter_20']
IDS14='reunion_hand_crossbow modified_nail_gun imperial_heavy_crossbow scrap_casting_staff reunion_caster_staff lgd_hand_crossbow leader_repeating_crossbow laterano_smuggled_pistol bronze_bell_staff yan_talisman_staff sami_hunting_bow tundra_hunting_gun composite_horn_bow birch_shaman_staff snowpriest_staff family_gun_crossbow folding_sleeve_crossbow double_barrel_gun lawyer_casting_cane tribunal_staff rhodes_crossbow rhodes_staff'.split()
EMITS=set('mi_fallen_snowpriest_29 scrap_casting_staff reunion_caster_staff lawyer_casting_cane rhodes_crossbow rhodes_staff'.split())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def validate(root):
    expected=IDS12 if root.name=='batch_E12_v2' else IDS14
    data=json.loads((root/'manifest.json').read_text(encoding='utf-8'));assert [e['id'] for e in data]==expected
    assert {p.stem[:-5] for p in root.glob('*_emit.png')}==set(expected)&EMITS
    assert {p.stem for p in root.glob('*.png') if p.stem in set(IDS12+IDS14)}==set(expected)
    results=[]
    for e in data:
        item=e['id'];im=Image.open(root/e['file']).convert('RGBA');a=np.array(im);mask=a[:,:,3]>0
        assert im.size==((32,32) if expected==IDS12 else (72,32))
        assert set(np.unique(a[:,:,3]).tolist())=={0,255}
        p=a[:,:,:3];colors=np.unique(p[mask],axis=0);assert len(colors)<=24
        pad=np.pad(a,((1,1),(1,1),(0,0)));same=np.zeros(mask.shape,bool)
        for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
            n=pad[1+dy:1+dy+a.shape[0],1+dx:1+dx+a.shape[1]]
            same |= (n[:,:,3]>0)&np.all(p==n[:,:,:3],2)
        isolated=100*np.count_nonzero(mask&~same)/mask.sum();bright=100*np.count_nonzero(mask&((p@np.array([.2126,.7152,.0722]))>=153))/mask.sum()
        assert isolated<=10 and bright>=15,(item,isolated,bright)
        assert abs(round(isolated,2)-e['isolated_pixel_percent'])<.001
        assert abs(round(bright,2)-e['bright_pixel_percent'])<.001
        big=np.array(Image.open(root/f'{item}_8x.png').convert('RGBA'));assert np.array_equal(big,np.repeat(np.repeat(a,8,0),8,1))
        assert sha(root/e['source'])==e['source_sha256'] and sha(root/e['file'])==e['file_sha256']
        core=np.array(Image.open(root/'qa'/'core_masks'/f'{item}.png'))>0
        c=np.pad(core,1);outline=c[1:-1,1:-1]|c[:-2,1:-1]|c[2:,1:-1]|c[1:-1,:-2]|c[1:-1,2:]
        assert np.array_equal(mask,outline),(item,'outline geometry')
        assert np.all(p[outline&~core]==(11,12,13)),(item,'outline colour')
        # Flood final opaque geometry, independent from the processing helper.
        points=set(zip(*np.where(mask)));pending=[next(iter(points))];seen=set(pending)
        while pending:
            y,x=pending.pop()
            for dy in [-1,0,1]:
                for dx in [-1,0,1]:
                    n=(y+dy,x+dx)
                    if n in points and n not in seen:seen.add(n);pending.append(n)
        assert len(seen)==len(points),(item,'disconnected')
        if item in EMITS:
            b=np.array(Image.open(root/f'{item}_emit.png').convert('RGBA'));bm=b[:,:,3]>0
            assert b.shape==a.shape and bm.any() and np.all(mask[bm]) and np.array_equal(b[bm],a[bm])
            ys,xs=np.where(bm)
            if item=='mi_fallen_snowpriest_29':assert ys.min()>=21
            else:assert xs.min()>=(27 if item=='rhodes_crossbow' else 49)
        if e['region']=='rhodes':
            from pixel_support import E6_PALETTE,GROUPS
            assert {bytes(c).hex() for c in colors}<=set(E6_PALETTE)
            percentages=[sum(np.count_nonzero(mask&np.all(p==tuple(bytes.fromhex(v)),2)) for v in g)/mask.sum()*100 for g in GROUPS.values()]
            assert max(percentages)<=6 and sum(percentages)<=10
            x,y=e['logo_position'];logo=np.array(Image.open(root/'sources'/'rhodes_logo_S_9.png').convert('RGBA'));lm=logo[:,:,3]>0
            assert core[y:y+9,x:x+9].all() and np.array_equal(a[y:y+9,x:x+9][lm],logo[lm])
        results.append(dict(id=item,status='PASS',isolated_pixel_percent=round(isolated,2),bright_pixel_percent=round(bright,2)))
    base=np.array(Image.open(root/'contact_sheet.png'));big=np.array(Image.open(root/'contact_sheet_2x.png'));assert np.array_equal(big,np.repeat(np.repeat(base,2,0),2,1))
    qa=json.loads((root/'qa_report.json').read_text(encoding='utf-8'));assert qa['status']=='PASS'
    if expected==IDS12:
        bell=np.array(Image.open(root/'mi_fallen_snowpriest_29.png'));old=np.array(Image.open(root/'sources'/'snow_x21_accepted_reference.png').convert('RGBA'))
        bm=bell[:,:,3]>0;om=old[:,:,3]>0
        assert np.count_nonzero(bm)>np.count_nonzero(om)
        # Compare bell materials rather than the accepted silver bell's large
        # dark leather loop, which dominates whole-icon average luminance.
        bronze=bm&(bell[:,:,0]>bell[:,:,2]*1.1)
        silver=om&(old[:,:,0]<=old[:,:,2]*1.1)&(old[:,:,0]>40)&(old[:,:,1]>40)
        bronze_luma=float((bell[:,:,:3][bronze]@np.array([.2126,.7152,.0722])).mean())
        silver_luma=float((old[:,:,:3][silver]@np.array([.2126,.7152,.0722])).mean())
        assert bronze.sum()>silver.sum()*1.4 and bronze_luma<silver_luma*.8
        comparison=dict(bronze_body_pixels=int(bronze.sum()),silver_metal_pixels=int(silver.sum()),bronze_body_mean_luminance=round(bronze_luma,2),silver_metal_mean_luminance=round(silver_luma,2),definition='Warm bronze material versus neutral silver material; exclude outlines, violet, frost, and the accepted leather suspension loop.')
        assert np.where(bm)[1].max()-np.where(bm)[1].min()+1>=22
        assert np.array_equal(bell[29,15:18,:3],np.tile((214,185,139),(3,1)))
        cord=np.array(Image.open(root/'mi_ice_hunter_20.png'))
        assert np.array_equal(cord[4,23:29,:3],np.tile((251,248,238),(6,1)))
        assert np.array_equal(cord[6,23:29,:3],np.tile((185,174,149),(6,1)))
        for x,y in [(8,6),(5,12),(16,16),(23,21),(15,27),(6,23),(19,4)]:assert np.all(cord[y-1:y+1,x-1:x+2,:3]==(214,185,139))
    else:
        refs=json.loads((root/'sources'/'polearms.json').read_text(encoding='utf-8'));assert len(refs)==4
        crossbows=[e for e in data if e['form']=='crossbow']
        heavy=next(e for e in crossbows if e['id']=='imperial_heavy_crossbow')
        assert heavy['opaque_pixel_count']==max(e['opaque_pixel_count'] for e in crossbows)
    for p in ['README.md','process.py','pixel_support.py','generation_prompts.md','generation_history.json','silhouette_check.png']:
        assert (root/p).exists(),p
    result=dict(status='PASS',items=len(data),results=results,checks='Exact IDs/sizes; binary alpha; <=24 colors; <=10% isolated; >=15% bright; exact 8x/2x; source/final hashes; true complete 1px outer outline; final geometry connected; only required localized nonempty emits; Rhodes palette and accent budgets; exact logos inside painted core; E12 bell darker/larger than accepted silver and knot/toggle native dimensions.',runtime='Godot import and UI display remain untested for these new files.')
    if expected==IDS12:result['bell_material_comparison']=comparison
    (root/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(root.name,len(data),'PASS')

if __name__=='__main__':
    roots=[HERE] if HERE.name.startswith('batch_') else [HERE/'batch_E12_v2',HERE/'batch_E14_v1']
    for root in roots:
        import sys
        sys.path.insert(0,str(root));validate(root)
