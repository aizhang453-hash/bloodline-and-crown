extends TestCase
## 电脑乱玩: 随便乱点、乱按、乱滚、让时间走, 每一步检查状态没坏 (脚本出错也会被算成不对)。

const STEPS := 3000

var main: Node
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	rng.seed = 20261010


func after_each() -> void:
	main.free()


func test_random_play() -> void:
	var map: MapView = main.map
	var hud: Hud = main.hud
	var clock: Clock = main.clock
	var keys := [KEY_SPACE, KEY_EQUAL, KEY_MINUS, KEY_1, KEY_3, KEY_5, KEY_ESCAPE, KEY_F1, KEY_HOME]
	var last_day := clock.day
	for i in STEPS:
		var p := Vector2(rng.randf_range(0, 1920), rng.randf_range(0, 1080))
		match rng.randi_range(0, 7):
			0, 1:
				_click_map(map, p)
			2:
				var all: Array = hud._spots + hud._county_spots + hud._person_spots + hud._popup_spots
				all.reverse()
				for s in all:
					if s.visible and Rect2(s.position, s.size).has_point(p):
						if s.on_click.is_valid():
							s.on_click.call()
						break
			3:
				var ev := InputEventKey.new()
				ev.keycode = keys[rng.randi_range(0, keys.size() - 1)]
				ev.pressed = true
				main._unhandled_key_input(ev)
			4:
				var ev := InputEventMouseButton.new()
				ev.position = p
				ev.button_index = MOUSE_BUTTON_WHEEL_UP if rng.randf() < 0.5 else MOUSE_BUTTON_WHEEL_DOWN
				ev.pressed = true
				map._unhandled_input(ev)
			5:
				var ev := InputEventMouseMotion.new()
				ev.position = p
				ev.relative = Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
				map._unhandled_input(ev)
			6:
				if hud.county and hud.player == "" and rng.randf() < 0.3:
					hud._play_this()
			7:
				main._process(rng.randf_range(0.0, 0.5))
				map._process(0.016)
				hud._process(0.016)
		check(clock.day >= last_day, "日期只往前走")
		last_day = clock.day
		check(clock.speed >= 1 and clock.speed <= Clock.MAX_SPEED, "速度在一到五档")
		check(map.zoom() >= MapView.ZOOM_MIN - 0.001 and map.zoom() <= MapView.ZOOM_MAX + 0.001, "缩放在范围里")
		check(hud.county == 0 or not main.world.county_at(hud.county).is_empty(), "左边窗口开着的是一块真的领地")
		check(hud.player == "" or main.world.realms.has(hud.player), "玩家的国家是真的")
		check(hud.player != "" or clock.paused, "没选国王时间不走")
		if not failures.is_empty():
			failures.append("第 %d 步出的错" % i)
			return
	check(hud.player != "", "乱玩 %d 步, 应该选上了国王" % STEPS)
	check(clock.day > main.world.start_day, "时间走过")


func _click_map(map: MapView, p: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = p
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		map._unhandled_input(ev)
