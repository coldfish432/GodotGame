from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    result=json.loads((ROOT/'validation.json').read_text(encoding='utf-8'))
    assert result['status']=='PASS' and result['icons']==36
    files=[p for p in sorted(ROOT.rglob('*')) if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ['.pyc','.b64','.import'] and p.name not in ['delivery_manifest.json','partial_preview.png']]
    manifest={'batch':'BG1_v1','count':36,'generator':'built-in image_gen.imagegen','art_acceptance':'PENDING_REVIEW','static_validation':'PASS','godot_runtime_tested':False,'files':{p.relative_to(ROOT).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in files}}
    (ROOT/'delivery_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');files.append(ROOT/'delivery_manifest.json')
    archive=ROOT.parent.parent/'_to_sol/BG1_boss_gear_icons_v1.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in files:z.write(p,'batch_BG1_v1/'+p.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for p in files:assert hashlib.sha256(z.read('batch_BG1_v1/'+p.relative_to(ROOT).as_posix())).hexdigest()==sha(p)
    receipt={'file':archive.name,'members':len(files),'bytes':archive.stat().st_size,'sha256':sha(archive),'zip_crc':'PASS','members_equal_delivered_files':True}
    archive.with_suffix('.zip.qa.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8');print(json.dumps(receipt))
if __name__=='__main__':main()
