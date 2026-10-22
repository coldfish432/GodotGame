from pathlib import Path
import json,hashlib,zipfile,shutil,difflib
from PIL import Image
ROOT=Path(__file__).resolve().parent
FIELD=ROOT.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    qa=json.loads((ROOT/'qa_report.json').read_text())
    assert qa['static_checks']=='PASS' and not qa['pre_crop_clipping'] and not qa['foot_baseline_findings']
    jobs=json.loads((ROOT/'generation_records.json').read_text())
    sections=['# B1 stage2 exact generation prompts\n\nTool: built-in image_gen. All raw source paintings are under source_paintings/. Approved v1/v2 paintings were reference inputs. No CLI/API fallback.\n']
    for group in ['jobs','missing','sw','compact']:
        for j in jobs[group]:
            key=j.get('key',j['id']+'_'+j.get('kind',''))
            sections.append('\n## '+key+'\n\n'+j['prompt']+'\n')
    for p in sorted(ROOT.glob('*_prompt.txt')):sections.append('\n## '+p.stem+'\n\n'+p.read_text(encoding='utf-8')+'\n')
    (ROOT/'generation_prompts.md').write_text('\n'.join(sections),encoding='utf-8')
    original=(ROOT/'pipeline/bake_n2_original.py').read_text(encoding='utf-8')
    current=(FIELD/'bake_n2.py').read_text(encoding='utf-8')
    (ROOT/'bake_patch.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),current.splitlines(True),fromfile='approved-package/bake_n2.py',tofile='art/field/bake_n2.py')),encoding='utf-8')
    shutil.copy2(FIELD/'bake_n2.py',ROOT/'pipeline/bake_n2_delivered.py')
    ids=list(dict.fromkeys(j['id'] for j in jobs['jobs']))
    heights={}
    for id in ids:
        im=Image.open(ROOT/f'{id}_action_64.png').crop((0,0,64,64));b=im.getbbox();heights[id]=b[3]-b[1]
    qa['visible_S_IDLE_heights']=heights
    qa['bake_patch']='B1-only translation clamp after cropping empty transparent padding, oversized-pose rejection, and one reference scale calibrated to approved visible height. The same scale is used across both action and walk boards. No per-cell fitting or resizing. Default/non-B1 function regression:256 pixel comparisons PASS.'
    (ROOT/'qa_report.json').write_text(json.dumps(qa,indent=2),encoding='utf-8')
    sources=[{'file':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in sorted((ROOT/'source_paintings').glob('*.png'))]
    provenance={'tool':'built-in image_gen','status':'STAGE2_REVIEW_CANDIDATE','identity_approval':'../B1_stage2_inputs/B1_accepted_go_stage2.md','approved_identity_sources':'Patriot/Rat King/Eikthyrnir v2; other five identities including both Zaro poses v1. All approved source hashes unchanged.','painted_sources':sources,'prompts':'generation_prompts.md','assembly':'assemble_and_bake.py; hand-reviewed row cuts, remove detached neighboring alpha fragments (keep Agnir halo), crop/resize/repack only. No procedural character drawing. No source mirroring in code.','registration':'Each independently generated board/row is registered with one explicit source-DPI multiplier; multiplier details in assembly_manifest.json. This is not an automatic proof of physical/anatomical continuity.','first_cell':'Approved source painting reused in S/IDLE; first action cell determines all action/walk runtime scales. Zaro action first cell is lying, walk first standing.','bake':'FASTOCTREE16; BOX; supplied outline/thickening method with documented B1-only patch. Original and delivered bake scripts preserved under pipeline/.','bake_patch_regression':'qa/bake_patch_regression.json','runtime_evidence':'No Godot import/playback or fight integration tested. GIFs and contact sheets are offline previews.','approval_boundary':'Stage2 artwork needs user review; stage3 gear icons wait for board acceptance.','interpretations':['The explicit post-release THROW pose uses an empty throwing hand; no flying projectile.','N hides face naturally; identity is retained by silhouette/clothes/equipment.','Independent supplement strips correct missing rows and compact tall poses; visual direction, handedness, physical consistency and pose quality remain user review items.']}
    (ROOT/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
    readme='''# B1 stage2 review candidate (batch_B1_v3)

Eight identities, sixteen clean boards, 776 cells. Painted sources from built-in image_gen, exact prompts included. The accepted stage1 sources in batch_B1_v1/v2 are unchanged.

| id | action grid | walk grid | visible S/IDLE height |
|---|---|---|---|
| patriot | 8x9 | 8x8, first/second stance | 46 |
| rat_king | 8x8 | 8x4 | 36 |
| eikthyrnir | 8x9 | 8x4 | 46 |
| zaro | 8x9, lying IDLE | 8x4 standing trot | 38 lying |
| crownslayer | 8x7 | 8x4 | 30 |
| skullshatterer | 8x6 | 8x4 | 32 |
| hollow_snowpriest | 8x7 | 8x4 | 33 |
| father_agnir | 8x6 | 8x4 | 31 |

Each clean board has 256px square cells, transparent, no labels/grid. Columns S, SW, W, NW, N, NE, E, SE. Rows follow B1_accepted_go_stage2.md. Every board has _64.png and exact nearest-neighbour _64_x6.png. Each figure has _s_rows_x6.png: top action rows left-to-right, bottom walk phases. all_action_s_rows_x6.png shows eight action rows of figures in brief order. Walk GIFs arrange directions in a 4x2 panel; Patriot has one GIF per stance.

The approved source painting is reused in the first S/IDLE cell (approved threequarter pose). Raw model outputs sometimes omitted a row or had wrong-facing SW figures; independently painted supplements fill these, with all exact source-DPI calibration multipliers recorded. Raw generations remain in source_paintings for audit. Code does not construct character poses. Foreground-component cleanup removes cropped neighboring fragments, while preserving Agnir's detached halo.

## Bake repair

The supplied baker silently clipped fitting but asymmetric wolf silhouettes because lower-body centering pushed them past x64. The delivered patch crops only empty padding and clamps B1 placement without resizing; truly oversized poses raise an error. A second B1-only correction calibrates ONE scale from the first action cell to its final visible height after thickening. Every cell and its walk board uses that same scale. Default/non-B1 bake_cell output is unchanged in256 sample comparisons using both quantizers. See bake_patch.diff and qa/bake_patch_regression.json. Both original and delivered scripts are retained in pipeline/.

## Review and evidence boundary

Technical checks cover all776 cells: exact dimensions, binary native alpha, exact x6 previews, pixel equality with the delivered baker, common action/walk scale, visible IDLE heights, actual foreground before compositing (zero cropped pixels), foot bounds and unchanged accepted source hashes. These checks do not prove true profile/back anatomy, handedness, physical body-size continuity, legibility of every mark in every pose, or final art acceptance. Review the baked direction boards, action row overviews and walk GIFs. Godot import, animation playback and fight integration were not tested; previews are offline. This package is a stage2 review candidate, not accepted production art. Stage3 icons wait for board acceptance as required.

## Rebuild

Extract the archive preserving paths (its root corresponds to art/field), then run python batch_B1_v3/assemble_and_bake.py, python batch_B1_v3/validate_stage2.py and python batch_B1_v3/check_bake_patch.py. Use the delivered root bake_n2.py and reduce_n1.py. All walk CLI commands in bake_commands.json use --scale-from their action board. Requires Python, Pillow and NumPy. Historical stage1 metadata is frozen; the acceptance note in B1_stage2_inputs is the current authority.
'''
    (ROOT/'README.md').write_text(readme,encoding='utf-8')
    manifest={'stage':2,'status':'READY_FOR_ART_REVIEW','boards':[{**j,'source':f'{j["id"]}_{j["kind"]}.png','runtime':f'{j["id"]}_{j["kind"]}_64.png','preview':f'{j["id"]}_{j["kind"]}_64_x6.png'} for j in [{'id':j['id'],'kind':j['kind'],'rows':j['rows']} for j in jobs['jobs']]],'cells':776,'source_paintings':len(sources),'visible_S_IDLE_heights':heights,'static_checks':'qa_report.json','approved_stage1':'UNCHANGED','stage3':'NOT STARTED; board acceptance first'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    archive=FIELD/'B1_stage2_v3_review.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for folder in [ROOT,FIELD/'batch_B1_v1',FIELD/'batch_B1_v2',FIELD/'B1_stage2_inputs']:
            for p in sorted(folder.rglob('*')):
                if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ['.import','.b64']:z.write(p,p.relative_to(FIELD).as_posix())
        for name in ['bake_n2.py','reduce_n1.py']:z.write(FIELD/name,name)
    with zipfile.ZipFile(archive) as z:assert z.testzip() is None
    result={'archive':str(archive),'bytes':archive.stat().st_size,'sha256':sha(archive),'CRC':'PASS','boards':16,'cells':776,'sources':len(sources)}
    (FIELD/'B1_stage2_v3_review_manifest.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
