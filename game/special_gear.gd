class_name SpecialGear
extends RefCounted

## Special equipment (特殊装备): named gear whose fixed special affix deals
## damage of its own — the attack effects that used to be relics (用户
## 2026-10-03: relics change numbers and rules; attack effects belong to
## equipment). Each also rolls one ordinary affix. Being equipment, it follows
## every equipment rule: it takes pack cells, can be insured, carried
## home and kept. One per slot, so the three slots are a real choice.
##
## How it is obtained is still open (用户：具体归宿待定). For now it drops from
## ordinary loot rolls at DROP_CHANCE, region-weighted, so it can be played.

const DROP_CHANCE := 0.05
const DROP_CHANCE_PER_REWARD := 0.03
const REGION_WEIGHT := 3.0

const T := ItemModifier.Trigger
const GEAR := {
	"lord_blade": {"name": "领主宽刃", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.6, "region": "city",
		"triggers": [T.CLEAVE], "cost": [ItemModifier.Stat.ATTACK_SPEED_PCT, -0.10],
		"text": "一把为了同时面对很多人而打的刀。", "source": "宽刃（原锋刃构筑物）"},
	"twin_fang": {"name": "双生狼牙", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.2, "region": "snow",
		"triggers": [T.TWIN_WAVE], "cost": [],
		"text": "两柄刃，一道光分成三道。", "source": "双生剑气（原狼魂构筑物）"},
	"ember_fang": {"name": "余烬之牙", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.2, "region": "snow",
		"triggers": [T.EMBER], "cost": [],
		"text": "刃脊里封着一点不肯熄的火。", "source": "余烬剑气（原狼魂构筑物）"},
	"moon_edge": {"name": "月下刃", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.4, "region": "snow",
		"triggers": [T.MOON_WAVE], "cost": [],
		"text": "刀光够亮的时候，会自己飞出去。", "source": "月下双刃（原桥梁构筑物）"},
	"crystal_edge": {"name": "源石结晶刃", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.4, "region": "mine",
		"triggers": [T.ARTS_EDGE], "cost": [],
		"text": "刃上长出了不该长的东西。", "source": "源石结晶刃（原源石构筑物）"},
	"vein_core": {"name": "共振矿芯", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 2.0, "region": "mine",
		"triggers": [T.VEIN_BURST], "cost": [],
		"text": "握在手里会轻轻发颤，敌人倒下时颤得更厉害。", "source": "矿脉共振（原源石构筑物）"},
	"shadow_bracer": {"name": "残影护腕", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 2.0, "region": "city",
		"triggers": [T.AFTERIMAGE], "cost": [],
		"text": "动得够快，影子也会伤人。", "source": "残影步（原迅捷构筑物）"},
	"spike_plate": {"name": "尖刺重铠", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 2.6, "region": "mine",
		"triggers": [T.THORNS], "cost": [ItemModifier.Stat.MOVE_SPEED_PCT, -0.08],
		"text": "抱住它的人会后悔。", "source": "坚壁 4 共鸣的荆棘"},
	"bash_shield": {"name": "反击塔盾", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 2.6, "region": "city",
		"triggers": [T.SHIELD_BASH], "cost": [],
		"text": "挡下来的，原样还回去。", "source": "盾反（原坚壁构筑物）"},
	# --- 装备扩充策划案 §5–§6: enemy exclusives (Grim Dawn MI, "kind": "exclusive",
	# only `source_enemy` drops them) and regional set pieces ("kind": "set").
	# Fixed 稀有, the intrinsic stats, one fixed effect (GearEffects) or the set
	# mark, plus one random affix. `req`: the attribute the requirement asks.
	"mi_thug_0": {"name": "暴徒的改刃", "kind": "exclusive", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "mine", "source_enemy": "thug",
		"implicit": [[ItemModifier.Stat.CRIT_DMG, 0.1]], "fx": "kill_aspd_stack", "fx_text": "击杀时：4 秒内攻速 +12%，叠 3 层", "req": "tec", "form": "blade", "text": "每换一个主人，就多一道焊。"},
	"mi_crossbow_1": {"name": "绞盘护腕", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine", "source_enemy": "crossbow",
		"implicit": [[ItemModifier.Stat.ATTACK_SPEED_PCT, 0.05]], "fx": "evade_next_crit", "fx_text": "闪避时：下一次攻击必定暴击（冷却 3 秒）", "req": "agi", "text": "上弦的那只手，手腕先坏。"},
	"mi_slug_2": {"name": "蜕下的虫壳", "kind": "exclusive", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "mine", "source_enemy": "slug",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0]], "fx": "hurt_shards", "fx_text": "受击时：20% 向周围 2 米迸出碎屑，60% 法术攻击力", "req": "phy", "text": "虫子长大了，壳留在原地。"},
	"mi_armed_3": {"name": "不明罐装呼吸器", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine", "source_enemy": "armed",
		"implicit": [[ItemModifier.Stat.MAX_HP_PCT, 0.04]], "fx": "low_hp_def", "fx_text": "受击时：生命低于 35%，5 秒内防御 +50%（冷却 60 秒）", "req": "phy", "text": "罐子里装的是什么，标签已经说不清。"},
	"mi_armed_4": {"name": "震荡护符", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine", "source_enemy": "armed",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0]], "fx": "hurt_shockwave", "fx_text": "受击时：20% 震出半径 1.6 冲击波，60% 攻击力（冷却 3 秒）", "req": "phy", "text": "挨打的人学会了回声。"},
	"mi_caster_5": {"name": "裸晶护腕", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine", "source_enemy": "caster",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05]], "fx": "signature_spike", "fx_text": "招牌发动时：第一个命中的敌人脚下爆出晶刺，80% 法术攻击力", "req": "arts", "text": "它的上一个主人不需要法杖。"},
	"mi_shield_6": {"name": "盾面背板", "kind": "exclusive", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "mine", "source_enemy": "shield",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0]], "fx": "hurt_front_block", "fx_text": "受击时：正面伤害 20% 几率减免 60%", "req": "phy", "text": "原来是挡在前面的，现在背在身上。"},
	"mi_slug_volatile_7": {"name": "不稳定虫腹", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine", "source_enemy": "slug_volatile",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05]], "fx": "kill_explode", "fx_text": "击杀时：25% 让被击杀者 0.8 秒后爆炸，150% 法术攻击力", "req": "arts", "text": "它安静的时候最危险。"},
	"mi_picket_8": {"name": "纠察官的套索", "kind": "exclusive", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "mine", "source_enemy": "picket",
		"implicit": [[ItemModifier.Stat.MOVE_SPEED_PCT, 0.04]], "fx": "hit_execute_bonus", "fx_text": "命中时：对生命低于 30% 的敌人伤害 +30%", "req": "tec", "form": "blade", "text": "追到最后，就不用再追了。"},
	"mi_picket_9": {"name": "赏金账簿", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine", "source_enemy": "picket",
		"implicit": [[ItemModifier.Stat.CRIT_RATE, 0.03]], "fx": "kill_gold", "fx_text": "击杀时：精英额外掉 1 赤金；普通敌人 10% 额外掉 1 赤金", "req": "tec", "text": "每一页都是一个名字和一个价钱。"},
	"mi_brawler_10": {"name": "快拳绑带", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "city", "source_enemy": "brawler",
		"implicit": [[ItemModifier.Stat.ATTACK_SPEED_PCT, 0.05]], "fx": "hit_fourth", "fx_text": "命中时：连续命中同一目标第 4 下，追加 40% 攻击力打击", "req": "agi", "text": "第四拳，才是认真的。"},
	"mi_crossbow_leader_11": {"name": "组长臂章", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "city", "source_enemy": "crossbow_leader",
		"implicit": [[ItemModifier.Stat.CRIT_RATE, 0.03]], "fx": "signature_shards", "fx_text": "招牌发动时：前方扇形射出 3 枚碎片，各 25% 攻击力", "req": "tec", "text": "三支里总有一支，替他记着人。"},
	"mi_greytail_12": {"name": "灰尾屏障坠", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "city", "source_enemy": "greytail",
		"implicit": [[ItemModifier.Stat.RES_FLAT, 4.0]], "fx": "idle_barrier", "fx_text": "空闲 8 秒（未受伤）：获得 15% 生命上限的屏障；破碎时移速 +30% 3 秒", "req": "arts", "text": "碎掉的时候，人就该跑了。"},
	"mi_greytail_lord_13": {"name": "香主铁骨扇", "kind": "exclusive", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "city", "source_enemy": "greytail_lord",
		"implicit": [[ItemModifier.Stat.RES_FLAT, 4.0]], "fx": "kill_barrier", "fx_text": "击杀时：获得 10% 生命上限的屏障 5 秒（刷新不叠加）", "req": "agi", "form": "fist", "text": "扇面是纸，扇骨不是。"},
	"mi_thrower_14": {"name": "燃烧瓶挂包", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "city", "source_enemy": "thrower",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05]], "fx": "kill_fire", "fx_text": "击杀时：倒下处留 3 秒火区，每 0.5 秒 15% 法术攻击力", "req": "arts", "text": "瓶子都空了，包还是一股味。"},
	"mi_bully_15": {"name": "推土肩甲", "kind": "exclusive", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "city", "source_enemy": "bully",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0], [ItemModifier.Stat.MOVE_SPEED_PCT, -0.04]], "fx": "evade_ram", "fx_text": "闪避时：闪避变冲撞，路径上敌人受 60% 攻击力并被推开", "req": "phy", "heavy": true, "req_column": "heavy_armor", "text": "挡在前面的，只是还没被推开的。"},
	"mi_avenger_16": {"name": "换手刃", "kind": "exclusive", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "city", "source_enemy": "avenger",
		"implicit": [[ItemModifier.Stat.ATK_PCT, 0.04]], "fx": "hurt_half_rage", "fx_text": "受击时：生命 ≤50% 时攻击力 +30%、攻速 +15%，6 秒（冷却 12 秒）", "req": "tec", "form": "blade", "text": "换一只手，再来一次。"},
	"mi_breacher_17": {"name": "攻坚重锤", "kind": "exclusive", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "city", "source_enemy": "breacher",
		"implicit": [[ItemModifier.Stat.ATK_PCT, 0.04], [ItemModifier.Stat.MOVE_SPEED_PCT, -0.04]], "fx": "hit_third_stun", "fx_text": "命中时：每第 3 次命中眩晕 0.8 秒（精英 0.4 秒）", "req": "phy", "form": "heavy", "req_column": "heavy", "text": "第三下之前，没人会当回事。"},
	"mi_ice_warrior_18": {"name": "劈冰者", "kind": "exclusive", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "snow", "source_enemy": "ice_warrior",
		"implicit": [[ItemModifier.Stat.CRIT_DMG, 0.1]], "fx": "hit_fresh_bonus", "fx_text": "命中时：目标生命高于 80% 时伤害 +50%", "req": "phy", "form": "heavy", "req_column": "heavy", "text": "第一下最重。"},
	"mi_ice_warrior_19": {"name": "雪顶护肩", "kind": "exclusive", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "snow", "source_enemy": "ice_warrior",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0]], "fx": "hurt_def_stack", "fx_text": "受击时：3 秒内防御 +15%，叠 3 层", "req": "phy", "text": "越挨打，越硬。"},
	"mi_ice_hunter_20": {"name": "结绳猎记", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow", "source_enemy": "ice_hunter",
		"implicit": [[ItemModifier.Stat.CRIT_RATE, 0.03]], "fx": "hit_low_crit", "fx_text": "命中时：对生命低于 35% 的敌人暴击率 +25%", "req": "tec", "text": "每打一个结，就少一只。"},
	"mi_ice_hunter_21": {"name": "猎人的耐心", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow", "source_enemy": "ice_hunter",
		"implicit": [[ItemModifier.Stat.CRIT_DMG, 0.1]], "fx": "evade_next_crit_long", "fx_text": "闪避时：4 秒内下一次攻击必定暴击（冷却 6 秒）", "req": "tec", "text": "等它先动。"},
	"mi_taint_husk_22": {"name": "空壳战袍", "kind": "exclusive", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "snow", "source_enemy": "taint_husk",
		"implicit": [[ItemModifier.Stat.MAX_HP_PCT, 0.04]], "fx": "hurt_sprint", "fx_text": "受击时：2 秒内移速 +40%（冷却 5 秒）", "req": "agi", "text": "已经不疼了，只是想跑。"},
	"mi_distorted_caster_23": {"name": "置换指骨", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow", "source_enemy": "distorted_caster",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05]], "fx": "idle_strike", "fx_text": "空闲 5 秒（未攻击）：移速 +30%，之后第一次命中追加 80% 法术攻击力", "req": "arts", "text": "它记得怎么施法，不记得为什么。"},
	"mi_shattered_champion_24": {"name": "泯灭护颈", "kind": "exclusive", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "snow", "source_enemy": "shattered_champion",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0]], "fx": "hurt_last_stand", "fx_text": "受击时：每层首次低于 30% 生命，3 秒内受伤 −50%、移速 +30%", "req": "phy", "text": "到最后，连自己也可以舍掉。"},
	"mi_shattered_champion_25": {"name": "折角", "kind": "exclusive", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "snow", "source_enemy": "shattered_champion",
		"implicit": [[ItemModifier.Stat.ATTACK_SPEED_PCT, 0.05]], "fx": "kill_aspd_stack_big", "fx_text": "击杀时：5 秒内攻速 +20%，叠 3 层", "req": "agi", "form": "fist", "text": "断掉的那一半，还在别人身上。"},
	"mi_shell_vine_26": {"name": "壳中种子", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow", "source_enemy": "shell_vine",
		"implicit": [[ItemModifier.Stat.MAX_HP_PCT, 0.04]], "fx": "kill_extra_material", "fx_text": "击杀时：10% 让该敌人多掉一份材料", "req": "tec", "text": "它也在等你打开。"},
	"mi_rock_hornbeast_27": {"name": "冲阵蹄铁", "kind": "exclusive", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "snow", "source_enemy": "rock_hornbeast",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0]], "fx": "evade_ram", "fx_text": "闪避时：路径上的敌人受 60% 攻击力并被推开", "req": "phy", "text": "让开的不是它。"},
	"mi_fallen_snowpriest_28": {"name": "雪祀断冠", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow", "source_enemy": "fallen_snowpriest",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05]], "fx": "signature_chain", "fx_text": "招牌发动时：招牌命中后跳向 3.5 米内另一敌人，每跳 −15%，最多 2 跳", "req": "arts", "text": "它还在替部族挑选。"},
	"mi_fallen_snowpriest_29": {"name": "反馈赠之铃", "kind": "exclusive", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow", "source_enemy": "fallen_snowpriest",
		"implicit": [[ItemModifier.Stat.ATTACK_SPEED_PCT, 0.05]], "fx": "kill_haste", "fx_text": "击杀时：4 秒内移速 +25%、攻速 +15%", "req": "agi", "text": "不该给的，它都给了。"},
	"set_nameless_0": {"name": "无名者的砍刀", "kind": "set", "set_id": "nameless", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "mine",
		"implicit": [[ItemModifier.Stat.ATK_PCT, 0.04]], "req": "tec", "form": "blade", "text": "刀柄上刻过名字，又被刮掉了。"},
	"set_nameless_1": {"name": "无名者的外套", "kind": "set", "set_id": "nameless", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "mine",
		"implicit": [[ItemModifier.Stat.MAX_HP_PCT, 0.04]], "req": "phy", "text": "衣服是同一批，血不是。"},
	"set_nameless_2": {"name": "无名者的面具", "kind": "set", "set_id": "nameless", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine",
		"implicit": [[ItemModifier.Stat.ATTACK_SPEED_PCT, 0.05]], "req": "agi", "text": "摘下来也没有人认得。"},
	"set_warrant_0": {"name": "追缉令·钩刀", "kind": "set", "set_id": "warrant", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "mine",
		"implicit": [[ItemModifier.Stat.CRIT_RATE, 0.03]], "req": "tec", "form": "blade", "text": "刀鞘上的格子，一格一个名字。"},
	"set_warrant_1": {"name": "追缉令·皮大衣", "kind": "set", "set_id": "warrant", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "mine",
		"implicit": [[ItemModifier.Stat.MOVE_SPEED_PCT, 0.04]], "req": "agi", "text": "雪地里跑起来，下摆不会绊脚。"},
	"set_warrant_2": {"name": "追缉令·名单", "kind": "set", "set_id": "warrant", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "mine",
		"implicit": [[ItemModifier.Stat.CRIT_DMG, 0.1]], "req": "tec", "text": "划掉的比没划掉的多。"},
	"set_inspectors_0": {"name": "督察组定制长刀", "kind": "set", "set_id": "inspectors", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "city",
		"implicit": [[ItemModifier.Stat.CRIT_RATE, 0.03]], "req": "tec", "form": "blade", "text": "刀鞘上刻着上一任的名字，被磨掉了。"},
	"set_inspectors_1": {"name": "督察组外勤背心", "kind": "set", "set_id": "inspectors", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "city",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0]], "req": "phy", "text": "第二年的夏天最难熬。"},
	"set_inspectors_2": {"name": "督察组任期铭牌", "kind": "set", "set_id": "inspectors", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "city",
		"implicit": [[ItemModifier.Stat.MAX_HP_PCT, 0.04]], "req": "phy", "text": "两个日期，中间一道横线。"},
	"set_grey_order_0": {"name": "琉璃骨尺", "kind": "set", "set_id": "grey_order", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "city",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05]], "req": "agi", "form": "fist", "text": "尺子量的是规矩。"},
	"set_grey_order_1": {"name": "灰尾长衫", "kind": "set", "set_id": "grey_order", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "city",
		"implicit": [[ItemModifier.Stat.RES_FLAT, 4.0]], "req": "arts", "text": "穿上这身，就不是一个人走夜路。"},
	"set_grey_order_2": {"name": "碎琉璃坠", "kind": "set", "set_id": "grey_order", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "city",
		"implicit": [[ItemModifier.Stat.RES_FLAT, 4.0]], "req": "arts", "text": "碎了一半，另一半还认得主人。"},
	"set_clean_snow_0": {"name": "洁雪仪刃", "kind": "set", "set_id": "clean_snow", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "snow",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05], [ItemModifier.Stat.CRIT_RATE, 0.03]], "req": "tec", "form": "blade", "text": "刃面上的环纹，是一场雪落下的样子。"},
	"set_clean_snow_1": {"name": "洁雪仪氅", "kind": "set", "set_id": "clean_snow", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "snow",
		"implicit": [[ItemModifier.Stat.RES_FLAT, 4.0], [ItemModifier.Stat.MAX_HP_PCT, 0.04]], "req": "arts", "text": "雪祀的时候，它比雪还白。"},
	"set_clean_snow_2": {"name": "洁雪手鼓", "kind": "set", "set_id": "clean_snow", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow",
		"implicit": [[ItemModifier.Stat.ARTS_PCT, 0.05]], "req": "arts", "text": "鼓面上一棵树、三个人，鼓声替他们说话。"},
	"set_fire_watch_0": {"name": "守望者战斧", "kind": "set", "set_id": "fire_watch", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 1.6, "region": "snow",
		"implicit": [[ItemModifier.Stat.ATK_PCT, 0.04], [ItemModifier.Stat.DEF_FLAT, 20.0]], "req": "phy", "form": "heavy", "req_column": "heavy", "text": "斧背上的铁钉，是用来敲醒守夜人的。"},
	"set_fire_watch_1": {"name": "守望者皮甲", "kind": "set", "set_id": "fire_watch", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 1.6, "region": "snow",
		"implicit": [[ItemModifier.Stat.DEF_FLAT, 20.0], [ItemModifier.Stat.MAX_HP_PCT, 0.04]], "req": "phy", "text": "皮子是去年的，火是今晚的。"},
	"set_fire_watch_2": {"name": "守望者火绒盒", "kind": "set", "set_id": "fire_watch", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 1.6, "region": "snow",
		"implicit": [[ItemModifier.Stat.MAX_HP_PCT, 0.04]], "req": "phy", "text": "盖缝里透出一点光，一整夜都不会灭。"},
}

## Set names and bonuses (§6); the bonuses themselves are in GearEffects.
const SETS := {
	"nameless": {"name": "无名者", "region": "mine", "pieces": ["set_nameless_0", "set_nameless_1", "set_nameless_2"], "two": "生命低于 50% 时攻速 +12", "three": "击杀叠「接替」最多 3 层；招牌发动时消耗，每层招牌伤害 +30%"},
	"warrant": {"name": "追缉令", "region": "mine", "pieces": ["set_warrant_0", "set_warrant_1", "set_warrant_2"], "two": "对生命低于 50% 的敌人暴击率 +10%", "three": "命中时标记一名敌人 4 秒；它死亡时 3 秒内移速 +15%、回复 3% 生命"},
	"inspectors": {"name": "特别督察组", "region": "city", "pieces": ["set_inspectors_0", "set_inspectors_1", "set_inspectors_2"], "two": "防御 +40；受击时 10% 格挡一半伤害", "three": "招牌发动时 3 秒受伤 −20%，半径 3 内敌人停顿 0.5 秒（冷却 8 秒）"},
	"grey_order": {"name": "灰色秩序", "region": "city", "pieces": ["set_grey_order_0", "set_grey_order_1", "set_grey_order_2"], "two": "法抗 +8；生命低于 50% 时获得 20% 生命上限的屏障（冷却 20 秒）", "three": "屏障破碎时，半径 2.5 内 120% 法术攻击力并眩晕 1 秒"},
	"clean_snow": {"name": "洁雪之仪", "region": "snow", "pieces": ["set_clean_snow_0", "set_clean_snow_1", "set_clean_snow_2"], "two": "法术攻击力 +15%", "three": "招牌发动时降下 3 米洁雪 4 秒：敌人移速 −30%，自身每秒回复 2% 生命（冷却 10 秒）"},
	"fire_watch": {"name": "执火守望", "region": "snow", "pieces": ["set_fire_watch_0", "set_fire_watch_1", "set_fire_watch_2"], "two": "防御 +40；生命上限 +8%", "three": "2 秒内受击 3 次时震地一次：半径 2.5、120% 攻击力、推开（冷却 8 秒）"},
}

## Per-kill chance of the killer's exclusive, and of a regional set piece (§1.1).
const EXCLUSIVE_CHANCE := {"normal": 0.005, "guard": 0.02, "elite": 0.04, "boss": 0.25}
const SET_CHANCE := {"elite": 0.015, "vault": 0.015, "boss": 0.05}
## A set piece of a set already found this contract is this much likelier.
const SET_SEEN_WEIGHT := 2.0

static func kind(id: String) -> String:
	return str(GEAR.get(id, {}).get("kind", "special"))

## The exclusives an enemy type drops.
static func exclusives_of(enemy_type: String) -> Array:
	return GEAR.keys().filter(func(id): return kind(id) == "exclusive" and str(GEAR[id].source_enemy) == enemy_type)

static func roll_exclusive(enemy_type: String, region: String, depth: int, rng: RandomNumberGenerator, boss: bool = false) -> Item:
	var ids := exclusives_of(enemy_type)
	if ids.is_empty(): return null
	var item := create(ids[rng.randi_range(0, ids.size() - 1)], depth, rng, boss)
	item.origin_region = region
	return item

## A set piece from `region`'s sets; `seen` holds set ids already found.
static func roll_set_piece(region: String, depth: int, rng: RandomNumberGenerator, seen: Dictionary = {}, boss: bool = false) -> Item:
	var ids := GEAR.keys().filter(func(id): return kind(id) == "set" and str(GEAR[id].region) == region)
	if ids.is_empty(): return null
	var weights: Array = ids.map(func(id): return SET_SEEN_WEIGHT if seen.has(str(GEAR[id].set_id)) else 1.0)
	var total := 0.0
	for w in weights: total += float(w)
	var pick := rng.randf() * total
	var chosen: String = ids.back()
	for i in range(ids.size()):
		pick -= float(weights[i])
		if pick <= 0.0:
			chosen = ids[i]
			break
	var item := create(chosen, depth, rng, boss)
	item.origin_region = region
	return item

## "Name 2/3" plus both bonuses, as the tooltip shows them.
static func set_lines(item: Item, worn: int) -> Array:
	var data: Dictionary = GEAR.get(item.special, {})
	if str(data.get("kind", "")) != "set": return []
	var set_data: Dictionary = SETS.get(str(data.set_id), {})
	return [[str(set_data.name), worn], ["2 件：" + str(set_data.two), worn >= 2], ["3 件：" + str(set_data.three), worn >= 3]]

static func drop_chance(reward: float) -> float:
	return DROP_CHANCE + maxf(reward, 0.0) * DROP_CHANCE_PER_REWARD

static func create(id: String, depth: int, rng: RandomNumberGenerator, boss: bool = false) -> Item:
	var data: Dictionary = GEAR[id]
	var size: Vector2i = data.size
	var item := Item.create(data.name, data.category, size.x, size.y, float(data.power) + depth * 0.2)
	item.special = id
	item.rarity = 2
	item.value = 60 + depth * 10
	item.description = data.text
	# Named gear is deep gear: T3 at the first block, a boss one grade higher.
	item.grade = Progression.grade_for(2, depth, 1 if boss else 0)
	for pair in data.get("implicit", []):
		var fixed := ItemModifier.stat_mod(pair[0], float(pair[1]))
		fixed.tier = GearCatalog.IMPLICIT_TIER
		item.modifiers.append(fixed)
	for trigger in data.get("triggers", []): item.modifiers.append(ItemModifier.trigger_mod(trigger))
	if not data.get("cost", []).is_empty():
		var cost := ItemModifier.stat_mod(data.cost[0], data.cost[1])
		cost.tier = -1
		item.modifiers.append(cost)
	var pool: Array = FieldCatalog.AFFIX_POOLS[data.category]
	var stat: int = pool[rng.randi_range(0, pool.size() - 1)]
	item.modifiers.append(ItemModifier.roll_affix(stat as ItemModifier.Stat, FieldCatalog._roll_tier(2, rng), rng))
	# Special and exclusive gear carry prefixes; set pieces do not (装备前缀策划案 §0.1-5).
	PrefixCatalog.roll_onto(item, str(data.get("region", "")), depth, rng)
	return item

## A region's own special gear is REGION_WEIGHT times as likely.
static func roll(region: String, depth: int, rng: RandomNumberGenerator) -> Item:
	var total := 0.0
	var ids := GEAR.keys().filter(func(id): return kind(id) == "special")
	for id in ids: total += REGION_WEIGHT if GEAR[id].region == region else 1.0
	var pick := rng.randf() * total
	for id in ids:
		pick -= REGION_WEIGHT if GEAR[id].region == region else 1.0
		if pick <= 0.0:
			var item := create(id, depth, rng)
			item.origin_region = region
			return item
	return create(ids.back(), depth, rng)
