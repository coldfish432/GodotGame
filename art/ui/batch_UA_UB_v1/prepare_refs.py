from pathlib import Path
import shutil, json, hashlib

B=Path(__file__).resolve().parent
ROOT=B.parents[2]
ART=ROOT/'art'
refs={
 'op_lappland':('characters/idle/refs/lappland_prts_art.png','拉普兰德','#f5c000','https://prts.wiki/w/拉普兰德'),
 'op_amiya':('characters/idle/refs/amiya_guard_prts_art.png','阿米娅（近卫）','#3fd2f2','https://prts.wiki/w/阿米娅(近卫)'),
 'npc_closure':('portraits/refs/prts/closure_art.png','可露希尔','#ff5fa2','https://prts.wiki/w/可露希尔'),
 'npc_cannot':('portraits/refs/prts/cannot_is_npc.png','坎诺特','#b49b70','https://prts.wiki/w/剧情角色一览'),
 'npc_squad':('portraits/refs/prts/reserve/melee_art.png','罗德岛预备干员','#3fd2f2','https://prts.wiki/w/预备干员-近战'),
 'npc_medic':('portraits/refs/prts/reserve/logistics_art.png','罗德岛医疗干员','#2fbfa6','https://prts.wiki/w/预备干员-后勤'),
}
for ident,cn,col in [('hellagur','赫拉格','#c9b27a'),('rosa','早露','#d8dde4'),('hoshiguma','星熊','#3ccf8e'),('lin','林','#c08cff'),('typhon','提丰','#b07cd8'),('santalla','寒檀','#8fc8ff'),('texas','德克萨斯','#e05050')]:
 refs['op_'+ident]=(f'characters/{ident}/refs_prts/{ident}_elite2_prts.png',cn,col,'https://prts.wiki/w/'+cn)
records=[]
existing_path=B/'reference_manifest.json'
regional_records=[r for r in json.loads(existing_path.read_text(encoding='utf-8')) if r['id'].startswith('npc_post_')] if existing_path.exists() else []
for ident,(src,name,col,url) in refs.items():
 target=B/'refs'/f'{ident}.png'
 shutil.copyfile(ART/src,target)
 records.append(dict(id=ident,name=name,representative_color=col,reference=target.relative_to(B).as_posix(),reference_page=url,reference_local_source='art/'+src,reference_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),reference_role='Costume and colors only; original standing redraw, no tracing.'))
shutil.copyfile(ART/'field/batch_B1_v2/source_paintings/patriot_generated.png',B/'refs/style_patriot.png')
(B/'reference_manifest.json').write_text(json.dumps(records+regional_records,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Prepared {len(records)} identity references and Patriot style reference')
