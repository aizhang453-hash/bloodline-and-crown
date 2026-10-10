extends Node2D
## 游戏入口: 地图 + 界面 + 时间。
## 开局先选一个国王 (在地图上点领地, 再点「玩这个人」), 然后按空格让时间走起来。

var world: World
var clock: Clock
var map: MapView
var hud: Hud


func _ready() -> void:
	world = World.load_867(randi())
	clock = Clock.new(world.start_day)
	map = MapView.new(world, ProvinceMap.new())
	add_child(map)
	hud = Hud.new(world, clock, map)
	add_child(hud)
	map.county_clicked.connect(_on_county_clicked)
	map.county_hovered.connect(hud.set_map_hover)
	hud.play_requested.connect(play_as)
	hud.mode_requested.connect(_on_mode)
	hud.close_requested.connect(close_panel)


func _process(delta: float) -> void:
	if clock.advance(delta) > 0:
		hud.redraw()


func play_as(realm_id: String) -> void:
	hud.set_player(realm_id)
	hud.toast("你现在是%s。按空格让时间走起来" % world.ruler_text(realm_id))


func close_panel() -> void:
	hud.close_county()
	map.set_selected(0)


func _on_county_clicked(index: int) -> void:
	if index == 0:
		close_panel()
		return
	map.set_selected(index)
	hud.show_county(index)


func _on_mode(mode: int) -> void:
	map.set_mode(mode)
	hud.redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE:
			hud._toggle_pause()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			clock.faster()
		KEY_MINUS, KEY_KP_SUBTRACT:
			clock.slower()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			clock.set_speed(k.keycode - KEY_0)
		KEY_ESCAPE:
			if hud.show_help:
				hud._toggle_help()
			else:
				close_panel()
		KEY_F1:
			hud._toggle_help()
		KEY_HOME:
			map.show_all()
		_:
			return
	hud.redraw()
	get_viewport().set_input_as_handled()
