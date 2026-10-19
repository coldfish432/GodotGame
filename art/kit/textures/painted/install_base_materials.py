"""Install reviewed R1-R10 outputs, merging the existing shared manifest."""
from pathlib import Path
import json,shutil,importlib.util
HERE=Path(__file__).resolve().parent
WORK=HERE if (HERE/'generation_specs.json').exists() else HERE/'base_materials_v1'
ROOT=WORK.parent

def install():
    spec=importlib.util.spec_from_file_location('base_validate',WORK/'validate.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.validate()
    entries=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
    for name,e in entries.items():
        for file in [name+'.png',name+'_tile_3x3.png']:shutil.copy2(WORK/'textures'/file,ROOT/file)
    shutil.copy2(WORK/'base_materials_contact.png',ROOT/'base_materials_contact.png')
    shared=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8')) if (ROOT/'manifest.json').exists() else {}
    for name,e in entries.items():
        out=dict(e);out['source']='base_materials_v1/'+e['source'];out['delivery_manifest']='base_materials_v1/manifest.json';shared[name]=out
    (ROOT/'manifest.json').write_text(json.dumps(shared,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    module.validate(True)
    print('Installed 10 textures + 10 previews; merged shared manifest')

if __name__=='__main__':install()
