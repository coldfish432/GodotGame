"""Capture project references and finalize independently reproducible art packs."""
from pathlib import Path
import json
import shutil
import hashlib
import zipfile

ROOT=Path(__file__).resolve().parent
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def references():
    out=ROOT/'batch_E13_v1'/'sources';(out/'lungmen').mkdir(exist_ok=True)
    seen=set();index=[]
    for b in ['batch_E2_v3','batch_E8_v2','batch_E8_v1','batch_E4_v4']:
        data=json.loads((ROOT/b/'manifest.json').read_text(encoding='utf-8'))
        for e in data if isinstance(data,list) else data['items']:
            if (b=='batch_E4_v4' and e['id']!='lord_blade') or e['id'] in seen or e.get('native_size')!=[72,32]:continue
            seen.add(e['id']);shutil.copy2(ROOT/b/e['file'],out/'lungmen'/f"{e['id']}.png")
            index.append(dict(id=e['id'],source=f"art/items/{b}/{e['file']}"))
    dump(out/'lungmen_index.json',index)
    for name in ['proto_brass_knuckles.jpg','proto_billhook.jpg','proto_sledgehammer.jpg','style_existing_weapons_4x.png']:
        shutil.copy2(ROOT/'refs_E7'/name,out/name)
    for enemy in ['soldier','eraser','intimidator','capo']:
        p=ROOT.parent/'field'/'batch_N4_v1'/f'identity_family_{enemy}_native.png'
        shutil.copy2(p,out/p.name)
    for b in ['E13','E6']:
        root=ROOT/f'batch_{b}_v1'
        shutil.copy2(ROOT/'build_e13_e6.py',root/'process.py')
        brief='E13_siracusa_weapons_brief_v1.md' if b=='E13' else 'E6_brief_v1.md'
        shutil.copy2(ROOT/brief,root/'source_brief.md')
    print('Retained',len(index),'Lungmen weapon comparisons')

def finalize():
    for b in ['E13','E6']:
        root=ROOT/f'batch_{b}_v1';manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
        for e in manifest:
            e['reference_urls']=[]
            e['processing']='process.py: uniform aspect-preserving reduction; prescribed palette; native colour cluster cleanup; localized small marks.'
            if b=='E13':
                refs=['sources/style_existing_weapons_4x.png','source_brief.md']
                if e['id'] in ['brass_knuckles','wolfhead_knuckles']:refs+=['sources/proto_brass_knuckles.jpg']
                if e['id']=='vineyard_billhook':refs+=['sources/proto_billhook.jpg']
                enemy={'family_stiletto':'soldier','brass_knuckles':'intimidator','eraser_curved_blade':'eraser','lead_cane':'capo'}.get(e['id'])
                if enemy:refs+=[f'sources/identity_family_{enemy}_native.png']
                e['prototype_refs']=list(dict.fromkeys(refs+e['prototype_refs']))
            else:
                e['prototype_refs']=['source_brief.md','sources/rhodes_logo_S_9.png']
                if e['id']=='rhodes_dual_blades':e['reference_urls']=['https://torappu.prts.wiki/assets/uniequip_img/uniequip_003_yato2.png']
                if e['id']=='rhodes_sword':e['reference_urls']=['https://torappu.prts.wiki/assets/uniequip_img/uniequip_002_chen.png']
                e['logo_position']={'rhodes_field_uniform':[58,24],'rhodes_protective_vest':[45,27],'rhodes_beacon':[12,17],'rhodes_medkit':[14,14],'rhodes_badge':[11,16]}.get(e['id'])
        dump(root/'manifest.json',manifest)
        specs=json.loads((root/'generation_specs.json').read_text(encoding='utf-8'))
        for spec,e in zip(specs,manifest):
            for key in ['prototype_refs','reference_urls','logo_position','processing']:
                if key in e:spec[key]=e[key]
        dump(root/'generation_specs.json',specs)
        prompts=root/'generation_prompts.md'
        initial=prompts.read_text(encoding='utf-8').split('\n## Targeted revisions')[0]
        revisions=sorted((root/'sources').glob('*_revision_prompt.txt'))
        prompts.write_text(initial+'\n## Targeted revisions\n\n'+ '\n\n'.join('### '+p.stem+'\n\n'+p.read_text(encoding='utf-8') for p in revisions)+'\n',encoding='utf-8')
        sources=[]
        for p in sorted((root/'sources').rglob('*')):
            if p.is_file():sources.append(dict(file=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
        dump(root/'source_hashes.json',sources)
        (root/'requirements.txt').write_text('Pillow>=10\nnumpy>=1.26\n',encoding='utf-8')
        (root/'README.md').write_text(f'''# {b} v1 painted inventory icons

{len(manifest)} items. Source artwork generated with the built-in imagegen tool,
one call per item, with targeted revisions retained alongside initial paintings.
`generation_prompts.md` records initial prompts; `sources/*_revision_prompt.txt`
records revision prompts. `source_hashes.json` records retained reference hashes.

Review `contact_sheet.png` at 1:1, `contact_sheet_2x.png`, `art_preview.png`, and
`silhouette_check.png`. E13 compares all 19 accepted Lungmen weapons with the
11 new weapons. Each black silhouette has its original colour version beside it.

Rebuild: install requirements, then run `python process.py` in this directory.
Validate: `python validate.py`. Processing uses only retained painted artwork;
it does not call an image service or synthesize weapon/armour geometry.
Images preserve aspect ratio; previews are exact nearest-neighbour multiples.
Pixel cleanup includes prescribed palette mapping, exposure of painted highlights,
pairing isolated colour flecks, and restoring tiny functional details. E6 places
the project's existing native 9x9 mark once per specified item; masks select only
the two blue blade cores or the cyan status LEDs. No emission halos are baked.

Static QA is recorded in `qa_report.json` and independent delivery checks in
`validation.json`. Luminance is weighted sRGB code value (Rec.709), threshold 153.
Isolated percentage counts all opaque pixels with no identical RGB in four opaque
orthogonal neighbours. Flat region means largest exact-colour connected region.
These metrics do not establish semantic/art acceptance or in-game readability.

Godot import, backpack UI display and full-game runtime are untested.
The batch is delivered here for review; no runtime artwork or game code was changed.
No E5 ground sprites were made.

Reference access: E6 module URLs were attempted through web and direct retrieval;
the reference host could not be retrieved in this session. The brief's supplied
shape descriptions and local Rhodes palette/logo were used. Retain this caveat
when comparing the module prototypes. Native cleanup decisions are in process.py.
''',encoding='utf-8')
        with zipfile.ZipFile(ROOT/f'batch_{b}_v1.zip','w',zipfile.ZIP_DEFLATED) as z:
            for p in sorted(root.rglob('*')):
                if p.is_file() and p.suffix not in ['.import','.pyc'] and '__pycache__' not in p.parts:z.write(p,Path(root.name)/p.relative_to(root))
        with zipfile.ZipFile(ROOT/f'batch_{b}_v1.zip') as z:assert z.testzip() is None
        print(b,'ZIP CRC PASS')

if __name__=='__main__':
    import sys
    references() if '--references' in sys.argv else finalize()
