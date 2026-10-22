"""Assemble original painted sources, then use the supplied B1 baker unchanged.
No character geometry, faces, poses or VFX are drawn in this script.
"""
from pathlib import Path
import hashlib,json,sys,subprocess,shutil
import numpy as np
from PIL import Image,ImageFilter

ROOT=Path(__file__).resolve().parent
FIELD=ROOT.parent
SRC=ROOT/'source_paintings'
DATA=json.loads((ROOT/'generation_records.json').read_text(encoding='utf-8'))
IDS=list(dict.fromkeys(j['id'] for j in DATA['jobs']))
BOUNDS={
 'patriot_action':[0,156,306,443,582,721,856,1003,1140,1330],
 'patriot_walk':[0,184,368,557,727,906,1081,1254],
 'rat_king_action':[0,164,315,489,650,823,997,1254],
 'eikthyrnir_action':[0,147,280,438,588,730,870,1012,1330],
 'zaro_action':[0,152,272,443,612,736,855,1033,1330],
 'crownslayer_action':[0,190,369,514,677,857,992,1174],
 'skullshatterer_action':[0,190,377,548,722,903,1086],
 'hollow_snowpriest_action':[0,180,359,520,690,856,1009,1174],
 'father_agnir_action':[0,191,373,548,730,908,1086],
 'zaro_sw_correction':[0,365,659,952,1254],
 'zaro_walk':[0,236,454,670,887],
 'hollow_snowpriest_walk':[0,239,453,664,887],
 'crownslayer_walk':[0,228,451,665,887],
 'skullshatterer_walk':[0,223,443,661,887],
 'father_agnir_walk':[0,226,445,657,887],
 'rat_king_walk':[0,227,446,658,887],
}
SIDE=256
GREY=(49,53,59,255)
MANIFEST=[]
ASSEMBLY_ISSUES=[]
CLEANUP=[]

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def trim(im):
    im=im.convert('RGBA')
    box=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    if not box:raise ValueError('empty painted cell')
    return im.crop(box)

def clean_foreign_fragments(im,key):
    """Keep the painted connected figure, plus Agnir's intentional detached halo.
    Generated row/column spacing can put a neighbor's cropped tail/hem in a
    cell. This removes detached alpha debris; no character pixels are drawn.
    Run-length union-find avoids large Python per-pixel flood fills.
    """
    pixels=np.array(im)
    alpha=pixels[:,:,3]>128
    parent=[];runs=[];previous=[]
    def find(i):
        while parent[i]!=i:
            parent[i]=parent[parent[i]];i=parent[i]
        return i
    for y,row in enumerate(alpha):
        changes=np.diff(np.pad(row.astype(np.int8),1))
        starts=np.where(changes==1)[0];ends=np.where(changes==-1)[0]
        current=[]
        for x0,x1 in zip(starts,ends):
            label=len(parent);parent.append(label)
            for p0,p1,pl in previous:
                if p1>x0 and p0<x1:parent[find(label)]=find(pl)
            record=(int(y),int(x0),int(x1),label)
            runs.append(record);current.append((x0,x1,label))
        previous=current
    areas={};boxes={}
    for y,x0,x1,label in runs:
        root=find(label);areas[root]=areas.get(root,0)+x1-x0
        b=boxes.setdefault(root,[x0,y,x1,y+1])
        b[0]=min(b[0],x0);b[1]=min(b[1],y);b[2]=max(b[2],x1);b[3]=max(b[3],y+1)
    main=max(areas,key=areas.get);keep={main}
    if key.startswith('father_agnir'):
        body=boxes[main]
        for root,b in boxes.items():
            if root==main or b[3]>body[1]+8 or b[2]<body[0] or b[0]>body[2]:continue
            region=pixels[b[1]:b[3],b[0]:b[2]]
            opaque=region[:,:,3]>128
            gold=(region[:,:,0]>95)&(region[:,:,1]>75)&(region[:,:,0]>region[:,:,2]*1.15)&opaque
            if gold.sum()>10:keep.add(root)
    mask=np.zeros_like(alpha)
    for y,x0,x1,label in runs:
        if find(label) in keep:mask[y,x0:x1]=True
    removed=int((alpha&~mask).sum())
    if removed:CLEANUP.append({'source':key,'detached_pixels_removed':removed,'preserved_detached_halo':len(keep)>1})
    mask=np.array(Image.fromarray(mask.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(3)))>0
    pixels[~mask]=0
    return Image.fromarray(pixels)

def grid(key,rows,cols=8):
    im=Image.open(SRC/f'{key}_generated.png').convert('RGBA')
    bounds=BOUNDS.get(key,[round(i*im.height/rows) for i in range(rows+1)])
    result=[]
    for r in range(len(bounds)-1):
        row=[]
        for c in range(cols):
            # Cropping/repacking sources only. No horizontal mirroring or warping.
            row.append(trim(clean_foreign_fragments(im.crop((round(c*im.width/cols),bounds[r],round((c+1)*im.width/cols),bounds[r+1])),key)))
        result.append(row)
    return result

def strip(key,height):
    im=Image.open(SRC/f'{key}_generated.png').convert('RGBA')
    row=[trim(clean_foreign_fragments(im.crop((round(c*im.width/8),0,round((c+1)*im.width/8),im.height)),key)) for c in range(8)]
    # One reviewed source-DPI calibration for the entire independently painted row.
    factor=height/row[0].height
    return [(im,factor,key) for im in row]

def pack(entries,id,kind):
    out=Image.new('RGBA',(SIDE*8,SIDE*len(entries)))
    records=[]
    for r,row in enumerate(entries):
        for c,(fig,factor,origin) in enumerate(row):
            im=fig.resize((max(1,round(fig.width*factor)),max(1,round(fig.height*factor))),Image.Resampling.LANCZOS)
            x=(SIDE-im.width)//2
            y=248-im.height
            if x<8 or y<8 or x+im.width>SIDE-8:
                ASSEMBLY_ISSUES.append({'id':id,'board':kind,'row':r+1,'col':c+1,'issue':'source cell margin under8px','size':im.size,'origin':origin})
            assert x>=0 and y>=0 and x+im.width<=SIDE,(id,kind,r,c,im.size)
            out.alpha_composite(im,(c*SIDE+x,r*SIDE+y))
            records.append({'row':r+1,'col':c+1,'source':origin,'uniform_source_scale':factor,'source_crop_size':fig.size,'assembled_size':im.size})
    out.save(ROOT/f'{id}_{kind}.png')
    MANIFEST.append({'id':id,'kind':kind,'rows':len(entries),'cols':8,'cell_size':SIDE,'file':f'{id}_{kind}.png','sha256':sha(ROOT/f'{id}_{kind}.png'),'assembly':records})

def assemble():
    for id in IDS:
        jobs=[j for j in DATA['jobs'] if j['id']==id]
        action_job=next(j for j in jobs if j['kind']=='action')
        walk_job=next(j for j in jobs if j['kind']=='walk')
        raw_a=grid(id+'_action',action_job['rows'])
        raw_w=grid(id+'_walk',walk_job['rows'])
        idle_height=144 if id=='zaro' else 180
        af=idle_height/raw_a[0][0].height
        wf=(idle_height*48/38 if id=='zaro' else idle_height)/raw_w[0][0].height
        a=[[(im,af,id+'_action') for im in row] for row in raw_a]
        w=[[(im,wf,id+'_walk') for im in row] for row in raw_w]
        if id=='patriot':w.insert(3,strip('patriot_walk_first_pass_b',180))
        if id=='rat_king':a.insert(3,strip('rat_king_strike',170))
        if id=='eikthyrnir':a.insert(5,strip('eikthyrnir_sweep',175))
        if id=='zaro':a.insert(6,strip('zaro_down',95))
        assert len(a)==action_job['rows'] and len(w)==walk_job['rows'],id
        sw_job=next(j for j in DATA['sw'] if j['id']==id)
        sw_key=id+'_sw_final' if id in ['patriot','eikthyrnir','crownslayer','skullshatterer','father_agnir'] else id+'_sw_correction'
        sw_rows=grid(sw_key,sw_job['rows'],4)
        sw=[im for row in sw_rows for im in row]
        sf=idle_height/sw[0].height
        # Replace only the SW column with independently painted direction repairs.
        for i in range(len(a)):
            if id=='zaro' and i in [0,1]:continue
            a[i][1]=(sw[i],sf,sw_key)
        for i in range(len(w)):w[i][1]=(sw[len(a)+i],sf,sw_key)
        if id=='eikthyrnir':a[8]=strip('eikthyrnir_roar_compact',184)
        if id=='zaro':
            for row,key,h in [(2,'charge',172),(3,'strike',170),(7,'pounce',170),(8,'howl',185)]:a[row]=strip('zaro_strike_final' if key=='strike' else 'zaro_'+key+'_compact',h)
        # Exact approved IDLE painting, not a freshly reinterpreted first cell.
        version=2 if id in ['patriot','rat_king','eikthyrnir'] else 1
        ref=FIELD/f'batch_B1_v{version}/source_paintings'/f'{"zaro_lying" if id=="zaro" else id}_generated.png'
        approved=trim(Image.open(ref))
        a[0][0]=(approved,idle_height/approved.height,str(ref.relative_to(FIELD)))
        if id=='zaro':
            standing_ref=FIELD/'batch_B1_v1/source_paintings/zaro_standing_generated.png'
            standing=trim(Image.open(standing_ref))
            w[0][0]=(standing,(idle_height*48/38)/standing.height,str(standing_ref.relative_to(FIELD)))
        pack(a,id,'action')
        pack(w,id,'walk')
    (ROOT/'assembly_manifest.json').write_text(json.dumps({'boards':MANIFEST,'margin_findings':ASSEMBLY_ISSUES,'alpha_debris_cleanup':CLEANUP,'method':'painted sources; uniform scaling per source board or supplementary painted row; no per-cell auto-fit, mirroring or procedural pose construction'},indent=2),encoding='utf-8')

def bake():
    commands=[]
    for j in DATA['jobs']:
        path=ROOT/f'{j["id"]}_{j["kind"]}.png'
        cmd=[sys.executable,str(FIELD/'bake_n2.py'),str(path),j['id'],str(j['rows'])]
        if j['kind']=='walk':cmd+=['--scale-from',str(ROOT/f'{j["id"]}_action.png')]
        r=subprocess.run(cmd,capture_output=True,text=True,check=True)
        commands.append({'command':cmd,'output':r.stdout.strip()})
    (ROOT/'bake_commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')

def previews():
    all_s=Image.new('RGBA',(9*384,8*384),GREY)
    for n,id in enumerate(IDS):
        count=next(j['rows'] for j in DATA['jobs'] if j['id']==id and j['kind']=='action')
        a=Image.open(ROOT/f'{id}_action_64.png').convert('RGBA')
        w=Image.open(ROOT/f'{id}_walk_64.png').convert('RGBA')
        s=Image.new('RGBA',(64*max(count,w.height//64),128),GREY)
        for r in range(count):
            im=a.crop((0,r*64,64,(r+1)*64))
            s.alpha_composite(im,(r*64,0))
            all_s.alpha_composite(im.resize((384,384),Image.Resampling.NEAREST),(r*384,n*384))
        for r in range(w.height//64):s.alpha_composite(w.crop((0,r*64,64,(r+1)*64)),(r*64,64))
        s.resize((s.width*6,s.height*6),Image.Resampling.NEAREST).save(ROOT/f'{id}_s_rows_x6.png')
        for stance in range(2 if id=='patriot' else 1):
            frames=[]
            for r in range(4):
                f=Image.new('RGBA',(512,256),GREY)
                for c in range(8):
                    im=w.crop((c*64,(stance*4+r)*64,(c+1)*64,(stance*4+r+1)*64)).resize((128,128),Image.Resampling.NEAREST)
                    f.alpha_composite(im,((c%4)*128,(c//4)*128))
                frames.append(f.convert('RGB'))
            frames[0].save(ROOT/f'{id}_walk_stance{stance+1}_preview.gif',save_all=True,append_images=frames[1:],duration=180,loop=0)
    all_s.save(ROOT/'all_action_s_rows_x6.png')

if __name__=='__main__':
    assemble()
    bake()
    previews()
    print('Assembled and baked16 boards; visual acceptance and pre-clip audit required.')
