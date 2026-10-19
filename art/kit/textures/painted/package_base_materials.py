"""Document and package the generated base material delivery; preserve other batches."""
from pathlib import Path
import hashlib, json, shutil, zipfile
P=Path(__file__).resolve().parent
W=P/'base_materials_v1'
PROJECT=P.parents[3]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
specs=json.loads((W/'generation_specs.json').read_text(encoding='utf-8'))
for s in specs:
    if s['neutral_tinted']:
        s['color_range']=[1,6]
        s['color_count_note']='Dedicated six-grey tint ramp overrides the generic 8-12 minimum; actual subset documented in manifest.'
(W/'generation_specs.json').write_text(json.dumps(specs,ensure_ascii=False,indent=2),encoding='utf-8')
prep=P/'prepare_base_materials.py'
prep.write_text(prep.read_text(encoding='utf-8').replace('color_range=[6,6] if neutral','color_range=[1,6] if neutral'),encoding='utf-8')
for src,dst in [('build_base_materials.py','process.py'),('validate_base_materials.py','validate.py'),('install_base_materials.py','install.py')]:
    shutil.copy2(P/src,W/dst)
shutil.copy2(PROJECT/'tests/capture_base_materials.gd',W/'capture_base_materials.gd')
history=[]
for s in specs:
    item={'id':s['id'],'source':f"sources/{s['name']}_raw.png",'tool':'image_gen.imagegen','initial_prompt':s['prompt']}
    revision=W/'sources'/f"{s['name']}_revision_prompt.txt"
    if revision.exists():
        item.update(first_source=f"sources/{s['name']}_first.png",revision_prompt=revision.read_text(encoding='utf-8'))
    history.append(item)
(W/'generation_history.json').write_text(json.dumps(history,ensure_ascii=False,indent=2),encoding='utf-8')
prompts='# Base material generation prompts\n\n'+ '\n\n'.join(f"## {h['id']}\n\n{h['initial_prompt']}"+(f"\n\n### Targeted source revision\n\n{h['revision_prompt']}" if 'revision_prompt' in h else '') for h in history)
(W/'generation_prompts.md').write_text(prompts,encoding='utf-8')
origin=PROJECT/'art/_to_sol/R_base_materials.zip'
provenance={'brief':'source_brief.md','reference_archive':str(origin),'reference_archive_sha256':digest(origin),'method':'Image-generated painted sources; deterministic resizing, local exposure cleanup, palette mapping and repeat-edge correction. No procedural replacement artwork.','source_hashes':{p.relative_to(W).as_posix():digest(p) for folder in ['sources','refs'] for p in sorted((W/folder).rglob('*')) if p.is_file()}}
(W/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
readme='''# 基地材质 R v1 — 2026-10-18

交付 R1–R10 共 10 张 RGB 原尺寸材质、10 张精确 3×3 平铺预览、总览、源图、参考、生成记录、处理脚本和验证报告。正式 PNG 位于本目录的上一级，文件名与现有加载路径一致。manifest.json 为本批次清单；仓库上一级的汇总 manifest 已合并，既有条目保留。

美术源图由 image_gen 生成；R2 钢材与 R3 医疗地胶定向清理面内斑驳。脚本仅用于尺寸、曝光整理、指定色板映射、边缘衔接、预览及 QA。R2/R7/R8 使用专属六阶中性灰色板的 4–5 个颜色；专属中性灰限制优先于通用 8–12 色最低值。其余材质实际使用 8–10 色。此取舍已写入验证报告。

R1/R2/R3/R10 为 256×256；R4 为 128×64；R5/R7/R8 为 128×128；R6 为 256×128；R9 为 512×256。R9 只需水平循环，其他材质双轴循环。材质是基础色，不含引擎光照；屏幕仅含几何图形，无文字。

运行 python process.py 可从保留源图重建；python validate.py 验证暂存；在本仓库同一目录结构中运行 python install.py 会安装并合并清单，再检查正式文件。脚本依赖 Python、Pillow、NumPy（以实际 import 为准）。

validation.json 记录尺寸、RGB/色板、循环边缘、精确平铺、哈希、亮度关系和 381 个已有 PNG/GLB 的保留检查。engine_evidence 中的导入日志、房间截图与 floor_routes.json 仅用于材质导入和三种直接地板路径检查。未对 84 个基地模型执行 Blender 重导出，也未宣称这些模型材质已全部在游戏中替换；需要按已接好的 Blender 材质路径重导出。不是完整游戏回归或用户最终美术验收。
'''
(W/'README.md').write_text(readme,encoding='utf-8')
shutil.copy2(W/'README.md',P/'base_materials_README.md')
archive=PROJECT/'art/_to_sol/R_base_materials_v1_2026-10-18.zip'
files=[P/s['file'] for s in specs]+[P/(s['name']+'_tile_3x3.png') for s in specs]+[P/'base_materials_contact.png',P/'base_materials_README.md']
files+=sorted(p for p in W.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc' and p.name!='process_id.txt')
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as z:
    for p in files: z.write(p,p.relative_to(P).as_posix())
with zipfile.ZipFile(archive) as z:
    bad=z.testzip()
    assert bad is None,bad
    count=len(z.namelist())
receipt={'archive':str(archive),'sha256':digest(archive),'files':count,'crc':'PASS','bytes':archive.stat().st_size}
(W/'package_receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(receipt,ensure_ascii=False))
