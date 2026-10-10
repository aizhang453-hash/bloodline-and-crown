class_name Person
extends RefCounted
## 一个人: 名字、性别、生日、文化、长相基因, 还有性格特点、本事、健康、压力, 对别人的好感。
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


## 在某一天几岁 (过了生日才算长一岁)
func age(day: int) -> int:
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
	return traits.filter(func(t: String) -> bool: return Traits.get_trait(t).get("kind", "") == "personality")


func congenital() -> Array:
	return traits.filter(func(t: String) -> bool: return Traits.get_trait(t).get("kind", "") == "congenital")


func stress_level() -> int:
	return clampi(floori(stress / STRESS_PER_LEVEL), 0, 3)


func add_stress(amount: float) -> void:
	stress = clampf(stress + amount, 0.0, MAX_STRESS)


## 过了几天: 压力慢慢降
func pass_days(days: int) -> void:
	var decay := STRESS_DECAY * (2.0 if has_trait("calm") else 1.0)
	add_stress(-decay * days / float(GameDate.YEAR_DAYS))


# ---- 本事 ----

## 一项本事的每一部分: [[说明, 加减], ...]
func skill_parts(skill: String, day: int) -> Array:
	var parts := []
	var a := age(day)
	var base := int(base_skills.get(skill, 0))
	if a < ADULT:
		base = floori(base * clampf(a / float(ADULT), 0.25, 1.0))
	parts.append(["底子", base])
	if not education.is_empty() and education.skill == skill and int(education.level) > 0:
		parts.append([Traits.education_name(education), Traits.education_bonus(int(education.level))])
	for t in traits:
		var info := Traits.get_trait(t)
		var sk: Dictionary = info.get("skills", {})
		var v := int(sk.get(skill, 0)) + (int(sk.get("all", 0)))
		if v != 0:
			parts.append([info.name, v])
	if skill == "prowess" and a > 40:
		parts.append(["年纪 (%d 岁)" % a, -((a - 40) / 5)])
	elif skill != "prowess" and a > 65:
		parts.append(["年纪 (%d 岁)" % a, -((a - 65) / 5)])
	if stress_level() > 0:
		parts.append(["压力 %d 档" % stress_level(), -stress_level()])
	return parts.filter(func(p: Array) -> bool: return p[1] != 0 or p[0] == "底子")


func skill(skill_id: String, day: int) -> int:
	var total := 0
	for p in skill_parts(skill_id, day):
		total += int(p[1])
	return maxi(0, total)


# ---- 健康 ----

func health_parts(day: int) -> Array:
	var parts := [["普通人", 5.0]]
	var a := age(day)
	if a > 40:
		parts.append(["年纪 (%d 岁)" % a, -pow(a - 40, 2) / 400.0])
	for t in traits:
		var info := Traits.get_trait(t)
		if info.has("health"):
			parts.append([info.name, float(info.health)])
	if stress_level() > 0:
		parts.append(["压力 %d 档" % stress_level(), -0.5 * stress_level()])
	return parts


func health(day: int) -> float:
	var total := 0.0
	for p in health_parts(day):
		total += float(p[1])
	return total


func health_text(day: int) -> String:
	var h := health(day)
	for b in HEALTH_BANDS:
		if h < b[0]:
			return b[1]
	return "很好"


# ---- 好感 ----

## 我对 other 的好感: {total, parts: [[说明, 加减], ...]}
func opinion_of(other: Person) -> Dictionary:
	var parts := []
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
	var total := 0
	for p in parts:
		total += int(p[1])
	return {"total": clampi(total, -100, 100), "parts": parts}
