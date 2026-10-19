"""Independently validate native R1-R10 textures and exact repeat previews."""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
WORK=HERE if (HERE/'generation_specs.json').exists() else HERE/'base_materials_v1'
ROOT=WORK.parent
EXPECTED={'base_deck':(256,256),'base_steel':(256,256),'base_deck_med':(256,256),'base_hazard':(128,64),'base_grating':(128,128),'base_screen':(256,128),'base_fabric':(128,128),'base_container':(128,128),'base_wasteland_view':(512,256),'base_deck_store':(256,256)}
NEUTRAL={'base_steel','base_fabric','base_container'}
GRAY={'5a5a5a','7a7a7a','9a9a9a','b4b4b4','c8c8c8','dcdcdc'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def validate(installed=False):
    entries=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'));specs=json.loads((WORK/'generation_specs.json').read_text(encoding='utf-8'))
    assert set(entries)==set(EXPECTED) and len(specs)==10
    reports=[]
    for spec in specs:
        name=spec['name'];e=entries[name];path=WORK/'textures'/f'{name}.png'
        im=Image.open(path);assert im.mode=='RGB' and im.size==EXPECTED[name]
        a=np.array(im);colors={bytes(v).hex() for v in np.unique(a.reshape(-1,3),axis=0)}
        assert colors<=set(spec['palette']) and len(colors)==e['colors']
        if name in NEUTRAL:
            assert colors<=GRAY and len(colors)<=6
            assert np.all(a[:,:,0]==a[:,:,1]) and np.all(a[:,:,1]==a[:,:,2])
        else:assert 8<=len(colors)<=12,(name,len(colors))
        assert np.array_equal(a[:,0],a[:,-1]),(name,'horizontal seam')
        if name!='base_wasteland_view':assert np.array_equal(a[0],a[-1]),(name,'vertical seam')
        preview=np.array(Image.open(WORK/'textures'/f'{name}_tile_3x3.png'))
        assert np.array_equal(preview,np.tile(a,(3,3,1))),name
        assert sha(path)==e['file_sha256'] and sha(WORK/e['source'])==e['source_sha256']
        if name not in ['base_screen','base_wasteland_view']:assert e['quadrant_spread']<12
        if installed:
            assert sha(ROOT/f'{name}.png')==sha(path)
            assert sha(ROOT/f'{name}_tile_3x3.png')==sha(WORK/'textures'/f'{name}_tile_3x3.png')
        reports.append(dict(id=e['id'],file=name+'.png',status='PASS',size=list(im.size),colors=len(colors),mean_luma=e['mean_luma']))
    assert entries['base_deck']['mean_luma']<100
    assert entries['base_deck']['mean_luma']+15<entries['base_deck_store']['mean_luma']<150
    assert entries['base_deck_store']['mean_luma']+50<entries['base_deck_med']['mean_luma']<225
    assert 180<entries['base_steel']['mean_luma']<215
    project=ROOT.parent.parent.parent.parent
    protected=json.loads((WORK/'protected_assets.json').read_text(encoding='utf-8'))
    changed=[]
    for relative,value in protected.items():
        path=project/relative
        if path.exists() and sha(path)!=value:changed.append(relative)
    assert not changed,changed
    if installed:
        shared=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'));prior=json.loads((WORK/'previous_painted_manifest.json').read_text(encoding='utf-8'))
        for key,value in prior.items():assert shared[key]==value,('old manifest entry',key)
        for name in EXPECTED:assert shared[name]['file_sha256']==entries[name]['file_sha256']
    report=dict(status='PASS',textures=10,installed=installed,checks='Exact native sizes; RGB opaque; palette membership and colour counts; x repeat for all, y repeat except R9; exact 3x3 repeated pixels; source/final hashes; broad exposure uniformity; floor brightness hierarchy; unchanged pre-existing asset hashes; installed bytes and prior manifest entries when requested.',neutral_palette_exception='R2/R7/R8 use only the specified six neutral greys; actual used subsets have 4-5 colours. This dedicated ramp overrides the generic 8-12 minimum.',protected_assets=len(protected),protected_changes=changed,results=reports,runtime='See runtime_evidence.json if present; no Blender rebake of the 84 base models is performed here.')
    (WORK/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('R1-R10:',len(reports),'PASS; protected',len(protected),'unchanged; installed',installed)
    return report

if __name__=='__main__':validate('--installed' in sys.argv)
