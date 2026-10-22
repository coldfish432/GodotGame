"""Regression evidence for the B1 placement-only bake patch."""
from pathlib import Path
import sys,importlib.util,json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent))
import bake_n2 as current
spec=importlib.util.spec_from_file_location('b1_original_baker',ROOT/'pipeline/bake_n2_original.py')
previous=importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)
count=0
for p in sorted(ROOT.glob('*_action.png')):
    im=Image.open(p).convert('RGBA')
    first=current.figure_box(np.array(im.crop((0,0,256,256))))
    scale=.18
    for row in range(2):
        for col in range(8):
            cell=im.crop((col*256,row*256,(col+1)*256,(row+1)*256))
            for method in [Image.Quantize.MEDIANCUT,Image.Quantize.FASTOCTREE]:
                assert current.bake_cell(cell,scale,method).tobytes()==previous.bake_cell(cell,scale,method).tobytes()
                count+=1
too_large=Image.open(ROOT/'zaro_action.png').convert('RGBA').crop((2*256,0,3*256,256))
try:
    current.bake_cell(too_large,1,Image.Quantize.FASTOCTREE,fit_within_cell=True)
except ValueError:
    rejected=True
else:
    raise AssertionError('oversized silhouette was silently cropped')
result={'status':'PASS','default_function_comparisons':count,'methods':['MEDIANCUT','FASTOCTREE'],'oversized_B1_pose_rejected':rejected,'scope':'default/non-B1 bake_cell is pixel-identical on256 samples; B1 explicitly enables transparent-border crop and translation clamp; no sprite resizing'}
(ROOT/'qa/bake_patch_regression.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
