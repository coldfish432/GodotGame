"""Persist item-specific generation prompts from the authoritative briefs."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COMMON = '''Use case: stylized-concept. Asset type: finished painted pixel-art inventory icon for an extraction ARPG. Generate ONE isolated item only on genuinely transparent background, no backdrop, no shadow, no lettering, no watermark, no glow halo. Draw as carefully clustered native pixel art enlarged exactly 8 times: each logical pixel is a crisp uniform 8x8 square. Top-left light, 1 logical pixel near-black #0b0c0d outline, 4-5 tones per material, at most 24 colors, deliberate clusters rather than dithering. Composition must respect the logical canvas. Weapons: side view, horizontal, handle left and tip right, no more than 12 degrees uphill; almost fill width except short razor and compact knuckles. Armour: centered front view. Trinkets: centered. Retain generous highlights occupying at least 15 percent of the object, bright edges and raised surfaces; no antialiasing. The established game style has chunky steel highlights, warm leather grips and very readable silhouettes. No photorealism, no floating decoration, no additional objects.'''

for batch, brief in [('E13','E13_siracusa_weapons_brief_v1.md'), ('E6','E6_brief_v1.md')]:
    root = ROOT / f'batch_{batch}_v1'
    (root / 'sources').mkdir(parents=True, exist_ok=True)
    text = (ROOT / brief).read_text(encoding='utf-8')
    rows = [line for line in text.splitlines() if line.startswith('| ') and (' | blade ' in line or ' | fist ' in line or ' | heavy ' in line or ' | **polearm** ' in line or ' | **32×32 trinket** ' in line or line.startswith('| rhodes_'))]
    entries = []
    for line in rows:
        fields = [c.strip() for c in line.strip('|').split('|')]
        item_id, name = fields[:2]
        if batch == 'E13':
            form = fields[2].replace('**','').split(' · ')[0]
            form = 'trinket' if 'trinket' in form else form
            size = [32,32] if form == 'trinket' else [72,32]
            refs = [fields[3]]
            extra = '1940s Italian old-town civilian or gangster equipment, dressed and maintained, not military. Palette: steel #2a2d33 #4a5058 #7d868e #b4bec4 #eef3f5; leather browns; charcoal #1a1b1e #2e3036 #4a4d55 #767a84; wood #3a2618 #5e3f26 #8a6440; brass #5e4418 #9a7428 #d0a848 #f0d888; ivory #8e8470 #c8bea6 #ece4d0. Small accents only. No light emission. Generic wolf imagery only, never an actual emblem.'
        else:
            size = [int(n) for n in fields[2].split('×')]
            form = 'armour' if size == [72,72] else ('blade' if size == [72,32] else 'trinket')
            refs = ['../E6_brief_v1.md', '../../rhodes/batch_L0_logo_v1/rhodes_logo_S_gray_v1.png']
            extra = 'Clean industrial Rhodes Island ship gear. STRICT palette only: #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc #a9b2b3 #d4dadb #eef2f2 #385878 #5888a8 #78b8e8 #6e2f14 #b8531f #e0782a #0f3a40 #2a8a92 #5fd0d8 #b8f4f6 #6b5a1e #b89a2a #f4d73c. Blue/orange/cyan/yellow accents together below 10 percent and each color family below 6 percent of opaque area. Neutral body surfaces. Leave the requested logo position as a small neutral patch; the exact 9x9 two-tone triangle/tower mark will be restored during native pixel cleanup. Do not invent lettering. No red cross.'
        prompt = COMMON + '\n' + extra + f'\nLogical canvas {size[0]}x{size[1]}; enlarged output {size[0]*8}x{size[1]*8} or same aspect ratio with transparent margins.\nSubject: ' + name + '.\nMandatory silhouette/details: ' + fields[-1]
        e = dict(id=item_id, name=name, form=form, native_size=size, kind='exclusive' if item_id=='saluzzo_crest' else 'base', prototype_refs=refs, has_emit=item_id in ['rhodes_dual_blades','rhodes_protective_vest','rhodes_beacon'], prompt=prompt)
        entries.append(e)
    (root/'generation_specs.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
    (root/'generation_prompts.md').write_text('# '+batch+' generation prompts\n\nBuilt-in imagegen; one call per asset. Authoritative brief: '+brief+'\n\n'+'\n\n'.join('## '+e['id']+'\n\n'+e['prompt'] for e in entries),encoding='utf-8')
    print(batch, len(entries))
