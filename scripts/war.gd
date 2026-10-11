class_name War
extends RefCounted
## 打仗的规矩和数字 (第 6 块, 用户 2026-10-11 说「都按推荐」)。玩法照三代 (查了官方百科 Warfare / Casus belli / Army / Alliance / Titles),
## 数字按我们的小地图缩小 (宣战花的威望大约是三代的四分之一), 试玩再调。打仗的过程 (军队、打仗、围城、战争分数) 在 Warfare。

# ---- 宣战理由 (三代叫 casus belli) ----
const CB_NAMES := {"claim": "宣称", "de_jure": "法理", "conquest": "征服", "holy": "圣战", "independence": "独立", "punitive": "讨伐"}
const CB_ICONS := {"claim": "decree", "de_jure": "coronet", "conquest": "swords", "holy": "cross", "independence": "banner", "punitive": "torch"}
const CB_DESCS := {
	"claim": "对这块地 (或者这个王位) 有继承权的人去要回来。赢了归他; 输了宣称就没了",
	"de_jure": "这块地本来属于你手里的公国, 去要回来。赢了归你; 输了赔钱",
	"conquest": "信北欧旧神的维京人可以直接抢别人的地。赢了归你; 平局丢威望; 输了赔钱",
	"holy": "信仰不同, 打圣战抢他的地。赢了归你; 输了赔钱",
	"independence": "封臣起兵, 不再听国王的。赢了自立为王; 输了被国王关起来",
	"punitive": "带兵去教训他。赢了他赔钱、你涨威望; 输了你赔钱",
}

# 威望: 开局国王 100、封臣 25 (以前开局都是 0, 宣战要花)
const START_PRESTIGE_KING := 100.0
const START_PRESTIGE_VASSAL := 25.0
# 宣战花多少威望 (三代的四分之一左右)
const COST_CLAIM_COUNTY := 25.0      # 自己的宣称; 替家里人 ×2.5, 替别人 ×5 (照三代)
const COST_CLAIM_REALM := 50.0
const CLAIM_FAMILY := 2.5
const CLAIM_OTHER := 5.0
const COST_DE_JURE := 25.0           # 每块地
const COST_CONQUEST := 10.0          # 一块地: 10 + 自己每块地 2.5 (三代按自己国家大小算)
const COST_CONQUEST_PER_OWN := 2.5
const COST_CONQUEST_DUCHY := 25.0    # 一个公国: 25 + 自己每块地 5
const COST_CONQUEST_DUCHY_PER_OWN := 5.0
const COST_HOLY := 25.0              # 一块地 (三代花虔诚; 第 13 块有了虔诚再改)
const COST_HOLY_DUCHY := 50.0
const COST_INDEPENDENCE := 50.0
const COST_PUNITIVE := 25.0
const TRUCE_YEARS := 5
const TRUCE_BREAK := 100.0           # 停战期间硬要打: 多丢的威望 (大家对你好感 -20, 三年)

# ---- 军队 ----
const UPKEEP_PER_1000 := 3.0         # 征着的兵每 1000 人每月多少金币 (照三代)
const LEVY_REFILL := 0.1             # 解散以后每月补回来多少 (占满员的几成)
const GATHER_DAYS := 3               # 集合: 3 天 + 国家每 3 块地多 1 天 (最多 15 天), 集合时打仗吃亏
const LAND_KM := 25.0                # 每天走多少公里
const SEA_KM := 70.0                 # 坐船每天多少公里
const EMBARK_DAYS := 2               # 上船下船
const SEA_MAX_KM := 260.0            # 一次最远坐多远的船 (靠海的地之间)
const SHIP_GOLD := 0.5               # 坐船每 100 人多少金币
const ATTRITION_MOVE := 0.05         # 在敌人的地上往前走一块 (不挨着自己人的地) 掉 5%, 最少 100 人
const ATTRITION_SIEGE := 0.01        # 围城每月掉 1%

# ---- 打仗 (照三代: 摆阵 2 天, 对砍; 头 12 天就垮的一方全军覆没; 赢的追着砍逃兵) ----
const DAMAGE := 10.0                 # 农民兵的伤害和韧性都是 10 (照三代)
const TOUGHNESS := 10.0
const DAMAGE_SCALE := 0.03           # 每点伤害每天打掉 0.03 的韧性
const ADV_BONUS := 0.05              # 优势每多一点, 伤害多 5% (照三代)
const MANEUVER_DAYS := 2
const EARLY_DAYS := 12
const KILLED_SHARE := 0.3            # 打掉的兵里死了的; 剩下的是逃散的 (打完回来)
const PURSUIT := 1.0 / 3.0           # 输的一方逃散的兵被追着砍死的
const BREAK_AT := 0.2                # 剩下不到开打时的两成就垮了
const ADV_GATHERING := -10
const ADV_DEBT := -10
const ADV_SEA := -30                 # 从船上下来就开打
const ADV_LIEGE := 5                 # 国王亲自带兵
const ROLL_DAYS := 3                 # 每 3 天带兵的人掷一次骰子 (1–10)
const CAPTURE := 0.1                 # 输了的带兵的人被抓的机会 (武力高的少)
const DIE_LOSE := 0.08               # 输了的带兵的人战死的机会 (武力高的少)
const DIE_WIN := 0.02
const BATTLE_PRESTIGE := 5.0         # 打赢一仗涨的威望

# ---- 围城 ----
const FORT_BASE := 1                 # 每块地城墙至少 1 级; 都城 +1; 罗马人留下城墙的城、岩石上的要塞再 +1 (data 的 forts)
const GARRISON_PER_FORT := 100       # 每级城墙守军 100 人
const GARRISON_REFILL := 0.1         # 没被围的时候守军每月补一成
const SIEGE_BASE := 100.0            # 围下来要多少进度: 100 + 每级城墙 75 (照三代)
const SIEGE_PER_FORT := 75.0
const SIEGE_DAILY := 1.0             # 每天 1 点, 比守军多出来的兵每 200 人多 0.05 (照三代)
const SIEGE_PER_200 := 0.05
const SIEGE_EVENT_DAYS := 20         # 每 20 天出一件事: 没动静 / 有人逃出城 (+5) / 断粮 / 闹病
const CAPTURE_IN_CAPITAL := 0.35     # 打下都城时城里的人被抓的机会 (密谋、武力高的少; 照三代)

# ---- 战争分数 (-100 到 100) ----
const BATTLE_CAP := 50.0             # 打仗最多算 50 分 (照三代)
const CAPITAL_SCORE := 10.0
const LEADER_CAPTURED := 100.0
const HEIR_CAPTURED := 50.0
const TARGET_TICK := 1.0             # 要的地全占着: 每月 +1; 打了一年还一块没占下: 防守方每月 +1
const TARGET_GRACE := 12
const WIN_PRESTIGE := 50.0
const DEFEND_PRESTIGE := 25.0
const WHITE_CONQUEST := 20.0         # 征服平局: 进攻方丢的威望
const LOSER_PAY_MONTHS := 6          # 输了赔钱: 半年的收入 (最少 20)
const DECLINE_ATTACK := -20          # 盟友不来帮你进攻: 他对你 -20 (五年); 不来帮你防守: -40 (十年)
const DECLINE_DEFEND := -40


static func cb_name(cb: String) -> String:
	return CB_NAMES.get(cb, cb)


## 进攻方输了要赔多少钱
static func loser_pays(monthly: float) -> int:
	return maxi(20, int(monthly * LOSER_PAY_MONTHS))


## 花钱求和要多少钱 (史料: 被打的一方给维京大军钱换和平): 50 + 自己 8 个月的收入, 被打得越惨要得越多
static func peace_price(defender_monthly: float, score: float) -> int:
	return int((50.0 + defender_monthly * 8.0) * (1.0 + maxf(0.0, score) / 100.0))
