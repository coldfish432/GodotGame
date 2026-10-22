"""Create a self-contained review archive and verify CRC/content hashes."""
from pathlib import Path
import zipfile,json,hashlib
B=Path(__file__).resolve().parent
zpath=B.parent/'E15a_v1_review.zip'
files=[p for p in B.rglob('*') if p.is_file() and '__pycache__' not in p.parts and not p.name.endswith('.import') and p.name!='ring_quant_debug.png']
assert json.loads((B/'qa_report.json').read_text(encoding='utf-8'))['pass']
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(files):z.write(p,'batch_E15a_v1/'+p.relative_to(B).as_posix())
with zipfile.ZipFile(zpath) as z:
    assert z.testzip() is None
    for p in files:assert hashlib.sha256(z.read('batch_E15a_v1/'+p.relative_to(B).as_posix())).digest()==hashlib.sha256(p.read_bytes()).digest()
print('ZIP CRC + content hashes PASS:',len(files),'files,',zpath.stat().st_size,'bytes')
