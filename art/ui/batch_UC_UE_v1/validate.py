"""Independent brief-level checks; validates files on disk, then packages delivery."""
from pathlib import Path
from PIL import Image
import hashlib, json, zipfile

B=Path(__file__).resolve().parent
UI=B.parent
expected={
    'panel_plate':(96,96),'panel_glass':(96,96),'header_strip':(256,48),
    'btn_go':(96,48),'btn_go_stripes':(32,48),'slot_frame':(48,48),'tip_frame':(48,48),
}
expected.update({f'btn_{s}':(48,48) for s in ('normal','hover','press','disabled')})
expected.update({f'holo_ring_{s}':(256,256) for s in ('ticks','dash','arc')})
expected.update({f'sil_{s}':(48,48) for s in ('head','chest','hands','legs','feet','amulet','ring','weapon')})
expected.update({f'dept_{s}':(24,24) for s in ('bridge','warehouse','logistics','medical','research','store')})
icons=('equipment','operator','relic','map','contract','lmd','gold','pollution')
expected.update({s:(24,24) for s in icons})
manifest=json.loads((B/'manifest.json').read_text(encoding='utf-8'))
assert len(manifest['files'])==36
checks=[]
for name,size in expected.items():
    path=UI/('icons' if name in icons else 'kit')/(name+'.png')
    with Image.open(path) as im:
        im.load()
        assert im.size==size,(name,im.size)
        assert im.mode=='RGBA',(name,im.mode)
        pixels=list(im.get_flattened_data())
        alpha={p[3] for p in pixels}
        if name=='panel_glass':
            assert alpha=={0,204,255}
            assert im.getpixel((48,48))[3]==204
        else: assert alpha<={0,255},(name,alpha)
        visible={p[:3] for p in pixels if p[3]}
        if name in icons or name.startswith(('dept_','holo_ring_')):
            assert visible=={(255,255,255)},(name,visible)
        if name.startswith('sil_'):
            assert len(visible)==1
            rgb=next(iter(visible)); assert min(rgb)>=128 and max(rgb)<=192
        if name=='btn_go_stripes':
            assert all(im.getpixel((0,y))==im.getpixel((16,y)) for y in range(48))
            assert all(im.getpixel((x,0))==im.getpixel((x,16)) for x in range(32))
        record=next(e for e in manifest['files'] if Path(e['file']).stem==name)
        assert hashlib.sha256(path.read_bytes()).hexdigest()==record['sha256']
        fixed=B/'feedback/fixed'/path.name
        if fixed.exists():
            assert path.read_bytes()==fixed.read_bytes(),f'Accepted correction overwritten: {name}'
        if name=='panel_glass':
            assert im.getpixel((48,48))==(18,24,28,204)
        if name=='holo_ring_arc':
            assert sum(p[3]>0 for p in pixels)>=500,'Reviewed arcs lost visibility'
        if name=='equipment':
            assert path.read_bytes()!=(UI/'kit/dept_store.png').read_bytes()
        if record['nine_patch_margin']:
            n=record['nine_patch_margin']; w,h=im.size
            # Nine-patch straight edge repeat zones must never introduce holes.
            for x in range(n,w-n):
                assert im.getpixel((x,0))[3]==255
                assert im.getpixel((x,h-1))[3]==255
            for y in range(n,h-n):
                assert im.getpixel((0,y))[3]==255
                assert im.getpixel((w-1,y))[3]==255
        checks.append(dict(file=str(path.relative_to(UI)),result='PASS',size=list(size),alpha=sorted(alpha)))
baseline=json.loads((B/'feedback/pre_update_delivery.json').read_text(encoding='utf-8'))
for record in baseline:
    assert hashlib.sha256((UI/record['file']).read_bytes()).hexdigest()==record['sha256'],f"Reviewed delivery changed: {record['file']}"
report=dict(result='PASS',assets=36,checks=checks,reviewed_delivery_preserved=36,
            limits=['No Godot import/runtime integration tested.','No automatic test proves absence of lettering.'],
            visual_review='Accepted by Claude with six touchups per feedback/review_claude.md; regenerated contact sheet inspected separately.')
(B/'qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
archive=UI/'UC_UE_v1_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for e in manifest['files']: z.write(UI/e['file'],e['file'])
    for folder in ('kit','icons'): z.write(UI/folder/'manifest.json',folder+'/manifest.json')
    for path in sorted(B.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts and path.name!='package_check.json':
            z.write(path,'batch_UC_UE_v1/'+str(path.relative_to(B)).replace('\\','/'))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    count=len(z.namelist())
(B/'package_check.json').write_text(json.dumps(dict(result='PASS',archive=archive.name,entries=count,crc='PASS',sha256=hashlib.sha256(archive.read_bytes()).hexdigest()),indent=2),encoding='utf-8')
print(f'36/36 PASS; ZIP CRC PASS: {archive}')
