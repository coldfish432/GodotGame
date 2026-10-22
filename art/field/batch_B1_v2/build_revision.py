"""Stage-1 v2: three painted revisions, six immutable v1 poses, static review only."""
from pathlib import Path
import sys, json, random, zipfile
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
FIELD=HERE.parent
BASE=FIELD/'batch_B1_v1'
INPUT=FIELD/'B1_revision_v2_inputs'
sys.path.insert(0,str(BASE))
from build_stage1 import IDS,ORDER,HEIGHTS,GREY,sha,crop_source,reduce_height,cell,enlarged,colour_count
REVISED=['patriot','rat_king','eikthyrnir']
PRESERVED=[name for name in ORDER if name not in REVISED]

def main():
    (HERE/'native').mkdir(exist_ok=True)
    (HERE/'qa').mkdir(exist_ok=True)
    baseline=json.loads((BASE/'manifest.json').read_text(encoding='utf-8'))
    entries_by_id={e['id']:e for e in baseline['figures']}
    cells={}
    figures={}
    entries=[]
    for name in ORDER:
        if name in REVISED:
            src=HERE/'source_paintings'/f'{name}_generated.png'
            painting,box=crop_source(src)
            figures[name]=reduce_height(painting,HEIGHTS[name])
            cells[name]=cell(figures[name])
            figures[name].save(HERE/'native'/f'{name}.png')
            cells[name].save(HERE/'native'/f'{name}_64.png')
            origin='revised painted source; built-in image_gen'
            source=str(src.relative_to(FIELD))
        else:
            e=entries_by_id[name]
            assert sha(BASE/e['source'])==e['source_sha256'],name+' original source changed'
            assert sha(BASE/e['native_cell'])==e['native_cell_sha256'],name+' accepted native changed'
            cells[name]=Image.open(BASE/e['native_cell']).convert('RGBA')
            figures[name]=Image.open(BASE/e['native']).convert('RGBA')
            src=BASE/e['source']
            origin='accepted v1 artwork reused byte-for-byte; not regenerated'
            source=str(src.relative_to(FIELD))
        im=cells[name]
        alpha=np.array(im)[:,:,3]
        bbox=im.getbbox()
        assert im.size==(64,64) and set(np.unique(alpha))<={0,255}
        assert bbox[0]>=2 and bbox[1]>=2 and bbox[2]<=62 and bbox[3]<=52
        entries.append({'id':name,'origin':origin,'source':source,'source_sha256':sha(src),'visible_size':figures[name].size,'native_cell_sha256':__import__('hashlib').sha256(im.tobytes()).hexdigest(),'hash_kind':'decoded RGBA pixels','baseline_native_file_sha256':sha(BASE/'native'/f'{name}_64.png') if name in PRESERVED else None})
    sheet=Image.new('RGBA',(192,192))
    for i,name in enumerate(ORDER):sheet.alpha_composite(cells[name],((i%3)*64,(i//3)*64))
    enlarged(sheet).save(HERE/'identity_sheet.png')
    grey=Image.new('RGBA',sheet.size,GREY)
    grey.alpha_composite(sheet)
    enlarged(grey).save(HERE/'identity_sheet_grey.png')
    # Same six accepted cells at precisely the same scale and position as v1.
    previous=Image.open(BASE/'identity_sheet.png').convert('RGBA')
    result=enlarged(sheet)
    for name in PRESERVED:
        i=ORDER.index(name)
        box=((i%3)*384,(i//3)*384,(i%3+1)*384,(i//3+1)*384)
        assert previous.crop(box).tobytes()==result.crop(box).tobytes(),name
    before_after=Image.new('RGBA',(192,128),GREY)
    for col,name in enumerate(REVISED):
        before_after.alpha_composite(Image.open(BASE/'native'/f'{name}_64.png').convert('RGBA'),(col*64,0))
        before_after.alpha_composite(cells[name],(col*64,64))
    enlarged(before_after).save(HERE/'revision_before_after.png')
    preview=before_after.crop((0,64,192,128))
    enlarged(preview).save(HERE/'revision_preview.png')
    # Preserve exact original N1 overview pixels and x6 accepted cast scale.
    cast=Image.open(FIELD/'batch_N1_claude/overview_x6.png').convert('RGBA')
    comparison=Image.new('RGBA',(2304,768+cast.height),GREY)
    groups=[['patriot','rat_king','eikthyrnir','zaro_standing','zaro_lying'],['crownslayer','skullshatterer','hollow_snowpriest','father_agnir']]
    for row,group in enumerate(groups):
        for col,name in enumerate(group):comparison.alpha_composite(enlarged(cells[name]),(col*384,row*384))
    for path,col,row in [('batch_N1_claude/native/armed.png',5,0),('batch_N1_claude/native/fallen_snowpriest.png',4,1),('batch_N4_v1/identity_family_soldier_native.png',5,1)]:
        comparison.alpha_composite(enlarged(cell(Image.open(FIELD/path).convert('RGBA'))),(col*384,row*384))
    comparison.alpha_composite(cast,((2304-cast.width)//2,768))
    comparison.save(HERE/'identity_sheet_with_cast.png')
    shuffled=IDS.copy()
    random.Random(20261020).shuffle(shuffled)
    blind=Image.new('RGBA',(3072,800),GREY)
    for i,name in enumerate(IDS):
        ref=Image.open(INPUT/'refs_B1/prts'/f'enemy_{name}.png').convert('RGBA').resize((256,256),Image.Resampling.NEAREST)
        blind.alpha_composite(ref,(i*384+64,48))
    for i,name in enumerate(shuffled):blind.alpha_composite(enlarged(cells['zaro_lying' if name=='zaro' else name]),(i*384,416))
    blind.save(HERE/'identity_vs_prts.png')
    (HERE/'identity_vs_prts_key.md').write_text('# Private blind-match key\n\nTop, left to right: '+', '.join(IDS)+'.\n\nBottom, left to right: '+', '.join(shuffled)+'.\n\nDo not show this to the independent reviewer. User approval pending.\n',encoding='utf-8')
    ground=[]
    for region,names in {'mine':['patriot','crownslayer'],'city':['rat_king','skullshatterer'],'snow':['eikthyrnir','hollow_snowpriest']}.items():
        src=FIELD/f'surface_{region}_v2.png'
        bg=Image.open(src).convert('RGBA').resize((256,256),Image.Resampling.BOX).crop((0,0,256,128))
        for i,name in enumerate(names):bg.alpha_composite(cells[name],(32+i*128,40))
        enlarged(bg).save(HERE/f'identity_on_{region}_surface_x6.png')
        ground.append({'region':region,'source':str(src.relative_to(FIELD)),'sha256':sha(src),'evidence':'static texture composite, not runtime evidence'})
    # Palette-only comparison: full-colour BOX then approved future FASTOCTREE candidate.
    palette=Image.new('RGBA',(512,128),GREY)
    palette_counts={}
    for row,method in enumerate([None,Image.Quantize.FASTOCTREE]):
        palette_counts[str(method)]={}
        for col,name in enumerate(IDS):
            im=figures['zaro_lying' if name=='zaro' else name].copy()
            if method is not None:
                a=im.getchannel('A')
                im=im.convert('RGB').quantize(colors=16,method=method,dither=Image.Dither.NONE).convert('RGBA')
                im.putalpha(a)
            palette.alpha_composite(cell(im),(col*64,row*64))
            palette_counts[str(method)][name]={kind:colour_count(im,kind) for kind in ['red','orange','purple','blue']}
    enlarged(palette).save(HERE/'qa/fullcolour_vs_fast_octree.png')
    (HERE/'qa/palette_counts.json').write_text(json.dumps(palette_counts,indent=2),encoding='utf-8')
    # Rat cane lower-shaft scan: source position isolates the external shaft, not coat.
    rat=np.array(figures['rat_king'])
    rows=[]
    for y in range(24,33):
        xs=np.where((rat[y,:,3]>0)&(np.arange(rat.shape[1])>=28))[0]
        dark=[int(x) for x in xs if rat[y,x,:3].mean()<140]
        rows.append({'native_y':y,'external_shaft_pixels':len(xs),'dark_shaft_pixels':len(dark),'x':xs.tolist()})
    # Manual landmark annotations on painted source, then measured at native scale.
    eik,box=crop_source(HERE/'source_paintings/eikthyrnir_generated.png')
    scale=figures['eikthyrnir'].height/eik.height
    hammer_extension=(380-20)*scale
    assert hammer_extension>=4
    report={'technical_status':'PASS','characters':8,'poses':9,'revised_figures':REVISED,'accepted_figures_unchanged':PRESERVED,'preservation_evidence':'v1 source and encoded native hashes checked against original v1 manifest; accepted x6 sheet cells pixel-identical','native_heights':{n:figures[n].height for n in REVISED},'native_cells':'64x64, binary alpha, >=2px clear border, common foot baseline51','preview':'BOX to game size, x6 nearest','blind_match':'PENDING user; no labels or names on image','revision_review':{'patriot':'Visually checked branching antlers, single visible red eye, front tower shield/orange X, halberd/banner, ragged pale cloak at native x6','eikthyrnir':{'hammer':'dark head, single cyan band outside coat','face':'warm tan face with dark hair covering one eye','hammer_protrusion_px':round(hammer_extension,2),'measurement':'manual source landmarks: head outer x20, adjacent mantle outer x380; multiplied by BOX native scale'},'rat_king':{'cane':'gold knob, dark thick diagonal shaft extended outside coat; lower shaft isolated from body','native_external_shaft_scan':rows}},'palette':'FASTOCTREE 16-colour diagnostic included. Stage1 remains full colour BOX; stage2 must use fast octree per revision, complete bake unperformed.','ground':ground,'stage_2':'NOT STARTED; v2 user identity approval required','engine_integration':'NOT PERFORMED; static image review only'}
    assert all(row['dark_shaft_pixels']>=2 for row in rows),rows
    (HERE/'qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    manifest={'stage':1,'version':2,'status':'READY_FOR_USER_IDENTITY_REVIEW','revised':REVISED,'preserved':PRESERVED,'identity_sheet_order':ORDER,'figures':entries,'acceptance':'v2 blind match and user approval pending','private_answer':'identity_vs_prts_key.md','future_bake_quantizer':'FASTOCTREE, not MEDIANCUT'}
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    provenance={'tool':'built-in image_gen','revision_input':'../B1_revision_v2_inputs/B1_revision_v2.md','updated_brief':'../B1_revision_v2_inputs/B_bosses_brief_v1.md','brief_sha256':sha(INPUT/'B_bosses_brief_v1.md'),'reference_source':'../B1_revision_v2_inputs/refs_B1/prts_sources.md','patriot_model':'../B1_revision_v2_inputs/refs_B1/prts/patriot_model/stance1_marching_idle.png','edit_targets':['../batch_B1_v1/source_paintings/eikthyrnir_generated.png','../batch_B1_v1/source_paintings/rat_king_generated.png'],'prompts':'generation_prompts.json','method':'Only three painted source revisions. Code performs BOX resampling, alpha thresholding, assembly, measurements and packaging; no geometry drawing or manual pixel repainting.','explicit_emblem_exceptions':['Patriot tower shield orange X','accepted Father Agnir chest gold cross'],'review_status':'Five character identities accepted per user review (six poses); three revised identities pending approval.','sources':[{'file':str(p.relative_to(HERE)),'sha256':sha(p)} for p in sorted((HERE/'source_paintings').glob('*.png'))]}
    (HERE/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
    (HERE/'README.md').write_text('''# B1 stage 1, revision v2

Only Patriot, Eikthyrnir and Rat King are revised in this directory. Six accepted poses remain in batch_B1_v1 and are reused unchanged. No v1 art or bake script is modified.

Patriot is redrawn with branching deer antlers, one visible red eye, a huge front tower shield with orange X, a rusted halberd and tattered orange-red banner, hose and ragged grey cloak. Eikthyrnir has a larger dark hammer with one cyan band outside the coat, a warm skin-tone face and dark hair over one eye. Rat King has a thicker, longer cane angled out in front of the coat; a second cane edit ensures it survives at 36px.

identity_sheet.png is transparent, 3x3 at x6 native scale. Order is Patriot, Rat King, Eikthyrnir; Zaro lying, Crownslayer, Skullshatterer; Hollow Snowpriest, Father Agnir, Zaro standing. identity_sheet_grey.png is for display. All six accepted pose cells are pixel-identical to v1.

revision_before_after.png: top v1, bottom v2; columns Patriot, Rat King, Eikthyrnir. revision_preview.png shows only the revised row. identity_sheet_with_cast.png includes accepted N1/N4 figures at the same native x6 scale and the untouched N1 overview below.

identity_vs_prts.png has PRTS portraits in brief order above shuffled game-size figures. No labels. Keep identity_vs_prts_key.md private until after blind review. The v2 user approval is PENDING. Do not begin stage2 before approval (B1_revision_v2.md, Unchanged).

Ground previews are static surface composites, not new engine screenshots. Palette comparison: qa/fullcolour_vs_fast_octree.png top full-colour BOX, bottom 16-colour FASTOCTREE. Stage1 retains BOX full colour; stage2 must use fast octree per the revision. This diagnostic does not prove full bake, animation, Godot import, playback or user acceptance.

Prompts and provenance are bundled. Rebuild with python build_revision.py from the archive's art/field-style root. The archive includes v1 baseline, revision input package, cast references and project surface files as dependencies. Code only assembles and validates; original source art comes from built-in image_gen. Technical checks and manual landmark measurements are in qa_report.json.
''',encoding='utf-8')
    archive=FIELD/'B1_stage1_v2_review.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for root in [HERE,BASE,INPUT]:
            for p in sorted(root.rglob('*')):
                if p.is_file() and p.suffix!='.import' and '__pycache__' not in p.parts:z.write(p,str(p.relative_to(FIELD)))
        for path in ['batch_N1_claude/overview_x6.png','batch_N1_claude/native/armed.png','batch_N1_claude/native/fallen_snowpriest.png','batch_N4_v1/identity_family_soldier_native.png','surface_mine_v2.png','surface_city_v2.png','surface_snow_v2.png']:
            z.write(FIELD/path,path)
    with zipfile.ZipFile(archive) as z:assert z.testzip() is None
    print(json.dumps({'status':'PASS','revised':REVISED,'preserved_poses':6,'rat_cane_min_scan_width':min(r['external_shaft_pixels'] for r in rows),'eik_hammer_extension':hammer_extension,'archive':str(archive),'archive_bytes':archive.stat().st_size},indent=2))

if __name__=='__main__':main()
