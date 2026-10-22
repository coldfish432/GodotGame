"""Create a self-contained, reproducible review ZIP and verify every member."""
from pathlib import Path
import json,hashlib,zipfile,shutil
ROOT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    inputs=ROOT.parent/'B1_stage2_revision_inputs'
    refs=ROOT/'revision_reference'
    refs.mkdir(exist_ok=True)
    for name in ['B1_stage2_revision_v1.md','B_bosses_brief_v1.md']:
        shutil.copy2(inputs/name,refs/name)
    shutil.copytree(inputs/'refs_B1',refs/'refs_B1',dirs_exist_ok=True)
    for name in ['patriot_action_last_row.png','eikthyrnir_action_last_row.png']:
        p=ROOT/'qa'/name
        if p.exists():p.unlink() # Obsolete previews produced by this revision run.
    jobs=json.loads((ROOT/'generation_jobs.json').read_text(encoding='utf-8'))
    lines=['# Generation provenance','', 'Tool: built-in `image_gen.imagegen`. No CLI fallback. Transparent outputs.','', 'Raw outputs are retained in source_paintings/. Registration and exact selected slots are recorded in assembly_manifest.json. Follow-up outputs supersede the initial attempt only where selected by build_revision.py.','']
    for job in jobs:
        lines+=['## '+job['key'],'','References: '+', '.join(job['refs']),'','```text',job['prompt'],'```','']
    for path in sorted(ROOT.glob('*_prompt.txt')):
        lines+=['## Follow-up: '+path.stem,'','```text',path.read_text(encoding='utf-8'),'```','']
    (ROOT/'generation_prompts.md').write_text('\n'.join(lines),encoding='utf-8')
    report=json.loads((ROOT/'qa/validation_report.json').read_text())
    assert report['status']=='PASS'
    files=[p for p in sorted(ROOT.rglob('*')) if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ['.pyc','.b64','.import'] and p.name!='delivery_manifest.json']
    manifest={'batch':'B1 stage 2 v4 row revision','review_status':'READY_FOR_VISUAL_REVIEW','tool':'built-in image_gen.imagegen','raw_generated_images':len(list((ROOT/'source_paintings').glob('*.png'))),'changed_boards':['patriot_action','patriot_walk','eikthyrnir_action','zaro_action'],'changed_rows':9,'changed_cells':72,'accepted_cells_in_changed_boards_preserved':208,'baseline_file_hashes_verified':48,'baker_modified':False,'static_validation':'PASS','godot_import_tested':False,'godot_playback_tested':False,'files':{p.relative_to(ROOT).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in files}}
    (ROOT/'delivery_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    files.append(ROOT/'delivery_manifest.json')
    archive=ROOT.parent/'B1_stage2_v4_revision_review.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in files:z.write(p,'batch_B1_v4/'+p.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert len(z.infolist())==len(files)
        for p in files:
            assert hashlib.sha256(z.read('batch_B1_v4/'+p.relative_to(ROOT).as_posix())).hexdigest()==sha(p)
    receipt={'archive':archive.name,'bytes':archive.stat().st_size,'sha256':sha(archive),'members':len(files),'crc':'PASS','all_members_equal_delivery_files':True}
    (ROOT.parent/'B1_stage2_v4_revision_review.zip.qa.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print(json.dumps(receipt))
if __name__=='__main__':main()
