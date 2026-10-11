extends SceneTree
## 拍画面: 打开游戏, 摆出几种场面各拍一张, 存到给定的文件夹 (会开一下窗口, 拍完自己关)。
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/screenshots.gd -- 存图的文件夹
## 假屏幕 (--headless) 画不出东西, 要开真窗口。

var out := ""
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	SaveGame.dir = OS.get_temp_dir().path_join("bloodline_shot_saves")  # 不碰真的存档
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _wait(frames := 4) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait()
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("拍了 ", name)


func _run() -> void:
	var w: World = main.world
	var map: MapView = main.map
	var hud: Hud = main.hud
	await _shot("1_开局")
	hud.open_rules()
	await _shot("1b_开局设置")
	hud.close_popup()

	main._on_county_clicked(w.by_id.hampshire.index)
	await _shot("2_点了汉普郡")

	main.play_as("wessex")
	main.close_panel()
	hud._focus_player()
	await _shot("3_选了威塞克斯")

	main.clock.toggle_pause()
	main.clock.set_speed(5)
	for i in 30:
		main._process(0.1)
	map.focus(w.by_id.york.seat, 1.5)
	main._on_county_clicked(w.by_id.york.index)
	await _shot("4_约克放大")

	main.close_panel()
	map.show_all()
	map.set_mode(MapView.Mode.DUCHY)
	hud.redraw()
	await _shot("5_公国地图")

	map.set_mode(MapView.Mode.KINGDOM)
	hud.redraw()
	await _shot("6_王国地图")

	map.set_mode(MapView.Mode.REALM)
	map.focus(w.by_id.dublin.seat, 0.9)
	hud._toggle_help()
	await _shot("7_操作说明")

	hud._toggle_help()
	var sheet := IconSheet.new()
	sheet.world = w
	hud.add_child(sheet)
	await _shot("8_图标和纹章")

	sheet.queue_free()
	var traits := TraitSheet.new()
	hud.add_child(traits)
	await _shot("9_特点图标")

	traits.queue_free()
	map.show_all()
	hud.show_person(w.realms.gwynedd.ruler_id)
	await _shot("10_人物窗口_罗德里")
	hud.show_person(w.realms.isles.ruler_id)
	await _shot("11_人物窗口_凯蒂尔")

	# 第 3 块: 罗德里去世, 儿子们分家 (右边出消息); 安纳拉乌德的人物窗口 (家人那一排); 你的国王去世
	main.close_panel()
	var events := []
	w.kill(w.ruler("gwynedd"), main.clock.day, events)
	main.handle_events(events)
	map.focus(w.by_id.mathrafal.seat, 1.2)
	await _shot("12_罗德里去世分家")
	hud.show_person("anarawd")
	await _shot("13_人物窗口_家人")
	main.close_panel()
	events = []
	w.kill(w.ruler("wessex"), main.clock.day, events)
	main.handle_events(events)
	await _shot("14_你的国王去世")

	# 第 4 块: 说亲窗口、教育窗口、生孩子起名、人物窗口里的配偶怀孕同盟、小时候的性格
	hud.close_popup()
	var alfred: Person = w.people["alfred"]
	hud.show_person("alfred")
	await _shot("15_人物窗口_阿尔弗雷德")
	hud._open_match()
	await _shot("16_说亲窗口")
	hud.close_window()
	var kid: Person = w.people["aethelhelm"]
	kid.birth_day = main.clock.day - 7 * 365
	w._grow(kid, main.clock.day, [])
	hud.show_person("aethelhelm")
	hud._open_teacher()
	await _shot("17_教育窗口")
	hud.close_window()
	main.close_panel()
	w.marry(alfred, w.people["ealhswith"], main.clock.day, [])
	while not hud.popup.is_empty():
		print("关掉挡着的窗口: ", hud.popup.kind, " ", hud.popup.get("story", {}).get("id", ""))
		hud.close_popup()
	var ev := []
	w.people["ealhswith"].pregnant = {"father": "alfred", "due": main.clock.day}
	w._give_birth(w.people["ealhswith"], main.clock.day, ev)
	main.handle_events(ev)
	await _shot("18_生孩子起名")
	hud.name_edit.text = "阿特尔斯坦"
	hud.name_edit.caret_column = 5
	await _shot("18b_自己起名")
	hud.close_popup()
	w.people["ealhswith"].pregnant = {"father": "alfred", "due": main.clock.day + 200}
	hud.show_person("ealhswith")
	await _shot("19_人物窗口_怀孕")
	hud.show_person(w.realms.ailech.ruler_id)
	await _shot("20_人物窗口_艾德")
	main.close_panel()
	var sheet2 := TraitSheet.new()
	hud.add_child(sheet2)
	await _shot("21_特点图标")

	# 第 5 块: 封臣
	sheet2.queue_free()
	map.show_all()
	main.close_panel()
	hud._open_realm_window()
	await _shot("22_我的国家")
	var rows: Array = hud.window.rows
	for i in rows.size():
		if rows[i].type == "county" and not rows[i].capital:
			hud._choose_row(i)
			break
	await _shot("23_封地")
	hud.close_window()
	hud.me().gold = 60
	hud.show_person("wulfhere_wiltshire")
	await _shot("24_人物窗口_郡长")
	hud._open_actions()
	await _shot("25_互动")
	hud.close_window()
	main.close_panel()
	map.focus(w.by_id.berkshire.seat, 1.6)
	main._on_county_clicked(w.by_id.berkshire.index)
	await _shot("26_领地窗口_伯克郡")

	# 地图上分出国王和封臣 (学三代): 封臣之间的细线、纹章, 选中国王时他的地亮起来, 家族地图模式
	main.close_panel()
	map.focus(w.by_id.oxford.seat, 0.75)
	await _shot("27_地图_封臣和纹章")
	main._on_county_clicked(w.by_id[w.realms.wessex.capital].index)
	await _shot("28_地图_选中国王")
	main.close_panel()
	map.set_mode(MapView.Mode.HOUSE)
	hud.redraw()
	await _shot("29_地图_家族模式")
	map.set_mode(MapView.Mode.REALM)
	map.focus(w.by_id.scone.seat, 1.2)
	await _shot("30_地图_阿尔巴放大")

	# 存档 (照三代: 菜单里随时能存、能读)
	main.save_game("截图用的存档")
	hud._menu()
	await _shot("31_菜单")
	hud._menu_view("save")
	await _shot("32_存档")
	hud._menu_view("load")
	await _shot("33_读档")
	hud.close_popup()
	# 提醒 (照三代的「重要事项」): 屏幕上方正中一排
	var kid2: Person = w.people["aethelhelm"]
	kid2.birth_day = main.clock.day - 7 * 365
	kid2.guardian = ""
	map.show_all()
	hud.redraw()
	await _shot("34_提醒")

	# 第 6 块「打仗」: 玩诺森布里亚 (开局就在跟维京大军打)
	main.new_game({}, 5)
	w = main.world
	map = main.map
	hud = main.hud
	main.play_as("northumbria")
	var me: Person = hud.me()
	var wf := w.warfare
	var war: Dictionary = wf.wars_of(me.id)[0]
	hud._open_army_window()
	await _shot("35_军队窗口")
	hud._choose_row(0)  # 征兵
	var army: Dictionary = wf.army_of(me.id)
	map.selected_army = army.id
	wf.order_move(army, "york")
	hud.close_window()
	main.clock.paused = false
	main.clock.set_speed(3)
	for i in 12:
		main._process(1.0)
	map.focus(w.by_id.york.seat, 1.3)
	hud.redraw()
	await _shot("36_地图_行军")
	var tries := 0
	while wf.battles.is_empty() and tries < 400:
		tries += 1
		if not hud.popup.is_empty():
			hud.close_popup()
		main.clock.paused = false
		main._process(0.2)
	map.focus(w.by_id.york.seat, 1.3)
	hud.redraw()
	await _shot("37_地图_打仗")
	hud._open_war(int(war.id))
	await _shot("38_战争窗口")
	hud.close_window()
	# 围城: 让一支军队停在敌人的地上 (找一场有人在围城的仗)
	tries = 0
	while wf.sieges.is_empty() and tries < 3000:
		tries += 1
		if not hud.popup.is_empty():
			hud.close_popup()
		main.clock.paused = false
		main.clock.set_speed(5)
		main._process(0.2)
	if not wf.sieges.is_empty():
		map.focus(w.by_id[wf.sieges.keys()[0]].seat, 1.3)
	hud.redraw()
	await _shot("39_地图_围城")
	while not hud.popup.is_empty():
		hud.close_popup()
	# 宣战窗口: 对阿尔巴国王
	main.clock.paused = true
	hud.show_person(w.realms.alba.ruler_id)
	hud._open_actions()
	await _shot("40_互动_宣战")
	hud._open_window("declare")
	await _shot("41_宣战窗口")
	hud.close_window()
	hud.close_person()
	# 盟友叫你帮忙 (问你要不要)
	var other: Dictionary = {}
	for x in wf.wars:
		if wf.side(x, me.id) == 0:
			other = x
	if not other.is_empty():
		main.handle_events([{"type": "ally_call", "war": other.id, "ally": me.id, "leader": other.defender, "side": -1, "day": main.clock.day}])
	else:
		hud.show_popup({"kind": "ask", "icon": "rings", "title": "请你帮忙打仗", "lines": ["(这一局没有别的仗)"], "yes": "去帮忙", "no": "不去"})
	await _shot("42_盟友求助")
	hud.close_popup()

	# 第 7 块「阴谋」: 玩威塞克斯, 暗杀麦西亚国王
	main.new_game({"wars": "off"}, 3)
	w = main.world
	map = main.map
	hud = main.hud
	main.play_as("wessex")
	var king: Person = hud.me()
	king.base_skills.intrigue = 14
	king.gold = 300.0
	var vic: Person = w.ruler("mercia")
	hud.show_person(vic.id)
	hud._open_actions()
	await _shot("43_互动_暗杀拉拢")
	var ev2 := []
	var r2 := w.intrigue.start(king, vic, "murder", main.clock.day, ev2)
	var sc: Dictionary = w.intrigue.schemes[int(r2.scheme)]
	hud._open_window("agents", 0, {"scheme": int(sc.id)})
	await _shot("44_拉内应")
	for q in w.intrigue.agent_candidates(sc).slice(0, 2):
		w.intrigue.invite(sc, q, main.clock.day)
	sc.advantages = 3
	sc.progress = 10.0
	hud._open_scheme(int(sc.id))
	await _shot("45_暗杀窗口")
	w.intrigue.start(king, w.ruler("alba"), "sway", main.clock.day, [])
	hud.close_person()
	hud._open_schemes_window()
	await _shot("46_阴谋窗口")
	hud.close_window()
	main.handle_events([{"type": "scheme_revealed", "scheme": 0, "owner": w.ruler("east_anglia").id, "target": king.id, "day": main.clock.day}])
	await _shot("47_有人要暗杀你")
	hud.close_popup()

	# 第 8 块「随机事件和决议」
	main.new_game({"wars": "off"}, 3)
	w = main.world
	map = main.map
	hud = main.hud
	main.play_as("alba")
	hud.me().gold = 400.0
	hud._dec_day = -1
	hud._open_decisions()
	await _shot("48_决议窗口")
	hud.close_window()
	await _shot("49_提醒_能建立王国")
	main.play_as("wessex")
	var me8: Person = hud.me()
	if me8.living_spouse() == null:
		var bride := w.make_noble("anglo_saxon", true, 22, main.clock.day)
		w._register(bride)
		w.marry(me8, bride, main.clock.day, [])
	me8.traits = ["shy", "just", "calm"]
	me8.gold = 10.0  # 送礼要 15: 拍「钱不够」的样子
	var defs := {}
	for d in StoryEvents.defs():
		defs[d.id] = d
	main.handle_events([{"type": "story", "story": w.story.build(defs.neglected_spouse, {"w": w, "me": me8, "day": main.clock.day, "events": [], "sp": me8.living_spouse().id}), "day": main.clock.day}])
	await _shot("50_事件_冷落了家里人")
	hud._pick_story(0)
	main.handle_events([{"type": "story", "story": w.story.build(defs.eclipse_878, {"w": w, "me": me8, "day": main.clock.day, "events": []}), "day": main.clock.day}])
	await _shot("51_事件_日食_历史背景")
	hud._pick_story(0)
	me8.stress = 330.0
	var evb := []
	w.story._check_breaks(main.clock.day, evb)
	main.handle_events(evb)
	await _shot("52_崩溃了")
	hud._pick_story(0)
	me8.traits.append_array(["drunkard", "journaller"])
	StoryEvents.add_trait(me8, "melancholic")
	me8.stress = 180.0
	hud.show_person(me8.id)
	await _shot("53_人物窗口_压力毛病")
	hud.close_person()
	hud._dec_day = -1
	hud._open_decisions()
	await _shot("54_决议_排解压力")
	hud.close_window()

	# 第 9 块「议会」
	main.play_as("mercia")
	hud._open_council_window()
	await _shot("55_议会")
	hud._council_click(4, false)
	await _shot("56_议会_挑宗教大臣")
	hud._open_window("council_task", 0, {"seat": "spymaster"})
	await _shot("57_议会_密探头子的活")
	hud._open_window("council_target", 0, {"seat": "chaplain"})
	await _shot("58_议会_编造宣称的目标")
	hud.close_window()

	# 对犯人的处置 (照三代)
	var me9: Person = hud.me()
	var cap: Person = w.vassals_of(me9)[0]
	cap.prisoner_of = me9.id
	cap.dungeon = true
	hud.show_person(cap.id)
	hud._open_actions()
	await _shot("59_对犯人的处置")
	hud.close_window()
	w.blind(me9, cap, main.clock.day)
	w.torture(me9, cap, main.clock.day, [])
	hud.show_person(cap.id)
	await _shot("60_刺瞎和用刑以后")
	hud.show_person(me9.id)
	await _shot("61_人物窗口_恐惧")
	hud.close_person()

	# 性别法、随母婚
	me9.prestige = 600.0
	hud._open_realm_window()
	await _shot("62_国家窗口_性别法")
	hud.close_window()
	var dau := w.make_noble(me9.culture, true, 17, main.clock.day)
	dau.house = me9.house
	dau.father = me9.id
	w._register(dau)
	hud.show_person(dau.id)
	hud._open_match()
	hud._toggle_matri()
	await _shot("63_说亲_随母婚")
	hud.close_window()
	hud.close_person()
	for file in DirAccess.get_files_at(SaveGame.dir):
		DirAccess.remove_absolute(SaveGame.dir.path_join(file))
	quit()


## 把所有图标和每个国家的纹章排在一张图上
class IconSheet:
	extends Control

	var world: World

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.07, 0.075, 0.09))
		for i in Icons.NAMES.size():
			var c := Vector2(90 + (i % 13) * 142, 110 + (i / 13) * 170)
			draw_rect(Rect2(c - Vector2(60, 60), Vector2(120, 120)), Color(0.12, 0.125, 0.14))
			Icons.draw(self, Icons.NAMES[i], c, 100, Look.GOLD)
			Icons.draw(self, Icons.NAMES[i], c + Vector2(48, 48), 28, Look.GOLD)
			Look.text_center(self, Rect2(c.x - 70, c.y + 62, 140, 24), Icons.NAMES[i], 16, Look.TEXT_DIM, "sans")
		for i in world.realm_order.size():
			var realm: Dictionary = world.realms[world.realm_order[i]]
			var r := Rect2(60 + (i % 13) * 140, 480 + (i / 13) * 290, 90, 110)
			Icons.realm_arms(self, r, realm)
			Look.text_center(self, Rect2(r.position.x - 25, r.end.y + 8, 140, 28), world.realm_name(realm.id), 18, Look.TEXT)


## 所有特点和本事的图标, 下面写名字
class TraitSheet:
	extends Control

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.07, 0.075, 0.09))
		var items := []
		for t in Traits.data().personality:
			items.append([t.id, t.name])
		for t in Traits.data().congenital:
			items.append([t.id, t.name])
		for t in Traits.data().childhood:
			items.append([t.id, t.name])
		for t in Traits.data().coping + Traits.data().stress + Traits.data().physical:
			items.append([t.id, t.name])
		for tr in Traits.data().education.tracks:
			for lv in [1, 4]:
				items.append([{"skill": tr.skill, "level": lv}, Traits.education_name({"skill": tr.skill, "level": lv})])
		for i in items.size():
			var c := Vector2(70 + (i % 18) * 104, 60 + (i / 18) * 112)
			Icons.trait_icon(self, items[i][0], c, 64)
			Look.text_center(self, Rect2(c.x - 52, c.y + 36, 104, 22), items[i][1], 14, Look.TEXT_DIM, "sans")
		for i in Traits.SKILLS.size():
			var c := Vector2(70 + i * 104, 1000)
			Icons.skill_icon(self, Traits.SKILLS[i], c, 64)
			Look.text_center(self, Rect2(c.x - 52, c.y + 36, 104, 22), Traits.skill_info(Traits.SKILLS[i]).name, 14, Look.TEXT_DIM, "sans")
