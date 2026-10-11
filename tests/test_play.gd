extends TestCase
## 整个游戏的操作: 不开窗口, 把鼠标键盘的事件交给游戏, 看点了有没有反应。
## 画得对不对要看截图 (screenshots.gd), 这里只管操作。

var main: Node
var world: World
var map: MapView
var hud: Hud


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("bloodline_test_saves_%d" % OS.get_process_id())  # 不碰真的存档
	main = load("res://scenes/main.tscn").instantiate()
	main.allow_quit = false
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	world = main.world
	map = main.map
	hud = main.hud


func after_each() -> void:
	main.free()
	for file in DirAccess.get_files_at(SaveGame.dir) if DirAccess.dir_exists_absolute(SaveGame.dir) else []:
		DirAccess.remove_absolute(SaveGame.dir.path_join(file))


func key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	main._unhandled_key_input(ev)


## 在地图上点一下 (屏幕坐标)
func click_map(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = p
		ev.button_index = button
		ev.pressed = pressed
		map._unhandled_input(ev)


## 点界面上的一个能点的地方 (按位置找; 跟 Godot 一样, 后加的在上面, 先接到点击)
func click_hud(p: Vector2) -> bool:
	var all: Array = hud._spots + hud._alert_spots + hud._war_spots + hud._county_spots + hud._person_spots + hud._window_spots + hud._popup_spots
	all.reverse()
	for s in all:
		if not s.visible or not Rect2(s.position, s.size).has_point(p):
			continue
		if s.on_click.is_valid():
			var ev := InputEventMouseButton.new()
			ev.position = p - s.position
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			s._gui_input(ev)
			return true
		return false  # 上面这一块挡住了, 点不到下面的
	return false


func test_start_state() -> void:
	eq(hud.player, "", "开局还没选国王")
	check(main.clock.paused, "开局是暂停的")
	eq(main.clock.text(), "867 年 1 月 1 日")
	eq(map.mode, MapView.Mode.REALM)


func test_click_county_on_map() -> void:
	var york: Dictionary = world.by_id.york
	map.focus(york.seat, 1.0)
	click_map(map.map_to_screen(york.seat))
	eq(hud.county, york.index, "点约克, 左边开约克的窗口")
	eq(map.selected, york.index)
	click_map(map.map_to_screen(Vector2(20, 20)))
	eq(hud.county, 0, "点海上, 窗口关上")
	eq(map.selected, 0)


func test_drag_is_not_a_click() -> void:
	map.focus(world.by_id.york.seat, 2.0)  # 整张图的宽度放得进画面时横着拖不动, 先放大
	var before := map.camera.position
	var p := map.map_to_screen(world.by_id.york.seat)
	var down := InputEventMouseButton.new()
	down.position = p
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	map._unhandled_input(down)
	var move := InputEventMouseMotion.new()
	move.position = p + Vector2(200, 0)
	move.relative = Vector2(200, 0)
	map._unhandled_input(move)
	var up := down.duplicate()
	up.pressed = false
	up.position = move.position
	map._unhandled_input(up)
	eq(hud.county, 0, "拖地图不算点")
	check(map.camera.position.x < before.x, "往右拖, 地图往右走 (看的地方往左挪)")


func test_wheel_zooms_around_mouse() -> void:
	map.focus(Vector2(900, 1500), 1.0)
	var p := Vector2(1300, 700)
	var spot := map.screen_to_map(p)
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	map._unhandled_input(ev)
	check(map.zoom() > 1.0, "滚轮往上放大")
	check(map.screen_to_map(p).distance_to(spot) < 1.0, "鼠标指着的地方不动")
	for i in 60:
		map._unhandled_input(ev)
	eq(map.zoom(), MapView.ZOOM_MAX, "放大有上限")


func test_cannot_start_time_before_choosing() -> void:
	key(KEY_SPACE)
	check(main.clock.paused, "没选国王, 空格不让时间走")
	has_text(hud._toast, "先")


func test_choose_ruler_and_play() -> void:
	var c: Dictionary = world.by_id.cashel
	main._on_county_clicked(c.index)
	check(click_hud(Vector2(280, 988)), "点「玩这个人」")
	eq(hud.player, "munster", "选了芒斯特")
	has_text(hud._toast, "肯·法拉德")
	key(KEY_SPACE)
	check(not main.clock.paused, "空格让时间走")
	key(KEY_5)
	eq(main.clock.speed, 5)
	main._process(1.0)
	eq(main.clock.text(), "867 年 1 月 31 日", "五档一秒 30 天")
	key(KEY_MINUS)
	eq(main.clock.speed, 4)
	key(KEY_SPACE)
	main._process(1.0)
	eq(main.clock.text(), "867 年 1 月 31 日", "暂停了不走")


func test_faces_in_hud() -> void:
	check(not hud._player_face.visible, "没选国王时左下角没有头像")
	main.play_as("gwynedd")
	check(hud._player_face.visible, "选了国王, 左下角有头像")
	eq(hud._player_face.texture, hud.face(world.ruler("gwynedd")))
	main._on_county_clicked(world.by_id.york.index)
	check(hud._county_face.visible, "领地窗口里有主人的头像")
	check(not hud._player_face.visible, "左边窗口开着时盖住左下角的头像")
	eq(hud._county_face.texture, hud.face(world.ruler("great_army")))
	key(KEY_ESCAPE)
	check(hud._player_face.visible and not hud._county_face.visible, "关了窗口, 左下角的头像回来")


func test_play_button_only_before_choosing() -> void:
	main.play_as("wessex")
	main._on_county_clicked(world.by_id.cashel.index)
	click_hud(Vector2(280, 988))
	eq(hud.player, "wessex", "选好以后不能再换人")


func test_escape_closes_panel() -> void:
	main._on_county_clicked(world.by_id.dublin.index)
	key(KEY_ESCAPE)
	eq(hud.county, 0)
	key(KEY_F1)
	check(hud.show_help, "F1 打开说明")
	key(KEY_ESCAPE)
	check(not hud.show_help, "Esc 先关说明")


func test_map_mode_buttons() -> void:
	check(click_hud(Hud.MODE_SMALL[0]), "点「公」")
	eq(map.mode, MapView.Mode.DUCHY)
	click_hud(Hud.MODE_SMALL[1])
	eq(map.mode, MapView.Mode.KINGDOM)
	click_hud(Hud.MODE_SMALL[2])
	eq(map.mode, MapView.Mode.EMPIRE)
	click_hud(Hud.MODE_BIG)
	eq(map.mode, MapView.Mode.REALM)


func test_unfinished_buttons_say_later() -> void:
	for i in Hud.RIGHT_MENU_Y.size():
		if i in [0, 1, 4]:
			continue  # 「领地」第 5 块、「军队」第 6 块、「阴谋」第 7 块做好了
		var y: float = Hud.RIGHT_MENU_Y[i]
		hud._toast = ""
		check(click_hud(Vector2(1898, y)), "右边按钮 %d" % y)
		has_text(hud._toast, "以后才有")
	hud._toast = ""
	click_hud(Hud.MODE_SMALL[3])
	has_text(hud._toast, "以后才有", "地形地图模式")


func test_speed_boxes() -> void:
	click_hud(Vector2(Hud.SPEED_BOXES_X + 3 * 33 + 10, 1060))
	eq(main.clock.speed, 4, "点第四个格子换四档")


func test_title_shield_focuses_realm() -> void:
	main.play_as("alba")
	map.show_all()
	click_hud(Vector2(30, 1040))
	var scone: Vector2 = world.by_id.scone.seat
	check(map.camera.position.distance_to(scone) < 500, "点盾牌, 地图移到阿尔巴")
	check(map.zoom() > 0.5, "放大一些")


func test_every_county_clickable() -> void:
	map.set_zoom(2.0)
	for c in world.counties:
		map.focus(c.seat)
		click_map(map.map_to_screen(c.seat))
		eq(hud.county, c.index, c.name + " 点得到")


func test_character_window() -> void:
	main.play_as("wessex")
	check(click_hud(Hud.PORTRAIT.get_center()), "点左下角的头像")
	eq(hud.person_id, world.realms.wessex.ruler_id, "打开自己国王的人物窗口")
	check(hud._person_face.visible and not hud._player_face.visible)
	check(not hud._person_spots.is_empty(), "人物窗口里有能指的地方")
	key(KEY_ESCAPE)
	eq(hud.person_id, "", "Esc 关上")
	main._on_county_clicked(world.by_id.york.index)
	check(click_hud(Hud.PANEL_FACE.get_center()), "点领地窗口里主人的头像")
	eq(hud.person_id, world.realms.great_army.ruler_id, "打开伊瓦尔的人物窗口")
	eq(hud.county, 0, "领地窗口让给人物窗口")
	var tips := hud._person_spots.map(func(x: Control) -> String: return x.tooltip_text)
	check(tips.any(func(t: String) -> bool: return t.begins_with("他对你的好感")), "看别人时有好感说明")
	check(tips.any(func(t: String) -> bool: return t.begins_with("健康")), "有健康说明")
	check(click_hud(person_button("国家")), "点「国家」(看看整个维京大军)")
	check(map.camera.position.distance_to(world.by_id.york.seat) < 300)
	main._on_county_clicked(world.by_id.dublin.index)
	eq(hud.person_id, "", "点地图换成领地窗口")
	eq(hud.county, world.by_id.dublin.index)


func test_every_ruler_window_opens() -> void:
	main.play_as("alba")
	for id in world.realm_order:
		hud.show_person(world.realms[id].ruler_id)
		var traits := hud._person_badges(world.ruler(id))
		check(traits.size() >= 4, "%s 至少 3 个性格 + 教育" % world.ruler(id).name)
	hud.close_person()
	eq(hud._person_spots.size(), 0, "关了以后能指的地方清掉")


func test_player_ruler_dies() -> void:
	main.play_as("wessex")
	main.clock.paused = false
	var events := []
	world.kill(world.ruler("wessex"), main.clock.day, events)
	main.handle_events(events)
	eq(hud.popup.get("kind", ""), "succession", "跳出国王去世的窗口")
	check(main.clock.paused, "游戏暂停")
	eq(hud.player, "wessex", "还是玩威塞克斯")
	eq(world.ruler("wessex").name, "阿尔弗雷德", "现在是阿尔弗雷德")
	key(KEY_SPACE)
	check(hud.popup.is_empty(), "空格关上窗口")
	check(main.clock.paused, "关窗口不会顺手让时间走")
	eq(hud._player_face.texture, hud.face(world.ruler("wessex")), "左下角换成阿尔弗雷德的头像")


func test_game_over_when_house_dies_out() -> void:
	main.play_as("east_anglia")
	for c in world.children_of(world.ruler("east_anglia")):  # 开局生成的儿子先死
		world.kill(c, main.clock.day, [])
	var events := []
	world.kill(world.ruler("east_anglia"), main.clock.day, events)
	main.handle_events(events)
	eq(hud.popup.get("kind", ""), "game_over", "埃德蒙没有儿子了, 游戏结束")
	check(click_hud(Hud.POPUP_BUTTON.get_center()), "点「换一个国王接着玩」")
	eq(hud.player, "", "可以重新选国王")
	main._on_county_clicked(world.by_id.norwich.index)
	check(click_hud(Vector2(280, 988)), "点「玩这个人」")
	eq(hud.player, "east_anglia", "接着玩东盎格利亚的新国王")


func test_other_kings_death_is_a_message() -> void:
	main.play_as("wessex")
	var events := []
	world.kill(world.ruler("mercia"), main.clock.day, events)
	main.handle_events(events)
	check(hud.popup.is_empty(), "别国的事不跳窗口")
	eq(hud._notes.size(), 1)
	has_text(hud._notes[0][0], "伯格雷德")


func test_partition_redraws_map() -> void:
	main.play_as("gwynedd")
	var events := []
	world.kill(world.ruler("gwynedd"), main.clock.day, events)
	main.handle_events(events)
	var powys: String = world.people["gwriad"].realm
	var c: Dictionary = world.by_id.mathrafal
	eq(c.holder, powys)
	var shown := map._lookup.get_pixel(c.index, 0)
	var want: Color = world.realms[powys].color
	check(absf(shown.r - want.r) + absf(shown.g - want.g) + absf(shown.b - want.b) < 0.02, "地图上波伊斯换了颜色")
	eq(hud.player, "gwynedd", "玩家拿主要的王国")


func test_family_row_and_heir_in_window() -> void:
	main.play_as("gwynedd")
	hud.show_person("ruler_gwynedd")
	eq(hud._family.size(), Hud.FAMILY_MAX, "家人超过 8 个只显示 8 个")
	eq(hud._family[0], "merfyn_frych", "第一个是父亲")
	check(click_hud(Hud.CHAR_HEIR.get_center()), "点继承人")
	eq(hud.person_id, "anarawd", "打开继承人安纳拉乌德")
	check(click_hud(hud._family_rect(0).get_center()), "点家人的头像")
	eq(hud.person_id, "ruler_gwynedd", "安纳拉乌德的第一个家人是父亲罗德里")


# ---- 第 4 块: 说亲、教育、生孩子起名 ----

## 人物窗口下面那一排按钮里, 叫 label 的那个的中间
func person_button(label: String) -> Vector2:
	var p: Person = world.people[hud.person_id]
	var buttons := hud._person_buttons(p)
	for i in buttons.size():
		if String(buttons[i][0]).contains(label):
			return hud._button_rect(i, buttons.size()).get_center()
	return Vector2(-1, -1)


func test_arrange_marriage_from_person_panel() -> void:
	main.play_as("wessex")
	hud.show_person("alfred")
	var at := person_button("说亲")
	check(at.x > 0, "阿尔弗雷德没结婚, 有说亲按钮")
	check(click_hud(at))
	eq(hud.window.get("kind", ""), "match", "开了说亲窗口")
	var rows: Array = hud.window.rows
	check(rows.size() > 3, "有不少能说的人")
	eq(rows[0].person.id, "ealhswith", "史料里的配偶排在最前面")
	for r in rows:
		check(Marriage.problem(world, world.people["alfred"], r.person, main.clock.day, true) == "", "名单里都是能结的")
	# 点第一行: 埃尔斯维斯
	check(click_hud(hud._win_row_rect(0).get_center()))
	if rows[0].acc.total > 0:
		# 埃尔斯维斯开局 15 岁: 先订婚, 都满 16 岁再成亲
		eq(world.people["alfred"].betrothed, "ealhswith", "点了就订婚")
		check(hud.window.is_empty(), "订完婚窗口关上")
		eq(person_button("说亲"), Vector2(-1, -1), "订了婚就没有说亲按钮了")
		check(hud._family.has("ealhswith"), "家人那一排有未婚妻")
	key(KEY_ESCAPE)


func test_match_window_tabs_and_pages() -> void:
	main.play_as("wessex")
	hud.show_person("alfred")
	hud._open_match()
	check(click_hud(hud._win_tab_rect(1, 3).get_center()))
	eq(hud.window.tab, 1, "按身份排")
	var st: Array = hud.window.rows.map(func(r: Dictionary) -> int: return r.status)
	for i in st.size() - 1:
		check(st[i] >= st[i + 1], "身份高的在前")
	if hud._win_pages() > 1:
		check(click_hud(Rect2(WINDOW_NEXT(), Vector2(10, 10)).position))
		eq(hud.window.page, 1, "翻到第二页")
	key(KEY_ESCAPE)
	check(hud.window.is_empty(), "Esc 先关说亲窗口")
	check(hud.person_id != "", "人物窗口还开着")


func WINDOW_NEXT() -> Vector2:
	return Vector2(Hud.WINDOW.end.x - 120, Hud.WINDOW.end.y - 40)


func test_choose_teacher() -> void:
	main.play_as("wessex")
	var kid: Person = world.people["aethelhelm"]
	kid.birth_day = main.clock.day - 7 * 365
	world._grow(kid, main.clock.day, [])
	hud.show_person("aethelhelm")
	var at := person_button("教育")
	check(at.x > 0, "7 岁的孩子有教育按钮")
	check(click_hud(at))
	eq(hud.window.get("kind", ""), "teacher")
	check(click_hud(hud._win_tab_rect(4, 5).get_center()))
	eq(kid.focus, "learning", "改学学识")
	var rows: Array = hud.window.rows
	check(not rows.is_empty())
	var last: Person = rows[rows.size() - 1].person
	check(click_hud(hud._win_row_rect(mini(rows.size() - 1, Hud.WIN_ROWS - 1)).get_center()))
	if rows.size() <= Hud.WIN_ROWS:
		eq(kid.guardian, last.id, "请了点的那个人当老师")
	check(hud._school_tip(kid).contains("老师"))


func test_birth_popup_and_naming() -> void:
	main.play_as("wessex")
	var king := world.ruler("wessex")
	var queen: Person = world.people["wulfthryth"]
	queen.pregnant = {"father": king.id, "due": main.clock.day}
	var events := []
	world._give_birth(queen, main.clock.day, events)
	main.handle_events(events)
	eq(hud.popup.get("kind", ""), "birth", "你的孩子出生跳窗口")
	check(main.clock.paused, "游戏暂停")
	var baby: Person = world.people[hud.popup.child]
	var names: Array = hud.popup.names
	eq(names[0], baby.name, "第一个是现在的名字")
	check(names.size() >= 4, "有几个名字可以挑")
	check(names.has(king.name) or baby.female, "儿子可以用父亲的名字")
	check(click_hud(hud._name_rect(2).get_center()))
	eq(baby.name, names[2], "点了哪个就叫哪个")
	check(hud.popup.is_empty() or hud.popup.child != baby.id, "起完名窗口关上")


func test_birth_popup_enter_keeps_name() -> void:
	main.play_as("wessex")
	var king := world.ruler("wessex")
	var queen: Person = world.people["wulfthryth"]
	queen.pregnant = {"father": king.id, "due": main.clock.day}
	var events := []
	world._give_birth(queen, main.clock.day, events)
	main.handle_events(events)
	var baby: Person = world.people[hud.popup.child]
	var before := baby.name
	key(KEY_ENTER)
	eq(baby.name, before, "回车就用第一个名字")


func test_allies_shown_for_rulers() -> void:
	main.play_as("wessex")
	hud.show_person(world.realms.wessex.ruler_id)
	var tip := ""
	for s in hud._person_spots:
		if Rect2(s.position, s.size) == Hud.CHAR_ALLIES:
			tip = s.tooltip_text
	has_text(tip, "麦西亚", "人物窗口写着同盟")


## 你的国王的妻子生个孩子, 跳起名窗口, 返回孩子
func baby_popup() -> Person:
	main.play_as("wessex")
	var king := world.ruler("wessex")
	var queen: Person = world.people["wulfthryth"]
	queen.pregnant = {"father": king.id, "due": main.clock.day}
	var events := []
	world._give_birth(queen, main.clock.day, events)
	main.handle_events(events)
	return world.people[hud.popup.child]


func test_type_your_own_name() -> void:
	var baby := baby_popup()
	check(hud.name_edit != null, "起名窗口有自己写名字的框")
	eq(hud.name_edit.max_length, Hud.NAME_MAX)
	hud.name_edit.text = "  阿特尔斯坦  "
	hud.name_edit.text_submitted.emit(hud.name_edit.text)
	eq(baby.name, "阿特尔斯坦", "按回车就用自己写的名字 (前后空格去掉)")
	check(hud.name_edit == null, "起完名窗口关上")


func test_typed_name_with_button() -> void:
	var baby := baby_popup()
	hud.name_edit.text = "小王子"
	check(click_hud(Hud.NAME_OK.get_center()), "点「就叫这个」")
	eq(baby.name, "小王子")


func test_empty_typed_name_keeps_first() -> void:
	var baby := baby_popup()
	var first: String = hud.popup.names[0]
	hud.name_edit.text = "   "
	hud.name_edit.text_submitted.emit(hud.name_edit.text)
	eq(baby.name, first, "什么都没写就用第一个名字")


# ---- 第 5 块: 封臣 ----

func test_realm_window_and_grant() -> void:
	main.play_as("wessex")
	check(click_hud(Vector2(1898, Hud.RIGHT_MENU_Y[0])), "点右边的「领地」")
	eq(hud.window.get("kind", ""), "realm", "开了你的国家")
	var rows: Array = hud.window.rows
	check(rows.any(func(r: Dictionary) -> bool: return r.type == "vassal"), "有封臣")
	check(rows.any(func(r: Dictionary) -> bool: return r.type == "duchy"), "有能封副王的公国头衔 (肯特……)")
	var i := -1
	for k in rows.size():
		if rows[k].type == "county" and not rows[k].capital:
			i = k
			break
	check(i >= 0, "有能封出去的直辖领地")
	var c: Dictionary = rows[i].county
	check(click_hud(hud._win_row_rect(i).get_center()))
	eq(hud.window.get("kind", ""), "grant", "选给谁")
	check(not hud.window.rows.is_empty())
	var target: Person = hud.window.rows[0].person
	check(click_hud(hud._win_row_rect(0).get_center()))
	eq(c.lord, target.id, "封出去了")
	eq(hud.window.get("kind", ""), "realm", "回到你的国家")


func test_actions_gift_and_arrest() -> void:
	main.play_as("wessex")
	var me := world.ruler("wessex")
	me.gold = 100
	hud.show_person("wulfhere_wiltshire")
	var at := person_button("互动")
	check(at.x > 0, "对自己的封臣有互动按钮")
	check(click_hud(at))
	eq(hud.window.get("kind", ""), "actions")
	var names: Array = hud.window.rows.map(func(r: Dictionary) -> String: return r.name)
	for n in ["送礼", "收回领地", "关进大牢"]:
		check(names.has(n), "能" + n)
	check(click_hud(hud._win_row_rect(names.find("送礼")).get_center()))
	eq(me.gold, 75.0, "送礼花了 25 金币")
	names = hud.window.rows.map(func(r: Dictionary) -> String: return r.name)
	var arrest := names.find("关进大牢")
	me.base_skills.intrigue = 60
	check(click_hud(hud._win_row_rect(arrest).get_center()))
	eq(world.people["wulfhere_wiltshire"].prisoner_of, "", "狠的事点一次还不算")
	eq(hud.window.armed, arrest)
	# 抓人有机会失败 (最多 95%): 先把随机数定在一个抓得到的种子上
	for seed in range(1, 100):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed
		if probe.randf() < 0.9:
			world.rng.seed = seed
			break
	check(click_hud(hud._win_row_rect(arrest).get_center()))
	eq(world.people["wulfhere_wiltshire"].prisoner_of, me.id, "点两次关起来了")
	names = hud.window.rows.map(func(r: Dictionary) -> String: return r.name)
	check(names.has("放了他") and names.has("处死"), "关着的人能放、能处死")


func test_play_as_vassal() -> void:
	main._on_county_clicked(world.by_id.berkshire.index)
	eq(hud._county_face.texture, hud.face(world.people["aethelwulf_berkshire"]), "领地窗口的主人是郡长")
	check(click_hud(Vector2(280, 988)), "点「玩这个人」")
	eq(hud.player_id, "aethelwulf_berkshire", "玩伯克郡郡长")
	eq(hud.player, "wessex", "他在威塞克斯")
	eq(world.player, "aethelwulf_berkshire")
	check(hud._player_face.visible or hud.county != 0)
	var tip := ""
	for s in hud._res_spots:
		tip += s.tooltip_text
	has_text(tip, "交给上面", "钱的说明写着交给国王多少")
	hud._open_realm_window()
	eq(hud.window.rows[0].type, "liege", "你的领地窗口先写效忠谁")


func test_vassal_player_succession_and_game_over() -> void:
	main.play_as("aethelwulf_berkshire")
	var v: Person = world.people["aethelwulf_berkshire"]
	var son := Person.new()
	son.id = "test_son"
	son.name = "测试儿子"
	son.father = v.id
	son.house = v.house
	son.culture = v.culture
	son.birth_day = main.clock.day - 20 * GameDate.YEAR_DAYS
	son.traits = Traits.random_personality(world.rng)
	son.education = {"skill": "martial", "level": 2}
	son.dna = Portrait.random_dna(world.rng, son.culture)
	for c in world.children_of(v):  # 开局生成的孩子先死, 只留测试的儿子
		world.kill(c, main.clock.day, [])
	world._register(son)
	var events := []
	world.kill(v, main.clock.day, events)
	main.handle_events(events)
	eq(hud.popup.get("kind", ""), "vassal_succession", "你的郡长去世跳窗口")
	eq(hud.player_id, "test_son", "接着玩儿子")
	hud.close_popup()
	events = []
	world.kill(son, main.clock.day, events)
	main.handle_events(events)
	eq(hud.popup.get("kind", ""), "vassal_over", "家族没地了, 游戏结束")
	hud.close_popup()
	eq(hud.player_id, "", "可以换一个人")


func test_king_player_death_follows_heir_person() -> void:
	main.play_as("wessex")
	var events := []
	world.kill(world.ruler("wessex"), main.clock.day, events)
	main.handle_events(events)
	eq(hud.player_id, "alfred", "玩家换成继承人这个人")
	eq(world.player, "alfred")


## 游戏里不写谁是史料里的、谁是随机生成的 (用户 2026-10-10 说的), 也不提「三代」
func no_meta(where: String) -> void:
	for s in hud._spots + hud._county_spots + hud._person_spots + hud._window_spots + hud._popup_spots:
		for word in ["随机", "史料", "三代", "查不到"]:
			check(not s.tooltip_text.contains(word), "%s 的说明里有「%s」: %s" % [where, word, s.tooltip_text.left(60)])


func test_no_random_or_history_labels() -> void:
	main._on_county_clicked(world.by_id.wigtown.index)  # 加洛韦: 开局随机的统治者
	no_meta("领地窗口")
	main.play_as("wessex")
	for id in ["alfred", world.realms.galloway.ruler_id, world.by_id.devon.lord, "ealhswith", world.realms.wessex.ruler_id]:
		hud.show_person(id)
		no_meta("人物窗口 " + id)
	hud.show_person("alfred")
	hud._open_match()
	no_meta("说亲窗口")
	hud.close_window()
	hud.show_person(world.by_id.devon.lord)
	hud._open_actions()
	no_meta("互动窗口")
	hud._open_realm_window()
	no_meta("国家窗口")
	hud.close_window()
	hud.open_rules()
	no_meta("开局设置")
	hud.close_popup()


func test_cannot_arrange_for_landed_relative() -> void:
	main.play_as("wessex")
	var k := world.ruler("wessex")
	hud.show_person("alfred")
	check(person_button("说亲").x > 0, "没领地的弟弟: 你给他说亲")
	var dom := world.lands_of(k)
	world.grant_county(k, dom[dom.size() - 1], world.people["alfred"], main.clock.day, [])
	hud.show_person("alfred")
	eq(person_button("说亲"), Vector2(-1, -1), "封了领地: 他自己找对象")
	hud.show_person(k.id)
	if not k.married():
		check(person_button("说亲").x > 0, "你自己的婚事你管")


# ---- 地图上分出国王和封臣 (学三代) ----

func test_map_shows_lords() -> void:
	var lords := {}
	map.set_mode(MapView.Mode.REALM)
	for c in world.counties:
		lords[c.lord] = map._lookup.get_pixel(c.index, 2)
	var ws := world.counties_of("wessex")
	var a: Dictionary = ws[0]
	var b: Dictionary = world.by_id.berkshire
	check(map._lookup.get_pixel(a.index, 2) != map._lookup.get_pixel(b.index, 2), "国王和伯克郡郡长的地之间画线 (主人不一样)")
	var shields: Array = map.overlay.shields()
	var who := shields.map(func(sh: Dictionary) -> String: return sh.person.id)
	check(who.has(world.realms.wessex.ruler_id) and who.has("aethelwulf_berkshire"), "国王和郡长都有纹章")
	for sh in shields:
		if sh.person.id == world.realms.wessex.ruler_id:
			check(sh.king, "国王的纹章带王冠")


func test_map_focus_highlights_domain() -> void:
	map.set_mode(MapView.Mode.REALM)
	var cap: Dictionary = world.by_id[world.realms.wessex.capital]
	var berk: Dictionary = world.by_id.berkshire
	var york: Dictionary = world.by_id.york
	var plain_cap := map._lookup.get_pixel(cap.index, 0)
	var plain_york := map._lookup.get_pixel(york.index, 0)
	main._on_county_clicked(cap.index)
	eq(map.focus_person, world.realms.wessex.ruler_id, "点国王的地: 选中国王")
	check(map._lookup.get_pixel(cap.index, 0).v > plain_cap.v, "国王直辖的地亮起来")
	check(map._lookup.get_pixel(york.index, 0).v < plain_york.v, "别的国家暗下去")
	var berk_col := map._lookup.get_pixel(berk.index, 0)
	check(berk_col.v < map._lookup.get_pixel(cap.index, 0).v, "郡长的地比国王直辖的暗")
	main.close_panel()
	eq(map.focus_person, "", "关了窗口就不选了")
	hud.show_person("aethelwulf_berkshire")
	eq(map.focus_person, "aethelwulf_berkshire", "看郡长的人物窗口: 选中郡长")


func test_house_map_mode() -> void:
	check(click_hud(Hud.MODE_SMALL[6]), "点「家族」地图模式")
	eq(map.mode, MapView.Mode.HOUSE)
	var a: Color = map._lookup.get_pixel(world.by_id[world.realms.wessex.capital].index, 0)
	var b: Color = map._lookup.get_pixel(world.by_id.berkshire.index, 0)
	check(not a.is_equal_approx(b), "国王家族和郡长家族颜色不一样")
	var texts: Array = map.overlay._groups().map(func(g: Dictionary) -> String: return g.text)
	check(texts.has(world.house_name(world.people["aethelwulf_berkshire"].house)), "地图上写着家族的名字")


# ---- 存档 (照三代: 菜单里随时能存、能读) ----

func test_menu_save_and_load() -> void:
	main.play_as("wessex")
	main.clock.paused = false
	check(click_hud(Vector2(1347, 1060)), "点右下角的「≡」菜单")
	eq(hud.popup.get("kind", ""), "menu")
	check(main.clock.paused, "打开菜单游戏暂停")
	check(click_hud(hud._menu_button(1).get_center()), "点「存档」")
	eq(hud.popup.view, "save")
	hud.name_edit.text = "我的第一个存档"
	hud.name_edit.text_submitted.emit(hud.name_edit.text)
	check(hud.popup.is_empty(), "存好了菜单关上")
	eq(SaveGame.list().size(), 1)
	var alfred_before: String = world.people["alfred"].name
	# 走几个月, 再读回来
	main.clock.paused = false
	for i in 20:
		main._process(1.0)
	var day_after: int = main.clock.day
	check(click_hud(Vector2(1347, 1060)))
	check(click_hud(hud._menu_button(2).get_center()), "点「读档」")
	eq(hud.popup.view, "load")
	check(click_hud(hud._menu_row(0).get_center()), "点一次")
	eq(main.clock.day, day_after, "点一次还不读")
	check(click_hud(hud._menu_row(0).get_center()), "再点一次读档")
	world = main.world
	hud = main.hud
	map = main.map
	eq(main.clock.day, world.start_day, "回到存档的那天")
	eq(hud.player_id, world.realms.wessex.ruler_id, "还是玩威塞克斯国王")
	eq(world.people["alfred"].name, alfred_before)
	check(main.clock.paused, "读完是暂停的")


func test_autosave_each_year() -> void:
	main.play_as("wessex")
	main.clock.paused = false
	main.clock.set_speed(5)
	while GameDate.from_day(main.clock.day)[0] == 867:
		if not hud.popup.is_empty():
			hud.close_popup()  # 打仗的弹窗 (盟友叫你帮忙……) 会暂停, 关掉接着走
			main.clock.paused = false
		main._process(1.0)
	check(SaveGame.list().any(func(x: Dictionary) -> bool: return x.auto), "到 868 年自动存了一次档")


# ---- 提醒 (照三代的「重要事项」) ----

func alert(kind: String) -> Dictionary:
	hud.redraw()
	for a in hud.alerts:
		if a.kind == kind:
			return a
	return {}


func test_alerts() -> void:
	eq(hud.alerts.size(), 0, "没选人时没有提醒")
	main.play_as("wessex")
	var k := world.ruler("wessex")
	check(not alert("marry").is_empty(), "阿尔弗雷德成年没结婚: 有提醒")
	has_text(alert("marry").tip, "阿尔弗雷德")
	# 孩子没有老师
	var kid: Person = world.people["aethelhelm"]
	kid.birth_day = main.clock.day - 7 * 365
	kid.guardian = ""
	check(not alert("teacher").is_empty(), "7 岁的孩子没有老师: 有提醒")
	var idx := -1
	for i in hud.alerts.size():
		if hud.alerts[i].kind == "teacher":
			idx = i
	var r := hud._alert_rect(idx, hud.alerts.size())
	check(click_hud(r.get_center()), "点提醒")
	eq(hud.person_id, "aethelhelm")
	eq(hud.window.get("kind", ""), "teacher", "直接打开请老师的窗口")
	# 直辖超过上限
	for c in world.counties_of("wessex"):
		c.lord = k.id
	world._feudal_dirty = true
	check(not alert("domain").is_empty(), "直辖超过上限: 有提醒")
	# 大牢
	world.people["wulfhere_wiltshire"].prisoner_of = k.id
	check(not alert("prison").is_empty(), "有人关在大牢里: 有提醒")
	world.people["wulfhere_wiltshire"].prisoner_of = ""
	check(alert("prison").is_empty(), "放了就没了")


func test_player_kids_get_no_automatic_teacher() -> void:
	# 照三代 (也是第 4 块清单写的): 你家孩子的老师你请, 电脑家的自动请
	main.play_as("wessex")
	var kid: Person = world.people["aethelhelm"]
	kid.birth_day = main.clock.day - 6 * 365 - 10
	kid.guardian = ""
	kid.edu_years = 0
	world._grow(kid, main.clock.day, [])
	eq(kid.guardian, "", "你家孩子不自动请老师")
	check(kid.focus != "", "学什么自动选了 (可以改)")
	var other: Person = world.people["owain_g"]  # 格利维辛国王的儿子
	other.guardian = ""
	world._grow(other, main.clock.day, [])
	check(other.guardian != "", "电脑家的孩子自动请老师")


# ---- 开局设置 ----

func test_rules_window_before_start() -> void:
	var seed := world.name_seed
	check(click_hud(Hud.RULES_BUTTON.get_center()), "点横幅下面的「开局设置」")
	eq(hud.popup.get("kind", ""), "rules")
	check(click_hud(hud._rule_option(0, 2).get_center()), "生成家人选「关」")
	world = main.world
	hud = main.hud
	map = main.map
	eq(world.rules.generate_families, "off")
	eq(world.name_seed, seed, "同一个种子重新开局")
	check(not world.ruler("east_anglia").married())
	eq(hud.popup.get("kind", ""), "rules", "设置窗口还开着")
	check(click_hud(hud._menu_back().get_center()), "开始选人")
	main.play_as("wessex")
	hud.open_rules()
	check(click_hud(hud._rule_option(0, 0).get_center()))
	eq(world.rules.generate_families, "off", "开始以后不能改")


func test_ironman_menu() -> void:
	main.new_game({"ironman": "on"}, 5)
	world = main.world
	hud = main.hud
	map = main.map
	main.play_as("wessex")
	hud._menu()
	check(click_hud(hud._menu_button(1).get_center()), "点存档")
	eq(hud.popup.view, "main", "铁人模式不能自己存档")
	has_text(hud._toast, "铁人模式")
	hud.close_popup()
	main.clock.paused = false
	main.clock.set_speed(5)
	while GameDate.from_day(main.clock.day)[1] < 7:
		if not hud.popup.is_empty():
			hud.close_popup()
			main.clock.paused = false
		main._process(1.0)
	check(SaveGame.list().any(func(x: Dictionary) -> bool: return x.label == "铁人模式"), "过了半年自动存了铁人模式的档")


# ---- 打仗 (第 6 块) ----

func row_named(prefix: String) -> int:
	for i in hud.window.get("rows", []).size():
		var r: Dictionary = hud.window.rows[i]
		if r.has("name") and String(r.name).begins_with(prefix):
			return i
	return -1


func test_army_window_raise_and_move() -> void:
	main.play_as("wessex")
	check(click_hud(Vector2(1898, Hud.RIGHT_MENU_Y[1])), "右边一列第二个「军队」")
	eq(hud.window.get("kind", ""), "army")
	var i := row_named("征兵")
	check(i >= 0, "有征兵")
	check(click_hud(hud._win_row_rect(i).get_center()))
	var a := world.warfare.army_of(hud.player_id)
	check(not a.is_empty(), "征了兵")
	eq(map.selected_army, int(a.id), "征了兵就选中了")
	check(row_named("解散军队") >= 0, "窗口里能解散")
	# 右键点伦敦: 军队走过去
	map.focus(world.by_id.london.seat, 1.0)
	click_map(map.map_to_screen(world.by_id.london.seat), MOUSE_BUTTON_RIGHT)
	check(not a.path.is_empty(), "右键点了地, 军队有路要走")
	eq(a.path[a.path.size() - 1][0], "london", "去伦敦")
	has_text(hud._toast, "去伦敦")
	# 点军队的小牌子也能选中
	map.selected_army = -1
	map.focus(world.warfare.army_pos(a), 1.0)
	click_map(map.army_rect(a).get_center())
	eq(map.selected_army, int(a.id), "点牌子选中了")
	key(KEY_ESCAPE)
	eq(map.selected_army, -1, "Esc 不选了")


func test_declare_war_from_actions() -> void:
	main.new_game({"wars": "off"}, 3)
	world = main.world
	hud = main.hud
	map = main.map
	main.play_as("isles")
	var me := hud.me()
	hud.show_person(world.realms.man.ruler_id)
	check(click_hud(person_button("互动")))
	var i := row_named("宣战")
	check(i >= 0, "互动里有宣战")
	check(click_hud(hud._win_row_rect(i).get_center()))
	eq(hud.window.get("kind", ""), "declare", "打开宣战窗口")
	var j := row_named("征服")
	check(j >= 0, "维京人能征服")
	check(click_hud(hud._win_row_rect(j).get_center()))
	check(world.warfare.wars.is_empty(), "点一次还不算")
	check(click_hud(hud._win_row_rect(j).get_center()))
	eq(world.warfare.wars.size(), 1, "点两次宣战了")
	eq(hud.window.get("kind", ""), "war", "接着打开战争窗口")
	hud.redraw()
	eq(hud._war_spots.size(), 1, "右上角多了这场仗的小图标")
	check(me.prestige < War.START_PRESTIGE_KING, "花了威望")
	# 投降 (点两次)
	var k := row_named("投降")
	check(click_hud(hud._win_row_rect(k).get_center()))
	check(click_hud(hud._win_row_rect(k).get_center()))
	check(world.warfare.wars.is_empty(), "投降了, 仗打完了")
	eq(hud.popup.get("kind", ""), "info", "弹窗说仗打完了")
	has_text(hud.popup.title, "打输了")


func test_war_declared_on_player_pauses() -> void:
	main.new_game({"wars": "off"}, 3)
	world = main.world
	hud = main.hud
	main.play_as("man")
	main.clock.paused = false
	var att := world.ruler("isles")
	var o: Dictionary = {}
	for x in world.warfare.cb_options(att, hud.me()):
		if x.cb == "conquest":
			o = x
	var ev := []
	world.warfare.declare(att, o, main.clock.day, ev)
	main.handle_events(ev)
	check(main.clock.paused, "有人向你宣战, 暂停")
	has_text(hud.popup.title, "向你宣战")
	hud.close_popup()
	hud.redraw()
	eq(hud._war_spots.size(), 1)


func test_ally_call_popup() -> void:
	main.new_game({"wars": "off"}, 3)
	world = main.world
	hud = main.hud
	main.play_as("wessex")
	var wf := world.warfare
	var ev := []
	wf.declare(world.ruler("great_army"), {"cb": "conquest", "target": "nottingham", "targets": ["nottingham"], "claimant": "", "cost": 0.0,
			"label": "抢诺丁汉", "defender": world.ruler("mercia").id, "ok": true, "why": "", "truce": false}, main.clock.day, ev, true)
	main.handle_events(ev)
	eq(hud.popup.get("kind", ""), "ask", "盟友麦西亚挨打了, 问你去不去")
	check(click_hud(Hud.ASK_BUTTONS[0].get_center()), "点「去帮忙」")
	check(wf.wars[0].defenders.has(hud.player_id), "加入了防守方")


# ---- 阴谋 (第 7 块) ----

func test_murder_scheme_from_actions() -> void:
	main.new_game({"wars": "off"}, 3)
	world = main.world
	hud = main.hud
	main.play_as("wessex")
	var me := hud.me()
	me.base_skills.intrigue = 30
	var t := world.ruler("mercia")
	hud.show_person(t.id)
	check(click_hud(person_button("互动")))
	var i := row_named("暗杀")
	check(i >= 0, "互动里有暗杀")
	check(click_hud(hud._win_row_rect(i).get_center()))
	check(world.intrigue.schemes.is_empty(), "点一次还不算")
	check(click_hud(hud._win_row_rect(i).get_center()))
	var s := world.intrigue.scheme_of(me.id, "murder")
	check(not s.is_empty(), "开始暗杀了")
	eq(hud.window.get("kind", ""), "scheme", "打开这个阴谋")
	# 拉内应
	var j := row_named("拉内应")
	check(click_hud(hud._win_row_rect(j).get_center()))
	eq(hud.window.get("kind", ""), "agents")
	check(not hud.window.rows.is_empty(), "有能拉的人")
	me.gold = 500.0
	check(click_hud(hud._win_row_rect(0).get_center()))
	eq(hud.window.get("kind", ""), "scheme", "拉完回到阴谋窗口")
	# 右边一列「阴谋」
	hud.close_window()
	check(click_hud(Vector2(1898, Hud.RIGHT_MENU_Y[4])), "右边一列第五个「阴谋」")
	eq(hud.window.get("kind", ""), "schemes")
	check(row_named("暗杀") >= 0, "阴谋窗口里有这个暗杀")
	# 攒够机会: 提醒, 动手
	s.advantages = Schemes.READY
	hud.redraw()
	check(hud.alerts.any(func(a: Dictionary) -> bool: return a.kind == "scheme_ready"), "提醒可以动手")
	hud._open_scheme(int(s.id))
	var k := row_named("动手")
	check(click_hud(hud._win_row_rect(k).get_center()))
	check(click_hud(hud._win_row_rect(k).get_center()))
	check(not world.intrigue.schemes.has(int(s.id)), "动手了, 阴谋结束")


func test_blackmail_popup() -> void:
	main.new_game({"wars": "off"}, 3)
	world = main.world
	hud = main.hud
	main.play_as("wessex")
	var me := hud.me()
	var k := world.ruler("mercia")
	me.secrets.append({"type": "murder", "target": world.ruler("alba").id, "day": main.clock.day, "known": [k.id], "exposed": false})
	var ev := []
	world.intrigue.blackmail(k, me, me.secrets[0], main.clock.day, ev)
	main.handle_events(ev)
	eq(hud.popup.get("kind", ""), "ask", "被勒索: 问你给不给把柄")
	check(click_hud(Hud.ASK_BUTTONS[0].get_center()), "给他把柄")
	check(world.intrigue.held_by(me, k), "他攥着你的把柄了")
	check(world.warfare.cb_options(me, k).all(func(o: Dictionary) -> bool: return not o.ok), "不能对他宣战了")


# ---- 第 8 块: 决议、随机事件 ----

func test_decisions_window() -> void:
	main.play_as("alba")
	var k := world.ruler("alba")
	k.gold = 400.0
	var c: Vector2 = Hud.BOTTOM_ROW[3][0]
	check(click_hud(c), "左下角最右边的「决议」能点")
	eq(hud.window.get("kind", ""), "decisions")
	var i := -1
	for j in hud.window.rows.size():
		if hud.window.rows[j].id == "kingdom:scotland":
			i = j
	check(i >= 0, "列出建立苏格兰王国")
	var rect := hud._win_row_rect(i)
	click_hud(rect.get_center())
	eq(world.title_holder("kingdom", "scotland"), "", "要点两次")
	click_hud(rect.get_center())
	eq(world.title_holder("kingdom", "scotland"), "alba", "点两次就建立了")
	eq(world.realms.alba.title, "苏格兰国王")
	no_meta("决议窗口")


func test_decision_alert() -> void:
	main.play_as("alba")
	world.ruler("alba").gold = 400.0
	hud._dec_day = -1
	var kinds: Array = hud.alerts_now().map(func(a: Dictionary) -> String: return a.kind)
	check(kinds.has("decision"), "能建立王国: 上方有提醒 %s" % str(kinds))


func test_story_popup_click() -> void:
	main.play_as("wessex")
	var me := hud.me()
	var d := {}
	for x in StoryEvents.defs():
		if x.id == "wandering_poet":
			d = x
	me.gold = 0.0
	var s := world.story.build(d, {"w": world, "me": me, "day": main.clock.day, "events": []})
	main.clock.paused = false
	main.handle_events([{"type": "story", "story": s, "day": main.clock.day}])
	eq(hud.popup.get("kind", ""), "story", "事件弹窗")
	check(main.clock.paused, "弹窗时暂停")
	no_meta("事件窗口")
	click_hud(hud.story_option_rect(0, s.options.size()).get_center())
	eq(hud.popup.get("kind", ""), "story", "钱不够: 点了没用")
	me.gold = 50.0
	var g0 := me.gold
	check(click_hud(hud.story_option_rect(0, s.options.size()).get_center()), "点第一个办法")
	check(hud.popup.is_empty(), "选了就关上")
	eq(me.gold, g0 - 10.0, "赏了诗人 10 金币")


func test_story_keys_and_history() -> void:
	main.play_as("wessex")
	var me := hud.me()
	var d := {}
	for x in StoryEvents.defs():
		if x.id == "eclipse_878":
			d = x
	var s := world.story.build(d, {"w": world, "me": me, "day": main.clock.day, "events": []})
	main.handle_events([{"type": "story", "story": s, "day": main.clock.day}])
	var book := false
	for sp in hud._popup_spots:
		if Rect2(sp.position, sp.size) == Hud.STORY_BOOK:
			book = sp.tooltip_text.begins_with("历史背景")
	check(book, "照史料来的事件右上角有历史背景")
	key(KEY_ESCAPE)
	eq(hud.popup.get("kind", ""), "story", "Esc 关不掉, 一定要选")
	var p0 := me.prestige
	key(KEY_1)
	check(hud.popup.is_empty(), "按 1 选第一个")
	eq(me.prestige, p0 + 5.0)


func test_player_abdicates_from_breakdown() -> void:
	main.play_as("wessex")
	var me := hud.me()
	var heir := world.heir("wessex", main.clock.day)
	me.stress = 330.0
	var ev := []
	world.story._check_breaks(main.clock.day, ev)
	main.handle_events(ev)
	eq(hud.popup.get("kind", ""), "story")
	var s: Dictionary = hud.popup.story
	var i := -1
	for k in s.options.size():
		if s.options[k].get("kind", "") == "abdicate":
			i = k
	check(i >= 0, "第 3 档能让位")
	click_hud(hud.story_option_rect(i, s.options.size()).get_center())
	eq(hud.player_id, heir.id, "让位以后接着玩继承人")
	eq(hud.popup.get("kind", ""), "succession", "弹出继位的窗口")
	check(hud.popup.event.abdicated)


func test_match_sort_keeps_people() -> void:
	main.play_as("wessex")
	hud.show_person("alfred")
	hud._open_match()
	var before: Array = hud.window.rows.map(func(r: Dictionary) -> String: return r.person.id)
	before.sort()
	check(click_hud(hud._win_tab_rect(1, Hud.MATCH_TABS.size()).get_center()), "点「身份最高的在前」")
	eq(hud.window.get("kind", ""), "match", "还是说亲窗口")
	eq(hud.window.tab, 1)
	var after: Array = hud.window.rows.map(func(r: Dictionary) -> String: return r.person.id)
	after.sort()
	eq(after, before, "换排法: 名单里的人不变 (不会又换一批本地贵族)")
	var st: Array = hud.window.rows.map(func(r: Dictionary) -> int: return r.status)
	for i in st.size() - 1:
		check(st[i] >= st[i + 1], "身份高的在前")


func test_rules_defaults_and_reset() -> void:
	hud.open_rules()
	click_hud(hud._rule_option(1, 1).get_center())  # 铁人模式: 开
	hud = main.hud  # 改了设置会用新设置重新开一局 (界面也是新的)
	eq(main.world.rules.ironman, "on", "改了设置")
	eq(hud.popup.get("kind", ""), "rules", "改了以后还开着设置")
	check(click_hud(hud._rules_reset().get_center()), "点「恢复默认」")
	hud = main.hud
	world = main.world
	eq(main.world.rules, Rules.defaults(), "都换回默认的")
	hud.close_popup()
	main.play_as("wessex")
	hud.open_rules()
	var has_reset := false
	for sp in hud._popup_spots:
		if Rect2(sp.position, sp.size) == hud._rules_reset():
			has_reset = true
	check(not has_reset, "开始以后没有「恢复默认」")
