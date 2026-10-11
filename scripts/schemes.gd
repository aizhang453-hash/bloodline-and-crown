class_name Schemes
extends RefCounted
## 阴谋的规矩和数字 (第 7 块, 用户 2026-10-11 定的): 玩法照三代 (官方百科 Schemes / Hooks / Interactions), 数字我们定, 试玩再调。
## 过程 (每天走、每月走、电脑搞阴谋) 在 Intrigue。勾引 (情人、私生子) 第 12 块再做; 打探秘密等第 9 块的密探头子 (用户选的「照三代」)。

const NAMES := {"murder": "暗杀", "sway": "拉拢"}
const ICONS := {"murder": "p_dagger", "sway": "decree"}

# ---- 暗杀 (照三代的「敌对阴谋」) ----
const OWN_POTENTIAL_PER := 1.5    # 成功率上限: 你的密谋每点 1.5%, 自己最多给 30% (照三代), 剩下的靠内应
const OWN_POTENTIAL_MAX := 30.0
const MAX_SUCCESS := 95.0         # 最多 95% (照三代)
const AT_WAR := -50.0             # 正在跟他打仗 (照三代)
const VS_HIGHER := -10.0          # 对身份比你高的人下手
const TARGET_INTRIGUE := 1.0      # 他的密谋每点 -1% (最多 -20)
const PHASE_DAYS := 30.0          # 多久攒一次「机会」: 30 天 - 你的密谋每点半天, 最少 15 天
const PHASE_PER_SKILL := 0.5
const PHASE_MIN := 15.0
const READY := 5                  # 攒够 5 次机会就能动手 (照三代)
const BONUS := [[20, 20.0], [15, 10.0], [10, 5.0]]   # 攒到 10、15、20 次: 成功率 +5、+10、+20 (照三代)
const MAX_ADVANTAGES := 20
const SECRECY_BASE := 40.0        # 保密: 40 + 你的密谋 ×2 - 他的密谋, 5%–95%
const SECRECY_MIN := 5.0
const SECRECY_MAX := 95.0
const GRACE_DAYS := 180           # 开头 6 个月不会走漏 (照三代)
const MAX_BREACHES := 5           # 走漏 5 次就失败 (照三代)
const BREACH_SUCCESS := -5.0      # 走漏一次成功率 -5
const REVEAL_ON_BREACH := 0.2     # 走漏时让对方知道是谁在害他的机会
const STRESS := {"compassionate": 80.0, "honest": 40.0, "just": 40.0}   # 开始暗杀时涨的压力 (照三代)

# ---- 内应 (照三代的「同谋」) ----
const MAX_AGENTS := 5
const AGENT_SKILL_MAX := 25.0     # 本事最多给 25 (密谋、武力里高的那个 ×0.75 + 低的 ×0.25)
const CLOSE := {"spouse": ["他的妻子", 30.0], "husband": ["她的丈夫", 30.0], "close": ["近亲", 10.0], "extended": ["同一个家族", 5.0], "vassal": ["他的封臣", 2.0]}
const BRIBE := 25                 # 收买一个内应多少金币 (肯不肯 +30)
const BRIBE_ACCEPT := 30

# ---- 拉拢 (照三代的「个人阴谋」) ----
const SWAY_DAYS := 90.0           # 90 天 - 你的外交每点 2 天, 最少 30 天
const SWAY_PER_SKILL := 2.0
const SWAY_MIN := 30.0
const SWAY_BASE := 60.0           # 成功率: 60 + 外交 ×2 (对身份比你高的 -10), 10%–95%
const SWAY_GAIN := 25             # 成了: 他对你好感 +25 (十年)
const SWAY_FAIL := -10            # 没成: -10 (五年), 以后不能再拉拢他 (照三代)
const SWAY_YEARS := 10

# ---- 秘密和把柄 ----
const SECRET_NAMES := {"murder": "杀过人", "attempted_murder": "谋杀未遂"}
const EXPOSE_PRESTIGE := {"murder": 50.0, "attempted_murder": 25.0}   # 被揭发丢的威望
const HOOK_COOLDOWN_YEARS := 5    # 强把柄五年能用一次 (照三代)
const HOOK_MARRIAGE := {true: 200, false: 100}   # 说亲: 强把柄 +200 (直接答应)、弱把柄 +100 (照三代)
const HOOK_ARREST_WEAK := 0.3     # 关大牢: 弱把柄 +30% (强把柄一定抓到)
const BLACKMAIL_ACCEPT := 0.75    # 电脑被勒索时肯给把柄的机会 (不给就被揭发)


static func scheme_name(kind: String) -> String:
	return NAMES.get(kind, kind)


static func secret_name(type: String) -> String:
	return SECRET_NAMES.get(type, type)
