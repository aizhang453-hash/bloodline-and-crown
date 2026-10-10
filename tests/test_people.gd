extends TestCase
## 人物的规矩: 性格特点、本事、健康、压力、好感 (第 2 块, 用户 2026-10-10 同意的清单)

const START := 867 * 365


func person(traits: Array = [], age := 30, culture := "anglo_saxon") -> Person:
	var p := Person.new()
	p.id = "test"
	p.name = "测试"
	p.culture = culture
	p.birth_day = START - age * 365
	p.traits = traits
	p.education = {"skill": "martial", "level": 3}
	for s in Traits.SKILLS:
		p.base_skills[s] = 5
	return p


func test_random_personality_has_three_and_no_opposites() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 300:
		rng.seed = seed
		var ts := Traits.random_personality(rng)
		eq(ts.size(), 3)
		for a in ts:
			eq(ts.count(a), 1, "不重复")
			for b in ts:
				check(not Traits.opposite(a, b), "%s 和 %s 相反, 不能一起" % [a, b])
	rng.seed = 1
	var forced := Traits.random_personality(rng, 3, ["zealous", "brave"])
	check(forced.has("zealous") and forced.has("brave"), "史料给的性格一定在")
	check(not forced.has("cynical") and not forced.has("craven"), "随机补的不跟史料给的相反")


func test_opposites_go_both_ways() -> void:
	for t in Traits.data().personality:
		for o in t.opposite:
			check(Traits.opposite(o, t.id), "%s 和 %s 互相相反" % [o, t.id])


func test_congenital_one_per_group() -> void:
	var rng := RandomNumberGenerator.new()
	var seen := 0
	for seed in 2000:
		rng.seed = seed
		var ts := Traits.random_congenital(rng)
		var groups := {}
		for t in ts:
			var g: String = Traits.get_trait(t).group
			check(not groups.has(g), "一组只有一个")
			groups[g] = true
		seen += ts.size()
	check(seen > 300 and seen < 900, "大多数人没有天生特点 (2000 人里有 %d 个)" % seen)


func test_skills_add_up() -> void:
	var p := person(["brave", "diligent"])
	var parts := p.skill_parts("martial", START)
	var total := 0
	for x in parts:
		total += int(x[1])
	eq(p.skill("martial", START), total)
	eq(p.skill("martial", START), 5 + 5 + 2 + 1, "底子 5 + 军事教育好 5 + 勇敢 2 + 勤奋 1")
	eq(p.skill("prowess", START), 5 + 3 + 1, "武力: 底子 5 + 勇敢 3 + 勤奋 1")
	eq(p.skill("diplomacy", START), 5 + 1)
	eq(person(["intellect_bad_3", "lazy"]).skill("learning", START), 0, "本事最低是 0")


func test_age_lowers_prowess_and_health() -> void:
	var young := person([], 30)
	var old := person([], 70)
	young.base_skills.prowess = 10
	old.base_skills.prowess = 10
	eq(old.skill("prowess", START), young.skill("prowess", START) - 6, "70 岁武力 -6")
	eq(old.skill("diplomacy", START), young.skill("diplomacy", START) - 1, "70 岁别的本事 -1")
	check(young.health(START) > old.health(START))
	eq(young.health_text(START), "好")
	eq(person([], 80).health_text(START), "差")
	eq(person([], 85).health_text(START), "很差")
	eq(person(["physique_good_2"], 30).health_text(START), "很好", "强壮的人健康很好")


func test_children_have_smaller_skills() -> void:
	var kid := person([], 8)
	kid.education = {}
	check(kid.skill("learning", START) < 5, "小孩本事小")
	check(not kid.adult(START))
	check(person([], 16).adult(START), "16 岁成年")


func test_stress_levels_and_recovery() -> void:
	var p := person()
	p.add_stress(250)
	eq(p.stress_level(), 2)
	eq(p.skill("diplomacy", START), 5 - 2, "压力 2 档, 本事 -2")
	p.add_stress(1000)
	eq(p.stress, Person.MAX_STRESS, "压力最多 300")
	p.stress = 100.0
	p.pass_days(365)
	check(absf(p.stress - 85.0) < 0.01, "一年降 15")
	var calm := person(["calm"])
	calm.stress = 100.0
	calm.pass_days(365)
	check(absf(calm.stress - 70.0) < 0.01, "冷静的人降两倍")
	p.stress = 5.0
	p.pass_days(3650)
	eq(p.stress, 0.0, "不会降到 0 以下")


func test_opinion() -> void:
	var a := person(["brave", "zealous", "honest"])
	var b := person(["brave", "cynical", "beauty_good_2"])
	var o := a.opinion_of(b)
	eq(o.total, 10 - 10 + 10 + 10, "都勇敢 +10, 虔信对愤世 -10, 他美貌 +10, 同文化 +10")
	eq(o.parts.size(), 4)
	var c := person(["brave"], 30, "norse")
	eq(a.opinion_of(c).total, 10, "不同文化不加")
	var cruel := person(["sadistic"])
	var kind := person(["compassionate"])
	eq(kind.opinion_of(cruel).total, -10 + 10)


func test_world_rulers_have_traits_and_skills() -> void:
	var w := World.load_867()
	for id in w.realm_order:
		var p := w.ruler(id)
		eq(p.personality().size(), 3, p.name + " 有 3 个性格")
		check(int(p.education.level) >= 1 and int(p.education.level) <= 4, p.name + " 受过教育")
		for s in Traits.SKILLS:
			var v := p.skill(s, w.start_day)
			check(v >= 0 and v <= 40, "%s 的 %s 是 %d" % [p.name, s, v])
	var p := w.ruler("wessex")
	p.stress = 200.0
	w.advance(365)
	check(p.stress < 200.0, "过一年压力降了")
