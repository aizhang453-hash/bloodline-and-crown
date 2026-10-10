class_name MapView
extends Node2D
## 地图: 领地图按国家 (或公国、王国、帝国) 上色, 能拖、能缩放、点一下选中一块领地。
## 地图上的坐标就是领地图的像素坐标 (一个像素 0.5 公里)。

signal county_clicked(index: int)   # 0 = 点在海上
signal county_hovered(index: int)

enum Mode { REALM, DUCHY, KINGDOM, EMPIRE }
const MODE_NAMES := ["国家", "公国", "王国", "帝国"]
const KINGDOM_COLORS := {"england": "a8433a", "scotland": "3d6299", "wales": "418a4b", "ireland": "c4a24c"}
const EMPIRE_COLOR := Color("7b5a8f")
const ZOOM_MIN := 0.36
const ZOOM_MAX := 4.0
const KEY_PAN_SPEED := 900.0  # 每秒多少屏幕像素
const CLICK_SLOP := 6.0       # 按下去动了这么多像素以内算「点」, 再多就算「拖」
const SEA_PAD := 3000.0       # 领地图外面再铺这么宽的海 (缩到最小也看不到边)

var world: World
var pmap: ProvinceMap
var mode := Mode.REALM
var hovered := 0
var selected := 0
var camera := Camera2D.new()
var overlay := MapOverlay.new()

var _sprite := Sprite2D.new()
var _material := ShaderMaterial.new()
var _lookup := Image.create(1, 2, false, Image.FORMAT_RGBA8)
var _lookup_tex: ImageTexture
var _dragging := false
var _drag_moved := 0.0
var _time := 0.0


func _init(p_world: World, p_pmap: ProvinceMap) -> void:
	world = p_world
	pmap = p_pmap


func _ready() -> void:
	_material.shader = load("res://shaders/map.gdshader")
	_sprite.texture = pmap.texture
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(-SEA_PAD, -SEA_PAD, world.map_size.x + 2 * SEA_PAD, world.map_size.y + 2 * SEA_PAD)
	_sprite.position = Vector2(-SEA_PAD, -SEA_PAD)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _material
	add_child(_sprite)
	overlay.view = self
	add_child(overlay)
	add_child(camera)
	camera.make_current()
	_lookup = Image.create(world.counties.size() + 1, 2, false, Image.FORMAT_RGBA8)
	_lookup_tex = ImageTexture.create_from_image(_lookup)
	_material.set_shader_parameter("lookup", _lookup_tex)
	_material.set_shader_parameter("provinces", pmap.texture)
	refresh_colors()
	show_all()


## 整个群岛都放进画面
func show_all() -> void:
	camera.position = Vector2(world.map_size) / 2.0
	set_zoom(get_viewport_rect().size.y / float(world.map_size.y) * 1.02)


func focus(p: Vector2, zoom := -1.0) -> void:
	camera.position = p
	if zoom > 0:
		set_zoom(zoom)
	_clamp_camera()


func set_zoom(z: float) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	_clamp_camera()
	overlay.queue_redraw()


func zoom() -> float:
	return camera.zoom.x


func set_mode(m: int) -> void:
	mode = m
	refresh_colors()


func set_selected(index: int) -> void:
	selected = index
	_material.set_shader_parameter("selected", index)


## 按现在的地图模式重新上色。领地换了主人以后也要调一次。
func refresh_colors() -> void:
	for c in world.counties:
		var col: Color
		var group: int
		match mode:
			Mode.REALM:
				var r: Dictionary = world.realm_of(c)
				col = r.color
				group = r.index
			Mode.DUCHY:
				group = world.duchies.keys().find(c.duchy) + 1
				col = Color.from_hsv(fmod(group * 0.618034, 1.0), 0.42, 0.78)
			Mode.KINGDOM:
				var k: String = world.duchy_of(c).kingdom
				group = world.kingdoms.keys().find(k) + 1
				col = Color(KINGDOM_COLORS[k])
			_:
				group = 1
				col = EMPIRE_COLOR
		_lookup.set_pixel(c.index, 0, col)
		_lookup.set_pixel(c.index, 1, Color8(group >> 8, group & 255, 0))
	_lookup_tex.update(_lookup)
	overlay.queue_redraw()


## 屏幕上一点 (1920×1080 的画面坐标) 在地图上是哪里
func screen_to_map(p: Vector2) -> Vector2:
	return camera.position + (p - get_viewport_rect().size / 2.0) / zoom()


func map_to_screen(p: Vector2) -> Vector2:
	return (p - camera.position) * zoom() + get_viewport_rect().size / 2.0


func _process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("time_s", _time)
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1
	if pan != Vector2.ZERO:
		camera.position += pan.normalized() * KEY_PAN_SPEED * delta / zoom()
		_clamp_camera()
		_update_hover(get_viewport().get_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			_zoom_at(mb.position, zoom() * factor)
			get_viewport().set_input_as_handled()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if mb.button_index == MOUSE_BUTTON_LEFT and _drag_moved < CLICK_SLOP:
					county_clicked.emit(pmap.index_at(screen_to_map(mb.position)))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			_drag_moved += mm.relative.length()
			if _drag_moved >= CLICK_SLOP:
				camera.position -= mm.relative / zoom()
				_clamp_camera()
		_update_hover(mm.position)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.position, zoom() * mg.factor)
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		camera.position += pg.delta * 12.0 / zoom()
		_clamp_camera()


func _zoom_at(screen_pos: Vector2, z: float) -> void:
	var before := screen_to_map(screen_pos)
	set_zoom(z)
	camera.position = before - (screen_pos - get_viewport_rect().size / 2.0) / zoom()
	_clamp_camera()


func _update_hover(screen_pos: Vector2) -> void:
	var i := pmap.index_at(screen_to_map(screen_pos))
	if i != hovered:
		hovered = i
		_material.set_shader_parameter("hovered", i)
		county_hovered.emit(i)


func clear_hover() -> void:
	if hovered != 0:
		hovered = 0
		_material.set_shader_parameter("hovered", 0)
		county_hovered.emit(0)


func _clamp_camera() -> void:
	var half := get_viewport_rect().size / 2.0 / zoom()
	var size := Vector2(world.map_size)
	var p := camera.position
	for axis in 2:
		if half[axis] * 2.0 >= size[axis]:
			p[axis] = size[axis] / 2.0
		else:
			p[axis] = clampf(p[axis], half[axis] - 80.0, size[axis] - half[axis] + 80.0)
	camera.position = p
	overlay.queue_redraw()


## 地图上面一层: 海岸线、都城的点、国家和领地的名字
class MapOverlay:
	extends Node2D

	var view: MapView

	func _draw() -> void:
		var z := view.zoom()
		var w := view.world
		for ring in w.coastline:
			draw_polyline(ring, Color(0.12, 0.1, 0.07, 0.75), 1.3 / z, true)
		var font := Look.font("map")
		var show_counties := z >= 1.0
		if show_counties:
			var size := int(15.0 / z)
			for c in w.counties:
				draw_circle(c.seat, 2.6 / z, Color(0.12, 0.1, 0.07, 0.9))
				_label(font, c.center + Vector2(0, size * 0.35), c.name, size, 3.0 / z)
		if z < 1.35:
			var alpha := clampf((1.35 - z) / 0.35, 0.0, 1.0)
			for g in _groups():
				var size := clampf(sqrt(g.area) * 0.11, 18.0, 150.0)
				size = minf(size, g.width * 0.85 / maxf(1.0, g.text.length()))
				if size * z < 9.0:
					continue
				_label(font, g.pos + Vector2(0, size * 0.35), g.text, int(size), size * 0.08, alpha)

	func _label(font: Font, pos: Vector2, s: String, size: int, outline: float, alpha := 1.0) -> void:
		var width := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := pos - Vector2(width / 2.0, 0)
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(1, int(outline)), Color(0.96, 0.92, 0.8, 0.75 * alpha))
		draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.13, 0.1, 0.07, alpha))

	## 按地图模式把领地分组 (国家 / 公国 / 王国 / 帝国), 每组的名字写在中间
	func _groups() -> Array:
		var w := view.world
		var groups := {}
		for c in w.counties:
			var key: String
			var text: String
			match view.mode:
				MapView.Mode.REALM:
					key = c.holder
					text = w.realm_name(c.holder)
				MapView.Mode.DUCHY:
					key = c.duchy
					text = w.duchy_of(c).name
				MapView.Mode.KINGDOM:
					key = w.duchy_of(c).kingdom
					text = w.kingdom_of(c).name
				_:
					key = "empire"
					text = w.empire.name
			if not groups.has(key):
				groups[key] = {"text": text, "area": 0.0, "sum": Vector2.ZERO, "min": Vector2(INF, INF), "max": -Vector2(INF, INF)}
			var g: Dictionary = groups[key]
			var px := float(c.area_km2) / (w.km_per_px * w.km_per_px)
			g.area += px
			g.sum += c.center * px
			g.min = g.min.min(Vector2(c.rect.position))
			g.max = g.max.max(Vector2(c.rect.end))
		var out := []
		for g in groups.values():
			out.append({"text": g.text, "area": g.area, "pos": g.sum / g.area, "width": (g.max - g.min).x})
		return out
