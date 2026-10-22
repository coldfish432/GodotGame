"""Assemble imagegen paintings, BOX game-size identities and review artifacts.

No character geometry is drawn by this script. Stage 2 remains approval-gated.
"""
from pathlib import Path
import hashlib
import json
import random
import shutil
import zipfile
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
FIELD=HERE.parent
REFS=FIELD/'refs_B1'
IDS=['patriot','rat_king','eikthyrnir','zaro','crownslayer','skullshatterer','hollow_snowpriest','father_agnir']
HEIGHTS={'patriot':46,'rat_king':36,'eikthyrnir':46,'zaro':38,'crownslayer':30,'skullshatterer':32,'hollow_snowpriest':33,'father_agnir':31}
ORDER=['patriot','rat_king','eikthyrnir','zaro_lying','crownslayer','skullshatterer','hollow_snowpriest','father_agnir','zaro_standing']
GREY=(49,53,59,255)

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def crop_source(path):
    im=Image.open(path).convert('RGBA')
    box=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    assert box, path
    return im.crop(box),box

def binary(im):
    a=np.array(im)
    a[:,:,3]=np.where(a[:,:,3]>128,255,0)
    a[a[:,:,3]==0]=0
    return Image.fromarray(a)

def reduce_height(im,height):
    # All trials are BOX reductions of the original painting, not repeated
    # filtering. Choose the scale whose visible alpha height meets the contract.
    choices=[]
    for canvas_h in range(max(1,height-2),height+5):
        out=binary(im.resize((max(1,round(im.width*canvas_h/im.height)),canvas_h),Image.Resampling.BOX))
        box=out.getbbox()
        if box:
            sprite=out.crop(box)
            choices.append((abs(sprite.height-height),abs(canvas_h-height),sprite))
    choices.sort(key=lambda item:item[:2])
    result=choices[0][2]
    assert result.height==height,(result.size,height)
    return result

def cell(sprite):
    assert sprite.width<=60 and sprite.height<=50,sprite.size
    out=Image.new('RGBA',(64,64))
    out.alpha_composite(sprite,((64-sprite.width)//2,52-sprite.height))
    return out

def enlarged(im): return im.resize((im.width*6,im.height*6),Image.Resampling.NEAREST)

def colour_count(im,kind):
    a=np.array(im).astype(int)
    r,g,b=a[:,:,0],a[:,:,1],a[:,:,2]
    masks={'red':(r>100)&(r>g*1.6)&(r>b*1.25),'orange':(r>140)&(g>55)&(g<190)&(b<110),'purple':(r>100)&(b>140)&(b>g*1.25),'blue':(b>60)&(b>r*1.3)&(b>g*1.15)}
    return int((masks[kind]&(a[:,:,3]>0)).sum())

def main():
    native=HERE/'native'
    native.mkdir(exist_ok=True)
    source={}
    for ident in ORDER:
        path=HERE/'source_paintings'/f'{ident}_generated.png'
        assert path.exists(),path
        source[ident]=crop_source(path)
    figures={}
    for ident in ORDER:
        if ident.startswith('zaro'): continue
        figures[ident]=reduce_height(source[ident][0],HEIGHTS[ident])
    # Reviewed source landmark: shoulder/back below the tallest ruff tuft at
    # image y440, soles at y1065. 38/(1065-440) gives a 60x48px wolf.
    zaro_im,zaro_box=source['zaro_standing']
    shoulder_y=440
    shoulder_scale=38/(zaro_box[3]-shoulder_y)
    standing=binary(zaro_im.resize((round(zaro_im.width*shoulder_scale),round(zaro_im.height*shoulder_scale)),Image.Resampling.BOX))
    standing=standing.crop(standing.getbbox())
    assert standing.width<=60,standing.size
    figures['zaro_standing']=standing
    lying=source['zaro_lying'][0]
    # Match physical body length, rather than inflating a lying wolf to 38px tall.
    figures['zaro_lying']=binary(lying.resize((standing.width,round(lying.height*standing.width/lying.width)),Image.Resampling.BOX))
    figures['zaro_lying']=figures['zaro_lying'].crop(figures['zaro_lying'].getbbox())
    assert figures['zaro_lying'].height<standing.height
    cells={ident:cell(figures[ident]) for ident in ORDER}
    for ident in ORDER:
        figures[ident].save(native/f'{ident}.png')
        cells[ident].save(native/f'{ident}_64.png')
    sheet=Image.new('RGBA',(192,192))
    for i,ident in enumerate(ORDER): sheet.alpha_composite(cells[ident],((i%3)*64,(i//3)*64))
    enlarged(sheet).save(HERE/'identity_sheet.png')
    grey=Image.new('RGBA',sheet.size,GREY)
    grey.alpha_composite(sheet)
    enlarged(grey).save(HERE/'identity_sheet_grey.png')
    # Native x6 figures beside accepted native x6 references. The untouched
    # overview is included below, with its exact original size and pixels.
    cast=Image.open(FIELD/'batch_N1_claude/overview_x6.png').convert('RGBA')
    comparison=Image.new('RGBA',(2304,768+cast.height),GREY)
    groups=[['patriot','rat_king','eikthyrnir','zaro_standing','zaro_lying'],['crownslayer','skullshatterer','hollow_snowpriest','father_agnir']]
    for row,group in enumerate(groups):
        for col,ident in enumerate(group): comparison.alpha_composite(enlarged(cells[ident]),(col*384,row*384))
    old=[('batch_N1_claude/native/armed.png',5,0),('batch_N1_claude/native/fallen_snowpriest.png',4,1),('batch_N4_v1/identity_family_soldier_native.png',5,1)]
    for path,col,row in old:
        sprite=Image.open(FIELD/path).convert('RGBA')
        comparison.alpha_composite(enlarged(cell(sprite)),(col*384,row*384))
    comparison.alpha_composite(cast,((2304-cast.width)//2,768))
    comparison.save(HERE/'identity_sheet_with_cast.png')
    # No names, labels, badges or row captions in the blind comparison image.
    shuffled=IDS.copy()
    random.Random(20261019).shuffle(shuffled)
    blind=Image.new('RGBA',(3072,800),GREY)
    for i,ident in enumerate(IDS):
        ref=Image.open(REFS/'prts'/f'enemy_{ident}.png').convert('RGBA')
        ref=ref.resize((256,256),Image.Resampling.NEAREST)
        blind.alpha_composite(ref,(i*384+64,48))
    for i,ident in enumerate(shuffled):
        sprite=cells['zaro_lying' if ident=='zaro' else ident]
        blind.alpha_composite(enlarged(sprite),(i*384,416))
    blind.save(HERE/'identity_vs_prts.png')
    (HERE/'identity_vs_prts_key.md').write_text('# B1 blind comparison answer\n\nTop row, left to right: '+', '.join(IDS)+'.\n\nBottom row, left to right: '+', '.join(shuffled)+'.\n\nZaro uses the lying phase-1 identity. Do not show this key to the independent reviewer. No blind-match result has been claimed.\n',encoding='utf-8')
    fallen=Image.open(FIELD/'batch_N1_claude/native/fallen_snowpriest.png').convert('RGBA')
    snow_compare=Image.new('RGBA',(128,64),GREY)
    snow_compare.alpha_composite(cells['hollow_snowpriest'],(0,0))
    snow_compare.alpha_composite(cell(fallen),(64,0))
    enlarged(snow_compare).save(HERE/'hollow_vs_fallen.png')
    ground=REFS/'ground'
    ground.mkdir(exist_ok=True)
    ground_sources={}
    regions={'mine':['patriot','crownslayer'],'city':['rat_king','skullshatterer'],'snow':['eikthyrnir','hollow_snowpriest']}
    for region,group in regions.items():
        src=FIELD/f'surface_{region}_v2.png'
        shutil.copy2(src,ground/f'{region}_project_surface.png')
        bg=Image.open(src).convert('RGBA').resize((256,256),Image.Resampling.BOX).crop((0,0,256,128))
        for i,ident in enumerate(group): bg.alpha_composite(cells[ident],(32+i*128,40))
        enlarged(bg).save(HERE/f'identity_on_{region}_surface_x6.png')
        ground_sources[region]={'kind':'static project surface composite, not engine screenshot','source':str(src),'sha256':sha(src)}
    rain_src=FIELD.parent/'_to_sol/recruit_N4_work_v1/N4_siracusa_enemies/refs_N4/siracusa_ingame_rain.png'
    shutil.copy2(rain_src,ground/'siracusa_ingame_rain_reference.png')
    rain=Image.open(rain_src).convert('RGBA')
    for ident,x,y in [('zaro_lying',720,540),('zaro_standing',890,470),('father_agnir',500,480)]:
        sprite=cells[ident].resize((128,128),Image.Resampling.NEAREST)
        rain.alpha_composite(sprite,(x-64,y-104))
    rain.save(HERE/'identity_on_siracusa_rain_composite.png')
    ground_sources['siracusa']={'kind':'static composite on a prior engine screenshot; new sprites not runtime rendered or relit','source':str(rain_src),'sha256':sha(rain_src),'sprite_scale':2}
    (ground/'ground_sources.json').write_text(json.dumps(ground_sources,indent=2),encoding='utf-8')
    features={'patriot_red_pixels':colour_count(figures['patriot'],'red'),'zaro_standing_red_pixels':colour_count(standing,'red'),'zaro_lying_red_pixels':colour_count(figures['zaro_lying'],'red'),'skullshatterer_orange_pixels':colour_count(figures['skullshatterer'],'orange'),'hollow_purple_pixels':colour_count(figures['hollow_snowpriest'],'purple'),'hollow_blue_pixels':colour_count(figures['hollow_snowpriest'],'blue')}
    assert all(value>0 for value in features.values()),features
    entries=[]
    for ident in ORDER:
        im=cells[ident]
        a=np.array(im)
        assert im.size==(64,64) and set(np.unique(a[:,:,3])).issubset({0,255})
        b=im.getbbox()
        assert b and b[0]>=2 and b[2]<=62 and b[1]>=2 and b[3]<=52,(ident,b)
        original=HERE/'source_paintings'/f'{ident}_generated.png'
        entries.append({'id':ident,'source':str(original.relative_to(HERE)),'source_sha256':sha(original),'native':f'native/{ident}.png','native_cell':f'native/{ident}_64.png','visible_size':list(figures[ident].size),'foreground_bbox':list(b),'native_cell_sha256':sha(native/f'{ident}_64.png')})
    manifest={'stage':1,'status':'READY_FOR_USER_IDENTITY_REVIEW','figures':entries,'reference_order':IDS,'identity_sheet_order':ORDER,'target_heights':HEIGHTS,'scale':{'cell':64,'foot_y_inclusive':51,'preview_scale':6,'downscale':'BOX from generated painting; binary alpha >128; no source palette quantization','zaro_standing_shoulder_y_source':shoulder_y,'zaro_source_sole_y_exclusive':zaro_box[3],'zaro_shoulder_height':38,'zaro_scale':shoulder_scale,'zaro_note':'Shoulder landmark below tallest ruff tuft, manually reviewed in this three-quarter identity. Lying pose uses standing body length; final S/profile board calibration remains stage 2.'},'stage_2':'NOT STARTED; user identity approval required','stage_3':'NOT STARTED'}
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    report={'technical_status':'PASS','characters':8,'poses':9,'references':8,'cell_borders':'PASS: at least 2px transparent at every 64px cell edge','native_heights':'PASS for seven humanoids; Zaro uses 38px shoulder calibration, both poses <=60px wide','alpha':'native binary; transparent identity sheet; original imagegen alpha retained in sources','preview_scaling':'native x6 nearest-neighbour','blind_panel':'8 PRTS portraits in brief order; 8 shuffled native identity figures; no added text or labels','feature_colour_presence':features,'blind_identification':'PENDING independent reviewer, then user approval','visual_identity_and_size_acceptance':'PENDING user review','ground_checks':ground_sources,'engine_integration':'NOT PERFORMED; stage 1 static art review only','future_bake':'Stage-2 16-colour bake, dynamic poses, anatomical registration and all eight S/profile/rear directions remain untested.'}
    import subprocess, sys
    subprocess.run([sys.executable,str(HERE/'compare_quantizers.py')],check=True,capture_output=True)
    palette=json.loads((HERE/'qa/quantizer_counts.json').read_text(encoding='utf-8'))
    report['palette_only_diagnostic']={'results':'qa/quantizer_counts.json','preview':'qa/quantizer_comparison.png','rows':['full-colour BOX','16-colour median cut','16-colour fast octree'],'counts':palette,'finding':'Median cut loses Patriot red/orange, Zaro lying red and Hollow face purple. Fast octree preserves those colour categories in this diagnostic. Full-colour stage-1 previews retained; complete stage-2 bake remains untested.'}
    (HERE/'qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    provenance={'date':'2026-10-19 America/New_York','tool':'built-in image_gen','method':'Nine original painted sprite identities, PRTS icons used only as visual reference; deterministic cropping, BOX downscale and assembly','source_reference_manifest':'../refs_B1/reference_manifest.json','style_reference':['../batch_N1_claude/identity_sheet.png','../batch_N1_claude/overview_x6.png','../batch_N4_v1/identity_sheet.png'],'brief':'../B_bosses_brief_v1.md','brief_sha256':sha(FIELD/'B_bosses_brief_v1.md'),'approval_boundary':'Identity art is not approved yet. Stop before stage 2. User authorized self-sourcing references, not bypassing identity approval.','interpretations':['Father Agnir has an eye-covering white band as the brief explicitly requires; the supplied PRTS portrait has its wrap higher.','Father Agnir chest cross is the explicit exception to the generic no-emblem rule.','Zaro lying and standing are the same physical body length; do not scale lying silhouette height to standing shoulder height.','Stage 1 uses the explicit BOX preview instruction. Stage-2 palette and feature survival require a separate bake review.'],'sources':[{'file':str(p.relative_to(HERE)),'sha256':sha(p)} for p in sorted((HERE/'source_paintings').glob('*.png'))]}
    (HERE/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
    readme='''# B1 stage 1 identity review

Eight characters, nine identity poses: Zaro is supplied lying in phase-1 IDLE and standing. All views are three-quarter front-right. This is identity art for approval, not action/walk boards.

`identity_sheet.png`: transparent 3x3, manifest order, game-size sprites enlarged x6 nearest-neighbour. `identity_sheet_grey.png`: identical art on grey for display.

`identity_sheet_with_cast.png`: bosses next to an accepted elite on the first row; wardens next to the old Fallen Snowpriest and N4 family soldier on the second. The original, unscaled N1 overview_x6 is preserved below. All character comparisons use the same x6 native scale.

`identity_vs_prts.png`: top PRTS portraits in brief order, bottom shuffled native identities, no added labels. Keep `identity_vs_prts_key.md` away from the independent reviewer. Blind matching and user acceptance are PENDING.

`hollow_vs_fallen.png`: left new Hollow Snowpriest, right existing Fallen Snowpriest, both x6 native. Ground images are static composites. Siracusa uses an existing rainy in-game screenshot as a background; this batch has not been imported, relit or rendered in-engine. Ground source paths and hashes are under ../refs_B1/ground/ground_sources.json.

Source paintings keep full colour and real alpha. Native previews follow stage-1 BOX downscale and x6 nearest-neighbour, with binary native alpha. Stage-2 16-colour bake is not yet performed. Zaro shoulder height is calibrated using a reviewed source landmark; the final S view and 60px W/E profile require separate board-stage checks.

Palette-only diagnostic: qa/quantizer_comparison.png shows full-colour BOX, 16-colour median cut, and 16-colour fast octree in that row order. Median cut removes key identity colours (Patriot red/orange, Zaro lying red, Hollow face purple). Fast octree retains those colour categories, but a complete stage-2 bake and visual acceptance remain pending. Counts are diagnostic thresholds, not an identity-recognition result.

Rebuild: python build_stage1.py. All references, prompt text, original generations, processing code, manifest, provenance and technical QA are included. No accepted N1/N4 assets or bake_n2.py were changed. No stage-2 action/walk boards or stage-3 equipment icons were started.
'''
    (HERE/'README.md').write_text(readme,encoding='utf-8')
    archive=FIELD/'B1_stage1_v1_review.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for base in [HERE,REFS]:
            for path in sorted(base.rglob('*')):
                if path.is_file() and '__pycache__' not in path.parts and path.suffix!='.import': z.write(path,str(path.relative_to(FIELD)))
        z.write(FIELD/'B_bosses_brief_v1.md','B_bosses_brief_v1.md')
        z.write(FIELD/'fetch_b1_refs.py','fetch_b1_refs.py')
    with zipfile.ZipFile(archive) as z: assert z.testzip() is None
    print(json.dumps({'status':'PASS','characters':8,'poses':9,'features':features,'zaro_standing_size':standing.size,'zaro_lying_size':figures['zaro_lying'].size,'zip_bytes':archive.stat().st_size,'zip_crc':'PASS'},indent=2))

if __name__=='__main__': main()
