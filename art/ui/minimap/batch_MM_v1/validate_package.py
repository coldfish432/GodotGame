from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,zipfile
p=Path(r'D:\策划测试题\MM_minimap_v1');rec=json.loads((p/'generation_records.json').read_text(encoding='utf8'));report=[];outline=(16,20,24)
for a in rec['assets']:
 n=a['id'];f=p/'art/ui/minimap'/f'mm_{n}.png';im=Image.open(f);ar=np.array(im);mask=ar[:,:,3]>0;colored=mask&np.any(ar[:,:,:3]!=outline,axis=2)
 # Every coloured pixel has an opaque 8-neighbourhood; all outer pixels are outline.
 boundary=np.zeros((16,16),bool)
 for y,x in zip(*np.where(mask)):
  if x==0 or y==0 or x==15 or y==15 or not mask[max(0,y-1):y+2,max(0,x-1):x+2].all():boundary[y,x]=True
 boundary_ok=all(tuple(v)==outline for v in ar[:,:,:3][boundary]);colors={tuple(v) for v in ar[:,:,:3][colored]};box=im.getbbox();expected=tuple(bytes.fromhex(a['color'][1:]));assert im.size==(16,16) and set(np.unique(ar[:,:,3]))=={0,255};assert boundary_ok and len(colors)<=3 and expected in colors
 if n=='box':assert box[2]-box[0]<=10 and box[3]-box[1]<=10 and all(r==g==b for r,g,b in colors)
 report.append({'id':n,'file':f'art/ui/minimap/mm_{n}.png','size':[16,16],'alpha_values':[0,255],'outline':'#101418','outer_boundary_all_outline':boundary_ok,'interior_colors':['#%02x%02x%02x'%c for c in sorted(colors)],'exact_base_present':True,'bbox':box,'opaque_pixels':int(mask.sum()),'colored_pixels':int(colored.sum()),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
assert len(report)==20 and len({r['sha256'] for r in report})==20
ranking=sorted(report,key=lambda r:r['opaque_pixels'],reverse=True);assert [r['id'] for r in ranking[:2]]==['boss','relic_cache']
manifest={'batch':'MM_v1','native_size':16,'map_size':32,'filter':'nearest','icons':report};(p/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
(p/'qa_report.json').write_text(json.dumps({'count':20,'all_static_checks':'passed','silhouette_coverage_ranking':[{'id':r['id'],'pixels':r['opaque_pixels']} for r in ranking],'runtime_tested':False,'recognition_user_acceptance':'pending; unique files and coverage ranking do not prove human recognition or attention priority','assets':report},indent=2),encoding='utf8')
(p/'README.md').write_text('''# MM 小地图图标 v1

20 个 16×16 RGBA PNG，位于 art/ui/minimap/mm_<id>.png。用于小地图 1×，大地图 2× nearest。未绘制玩家箭头。

沿用简报色值，透明度只有 0/255，统一 #101418 一像素深色外轮廓，内部最多三色。箱子为中性灰，可在代码中染色，外框不超过 10×10。
头目占最大轮廓；蓝色战斗缴获为第二大轮廓，并用顶部亮标强调。外轮廓像素覆盖排序见 qa_report.json；显眼程度和辨识度仍需要实际地图审阅。

preview_1x_2x_on_ground.png：全部图标 1× 与 2× 同屏预览，背景取自用户当前小地图截图内部地面并平铺，不是运行时截图。
preview_8x.png：nearest 8× 放大像素检查图。

内置 image_gen 每图单独绘制源稿，raw/ 保留原图，generation_records.json 保留全部最终提示词。bake_icons.py 仅作确定性缩小、颜色归一、二值透明和一像素轮廓烘焙及拼版，不以程序绘制替代源图。
manifest.json 保存颜色、尺寸、哈希；qa_report.json 记录 20 图完整性、像素边界、色数、透明度和显眼轮廓排序检查。静态检查与 ZIP CRC 通过；未验证 Godot 导入、地图图标接入或游戏内显示，未改绘制代码。
''',encoding='utf8')
archive=p.parent/'MM_minimap_icons_v1_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for f in sorted(p.rglob('*')):
  if f.is_file():z.write(f,f.relative_to(p))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({'icons':20,'checks':'passed','crc':'passed','ranking':[(r['id'],r['opaque_pixels']) for r in ranking[:3]],'archive':str(archive)},ensure_ascii=False))
