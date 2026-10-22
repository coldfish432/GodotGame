"""B2 stage1 only: painted identity registration, native reduction, review composites."""
from pathlib import Path
import sys,json,hashlib,zipfile
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'pipeline'))
import bake_n2 as bake
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def crop(im):
    a=np.array(im.convert('RGBA'));ys,xs=np.where(a[:,:,3]>128)
    assert len(ys)
    return im.crop((int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)))
def paste_bottom(out,im,x,foot):out.paste(im,(x,foot-im.height),im)
def main():
    source=Image.open(ROOT/'sources/civilian_identity_raw.png').convert('RGBA')
    source_box=source.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox()
    fig=source.crop(source_box);factor=232/fig.height
    fig=fig.resize((round(fig.width*factor),232),Image.Resampling.LANCZOS)
    clean=Image.new('RGBA',(256,256));clean.alpha_composite(fig,((256-fig.width)//2,248-fig.height))
    clean.save(ROOT/'identity.png')
    # Stage1 preview is calibrated to exactly26 visible pixels including the
    # outline. No project/pipeline script or stage2 board is changed.
    scale=bake.b1_reference_scale(clean,26,Image.Quantize.FASTOCTREE)
    native=bake.bake_cell(clean,scale,Image.Quantize.FASTOCTREE,fit_within_cell=True)
    assert native.getbbox()[3]-native.getbbox()[1]==26
    native.save(ROOT/'identity_64.png')
    native.resize((384,384),Image.Resampling.NEAREST).save(ROOT/'identity_64_x6.png')
    soldier_sheet=Image.open(ROOT/'refs/enemy_dir_family_soldier_64.png').convert('RGBA')
    # SW column of accepted first row is the 3/4 comparison, unchanged.
    soldier=soldier_sheet.crop((64,0,128,64))
    portrait=Image.open(ROOT/'refs/prts/enemy_civilian.png').convert('RGBA')
    bg=(48,51,54,255)
    comp=Image.new('RGBA',(576,224),bg)
    portrait.thumbnail((158,158));comp.alpha_composite(portrait,((192-portrait.width)//2,(224-portrait.height)//2))
    for i,img in enumerate([native,soldier],1):
        large=crop(img).resize((crop(img).width*6,crop(img).height*6),Image.Resampling.NEAREST)
        paste_bottom(comp,large,i*192+(192-large.width)//2,196)
    comp.save(ROOT/'identity_vs_prts.png')
    # Existing lineup already at6x: append new figures without rescaling it.
    old=Image.open(ROOT/'refs/batch_N1_claude/overview_x6.png').convert('RGBA')
    cast=Image.new('RGBA',(old.width+384,old.height),bg);cast.alpha_composite(old,(384,0))
    for i,img in enumerate([native,soldier]):
        large=crop(img).resize((crop(img).width*6,crop(img).height*6),Image.Resampling.NEAREST)
        paste_bottom(cast,large,i*192+(192-large.width)//2,216)
    cast.save(ROOT/'identity_with_cast.png')
    # Offline evidence: place six civilians on clear piazza stones next to
    # the six placeholder NPCs in the supplied screenshot. Preserve original
    # screenshot pixels except the explicitly added foreground masks.
    ground=Image.open(ROOT/'refs/siracusa_arena_ingame.png').convert('RGBA')
    positions=[(589,187),(406,295),(863,295),(406,485),(863,485),(695,554)]
    foreground=crop(native)
    for x,foot in positions:paste_bottom(ground,foreground,x,foot)
    ground.save(ROOT/'identity_on_ground_native_1x.png')
    ground=Image.open(ROOT/'refs/siracusa_arena_ingame.png').convert('RGBA')
    # Approximate the supplied screenshot's enlarged actor presentation;
    # keep a separate literal1x overlay as well. This is not engine evidence.
    foreground=foreground.resize((round(foreground.width*1.5),39),Image.Resampling.NEAREST)
    for x,foot in positions:paste_bottom(ground,foreground,x,foot)
    ground.save(ROOT/'identity_on_ground.png')
    inset=ground.crop((350,225,460,325)).resize((660,600),Image.Resampling.NEAREST)
    inset.save(ROOT/'ground_detail_x6.png')
    manifest={'batch':'B2_v1 stage1 identity','character':'civilian','status':'READY_FOR_IDENTITY_REVIEW','generator':'built-in image_gen.imagegen','native_visible_height':26,'source_bbox':source_box,'registration_scale':factor,'native_bake_scale':scale,'native_reference_calibration':'b1_reference_scale to26 visible pixels; identity preview only','soldier_reference':'refs/enemy_dir_family_soldier_64.png, row1 column2 SW','comparison_order':['PRTS portrait','civilian native x6','accepted family soldier native x6'],'cast_order':'civilian, family soldier, unmodified N1 overview at original6x','ground_evidence':'Offline composite over supplied screenshot; new civilians placed beside existing placeholder NPCs. Not a runtime capture. Main overlay uses assumed1.5x screen scale (39px); literal native1x overlay also supplied. Camera projection is not verified.','ground_placements_bottom_left':positions,'source_sha256':sha(ROOT/'sources/civilian_identity_raw.png'),'pipeline_hashes':{n:sha(ROOT/'pipeline'/n) for n in ['bake_n2.py','reduce_n1.py']},'no_action_or_walk_boards_created':True,'approval_gate':'Source brief: The user approves it before you start the boards.'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps({'native_bbox':native.getbbox(),'native_height':26,'identity':clean.size,'native_scale':scale}))
if __name__=='__main__':main()
