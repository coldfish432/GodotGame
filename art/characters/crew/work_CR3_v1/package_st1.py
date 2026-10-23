"""Package the ST1/CR3 art delivery with provenance and static evidence."""
from pathlib import Path
import json,zipfile,hashlib

ROOT=Path(__file__).resolve().parents[4]
STORY=ROOT/'art/characters/story/batch_ST1_v2'
STAGE=STORY/'stage2'
WORK=Path(__file__).resolve().parent
paths=[]
for directory in [STORY,ROOT/'art/characters/crew/batch_CR3_v1',WORK/'raw']:
    paths.extend(p for p in directory.rglob('*') if p.is_file())
paths.extend(WORK/name for name in ['prompts.json','build_st1.py','validate_st1.py','package_st1.py'])
paths.extend(ROOT/rel for rel in ['art/characters/crew/work_CR_v1/build_crew.py','art/characters/crew/CR_brief_v1.md','art/characters/story/ST1_brief_v2.md','art/ui/portraits/npc_dobermann.png','art/ui/portraits/npc_kaltsit.png'])
manifest={'batch':'ST1_v2 + CR3_v1','files':[{'file':str(p.relative_to(ROOT)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(set(paths)) if p.name!='delivery_manifest.json']}
mp=STAGE/'delivery_manifest.json';mp.write_text(json.dumps(manifest,indent=2),encoding='utf-8');paths.append(mp)
out=ROOT/'art/characters/story/ST1_v2_complete_sources.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(set(paths)):z.write(p,str(p.relative_to(ROOT)))
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(set(z.namelist()))
    print('ZIP CRC PASS:',len(z.namelist()),'files;',out.stat().st_size,'bytes;',out)
