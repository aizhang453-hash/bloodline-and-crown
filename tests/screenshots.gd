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
