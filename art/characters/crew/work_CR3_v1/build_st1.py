"""Assemble imagegen paintings into ST1 portraits and CR3 sources; no procedural art."""
from pathlib import Path
import sys, json, hashlib, shutil, zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

WORK = Path(__file__).resolve().parent
CREW = WORK.parent
ROOT = CREW.parents[2]
STORY = ROOT/'art/characters/story/batch_ST1_v2'
BATCH = CREW/'batch_CR3_v1'
STAGE = STORY/'stage2'
PORTRAITS = ROOT/'art/ui/portraits'
DIRS = ['S','SW','W','NW','N','NE','E','SE']
sys.path.insert(0, str(CREW/'work_CR_v1'))
from build_crew import cells, breathe

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def fit(sprite, scale):
    sprite = sprite.crop(sprite.getbbox())
    sprite = sprite.resize((max(1,round(sprite.width*scale)),max(1,round(sprite.height*scale))),Image.Resampling.LANCZOS)
    sprite = sprite.crop(sprite.getbbox())
    out = Image.new('RGBA',(256,256))
    out.alpha_composite(sprite,((256-sprite.width)//2,240-sprite.height))
    return out

def preview32(cell):
    im = cell.resize((32,32), Image.Resampling.BOX)
    a = np.array(im)
    a[:,:,3] = np.where(a[:,:,3]>=128,255,0)
    a[a[:,:,3]==0] = 0
    return Image.fromarray(a)

def portrait(ident):
    im = Image.open(STORY/'paintings'/f'{ident}_standing_painting.png').convert('RGBA')
    # Ignore nearly invisible fringe when determining the proportional fit.
    a=np.array(im.getchannel('A'));bbox=Image.fromarray(np.where(a>=128,255,0).astype('uint8')).getbbox()
    im=im.crop(bbox)
    size=(round(im.width*240/im.height),240)
    assert size[0]<=120
    im=im.resize(size,Image.Resampling.BOX)
    a=np.array(im);a[:,:,3]=np.where(a[:,:,3]>=128,255,0);a[a[:,:,3]==0]=0
    im=Image.fromarray(a);im=im.crop(im.getbbox())
    out=Image.new('RGBA',(120,240));out.paste(im,((120-im.width)//2,240-im.height))
    path=PORTRAITS/f'npc_{ident}.png'
    if path.exists():
        assert path.read_bytes()==encoded_png(out),f'Refusing to overwrite existing {path}'
    else:
        out.save(path)
    shutil.copy2(path,STAGE/path.name)
    out.resize((240,480),Image.Resampling.NEAREST).save(STAGE/f'npc_{ident}_2x.png')
    assert out.getchannel('A').getbbox()[3]==240
    return {'file':str(path.relative_to(ROOT)),'size':[120,240],'alpha_values':[0,255],'sha256':sha(path)}

def encoded_png(im):
    import io
    b=io.BytesIO();im.save(b,format='PNG');return b.getvalue()

def build():
    BATCH.mkdir(exist_ok=True);STAGE.mkdir(exist_ok=True);PORTRAITS.mkdir(exist_ok=True)
    (BATCH/'previews').mkdir(exist_ok=True)
    records=[];checks={};portraits=[];assembled={}
    for ident in ['dobermann','kaltsit']:
        walk=cells(WORK/'raw'/f'{ident}_walk.png',4)
        idle_path=WORK/'raw'/f'{ident}_idle.png'
        if ident=='kaltsit':
            # This generation has seven painted rows and an unused bottom band.
            # Trim only that empty band before segmentation, so the helper's
            # expected row boundaries cannot split E/SE and attach a stray coat.
            raw_im=Image.open(idle_path).convert('RGBA')
            alpha=np.array(raw_im.getchannel('A'))
            bb=Image.fromarray(np.where(alpha>=128,255,0).astype('uint8')).getbbox()
            idle_path=WORK/'kaltsit_idle_trimmed_for_assembly.png'
            raw_im.crop((0,0,raw_im.width,bb[3]+1)).save(idle_path)
        idle_raw=cells(idle_path,2,7 if ident=='kaltsit' else 8)
        idle=[row[0] for row in idle_raw]
        if ident=='kaltsit':
            # Inspected source has S SW W NW N E SE. All three rear directions
            # are replaced with dedicated rear art, so missing NE is not mirrored.
            idle=[idle[i] for i in [0,1,2,3,4,4,5,6]]
        rear=cells(WORK/'raw'/f'{ident}_rear.png',5,3 if ident=='kaltsit' else 2)
        destinations=[3,4,5] if ident=='kaltsit' else [3,5]
        # Preserve uniform scale within each original source atlas, matching the
        # established CR assembly pipeline, with a common 224 px figure envelope.
        def scale_group(group):
            h=max(im.height for im in group)
            return [fit(im,224/h) for im in group]
        walk=scale_group([im for row in walk for im in row])
        walk=[walk[r*4:r*4+4] for r in range(8)]
        idle=scale_group(idle)
        rear_flat=scale_group([im for row in rear for im in row])
        for patchrow,dest in enumerate(destinations):
            walk[dest]=rear_flat[patchrow*5:patchrow*5+4]
            idle[dest]=rear_flat[patchrow*5+4]
        idle=[[im,breathe(im)] for im in idle]
        assembled[ident]={'walk':walk,'idle':idle}
        cc=[]
        for kind,rows,cols in [('walk',walk,4),('idle',idle,2)]:
            out=Image.new('RGBA',(cols*256,2048))
            for r,row in enumerate(rows):
                for c,im in enumerate(row):
                    bbox=im.getbbox()
                    assert bbox and bbox[0]>=8 and bbox[1]>=8 and bbox[2]<=248 and bbox[3]==240,(ident,kind,r,c,bbox)
                    assert abs((bbox[0]+bbox[2])/2-128)<=1
                    out.paste(im,(256*c,256*r))
                    cc.append({'kind':kind,'row':DIRS[r],'col':c,'bbox':bbox})
                if kind=='idle':
                    assert np.array_equal(np.array(row[0])[192:],np.array(row[1])[192:])
                    # Head and shoulders translate 8px before tapering at the hip.
                    assert np.array_equal(np.array(row[0])[0:152],np.array(row[1])[8:160])
            fn=f'{ident}_{kind}_source.png';out.save(BATCH/fn)
            records.append({'id':ident,'kind':kind,'file':fn,'cols':cols,'rows':8,'cell':256})
        checks[ident]={'cells':cc,'breath_knee_y':192,'head_shoulders_shift_y':8,'lower_legs_identical':True,
            'walk_unique_frames':[len({hashlib.sha256(im.tobytes()).hexdigest() for im in row}) for row in walk]}
        assert all(n==4 for n in checks[ident]['walk_unique_frames'])
        portraits.append(portrait(ident))
    (BATCH/'manifest.json').write_text(json.dumps({'sheets':records},indent=2),encoding='utf-8')
    preview=Image.new('RGBA',(64,32))
    directions=Image.new('RGB',(512,8*160),(44,49,59));draw=ImageDraw.Draw(directions)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
    for i,ident in enumerate(assembled):
        for r in range(8):
            sprite=preview32(assembled[ident]['idle'][r][0]);large=sprite.resize((128,128),Image.Resampling.NEAREST)
            directions.paste(large,(i*256+65,r*160+26),large)
            draw.text((i*256+8,r*160+4),ident+' '+DIRS[r],font=font,fill='white')
            if r==0:preview.paste(sprite,(i*32,0))
    preview.save(BATCH/'preview_32.png');directions.save(BATCH/'previews/directions_32_enlarged.png')
    contact=Image.new('RGB',(1000,780),(44,49,59));draw=ImageDraw.Draw(contact)
    for i,ident in enumerate(assembled):
        x=500*i;draw.text((x+16,10),ident.upper(),font=font,fill='white')
        av=Image.open(STORY/'refs/prts'/f'{ident}_avatar.png').convert('RGBA');av.thumbnail((180,180))
        contact.paste(av,(x+300,55),av)
        p=Image.open(STAGE/f'npc_{ident}_2x.png');contact.paste(p,(x+30,55),p)
        draw.text((x+18,548),'120 x 240 portrait at 2x',font=font,fill='white')
        small=preview.crop((i*32,0,i*32+32,32));contact.paste(small,(x+300,300),small)
        large=small.resize((192,192),Image.Resampling.NEAREST);contact.paste(large,(x+285,370),large)
        draw.text((x+275,580),'32 px idle / 6x',font=font,fill='white')
    contact.save(STAGE/'identity_prts_comparison.png')
    # Animation preview samples every direction in a separate labelled row.
    frames=[]
    for col in range(4):
        canvas=Image.new('RGB',(500,8*100),(44,49,59));d=ImageDraw.Draw(canvas)
        for i,ident in enumerate(assembled):
            for row in range(8):
                s=preview32(assembled[ident]['walk'][row][col]).resize((96,96),Image.Resampling.NEAREST)
                canvas.paste(s,(i*250+70,row*100),s);d.text((i*250+8,row*100+40),DIRS[row],font=font,fill='white')
        frames.append(canvas)
    frames[0].save(BATCH/'previews/walk_preview.gif',save_all=True,append_images=frames[1:],duration=190,loop=0)
    provenance={'generator':'built-in image_gen','prompt_file':str((WORK/'prompts.json').relative_to(ROOT)),
        'sources':[{'file':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in (WORK/'raw').glob('*.png')],
        'assembly':'Component extraction and uniform proportional fitting from generated art, dedicated rear row replacements, established CR deterministic 8px breath warp. Portraits proportionally BOX downsampled from approved paintings; alpha threshold 128. No palette quantization.',
        'directions':DIRS,'stage1_approval':'User continued after painting review.',
        'runtime_bake':'Not run; source manifest is discoverable by prepare_crew_atlas.py.'}
    (BATCH/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
    report={'static_status':'PASS','portraits':portraits,'sheets':records,'checks':checks,
        'visual_review':'Author inspection of 8 facings and 32px comparison; independent identity acceptance pending.',
        'not_verified':['Godot import','in-game UI display','in-game walk playback','full-game regression','independent blind identity match']}
    (STAGE/'qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    shutil.copy2(STAGE/'qa_report.json',BATCH/'qa_report.json')
    shutil.copy2(ROOT/'art/characters/story/ST1_brief_v2.md',STAGE/'brief_snapshot.md')
    print('PASS: 2 portraits; 4 sheets; 96 cells; 16 exact knee-locked breath pairs; 64 unique walk cells')
    print(ROOT)

if __name__=='__main__':
    build()
