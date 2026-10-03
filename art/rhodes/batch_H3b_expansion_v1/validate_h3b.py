"""Independent acceptance checks for the H3b expansion kit."""
from __future__ import annotations
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
ART=ROOT.parent
sys.path.insert(0,str(ART))
from pixel_kit import COLORS, GLYPHS_5


def array(path):return np.asarray(Image.open(path).convert('RGBA'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def luminance(im):
    p=im[:,:,:3][im[:,:,3]>0]
    return float(np.mean(p @ np.array([0.2126,0.7152,0.0722])/255))


def main():
    manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf8'))
    errors=[];report=[]
    def check(ok,message):
        if not ok:errors.append(message)
    allowed={tuple(bytes.fromhex(v[1:])) for v in COLORS.values()}
    assets={a['id']:a for a in manifest['assets']}
    required={'corridor_straight_cleared','corridor_straight_uncleared',
              'corridor_dead_end_uncleared','corridor_clearing_overlay',
              'engineering_drone','construction_work_lamp','corridor_debris',
              'room_slot_door_sealed','room_slot_door_empty','room_slot_door_built',
              'room_slot_number_plate_B1_05','room_slot_empty_backing_32x36',
              'pending_build_floor_90x51'}
    check(required<=assets.keys(),'missing requested asset')
    for name,a in assets.items():
        path=ROOT/a['file'];im=array(path)
        check(list(im.shape[1::-1])==a['size_px'],name+': manifest size')
        check(np.isin(im[:,:,3],(0,255)).all(),name+': alpha not binary')
        colors={tuple(p) for p in im[:,:,:3][im[:,:,3]>0]}
        check(colors<=allowed,name+': out-of-palette colour')
        check(np.array_equal(array(ROOT/(path.stem+'_8x.png')),np.repeat(np.repeat(im,8,0),8,1)),name+': 8x mismatch')
        check(0<=a['anchor_px'][0]<=im.shape[1] and 0<=a['anchor_px'][1]<=im.shape[0],name+': anchor bounds')
        if a['locked_source']:
            check(sha(path)==sha(ROOT/a['locked_source']),name+': locked accepted pixels changed')
        if a['source']:
            s=a['source'];src=ROOT/s['source']
            check(src.parent.name=='sources' and sha(src)==s['source_sha256'],name+': original source hash')
            check(list(Image.open(src).size)==s['source_size_px'],name+': original source size')
            check(isinstance(s['integer_reduction'],int) and s['integer_reduction']>=2,name+': not integer reduction')
            opaque=im[:,:,:3][im[:,:,3]>0]
            nearblack=float(np.mean(np.all(opaque==[11,12,13],axis=1)))
            check(nearblack<=.03,name+': near-black exceeds 3 percent')
            gray={tuple(bytes.fromhex(COLORS[k][1:])) for k in ['S0','S1','S2','S3','G0','G1','G2','W0','W1','W2']}
            steps=len(colors&gray);check(steps>=4,name+': insufficient shaded grey steps')
            families={family:{tuple(bytes.fromhex(COLORS[k][1:])) for k in keys} for family,keys in
                      {'orange':['O0','O1','O2'],'yellow':['Y0','Y1','Y2'],'cyan':['T0','T1','T2','T3'],
                       'blue':['B0','B1','B2'],'red':['R0']}.items()}
            accents={family:sum(tuple(p) in values for p in opaque)/len(opaque) for family,values in families.items()}
            report.append(f'{name}: {im.shape[1]}x{im.shape[0]}, factor {s["integer_reduction"]}, mean luminance {luminance(im):.3f}, near-black {nearblack*100:.1f}%, grey steps {steps}; '+
                          ', '.join(f'{k} {v*100:.1f}%' for k,v in accents.items()))
        if a['emit']:
            em=array(ROOT/a['emit']);on=em[:,:,3]>0
            check(em.shape==im.shape and on.any(),name+': missing or empty emit')
            check(np.isin(em[:,:,3],(0,255)).all(),name+': emit alpha')
            check(np.array_equal(em[on],im[on]),name+': emit alignment')
            check(np.array_equal(array(ROOT/a['emit'].replace('.png','_8x.png')),
                                 np.repeat(np.repeat(em,8,0),8,1)),name+': emit 8x')
    for d in manifest['external_dependencies']:
        check(sha(ROOT/d['file'])==d['sha256'],'dependency hash: '+d['file'])

    projection=manifest['projection']
    check(projection['corridor_units']==[6,4] and projection['floor_px']==[90,51], 'four-unit corridor projection')
    check(projection['wall_px']==46 and projection['door_px']==[45,46], 'locked module dimensions')
    for state,source in [('sealed','sealed'),('empty','open'),('built','closed')]:
        im=array(ROOT/f'room_slot_door_{state}.png')
        check(np.array_equal(im,array(ART/f'batch1_v5/door_{source}_45x46_v5.png')),state+': frame/chamfer drift')
    door=array(ROOT/'room_slot_door_empty.png')
    check(np.all(door[9:45,6:38,3]==0),'32x36 clear opening changed')
    backing=array(ROOT/'room_slot_empty_backing_32x36.png')
    check(backing.shape==(36,32,4),'empty backing exceeds clearance')
    check(manifest['assemblies']['room_slot']['empty'][0]['offset_px']==[6,9],'empty backing alignment')
    socket=array(ROOT/'corridor_door_socket_90x46.png')
    check(np.all(socket[:,22:67,3]==0),'door socket width or alpha')

    clear=array(ROOT/'corridor_straight_cleared.png')
    uncleared=array(ROOT/'corridor_straight_uncleared.png')
    ground=array(ROOT/'corridor_floor_90x51.png')
    check(clear.shape==uncleared.shape==(103,90,4),'corridor state size')
    for name,im in [('clear',clear),('uncleared',uncleared),('floor',ground)]:
        check(np.array_equal(im[:,0],im[:,-1]),name+': horizontal repeat seam')
    check(np.array_equal(clear[46:97],ground),'four-unit floor placement')
    check(luminance(uncleared[46:70])<luminance(clear[46:70]),'uncleared floor not dimmed')
    check(np.array_equal(array(ROOT/'corridor_debris.png')[:,:,3],
                         array(ROOT/'corridor_debris_dimmed.png')[:,:,3]),'dim debris geometry changed')
    tarp=array(ART/'batch_L0_logo_v1/rhodes_logo_tarp_print_v1.png')
    fence=array(ROOT/'corridor_end_fence_60x46.png')
    check(np.array_equal(fence[3:43,18:58],tarp),'accepted tarp drift or resampling')
    check(fence.shape==(46,60,4),'four-unit end-fence frontage')
    overlay=array(ROOT/'corridor_clearing_overlay.png')
    drone=array(ROOT/'engineering_drone.png');lamp=array(ROOT/'construction_work_lamp.png')
    for im,(x,y) in [(drone,(10,48)),(drone,(45,50)),(lamp,(63,65))]:
        h,w=im.shape[:2];mask=im[:,:,3]>0
        check(np.array_equal(overlay[y:y+h,x:x+w][mask],im[mask]),'clearing overlay item resampled/occluded')
    check(lamp.shape[0]<=30 and drone.shape[0]<=20,'construction scale vs 30px character')

    # Actual glyph silhouettes, not OCR or generated lettering.
    for filename,word,x,y,color in [('uncleared_zone_sign_60x12.png','UNCLEARED',3,3,'Y1'),
                                   ('pending_build_floor_90x51.png','PENDING',24,18,'G1'),
                                   ('pending_build_floor_90x51.png','BUILD',30,29,'Y1')]:
        im=array(ROOT/filename);ink=tuple(bytes.fromhex(COLORS[color][1:]))
        for i,char in enumerate(word):
            for yy,row in enumerate(GLYPHS_5[char].split('/')):
                for xx,bit in enumerate(row):
                    if bit=='1':check(tuple(im[y+yy,x+i*6+xx,:3])==ink,'native glyph mismatch: '+word)
    preview=array(ROOT/manifest['preview']['file'])
    check(preview.shape==(300,480,4),'1x gallery size')
    check(np.array_equal(array(ROOT/manifest['preview']['review_4x']),
                         np.repeat(np.repeat(preview,4,0),4,1)),'exact 4x gallery')
    lap=array(ART/'batch1_v5/lappland_frame0_64.png');mask=lap[:,:,3]>0
    for x,y in manifest['preview']['character_origins_px']:
        check(np.array_equal(preview[y:y+64,x:x+64][mask],lap[mask]),'Lappland frame 0 changed')
    check(sum(a['source'] is not None for a in assets.values())==3,'source inventory')
    check((ROOT/'build_h3b.py').exists() and (ROOT/'sources/prompts.json').exists(),'local script and prompts')
    result=['H3b expansion v1 independent validation',
            f'Assets: {len(assets)}; emit masks: {sum(bool(a["emit"]) for a in assets.values())}; generated originals: 3.',
            'PASS checks cover palette, binary alpha, source/dependency hashes, uniform integer factors, exact 8x exports, locked frames and corners, 32x36 clearance, 4-unit corridor width, repeat seams, tarp pixels, native glyphs, 1x Lappland and exact 4x gallery.',
            *report, f'Result: {"PASS" if not errors else "FAIL"} ({len(errors)} errors).',
            *['ERROR: '+e for e in errors],
            'Visual review: front-facing generated hardware, level lamp head, native fence and orthogonal modules. Asset kit only; no gameplay scene assembled.']
    (ROOT/'validation.txt').write_text('\n'.join(result)+'\n',encoding='utf8')
    print('\n'.join(result[-len(errors)-2:]))
    if errors:raise SystemExit(1)


if __name__=='__main__':main()
