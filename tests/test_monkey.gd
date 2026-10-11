extends TestCase
## 电脑乱玩: 随便乱点、乱按、乱滚、让时间走, 每一步检查状态没坏 (脚本出错也会被算成不对)。

const STEPS := 3000

var main: Node
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("bloodline_test_saves_%d" % OS.get_process_id())  # 不碰真的存档
	main = load("res://scenes/main.tscn").instantiate()
	main.allow_quit = false
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	rng.seed = 20261010


func after_each() -> void:
	main.free()
	for file in DirAccess.get_files_at(SaveGame.dir) if DirAccess.dir_exists_absolute(SaveGame.dir) else []:
		DirAccess.remove_absolute(SaveGame.dir.path_join(file))


func test_random_play() -> void:
	var map: MapView = main.map
	var hud: Hud = main.hud
	var clock: Clock = main.clock
	var keys := [KEY_SPACE, KEY_EQUAL, KEY_MINUS, KEY_1, KEY_3, KEY_5, KEY_ESCAPE, KEY_F1, KEY_HOME]
	var last_day := clock.day
	for i in STEPS:
		var p := Vector2(rng.randf_range(0, 1920), rng.randf_range(0, 1080))
		match rng.randi_range(0, 9):
			0, 1:
				_click_map(map, p, MOUSE_BUTTON_LEFT if rng.randf() < 0.8 else MOUSE_BUTTON_RIGHT)
			2:
				var all: Array = hud._spots + hud._alert_spots + hud._war_spots + hud._county_spots + hud._person_spots + hud._window_spots + hud._popup_spots
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
			9:
				# 打开你的国家, 或者对你国家里随便一个人「互动」 (第 5 块)
				if hud.player_id != "" and hud.popup.is_empty():
					var r := rng.randf()
					if r < 0.2:
						hud._open_realm_window()
					elif r < 0.3:
						hud._open_schemes_window()  # 阴谋 (第 7 块)
					elif r < 0.35:
						hud._open_decisions()  # 决议 (第 8 块)
					elif r < 0.4:
						# 军队 (第 6 块): 打开军队窗口, 有时选中自己的军队
						hud._open_army_window()
						var mine: Dictionary = main.world.warfare.army_of(hud.player_id)
						if not mine.is_empty() and rng.randf() < 0.5:
							map.selected_army = mine.id
					else:
						var them: Array = main.world.living.values().filter(func(x: Person) -> bool: return main.world.home_realm(x) == hud.player)
						if not them.is_empty():
							hud.show_person(them[rng.randi_range(0, them.size() - 1)].id)
							if not hud._actions_for(main.world.people[hud.person_id]).is_empty():
								hud._open_actions()
			8:
				# 打开你家族里随便一个人的人物窗口 (这样乱点才点得到说亲、教育、起名这些)
				if hud.player != "" and hud.popup.is_empty():
					var mine: Array = main.world.living.values().filter(func(x: Person) -> bool: return main.world.is_player_family(x))
					if not mine.is_empty():
						hud.show_person(mine[rng.randi_range(0, mine.size() - 1)].id)
						if rng.randf() < 0.5:
							for b in hud._person_buttons(main.world.people[hud.person_id]):
								if rng.randf() < 0.5:
									b[2].call()
									break
		check(clock.day >= last_day, "日期只往前走")
		last_day = clock.day
		check(clock.speed >= 1 and clock.speed <= Clock.MAX_SPEED, "速度在一到五档")
		check(map.zoom() >= MapView.ZOOM_MIN - 0.001 and map.zoom() <= MapView.ZOOM_MAX + 0.001, "缩放在范围里")
		check(hud.county == 0 or not main.world.county_at(hud.county).is_empty(), "左边窗口开着的是一块真的领地")
		check(hud.player == "" or main.world.realms.has(hud.player), "玩家的国家是真的")
		check(hud.player != "" or clock.paused, "没选国王时间不走")
		check(main.world.player == hud.player_id or clock.paused, "世界知道玩家是谁")
		check(hud.window.is_empty() or hud.window.kind in ["realm", "grant", "army", "war", "commander", "schemes", "scheme", "agents", "decisions"] or hud.person_id == hud.window.person, "说亲、教育、互动、宣战的窗口跟着人物窗口")
		for a in main.world.warfare.armies.values():
			check(a.levy >= 0.0 and a.special >= 0.0, "军队的人数不是负数")
			check(main.world.by_id.has(a.loc), "军队在一块真的地上")
		check(hud.player_id == "" or main.world.is_landed(main.world.people[hud.player_id]) or not hud.popup.is_empty(), "玩家有领地 (不然游戏结束)")
		check(hud.popup.get("kind", "") != "story" or not hud.popup.story.options.is_empty(), "事件至少有一个办法")
		if hud.player_id != "":
			var me: Person = main.world.people[hud.player_id]
			check(me.stress >= 0.0 and me.stress <= Person.MAX_STRESS, "压力在 0 到 %d" % int(Person.MAX_STRESS))
		if not failures.is_empty():
			failures.append("第 %d 步出的错" % i)
			return
	check(hud.player != "", "乱玩 %d 步, 应该选上了国王" % STEPS)
	check(clock.day > main.world.start_day, "时间走过")


func _click_map(map: MapView, p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = p
		ev.button_index = button
		ev.pressed = pressed
		map._unhandled_input(ev)
