class_name Feudal
extends RefCounted
## 封臣的规矩 (第 5 块, 用户 2026-10-10 选的「折中」: 玩法照三代, 叫法和几处规矩照史实)。数字是我们定的, 试玩再调。
##   叫法看封臣在哪个国家: 英格兰「郡长」(国王任命, 撤换不算暴政)、爱尔兰「小国王」(交贡品出兵, 收回暴政翻倍)、
##   维京人「雅尔」、威尔士 / 康沃尔 / 斯特拉斯克莱德 / 阿尔巴先叫「领主」(867 年怎么叫查不到)。规矩都相当于三代的伯爵, 世袭。
##   国王多出来的公国头衔可以封给家里人当「副王」(史实: 威塞克斯王子当过肯特国王), 相当于三代的公爵。

const GOLD_PER_COUNTY := 1.0      # 每块领地每月出的钱 (第 15 块「领地建设」以前都一样)
const LEVY_PER_COUNTY := 200      # 每块领地能征的兵
const CONTRACTS := ["少交", "照常", "多交"]
const TAX_SHARE := [0.10, 0.20, 0.30]
const LEVY_SHARE := [0.15, 0.25, 0.35]
const BASE_DOMAIN := 2            # 亲自管的领地上限: 2 块 + 管理每 5 点多 1 块
const TYRANNY := 20.0             # 没理由收回、没理由关人、让封臣多交
const TYRANNY_EXECUTE := 10.0     # 处死
const TYRANNY_DECAY := 0.25       # 每月降多少 (三代也是 0.25)
const GIFT := 25.0                # 送一次礼多少金币
const CRIME_YEARS := 10           # 「抗命」这类罪记几年


## 封臣的叫法 (看他的国家)
static func kind(w: World, realm_id: String) -> String:
	if not w.realms.has(realm_id):
		return "领主"
	var culture: String = w.realms[realm_id].culture
	if culture == "anglo_saxon":
		return "郡长"
	if culture == "gaelic" and w.realm_kingdom(realm_id) == "ireland":
		return "小国王"
	if culture in ["norse", "norse_gael"]:
		return "雅尔"
	return "领主"


static func kind_desc(k: String) -> String:
	match k:
		"郡长":
			return "郡长: 国王任命的地方长官, 带当地的兵、跟主教一起审案。郡长的位子父子相传, 但国王撤换郡长不算暴政"
		"小国王":
			return "小国王: 向上面的国王交贡品、出兵, 自己的地上面的国王管不着。收回他的地暴政翻倍"
		"雅尔":
			return "雅尔: 北欧国王派去管一块地方的人"
		"副王":
			return "副王: 国王把一个公国封给家里人管, 那里的领地和封臣都归他"
	return "领主: 管一块领地的贵族"


## 亲自管的领地上限
static func domain_limit(p: Person, day: int) -> int:
	return BASE_DOMAIN + p.skill("stewardship", day) / 5


## 收回这个人的领地算不算暴政、算多少 (有理由的不算)
static func revoke_tyranny(w: World, target: Person, day: int) -> float:
	if target.prisoner_of != "" or has_crime(target, day):
		return 0.0
	var k := kind(w, target.liege_realm)
	if k == "郡长":
		return 0.0
	return TYRANNY * (2.0 if k == "小国王" else 1.0)


## 有没有正当理由 (犯过罪还没过期)
static func has_crime(p: Person, day: int) -> bool:
	for c in p.crimes:
		if int(p.crimes[c]) > day:
			return true
	return false


static func crime_text(p: Person, day: int) -> String:
	var list := []
	for c in p.crimes:
		if int(p.crimes[c]) > day:
			list.append("%s (到 %d 年)" % [c, GameDate.from_day(int(p.crimes[c]))[0]])
	return "、".join(list)


## 抓人能不能抓到: 一半 + 你和他密谋本事的差 (每点 3%), 最少 10%, 最多 95%
static func arrest_chance(jailer: Person, target: Person, day: int) -> float:
	return clampf(0.5 + (jailer.skill("intrigue", day) - target.skill("intrigue", day)) * 0.03, 0.1, 0.95)


## 关着的人每个月逃跑的机会 (软禁比地牢容易跑; 密谋好的容易跑)
static func escape_chance(p: Person, day: int) -> float:
	var base := 0.005 if p.dungeon else 0.01
	return clampf(base * (1.0 + p.skill("intrigue", day) / 10.0), 0.002, 0.05)


## 赎金: 30 金币 + 他半年的收入
static func ransom(w: World, p: Person) -> int:
	return 30 + int(w.income(p).gold * 6.0)
