extends TestCase
## 开局设置 (照三代的游戏规则)。每条测完把孩子的健康改回默认, 不影响别的测试


func after_each() -> void:
	Person.child_health = Rules.CHILD_HEALTH.normal


func test_defaults() -> void:
	var w := World.load_867(1)
	eq(w.rules, {"generate_families": "on", "ironman": "off", "child_death": "normal", "history": "on", "wars": "on"})


func test_generate_families_off() -> void:
	var w := World.load_867(1, {"generate_families": "off"})
	check(not w.ruler("east_anglia").married(), "关了: 埃德蒙开局没有家人")
	var w2 := World.load_867(1)
	check(w2.ruler("east_anglia").married(), "默认开: 有家人")


func test_generate_families_ai_only() -> void:
	var w := World.load_867(1, {"generate_families": "ai"})
	var edmund := w.ruler("east_anglia")
	check(edmund.married(), "开局先都生成")
	var kids := w.children_of(edmund)
	check(not kids.is_empty())
	w.remove_generated_family(edmund.id)
	check(not edmund.married(), "玩家选了他: 生成的家人拿掉")
	eq(w.children_of(edmund).size(), 0)
	check(not w.people.has(kids[0].id))
	check(w.ruler("great_army").married(), "别人的不动")


func test_child_death_rule() -> void:
	World.load_867(1, {"child_death": "history"})
	var hist := _share_dying()
	World.load_867(1, {"child_death": "low"})
	var low := _share_dying()
	World.load_867(1)
	var normal := _share_dying()
	check(hist > 0.27 and hist < 0.36, "照史实: 大约三分之一 (%.2f)" % hist)
	check(normal > 0.15 and normal < 0.25, "默认: 大约五分之一 (%.2f)" % normal)
	check(low > 0.06 and low < 0.14, "少: 大约十分之一 (%.2f)" % low)


func _share_dying() -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var died := 0
	for i in 4000:
		var p := Person.new()
		p.birth_day = 0
		for year in 16:
			if rng.randf() < p.yearly_death_chance(year * 365 + 10):
				died += 1
				break
	return died / 4000.0


func test_history_rule() -> void:
	var w := World.load_867(1, {"history": "off"})
	eq(w.history_marriages.size(), 0, "全随机: 没有史料里的婚事")
	eq(w.history_children.size(), 0)
	check(World.load_867(1).history_marriages.size() > 0)


func test_rules_saved() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("bloodline_test_rules_%d" % OS.get_process_id())
	var w := World.load_867(3, {"ironman": "on", "child_death": "low"})
	var path := SaveGame.write("测试", w, Clock.new(w.start_day), {})
	var w2 := World.from_save(SaveGame.read(path).world)
	eq(w2.rules.ironman, "on")
	eq(w2.rules.child_death, "low")
	SaveGame.remove(path)
