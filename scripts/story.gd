class_name StoryEvents
extends RefCounted
## 随机事件和压力崩溃 (第 8 块, 用户 2026-10-11 看了单子说可以)。照三代: 正中弹窗、几个选项, 选了违背性格的涨压力;
## 平均一年一件 (玩家家里), 同一件事过好些年才会再出; 照史料来的事件到了那年那月、在那一带才出, 只出一次, 带「历史背景」小提示
## (学社区模组 VIET 事件; 用户同意只放在照史料来的事件上)。压力涨过 100 / 200 / 300 崩溃 (一年最多一次; 一直降不下来五年后再崩溃一次),
## 玩家弹窗选, 电脑自动选。
## 一个事件: {id, cat, weight, cooldown 年, once, window [从哪天, 到哪天], months [几月才出], when(c), title, text(c), face (c 里哪个人),
##   options: [{label, tip(c), stress {性格: 压力}, do(c) -> 结果}], history}。c 是这一次的情形: {w, me, day, 还有挑出来的人的 id, events}

const MONTHLY := 1.0 / 12.0     # 每个月出一件的机会 (平均一年一件)
const BREAK_YEARS := 5          # 五年最多崩溃一次 (照三代)
const BREAK_RELIEF := [0, 60.0, 100.0, 150.0]   # 第几档崩溃, 选了一个毛病降多少压力

var w: World
var fired := {}                 # 事件 id -> 上次哪天出的
var last_win := {}              # 你的将领最近打赢的一仗 {commander, day}
var last_norse_win := {}        # 最近打赢的维京首领 {enemy, day}
static var _defs: Array = []


func _init(p_world: World) -> void:
	w = p_world


# ---- 每个月 ----

func monthly(day: int, events: Array) -> void:
	_check_breaks(day, events)
	var me := w.me()
	if me == null or not me.alive or not me.adult(day) or me.prisoner_of != "":
		return
	var dated := []
	var pool := []
	for def in defs():
		if not _ready(def, day):
			continue
		var c := {"w": w, "me": me, "day": day, "events": []}
		if def.has("months") and not def.months.has(int(GameDate.from_day(day)[1])):
			continue
		if not def.when.call(c):
			continue
		(dated if def.has("window") else pool).append([def, c])
	var pick: Array = []
	if not dated.is_empty():
		pick = dated[0]
	elif not pool.is_empty() and w.rng.randf() < MONTHLY:
		var total := 0
		for x in pool:
			total += int(x[0].weight)
		var r := w.rng.randi_range(1, total)
		for x in pool:
			r -= int(x[0].weight)
			if r <= 0:
				pick = x
				break
	if pick.is_empty():
		return
	fired[pick[0].id] = day
	events.append({"type": "story", "story": build(pick[0], pick[1]), "day": day})


func _ready(def: Dictionary, day: int) -> bool:
	if def.has("window") and (day < int(def.window[0]) or day > int(def.window[1])):
		return false
	if not fired.has(def.id):
		return true
	if def.get("once", false):
		return false
	return day - int(fired[def.id]) >= int(def.get("cooldown", 10)) * GameDate.YEAR_DAYS


## 把事件做成弹窗要的样子
func build(def: Dictionary, c: Dictionary) -> Dictionary:
	var opts := []
	for o in def.options:
		if o.has("show") and not o.show.call(c):
			continue
		opts.append(o)
	return {"id": def.id, "title": def.title, "text": def.text.call(c), "face": c.get(def.get("face", ""), ""), "options": opts,
			"history": def.get("history", ""), "ctx": c}


func label_of(s: Dictionary, i: int) -> String:
	var o: Dictionary = s.options[i]
	return o.label.call(s.ctx) if o.label is Callable else o.label


## 这个办法要花多少钱 (不花钱是 0)
func cost_of(s: Dictionary, i: int) -> int:
	var g: Variant = s.options[i].get("gold", 0)
	return g.call(s.ctx) if g is Callable else int(g)


## 钱够不够选这个办法 (照三代: 钱不够的办法是灰的)
func can_choose(s: Dictionary, i: int) -> bool:
	var me: Person = s.ctx.me
	return cost_of(s, i) <= 0 or me.gold >= cost_of(s, i)


## 第一个能选的办法 (电脑、程序里直接关窗口时用)
func first_ok(s: Dictionary) -> int:
	for i in s.options.size():
		if can_choose(s, i):
			return i
	return s.options.size() - 1


## 选项的说明: 后果, 再加上违背 (或者合) 你性格的压力
func tip_of(s: Dictionary, i: int) -> String:
	var o: Dictionary = s.options[i]
	var me: Person = s.ctx.me
	var lines := [o.tip.call(s.ctx) if o.has("tip") else ""]
	if not can_choose(s, i):
		lines.append("钱不够: 要 %d 金币, 你只有 %d" % [cost_of(s, i), int(me.gold)])
	for t in o.get("stress", {}):
		if me.has_trait(t):
			var v: float = o.stress[t]
			lines.append("你是「%s」的人: 压力 %+d" % [Traits.get_trait(t).name, int(v)])
	return "\n".join(lines.filter(func(x: String) -> bool: return x != ""))


## 选了第 i 个: 先算压力, 再照选项办; 返回结果的话
func choose(s: Dictionary, i: int) -> String:
	var o: Dictionary = s.options[i]
	var me: Person = s.ctx.me
	for t in o.get("stress", {}):
		if me.has_trait(t):
			me.add_stress(float(o.stress[t]))
	return o.do.call(s.ctx)


# ---- 压力崩溃 (照三代) ----

func _check_breaks(day: int, events: Array) -> void:
	for q in w.living.values():
		var p: Person = q
		if not p.alive:
			continue
		var lv := p.stress_level()
		if lv < p.break_level:
			p.break_level = lv  # 压力降下来了, 以后再涨过这一档还会崩溃
		if lv == 0 or not p.adult(day):
			continue
		var since := day - p.last_break
		var new_level := lv > p.break_level and since >= GameDate.YEAR_DAYS
		if not new_level and since < BREAK_YEARS * GameDate.YEAR_DAYS:
			continue
		p.break_level = lv
		p.last_break = day
		var s := mental_break(p, lv, day)
		if p.id == w.player:
			events.append({"type": "story", "story": s, "day": day})
		else:
			var i := 0
			if lv == 3:
				var r := w.rng.randf()
				for k in s.options.size():
					var kind: String = s.options[k].get("kind", "")
					if (r < 0.05 and kind == "death") or (r >= 0.05 and r < 0.2 and kind == "abdicate"):
						i = k
			var ev: Array = s.ctx.events
			var said := choose(s, i)
			events.append({"type": "mental_break", "person": p.id, "level": lv, "kind": s.options[i].get("kind", ""), "text": said, "day": day})
			events.append_array(ev)


## 崩溃的事件: 第 1 档两个排解压力的毛病挑一个 (或者硬扛); 第 2 档还可能变得忧郁、专断、古怪; 第 3 档暴躁、疯癫、忧郁, 或者让位、寻死
func mental_break(p: Person, lv: int, day: int) -> Dictionary:
	var c := {"w": w, "me": p, "day": day, "events": [], "who": p.id}
	var opts := []
	var coping := []
	for t in Traits.data().coping:
		if not p.has_trait(t.id):
			coping.insert(w.rng.randi_range(0, coping.size()), t.id)  # 随机排一排 (用游戏的随机数, 读档后接着一样)
	match lv:
		1:
			for t in coping.slice(0, 2):
				opts.append(_trait_option(t, BREAK_RELIEF[1]))
		2:
			if not coping.is_empty():
				opts.append(_trait_option(coping[0], BREAK_RELIEF[2]))
			var pool := ["melancholic", "arbitrary", "eccentric"].filter(func(t: String) -> bool: return not p.has_trait(t))
			if not pool.is_empty():
				opts.append(_trait_option(pool[w.rng.randi_range(0, pool.size() - 1)], BREAK_RELIEF[2]))
		3:
			var pool := ["wrathful", "lunatic", "melancholic"].filter(func(t: String) -> bool: return not p.has_trait(t))
			if not pool.is_empty():
				opts.append(_trait_option(pool[w.rng.randi_range(0, pool.size() - 1)], BREAK_RELIEF[3]))
			if w.is_landed(p):
				opts.append({"kind": "abdicate", "label": "撑不住了, 让位给继承人", "tip": func(_c: Dictionary) -> String:
						return "所有头衔照继承法传给继承人, 你接着玩继承人; 他丢 100 威望, 压力 -200",
						"do": func(cc: Dictionary) -> String:
							var me: Person = cc.me
							me.add_stress(-200.0)
							cc.w.abdicate(me, cc.day, cc.events)
							return "%s让位了" % me.name})
			opts.append({"kind": "death", "label": "活不下去了", "tip": func(_c: Dictionary) -> String: return "他会死",
					"do": func(cc: Dictionary) -> String:
						var me: Person = cc.me
						cc.w.kill(me, cc.day, cc.events, "自尽身亡")
						return "%s自尽身亡" % me.name})
	opts.append({"kind": "endure", "label": "咬牙撑下去", "tip": func(_c: Dictionary) -> String: return "什么毛病也不染, 可压力还会再涨 %d" % (20 * lv),
			"do": func(cc: Dictionary) -> String:
				var me: Person = cc.me
				me.add_stress(20.0 * lv)
				return "%s咬着牙撑了下来" % me.name})
	var texts := ["", "%s这些日子心里乱糟糟的: 夜里睡不着, 白天对谁都没好脸色。总得找个法子让自己喘口气。",
			"%s快撑不住了: 一闭眼就是烦心事, 手发抖, 饭也吃不下。身边的人都看出来不对劲。",
			"%s彻底垮了: 整夜整夜地盯着黑暗, 有时候自言自语, 有时候大哭大叫。再这样下去, 人就完了。"]
	return {"id": "break_%d" % lv, "title": ["", "压力太大了", "快撑不住了", "崩溃了"][lv], "text": texts[lv] % p.name, "face": p.id,
			"options": opts, "history": "", "ctx": c}


## 「染上某个特点」的选项 (排解压力的毛病, 或者忧郁、专断这些)
func _trait_option(t: String, relief: float) -> Dictionary:
	var info := Traits.get_trait(t)
	var label := ("靠「%s」撑过去" if info.kind == "coping" else "变得「%s」") % info.name
	return {"kind": "trait", "label": label, "tip": func(_c: Dictionary) -> String:
			return "染上「%s」: %s · 压力 -%d%s" % [info.name, info.desc, int(relief), ("\n(每个排解压力的毛病让压力降得快 20%, 还带一个解压的决议)" if info.kind == "coping" else "")],
			"do": func(cc: Dictionary) -> String:
				var me: Person = cc.me
				add_trait(me, t)
				me.add_stress(-relief)
				return "%s染上了「%s」" % [me.name, info.name]}


## 加一个特点: 性格类的 (专断、古怪、暴躁) 去掉相反的, 不然换掉一个旧性格 (照三代: 崩溃改性格时去掉一个原来的)
static func add_trait(p: Person, t: String) -> void:
	if p.has_trait(t):
		return
	var info := Traits.get_trait(t)
	if info.get("kind", "") == "personality":
		var mine := p.personality()
		var drop := ""
		for o in mine:
			if Traits.opposite(t, o):
				drop = o
		if drop == "" and mine.size() >= 3:
			drop = mine[0]
		if drop != "":
			p.traits.erase(drop)
	p.traits.append(t)


# ---- 帮手 ----

static func _y(years: int) -> int:
	return years * GameDate.YEAR_DAYS


static func _mem(target: Person, who: Person, text: String, value: int, years: int, day: int) -> void:
	target.remember(who.id, text, value, day + _y(years), true)


static func _cond(p: Person, text: String, health: float, months: int, day: int) -> void:
	p.conditions.append({"text": text, "health": health, "until": day + months * 30})


static func _boon(p: Person, text: String, gold: float, months: int, day: int) -> void:
	p.boons.append({"text": text, "gold": gold, "until": day + months * 30})


static func _kids(w2: World, p: Person, lo: int, hi: int, day: int) -> Array:
	return w2.children_of(p).filter(func(k: Person) -> bool: return k.alive and k.age(day) >= lo and k.age(day) <= hi)


static func _p(c: Dictionary, key: String) -> Person:
	return c.w.people[c[key]]


static func _he(p: Person) -> String:
	return "她" if p.female else "他"


static func _christian(p: Person) -> bool:
	return Marriage.faith_of(p.culture) == "christian"


## 你的封臣和住在你那里的大人里挑一个 (不是你自己)
static func _court_man(c: Dictionary, key: String) -> bool:
	var me: Person = c.me
	var w2: World = c.w
	var list: Array = w2.vassals_of(me)
	if list.is_empty():
		for q in w2.house_members(me.house):
			if q != me and q.adult(c.day) and q.prisoner_of == "":
				list.append(q)
	if list.is_empty():
		return false
	c[key] = list[w2.rng.randi_range(0, list.size() - 1)].id
	return true


static func _window(y1: int, m1: int, y2: int, m2: int) -> Array:
	return [GameDate.to_day(y1, m1, 1), GameDate.to_day(y2, m2, 28)]


# ---- 事件 (第一批 31 个) ----

static func defs() -> Array:
	if not _defs.is_empty():
		return _defs
	_defs = [_kids_fight(), _tutor_praise(), _child_fever(), _neglected_spouse(), _brothers_quarrel(), _parent_convent(), _heir_lowborn(),
		_border_dispute(), _vassal_loan(), _drunk_insult(), _wandering_poet(), _goldsmith(), _talk_kingship(),
		_bad_harvest(), _bandits(), _market(), _bridge(), _hunting_fall(), _winter_cough(),
		_general_reward(), _agent_wavers(), _captive_plea(),
		_eclipse_878(), _comet_891(), _cuthbert(), _strange_sails(), _harsh_winter(), _learn_latin(), _gospel_book(), _blot(), _baptism()]
	return _defs


# 1 孩子打架
static func _kids_fight() -> Dictionary:
	return {"id": "kids_fight", "cat": "家里", "weight": 10, "cooldown": 6, "face": "a", "title": "孩子打架",
		"when": func(c: Dictionary) -> bool:
			var ks := _kids(c.w, c.me, 4, 15, c.day)
			if ks.size() < 2:
				return false
			ks.sort_custom(func(x: Person, y: Person) -> bool: return x.birth_day < y.birth_day)
			c.a = ks[0].id
			c.b = ks[1].id
			return true,
		"text": func(c: Dictionary) -> String:
			return "%s和%s在院子里扭打成一团: 一个鼻子流血, 一个袖子扯破了。仆人把两个孩子拉到你面前。" % [_p(c, "a").name, _p(c, "b").name],
		"options": [
			{"label": func(c: Dictionary) -> String: return "罚%s: 大的该让着小的" % _p(c, "a").name,
				"tip": func(c: Dictionary) -> String: return "%s对你好感 -10, %s +5" % [_p(c, "a").name, _p(c, "b").name],
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "a"), c.me, "罚了我", -10, 5, c.day)
					_mem(_p(c, "b"), c.me, "替我做主", 5, 5, c.day)
					return "你罚了%s, %s噘着嘴走了, %s偷偷在笑。" % [_p(c, "a").name, _he(_p(c, "a")), _p(c, "b").name]},
			{"label": func(c: Dictionary) -> String: return "罚%s: 小的不该先动手" % _p(c, "b").name,
				"tip": func(c: Dictionary) -> String: return "%s对你好感 -10, %s +5" % [_p(c, "b").name, _p(c, "a").name],
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "b"), c.me, "罚了我", -10, 5, c.day)
					_mem(_p(c, "a"), c.me, "替我做主", 5, 5, c.day)
					return "你罚了%s。" % _p(c, "b").name},
			{"label": "由他们去, 孩子打打架长得结实", "stress": {"just": 10},
				"tip": func(c: Dictionary) -> String: return "两个孩子对你好感 +5; 小的那个可能越来越淘气",
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "a"), c.me, "没罚我", 5, 5, c.day)
					_mem(_p(c, "b"), c.me, "没罚我", 5, 5, c.day)
					var b := _p(c, "b")
					if c.w.rng.randf() < 0.4 and b.childhood() != "" and b.childhood() != "rowdy":
						b.traits.erase(b.childhood())
						b.traits.append("rowdy")
						return "%s从此越来越淘气了。" % b.name
					return "两个孩子很快又玩到一起去了。"},
		]}


# 2 老师报喜
static func _tutor_praise() -> Dictionary:
	return {"id": "tutor_praise", "cat": "家里", "weight": 8, "cooldown": 6, "face": "kid", "title": "老师报喜",
		"when": func(c: Dictionary) -> bool:
			for k in _kids(c.w, c.me, 6, 15, c.day):
				if k.guardian != "" and c.w.people.has(k.guardian) and c.w.people[k.guardian].alive and k.focus != "":
					c.kid = k.id
					c.teacher = k.guardian
					return true
			return false,
		"text": func(c: Dictionary) -> String:
			var k := _p(c, "kid")
			return "老师%s来报: %s学%s学得飞快, 是块好料子。要不要多花些钱, 给%s添些书和更好的师傅?" % [_p(c, "teacher").name, k.name, Traits.skill_info(k.focus).name, _he(k)],
		"options": [
			{"label": "多花 25 金币", "gold": 25, "stress": {"greedy": 10},
				"tip": func(c: Dictionary) -> String: return "金钱 -25; %s的教育更有可能出色" % _p(c, "kid").name,
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 25.0
					_p(c, "kid").edu_points += 2.0
					return "%s学得更起劲了。" % _p(c, "kid").name},
			{"label": "不必, 照常学", "stress": {"generous": 5},
				"tip": func(_c: Dictionary) -> String: return "什么都不变",
				"do": func(_c: Dictionary) -> String: return "老师点点头走了。"},
		]}


# 3 孩子发高烧
static func _child_fever() -> Dictionary:
	return {"id": "child_fever", "cat": "家里", "weight": 6, "cooldown": 8, "face": "kid", "title": "孩子发高烧",
		"when": func(c: Dictionary) -> bool:
			var ks := _kids(c.w, c.me, 0, 15, c.day)
			if ks.is_empty():
				return false
			c.kid = ks[c.w.rng.randi_range(0, ks.size() - 1)].id
			return true,
		"text": func(c: Dictionary) -> String:
			return "%s发起了高烧, 烧得说胡话, 一连两天都没退。" % _p(c, "kid").name,
		"options": [
			{"label": "请修士来祈祷", "stress": {"zealous": -10, "cynical": 10},
				"tip": func(_c: Dictionary) -> String: return "七成会好起来; 不然大病一场 (健康 -1.5, 一年)",
				"do": func(c: Dictionary) -> String: return _fever(c, 0.7)},
			{"label": "请懂草药的老妇", "gold": 5, "tip": func(_c: Dictionary) -> String: return "金钱 -5; 八成五会好起来",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 5.0
					return _fever(c, 0.85)},
			{"label": "听天由命", "stress": {"compassionate": 15},
				"tip": func(_c: Dictionary) -> String: return "一半会好起来",
				"do": func(c: Dictionary) -> String: return _fever(c, 0.5)},
		]}


static func _fever(c: Dictionary, chance: float) -> String:
	var k := _p(c, "kid")
	if c.w.rng.randf() < chance:
		return "第三天早上, %s的烧退了。" % k.name
	_cond(k, "大病了一场", -1.5, 12, c.day)
	return "%s的烧是退了, 可人瘦了一大圈, 得养好久。" % k.name


# 4 冷落了妻子 (丈夫)
static func _neglected_spouse() -> Dictionary:
	return {"id": "neglected_spouse", "cat": "家里", "weight": 8, "cooldown": 6, "face": "sp", "title": "冷落了家里人",
		"when": func(c: Dictionary) -> bool:
			var me: Person = c.me
			var sp := me.living_spouse()
			if sp == null:
				return false
			c.sp = sp.id
			return true,
		"text": func(c: Dictionary) -> String:
			var sp := _p(c, "sp")
			return "%s拦住你说: 你成天忙这忙那, 已经好久没好好跟%s说过话了。" % [sp.name, "她" if sp.female else "他"],
		"options": [
			{"label": func(c: Dictionary) -> String: return "放下手里的事, 陪陪%s" % _he(_p(c, "sp")), "stress": {"shy": 10, "gregarious": -10},
				"tip": func(c: Dictionary) -> String: return "%s对你好感 +15 (五年); 你也松了口气, 压力 -10" % _p(c, "sp").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "sp"), c.me, "陪了我", 15, 5, c.day)
					var me: Person = c.me
					me.add_stress(-10.0)
					return "那天晚上你们聊到很晚。"},
			{"label": "送件礼物", "gold": 15, "tip": func(c: Dictionary) -> String: return "金钱 -15; %s对你好感 +10" % _p(c, "sp").name,
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 15.0
					_mem(_p(c, "sp"), c.me, "送了我礼物", 10, 5, c.day)
					return "%s收下了一枚银胸针。" % _p(c, "sp").name},
			{"label": "没空理这些", "stress": {"compassionate": 10},
				"tip": func(c: Dictionary) -> String: return "%s对你好感 -15 (五年)" % _p(c, "sp").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "sp"), c.me, "冷落我", -15, 5, c.day)
					return "%s转身走了。" % _p(c, "sp").name},
		]}


# 5 兄弟争家产
static func _brothers_quarrel() -> Dictionary:
	return {"id": "brothers_quarrel", "cat": "家里", "weight": 6, "cooldown": 10, "face": "a", "title": "兄弟争家产",
		"when": func(c: Dictionary) -> bool:
			var me: Person = c.me
			var bs: Array = c.w.siblings_of(me).filter(func(q: Person) -> bool: return q.alive and not q.female and q.adult(c.day))
			if bs.size() < 2:
				return false
			c.a = bs[0].id
			c.b = bs[1].id
			return true,
		"text": func(c: Dictionary) -> String:
			return "你的兄弟%s和%s为了父亲留下的马群和银器吵得不可开交, 都来找你评理。" % [_p(c, "a").name, _p(c, "b").name],
		"options": [
			{"label": func(c: Dictionary) -> String: return "偏向%s" % _p(c, "a").name,
				"tip": func(c: Dictionary) -> String: return "%s好感 +15, %s -20" % [_p(c, "a").name, _p(c, "b").name],
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "a"), c.me, "替我说话", 15, 10, c.day)
					_mem(_p(c, "b"), c.me, "偏心", -20, 10, c.day)
					return "%s气得摔门而去。" % _p(c, "b").name},
			{"label": func(c: Dictionary) -> String: return "偏向%s" % _p(c, "b").name,
				"tip": func(c: Dictionary) -> String: return "%s好感 +15, %s -20" % [_p(c, "b").name, _p(c, "a").name],
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "b"), c.me, "替我说话", 15, 10, c.day)
					_mem(_p(c, "a"), c.me, "偏心", -20, 10, c.day)
					return "%s气得摔门而去。" % _p(c, "a").name},
			{"label": "各打五十大板", "stress": {"just": -10, "arbitrary": 10},
				"tip": func(_c: Dictionary) -> String: return "两个人好感都 -5, 可谁也挑不出你的错",
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "a"), c.me, "各打五十大板", -5, 5, c.day)
					_mem(_p(c, "b"), c.me, "各打五十大板", -5, 5, c.day)
					return "东西一人一半, 两个人都不太高兴。"},
		]}


# 6 老母亲想进修道院
static func _parent_convent() -> Dictionary:
	return {"id": "parent_convent", "cat": "家里", "weight": 4, "once": true, "face": "par", "title": "想进修道院",
		"when": func(c: Dictionary) -> bool:
			var me: Person = c.me
			if not _christian(me):
				return false
			for id in [me.mother, me.father]:
				if c.w.people.has(id):
					var par: Person = c.w.people[id]
					if par.alive and par.age(c.day) >= 55 and not par.married():
						c.par = par.id
						return true
			return false,
		"text": func(c: Dictionary) -> String:
			var par := _p(c, "par")
			return "%s拉着你的手说: 我老了, 想进修道院去, 安安静静地祈祷, 度过剩下的日子。" % par.name,
		"options": [
			{"label": "答应", "stress": {"zealous": -10},
				"tip": func(c: Dictionary) -> String: return "%s对你好感 +20; 威望 +10 (家里出了虔诚的人)" % _p(c, "par").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "par"), c.me, "成全了我", 20, 20, c.day)
					var me: Person = c.me
					me.prestige += 10.0
					return "你给修道院捐了一块地, 送%s过去。" % _p(c, "par").name},
			{"label": "舍不得, 留下来", "stress": {"compassionate": 5},
				"tip": func(c: Dictionary) -> String: return "%s对你好感 -10" % _p(c, "par").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "par"), c.me, "不让我去修道院", -10, 10, c.day)
					return "%s叹了口气, 没再提这件事。" % _p(c, "par").name},
		]}


# 7 继承人看上了身份低的姑娘
static func _heir_lowborn() -> Dictionary:
	return {"id": "heir_lowborn", "cat": "家里", "weight": 5, "cooldown": 10, "face": "son", "title": "门不当户不对",
		"when": func(c: Dictionary) -> bool:
			for k in _kids(c.w, c.me, 16, 30, c.day):
				if not k.female and not k.married() and k.betrothed == "" and c.w.is_player_court(k):
					c.son = k.id
					return true
			return false,
		"text": func(c: Dictionary) -> String:
			return "%s看上了附近一个自由农的女儿, 说非她不娶。手下人都在偷偷议论。" % _p(c, "son").name,
		"options": [
			{"label": "由他去, 娶就娶吧", "stress": {"arrogant": 15, "humble": -10},
				"tip": func(c: Dictionary) -> String: return "%s娶她, 对你好感 +20; 你的威望 -15 (门不当户不对)" % _p(c, "son").name,
				"do": func(c: Dictionary) -> String:
					var son := _p(c, "son")
					var me: Person = c.me
					var bride: Person = c.w.make_noble(son.culture, true, maxi(16, son.age(c.day) - 2), c.day)
					bride.rank = ""
					bride.homeland = son.homeland
					c.w._register(bride)
					c.w.marry(son, bride, c.day, c.events)
					_mem(son, me, "成全了我的婚事", 20, 20, c.day)
					me.prestige -= 15.0
					return "%s娶了%s。" % [son.name, bride.name]},
			{"label": "训斥他: 婚姻是两个家族的事", "stress": {"compassionate": 5},
				"tip": func(c: Dictionary) -> String: return "%s对你好感 -20" % _p(c, "son").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "son"), c.me, "拆散了我们", -20, 10, c.day)
					return "%s红着眼睛走了。" % _p(c, "son").name},
		]}


# 8 封臣争地界
static func _border_dispute() -> Dictionary:
	return {"id": "border_dispute", "cat": "宫廷", "weight": 8, "cooldown": 5, "face": "a", "title": "争地界",
		"when": func(c: Dictionary) -> bool:
			var vs: Array = c.w.vassals_of(c.me)
			if vs.size() < 2:
				return false
			var i: int = c.w.rng.randi_range(0, vs.size() - 1)
			c.a = vs[i].id
			c.b = vs[(i + 1) % vs.size()].id
			return true,
		"text": func(c: Dictionary) -> String:
			return "%s和%s为了两家中间的一片林子争了好几年, 今天一起来求你裁决。" % [_p(c, "a").name, _p(c, "b").name],
		"options": [
			{"label": func(c: Dictionary) -> String: return "判给%s" % _p(c, "a").name, "stress": {"just": 5},
				"tip": func(c: Dictionary) -> String: return "%s好感 +20, %s -20" % [_p(c, "a").name, _p(c, "b").name],
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "a"), c.me, "把林子判给我", 20, 10, c.day)
					_mem(_p(c, "b"), c.me, "把林子判给别人", -20, 10, c.day)
					return "林子归了%s。" % _p(c, "a").name},
			{"label": func(c: Dictionary) -> String: return "判给%s" % _p(c, "b").name, "stress": {"just": 5},
				"tip": func(c: Dictionary) -> String: return "%s好感 +20, %s -20" % [_p(c, "b").name, _p(c, "a").name],
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "b"), c.me, "把林子判给我", 20, 10, c.day)
					_mem(_p(c, "a"), c.me, "把林子判给别人", -20, 10, c.day)
					return "林子归了%s。" % _p(c, "b").name},
			{"label": "一人一半", "stress": {"just": -10, "arbitrary": 10},
				"tip": func(_c: Dictionary) -> String: return "两个人好感都 -5",
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "a"), c.me, "只给我一半", -5, 5, c.day)
					_mem(_p(c, "b"), c.me, "只给我一半", -5, 5, c.day)
					return "林子从中间劈开, 一家一半。"},
		]}


# 9 封臣遭灾来借钱
static func _vassal_loan() -> Dictionary:
	return {"id": "vassal_loan", "cat": "宫廷", "weight": 7, "cooldown": 5, "face": "v", "title": "来借钱",
		"when": func(c: Dictionary) -> bool:
			var vs: Array = c.w.vassals_of(c.me)
			if vs.is_empty():
				return false
			c.v = vs[c.w.rng.randi_range(0, vs.size() - 1)].id
			return true,
		"text": func(c: Dictionary) -> String:
			return "%s的庄子遭了水灾, 房子冲倒了一片。%s来求你借点钱渡过难关。" % [_p(c, "v").name, _he(_p(c, "v"))],
		"options": [
			{"label": "借他 30 金币", "gold": 30, "stress": {"greedy": 10, "generous": -10},
				"tip": func(c: Dictionary) -> String: return "金钱 -30; %s好感 +20 (十年)" % _p(c, "v").name,
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 30.0
					_p(c, "v").gold += 30.0
					_mem(_p(c, "v"), me, "借钱给我渡过难关", 20, 10, c.day)
					return "%s千恩万谢地走了。" % _p(c, "v").name},
			{"label": "免他一年该交的钱", "stress": {"greedy": 5},
				"tip": func(c: Dictionary) -> String: return "一年里少收 %.1f 金币一个月; %s好感 +25" % [c.w.income(_p(c, "v")).paid_gold, _p(c, "v").name],
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					_boon(me, "免了%s一年的税" % _p(c, "v").name, -c.w.income(_p(c, "v")).paid_gold, 12, c.day)
					_mem(_p(c, "v"), me, "免了我一年的税", 25, 10, c.day)
					return "%s感激得说不出话来。" % _p(c, "v").name},
			{"label": "不借", "stress": {"generous": 10},
				"tip": func(c: Dictionary) -> String: return "%s好感 -10" % _p(c, "v").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "v"), c.me, "不肯借钱给我", -10, 5, c.day)
					return "%s空着手回去了。" % _p(c, "v").name},
		]}


# 10 宴会上有人喝醉了
static func _drunk_insult() -> Dictionary:
	return {"id": "drunk_insult", "cat": "宫廷", "weight": 7, "cooldown": 5, "face": "who", "title": "喝醉了",
		"when": func(c: Dictionary) -> bool: return _court_man(c, "who"),
		"text": func(c: Dictionary) -> String:
			return "宴席上, %s喝得满脸通红, 当着众人的面笑你「管家务不如管马厩」。大厅里一下子安静了。" % _p(c, "who").name,
		"options": [
			{"label": "一笑了之", "stress": {"wrathful": 15, "calm": -10},
				"tip": func(c: Dictionary) -> String: return "%s好感 +10; 威望 -5" % _p(c, "who").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "who"), c.me, "没跟我计较", 10, 5, c.day)
					var me: Person = c.me
					me.prestige -= 5.0
					return "你哈哈一笑, 大家又喝了起来。"},
			{"label": "当众训斥他", "stress": {"calm": 5},
				"tip": func(c: Dictionary) -> String: return "%s好感 -15; 威望 +5" % _p(c, "who").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "who"), c.me, "当众训斥我", -15, 5, c.day)
					var me: Person = c.me
					me.prestige += 5.0
					return "%s酒醒了一半, 灰溜溜地坐下了。" % _p(c, "who").name},
			{"label": "不动声色, 记在心里", "stress": {"forgiving": 10, "vengeful": -10},
				"tip": func(c: Dictionary) -> String: return "你对%s好感 -20 (他不知道)" % _p(c, "who").name,
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.remember(c.who, "宴会上羞辱我", -20, c.day + _y(10))
					return "你笑着举杯, 心里记下了这笔账。"},
		]}


# 11 吟游诗人
static func _wandering_poet() -> Dictionary:
	return {"id": "wandering_poet", "cat": "宫廷", "weight": 6, "cooldown": 6, "title": "吟游诗人",
		"when": func(c: Dictionary) -> bool: return c.w.is_landed(c.me),
		"text": func(_c: Dictionary) -> String:
			return "一个背着竖琴的诗人来到大厅, 说要为你唱一首新编的歌, 歌颂你的祖先和你的勇武。",
		"options": [
			{"label": "赏他 10 金币", "gold": 10, "stress": {"greedy": 10},
				"tip": func(_c: Dictionary) -> String: return "金钱 -10; 威望 +15 (歌会传遍四方)",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 10.0
					me.prestige += 15.0
					return "诗人唱得满堂喝彩, 第二天就带着你的名字上路了。"},
			{"label": "没兴趣, 打发他走", "stress": {"gregarious": 5},
				"tip": func(_c: Dictionary) -> String: return "威望 -5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige -= 5.0
					return "诗人悻悻地走了, 听说在别处编了首歌笑你小气。"},
		]}


# 12 外乡的金匠
static func _goldsmith() -> Dictionary:
	return {"id": "goldsmith", "cat": "宫廷", "weight": 5, "cooldown": 12, "title": "外乡来的金匠",
		"when": func(c: Dictionary) -> bool: return c.me.realm != "",
		"text": func(_c: Dictionary) -> String:
			return "一个手艺很好的金匠从海那边来, 想在你的都城落脚开铺子, 只求你给块地方、免几年的税。",
		"options": [
			{"label": "收留他 (花 20 金币安顿)", "gold": 20, "tip": func(_c: Dictionary) -> String: return "金钱 -20; 以后五年每月多 1.5 金币",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 20.0
					_boon(me, "金匠的铺子", 1.5, 60, c.day)
					return "金匠的铺子开张了, 来买胸针的人络绎不绝。"},
			{"label": "不收外乡人", "tip": func(_c: Dictionary) -> String: return "什么都不变",
				"do": func(_c: Dictionary) -> String: return "金匠去了别的国家。"},
		]}


# 13 跟廷臣闲谈「什么是好国王」(学 VIET 的闲聊)
static func _talk_kingship() -> Dictionary:
	return {"id": "talk_kingship", "cat": "宫廷", "weight": 6, "cooldown": 8, "face": "who", "title": "闲谈",
		"when": func(c: Dictionary) -> bool: return _court_man(c, "who"),
		"text": func(c: Dictionary) -> String:
			return "晚饭后, %s跟你坐在火炉边闲聊, 忽然问: 「依您看, 什么样的人才算好国王?」" % _p(c, "who").name,
		"options": [
			{"label": "公正的人", "stress": {"just": -10, "arbitrary": 10},
				"tip": func(c: Dictionary) -> String: return "%s好感 +5" % _p(c, "who").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "who"), c.me, "跟我谈得来", 5, 5, c.day)
					return "%s点头说: 「这话该刻在门上。」" % _p(c, "who").name},
			{"label": "强大的人", "stress": {"ambitious": -10, "content": 10},
				"tip": func(c: Dictionary) -> String: return "%s好感 +5" % _p(c, "who").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "who"), c.me, "跟我谈得来", 5, 5, c.day)
					return "%s笑着说: 「那我可得跟紧您。」" % _p(c, "who").name},
			{"label": "虔诚的人", "stress": {"zealous": -10, "cynical": 10},
				"tip": func(c: Dictionary) -> String: return "%s好感 +5" % _p(c, "who").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "who"), c.me, "跟我谈得来", 5, 5, c.day)
					return "两个人一直聊到蜡烛烧完。"},
		]}


# 14 歉收
static func _bad_harvest() -> Dictionary:
	return {"id": "bad_harvest", "cat": "领地", "weight": 6, "cooldown": 6, "months": [8, 9, 10], "title": "歉收",
		"when": func(c: Dictionary) -> bool: return not c.w.lands_of(c.me).is_empty(),
		"text": func(_c: Dictionary) -> String:
			return "今年夏天雨下个不停, 麦子烂在地里。管家说, 照往年那样收, 不少人家要饿着过冬。",
		"options": [
			{"label": "开仓救济", "gold": func(c: Dictionary) -> int: return 5 * c.w.lands_of(c.me).size(), "stress": {"greedy": 15, "compassionate": -10},
				"tip": func(c: Dictionary) -> String: return "金钱 -%d; 威望 +10; 封臣好感 +10" % (5 * c.w.lands_of(c.me).size()),
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 5.0 * c.w.lands_of(me).size()
					me.prestige += 10.0
					for v in c.w.vassals_of(me):
						_mem(v, me, "荒年开仓救济", 10, 5, c.day)
					return "粮仓打开了, 百姓排着队领麦子。"},
			{"label": "照收不误", "stress": {"compassionate": 15, "greedy": -5},
				"tip": func(_c: Dictionary) -> String: return "封臣好感 -5",
				"do": func(c: Dictionary) -> String:
					for v in c.w.vassals_of(c.me):
						_mem(v, c.me, "荒年还照收", -5, 5, c.day)
					return "税照收了, 村子里怨声一片。"},
		]}


# 15 强盗
static func _bandits() -> Dictionary:
	return {"id": "bandits", "cat": "领地", "weight": 6, "cooldown": 6, "title": "林子里的强盗",
		"when": func(c: Dictionary) -> bool: return not c.w.lands_of(c.me).is_empty(),
		"text": func(_c: Dictionary) -> String:
			return "有人报信: 林子里聚了一伙强盗, 专抢过路的商人和去集市的农夫。",
		"options": [
			{"label": "派兵去剿", "stress": {"craven": 15, "brave": -5},
				"tip": func(_c: Dictionary) -> String: return "兵少一成 (慢慢补回来); 威望 +10",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.levy_ratio = maxf(0.0, me.levy_ratio - 0.1)
					me.prestige += 10.0
					return "强盗的窝点被端了, 头目吊在了路口。"},
			{"label": "花钱招安", "gold": 15, "stress": {"just": 10},
				"tip": func(_c: Dictionary) -> String: return "金钱 -15",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 15.0
					return "强盗头子收了钱, 答应带着手下去守关口。"},
			{"label": "不管", "stress": {"lazy": -5},
				"tip": func(_c: Dictionary) -> String: return "两年里每月少收 1 金币 (商人不敢来)",
				"do": func(c: Dictionary) -> String:
					_boon(c.me, "强盗出没", -1.0, 24, c.day)
					return "商人们开始绕道走了。"},
		]}


# 16 集市
static func _market() -> Dictionary:
	return {"id": "market", "cat": "领地", "weight": 5, "cooldown": 12, "title": "开集市",
		"when": func(c: Dictionary) -> bool: return c.me.realm != "",
		"text": func(_c: Dictionary) -> String:
			return "几个商人来求你: 准许他们每个月在都城外开一次集市, 他们愿意交摊位钱。",
		"options": [
			{"label": "准了 (修摊位花 15 金币)", "gold": 15, "tip": func(_c: Dictionary) -> String: return "金钱 -15; 以后五年每月多 1.5 金币",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 15.0
					_boon(me, "集市", 1.5, 60, c.day)
					return "第一次开集市, 来了好几百人。"},
			{"label": "不准, 怕招来是非", "tip": func(_c: Dictionary) -> String: return "什么都不变",
				"do": func(_c: Dictionary) -> String: return "商人们去了邻国。"},
		]}


# 17 桥塌了 (修桥是当时人人要出力的三项义务之一: 当兵、修堡垒、修桥)
static func _bridge() -> Dictionary:
	return {"id": "bridge", "cat": "领地", "weight": 5, "cooldown": 8, "title": "桥塌了",
		"when": func(c: Dictionary) -> bool: return not c.w.lands_of(c.me).is_empty(),
		"text": func(_c: Dictionary) -> String:
			return "春天发大水, 冲塌了河上的木桥。过河的人只能绕一天的路。修桥是大家都要出力的事, 可正赶上春耕。",
		"options": [
			{"label": "征民夫马上修", "gold": 10, "stress": {"lazy": 10, "diligent": -5},
				"tip": func(_c: Dictionary) -> String: return "金钱 -10; 威望 +5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 10.0
					me.prestige += 5.0
					return "一个月后新桥修好了, 比原来的还结实。"},
			{"label": "先放着, 秋收以后再说", "stress": {"diligent": 10},
				"tip": func(_c: Dictionary) -> String: return "威望 -5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige -= 5.0
					return "一整个夏天, 百姓都在抱怨要绕路。"},
		]}


# 18 打猎落马
static func _hunting_fall() -> Dictionary:
	return {"id": "hunting_fall", "cat": "身体", "weight": 5, "cooldown": 8, "title": "打猎落马",
		"when": func(c: Dictionary) -> bool: return c.me.age(c.day) <= 60,
		"text": func(_c: Dictionary) -> String:
			return "追一头公鹿的时候, 你的马被树根绊倒, 你摔出去老远, 爬起来时腿疼得站不稳。",
		"options": [
			{"label": "回去好好休养", "stress": {"diligent": 10, "lazy": -5},
				"tip": func(_c: Dictionary) -> String: return "健康 -0.5 (半年)",
				"do": func(c: Dictionary) -> String:
					_cond(c.me, "落马受伤", -0.5, 6, c.day)
					return "你躺了一个多月才下地。"},
			{"label": "咬牙接着追", "stress": {"craven": 10, "brave": -5},
				"tip": func(_c: Dictionary) -> String: return "一半会伤得更重 (健康 -1.5, 一年); 不然威望 +5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					if c.w.rng.randf() < 0.5:
						_cond(me, "落马后硬撑, 伤重了", -1.5, 12, c.day)
						return "鹿是追到了, 可你的腿肿得像水桶。"
					me.prestige += 5.0
					return "你一瘸一拐地把鹿追到了, 手下人都服了。"},
		]}


# 19 冬天咳嗽
static func _winter_cough() -> Dictionary:
	return {"id": "winter_cough", "cat": "身体", "weight": 6, "cooldown": 4, "months": [11, 12, 1, 2], "title": "咳嗽不止",
		"when": func(_c: Dictionary) -> bool: return true,
		"text": func(_c: Dictionary) -> String:
			return "入冬以后你一直咳嗽, 夜里咳得睡不着, 有时还发冷。",
		"options": [
			{"label": "在床上静养", "stress": {"diligent": 10},
				"tip": func(_c: Dictionary) -> String: return "健康 -0.5 (三个月)",
				"do": func(c: Dictionary) -> String:
					_cond(c.me, "咳嗽", -0.5, 3, c.day)
					return "躺了一冬, 开春就好了。"},
			{"label": "请医生 (10 金币)", "gold": 10, "tip": func(_c: Dictionary) -> String: return "金钱 -10; 病很快就好",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 10.0
					return "医生开了一罐难喝的药, 半个月就不咳了。"},
			{"label": "不当回事", "stress": {"craven": 10},
				"tip": func(_c: Dictionary) -> String: return "三成会拖成重病 (健康 -2, 一年)",
				"do": func(c: Dictionary) -> String:
					if c.w.rng.randf() < 0.3:
						_cond(c.me, "咳嗽拖成了重病", -2.0, 12, c.day)
						return "咳嗽拖成了重病, 你躺倒了。"
					return "过了几个礼拜, 咳嗽自己好了。"},
		]}


# 20 将领请赏
static func _general_reward() -> Dictionary:
	return {"id": "general_reward", "cat": "打仗", "weight": 20, "cooldown": 3, "face": "gen", "title": "将领请赏",
		"when": func(c: Dictionary) -> bool:
			var s: StoryEvents = c.w.story
			if s.last_win.is_empty() or c.day - int(s.last_win.day) > 180 or not c.w.people.has(s.last_win.commander):
				return false
			var g: Person = c.w.people[s.last_win.commander]
			if not g.alive or g == c.me:
				return false
			c.gen = g.id
			return true,
		"text": func(c: Dictionary) -> String:
			return "%s带着打了胜仗的兵回来, 在大厅里当着众人向你请赏。" % _p(c, "gen").name,
		"options": [
			{"label": "赏他 20 金币", "gold": 20, "stress": {"greedy": 10, "generous": -5},
				"tip": func(c: Dictionary) -> String: return "金钱 -20; %s好感 +20 (十年)" % _p(c, "gen").name,
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 20.0
					_p(c, "gen").gold += 20.0
					_mem(_p(c, "gen"), me, "打了胜仗重赏我", 20, 10, c.day)
					return "%s捧着钱袋, 当场跪下谢恩。" % _p(c, "gen").name},
			{"label": "当众夸他几句", "tip": func(c: Dictionary) -> String: return "%s好感 +5" % _p(c, "gen").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "gen"), c.me, "夸了我", 5, 5, c.day)
					return "%s笑着行了个礼, 眼里有点失望。" % _p(c, "gen").name},
		]}


# 21 内应动摇了
static func _agent_wavers() -> Dictionary:
	return {"id": "agent_wavers", "cat": "阴谋", "weight": 20, "cooldown": 3, "face": "ag", "title": "内应动摇了",
		"when": func(c: Dictionary) -> bool:
			var me: Person = c.me
			var sc: Dictionary = c.w.intrigue.scheme_of(me.id, "murder")
			if sc.is_empty() or sc.agents.is_empty():
				return false
			c.sid = int(sc.id)
			c.ag = sc.agents[0]
			c.tg = sc.target
			return c.w.people.has(c.ag),
		"text": func(c: Dictionary) -> String:
			return "%s半夜来找你, 声音发抖: 「对%s下手的事……我这几天睡不着, 怕被人看出来。」" % [_p(c, "ag").name, _p(c, "tg").name],
		"options": [
			{"label": "再给他 20 金币, 稳住他", "gold": 20, "tip": func(_c: Dictionary) -> String: return "金钱 -20; 他接着当内应",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 20.0
					return "%s把钱揣进怀里, 不再提这事了。" % _p(c, "ag").name},
			{"label": "吓唬他: 你已经脱不了身了", "stress": {"compassionate": 10, "callous": -5},
				"tip": func(c: Dictionary) -> String: return "%s好感 -20; 一半会退出" % _p(c, "ag").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "ag"), c.me, "威胁我", -20, 10, c.day)
					if c.w.rng.randf() < 0.5:
						_drop_agent(c)
						return "%s吓坏了, 从此躲着你, 不再当内应。" % _p(c, "ag").name
					return "%s脸色发白, 点了点头。" % _p(c, "ag").name},
			{"label": "放他走", "stress": {"compassionate": -5},
				"tip": func(c: Dictionary) -> String: return "%s不再当内应" % _p(c, "ag").name,
				"do": func(c: Dictionary) -> String:
					_drop_agent(c)
					return "%s松了一口气。" % _p(c, "ag").name},
		]}


static func _drop_agent(c: Dictionary) -> void:
	var sc: Dictionary = c.w.intrigue.schemes.get(int(c.sid), {})
	if not sc.is_empty():
		sc.agents.erase(c.ag)


# 22 关着的人的家人来求情
static func _captive_plea() -> Dictionary:
	return {"id": "captive_plea", "cat": "打仗", "weight": 15, "cooldown": 3, "face": "kin", "title": "来求情",
		"when": func(c: Dictionary) -> bool:
			var me: Person = c.me
			for q in c.w.living.values():
				if q.prisoner_of == me.id:
					for f in c.w._close_family(q):
						if f.adult(c.day) and f.prisoner_of == "":
							c.pr = q.id
							c.kin = f.id
							return true
			return false,
		"text": func(c: Dictionary) -> String:
			return "%s跪在你面前, 求你放了%s的%s%s。" % [_p(c, "kin").name, _he(_p(c, "kin")), c.w.relation(_p(c, "kin"), _p(c, "pr")), _p(c, "pr").name],
		"options": [
			{"label": "交赎金就放", "tip": func(c: Dictionary) -> String: return "要 %d 金币赎金 (他们拿得出才放)" % Feudal.ransom(c.w, _p(c, "pr")),
				"do": func(c: Dictionary) -> String: return c.w.ransom(c.me, _p(c, "pr"), c.day).text},
			{"label": "看在你的份上, 放了", "stress": {"compassionate": -10, "callous": 10},
				"tip": func(c: Dictionary) -> String: return "%s好感 +20, %s +15" % [_p(c, "pr").name, _p(c, "kin").name],
				"do": func(c: Dictionary) -> String:
					c.w.release(c.me, _p(c, "pr"), c.day)
					_mem(_p(c, "kin"), c.me, "放了我的家人", 15, 10, c.day)
					return "%s被放了出来。" % _p(c, "pr").name},
			{"label": "不放", "stress": {"compassionate": 10},
				"tip": func(c: Dictionary) -> String: return "%s好感 -10" % _p(c, "kin").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "kin"), c.me, "不肯放我的家人", -10, 10, c.day)
					return "%s哭着被拉了出去。" % _p(c, "kin").name},
		]}


# 23 日食 (878 年 10 月 29 日)
static func _eclipse_878() -> Dictionary:
	return {"id": "eclipse_878", "cat": "史料", "weight": 1, "once": true, "window": _window(878, 11, 878, 11), "title": "白天变黑了",
		"history": "《盎格鲁-撒克逊编年史》在 879 年下面记了一次日食: 「太阳暗了一个时辰」。那时候一年从九月算起, 天文学家推算这就是 878 年 10 月 29 日的日全食, 伦敦一带看到的是全食。",
		"when": func(_c: Dictionary) -> bool: return true,
		"text": func(_c: Dictionary) -> String:
			return "十月二十九日中午, 太阳一点一点被吃掉, 天黑得能看见星星, 过了好一阵才又亮起来。百姓跪在地上哭喊, 说这是上天发怒了。",
		"options": [
			{"label": "请教士出来解释", "stress": {"cynical": 5},
				"tip": func(_c: Dictionary) -> String: return "威望 +5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige += 5.0
					return "教士说这是神提醒世人悔改, 人心慢慢安定下来。"},
			{"label": "说成吉兆, 鼓舞人心", "stress": {"honest": 10},
				"tip": func(c: Dictionary) -> String: return "外交好 (10 以上) 威望 +15, 不然 +5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					if me.skill("diplomacy", c.day) >= 10:
						me.prestige += 15.0
						return "你站在城门上高声说: 黑暗过去了, 光明回来了! 人群欢呼起来。"
					me.prestige += 5.0
					return "你说这是好兆头, 可没几个人信。"},
			{"label": "闭门祈祷", "stress": {"zealous": -10, "cynical": 10},
				"tip": func(_c: Dictionary) -> String: return "你心里安稳些",
				"do": func(_c: Dictionary) -> String: return "你跪在小教堂里, 一直祈祷到天亮。"},
		]}


# 24 彗星 (891 年复活节后)
static func _comet_891() -> Dictionary:
	return {"id": "comet_891", "cat": "史料", "weight": 1, "once": true, "window": _window(891, 5, 891, 5), "title": "长头发的星",
		"history": "《盎格鲁-撒克逊编年史》891 年 (有的抄本记在 892 年): 复活节以后、祈祷日前后天上出现一颗星, 书上的拉丁文叫它 cometa, 有人说用英语可以叫「长头发的星」。",
		"when": func(_c: Dictionary) -> bool: return true,
		"text": func(_c: Dictionary) -> String:
			return "复活节过后, 夜空里出现一颗拖着长尾巴的星, 一连好多天。修士说书上管它叫「cometa」, 老百姓叫它「长头发的星」, 都说要出大事了。",
		"options": [
			{"label": "当作凶兆, 祈祷消灾", "stress": {"zealous": -10, "cynical": 10},
				"tip": func(_c: Dictionary) -> String: return "你心里安稳些",
				"do": func(_c: Dictionary) -> String: return "各个教堂一连做了七天弥撒。"},
			{"label": "不信这一套", "stress": {"cynical": -10, "zealous": 10},
				"tip": func(_c: Dictionary) -> String: return "什么都不变",
				"do": func(_c: Dictionary) -> String: return "你照常吃饭睡觉, 星星过了一个月就不见了。"},
			{"label": "说这是我们的好兆头", "stress": {"honest": 10},
				"tip": func(_c: Dictionary) -> String: return "威望 +10",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige += 10.0
					return "手下的人都说, 这颗星是来为你开路的。"},
		]}


# 25 圣卡斯伯特的棺材 (875–883 年, 北边)
static func _cuthbert() -> Dictionary:
	return {"id": "cuthbert", "cat": "史料", "weight": 30, "once": true, "title": "抬着棺材的修士",
		"history": "875 年维京人打过来以后, 林迪斯法恩的修士在主教埃德伍尔夫带领下, 抬着圣卡斯伯特的棺材 (还带着《林迪斯法恩福音书》) 流浪了七年左右, 到过坎布里亚、加洛韦, 883 年才在切斯特勒斯特里特落脚。",
		"when": func(c: Dictionary) -> bool:
			if c.day < GameDate.to_day(875, 1, 1) or c.day > GameDate.to_day(883, 12, 28):
				return false
			var me: Person = c.me
			if not _christian(me):
				return false
			var rid: String = c.w.realm_of_person(me)
			for c2 in c.w.counties:
				if c2.holder == rid and c2.duchy in ["bernicia", "deira", "lothian", "galloway", "strathclyde"]:
					return true
			return false,
		"text": func(_c: Dictionary) -> String:
			return "一群风尘仆仆的修士推着牛车来到你的大门口, 车上是一口木棺。领头的说: 里面是圣卡斯伯特, 维京人烧了林迪斯法恩, 他们抬着圣徒已经走了好几年, 求你收留。",
		"options": [
			{"label": "收留他们, 给块地方", "gold": 20, "stress": {"zealous": -15, "greedy": 10},
				"tip": func(_c: Dictionary) -> String: return "金钱 -20; 威望 +25",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 20.0
					me.prestige += 25.0
					return "修士们在你的地上住了下来, 远近的人都来朝拜圣徒。"},
			{"label": "给些干粮, 打发他们上路", "gold": 5, "stress": {"zealous": 5},
				"tip": func(_c: Dictionary) -> String: return "金钱 -5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 5.0
					return "修士们谢过你, 推着牛车又上路了。"},
			{"label": "不理他们", "stress": {"zealous": 15},
				"tip": func(_c: Dictionary) -> String: return "威望 -10",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige -= 10.0
					return "修士们在门外祈祷了一夜, 第二天走了。消息传开, 人们都说你薄情。"},
		]}


# 26 海边的陌生船帆
static func _strange_sails() -> Dictionary:
	return {"id": "strange_sails", "cat": "史料", "weight": 5, "cooldown": 10, "title": "陌生的船帆",
		"history": "793 年维京人抢了林迪斯法恩修道院以后, 编年史里常常记着「异教徒的船」沿着海岸抢劫, 修道院和沿海的村子最先遭殃。",
		"when": func(c: Dictionary) -> bool:
			var me: Person = c.me
			if not _christian(me):
				return false
			for c2 in c.w.lands_of(me):
				if c2.coastal:
					return true
			return false,
		"text": func(_c: Dictionary) -> String:
			return "海边的渔夫跑来报信: 天亮的时候, 海上出现了几条陌生的长船, 船头雕着龙头, 正朝岸边划过来。",
		"options": [
			{"label": "召集民兵守海岸", "gold": 10, "stress": {"craven": 5},
				"tip": func(_c: Dictionary) -> String: return "金钱 -10; 威望 +5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 10.0
					me.prestige += 5.0
					return "长船在岸边转了一圈, 看见岸上的人多, 又划走了。"},
			{"label": "加固修道院和教堂", "gold": 15, "stress": {"zealous": -5},
				"tip": func(_c: Dictionary) -> String: return "金钱 -15; 威望 +10",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 15.0
					me.prestige += 10.0
					return "修士们把圣物藏进了新修的石塔。"},
			{"label": "大概是商船, 不理", "stress": {"lazy": -5},
				"tip": func(_c: Dictionary) -> String: return "三成会被抢: 金钱 -20、威望 -10",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					if c.w.rng.randf() < 0.3:
						me.gold -= 20.0
						me.prestige -= 10.0
						return "船上的人上岸抢了一个村子, 烧了教堂。"
					return "那几条船果然是来做买卖的。"},
		]}


# 27 严冬
static func _harsh_winter() -> Dictionary:
	return {"id": "harsh_winter", "cat": "史料", "weight": 5, "cooldown": 8, "months": [12, 1, 2], "title": "严冬",
		"history": "爱尔兰的年鉴 (比如《阿尔斯特年鉴》) 常常记下大雪、严寒和牲口的瘟疫; 那时候一个坏冬天就会闹饥荒。",
		"when": func(c: Dictionary) -> bool: return not c.w.lands_of(c.me).is_empty(),
		"text": func(_c: Dictionary) -> String:
			return "今年冬天冷得出奇, 河都冻上了, 大雪压塌了好些房子, 牲口冻死了不少。",
		"options": [
			{"label": "分柴分粮", "gold": 15, "stress": {"greedy": 10, "compassionate": -10},
				"tip": func(_c: Dictionary) -> String: return "金钱 -15; 威望 +10; 封臣好感 +5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 15.0
					me.prestige += 10.0
					for v in c.w.vassals_of(me):
						_mem(v, me, "严冬里分柴分粮", 5, 5, c.day)
					return "百姓们说, 这个冬天多亏了你。"},
			{"label": "各家顾各家", "stress": {"compassionate": 15},
				"tip": func(_c: Dictionary) -> String: return "威望 -5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige -= 5.0
					return "开春的时候, 好几个村子少了人。"},
		]}


# 28 学读拉丁文
static func _learn_latin() -> Dictionary:
	return {"id": "learn_latin", "cat": "史料", "weight": 5, "once": true, "title": "学读拉丁文",
		"history": "阿瑟在《阿尔弗雷德传》里写, 阿尔弗雷德 887 年 (快四十岁了) 才开始学着读拉丁文, 后来还亲手把几本书翻成英语。",
		"when": func(c: Dictionary) -> bool:
			var me: Person = c.me
			return _christian(me) and me.age(c.day) >= 20 and me.skill("learning", c.day) < 12,
		"text": func(_c: Dictionary) -> String:
			return "一位上了年纪的修士劝你: 「您该学着自己读拉丁文的书, 不能光听别人念。读书的国王, 才知道古人是怎么治国的。」",
		"options": [
			{"label": "学", "stress": {"lazy": 10, "diligent": -5},
				"tip": func(_c: Dictionary) -> String: return "学识 +2; 威望 +5",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.base_skills.learning = int(me.base_skills.get("learning", 0)) + 2
					me.prestige += 5.0
					return "一年以后, 你已经能磕磕绊绊地读《圣经》了。"},
			{"label": "没空", "stress": {"diligent": 5},
				"tip": func(_c: Dictionary) -> String: return "什么都不变",
				"do": func(_c: Dictionary) -> String: return "修士叹了口气, 把书收了起来。"},
		]}


# 29 抄福音书
static func _gospel_book() -> Dictionary:
	return {"id": "gospel_book", "cat": "史料", "weight": 4, "cooldown": 15, "title": "抄一部福音书",
		"history": "这一带的修道院抄过很多精美的福音书, 像《林迪斯法恩福音书》《凯尔经》; 抄一部这样的书要用上百张小牛皮, 颜料有的从很远的地方运来。",
		"when": func(c: Dictionary) -> bool: return _christian(c.me) and c.me.realm != "",
		"text": func(_c: Dictionary) -> String:
			return "修道院长来求见: 修士们想抄一部福音书, 配上金色和蓝色的花纹, 可羊皮纸和颜料都太贵了, 想请您资助。",
		"options": [
			{"label": "出 30 金币", "gold": 30, "stress": {"greedy": 10, "zealous": -10},
				"tip": func(_c: Dictionary) -> String: return "金钱 -30; 威望 +20",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 30.0
					me.prestige += 20.0
					return "几年以后书抄好了, 扉页上写着你的名字。"},
			{"label": "国库不宽裕, 不出", "stress": {"zealous": 10},
				"tip": func(_c: Dictionary) -> String: return "什么都不变",
				"do": func(_c: Dictionary) -> String: return "院长失望地走了。"},
		]}


# 30 维京人的献祭节 (只给信北欧旧神的人)
static func _blot() -> Dictionary:
	return {"id": "blot", "cat": "史料", "weight": 6, "cooldown": 5, "months": [10, 11], "title": "献祭的大会",
		"history": "北欧人把献祭的大会叫 blót, 秋天、冬天都要办, 宰牲口、喝酒、敬奉神明; 后来的萨迦和不来梅的亚当都写过这种献祭。",
		"when": func(c: Dictionary) -> bool: return not _christian(c.me) and c.w.is_landed(c.me),
		"text": func(_c: Dictionary) -> String:
			return "秋天到了, 族人等着你主持献祭的大会: 宰牛宰马, 把血洒在神像上, 再一起喝酒吃肉, 敬奉神明。",
		"options": [
			{"label": "主持献祭", "gold": 10, "stress": {"cynical": 10, "zealous": -10},
				"tip": func(_c: Dictionary) -> String: return "金钱 -10; 威望 +15",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.gold -= 10.0
					me.prestige += 15.0
					return "大会一连开了三天, 大家都说今年神会保佑。"},
			{"label": "随便应付一下", "stress": {"zealous": 10},
				"tip": func(_c: Dictionary) -> String: return "威望 -10",
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige -= 10.0
					return "族里的老人们摇着头, 说你不敬神明。"},
		]}


# 31 打败的维京首领愿意受洗
static func _baptism() -> Dictionary:
	return {"id": "baptism", "cat": "史料", "weight": 25, "cooldown": 10, "face": "en", "title": "愿意受洗",
		"history": "878 年阿尔弗雷德在埃丁顿打败古特鲁姆, 古特鲁姆和三十个手下受了洗, 阿尔弗雷德当他的教父 (《盎格鲁-撒克逊编年史》)。",
		"when": func(c: Dictionary) -> bool:
			var s: StoryEvents = c.w.story
			if not _christian(c.me) or s.last_norse_win.is_empty() or c.day - int(s.last_norse_win.day) > 365:
				return false
			if not c.w.people.has(s.last_norse_win.enemy) or not c.w.people[s.last_norse_win.enemy].alive:
				return false
			c.en = s.last_norse_win.enemy
			return true,
		"text": func(c: Dictionary) -> String:
			return "被你打败的维京首领%s派人来说: %s愿意带着手下受洗, 请你当%s的教父。" % [_p(c, "en").name, _he(_p(c, "en")), _he(_p(c, "en"))],
		"options": [
			{"label": "当他的教父", "stress": {"zealous": -10, "vengeful": 10},
				"tip": func(c: Dictionary) -> String: return "威望 +20; %s好感 +40 (二十年)" % _p(c, "en").name,
				"do": func(c: Dictionary) -> String:
					var me: Person = c.me
					me.prestige += 20.0
					_mem(_p(c, "en"), me, "当了我的教父", 40, 20, c.day)
					return "受洗那天, 你亲手把%s从水里扶了起来。" % _p(c, "en").name},
			{"label": "不理他", "stress": {"zealous": 10},
				"tip": func(c: Dictionary) -> String: return "%s好感 -10" % _p(c, "en").name,
				"do": func(c: Dictionary) -> String:
					_mem(_p(c, "en"), c.me, "看不起我", -10, 10, c.day)
					return "使者被打发回去了。"},
		]}


# ---- 记下打赢的仗 (将领请赏、维京首领受洗要用) ----

func watch(events: Array) -> void:
	for e in events:
		match e.type:
			"battle":
				var ws: Array = e.get("winners", [])
				var cs: Array = e.get("winner_commanders", [])
				for i in ws.size():
					if ws[i] == w.player and i < cs.size() and cs[i] != "" and cs[i] != w.player:
						last_win = {"commander": cs[i], "day": int(e.day)}
			"war_end":
				var war: Dictionary = e.war
				var enemy := ""
				if e.result == "attacker" and war.attacker == w.player:
					enemy = war.defender
				elif e.result == "defender" and war.defender == w.player:
					enemy = war.attacker
				if enemy != "" and w.people.has(enemy) and w._norse(w.people[enemy]):
					last_norse_win = {"enemy": enemy, "day": int(e.day)}


# ---- 存档 ----

func to_save() -> Dictionary:
	return {"fired": fired, "last_win": last_win, "last_norse_win": last_norse_win}


func from_save(d: Dictionary) -> void:
	fired = {}
	for k in d.get("fired", {}):
		fired[k] = int(d.fired[k])
	last_win = d.get("last_win", {})
	last_norse_win = d.get("last_norse_win", {})
