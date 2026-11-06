from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,shutil,zipfile
R=Path(__file__).parent;B=R.parent;P=B.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
q=json.loads((R/'qa_report.json').read_text(encoding='utf-8'))
assert q['floor_darker_than_top'] and 8<=q['colors']<=12 and .2<=q['gray_ratio_to_v1']<=.45
assert q['seam_x_mean']<=q['internal_x_p95'] and q['seam_y_mean']<=q['internal_y_p95']
base={Path(k).as_posix():v for k,v in json.loads((R/'baseline.json').read_text()).items()};snowpath='art/kit/textures/painted/snow_floor.png'
assert sha(P/snowpath)==base[snowpath]
for source,name in [(B/'sources/snow_floor.png','source_v1.png'),(B/'terrain_qa.json','terrain_qa_v1.json'),(B/'terrain_generation.json','terrain_generation_v1.json')]:
 target=R/'before'/name
 if not target.exists():shutil.copy2(source,target)
for source,dest in [(R/'snow_floor.png',P/snowpath),(R/'snow_floor_tile_3x3.png',P/'art/kit/textures/painted/snow_floor_tile_3x3.png'),(R/'snow_floor.png',B/'terrain/snow_floor.png'),(R/'snow_floor_tile_3x3.png',B/'previews/snow_floor_tile_3x3.png'),(R/'source.png',B/'sources/snow_floor.png')]:shutil.copy2(source,dest)
assert all(sha(P/path)==digest for path,digest in base.items() if path!=snowpath)
assert sha(P/snowpath)==q['sha256']
q['delivery']={'target':snowpath,'hash_match':True,'other_five_terrain_and_two_icons_unchanged':True}
q['visual_review']='Before/after and standard 3x3 reviewed; cleaner snow with sparse exposed gray, no obvious border seams observed.'
(R/'qa_report.json').write_text(json.dumps(q,ensure_ascii=False,indent=2),encoding='utf-8')
main=json.loads((B/'terrain_qa.json').read_text(encoding='utf-8'));keys=['colors','luma_mean','seam_x_mean','seam_y_mean','internal_x_p95','internal_y_p95','sha256','source_sha256']
for row in main['checks']:
 if row['id']=='snow_floor':row.update({k:q[k] for k in keys});row['revision']=2;row['gray_coverage']=q['gray_coverage_after']
main['snow_floor_revision']=q;main['tiling_visual_review']['result']='All six 3x3 previews reviewed; snow_floor v2 re-reviewed after gray reduction.'
(B/'terrain_qa.json').write_text(json.dumps(main,ensure_ascii=False,indent=2),encoding='utf-8')
gen=json.loads((B/'terrain_generation.json').read_text(encoding='utf-8'));new=json.loads((R/'generation.json').read_text(encoding='utf-8-sig'));old=gen['snow_floor'];new['initial_source_path']=old['initial_source_path'];new['original_prompt']=old['prompt'];gen['snow_floor']=new
(B/'terrain_generation.json').write_text(json.dumps(gen,ensure_ascii=False,indent=2),encoding='utf-8')
manifest=json.loads((B/'delivery.json').read_text(encoding='utf-8'))
for row in manifest['assets']:
 if row['path']==snowpath:row['sha256']=q['sha256'];row['revision']=2
manifest['revision']='snow_floor v2 gray reduction only';(B/'delivery.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
plan=json.loads((B/'terrain_plan.json').read_text(encoding='utf-8-sig'));font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
sheet=Image.new('RGB',(900,640),'#202832');d=ImageDraw.Draw(sheet)
for k,row in enumerate(plan):
 x,y=k%3*300,k//3*320;sheet.paste(Image.open(B/'terrain'/(row['id']+'.png')),(x+22,y+12));d.text((x+12,y+278),row['code']+' '+row['id'],font=font,fill='white')
sheet.save(B/'previews/terrain_contact_sheet.png')
note=f'''# 萨米路面 snow_floor v2\n\n仅修改 snow_floor.png 及其3×3预览，已更新到 art/kit/textures/painted/。其他5张地形和2个材料图标哈希保持不变。\n\n灰斑面积由 {q['gray_coverage_before']:.1%} 降到 {q['gray_coverage_after']:.1%}，约为原图 {q['gray_ratio_to_v1']:.0%}，减少约 {1-q['gray_ratio_to_v1']:.0%}。雪面更连续，保留9色冷蓝调色板和256×256硬像素规格。路面平均明度 {q['luma_mean']}，低于岩台厚雪 {q['snow_top_luma']}。\n\n内置 image_gen 局部修订；确定性近邻尺寸/指定色映射及半幅环绕相位恢复用于交付整理。灰斑、明度和3×3平铺已重新检查，边界跳变未高于内部95百分位；未运行Godot。\n\nbefore/ 保留原版，draft1–3 保留过程中间稿；generation.json 保存完整提示词，qa_report.json 保存指标。before_after.png 与 tiling_before_after.png 为对比图。\n\n原 missing_art_v1_8_assets.zip 保留为历史版本；最新整批包为 ../missing_art_v2_8_assets.zip。\n'''
(R/'README.md').write_text(note,encoding='utf-8')
readme=(B/'README.md').read_text(encoding='utf-8-sig')
if '## snow_floor v2 修订' not in readme:readme+='\n\n## snow_floor v2 修订\n\n萨米路面灰斑由13.0%降为5.2%，保留冷蓝明度层次；其他资产不变。修订详情与前后对比见 snow_floor_v2/README.md。最新全批交付包为 missing_art_v2_8_assets.zip，v1 ZIP保留作历史记录。\n'
(B/'README.md').write_text(readme,encoding='utf-8')
with zipfile.ZipFile(R/'snow_floor_v2.zip','w',zipfile.ZIP_DEFLATED) as z:
 for name in ['snow_floor.png','snow_floor_tile_3x3.png']:z.write(R/name,'art/kit/textures/painted/'+name)
 for name in ['README.md','generation.json','qa_report.json','before_after.png','tiling_before_after.png']:z.write(R/name,'review/'+name)
with zipfile.ZipFile(B/'missing_art_v2_8_assets.zip','w',zipfile.ZIP_DEFLATED) as z:
 for row in manifest['assets']:z.write(P/row['path'],row['path'])
 for row in plan:
  f=P/'art/kit/textures/painted'/(row['id']+'_tile_3x3.png');z.write(f,'art/kit/textures/painted/'+f.name)
 for name in ['README.md','icons_generation.json','terrain_generation.json','terrain_plan.json','icons_qa.json','terrain_qa.json','delivery.json']:z.write(B/name,'review/'+name)
 for f in sorted((B/'previews').glob('*.png')):z.write(f,'review/previews/'+f.name)
 for name in ['README.md','generation.json','qa_report.json','before_after.png','tiling_before_after.png']:z.write(R/name,'review/snow_floor_v2/'+name)
for f in [R/'snow_floor_v2.zip',B/'missing_art_v2_8_assets.zip']:
 with zipfile.ZipFile(f) as z:assert z.testzip() is None
print('snow_floor v2 delivered. Gray coverage 12.99% -> 5.18%; remaining 7 assets unchanged. ZIP CRC checks PASS.')
