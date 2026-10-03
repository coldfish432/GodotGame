# 敌人攻击素材生成与烘焙

2026-09-30，使用内置 imagegen，以 `enemies_v1.png` 为角色外观参考。
生成原图：`enemy_attacks_source.png`；运行图集：`enemy_attacks_64.png`。
7 行依次为暴徒、弩手、源石虫、拳刃武士、弩手组长、冰原战士、冰原猎人。
5 列依次为待机、起手、蓄力、出手、收招；64×64 单元格，透明 RGBA。

`../prepare_enemy_atlas.py` 从真实透明行间隔切图，同一敌人的所有姿势共用缩放，
预乘 alpha 后 BOX 降采样。站立人形 27 texel，源石虫 19 texel；脚底 y=51，
以髋部/脚底对齐身体中线。猎人的长枪跨过生成图的格间隙，使用明确分界与连通
区域过滤，避免把下一格的衣角带入当前帧。原始生成图保留不变。

远程敌人直接使用图上画好的弩和枪。曾经有一张擦掉枪管的 `enemy_attacks_aimed_64.png`，
由引擎另画一根随瞄准方向旋转的像素武器；这根悬浮武器看起来像蓄力条，
2026-09-30 按用户要求删除，该图集随之移除。

复现：`python art/prepare_enemy_atlas.py`（依赖 Pillow、numpy）。
逐帧边界记录：`enemy_attacks_alignment.json`。

## 原始生成提示词

Use case: identity-preserve. Asset type: production transparent pixel sprite animation atlas for a Godot game. Reference image: D:/CSYE 7370/downfall-godot/art/field/enemies_v1.png, use ONLY the seven ordinary enemy identities described below. Produce ONE clean transparent sprite sheet arranged in EXACTLY 5 COLUMNS x 7 ROWS, all equal cells, generous empty gutters, no labels, no ground shadows, no effect arcs or background. Each row depicts the SAME character facing RIGHT in side/three-quarter side view, at SAME BODY SCALE and same foot baseline across all 5 cells. Columns are idle, startup, exaggerated held windup, strike, recovery. Distinct redrawn poses, not translated duplicates. Crisp large pixel clusters that survive baking to about 27 pixels tall. Weapons must be clearly outside the silhouette. Humanoid heads same size in all poses; only posture changes.
Row 1 reference top-left: dark gray hood, white mask, red armband, rough cleaver. Idle; raise over shoulder; lean BACK with cleaver raised far ABOVE HEAD; cleave DOWN and FORWARD to the right; lower cleaver.
Row 2 reference top-middle: tan hood white mask yellow accents compact crossbow. Idle low crossbow; raise; crouch forward and shoulder crossbow extended horizontally RIGHT at least one quarter body width beyond silhouette; release bolt with recoil; reload.
Row 3 reference top-right: squat black spiky armored slug with orange glowing underbelly. Idle; flatten; squash very low with bright underbelly; elongate forwards in a LEAP to the right; land. Creature stays squat, about 2/3 humanoid height, same head/body mass.
Row 4 reference middle-left: black capped masked warrior red scarf gray armor fist blade. Idle; turn shoulder back; lean far BACK with fist blade drawn behind waist, free hand pointing right; long low forward THRUST with fist blade fully extended right; withdraw blade.
Row 5 reference middle-middle: gray hood masked olive armored crossbow leader. Idle; raise; crouch and shoulder a visibly WIDER triple crossbow horizontal to right; discharge with recoil; reload.
Row 6 reference bottom-left: white fur hood mask red scarf heavy axe. Idle; lift; lean back with BOTH HANDS raising axe very HIGH above head; drive heavy axe forward DOWN to right at ground; pull axe out.
Row 7 reference bottom-middle: white broad-brim hat mask winter cloak scoped rifle. Idle low rifle; raise rifle to shoulder; crouch and sight along LONG horizontal rifle pointing RIGHT, barrel protrudes by 1/3 body width; firing recoil rifle still horizontal right; work bolt.
Transparent RGBA background. All 35 separate full sprites, no cropped weapons. Side-view only, NO back views. Keep exact reference clothing color/identity and chunky pixel-art style. Recommended canvas 1536x2048 or larger with exact grid. Do NOT draw muzzle glows, ground indicators, text or borders.
