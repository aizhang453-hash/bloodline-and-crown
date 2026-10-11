class_name Person
extends RefCounted
## 一个人: 名字、性别、生日、文化、长相基因, 还有性格特点、本事、健康、压力, 对别人的好感;
## 家人 (父母、配偶; 孩子和兄弟姐妹从父母推出来, 见 World)、家族、活着没有、威望。
## 第 4 块: 订婚、怀孕、小时候的性格、学什么、老师 (监护人)。
## 第 5 块: 封臣 (给哪个国家当封臣、合同)、金钱、暴政、关大牢、记仇记恩 (memories)。
## 本事、健康、好感都是现算的, 每样都能列出「哪一项加了多少」(鼠标指着时给人看)。

const ADULT := 16
const STRESS_PER_LEVEL := 100.0
const MAX_STRESS := 300.0
const STRESS_DECAY := 15.0  # 每年自己降多少 (冷静的人降两倍)
const CULTURE_NAMES := {
	"anglo_saxon": "盎格鲁-撒克逊人", "norse": "诺斯人", "norse_gael": "诺斯-盖尔人", "gaelic": "盖尔人",
	"welsh": "威尔士人", "cornish": "康沃尔人", "cumbric": "坎布里亚人",
}
const HEALTH_BANDS := [[1.0, "很差"], [2.5, "差"], [4.0, "一般"], [5.5, "好"], [INF, "很好"]]
const SPOUSE_SHARE := 5       # 国王的配偶: 本事的五分之一加给国王
# 小孩身子弱 (第 4 块: 用户定的大约五个孩子里一个长不到 16 岁; 史实大约三分之一)。开局设置「孩子夭折」能换 (Rules.CHILD_HEALTH)
static var child_health := [-1.5, -0.8, 0.0, 0.0]  # 不满 1 岁, 1 到 4 岁, 5 到 9 岁, 10 到 15 岁
const DUNGEON_HEALTH := -1.5  # 关在地牢里 (照三代: 地牢伤身体)

var id: String
var name: String
var female := false
var birth_day: int            # 生日 (GameDate 的第几天)
var birth_estimated := false  # 生年史料没记, 是估计的
var culture: String
var dna: Dictionary           # 长相基因 (Portrait.random_dna)
var rank := ""                # "king" 国王、"noble" 贵族、"" 平民
var realm := ""               # 统治哪个国家 (不是统治者就是空的)
var note := ""                # 史料说明 (给人看的)
var traits: Array = []        # 性格和天生的特点 (traits.json 里的 id)
var education := {}           # {skill, level}: 学的哪一样、第几档 (1 差 2 一般 3 好 4 出色)
var base_skills := {}         # 本事的底子
var stress := 0.0
var father := ""              # 父亲的 id (不知道就是空的)
var mother := ""
var spouse := ""              # 配偶的 id (对方死了也还记着, 再结婚时挪到 former_spouses)
var former_spouses: Array = [] # 以前的配偶 (死了的)
var secondary: Array = []     # 次妻 (爱尔兰古法: 男人在正妻 spouse 之外还能再娶, 见 Marriage.max_wives)
var homeland := ""            # 出身哪个王国 (england / scotland / wales / ireland), 爱尔兰古法要看
var betrothed := ""           # 订了婚的人 (都满 16 岁就成亲)
var pregnant := {}            # 怀孕了: {father: 孩子父亲的 id, due: 哪天生}; 空 = 没怀孕
var last_birth := -100000     # 上次生孩子是哪天 (生完几个月不会马上又怀上)
var focus := ""               # 6 岁开始学什么 (外交、军事、管理、密谋、学识里的一样)
var guardian := ""            # 老师 (三代叫「监护人」) 的 id
var edu_points := 0.0         # 学了几年攒下的分数, 16 岁时定教育的档次
var edu_years := 0            # 学了几年
var taught: Array = []        # 老师传给他的性格 (16 岁时一半机会留下)
var spouse_ref: WeakRef       # 配偶 (World 结婚时接上; 国王的本事有配偶帮忙)
var liege_realm := ""         # 封臣: 给哪个国家当封臣 (国王自己是空的; 领地在 World.counties 的 lord 里)
var contract := 1             # 封臣的合同: 0 少交、1 照常、2 多交 (见 Feudal)
var gold := 0.0               # 金钱
var tyranny := 0.0            # 暴政 (做了不正当的事, 封臣都不高兴; 每月慢慢降)
var prisoner_of := ""         # 关在谁的大牢里 (空 = 没关)
var dungeon := false          # 关在地牢里 (不然是软禁)
var crimes := {}              # 犯过的罪: {"抗命": 到哪天为止} (有罪的人关起来、收回领地都不算暴政)
var memories: Array = []      # 记着别人对他做过的事: [{who, text, value, until}] (好感里加减; 过期了 World 每月删掉)
var house := ""               # 家族 id (空 = 家族不详)
var alive := true
var death_day := -1           # 哪天死的
var prestige := 0.0           # 威望


## 在某一天几岁 (过了生日才算长一岁; 死了的人停在死的那年)
func age(day: int) -> int:
	if not alive:
		day = mini(day, death_day)
	return floori((day - birth_day) / float(GameDate.YEAR_DAYS))


func adult(day: int) -> bool:
	return age(day) >= ADULT


## 画头像要的东西
func looks(day: int) -> Dictionary:
	return {"female": female, "age": age(day), "culture": culture, "rank": rank, "dna": dna}


func culture_name() -> String:
	return CULTURE_NAMES.get(culture, culture)


func has_trait(t: String) -> bool:
	return traits.has(t)


func personality() -> Array:
	return _of_kind("personality")


func congenital() -> Array:
	return _of_kind("congenital")


func _of_kind(kind: String) -> Array:
	var list := []
	for t in traits:
		if Traits.get_trait(t).get("kind", "") == kind:
			list.append(t)
	return list


## 小时候的性格 (3 岁到 16 岁才有), 没有就是空的
func childhood() -> String:
	for t in traits:
		if Traits.get_trait(t).get("kind", "") == "childhood":
			return t
	return ""


## 配偶 (活着的才算), 没有就是 null
func living_spouse() -> Person:
	if spouse == "" or spouse_ref == null:
		return null
	var s: Person = spouse_ref.get_ref()
	return s if s != null and s.alive and s.id == spouse else null


func married() -> bool:
	return living_spouse() != null


func stress_level() -> int:
	return clampi(floori(stress / STRESS_PER_LEVEL), 0, 3)


func add_stress(amount: float) -> void:
	stress = clampf(stress + amount, 0.0, MAX_STRESS)


# ---- 存档 ----

## 存档要存的东西 (spouse_ref 读档以后 World 重新接上)
const SAVE_FIELDS := ["id", "name", "female", "birth_day", "birth_estimated", "culture", "dna", "rank", "realm", "note",
	"traits", "education", "base_skills", "stress", "father", "mother", "spouse", "former_spouses", "secondary", "homeland",
	"betrothed", "pregnant", "last_birth", "focus", "guardian", "edu_points", "edu_years", "taught", "house", "alive",
	"death_day", "prestige", "liege_realm", "contract", "gold", "tyranny", "prisoner_of", "dungeon", "crimes", "memories"]


func to_save() -> Dictionary:
	var d := {}
	for f in SAVE_FIELDS:
		d[f] = get(f)
	return d


## 读档: JSON 里的数字都是小数, 照原来的类型转回去
static func from_save(d: Dictionary) -> Person:
	var p := Person.new()
	for f in SAVE_FIELDS:
		if not d.has(f):
			continue
		var v: Variant = d[f]
		match typeof(p.get(f)):
			TYPE_INT:
				v = int(v)
			TYPE_FLOAT:
				v = float(v)
			TYPE_BOOL:
				v = bool(v)
			TYPE_STRING:
				v = str(v)
		p.set(f, v)
	return p


## 过了几天: 压力慢慢降
func pass_days(days: int) -> void:
	var decay := STRESS_DECAY * (2.0 if has_trait("calm") else 1.0)
	add_stress(-decay * days / float(GameDate.YEAR_DAYS))


# ---- 本事 ----

## 一项本事的每一部分: [[说明, 加减], ...]。国王的配偶帮忙: 加配偶这项本事的五分之一 (武力不算)
## labels = false 时不拼说明文字 (只要总数的时候用, 快一些)
func skill_parts(skill: String, day: int, with_spouse := true, labels := true) -> Array:
	var parts := []
	var a := age(day)
	var base := int(base_skills.get(skill, 0))
	if a < ADULT:
		base = floori(base * clampf(a / float(ADULT), 0.25, 1.0))
	parts.append(["底子", base])
	if not education.is_empty() and education.skill == skill and int(education.level) > 0:
		parts.append([Traits.education_name(education) if labels else "", Traits.education_bonus(int(education.level))])
	for t in traits:
		var info := Traits.get_trait(t)
		var sk: Dictionary = info.get("skills", {})
		var v := int(sk.get(skill, 0)) + (int(sk.get("all", 0)))
		if v != 0:
			parts.append([info.name, v])
	if skill == "prowess" and a > 40:
		parts.append([("年纪 (%d 岁)" % a) if labels else "", -((a - 40) / 5)])
	elif skill != "prowess" and a > 65:
		parts.append([("年纪 (%d 岁)" % a) if labels else "", -((a - 65) / 5)])
	if stress_level() > 0:
		parts.append([("压力 %d 档" % stress_level()) if labels else "", -stress_level()])
	var partner := living_spouse()
	if with_spouse and realm != "" and partner != null and skill != "prowess":
		var help := partner.skill(skill, day, false) / SPOUSE_SHARE
		if help != 0:
			parts.append([("%s%s帮忙" % ["妻子" if partner.female else "丈夫", partner.name]) if labels else "", help])
	var kept := []
	for x in parts:
		if x[1] != 0 or x[0] == "底子":
			kept.append(x)
	return kept


func skill(skill_id: String, day: int, with_spouse := true) -> int:
	var total := 0
	for p in skill_parts(skill_id, day, with_spouse, false):
		total += int(p[1])
	return maxi(0, total)


# ---- 健康 ----

func health_parts(day: int, labels := true) -> Array:
	var parts := [["普通人", 5.0]]
	var a := age(day)
	if a < 1:
		parts.append(["婴儿", float(child_health[0])])
	elif a < ADULT:
		var band := 1 if a < 5 else (2 if a < 10 else 3)
		if float(child_health[band]) != 0.0:
			parts.append([("小孩 (%d 岁)" % a) if labels else "", float(child_health[band])])
	if a > 40:
		parts.append([("年纪 (%d 岁)" % a) if labels else "", -pow(a - 40, 2) / 400.0])
	for t in traits:
		var info := Traits.get_trait(t)
		if info.has("health"):
			parts.append([info.name, float(info.health)])
	if stress_level() > 0:
		parts.append([("压力 %d 档" % stress_level()) if labels else "", -0.5 * stress_level()])
	if prisoner_of != "" and dungeon:
		parts.append(["关在地牢里", DUNGEON_HEALTH])
	return parts


func health(day: int) -> float:
	var total := 0.0
	for p in health_parts(day, false):
		total += float(p[1])
	return total


func health_text(day: int) -> String:
	var h := health(day)
	for b in HEALTH_BANDS:
		if h < b[0]:
			return b[1]
	return "很好"


# ---- 死 ----

## 一年里死的机会 (按健康算: 很好、好一年 1–2%, 一般 3–5%, 差 8–15%, 很差 30% 左右)
func yearly_death_chance(day: int) -> float:
	return clampf(0.012 * exp(0.65 * (5.0 - health(day))), 0.003, 0.6)


# ---- 好感 ----

## 我对 other 的好感: {total, parts: [[说明, 加减], ...]}
func opinion_of(other: Person) -> Dictionary:
	var parts := []
	if (other.id == spouse or secondary.has(other.id)) and alive and other.alive:
		parts.append(["夫妻", 20])
	elif other.id == betrothed:
		parts.append(["订了婚", 10])
	for t in personality():
		var info := Traits.get_trait(t)
		if other.has_trait(t):
			parts.append(["都是「%s」的人" % info.name, 10])
		else:
			for o in other.personality():
				if Traits.opposite(t, o):
					parts.append(["我「%s」, 他「%s」" % [info.name, Traits.get_trait(o).name], -10])
	for t in other.congenital():
		var info := Traits.get_trait(t)
		if info.has("opinion"):
			parts.append(["他%s" % info.name, int(info.opinion)])
	if culture == other.culture:
		parts.append(["都是%s" % culture_name(), 10])
	# 第 5 块: 我是他的封臣 (他是我的国王): 暴政、合同
	if liege_realm != "" and other.realm == liege_realm:
		if other.tyranny >= 1.0:
			parts.append(["暴政 %d" % int(other.tyranny), -int(other.tyranny / 2.0)])
		if contract != 1:
			parts.append(["合同: %s" % Feudal.CONTRACTS[contract], 10 if contract == 0 else -15])
	if other.id == prisoner_of:
		parts.append(["把我关在%s" % ("地牢里" if dungeon else "大牢里"), -40 if dungeon else -25])
	for m in memories:
		if m.who == other.id:
			parts.append([m.text, int(m.value)])
	var total := 0
	for p in parts:
		total += int(p[1])
	return {"total": clampi(total, -100, 100), "parts": parts}


# ---- 生孩子 (第 4 块) ----

## 女人能不能怀上的系数 (0 = 不能): 16 岁起, 20 多岁最容易, 35 岁以后越来越难, 45 岁以后不能
func fertility(day: int) -> float:
	var a := age(day)
	var f := 0.0
	if female:
		if a < ADULT or a >= 45:
			return 0.0
		f = 0.8 if a < 20 else (1.0 if a < 30 else (0.85 if a < 35 else (0.55 if a < 40 else 0.2)))
	else:
		if a < ADULT:
			return 0.0
		f = 1.0 if a < 50 else (0.75 if a < 60 else (0.5 if a < 70 else 0.25))
	if has_trait("lustful"):
		f *= 1.25
	if has_trait("chaste"):
		f *= 0.75
	if has_trait("inbred"):
		f *= 0.7
	if health(day) < 2.5:
		f *= 0.7
	return f


## 生孩子时母亲死的机会 (健康 5 大约 2%, 越差越危险)
func childbirth_death_chance(day: int) -> float:
	return clampf(0.02 * exp(0.4 * (5.0 - health(day))), 0.005, 0.15)


## 记住别人对他做的事 (好感里加减): years 年以后忘了; same 一样的事只记最新的一条 (比如送礼)
func remember(who: String, text: String, value: int, until: int, same := false) -> void:
	if same:
		memories = memories.filter(func(m: Dictionary) -> bool: return not (m.who == who and m.text == text))
	memories.append({"who": who, "text": text, "value": value, "until": until})
