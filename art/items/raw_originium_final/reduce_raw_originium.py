from PIL import Image, ImageFilter
import numpy as np
from collections import Counter, deque
src = Image.open("../raw_originium_reference_liked.webp").convert('RGBA')
a = np.array(src).astype(int)
H, W = a.shape[:2]
# background: flood fill near-white from the borders
white = (a[:,:,0] > 235) & (a[:,:,1] > 235) & (a[:,:,2] > 235)
bg = np.zeros((H, W), bool)
q = deque([(0,0),(0,W-1),(H-1,0),(H-1,W-1)])
for y,x in list(q): bg[y,x] = True
while q:
    y, x = q.popleft()
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
        ny, nx = y+dy, x+dx
        if 0 <= ny < H and 0 <= nx < W and not bg[ny,nx] and white[ny,nx]:
            bg[ny,nx] = True; q.append((ny,nx))
a[bg, 3] = 0
ys, xs = np.where(~bg)
crop = a[ys.min():ys.max()+1, xs.min():xs.max()+1]
Image.fromarray(crop.astype('uint8')).save('crop.png')
print('crop', crop.shape)
PAL = ['#0b0c0d','#2a2d33','#4a5058','#7d868e','#b4bec4','#eef3f5','#4a2a1d','#6e1616','#a82a22','#b85a12','#ee8a24','#ffb35a','#ffe0a8','#5a4d3a','#857555']
PAL = np.array([[int(h[i:i+2],16) for i in (1,3,5)] for h in PAL])
def quant(rgb):
    d = ((rgb[...,None,:]-PAL[None,None,:,:])**2).sum(-1)
    return PAL[d.argmin(-1)]
def fit(img_arr, tw, th):
    h, w = img_arr.shape[:2]
    s = min(tw / w, th / h)
    return max(1, round(w*s)), max(1, round(h*s))
TW, TH = 30, 70  # inside 32x72, 1 px outline margin
c = crop
# Method B: area average then quantize
im = Image.fromarray(c.astype('uint8'))
w, h = fit(c, TW, TH)
B = np.array(im.resize((w, h), Image.BOX)).astype(int)
def finish(arr, name):
    rgb = quant(arr[...,:3]); al = arr[...,3] > 110
    out = np.zeros((72, 32, 4), 'uint8')
    oy, ox = (72-arr.shape[0])//2, (32-arr.shape[1])//2
    out[oy:oy+arr.shape[0], ox:ox+arr.shape[1], :3] = rgb
    out[oy:oy+arr.shape[0], ox:ox+arr.shape[1], 3] = al*255
    # exterior outline
    m = out[...,3] > 0
    ring = np.zeros_like(m)
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
        ring |= np.roll(np.roll(m, dy, 0), dx, 1)
    ring &= ~m
    out[ring] = [11,12,13,255]
    Image.fromarray(out).save(name)
    return out
finish(B, 'B_box.png')
# Method C: quantize at high res, smooth by mode filter, then majority downsample
small = np.array(im.resize((w*6, h*6), Image.LANCZOS)).astype(int)
qrgb = quant(small[...,:3]); qal = small[...,3] > 110
qimg = Image.fromarray(np.dstack([qrgb, qal*255]).astype('uint8'))
qimg = qimg.filter(ImageFilter.ModeFilter(5))
qa = np.array(qimg).astype(int)
C = np.zeros((h, w, 4), int)
for y in range(h):
    for x in range(w):
        blk = qa[y*6:(y+1)*6, x*6:(x+1)*6].reshape(-1,4)
        if (blk[:,3] > 0).sum() < 18: continue
        cols = Counter(tuple(p[:3]) for p in blk if p[3] > 0)
        # keep glow / highlight if notable inside block (protect small bright details)
        top = cols.most_common(1)[0][0]
        for special in [(255,179,90),(238,138,36),(238,243,245)]:
            if cols.get(special,0) >= 8: top = special; break
        C[y,x,:3] = top; C[y,x,3] = 255
finish(C, 'C_mode.png')
