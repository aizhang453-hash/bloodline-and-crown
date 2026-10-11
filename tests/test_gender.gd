extends TestCase
## 性别法和随母婚 (用户 2026-10-11 定的, 照三代): 开局只有男人 (照史实), 花 500 威望改成男人优先; 随母婚孩子算母亲的家族。

var w: World
var k: Person
var girl: Person


func before_each() -> void:
	w = World.load_867(7, {"wars": "off"})
	w.today = w.start_day
	# 格温特国王: 换一个只有他自己的家族, 再给他一个女儿 (家里没有别的男人)
	k = w.ruler("gwent")
	k.house = "test_house"
	w.houses["test_house"] = {"id": "test_house", "name": "测试家族", "desc": "", "color": Color.RED, "design": 0}
	var wife := k.living_spouse()
	if wife == null:
		wife = w.make_noble("welsh", true, 30, w.today)
		w._register(wife)
		w.marry(k, wife, w.today, [])
	girl = w._new_child(k, wife, w.today - 18 * GameDate.YEAR_DAYS, 1)
	w._house_dirty = true


func test_default_male_only() -> void:
	eq(w.gender_law("gwent"), "male_only", "开局都是只有男人 (照史实)")
	eq(w.heir("gwent", w.today), null, "只有女儿: 没人能继承")


func test_change_law() -> void:
	k.prestige = 100.0
	check(w.change_gender_law(k, "male_pref").text.contains("威望不够"))
	k.prestige = 600.0
	var r := w.change_gender_law(k, "male_pref")
	check(r.ok, r.text)
	eq(k.prestige, 100.0, "花 500 威望 (照三代)")
	eq(w.heir("gwent", w.today), girl, "男人优先: 没有男人, 女儿继承")
	check(w.change_gender_law(k, "male_only").ok)
	eq(k.prestige, 100.0, "往严里改不花")
	check(w.gender_law_problem(k, "equal") != "", "男女平等要等宗教")


func test_queen() -> void:
	w.realms.gwent.gender_law = "male_pref"
	var ev := []
	w.kill(k, w.today, ev)
	eq(w.ruler("gwent"), girl, "女儿当了统治者")
	check(w.title_of(girl).contains("女王"), "叫女王: " + w.title_of(girl))
	check(not w.warfare.can_command(girl, w.today), "男人主导的信仰: 女王不能亲自带兵")
	var succ: Array = ev.filter(func(e: Dictionary) -> bool: return e.type == "succession")
	eq(succ[0].heir, girl.id)


func test_male_still_first() -> void:
	w.realms.gwent.gender_law = "male_pref"
	var wife := k.living_spouse()
	var boy := w._new_child(k, wife, w.today - 10 * GameDate.YEAR_DAYS, 0)
	w._house_dirty = true
	eq(w.heir("gwent", w.today), boy, "有儿子就轮不到女儿 (男人优先)")


func test_matrilineal() -> void:
	w.realms.gwent.gender_law = "male_pref"
	w.kill(k, w.today, [])
	var man := w.make_noble("welsh", false, 20, w.today)
	var acc := Marriage.acceptance(w, girl, girl, man, w.today, true)
	var labels: Array = acc.parts.map(func(x: Array) -> String: return x[0])
	check(labels.any(func(l: String) -> bool: return l.begins_with("随母婚")), "随母婚男方不太肯")
	w._register(man)
	w.marry(girl, man, w.today, [], "", true)
	check(girl.matrilineal)
	var baby := w._new_child(man, girl, w.today)
	eq(baby.house, "test_house", "随母婚: 孩子算母亲的家族")
	w._house_dirty = true
	eq(w.heir("gwent", w.today), baby, "女王的孩子能继承")


func test_ai_queen_marries_matrilineal() -> void:
	w.realms.gwent.gender_law = "male_pref"
	w.kill(k, w.today, [])
	check(not girl.married())
	w.rng.seed = 3
	for i in 60:
		w._ai_marriages(w.today + i * 30, [])
		if girl.married():
			break
	check(girl.married(), "电脑给女王说了亲")
	check(girl.matrilineal, "女王随母婚")


func test_split_and_save() -> void:
	w.realms.gwent.gender_law = "male_pref"
	girl.matrilineal = true
	var w2 := World.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	eq(w2.gender_law("gwent"), "male_pref", "存档记着性别法")
	check(w2.people[girl.id].matrilineal)
