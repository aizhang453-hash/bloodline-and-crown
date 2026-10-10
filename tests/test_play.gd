extends TestCase
## 整个游戏的操作: 不开窗口, 把鼠标键盘的事件交给游戏, 看点了有没有反应。
## 画得对不对要看截图 (screenshots.gd), 这里只管操作。

var main: Node
var world: World
var map: MapView
var hud: Hud


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	world = main.world
	map = main.map
	hud = main.hud


func after_each() -> void:
	main.free()


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
	var all: Array = hud._spots + hud._county_spots + hud._person_spots + hud._popup_spots
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
	for y in Hud.RIGHT_MENU_Y:
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
	check(click_hud(Hud.CHAR_BUTTON.get_center()), "点「看看整个维京大军」")
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
	var events := []
	world.kill(world.ruler("east_anglia"), main.clock.day, events)
	main.handle_events(events)
	eq(hud.popup.get("kind", ""), "game_over", "埃德蒙没有家人, 游戏结束")
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
