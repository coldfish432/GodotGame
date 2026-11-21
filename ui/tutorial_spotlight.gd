class_name TutorialSpotlight
extends Control

## First sight (用户 2026-10-22: 密室、踪迹、火堆、陷阱等玩家第一次屏幕中遇到后
## 暂停游戏蒙板高亮圈出目标并显示 prts 卡片; 局内操作、机制和基地设施都补教程).
## The first time one of these is on screen and near her — or, in the base,
## the first time she walks up to a station — the game stops (modal
## "tutorial"), the screen dims but for a ring (or a box, for a bar or a slot)
## round it, and a PRTS card beside it says what it is; 知道了 (or Esc) and on.
## A base screen's card comes up the first time that screen opens (用户
## 2026-10-23: 其他界面第一次打开的时候也介绍); the dispatch desk's comes in two,
## the contract on the right first, then the floors in the middle. Before the
## first contract, as soon as the waking talk is over (用户 2026-10-24: 这个页面
## 之后立即跳三个台的介绍), the three departure stations are ringed at once
## (DEPARTURE), each with its own card beside it: 调度台 (出击, with 知道了),
## 整备台 and 后勤柜台; TutorialCard's move and dodge come after it.
## Some come from events instead (low life, the first camp, a retreat, gear
## sent back): `request`, shown over whatever screen is up, with no ring when
## there is nothing to point at. Each kind once, ever
## (SystemScreens.settings.tutorial_seen); off with the 新手引导 setting. The
## base ones wait until the first contract has started (TutorialCard's
## contract step), so the first walk to the dispatch desk is not stopped at
## every station. Same look as TutorialCard. Only the real game shows it, or a
## test that sets `forced`.

## id -> [title, what PRTS says, ring radius in px]
const TIPS := {
	# --- 局内：地图上的东西 ---
	"vault": ["密室", "博士，这段墙脚有裂痕与幽光，墙后可能是一间密室。走到墙前按 E 即可破开；室内有稀有物资，也可能有守卫者。", 64.0],
	"sealed": ["密室守卫者", "密室里的宝箱和藏品已被封印。击败全部守卫者后才能打开，守卫者中有一名精英。", 64.0],
	"trace": ["踪迹", "检测到干员留下的踪迹。靠近后按交互键调查；同一名干员的踪迹集齐 6 条后，下次前往该地区就能找到她。", 48.0],
	"lost_signal": ["识别信号", "检测到失散的罗德岛干员的识别信号。她就在这一层，位置已标在小地图上。", 0.0],
	"lost_operator": ["失散干员", "失散的干员被敌人包围了。清理她周围的敌人，然后靠近她按 E。", 60.0],
	"lost_joined": ["归队", "罗德岛小队已接应干员。她已经归队，之后撤退或倒下都不受影响；她负责的部门可以重新运转了。", 0.0],
	"recruit": ["寻访目标", "博士，寻访目标就在前方，身边有守卫。击败守卫后按交互键与她会面；成功撤离后，她才会正式加入罗德岛。", 60.0],
	"handover": ["交接点", "运送合同的交接点。背包或安全袋里带着这张订单的大宗货箱时，按交互键交付；报酬在结算时到账。", 56.0],
	"fire": ["火堆", "这里有一处火堆。点燃时站在旁边寒冷会持续下降；熄灭了就按交互键，从背包里选燃料添进去。", 56.0],
	"trap": ["陷阱", "前方地面有陷阱。踩中会受到固定伤害并提高威胁值；重型陷阱触发后有短暂引信，及时闪避可以躲开。", 40.0],
	"shower": ["净化喷淋", "净化喷淋点仍可使用。在旁边按住交互键约 3 秒，可以降低污染，仅限一次。", 52.0],
	"extraction": ["撤离信标", "已发现撤离信标。进入撤离区域并停留数秒即可撤离，携带的物品将一同带回罗德岛。", 72.0],
	"route": ["深入入口", "这是通往下一层的入口，每条路线一个，颜色对应下一层的节点。按交互键打开路线图选择去向。", 56.0],
	"device": ["强化装置", "强化装置可以使用一次。按交互键从几件藏品中选择一件，效果持续到本次行动结束。", 56.0],
	"trader": ["坎诺特", "诡异行商坎诺特，只在路线图上的“诡异行商”节点出现。可以用赤金购买藏品、装备与药剂，也可以把物品卖给他；货架可以付费刷新。", 56.0],
	# 肉鸽路线图策划案 v0.2 §4–5.
	"event": ["不期而遇", "这一层有一件不期而遇的事。走近按交互键查看，每个选择都写明代价与收获；也可以不理会直接离开。", 56.0],
	"campfire": ["营火", "临时休整的营火。按交互键休息一次，回复 20% 生命上限并驱散寒冷。旁边的冲淋装置可以降低污染。", 56.0],
	"squad": ["罗德岛小队", "罗德岛小队在此待命。支付赤金可以为一件装备投保，或者直接把它送回基地。小队附近威胁值不会上涨。", 56.0],
	"post": ["势力据点", "这是一处势力据点。只收购该势力需要的货物，按当前价格当面成交。", 56.0],
	"cache": ["战斗缴获", "这里有一份战斗缴获。按交互键打开，从中选择一件藏品。", 48.0],
	"boss": ["区域头目", "博士，前方是头目的场地。头目倒下前出口闸门会保持关闭，请做好准备再进入。", 72.0],
	"mine": ["干扰地雷", "场地里布置有干扰地雷。站在旁边按交互键布雷，敌人踏入时会被炸伤，之后一段时间受到的伤害提高。每个只能用一次。", 44.0],
	"leader": ["头目", "检测到头目级敌对单位，威胁较高。请留意地面的攻击预警，必要时闪避。", 64.0],
	"elite": ["精英敌人", "精英敌人比普通敌人更强韧，击败后的物资也更好。", 52.0],
	"sentinel": ["萨卡兹哨兵", "萨卡兹哨兵发现博士后会发出警报，使威胁值加速上涨。建议优先将其击倒。", 52.0],
	"patrol": ["巡逻队", "威胁值涨满后，敌方会派出巡逻队搜捕博士。同一层里，后来的巡逻队会更强。", 60.0],
	"heal_orb": ["治疗球", "敌人掉落了治疗球。靠近即可吸取，立即回复生命。", 36.0],
	# --- 局内：界面与事件 ---
	"low_hp": ["生命告急", "博士，干员生命偏低。快捷栏上的急救剂可以立即回复；最右侧的自动格会在生命低于下限时自动喝药，上下限可在设置里调整。应急强心针放在背包里，会在致命一击时自动生效。", 34.0],
	"threat": ["威胁值", "敌对势力正在锁定博士的位置。屏幕上方的细条就是威胁值：停留越久涨得越快，涨满时会有巡逻队前来搜捕；进入下一层后保留一部分。", 0.0],
	"contamination": ["源石污染", "干员正在污染区中暴露。污染达到 60 时生命上限降低、自然回复减半，90 时开始持续掉血。抑制喷剂、净化喷淋和营地都可以降低污染。", 0.0],
	"cold": ["寒冷", "冰原的寒冷正在累积。达到 60 时移动和体力回复变慢，90 时攻速下降并开始掉血。站在点燃的火堆旁、使用热能饮剂或自热罐头都能驱寒。", 0.0],
	"debt": ["血债", "击杀家族成员会积累血债。达到 60 时家族敌人更凶狠，90 时会派出清算小队。中间人信物、镇静合剂和营地赔偿都可以降低血债。", 0.0],
	"camp": ["前进据点", "前进据点已确认，博士。这里没有敌人：可以在可露希尔处补给、处理污染或血债，也可以从这里撤离。到过的据点以后可以直接作为出发点。", 0.0],
	"death": ["撤退", "干员倒下，罗德岛小队已接回博士。安全袋里的物品全部保留；身上和背包里没有投保的物品遗失；投保的装备会在 2 到 4 小时后由罗德岛小队送回仓库。倒下的干员带着重伤，可在医疗前台治疗。", 0.0],
	"insured_back": ["投保送回", "罗德岛小队找回了投保的装备，已送回仓库。保险随之用掉，需要的话请在后勤柜台重新投保。", 0.0],
	# --- 基地设施（第一次走到旁边） ---
	# 用户 2026-10-24: 进入整备台后介绍仓库和制式选择.
	"loadout_depot": ["仓库", "仓库里存放着带回的物品。右键装备直接穿上，右键药剂放进背包；也可以把物品拖到人偶、背包或安全袋里。", 0.0],
	"loadout_issue_tab": ["罗德岛制式", "缺装备时，到制式页免费领取罗德岛制式装备：每个部位选一件，合同结束时收回，无需投保。", 0.0],
	"loadout_issue": ["制式选择", "每个部位列出可选的罗德岛制式装备，点击即可换上；补齐空槽会给所有空着的部位各配一件，交还制式则全部收回。", 0.0],
	"base_loadout": ["整备台", "整备台用于换装、改造和领取制式装备。换装页可以把仓库里的装备穿上、把物品放进背包或安全袋带走；改造页可以重铸、校准、精调装备的前缀；制式页可以免费领取罗德岛制式装备，合同结束时收回。", 60.0],
	"base_insurance": ["后勤柜台", "出发前可以在这里为装备投保。投保的装备若没能带回，罗德岛小队会在 2 到 4 小时后送回；保费等于装备的交付价。罗德岛制式装备合同结束时会收回，无需投保。", 60.0],
	"base_departure": ["调度台", "出击的地方：出发页选择地区和起点，合同板页接取各部门的合同，确认出发准备后即可出击。", 60.0],
	"base_stash": ["仓管台", "仓管台管理仓库。所有物品共用仓库容量，一格放一件装备或一组材料；仓储部升级会提高容量和材料的单格堆叠数量。点击物品带入背包，拖动背包里的物品即可存回。", 60.0],
	# The dispatch desk's screen, in two (BaseScreens.contracts' columns).
	"dispatch_contract": ["合同委托", "右侧是这个地区的详情：掉落和本局会生效的合同。合同在合同板页接取，最多同时进行 3 份；深入、猎杀、运送在一次外勤里完成并撤离才算，回收和交付带回后在出库区交。点击最终准备，确认干员与装备即可出击。", 0.0],
	"dispatch_floors": ["层数与撤离", "中间是本次行动的层数，每 10 层为一段。第 %d–%d 层中必有一层设有撤离信标；第 10 层是前哨据点（每 20 层是首领战场），之后是营地，营地设有固定撤离点，也可以在可露希尔处补给。", 0.0],
	# The route map (肉鸽路线图策划案 v0.2 §7), the first time it opens.
	"route_map": ["路线图", "每 10 层是一张路线图，每一列是一层。只看得清下一层；再下一层只显示是作战还是遭遇，更远的只标出撤离信标与合同目标。不同节点的层内内容不同，选好后点击前进。", 0.0],
	"base_outbound": ["出库区", "各部门把需要的物资写成订单挂在这里。交付货架或背包里的物品完成订单，就能获得龙门币；也可以把物品直接卖给可露希尔。", 60.0],
	"base_report": ["医疗前台", "医疗前台会给出上一份合同的回收报告。倒下的干员带有重伤、生命上限降低，在这里支付龙门币治疗。", 60.0],
	"base_pharmacy": ["药房窗口", "药房出售标准急救剂和缓释凝胶。每份合同出发时还会免费配发 3 瓶急救剂。", 56.0],
	"base_store": ["可露希尔的商店", "可露希尔的商店用赤金出售特供药剂，每小时补货。这里还可以出售赤金、换汇、贷款，以及购买减缓地图特色的随队物资。", 60.0],
	"base_exchange": ["交易所", "交易所终端可以买卖九大势力的商品，查看行情与新闻，下现货、挂单、远期和差价合约。交易所需要先建成才能使用。", 64.0],
	"base_workshop": ["加工站", "加工站用材料和龙门币加工成品，按现实时间计时，完成后直接入库。", 60.0],
	"base_personnel": ["人事部", "人事部记录各位干员的寻访进度：从发现踪迹到可以寻访、正式入职。", 56.0],
	"base_roster": ["特派干员", "突围时失散的特派干员。失散的一栏写着她最后的信号来自哪个地区、哪几层。", 0.0],
	"base_locked": ["负责干员失散", "这个部门的负责干员还没有归队。找到她，部门才能重新运转。", 0.0],
	"base_dept_return": ["归队的干员", "归队的干员回到了罗德岛，会在舰上走动。她负责的部门可以重新运转了。", 0.0],
	"base_sand_table": ["沙盘", "沙盘上可以指挥罗德岛号航行到各地，开启医疗驻留提升当地关系，或者提交、装箱大宗订单。航行按现实时间进行。", 72.0],
	"base_research": ["科研部", "科研终端用龙门币和材料推进研究，按现实时间进行。研究可以带来各种长期加成，部分课题需要先完成前置研究。", 60.0],
	"base_hub": ["基建总控台", "基建总控台需要先建成。之后，每个设施接入总控台，就能在这里远程查看和购买它的升级。", 64.0],
	"base_build_site": ["施工点", "这里是尚未建成的设施。按交互键查看建造需要的龙门币和材料；没有接入总控台的设施也可以在现场升级。", 64.0],
	"base_lift": ["升降梯", "升降梯连接舰桥大厅与二层，二层是农业部和食堂。", 56.0],
	"base_farm": ["农业部", "农业部的水培槽可以种植作物，按现实时间生长，成熟后不会枯萎。作物可以送到食堂烹饪。", 60.0],
	"base_canteen": ["食堂", "食堂用作物烹饪补给。出发前吃一份，下一份合同中干员会获得生命、回复或攻击方面的增益。", 60.0],
	# --- 界面首次打开（用户 2026-11-15: 做每个ui界面的首次开启介绍）: SCREENS ---
	"ui_pack": ["背包", "背包里是这次带出来的物品。右键使用或装备，拖动可以整理、丢弃或拖到快捷栏绑定药剂。安全袋里的物品倒下也不会丢失。", 0.0],
	"ui_relics": ["藏品", "本次行动拿到的藏品都在这里，效果持续到行动结束。图鉴页记录见过的全部藏品。", 0.0],
	"ui_map": ["地图", "整层地图，撤离信标、入口和合同目标都标在上面。", 0.0],
	"ui_dispatch_board": ["合同板", "各部门把需要的事挂在合同板上：外勤部的深入与猎杀，工程部、医疗部、后勤部的回收与交付，商务部的运送。最多同时接 3 份，接下后一直有效，直到完成或放弃；没接的合同每两次结算后换新。同一地区的深入、猎杀、运送各只能接一份。", 0.0],
	"ui_journal": ["外勤合同", "目标页是本局生效的合同；交付页是已接的回收、交付合同需要的物资，带回后在出库区交付。", 0.0],
	"ui_operator": ["干员", "当前干员的数值与成长。概览页列出全部最终数值，右侧名册可以切换查看其他干员。", 0.0],
	"ui_operator_attr": ["属性", "升级获得属性点，分配到各项属性上。每点的效果写在旁边。", 0.0],
	"ui_operator_skill": ["技能", "升级获得技能点，用来点亮技能树。", 0.0],
	"ui_settle": ["行动结算", "这次行动的结果：赤金、合同报酬、深度与可交付的合同，下方逐份列出合同是否完成。", 0.0],
	"ui_settle_store": ["入库", "把背包与安全袋里的物品存进仓库。可以一键入库，也可以逐件拖动。仓库放不下的会进 PRTS 邮件。", 0.0],
	"ui_deploy": ["出发准备", "出发前最后确认：出战干员、身上装备、背包和安全袋。确认无误后出击。", 0.0],
	"ui_prts": ["PRTS 终端", "PRTS 终端保存消息历史和邮件。仓库放不下的物品、运营账单和各种通知都会发到这里。按回车可以随时打开。", 0.0],
	"ui_pickup": ["拾取过滤", "按前缀数量和品质过滤地上的装备名牌，低于条件的不再显示。", 0.0],
	# 交易所各页.
	"ui_ex_market": ["行情", "左侧是九大势力的商品盘，中间是 K 线，右侧下单：现货立即成交，挂单等价格到了再成交，远期约定日后交割，差价合约可以带杠杆做多做空，保证金不足会被强平。", 0.0],
	"ui_ex_fx": ["外汇", "各地区货币盘与交叉盘。可以换汇、持有外币或做外汇差价合约。干员薪资按家乡货币支付，持有外币可以对冲汇率。", 0.0],
	"ui_ex_positions": ["持仓", "远期合约、差价合约和挂单都列在这里，带浮动盈亏。保证金不足时可以追加保证金或平仓。", 0.0],
	"ui_ex_news": ["新闻", "各地的行情新闻。新闻会推动相关商品和企业的价格，各势力也会据此买卖。", 0.0],
	"ui_ex_money": ["资金", "赤金实物可以存入赤金账户，账户里的赤金可以直接交易。下方是九大势力对罗德岛的关系，等级越高交易条件越好。", 0.0],
	# 经济系统教程：资产页第一次打开时依次出现.
	"ui_econ_money": ["罗德岛的钱", "龙门币是罗德岛的资金：合同报酬、出库交付、卖货、分红和利息都进余额，建设、升级、日账和薪资也从余额扣。赤金是局内货币，可以存进赤金账户，或在可露希尔处卖成龙门币。余额本身不生息。", 0.0],
	"ui_econ_worth": ["账户净值", "上方是账户总览。账户净值 = 龙门币 + 赤金与外币折算 + 存款 + 证券与策略 + 罗德岛库存 − 欠款，个人仓库里的物品不算。借款额度按净值计算。", 0.0],
	"ui_econ_upkeep": ["日账", "运营页是罗德岛的日账。每个交易日（和现实日期同步），各设施消耗一族材料：先从罗德岛库存扣，不够的按行情自动买进；干员薪资按家乡货币折算。设施越多、等级越高，日账越贵。", 0.0],
	"ui_econ_stock": ["罗德岛库存", "罗德岛库存专供设施消耗，在仓管台从个人仓库转入，只能转入、不能取回。行情低时买进材料转入，等于提前锁定日账成本。个人仓库里的东西永远不会被自动扣。", 0.0],
	"ui_econ_rations": ["口粮与热餐", "每个交易日，每名在舰干员吃 1 份基础作物，只从罗德岛库存扣，作物只能在农业部自己种。够了全舰有热餐，出击最大生命 +3%；不够就停发补给，补够后到食堂点“开饭”恢复。", 0.0],
	"ui_econ_arrears": ["欠费", "龙门币不够付日账时会自动借款，按天计息。额度用完或逾期后按顺序暂停：交易所策略、加工部、农业部、科研部。整备台、仓库和出击永远可用，还清后立即恢复。", 0.0],
	"ui_econ_cycle": ["景气指数", "左侧是净值走势和景气指数。景气由货价、势力、情绪和信贷松紧组成；信贷越紧，基础贷款利率越高，企业也越难扩张。", 0.0],
	"ui_econ_grow": ["让钱生钱", "存款页存活期或定存；证券页买赤金产品和债券；企业页买上市企业的股份；策略页让自动交易策略替你交易。收益越高，波动也越大。", 0.0],
	"ui_econ_deposit": ["存款", "活期随存随取，按天计息。定存 1、3、7 天，期限越长利率越高，提前取出没收利息。存进去的钱会借给市场，信贷池也会因此变松。", 0.0],
	"ui_econ_credit": ["信贷", "借款随借随还，没有到期日，按天复利。额度跟着净资产变，借得越接近额度利率越高。自动还款每天把超过 3 天日账的余额拿去还款。欠款超过额度 1.5 倍为逾期，龙门币收入先还债；超过 2 倍会依次变卖策略持仓、证券、定存和活期。", 0.0],
	"ui_econ_securities": ["证券", "左侧是赤金产品：赤金存单按赤金计息，两只基金持有一篮子企业股份并定期派息。右侧是债券：期限 3 天或 7 天，票息高于定存，到期还本；提前卖出按市价，价格随利率涨跌。", 0.0],
	"ui_firm_list": ["上市企业", "左侧是上市企业。市盈率 = 股价 ÷ 每股收益；PEG = 市盈率 ÷ 利润增长率，低于 1 显示绿色，高于 2 显示橙色。", 0.0],
	"ui_firm_detail": ["企业详情", "中间是选中企业的 K 线、关键比率、护城河 12 项（达标越多，经营越稳）和季报。企业按季度公布营收、净利和分红。", 0.0],
	"ui_firm_order": ["买卖股份", "右侧买卖股份。持有股份可以拿分红；持股达到 5% 会公开，各势力都会知道。下方是主要持有人和 PRTS 研报。", 0.0],
	"ui_strat_slots": ["策略槽", "交易所 3 级开 1 个策略槽，4 级开 2 个，科研“量化交易”再加 1 个。鼠标停在策略名称上可以查看规则。", 0.0],
	"ui_strat_new": ["新建策略", "选好模板，设定资金、止损线（净值回撤到这里就停）、运行天数、参数和标的。先点回测，用历史 K 线免费试算，每天 10 次；满意了再启动。", 0.0],
	"ui_strat_run": ["运行中的策略", "中间是策略的净值曲线、收益、最大回撤、胜率和持仓。策略每天按占用资金收 0.05% 托管费；罗德岛欠费时，策略最先暂停。", 0.0],
	# 其他设施的分页.
	"ui_stash_unpack": ["拆包", "交易所买来的大类包在这里拆开，按点数自选里面的物品。", 0.0],
	"ui_stash_stock": ["罗德岛库存", "把个人仓库的材料转入罗德岛库存，供设施日账和食堂口粮消耗。只能转入，不能取回也不能卖；右侧显示每族还够用几天。", 0.0],
	"ui_work_pack": ["打包", "把同一大类的物资打成交易包，交易所只按大类包交易。仓库里按 P 键也可以一键打包。", 0.0],
	"ui_work_gift": ["礼品包", "把收藏品打成礼品包，在沙盘的势力页送给势力，可以提升关系。", 0.0],
	"ui_bench_refit": ["改造", "用材料和龙门币改造装备的前缀：重铸、校准和精调。", 0.0],
	"ui_bench_insure": ["投保", "和后勤柜台一样：为装备投保后，没带回的会在 2 到 4 小时后由罗德岛小队送回。制式装备不用投保。", 0.0],
	"ui_bench_support": ["增益", "出发前的增益集中在这里：食堂补给、科研课题、药剂和随队物资。各部门的入口仍然保留。", 0.0],
	"ui_canteen_eat": ["用餐", "出发前吃一份做好的补给，下一份合同中生效。停发补给的日子不能用餐。", 0.0],
	"ui_canteen_mail": ["冷链", "把一份补给交给企鹅物流寄出，外勤时在罗德岛小队处领取。", 0.0],
	"ui_lab_projects": ["课题", "课题签下后持续 3 次出击，每次出发时收取费用，期间提供加成。课题位有限。", 0.0],
	"ui_lab_endless": ["基础研究", "基础研究没有上限，每升一级提供一点永久加成，费用逐级提高。", 0.0],
	"ui_sand_factions": ["势力", "九大势力对罗德岛的关系、修正项和解锁的特权。关系从冷漠升到崇拜，每升一级有礼物；礼品包也在这里送出。", 0.0],
	"ui_store_consign": ["代售", "可露希尔代售的交易包。在基地按锚地代售，营地按地图代售；可以买，也可以把自己的交易包交给她卖。", 0.0],
	"ui_store_bars": ["出售赤金", "把赤金实物卖成龙门币。", 0.0],
	"ui_store_fx": ["换汇", "按实时汇率在外币和龙门币之间兑换。", 0.0],
	"ui_store_loan": ["贷款", "和交易所资产页的信贷是同一笔：随借随还，按天计息，额度跟着净资产变。", 0.0],
	"ui_store_kits": ["随队物资", "减缓地图特色（污染、寒冷、血债）的随队物资，买下后下一份合同自动带上。", 0.0],
	"ui_store_cases": ["整理箱", "整理箱在仓库里只算 1 件，里面可以装多件物品，可以原地升级到 4 级。", 0.0],
	"ui_camp_deposit": ["寄存", "把背包里的普通材料交给可露希尔，付交付价 20% 的赤金，物品送回仓库。药剂和特殊材料不收。", 0.0],
	"ui_camp_delivery": ["交割", "到期的远期交货合约在这里交割：背包里的材料够数就能交货。", 0.0],
	"ui_camp_supply": ["补给", "用赤金买燃料和缓解地图特色的补给，直接放进背包。", 0.0],
	"ui_camp_treat": ["处理", "用赤金处理污染或血债，每个营地一次。", 0.0],
}

## Screens (用户 2026-11-15: 做每个ui界面的首次开启介绍，增加经济系统玩法教程):
## the key a screen reports (`screen`, from BaseScreens.shell and the screens
## outside it) -> its tips in order, each [id, where]: null for the card in the
## middle, a Rect2 box on screen, or "button:<text>" for that button.
## Stations whose own card (base_<kind>) already covers the first page list
## only their other pages.
const ASSET_TOP := Rect2(16, 110, 1248, 58)
const ASSET_LEFT := Rect2(16, 174, 500, 508)
const ASSET_RIGHT := Rect2(526, 174, 738, 508)
const SIDE_LEFT := Rect2(16, 110, 330, 572)
const SIDE_MID := Rect2(356, 108, 524, 574)
const SIDE_RIGHT := Rect2(890, 110, 374, 572)
const SCREENS := {
	"背包": [["ui_pack", null]],  # i18n: skip
	"藏品": [["ui_relics", null]],  # i18n: skip
	"地图": [["ui_map", null]],  # i18n: skip
	"外勤合同": [["ui_journal", null]],  # i18n: skip
	"调度台/合同板": [["ui_dispatch_board", null]],  # i18n: skip
	"干员": [["ui_operator", null]],  # i18n: skip
	"干员/属性": [["ui_operator_attr", "button:属性"]],  # i18n: skip
	"干员/技能": [["ui_operator_skill", "button:技能"]],  # i18n: skip
	"结算/结算": [["ui_settle", null]],  # i18n: skip
	"结算/仓库": [["ui_settle_store", "button:仓库"]],  # i18n: skip
	"出发准备": [["ui_deploy", null]],  # i18n: skip
	"PRTS": [["ui_prts", null]],  # i18n: skip
	"设置/拾取过滤": [["ui_pickup", "button:拾取过滤"]],  # i18n: skip
	"交易所/行情": [["ui_ex_market", "button:行情"]],  # i18n: skip
	"交易所/外汇": [["ui_ex_fx", "button:外汇"]],  # i18n: skip
	"交易所/持仓": [["ui_ex_positions", "button:持仓"]],  # i18n: skip
	"交易所/新闻": [["ui_ex_news", "button:新闻"]],  # i18n: skip
	"交易所/资金": [["ui_ex_money", "button:资金"]],  # i18n: skip
	"交易所/资产": [["ui_econ_money", null], ["ui_econ_worth", ASSET_TOP], ["ui_econ_upkeep", ASSET_RIGHT], ["ui_econ_stock", ASSET_RIGHT],  # i18n: skip
		["ui_econ_rations", ASSET_RIGHT], ["ui_econ_arrears", ASSET_RIGHT], ["ui_econ_cycle", ASSET_LEFT], ["ui_econ_grow", "button:存款"]],  # i18n: skip
	"交易所/资产/存款": [["ui_econ_deposit", ASSET_RIGHT]],  # i18n: skip
	"交易所/资产/信贷": [["ui_econ_credit", ASSET_RIGHT]],  # i18n: skip
	"交易所/资产/证券": [["ui_econ_securities", ASSET_RIGHT]],  # i18n: skip
	"交易所/企业": [["ui_firm_list", SIDE_LEFT], ["ui_firm_detail", SIDE_MID], ["ui_firm_order", SIDE_RIGHT]],  # i18n: skip
	"交易所/策略": [["ui_strat_slots", SIDE_LEFT], ["ui_strat_new", SIDE_RIGHT], ["ui_strat_run", SIDE_MID]],  # i18n: skip
	"仓管台/拆包": [["ui_stash_unpack", "button:拆包"]],  # i18n: skip
	"仓管台/罗德岛库存": [["ui_stash_stock", "button:罗德岛库存"]],  # i18n: skip
	"加工站/打包": [["ui_work_pack", "button:打包"]],  # i18n: skip
	"加工站/礼品包": [["ui_work_gift", "button:礼品包"]],  # i18n: skip
	"整备台/改造": [["ui_bench_refit", "button:改造"]],  # i18n: skip
	"整备台/投保": [["ui_bench_insure", "button:投保"]],  # i18n: skip
	"整备台/增益": [["ui_bench_support", "button:增益"]],  # i18n: skip
	"食堂/用餐": [["ui_canteen_eat", "button:用餐"]],  # i18n: skip
	"食堂/冷链": [["ui_canteen_mail", "button:冷链"]],  # i18n: skip
	"科研部/课题": [["ui_lab_projects", "button:课题"]],  # i18n: skip
	"科研部/基础研究": [["ui_lab_endless", "button:基础研究"]],  # i18n: skip
	"沙盘/势力": [["ui_sand_factions", "button:势力"]],  # i18n: skip
	"可露希尔的商店/代售": [["ui_store_consign", "button:代售"]],  # i18n: skip
	"可露希尔的商店/出售赤金": [["ui_store_bars", "button:出售赤金"]],  # i18n: skip
	"可露希尔的商店/换汇": [["ui_store_fx", "button:换汇"]],  # i18n: skip
	"可露希尔的商店/贷款": [["ui_store_loan", "button:贷款"]],  # i18n: skip
	"可露希尔的商店/随队物资": [["ui_store_kits", "button:随队物资"]],  # i18n: skip
	"可露希尔的商店/整理箱": [["ui_store_cases", "button:整理箱"]],  # i18n: skip
	"可露希尔的商店/寄存": [["ui_camp_deposit", "button:寄存"]],  # i18n: skip
	"可露希尔的商店/交割": [["ui_camp_delivery", "button:交割"]],  # i18n: skip
	"可露希尔的商店/补给": [["ui_camp_supply", "button:补给"]],  # i18n: skip
	"可露希尔的商店/处理": [["ui_camp_treat", "button:处理"]],  # i18n: skip
}
## The dispatch desk's columns, in screen pixels (BaseScreens.contracts).
const DISPATCH_CONTRACT := Rect2(884, 60, 396, 660)
const DISPATCH_FLOORS := Rect2(236, 64, 640, 440)
## The route map's scrolling columns (EventScreens.routes).
const ROUTE_MAP := Rect2(0, 90, 970, 590)
## Before the first contract (TutorialCard's contract step), rung together:
## the first is base_departure's card, the others [station, title, text] a
## card each beside their rings.
const DEPARTURE := [["dispatch"], ["workbench", "整备台", "换装、改造装备，免费领取罗德岛制式装备。"],
	["logistics", "后勤柜台", "出发前为装备投保。罗德岛制式装备合同结束时会收回，无需投保。"]]
## Seen counts within this far of her, and inside the screen by INSET px.
const SEE_RANGE := 16.0
const TRAP_RANGE := 7.0
const INSET := 48.0
const SCREEN := Vector2(1280, 720)
const CHECK_SECONDS := 0.2
const CARD_WIDTH := 300.0
const NOTE_WIDTH := 220.0
const DIM := 0.72

var game: GameManager
var forced := false
## The tip up now ("" none), and where its ring is.
var showing := ""
var ring_at := Vector2.ZERO
var ring_radius := 0.0
## A box instead of a ring, for a bar or a slot (size zero: the ring).
var ring_box := Rect2()
var _check_left := 0.0
## Tips an event asked for (low life, a camp, a death…): [id, at], `at` a
## world point (Vector3), a screen point (Vector2), or null for no ring.
var _queue: Array = []
## Whether the field was stopped for it (modal "tutorial"); a tip over a
## screen that already stops it (the camp, the settlement) leaves that as is.
var _owns_modal := false
## Rings beyond the first, for a tip round several places at once (screen
## points), and the cards beside them.
var more_rings: Array[Vector2] = []
var _notes: Array[Control] = []
var _mask: ColorRect
var _ring: Control
var _card: PanelContainer
var _title: Label
var _text: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask = ColorRect.new()
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec2 centre;
uniform float radius;
uniform vec4 box;
uniform vec2 extent;
uniform float dim;
uniform vec3 more_a;
uniform vec3 more_b;
void fragment() {
	vec2 at = UV * extent;
	float d = distance(at, centre) - radius;
	if (more_a.z > 0.0) d = min(d, distance(at, more_a.xy) - more_a.z);
	if (more_b.z > 0.0) d = min(d, distance(at, more_b.xy) - more_b.z);
	if (box.z > 0.0) {
		vec2 q = abs(at - (box.xy + box.zw * 0.5)) - box.zw * 0.5;
		d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	}
	COLOR = vec4(0.0, 0.0, 0.0, dim * smoothstep(0.0, 8.0, d));
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_mask.material = material
	add_child(_mask)
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var plate := AK.box(AK.PLATE, AK.BLUE, 0, 12)
	plate.border_width_left = 3
	_card.add_theme_stylebox_override("panel", plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var badge := AK.label("PRTS", 11, AK.INK, AK.en())
	var badge_plate := AK.box(AK.BLUE, Color.TRANSPARENT, 0, 0)
	badge_plate.content_margin_left = 6
	badge_plate.content_margin_right = 6
	badge.add_theme_stylebox_override("normal", badge_plate)
	head.add_child(badge)
	_title = AK.label("", 15, AK.FG)
	head.add_child(_title)
	column.add_child(AK.rect(AK.LINE, Vector2.ZERO, Vector2(CARD_WIDTH - 24, 1)))
	_text = AK.label("", 13, AK.FG)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(CARD_WIDTH - 24, 0)
	# It wraps instead: English keeps the full size (AK.fit would shrink it).
	_text.remove_meta("fit_size")
	column.add_child(_text)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(foot)
	var ok := AK.button("知道了", "blue", 12)
	ok.custom_minimum_size = Vector2(88, 30)
	ok.pressed.connect(dismiss)
	foot.add_child(ok)
	add_child(_card)
	visible = false

static func tips_on() -> bool:
	return bool(SystemScreens.settings.get("tutorial_tips", true))

static func seen(id: String) -> bool:
	return str(id) in SystemScreens.settings.get("tutorial_seen", [])

func dismiss() -> void:
	if showing.is_empty(): return
	showing = ""
	_showing_screen = ""
	visible = false
	for note in _notes: note.queue_free()
	_notes.clear()
	if _owns_modal and game.modal == "tutorial": game.close_modal()
	_owns_modal = false

## The workbench's depot column (LoadoutScreens._change) and its 制式 page's
## choices (LoadoutScreens._issue), in screen pixels.
const BENCH_DEPOT := Rect2(392, 76, 440, 608)
const BENCH_ISSUE := Rect2(392, 76, 440, 608)

## A base screen opened (GameManager.open_station): its card, the first time.
## The workbench's come in two, the depot and then the 制式 tab (a tab button,
## found when its card comes up); its 制式 page has one more the first time.
func screen_opened(kind: String) -> void:
	if kind == "contracts":
		request("dispatch_contract", DISPATCH_CONTRACT)
		request("dispatch_floors", DISPATCH_FLOORS)
		return
	if kind == "loadout":
		request("loadout_depot", BENCH_DEPOT)
		request("loadout_issue_tab", "button:制式")
		return
	if kind == "loadout_issue":
		request("loadout_issue", BENCH_ISSUE)
		return
	if kind == "route_map":
		request("route_map", ROUTE_MAP)
		return
	request("base_" + kind)

## The three departure stations ringed at once, a card beside each; the
## 后勤柜台's own first-visit card (base_insurance) is then marked seen.
func _show_departure() -> void:
	var main: Dictionary = game.base_map.station(str(DEPARTURE[0][0]))
	if main.is_empty(): return
	var more: Array = []
	for entry in DEPARTURE.slice(1):
		var station: Dictionary = game.base_map.station(str(entry[0]))
		if not station.is_empty(): more.append([(station.position as Vector3) + Vector3.UP * 0.6, entry[1], entry[2]])
	var list: Array = SystemScreens.settings.get("tutorial_seen", []).duplicate()
	if not "base_insurance" in list: list.append("base_insurance")
	SystemScreens.set_setting("tutorial_seen", list)
	show_tip("base_departure", (main.position as Vector3) + Vector3.UP * 0.6, more)

## The visible menu button reading `text` (its own text, before translation), or null.
func _button_rect(text: String) -> Variant:
	if not is_instance_valid(game.menu): return null
	for node in game.menu.find_children("*", "Button", true, false):
		var b := node as Button
		if b.is_visible_in_tree() and b.text == text: return b.get_global_rect()
	return null

## Esc on a tip: it closes (GameManager.go_back asks here first).
func go_back() -> bool:
	if showing.is_empty(): return false
	dismiss()
	return true

## An event's tip, shown as soon as it can be (once, like the rest).
## `screen`: the screen key it belongs to; it then shows only while that
## screen is the one up (SCREENS).
func request(id: String, at: Variant = null, screen := "") -> void:
	if not TIPS.has(id) or seen(id) or not tips_on() or not _active(): return
	if _queue.any(func(q): return q[0] == id): return
	_queue.append([id, at, screen])

## The screen keys up now (`screen_shown`) and the modal they were shown under.
var _screens_now: Array = []
var _screens_modal := ""
## The screen key of the card up now ("" not a screen's).
var _showing_screen := ""

## A screen was drawn: `keys` are what it is, from the whole screen to its
## page ("交易所", "交易所/资产", "交易所/资产/存款"). Deferred, so a station's
## own card (screen_opened, right after the screen is built) comes first.
static func screen(game: GameManager, keys: Array) -> void:
	if game == null or not is_instance_valid(game.tutorial_spotlight): return
	game.tutorial_spotlight.call_deferred("screen_shown", keys)

func screen_shown(keys: Array) -> void:
	if not is_instance_valid(game): return
	_screens_now = keys
	_screens_modal = game.modal
	for key in keys:
		for entry in SCREENS.get(key, []): request(str(entry[0]), entry[1], str(key))

## Whether a queued tip's screen is the one up (a tip with none: always).
func _screen_up(q: Array) -> bool:
	var key: String = q[2] if q.size() > 2 else ""
	if key.is_empty(): return true
	return not game.modal.is_empty() and game.modal == _screens_modal and key in _screens_now

func _active() -> bool:
	return is_instance_valid(game) and (forced or is_instance_valid(game.system_screens))

func _process(delta: float) -> void:
	if not _active():
		visible = false
		return
	if not showing.is_empty():
		# Its screen closed or changed: it goes with it.
		if not _showing_screen.is_empty() and not _screen_up([showing, null, _showing_screen]):
			dismiss()
			return
		# Something closed the modal under it (a test, a transition): gone too.
		if _owns_modal and game.modal != "tutorial":
			showing = ""
			visible = false
			_owns_modal = false
		return
	visible = false
	_check_left -= delta
	if _check_left > 0.0: return
	_check_left = CHECK_SECONDS
	if not tips_on() or game.transitioning: return
	# A screen's tips go with it; drawn again, it asks again.
	_queue = _queue.filter(func(q): return _screen_up(q))
	_watch_events()
	# 玩家反馈 2026-11-06: 打架时弹出提示，被敌人打死. In the field nothing comes
	# up mid-fight, nor over a screen the field keeps running under (a box's
	# window): what is queued waits until she is out of combat.
	if not hold_for_fight().is_empty(): return
	if not seen("base_departure") and game.in_base and game.modal.is_empty() and game.base_walk_active() and TutorialCard.step() <= TutorialCard.index_of("contract") \
			and (not Story.is_on() or "wake" in game.base.story.seen):
		_show_departure()
		return
	for i in range(_queue.size()):
		var q: Array = _queue[i]
		# A tip with no ring, or a screen box, goes over any screen; one round
		# a world point waits for the field.
		if q[1] == null or q[1] is Rect2 or q[1] is String or (game.simulation_active() and game.modal.is_empty()):
			_queue.remove_at(i)
			if not seen(q[0]):
				show_tip(q[0], q[1])
				_showing_screen = str(q[2]) if q.size() > 2 else ""
			return
	if game.simulation_active() and game.modal.is_empty():
		var found := first_in_sight()
		if not found.is_empty(): show_tip(found.id, found.at)

## Why a tip waits now ("" = it need not): "fight" while she has hit or been
## hit within Player.OUT_OF_COMBAT seconds, "running" while a screen is up
## that the field keeps running under. Only while the field runs: the base,
## the camp, a menu or the settlement never wait.
func hold_for_fight() -> String:
	if game.in_camp or not game.simulation_active() or not is_instance_valid(game.player): return ""
	if not game.modal.is_empty(): return "running"
	if game.player.combat_timer < Player.OUT_OF_COMBAT: return "fight"
	return ""

## What is watched rather than seen: life, the 威胁值 and the region's meter in
## the field, the first camp. Each queues its tip once.
const LOW_LIFE := 0.5
const THREAT_AT := 0.4
const FEATURE_AT := 20.0
func _watch_events() -> void:
	if game.in_base or not is_instance_valid(game.player): return
	if game.in_camp and game.modal == "camp":
		request("camp")
		return
	if not game.simulation_active(): return
	var p := game.player
	if p.hp < p.max_hp * LOW_LIFE: request("low_hp", potion_slot_rect())
	if game.threat.ratio() >= THREAT_AT: request("threat", TOP_BAR)
	for kind in ["contamination", "cold", "debt"]:
		if kind in game.shown_features() and game.feature_value(kind) >= FEATURE_AT: request(kind, TOP_BAR)

## The HUD's top strip, with the 威胁值 bar under it (Hud._draw_top_bar).
const TOP_BAR := Rect2(0, 0, 640, 47)

## The bar slot holding the first-aid flask, else the auto slot.
func potion_slot_rect() -> Rect2:
	var hud: Hud = game._hud
	if not is_instance_valid(hud): return Rect2(323, 648, 634, 58)
	var bar := Hotbar.slots()
	for i in range(bar.size()):
		if str(bar[i].action).begins_with("potion_"): return hud._config_rect(i)
	return hud._config_rect(Hotbar.AUTO)

## The station she stands at, if its tip is still to come ({id, at}).
func base_station() -> Dictionary:
	var station := game.nearby_station()
	if station.is_empty(): return {}
	var id := "base_" + str(station.kind)
	if not TIPS.has(id) or seen(id): return {}
	var at: Vector3 = station.get("position", game.player.global_position)
	return {"id": id, "at": at + Vector3.UP * 0.6}

## Every kind candidates() can name.
const SIGHT_KINDS := ["vault", "sealed", "recruit", "lost_operator", "handover", "boss", "mine", "trace", "fire", "trap", "shower",
	"event", "campfire", "extraction", "route", "device", "trader", "squad", "post", "cache", "leader", "elite", "sentinel", "patrol", "heal_orb"]

## The first tip not yet seen whose thing is on screen and near her.
func first_in_sight() -> Dictionary:
	var done := {}
	for id in SystemScreens.settings.get("tutorial_seen", []): done[str(id)] = true
	# Every kind seen: nothing on the floor could show.
	if SIGHT_KINDS.all(func(kind): return done.has(kind)): return {}
	var player_at := game.player.global_position
	for entry in candidates():
		var id: String = entry[0]
		if done.has(id): continue
		var at: Vector3 = entry[1]
		var reach := TRAP_RANGE if id == "trap" else SEE_RANGE
		var flat := at - player_at
		flat.y = 0.0
		if flat.length() > reach: continue
		var point := game.screen_point(at)
		if Rect2(Vector2(INSET, INSET), SCREEN - Vector2(INSET, INSET) * 2.0).has_point(point):
			return {"id": id, "at": at}
	return {}

## [id, world position] of every kind there is on this floor now.
func candidates() -> Array:
	var out: Array = []
	var map := game.world_map
	if not is_instance_valid(map): return out
	if is_instance_valid(map.vault_seal) and not game.vault_opened: out.append(["vault", map.vault_seal.wall_centre()])
	for node in get_tree().get_nodes_in_group("sealed_loot"):
		var chest := node as LootContainer
		if chest != null and chest.game == game and chest.sealed: out.append(["sealed", chest.global_position])
	if is_instance_valid(game.recruit_node) and game.recruit_node.visible and not game.recruit_met: out.append(["recruit", game.recruit_node.global_position])
	if is_instance_valid(game.lost_node) and game.lost_node.visible and not game.base.lost_back(game.lost_id): out.append(["lost_operator", game.lost_node.global_position + Vector3.UP * 0.6])
	if is_instance_valid(game.handover_node) and game.handover_node.visible and not game.cargo_delivered: out.append(["handover", game.handover_node.global_position])
	if is_instance_valid(game.arena):
		for node in get_tree().get_nodes_in_group("bosses"):
			var boss := node as Enemy
			if boss != null and boss.game == game and not boss._dead: out.append(["boss", boss.global_position + Vector3.UP * 1.0])
		for mine in game.arena.mines:
			if not mine.spent and not mine.armed and is_instance_valid(mine.node): out.append(["mine", (mine.node as Node3D).global_position])
	if is_instance_valid(game.trace_point) and game.trace_point.visible: out.append(["trace", game.trace_point.global_position])
	for node in get_tree().get_nodes_in_group("fire_pits"): out.append(["fire", (node as Node3D).global_position])
	for trap in game.traps:
		if is_instance_valid(trap) and not trap.spent: out.append(["trap", trap.global_position])
	if is_instance_valid(game.shower) and not game.shower.used: out.append(["shower", game.shower.global_position])
	if is_instance_valid(game.event_node) and game.event_node.visible and not game.event_done: out.append(["event", game.event_node.global_position])
	if is_instance_valid(game.rest_fire) and not game.campfire_used: out.append(["campfire", game.rest_fire.global_position])
	if game.is_extraction_floor() and is_instance_valid(map.exit_node) and map.exit_node.visible: out.append(["extraction", map.exit_node.global_position])
	for node in map.route_nodes:
		if is_instance_valid(node) and node.visible: out.append(["route", node.global_position])
	if is_instance_valid(map.buff_device_node) and map.buff_device_node.visible and game.is_buff_available(): out.append(["device", map.buff_device_node.global_position])
	if is_instance_valid(map.encounter_node) and map.encounter_node.visible and game.encounter in ["trader", "squad", "post"]:
		out.append([game.encounter, map.encounter_node.global_position])
	for node in get_tree().get_nodes_in_group("relic_caches"):
		if (node as RelicCache).game == game: out.append(["cache", (node as Node3D).global_position])
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy._dead or enemy.game != game: continue
		var mid := enemy.global_position + Vector3.UP * 0.8
		if enemy.boss: out.append(["leader", mid])
		elif enemy.elite: out.append(["elite", mid])
		if enemy.is_in_group("sentinels"): out.append(["sentinel", mid])
		if enemy.is_in_group("patrols"): out.append(["patrol", mid])
	for node in get_tree().get_nodes_in_group("heal_orbs"): out.append(["heal_orb", (node as Node3D).global_position])
	return out

## Stops the game and shows `id`'s card beside a ring round `at`: a world
## point (Vector3), a screen point (Vector2), a screen box (Rect2), or null
## for no ring and the card in the middle. `more`: further places ringed with
## it, [world point, title, text], each with a card of its own beside it.
func show_tip(id: String, at: Variant, more: Array = []) -> void:
	var list: Array = SystemScreens.settings.get("tutorial_seen", []).duplicate()
	list.append(id)
	SystemScreens.set_setting("tutorial_seen", list)
	showing = id
	_owns_modal = game.modal.is_empty()
	if _owns_modal: game.open_modal("tutorial")
	# "button:<text>": that button's rectangle on the screen now up.
	if at is String: at = _button_rect(str(at).trim_prefix("button:"))
	ring_box = at.grow(6.0) if at is Rect2 else Rect2()
	ring_at = game.screen_point(at) if at is Vector3 else (at if at is Vector2 else (ring_box.get_center() if at is Rect2 else SCREEN * 0.5))
	ring_radius = float(TIPS[id][2]) if at is Vector3 or at is Vector2 else 0.0
	_title.text = TIPS[id][0]
	_text.text = TIPS[id][1]
	if "%d" in _text.text:
		var floors: Array = FieldCatalog.EXTRACTION_FLOORS
		_text.text = TIPS[id][1] % [floors.min(), floors.max()]
	var material := _mask.material as ShaderMaterial
	material.set_shader_parameter("centre", ring_at)
	# No ring: the whole screen dims.
	material.set_shader_parameter("radius", ring_radius if at != null else -20.0)
	material.set_shader_parameter("box", Vector4(ring_box.position.x, ring_box.position.y, ring_box.size.x, ring_box.size.y))
	material.set_shader_parameter("extent", SCREEN)
	material.set_shader_parameter("dim", DIM)
	more_rings.clear()
	for note in _notes: note.queue_free()
	_notes.clear()
	for entry in more:
		var point := game.screen_point(entry[0])
		more_rings.append(point)
		var note := _note_card(str(entry[1]), str(entry[2]))
		add_child(note)
		note.reset_size()
		note.position = _beside(point, ring_radius, note.size)
		_notes.append(note)
	for k in range(2):
		var extra := Vector3(more_rings[k].x, more_rings[k].y, ring_radius) if k < more_rings.size() else Vector3.ZERO
		material.set_shader_parameter("more_a" if k == 0 else "more_b", extra)
	_card.reset_size()
	if at == null:
		_card.position = (SCREEN - _card.size) * 0.5
	elif at is Rect2 and ring_box.size.y > SCREEN.y * 0.6:
		# A tall box (a screen's column): beside it, on the side with more room.
		var x := ring_box.position.x - 18.0 - _card.size.x if ring_box.get_center().x > SCREEN.x * 0.5 else ring_box.end.x + 18.0
		_card.position = Vector2(clampf(x, 16.0, SCREEN.x - _card.size.x - 16.0), clampf(ring_box.position.y + 40.0, 16.0, SCREEN.y - _card.size.y - 16.0))
	elif at is Rect2:
		# Under a box at the top, over one at the bottom, lined up with it.
		var y := ring_box.end.y + 18.0 if ring_box.get_center().y < SCREEN.y * 0.5 else ring_box.position.y - 18.0 - _card.size.y
		var x := ring_box.get_center().x - _card.size.x * 0.5
		_card.position = Vector2(clampf(x, 16.0, SCREEN.x - _card.size.x - 16.0), clampf(y, 16.0, SCREEN.y - _card.size.y - 16.0))
	else: _card.position = _beside(ring_at, ring_radius, _card.size)
	visible = true
	_ring.queue_redraw()

## Beside a ring, on the side with more room, kept on screen.
func _beside(centre: Vector2, radius: float, card: Vector2) -> Vector2:
	var gap := radius + 24.0
	var x := centre.x + gap if centre.x < SCREEN.x * 0.5 else centre.x - gap - card.x
	var y := centre.y - card.y * 0.5
	return Vector2(clampf(x, 16.0, SCREEN.x - card.x - 16.0), clampf(y, 16.0, SCREEN.y - card.y - 16.0))

## A card with no button, for a place ringed alongside the tip's own.
func _note_card(title: String, text: String) -> PanelContainer:
	var note := PanelContainer.new()
	note.custom_minimum_size = Vector2(NOTE_WIDTH, 0)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := AK.box(AK.PLATE, AK.BLUE, 0, 12)
	plate.border_width_left = 3
	note.add_theme_stylebox_override("panel", plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	note.add_child(column)
	column.add_child(AK.label(title, 15, AK.FG))
	var body := AK.label(text, 13, AK.FG)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(NOTE_WIDTH - 24, 0)
	body.remove_meta("fit_size")
	column.add_child(body)
	return note

func _draw_ring() -> void:
	if showing.is_empty(): return
	if ring_box.size.x > 0.0:
		_ring.draw_rect(ring_box, AK.BLUE, false, 2.0)
		_ring.draw_rect(ring_box.grow(6.0), Color(AK.BLUE, 0.35), false, 1.0)
		return
	if ring_radius <= 0.0: return
	for centre in [ring_at] + more_rings:
		_ring.draw_arc(centre, ring_radius, 0.0, TAU, 64, AK.BLUE, 2.0, true)
		_ring.draw_arc(centre, ring_radius + 6.0, 0.0, TAU, 64, Color(AK.BLUE, 0.35), 1.0, true)
