from pathlib import Path
import json
import numpy as np
from PIL import Image
from build_stage1 import IDS,colour_count,cell,enlarged,GREY

ROOT=Path(__file__).resolve().parent
out=Image.new('RGBA',(512,192),GREY)
report={}
for row,method in enumerate([None,Image.Quantize.MEDIANCUT,Image.Quantize.FASTOCTREE]):
    report[str(method)]={}
    for col,ident in enumerate(IDS):
        name='zaro_lying' if ident=='zaro' else ident
        im=Image.open(ROOT/'native'/f'{name}.png').convert('RGBA')
        if method is not None:
            alpha=im.getchannel('A')
            im=im.convert('RGB').quantize(colors=16,method=method,dither=Image.Dither.NONE).convert('RGBA')
            im.putalpha(alpha)
        out.alpha_composite(cell(im),(col*64,row*64))
        report[str(method)][ident]={kind:colour_count(im,kind) for kind in ['red','orange','purple','blue']}
(ROOT/'qa').mkdir(exist_ok=True)
enlarged(out).save(ROOT/'qa/quantizer_comparison.png')
(ROOT/'qa/quantizer_counts.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({kind:{method:report[method][kind] for method in report} for kind in ['patriot','zaro','hollow_snowpriest']},indent=2))
