"""Retain references, audit preservation, and package review deliveries."""
from pathlib import Path
import json,hashlib,shutil,zipfile,ast,sys
from PIL import Image,ImageDraw,ImageFont
import numpy as np
ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parent.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def protected():
    ids=set('rhodes_dual_blades rhodes_sword rhodes_field_uniform rhodes_protective_vest rhodes_beacon rhodes_medkit rhodes_badge family_stiletto brass_knuckles switchblade old_town_crowbar barber_razor cane_sword butcher_cleaver vineyard_billhook eraser_curved_blade lead_cane wolfhead_knuckles saluzzo_crest'.split())
    for b in ['E11','E12']:
        data=json.loads((ROOT/f'batch_{b}_v1'/'manifest.json').read_text(encoding='utf-8'))
        ids.update(e['id'] for e in (data if isinstance(data,list) else data['items']) if e['id'] not in ['mi_fallen_snowpriest_29','mi_ice_hunter_20'])
    return {p.name:sha(p) for item in sorted(ids) for p in [ROOT/'runtime'/f'{item}.png',ROOT/'runtime'/f'{item}_emit.png'] if p.exists()}

def prepare():
    # Package only the helper definitions needed by this independent processor.
    tree=ast.parse((ROOT/'build_e13_e6.py').read_text(encoding='utf-8'))
    names={'metrics','smooth','rgb','map_palette','rim','GROUPS','E6_PALETTE'}
    nodes=[]
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:nodes.append(node)
        if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in names for t in node.targets):nodes.append(node)
    support='"""Pure palette and pixel metrics helpers derived from the prior painted-asset processor."""\nimport numpy as np\nfrom PIL import Image\n\n'+'\n\n'.join(ast.unparse(n) for n in nodes)+'\n'
    for batch in ['batch_E12_v2','batch_E14_v1']:
        root=ROOT/batch
        (root/'pixel_support.py').write_text(support,encoding='utf-8')
        shutil.copy2(ROOT/'process_e12v2_e14.py',root/'process.py')
        (root/'requirements.txt').write_text('Pillow>=10\nnumpy>=1.26\n',encoding='utf-8')
        if not (root/'protected_runtime_hashes.json').exists():dump(root/'protected_runtime_hashes.json',protected())
    r12=ROOT/'batch_E12_v2';r14=ROOT/'batch_E14_v1'
    shutil.copy2(ROOT/'E11_12_review_v1.md',r12/'source_review.md')
    shutil.copy2(ROOT/'E14_ranged_staves_brief_v1.md',r14/'source_brief.md')
    shutil.copy2(ROOT/'E13_revision_v2.md',r14/'source_review.md')
    review=PROJECT/'art'/'_to_sol'/'review_E11_E12_E13_E6.zip'
    for root in [r12,r14]:dump(root/'review_archive_origin.json',dict(file=str(review),sha256=sha(review)))
    for name in ['proto_quipu.jpg','proto_sleigh_bell.jpg']:
        shutil.copy2(ROOT/'refs_E10'/name,r12/'sources'/name)
    for item in ['mi_fallen_snowpriest_29','mi_ice_hunter_20']:
        shutil.copy2(ROOT/'batch_E12_v1'/f'{item}.png',r12/'sources'/f'{item}_previous.png')
    shutil.copy2(ROOT/'runtime'/'snow_x21.png',r12/'sources'/'snow_x21_accepted_reference.png')
    refs=[]
    for region,item in [('mine','mine_x08'),('lungmen','city_x08'),('sami','snow_x08'),('siracusa','vineyard_billhook')]:
        name=f'polearm_{item}.png';shutil.copy2(ROOT/'runtime'/f'{item}.png',r14/'sources'/name);refs.append(dict(region=region,id=item,file=name))
    dump(r14/'sources'/'polearms.json',refs)
    for item in ['cane_sword','lead_cane']:shutil.copy2(ROOT/'runtime'/f'{item}.png',r14/'sources'/f'accepted_{item}.png')
    shutil.copy2(ROOT/'refs_E7'/'style_existing_weapons_4x.png',r14/'sources'/'style_existing_weapons_4x.png')
    shutil.copy2(ROOT.parent/'field'/'batch_N4_v1'/'identity_family_crossbow_native.png',r14/'sources'/'identity_family_crossbow_native.png')

def finalize():
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',12)
    for batch in ['batch_E12_v2','batch_E14_v1']:
        root=ROOT/batch;manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
        report=json.loads((root/'qa_report.json').read_text(encoding='utf-8'));assert report['status']=='PASS'
        for e in manifest:
            e['prototype_refs']=['source_review.md','sources/proto_sleigh_bell.jpg' if e['id']=='mi_fallen_snowpriest_29' else 'sources/proto_quipu.jpg'] if batch=='batch_E12_v2' else ['source_brief.md','sources/style_existing_weapons_4x.png']
            if e['id']=='family_gun_crossbow':e['prototype_refs'].append('sources/identity_family_crossbow_native.png')
            if e['region']=='rhodes':e['prototype_refs'].append('sources/rhodes_logo_S_9.png')
        dump(root/'manifest.json',manifest)
        specs=json.loads((root/'generation_specs.json').read_text(encoding='utf-8'))
        for e,s in zip(manifest,specs):s['prototype_refs']=e['prototype_refs']
        dump(root/'generation_specs.json',specs)
        p=root/'generation_prompts.md';initial=p.read_text(encoding='utf-8').split('\n## Targeted revisions')[0]
        revisions=sorted((root/'sources').glob('*_revision_prompt.txt'))
        p.write_text(initial+'\n## Targeted revisions\n\n'+'\n\n'.join('### '+q.stem+'\n\n'+q.read_text(encoding='utf-8') for q in revisions),encoding='utf-8')
        sources=[dict(file=p.relative_to(root).as_posix(),sha256=sha(p)) for p in sorted((root/'sources').rglob('*')) if p.is_file()]
        dump(root/'source_hashes.json',sources)
        before=json.loads((root/'protected_runtime_hashes.json').read_text(encoding='utf-8'));current=protected()
        changed=[name for name,value in before.items() if current.get(name)!=value]
        dump(root/'preservation_check.json',dict(status='PASS' if not changed else 'CHANGED_EXTERNALLY',protected_runtime_files=len(before),changed=changed));assert not changed,changed
        (root/'README.md').write_text(f'''# {batch}

{len(manifest)} painted inventory icons, generated with built-in imagegen. Source
paintings and targeted revisions are retained. Initial prompts are in
generation_prompts.md; revisions are also retained as sources/*_revision_prompt.txt.
generation_history.json records generator output locations; source_hashes.json
records source and reference SHA256 values.

Rebuild on Windows: install requirements.txt, run `python process.py`.
Independent delivery check: `python validate.py`.
Review contact_sheet.png at native scale, contact_sheet_2x.png, art_preview.png,
and silhouette_check.png. E14 groups each region beside its accepted polearm.
The regional native colour source comparisons are retained under sources/.
E12 contains only the TWO requested replacements at the top level; the accepted
silver bell is included only as a labelled reference under sources/.

Processing preserves source aspect ratios. Staff paintings are rotated uniformly
to an eight-degree rise before reduction. The native core is given one external
pixel of #0b0c0d outline. Tiny reduction gaps are closed, small isolated source
specks removed, and colour flecks paired into clusters. Material highlights and
top-left rim light are restored on the painted surface. No weapon, bow or staff
silhouette is synthesized in code. Native E12 finishing restores seven painted
3x3 knots, a 6x3 bone toggle, and the bell's loop, frost and exposed clapper.
Rhodes logos use the existing exact 9x9 mark inside the enlarged painted plaques.

Metrics: luminance is Rec.709-weighted sRGB code values >=153/255, not linear
light; isolated percentage counts opaque pixels with no identical RGB among four
opaque orthogonal neighbors. Connectivity is eight-neighbor. This does not prove
semantic art acceptance. qa/core_masks records pre-outline geometry; validation
checks final alpha against its one-pixel expansion and checks the outer colour.

Emit files select only the bell mouth or the five specifically requested E14
lights/foci. There are no baked glow halos. Exact preview multiples, counts,
palette/alpha and hashes are checked by validate.py.

Accepted E11/E12/E13/E6 runtime icons were left unchanged; preservation_check.json
compares protected hashes. No game code or runtime art was installed by this pass.
Godot import, inventory UI display and runtime review remain untested for these
NEW replacements and E14. The prior accepted art remains in place pending review.
''',encoding='utf-8')
    # Native and enlarged before/after comparison for the two review corrections.
    root=ROOT/'batch_E12_v2';canvas=Image.new('RGB',(400,256),'#24282b');d=ImageDraw.Draw(canvas)
    for row,item in enumerate(['mi_fallen_snowpriest_29','mi_ice_hunter_20']):
        y=row*128;d.text((5,y+5),item,font=font,fill='#dddddd')
        for x,name in [(15,root/'sources'/f'{item}_previous.png'),(100,root/f'{item}.png')]:
            im=Image.open(name).convert('RGBA');canvas.paste(im,(x,y+52),im)
        d.text((15,y+32),'v1',font=font,fill='#aaaaaa');d.text((100,y+32),'v2',font=font,fill='#dddddd')
        im=Image.open(root/f'{item}_8x.png').convert('RGBA').resize((96,96),Image.Resampling.NEAREST);canvas.paste(im,(270,y+26),im)
    canvas.save(root/'before_after.png')
    # Include accepted silver bell only as a clearly labeled relative-scale reference.
    comp=Image.new('RGB',(240,70),'#2c2e30');d=ImageDraw.Draw(comp)
    for x,p,label in [(5,root/'mi_fallen_snowpriest_29.png','NEW bronze bell'),(125,root/'sources/snow_x21_accepted_reference.png','accepted silver')]:
        im=Image.open(p).convert('RGBA');comp.paste(im,(x,25),im);d.text((x,5),label,font=font,fill='#dddddd')
    comp.save(root/'bell_vs_accepted_silver.png')
    r14=ROOT/'batch_E14_v1';comp=Image.new('RGB',(420,150),'#2c2e30');d=ImageDraw.Draw(comp)
    for row,(p,label) in enumerate([(r14/'lawyer_casting_cane.png','new casting cane'),(r14/'sources/accepted_cane_sword.png','accepted cane sword'),(r14/'sources/accepted_lead_cane.png','accepted wolf cane')]):
        im=Image.open(p).convert('RGBA');comp.paste(im,(200,row*48+5),im);d.text((5,row*48+12),label,font=font,fill='#dddddd')
    comp.save(r14/'siracusa_canes_check.png')
    for batch in ['batch_E12_v2','batch_E14_v1']:
        root=ROOT/batch;destination=PROJECT/'art'/'_to_sol'/f'{batch[6:]}_2026-10-18.zip'
        with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED) as z:
            for p in sorted(root.rglob('*')):
                if p.is_file() and p.suffix not in ['.import','.pyc'] and '__pycache__' not in p.parts:z.write(p,Path('art/items')/root.name/p.relative_to(root))
        with zipfile.ZipFile(destination) as z:assert z.testzip() is None
        print(destination.name,'CRC PASS')

if __name__=='__main__':prepare() if '--prepare' in sys.argv else finalize()
