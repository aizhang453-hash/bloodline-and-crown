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


## 点界面上的一个能点的地方 (按位置找)
func click_hud(p: Vector2) -> bool:
	for s in hud._spots + hud._county_spots:
		if s.visible and s.on_click.is_valid() and Rect2(s.position, s.size).has_point(p):
			var ev := InputEventMouseButton.new()
			ev.position = p - s.position
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			s._gui_input(ev)
			return true
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
