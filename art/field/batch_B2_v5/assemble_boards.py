from pathlib import Path
from PIL import Image, ImageDraw
import json
OUT=Path(__file__).resolve().parent
CROPS=OUT/'reference_crops'
CELL=1024
DIRECTIONS=['S','SW','W','NW','N','NE','E','SE']
SCALES={'action_left':2.10,'action_right':2.10,'action_SW_repair':800/697,'action_NE_E_flinch':1.0,'walk_left':2.50,'walk_right':2.50,'walk_SW_W_repair':1.60,'action_W_flinch':0.60}
def select(board,row,col):
 group=board+('_left' if col<4 else '_right');r=row;c=col%4
 if board=='action' and col==1:group='action_SW_repair';r=0;c=row
 if board=='action' and row==2 and col in (5,6):group='action_NE_E_flinch';r=0;c=col-5
 if board=='action' and row==2 and col==2:group='action_W_flinch';r=0;c=0
 if board=='walk' and col in (1,2):group='walk_SW_W_repair';r=row;c=col-1
 return group,r,c
records=[]
for board,rows in [('action',3),('walk',4)]:
 sheet=Image.new('RGBA',(8*CELL,rows*CELL))
 for row in range(rows):
  for col in range(8):
   group,r,c=select(board,row,col);name=f'{group}_r{r}_c{c}.png'
   im=Image.open(CROPS/name).convert('RGBA');scale=SCALES[group]
   im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
   assert im.width<920 and im.height<920,(name,im.size)
   x=col*CELL+(CELL-im.width)//2;y=row*CELL+960-im.height
   sheet.alpha_composite(im,(x,y))
   records.append({'board':board,'row':row,'column':col,'direction':DIRECTIONS[col],'source_crop':name,'uniform_source_scale':scale,'destination_xy':[x,y],'painted_size':list(im.size)})
 sheet.save(OUT/f'civilian_{board}.png')
 sheet.resize((2048,rows*256),Image.Resampling.LANCZOS).save(OUT/f'civilian_{board}_preview.png')
# Required S-column sheet: actual painted cells, no native reduction.
preview=Image.new('RGBA',(7*384,440),(42,44,48,255));draw=ImageDraw.Draw(preview)
i=0
for board,labels in [('action',['IDLE','LOOK','FLINCH']),('walk',['CONTACT A','PASS A','CONTACT B','PASS B'])]:
 sheet=Image.open(OUT/f'civilian_{board}.png').convert('RGBA')
 for row,label in enumerate(labels):
  cell=sheet.crop((0,row*CELL,CELL,(row+1)*CELL)).resize((384,384),Image.Resampling.LANCZOS)
  preview.alpha_composite(cell,(i*384,24));draw.text((i*384+16,8),label,fill='white');i+=1
preview.save(OUT/'civilian_S_all_rows.png')
(OUT/'assembly_map.json').write_text(json.dumps({'cell_size':CELL,'directions':DIRECTIONS,'cells':records},indent=2),encoding='utf-8')
print('Assembled 56 painted cells; action8192x3072, walk8192x4096.')
