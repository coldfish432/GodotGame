"""Package three review batches, verify archive CRC and all file hashes.
Run beside batch_E15b_v1, batch_E15c_v1, batch_E15d_v1.
"""
from pathlib import Path
import json,hashlib,zipfile,shutil,subprocess,sys
from PIL import Image,ImageDraw,ImageFont
W=Path(__file__).resolve().parent
ROOT=next(p for p in W.parents if (p/'project.godot').exists())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def archive(path,files):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p,name in sorted(files,key=lambda x:x[1]):z.write(p,name)
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        for p,name in files:assert hashlib.sha256(z.read(name)).hexdigest()==sha(p)
    return dict(file=path.name,files=len(files),bytes=path.stat().st_size,sha256=sha(path),crc='PASS',content_hashes='PASS')
def main():
    summary=dict(total_icons=44,total_emission_masks=1,runtime_verified=False,art_accepted=False,batches=[],archives=[])
    allfiles=[];previews=[]
    for batch,region,count in [('E15b','龙门',20),('E15c','萨米',19),('E15d','罗德岛',5)]:
        b=W/('batch_'+batch+'_v1')
        # All paths in each package remain batch-relative.
        shutil.copy2(W/'build_validate.py',b/'build_validate.py')
        edits=[json.loads(p.read_text(encoding='utf-8')) for p in sorted((b/'sources').glob('*_edit_generation.json'))]
        (b/'edits.json').write_text(json.dumps(edits,ensure_ascii=False,indent=2),encoding='utf-8')
        subprocess.run([sys.executable,str(b/'build_validate.py')],check=True)
        q=json.loads((b/'qa_report.json').read_text(encoding='utf-8'));m=json.loads((b/'manifest.json').read_text(encoding='utf-8'))
        assert q['pass'] and len(m['items'])==count
        minimum=min(x['bright_fraction'] for x in q['items']);maximum=max(x['isolated_fraction'] for x in q['items'] if x['cloth_noise_enforced']) if any(x['cloth_noise_enforced'] for x in q['items']) else None
        record=dict(batch=batch,region=region,icons=count,emission_masks=len(m['emission_files']),minimum_bright_fraction=minimum,maximum_cloth_isolated_fraction=maximum,static_checks='PASS',initial_source_paintings=count,edited_source_paintings=len(edits))
        summary['batches'].append(record)
        readme=f'''# {batch} v1 — {region}装备图标

2026-10-21。依据 E15_slot_split_brief_v1.md 及 E15a_accepted_go_E15bcd.md，E15a 风格已获接受后继续绘制。

## 交付

{count}件图标：头/手/腿/脚72×72，戒指32×32，文件名为简报id。另有{len(m['emission_files'])}张发光蒙版。

- contact_sheet.png：所有新图在三种背景上展示，每件装备3倍、戒指5倍；每格自上至下 #2c2e30、#142538、#352710。
- silhouette_check.png：head、hands、legs、feet、ring 分行；E15c 额外展示现有冬牙角盔作对照，明确标注沿用原图，它不是新绘制件数的一部分。
- overview.png：紧凑预览；native_check.png：原生尺寸检查。
- sources/：{count}份逐件初稿与{len(edits)}份定向修改图，保留原始透明源PNG；每次绘制的实际完整提示词和外部源路径记录在 *_generation.json / *_edit_generation.json。
- generations.json / edits.json：初始要求、实际提示词和修改记录；refs/：本地既有装备与已接受E15a风格参考；manifest.json：交付清单、源图和最终PNG的SHA256。

## 绘制与处理

使用内置 imagegen 分件绘制与定向修正，没有脚本绘制物件。龙门战术装备对照 inspector_armor，绸裤对照 city_x13；萨米骨片与羽冠分别对照 bone_lamellar、snow_x15；罗德岛对照 rhodes_field_uniform。没有修改任何已有胸甲、项链或冬牙角盔，也没有替换 E15a。

build_validate.py 只执行透明阈值128、裁边、最近邻缩放、无抖动限色、1px #0b0c0d 内轮廓规范化、预览装配和静态检查。限色前将原有亮面与暗面分组分别求色，防止源图已画出的亮面被平均为中间色；不人工提亮像素。布料主调5色，细红边另2色；探险橙布料采用4色灰部件+4色橙部件；其他主调20色，冰晶另保留3色蓝；加轮廓后≤24色。冰晶发光蒙版只取最终图中明亮蓝色晶体像素，保持原始RGB和位置，不包含银环和外部光晕。

## 检查结果

静态检查 PASS。最低亮部比例 {minimum:.1%}；布料最大孤立像素比例 {maximum:.1%}。尺寸、RGBA、二值透明、≤24色、亮部≥15%、布料孤立像素≤10%、轮廓、留边、源图与最终图校验均通过。完整逐件数值见 qa_report.json。

亮部定义为数值 (.2126R+.7152G+.0722B)/255≥.6，不做sRGB线性化。孤立像素指排除轮廓后，8邻域无其他同RGB像素；布料执行上限，其他材质仅记录。

运行 python build_validate.py 可重建并检查本批；依赖 Pillow、numpy，中文预览使用 Windows 微软雅黑。图像来源中的外部绝对路径为生成记录，实际重建使用包内 sources/，不依赖外部生成目录。

这些检查仅证明素材文件规范和预览，不等同于 Godot 导入、背包实机显示或最终美术验收。本轮没有修改 runtime 目录。
'''
        if batch=='E15c':readme+='\n雪地发光文件为 snow_ring_3_emit.png，16个局部冰晶亮像素。冬牙角盔仅在 refs/snow_x14.png 留存相同原图作对照。\n'
        (b/'README.md').write_text(readme,encoding='utf-8')
        files=[(p,p.relative_to(W).as_posix()) for p in b.rglob('*') if p.is_file() and '__pycache__' not in p.parts and not p.name.endswith('.import')]
        ar=archive(W/(batch+'_v1_review.zip'),files);summary['archives'].append(ar);allfiles.extend(files);previews.append(Image.open(b/'overview.png').convert('RGB'))
    # Check pre-existing PNGs and accepted E15a byte-for-byte against the read-only baseline.
    baseline=json.loads((W/'protected_hashes.json').read_text(encoding='utf-8'));changes=[p for p,h in baseline.items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h]
    summary['protected_assets']=dict(checked=len(baseline),changed=changes,pass_=not changes)
    assert not changes,changes
    out=Image.new('RGB',(sum(i.width for i in previews)+32,max(i.height for i in previews)),'#191b1e');x=0
    for im in previews:out.paste(im,(x,0));x+=im.width+16
    out.save(W/'E15bcd_overview.png')
    # Small alignment preview for the sole new emission mask.
    b=W/'batch_E15c_v1';ep=Image.new('RGB',(480,220),'#142538');d=ImageDraw.Draw(ep);d.text((8,8),'snow_ring_3 base / emit',fill='white')
    for k,name in enumerate(['snow_ring_3.png','snow_ring_3_emit.png']):
        im=Image.open(b/name).convert('RGBA').resize((160,160),Image.Resampling.NEAREST);ep.paste(im,(40+k*230,36),im)
    ep.save(W/'emission_check.png')
    summary['static_pass']=all(x['static_checks']=='PASS' for x in summary['batches']) and not changes
    (W/'delivery_report.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    extras=['E15bcd_overview.png','emission_check.png','delivery_report.json','package_e15bcd.py','build_validate.py','protected_hashes.json','brief_snapshot.md','acceptance_snapshot.md']
    total=archive(W/'E15bcd_v1_review.zip',allfiles+[(W/p,p) for p in extras])
    (W/'archive_verification.json').write_text(json.dumps(total,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False));print('COMBINED ARCHIVE',total)
if __name__=='__main__':main()
