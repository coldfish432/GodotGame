"""Independent read-only PNG checks plus a generated validation report."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
def main():
    expected=[f'bg_{owner}_{i}' for owner in ['patriot','rat_king','eikthyrnir','zaro'] for i in range(9)]
    manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
    assert [e['id'] for e in manifest]==expected
    results=[]
    for e in manifest:
        id=e['id'];index=int(id.rsplit('_',1)[1]);size=(72,32) if index<3 else (72,72) if index<6 else (32,32)
        im=Image.open(ROOT/(id+'.png')).convert('RGBA');assert im.size==size
        a=np.array(im);mask=a[:,:,3]>0;rgb=a[:,:,:3]
        assert set(np.unique(a[:,:,3]))=={0,255}
        assert np.all(a[~mask]==0)
        colors=len(np.unique(rgb[mask],axis=0));assert colors<=24,(id,colors)
        pad=np.pad(a,((1,1),(1,1),(0,0)));same=np.zeros(mask.shape,bool)
        for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
            q=pad[1+dy:1+dy+a.shape[0],1+dx:1+dx+a.shape[1]]
            same|=(q[:,:,3]>0)&np.all(q[:,:,:3]==rgb,axis=2)
        isolated=float(np.count_nonzero(mask&~same)/mask.sum()*100)
        bright=float(np.count_nonzero(mask&(rgb.astype(float)@np.array([.2126,.7152,.0722])>=153))/mask.sum()*100)
        assert isolated<=10,(id,'isolated',isolated)
        assert bright>=15,(id,'bright',bright)
        r,g,b=rgb.astype(int).transpose(2,0,1)
        purple=mask&(b>g+10)&(r>g+8)&(b>=r)&(r>90)
        purple_percent=float(purple.sum()/mask.sum()*100)
        assert purple_percent<=10,(id,'lavender dominates',purple_percent)
        bbox=im.getbbox();assert bbox[0]>0 and bbox[1]>0 and bbox[2]<im.width and bbox[3]<im.height,(id,'no margin')
        preview=np.array(Image.open(ROOT/(id+'_8x.png')).convert('RGBA'))
        assert np.array_equal(preview,np.repeat(np.repeat(a,8,0),8,1))
        assert hashlib.sha256((ROOT/e['source']).read_bytes()).hexdigest()==e['source_sha256']
        assert abs(round(bright,2)-e['statistics']['bright_pixel_percent'])<.01
        assert abs(round(isolated,2)-e['statistics']['isolated_pixel_percent'])<.01
        results.append({'id':id,'status':'PASS','colors':colors,'isolated_pixel_percent':round(isolated,2),'bright_pixel_percent':round(bright,2),'lavender_hue_percent':round(purple_percent,2)})
    required=['contact_sheet.png','contact_sheet_2x.png','art_preview.png','rarity_backgrounds_1x.png','silhouette_check.png','generation_specs.json','generation_prompts.md','process.py','source_brief.md']
    for name in required:assert (ROOT/name).stat().st_size>0
    contact=np.array(Image.open(ROOT/'contact_sheet.png'))
    contact2=np.array(Image.open(ROOT/'contact_sheet_2x.png'))
    assert np.array_equal(contact2,np.repeat(np.repeat(contact,2,0),2,1))
    assert not list(ROOT.glob('*_emit.png'))
    result={'status':'PASS','icons':36,'checks':['Exact 36 brief IDs and native dimensions','Transparent binary alpha; nonempty and inside canvas','At most24 opaque colors; isolated color pixels<=10% using four neighbors','Luminance>=60% on at least15% of opaque pixels','Lavender is a minor accent (hue diagnostic <=10%)','Exact nearest-neighbor 8x previews and2x contact sheet','Source hashes match retained paintings; required review artifacts present'],'results':results,'limits':'Static assets checked. Godot import, inventory UI display and art acceptance not tested.'}
    (ROOT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'status':'PASS','icons':36,'min_bright_percent':min(r['bright_pixel_percent'] for r in results),'max_isolated_percent':max(r['isolated_pixel_percent'] for r in results)}))
if __name__=='__main__':main()
