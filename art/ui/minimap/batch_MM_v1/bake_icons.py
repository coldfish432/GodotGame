from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import json,numpy as np,shutil,hashlib
p=Path(__file__).parent;rec=json.loads((p/'generation_records.json').read_text(encoding='utf8'));(p/'raw').mkdir(exist_ok=True);dest=p/'art/ui/minimap';dest.mkdir(parents=True,exist_ok=True)
outline=(16,20,24);items=[]
for a in rec['assets']:
 n=a['id'];src=p/'raw'/(n+'.png');shutil.copy2(a['source'],src);im=Image.open(src).convert('RGBA');arr=np.array(im);fill=(arr[:,:,3]>128)&(arr[:,:,:3].max(2)>65)
 ys,xs=np.where(fill);box=(xs.min(),ys.min(),xs.max()+1,ys.max()+1);im=im.crop(box)
 extent=14 if n=='boss' else (12 if n=='relic_cache' else (8 if n in ['box','elite'] else (9 if n=='handover' else 10)))
 scale=extent/max(im.size);size=(max(1,round(im.width*scale)),max(1,round(im.height*scale)));raw=np.array(im);fm=(raw[:,:,3]>128)&(raw[:,:,:3].max(2)>65);coverage=Image.fromarray((fm*255).astype('uint8')).resize(size,Image.Resampling.BOX);im=im.resize(size,Image.Resampling.BOX);ar=np.array(im);mask=np.array(coverage)>({'post':20,'relic_cache':135,'relic_cache_sealed':155,'boss':135,'trader':150,'patrol':145,'elite':145,'handover':125}.get(n,90))
 b=np.array(tuple(bytes.fromhex(a['color'][1:])),dtype=float);highlight=np.round(b+(255-b)*(.78 if n=='relic_cache' else .33));shadow=np.round(b*.77);palette=np.stack([b,highlight,shadow]);colors=ar[:,:,:3].astype(float)
 # Relative source luminance selects tonal roles; the original brief base dominates.
 lum=colors@np.array([.2126,.7152,.0722]);vals=lum[mask];qlo,qhi=np.quantile(vals,[.18,.85]);idx=np.zeros(mask.shape,dtype=int);idx[(lum<qlo)&mask]=2;idx[(lum>qhi)&mask]=1
 out=Image.new('RGBA',(16,16));x=(16-size[0])//2;y=(16-size[1])//2
 m=Image.new('L',(16,16));m.paste(Image.fromarray((mask*255).astype('uint8')),(x,y));border=m.filter(ImageFilter.MaxFilter(3));out.paste((*outline,255),(0,0),border)
 for yy,xx in zip(*np.where(mask)):
  out.putpixel((x+int(xx),y+int(yy)),tuple(palette[idx[yy,xx]].astype(int))+(255,))
 out.save(dest/f'mm_{n}.png');items.append((n,out,a['color']))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',13)
# Native ground texture from supplied current-map screenshot, without its existing markers.
ground=Image.open(p/'input/refs/minimap_now.png').convert('RGB');tile=ground.crop((1042,124,1110,190))
def backdrop(w,h):
 im=Image.new('RGB',(w,h))
 for y in range(0,h,tile.height):
  for x in range(0,w,tile.width):im.paste(tile,(x,y))
 return im
sheet=backdrop(960,420);d=ImageDraw.Draw(sheet)
for i,(n,im,c) in enumerate(items):
 x=i%5*192;y=i//5*105;d.text((x+8,y+8),n,font=font,fill='#d2dae0');sheet.paste(im,(x+18,y+48),im);large=im.resize((32,32),Image.Resampling.NEAREST);sheet.paste(large,(x+67,y+40),large);d.text((x+115,y+48),'1x / 2x',font=font,fill='#8a969e')
sheet.save(p/'preview_1x_2x_on_ground.png')
zoom=backdrop(960,800);d=ImageDraw.Draw(zoom)
for i,(n,im,c) in enumerate(items):
 x=i%5*192;y=i//5*200;large=im.resize((128,128),Image.Resampling.NEAREST);zoom.paste(large,(x+32,y+40),large);d.text((x+8,y+12),n,font=font,fill='#d2dae0')
zoom.save(p/'preview_8x.png');print(dest)
