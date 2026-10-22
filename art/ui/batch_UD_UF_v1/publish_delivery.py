"""Copy the verified 18 new assets into the exact brief-specified folders."""
from pathlib import Path
import json,hashlib,shutil
B=Path(__file__).resolve().parent
ROOT=B.parents[2].resolve()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((B/'manifest.json').read_text(encoding='utf-8'))
assert len(manifest['files'])==18
allowed={(ROOT/'art/items/runtime').resolve(),(ROOT/'art/ui/key').resolve()}
for r in manifest['files']:
 src=B/'delivery'/r['file'];dst=(ROOT/r['file']).resolve()
 assert dst.parent in allowed
 assert sha(src)==r['sha256']
 if dst.exists():assert sha(dst)==r['sha256'],f'Different existing asset: {dst}'
for r in manifest['files']:
 src=B/'delivery'/r['file'];dst=(ROOT/r['file']).resolve()
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
for filename,folder in [('UD_manifest.json',ROOT/'art/ui/key'),('UF_manifest.json',ROOT/'art/items/runtime')]:
 shutil.copyfile(B/filename,folder/filename)
print('Published18 PNGs +2 manifests; all hashes match.')
