class_name Councils
extends RefCounted
## 议会 (第 9 块, 用户 2026-10-11 说「照你的推荐做」, 规矩写在看板第 9 块卡片上)。
## 照三代: 五个大臣 (首相 外交、元帅 军事、管家 管理、密探头子 密谋、宗教大臣 学识), 外加心腹 (配偶, 就是已有的「配偶的本事五分之一加给国王」)。
## 每个大臣一次干一件活, 本事越高效果越好, 数字照三代 (官方百科 Council)。只做现在用得上的活; 宗教关系、改信仰、发展、文化、控制等以后几块。
## 谁能当: 你家里的男人、你的直属封臣、请来住在你宫廷的本地贵族 (宗教大臣请修士 / 祭司); 女人只当心腹 (照三代「男人主导」)。
## 有实力的封臣没进议会对你好感 -40 (照三代); 撤掉大臣 -20 记十年 (三代查不清, 我们定的)。
## 议会按「国家」记 (国王死了议会留给新国王); 玩家是封臣时按人记。电脑的国王自己挑人、派活; 电脑的封臣没有议会 (省事, 看不到)。

const SEATS := ["chancellor", "marshal", "steward", "spymaster", "chaplain"]
const SEAT_INFO := {
	"chancellor": {"name": "首相", "skill": "diplomacy", "icon": "decree"},
	"marshal": {"name": "元帅", "skill": "martial", "icon": "swords"},
	"steward": {"name": "管家", "skill": "stewardship", "icon": "coins"},
	"spymaster": {"name": "密探头子", "skill": "intrigue", "icon": "p_dagger"},
	"chaplain": {"name": "宫廷牧师", "skill": "learning", "icon": "cross"},
}
const TASKS := {
	"chancellor": ["domestic", "foreign", "integrate"],
	"marshal": ["organize", "train"],
	"steward": ["taxes"],
	"spymaster": ["disrupt", "support", "secrets"],
	"chaplain": ["fabricate"],
}
const TASK_INFO := {
	"domestic": {"name": "内政", "icon": "council", "desc": "直属封臣对你的好感 +0.5/点本事, 暴政降得快 1%/点"},
	"foreign": {"name": "外交", "icon": "rings", "desc": "每月威望 +0.05/点, 别国国王对你的好感 +0.5/点"},
	"integrate": {"name": "整合头衔", "icon": "crown", "target": "duchy",
		"desc": "你手里的公国头衔不在你王国里的, 改成你王国法理上的地 (每月 1% + 0.1%/点)"},
	"organize": {"name": "整顿军队", "icon": "helmet", "desc": "养兵的钱 -1%/点, 兵补得快 +2%/点, 守军 +2%/点"},
	"train": {"name": "训练将领", "icon": "swords", "desc": "你的兵打仗 +1%/点; 每月 0.5%/点 的机会让家里一个带兵的人军事 +1"},
	"taxes": {"name": "收税", "icon": "coins", "desc": "直辖领地的钱 +0.5%/点"},
	"disrupt": {"name": "破坏阴谋", "icon": "intrigue", "desc": "别人害你和你家里人的阴谋: 攒机会慢 5 天 + 0.5 天/点, 保密 -1/点 (更容易被发现)"},
	"support": {"name": "支持阴谋", "icon": "p_dagger", "desc": "你的阴谋攒机会快 1 天/点, 成功率 +5% + 0.5%/点"},
	"secrets": {"name": "打探秘密", "icon": "torch", "desc": "每年 5%/点 的机会查出你国家里某个人的秘密"},
	"fabricate": {"name": "编造宣称", "icon": "quill", "target": "county",
		"desc": "对挨着你国家的一块别人的地编造宣称: 每月 3% + 0.2%/点, 编好了能拿来宣战"},
}
const DEFAULT_TASK := {"chancellor": "domestic", "marshal": "organize", "steward": "taxes", "spymaster": "disrupt", "chaplain": "fabricate"}

# 数字照三代 (官方百科 Council); 三代没写的标「我们定的」
const DOMESTIC_OPINION := 0.5
const DOMESTIC_TYRANNY := 0.01
const FOREIGN_PRESTIGE := 0.05
const FOREIGN_OPINION := 0.5
const INTEGRATE_BASE := 1.0       # 我们定的 (三代没写)
const INTEGRATE_PER := 0.1
const ORGANIZE_UPKEEP := 0.01
const ORGANIZE_REFILL := 0.02
const ORGANIZE_GARRISON := 0.02
const TRAIN_DAMAGE := 0.01
const TRAIN_CHANCE := 0.005
const TAX_PER := 0.005
const SECRETS_PER_YEAR := 0.05
const DISRUPT_DAYS := 5.0
const DISRUPT_PER := 0.5
const DISRUPT_SECRECY := 1.0
const SUPPORT_DAYS := 1.0
const SUPPORT_SUCCESS := 5.0
const SUPPORT_PER := 0.5
const FABRICATE_BASE := 3.0
const FABRICATE_PER := 0.2
const POWERFUL_OPINION := -40
const FIRED_OPINION := -20         # 我们定的 (三代查不清)
const FIRED_YEARS := 10
const LOCALS := 3                  # 每个位子多列几个能请来的本地人

var w: World
var off := false     # 测试用: 关掉议会 (量前几块的数字时, 不让大臣的加成掺进来)
var councils := {}   # 议会的 key ("r:国家" 或 "p:人") -> {位子: {who, task, progress, target}}


func _init(p_world: World) -> void:
	w = p_world


# ---- 查 ----

## 这个人的议会记在哪里: 国王按国家, 玩家是封臣按人; 别人没有议会 (空的)
func key_of(p: Person) -> String:
	if p == null:
		return ""
	if p.realm != "" and w.realms.has(p.realm):
		return "r:" + p.realm
	if p.id == w.player and w.is_landed(p):
		return "p:" + p.id
	return ""


func owner_of(key: String) -> Person:
	if key.begins_with("r:"):
		var rid := key.substr(2)
		return w.ruler(rid) if w.realms.has(rid) and w.realms[rid].has("ruler_id") else null
	return w.people.get(key.substr(2))


func council_of(p: Person) -> Dictionary:
	return councils.get(key_of(p), {})


func seat_name(p: Person, seat: String) -> String:
	if seat == "chaplain" and p != null and Marriage.faith_of(p.culture) != "christian":
		return "祭司"
	return SEAT_INFO[seat].name


func member(p: Person, seat: String) -> Person:
	var s: Dictionary = council_of(p).get(seat, {})
	return w.people.get(s.get("who", "")) if not s.is_empty() else null


## 干这件活的大臣的本事 (没人干这件活是 0)。owner 可以是 null
func task_skill(owner: Person, task: String) -> int:
	if owner == null or off:
		return 0
	var c := council_of(owner)
	if c.is_empty():
		return 0
	for seat in SEATS:
		var s: Dictionary = c.get(seat, {})
		if s.get("task", "") == task and s.get("who", "") != "" and w.people.has(s.who):
			return w.people[s.who].skill(SEAT_INFO[seat].skill, w.today)
	return 0


## 管着这个人的议会主人 (阴谋保护用): 有议会的人自己; 国王家里没领地的人归国王
func protector(t: Person) -> Person:
	if key_of(t) != "":
		return t
	if not w.is_landed(t):
		var rid := w.kin_realm(t)
		if rid != "" and w.realms.has(rid):
			return w.ruler(rid)
	return null


## 有实力的封臣: 直属封臣里兵最多的几个 (国王有王国头衔 5 个, 小国王 4 个, 封臣 3 个; 照三代 王 5、公 4、伯 3)
func powerful_vassals(owner: Person) -> Array:
	var vs: Array = w.vassals_of(owner).filter(func(v: Person) -> bool: return v.alive and not v.female and v.adult(w.today))
	var memo := {}
	vs.sort_custom(func(a: Person, b: Person) -> bool:
		var la: int = w.income(a, memo).levy
		var lb: int = w.income(b, memo).levy
		return la > lb if la != lb else a.id < b.id)
	var n := 5 if w.rank_bonus(owner) > 0 else (4 if owner.realm != "" else 3)
	return vs.slice(0, n)


func seat_of(owner: Person, q: Person) -> String:
	var c := council_of(owner)
	for seat in c:
		if c[seat].get("who", "") == q.id:
			return seat
	return ""


# ---- 谁能当 ----

## 是不是这个人宫廷里的人: 家里的男人 (没领地, 或者是他的封臣)、他的直属封臣、请来住在他宫廷的人
func at_court(owner: Person, q: Person) -> bool:
	var key := key_of(owner)
	if q.court != "" and q.court == key:
		return true
	if w.liege_of(q) == owner:
		return true
	if q.realm == "" and q.house != "" and q.house == owner.house and not w.is_landed(q):
		var rid := w.kin_realm(q)
		return rid == "" or rid == w.realm_of_person(owner)
	return false


## 能不能当这个位子: 空 = 能
func problem(owner: Person, seat: String, q: Person) -> String:
	if q == owner:
		return "不能是你自己"
	if not q.alive:
		return "已经去世了"
	if q.female:
		return "女人只能当心腹 (配偶)"
	if not q.adult(w.today):
		return "还没成年"
	if q.prisoner_of != "":
		return "关在大牢里"
	if seat == "chaplain" and Marriage.faith_of(q.culture) != Marriage.faith_of(owner.culture):
		return "跟你不是一个信仰"
	if q.realm != "":
		return "是别国的国王"
	if not at_court(owner, q):
		return "住在别人的宫廷里" if q.court != "" else "不是你宫廷里的人"
	var other := seat_of(owner, q)
	if other != "" and other != seat:
		return "已经是你的%s了" % seat_name(owner, other)
	return ""


## 能当这个位子的人 (已经在议会别的位子上的不算)
func candidates(owner: Person, seat: String) -> Array:
	var out := []
	var seen := {}
	var pool: Array = w.house_members(owner.house) if owner.house != "" else []
	pool = pool + w.vassals_of(owner)
	for q in w.living.values():
		if q.court != "" and q.court == key_of(owner):
			pool.append(q)
	for q in pool:
		if seen.has(q.id):
			continue
		seen[q.id] = true
		if problem(owner, seat, q) == "" and seat_of(owner, q) == "":
			out.append(q)
	return out


## 请来的本地人 (还没放进世界, 选上了才放): 这个位子的本事好一些; 宗教大臣是修士 (基督徒) 或者祭司
func make_local(owner: Person, seat: String, r: RandomNumberGenerator) -> Person:
	var q := Person.new()
	q.id = w._new_person_id()
	q.female = false
	q.culture = owner.culture
	q.name = w.random_name(r, q.culture, false)
	q.birth_day = w.today - r.randi_range(22, 50) * GameDate.YEAR_DAYS - r.randi_range(0, 364)
	q.birth_estimated = true
	q.dna = Portrait.random_dna(r, q.culture)
	q.traits = Traits.random_personality(r) + Traits.random_congenital(r)
	q.education = {"skill": SEAT_INFO[seat].skill, "level": r.randi_range(1, 3)}
	w._random_skills(r, q)
	var sk: String = SEAT_INFO[seat].skill
	q.base_skills[sk] = maxi(int(q.base_skills.get(sk, 0)), r.randi_range(5, 11))
	q.homeland = owner.homeland
	if seat == "chaplain":
		q.clergy = Marriage.faith_of(q.culture) == "christian"
		q.rank = ""
	else:
		q.rank = "noble"
	return q


## 本地人选上了: 放进世界, 住在你的宫廷 (修士没有家族, 别人是一个新的本地贵族家族)
func _bring_in(owner: Person, q: Person) -> void:
	if w.people.has(q.id):
		return
	if not q.clergy:
		q.house = w._new_house(q, "本地的贵族家族")
	q.court = key_of(owner)
	w._register(q)


# ---- 任命、撤掉、派活 ----

func appoint(owner: Person, seat: String, q: Person, day: int) -> Dictionary:
	var key := key_of(owner)
	if key == "":
		return {"ok": false, "text": "没有领地, 没有议会"}
	if not w.people.has(q.id):
		q.court = key  # 请来的本地人: 先算住进了你的宫廷
	var why := problem(owner, seat, q)
	if why != "":
		return {"ok": false, "text": why}
	_bring_in(owner, q)
	if not councils.has(key):
		councils[key] = {}
	var c: Dictionary = councils[key]
	var old: Dictionary = c.get(seat, {})
	if old.get("who", "") == q.id:
		return {"ok": true, "text": "%s已经是你的%s了" % [q.name, seat_name(owner, seat)]}
	if old.get("who", "") != "" and w.people.has(old.who):
		_fired(owner, w.people[old.who], day)
	var task: String = old.get("task", DEFAULT_TASK[seat])
	c[seat] = {"who": q.id, "task": task, "progress": float(old.get("progress", 0.0)), "target": old.get("target", "")}
	refresh_opinions()
	return {"ok": true, "text": "%s当了你的%s" % [q.name, seat_name(owner, seat)]}


func fire(owner: Person, seat: String, day: int) -> Dictionary:
	var c := council_of(owner)
	var s: Dictionary = c.get(seat, {})
	if s.get("who", "") == "" or not w.people.has(s.who):
		return {"ok": false, "text": "这个位子本来就空着"}
	var q: Person = w.people[s.who]
	_fired(owner, q, day)
	s.who = ""
	refresh_opinions()
	return {"ok": true, "text": "撤掉了%s (他对你好感 %d, 记 %d 年)" % [q.name, FIRED_OPINION, FIRED_YEARS]}


func _fired(owner: Person, q: Person, day: int) -> void:
	q.remember(owner.id, "把我撤出了议会", FIRED_OPINION, day + FIRED_YEARS * GameDate.YEAR_DAYS)


## 派活 (换活进度从头算; 照三代)
func set_task(owner: Person, seat: String, task: String, target := "") -> Dictionary:
	var key := key_of(owner)
	if not councils.has(key):
		councils[key] = {}
	var c: Dictionary = councils[key]
	if not c.has(seat):
		c[seat] = {"who": "", "task": DEFAULT_TASK[seat], "progress": 0.0, "target": ""}
	var s: Dictionary = c[seat]
	if not TASKS[seat].has(task):
		return {"ok": false, "text": "这个位子干不了这件活"}
	var why := task_problem(owner, task)
	if why != "":
		return {"ok": false, "text": why}
	if TASK_INFO[task].has("target"):
		var opts := target_options(owner, task)
		if target == "":
			target = s.target if s.task == task and opts.has(s.target) else (best_target(owner, task) if not opts.is_empty() else "")
		elif not opts.has(target):
			return {"ok": false, "text": "这个目标不行"}
	if s.task != task or s.target != target:
		s.progress = 0.0
	s.task = task
	s.target = target
	refresh_opinions()
	return {"ok": true, "text": "%s改去%s%s" % [seat_name(owner, seat), TASK_INFO[task].name, (": " + target_name(task, target)) if target != "" else ""]}


## 这件活现在干不了的原因 (空 = 能干)
func task_problem(owner: Person, task: String) -> String:
	match task:
		"integrate":
			if owner.realm == "" or w.realms[owner.realm].get("kingdoms", []).is_empty():
				return "要先有王国头衔 (左下角「决议」里建立)"
			if target_options(owner, task).is_empty():
				return "你手里的公国头衔都已经在你的王国里了"
		"fabricate":
			if target_options(owner, task).is_empty():
				return "挨着你的地都有宣称了, 或者没有挨着的别人的地"
		"foreign":
			if owner.realm == "":
				return "只有独立的国王能办外交"
	return ""


func target_options(owner: Person, task: String) -> Array:
	match task:
		"integrate":
			if owner.realm == "":
				return []
			var r: Dictionary = w.realms[owner.realm]
			var ks: Array = r.get("kingdoms", [])
			if ks.is_empty():
				return []
			return r.titles.filter(func(d: String) -> bool: return not ks.has(w.duchies[d].kingdom))
		"fabricate":
			var rid := w.realm_of_person(owner)
			if rid == "":
				return []
			var mine: Array = w.counties_of(rid) if owner.realm != "" else w.lands_of(owner)
			var seen := {}
			var out := []
			for c in mine:
				for n in c.neighbors:
					if seen.has(n):
						continue
					seen[n] = true
					var o: Dictionary = w.by_id[n]
					if o.holder != rid and w.realms.has(o.holder) and not owner.claims.has("county:" + n) and not owner.weak_claims.has("county:" + n):
						out.append(n)
			out.sort()
			return out
	return []


func target_name(task: String, target: String) -> String:
	if target == "":
		return ""
	if task == "integrate":
		return w.title_name("duchy", target)
	return w.by_id[target].name if w.by_id.has(target) else target


## 自动挑目标: 编造宣称挑最弱的邻居 (法理上本来就能要的地往后放); 整合挑第一个
func best_target(owner: Person, task: String) -> String:
	var opts := target_options(owner, task)
	if opts.is_empty():
		return ""
	if task != "fabricate":
		return opts[0]
	var mine_duchies := w.realm_duchies(w.realm_of_person(owner))
	var best := ""
	var best_v := INF
	for id in opts:
		var c: Dictionary = w.by_id[id]
		var v: float = w.warfare.strength(w.ruler(c.holder))
		if mine_duchies.has(c.duchy):
			v += 100000.0  # 法理上能要的不用编
		if w.allies(w.realm_of_person(owner)).has(c.holder):
			v += 50000.0
		if v < best_v:
			best_v = v
			best = id
	return best


## 进度每月涨多少 (%)
func monthly_progress(task: String, skill: int) -> float:
	match task:
		"integrate":
			return INTEGRATE_BASE + INTEGRATE_PER * skill
		"fabricate":
			return FABRICATE_BASE + FABRICATE_PER * skill
	return 0.0


# ---- 每个月 ----

func monthly(day: int, events: Array) -> void:
	if off:
		return
	_sync()
	for key in councils.keys():
		var owner := owner_of(key)
		if owner == null or not owner.alive or (key.begins_with("p:") and key_of(owner) != key):
			councils.erase(key)
			continue
		var c: Dictionary = councils[key]
		var mine := owner.id == w.player
		for seat in SEATS:
			var s: Dictionary = c.get(seat, {})
			if s.is_empty() or s.get("who", "") == "":
				continue
			var q: Person = w.people.get(s.who)
			var why := problem(owner, seat, q) if q != null else "不在了"
			if why != "":
				s.who = ""
				if mine and q != null:
					events.append({"type": "council_left", "person": q.id, "seat": seat_name(owner, seat), "why": why, "day": day})
		if not mine:
			_ai_fill(owner, day)
			_ai_tasks(owner)
		_work(owner, c, day, events)
	refresh_opinions()


## 每个国家都有议会 (新国家开一个, 电脑填人); 玩家是封臣也有
func _sync() -> void:
	for rid in w.realm_order:
		if w.realms.has(rid) and not councils.has("r:" + rid):
			councils["r:" + rid] = {}
	var me := w.me()
	if me != null and me.alive:
		var k := key_of(me)
		if k != "" and not councils.has(k):
			councils[k] = {}
			_ai_fill(me, w.today)
			_ai_tasks(me)


## 干活: 外交涨威望; 整合、编造宣称涨进度; 打探秘密、训练将领掷机会
func _work(owner: Person, c: Dictionary, day: int, events: Array) -> void:
	for seat in SEATS:
		var s: Dictionary = c.get(seat, {})
		if s.is_empty() or s.get("who", "") == "" or not w.people.has(s.who):
			continue
		var q: Person = w.people[s.who]
		var sk := q.skill(SEAT_INFO[seat].skill, day)
		match s.task:
			"foreign":
				if owner.realm != "":
					owner.prestige += FOREIGN_PRESTIGE * sk
			"integrate", "fabricate":
				if s.task == "fabricate" and owner.id != w.player and ai_has_spare_claim(owner):
					continue
				if s.target == "" or not target_options(owner, s.task).has(s.target):
					s.target = best_target(owner, s.task)
					s.progress = 0.0
				if s.target == "":
					continue
				s.progress = float(s.progress) + monthly_progress(s.task, sk)
				if float(s.progress) >= 100.0:
					_finish(owner, s, day, events)
			"secrets":
				if w.rng.randf() < SECRETS_PER_YEAR * sk / 12.0:
					_find_secret(owner, day, events)
			"train":
				if w.rng.randf() < TRAIN_CHANCE * sk:
					var cands: Array = w.warfare.commander_candidates(owner).filter(func(x: Person) -> bool: return x != owner)
					if not cands.is_empty():
						var g: Person = cands[w.rng.randi_range(0, cands.size() - 1)]
						g.base_skills.martial = int(g.base_skills.get("martial", 0)) + 1
						if owner.id == w.player:
							events.append({"type": "council_done", "text": "元帅%s把%s练得更会带兵了 (军事 +1)" % [q.name, g.name], "day": day})


func _finish(owner: Person, s: Dictionary, day: int, events: Array) -> void:
	var text := ""
	match s.task:
		"fabricate":
			owner.claims.append("county:" + s.target)
			text = "%s编好了对%s的宣称, 可以拿来宣战了" % [w.people[s.who].name, w.by_id[s.target].name]
		"integrate":
			var r: Dictionary = w.realms[owner.realm]
			w._set_dejure(s.target, r.kingdoms[0])
			text = "%s整合进了%s" % [w.title_name("duchy", s.target), w.title_name("kingdom", r.kingdoms[0])]
	s.progress = 0.0
	s.target = best_target(owner, s.task)
	if owner.id == w.player:
		events.append({"type": "council_done", "text": text, "day": day, "map": s.task == "integrate"})


## 打探秘密: 你国家里某个人的一个你还不知道的秘密
func _find_secret(owner: Person, day: int, events: Array) -> void:
	var rid := w.realm_of_person(owner)
	var found := []
	for p in w.living.values():
		if p == owner or p.secrets.is_empty() or w.home_realm(p) != rid:
			continue
		for sec in p.secrets:
			if not sec.exposed and not sec.known.has(owner.id):
				found.append([p, sec])
	if found.is_empty():
		return
	var pick: Array = found[w.rng.randi_range(0, found.size() - 1)]
	pick[1].known.append(owner.id)
	if owner.id == w.player:
		events.append({"type": "council_done", "text": "密探头子查出了一个秘密: %s" % w.intrigue.secret_text(pick[0], pick[1]), "day": day})


# ---- 电脑 ----

## 电脑填空位子: 本事最好的, 有实力的封臣优先 (不然他们不高兴); 一个人都没有就请一个本地人
func _ai_fill(owner: Person, day: int, r: RandomNumberGenerator = null) -> void:
	var key := key_of(owner)
	if key == "":
		return
	if not councils.has(key):
		councils[key] = {}
	var c: Dictionary = councils[key]
	var powerful := powerful_vassals(owner)
	for seat in SEATS:
		if not c.has(seat):
			c[seat] = {"who": "", "task": DEFAULT_TASK[seat], "progress": 0.0, "target": ""}
		if c[seat].who != "":
			continue
		var best: Person = null
		var best_v := -INF
		for q in candidates(owner, seat):
			var v := float(q.skill(SEAT_INFO[seat].skill, day)) + (8.0 if powerful.has(q) else 0.0)
			if v > best_v:
				best_v = v
				best = q
		if best == null:
			best = make_local(owner, seat, r if r != null else w.rng)
			_bring_in(owner, best)
		c[seat].who = best.id


## 电脑派活: 能整合就整合; 自己在搞暗杀就支持阴谋; 宗教大臣编造宣称
func _ai_tasks(owner: Person) -> void:
	var c := council_of(owner)
	if c.is_empty():
		return
	var ch: Dictionary = c.get("chancellor", {})
	if not ch.is_empty():
		var want := "integrate" if task_problem(owner, "integrate") == "" else "domestic"
		if ch.task != want:
			set_task(owner, "chancellor", want)
	var sp: Dictionary = c.get("spymaster", {})
	if not sp.is_empty():
		var want := "support" if not w.intrigue.scheme_of(owner.id, "murder").is_empty() else "disrupt"
		if sp.task != want:
			set_task(owner, "spymaster", want)
	var cp: Dictionary = c.get("chaplain", {})
	if not cp.is_empty() and cp.task == "fabricate" and cp.target == "":
		cp.target = best_target(owner, "fabricate")


## 电脑手里还有没用上的、编造来的领地宣称 (对别国的地): 有就先不编新的 (不然小国被吞得太快; 我们定的)
func ai_has_spare_claim(owner: Person) -> bool:
	var rid := w.realm_of_person(owner)
	for cl in owner.claims:
		if cl.begins_with("county:") and w.by_id.has(cl.substr(7)) and w.by_id[cl.substr(7)].holder != rid:
			return true
	return false


## 开局: 每个国家的议会照电脑的办法填好 (玩家选了人以后可以换)。r: 开局专用的随机数 (不动 World.rng)
func setup(r: RandomNumberGenerator) -> void:
	_sync()
	for key in councils:
		var owner := owner_of(key)
		if owner != null:
			_ai_fill(owner, w.today, r)
			_ai_tasks(owner)
	refresh_opinions()


# ---- 好感 (首相的内政、外交; 有实力的封臣没进议会) ----

func refresh_opinions() -> void:
	for p in w.living.values():
		if not p.council_opinion.is_empty():
			p.council_opinion = {}
	if off:
		return
	for key in councils:
		var owner := owner_of(key)
		if owner == null or not owner.alive:
			continue
		var dom := task_skill(owner, "domestic")
		if dom > 0:
			for v in w.vassals_of(owner):
				_add_opinion(v, owner, "首相在办内政", int(DOMESTIC_OPINION * dom))
		var fo := task_skill(owner, "foreign")
		if fo > 0 and owner.realm != "":
			for rid in w.realm_order:
				if rid != owner.realm and w.realms.has(rid):
					_add_opinion(w.ruler(rid), owner, "首相在办外交", int(FOREIGN_OPINION * fo))
		var seated := {}
		for seat in councils[key]:
			seated[councils[key][seat].get("who", "")] = true
		for v in powerful_vassals(owner):
			if not seated.has(v.id):
				_add_opinion(v, owner, "我有实力, 却没让我进议会", POWERFUL_OPINION)


func _add_opinion(p: Person, about: Person, text: String, value: int) -> void:
	if value == 0:
		return
	if not p.council_opinion.has(about.id):
		p.council_opinion[about.id] = []
	p.council_opinion[about.id].append([text, value])


# ---- 存档 ----

func to_save() -> Dictionary:
	return councils.duplicate(true)


func from_save(d: Dictionary) -> void:
	councils = {}
	for key in d:
		var c := {}
		for seat in d[key]:
			var s: Dictionary = d[key][seat]
			c[seat] = {"who": String(s.get("who", "")), "task": String(s.get("task", DEFAULT_TASK.get(seat, ""))),
					"progress": float(s.get("progress", 0.0)), "target": String(s.get("target", ""))}
		councils[key] = c
	refresh_opinions()
