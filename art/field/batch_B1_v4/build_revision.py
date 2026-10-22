"""Replace only9 approved revision rows; preserve every other RGBA cell."""
from pathlib import Path
import sys,json,hashlib,subprocess
import numpy as np
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parent
BASE=ROOT/'baseline'
SRC=ROOT/'source_paintings'
JOBS=json.loads((ROOT/'generation_jobs.json').read_text(encoding='utf-8'))
CHANGES={'patriot_action':[8,9],'patriot_walk':[5,6,7,8],'eikthyrnir_action':[9],'zaro_action':[7,8]}
GREY=(49,53,59,255)

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def extract(key,cols=4,rows=2,selected_slots=None):
    """Assign complete foreground components to slots, retaining props crossing
    invisible source cell lines. One global canvas-DPI scale, never per-cell fit.
    """
    path=SRC/(key+'_generated.png')
    im=Image.open(path).convert('RGBA');pixels=np.array(im);a=pixels[:,:,3]>128
    parent=[];runs=[];previous=[]
    def find(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for y,row in enumerate(a):
        diff=np.diff(np.pad(row.astype(np.int8),1));now=[]
        for x0,x1 in zip(np.where(diff==1)[0],np.where(diff==-1)[0]):
            label=len(parent);parent.append(label)
            for p0,p1,pl in previous:
                if p1>x0 and p0<x1:parent[find(label)]=find(pl)
            runs.append((y,int(x0),int(x1),label));now.append((x0,x1,label))
        previous=now
    areas={};boxes={}
    for y,x0,x1,l in runs:
        r=find(l);areas[r]=areas.get(r,0)+x1-x0;b=boxes.setdefault(r,[x0,y,x1,y+1])
        b[0]=min(b[0],x0);b[1]=min(b[1],y);b[2]=max(b[2],x1);b[3]=max(b[3],y+1)
    slots={}
    for r,b in boxes.items():
        if areas[r]<25:continue
        c=min(cols-1,int((b[0]+b[2])/2*cols/im.width));y=min(rows-1,int((b[1]+b[3])/2*rows/im.height))
        slots[r]=y*cols+c
    result=[];records=[]
    factor=cols*256/im.width
    assert abs(im.width/im.height-cols/rows)<.025,(key,im.size)
    for slot in range(cols*rows):
        if selected_slots is not None and slot not in selected_slots:
            result.append(None);records.append(None);continue
        mask=np.zeros_like(a)
        for y,x0,x1,l in runs:
            if slots.get(find(l))==slot:mask[y,x0:x1]=True
        assert mask.sum()>1000,(key,slot)
        mask=np.array(Image.fromarray(mask.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(3)))>0
        data=pixels.copy();data[~mask]=0;fig=Image.fromarray(data)
        box=fig.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox();fig=fig.crop(box)
        size=(round(fig.width*factor),round(fig.height*factor))
        fig=fig.resize(size,Image.Resampling.LANCZOS)
        assert fig.width<=256 and fig.height<=248,(key,slot,fig.size)
        cell=Image.new('RGBA',(256,256));cell.alpha_composite(fig,((256-fig.width)//2,248-fig.height))
        result.append(cell)
        records.append({'slot':slot,'source_bbox':box,'source_size':im.size,'uniform_canvas_dpi_scale':factor,'assembled_figure_size':size,'source_sha256':sha(path)})
    return result,records

def build():
    rows={};sources={}
    for j in JOBS:
        key=j['key']
        selected='kneel_pole_final' if key=='patriot_action_r09' else 'eikthyrnir_roar_final' if key=='eikthyrnir_action_r09' else key
        slots=[0,1,3,4,5,7] if key=='zaro_action_r08' else [0,3,4,5,7] if key=='zaro_action_r07' else None
        cells,records=extract(selected,selected_slots=slots)
        if key=='zaro_action_r07':
            fixed,details=extract('zaro_down_profiles_final',selected_slots=[1,2,6])
            for c in [1,2,6]:cells[c]=fixed[c];records[c]=details[c]
        if key=='zaro_action_r08':
            fixed,details=extract('zaro_pounce_profiles',selected_slots=[2,6])
            for c in [2,6]:cells[c]=fixed[c];records[c]=details[c]
        rows[key]=cells;sources[key]={'selected':selected,'registration':records}
    changed=0;preserved=0;commands=[]
    for key,numbers in CHANGES.items():
        original=Image.open(BASE/(key+'.png')).convert('RGBA');out=original.copy()
        for row in numbers:
            for c,cell in enumerate(rows[f'{key}_r{row:02d}']):out.paste(cell,(c*256,(row-1)*256))
        for r in range(original.height//256):
            for c in range(8):
                box=(c*256,r*256,(c+1)*256,(r+1)*256)
                same=out.crop(box).tobytes()==original.crop(box).tobytes()
                if r+1 in numbers:assert not same;changed+=1
                else:assert same;preserved+=1
        out.save(ROOT/(key+'.png'))
        id,kind=key.rsplit('_',1)
        cmd=[sys.executable,str(ROOT/'pipeline/bake_n2.py'),str(ROOT/(key+'.png')),id,str(out.height//256)]
        if kind=='walk':cmd+=['--scale-from',str(ROOT/(id+'_action.png'))]
        result=subprocess.run(cmd,capture_output=True,text=True)
        if result.returncode:raise RuntimeError(result.stderr)
        commands.append({'command':cmd,'output':result.stdout})
    (ROOT/'assembly_manifest.json').write_text(json.dumps({'changed_cells':changed,'preserved_source_cells_in_four_boards':preserved,'rows':sources,'commands':commands,'normalization':'uniform DPI from whole reference grid; no per-cell resizing, no geometry painting, no auto-fit to native64'},indent=2),encoding='utf-8')
    compare=Image.new('RGBA',(4*64,9*64),GREY)
    changed_rows=Image.new('RGBA',(8*64,9*64),GREY)
    order=[]
    for i,j in enumerate(JOBS):
        key=j['id']+'_'+j['kind'];r=j['row']-1
        old=Image.open(BASE/(key+'_64.png')).convert('RGBA');new=Image.open(ROOT/(key+'_64.png')).convert('RGBA')
        for col,c in enumerate([0,0,2,2]):
            source=old if col%2==0 else new
            compare.alpha_composite(source.crop((c*64,r*64,(c+1)*64,(r+1)*64)),(col*64,i*64))
        changed_rows.alpha_composite(new.crop((0,r*64,512,(r+1)*64)),(0,i*64))
        order.append({'preview_row':i+1,'key':key,'board_row':r+1})
    compare.resize((1536,3456),Image.Resampling.NEAREST).save(ROOT/'changed_rows_before_after_S_W_x6.png')
    changed_rows.resize((3072,3456),Image.Resampling.NEAREST).save(ROOT/'changed_rows_all_directions_x6.png')
    (ROOT/'preview_order.json').write_text(json.dumps(order,indent=2),encoding='utf-8')
    # Individual figure before/after sheets use the same four comparison columns.
    for id in ['patriot','eikthyrnir','zaro']:
        indices=[i for i,j in enumerate(JOBS) if j['id']==id]
        panel=Image.new('RGBA',(256,len(indices)*64),GREY)
        for n,i in enumerate(indices):panel.alpha_composite(compare.crop((0,i*64,256,(i+1)*64)),(0,n*64))
        panel.resize((1536,len(indices)*384),Image.Resampling.NEAREST).save(ROOT/(id+'_before_after_S_W_x6.png'))
    # Only the repaired second stance is animated; first stance is unchanged.
    walk=Image.open(ROOT/'patriot_walk_64.png').convert('RGBA');frames=[]
    for r in range(4,8):
        frame=Image.new('RGBA',(512,256),GREY)
        for c in range(8):frame.alpha_composite(walk.crop((c*64,r*64,(c+1)*64,(r+1)*64)).resize((128,128),Image.Resampling.NEAREST),((c%4)*128,(c//4)*128))
        frames.append(frame.convert('RGB'))
    frames[0].save(ROOT/'patriot_second_stance_walk.gif',save_all=True,append_images=frames[1:],duration=180,loop=0)
    print(json.dumps({'changed_cells':changed,'source_cells_preserved':preserved,'boards':4}))

if __name__=='__main__':build()
