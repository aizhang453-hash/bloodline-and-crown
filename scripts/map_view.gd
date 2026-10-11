class_name MapView
extends Node2D
## 地图: 领地图按国家 (或公国、王国、帝国、家族) 上色, 能拖、能缩放、点一下选中一块领地。
## 第 5 块 (学三代): 同一个国家里不同主人的地之间画细线, 每个主人的地上画他的纹章 (国王加小王冠);
## 选中一个人 (人物窗口、领地窗口) 时, 他直辖的地亮起来, 他的封臣照常, 别的地方暗下去。
## 地图上的坐标就是领地图的像素坐标 (一个像素 0.5 公里)。

signal county_clicked(index: int)   # 0 = 点在海上
signal county_hovered(index: int)

enum Mode { REALM, DUCHY, KINGDOM, EMPIRE, HOUSE }
const MODE_NAMES := ["国家", "公国", "王国", "帝国", "家族"]
const SHIELD_ZOOM := 0.55      # 放大到这么大才画纹章 (再远只看国家, 跟三代的「纸地图」一样)
const SHIELD_PX := 30.0        # 纹章在屏幕上多大
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
var focus_person := ""         # 选中的人 (他的地亮起来); 空 = 没选
var camera := Camera2D.new()
var overlay := MapOverlay.new()

var _sprite := Sprite2D.new()
var _material := ShaderMaterial.new()
var _lookup := Image.create(1, 2, false, Image.FORMAT_RGBA8)
var _lookup_tex: ImageTexture
var _dragging := false
var _drag_moved := 0.0
var _time := 0.0
var _lord_codes := {}           # 主人的 id -> 编号 (第 2 行用)


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
	_lookup = Image.create(world.counties.size() + 1, 3, false, Image.FORMAT_RGBA8)
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


## 选中一个人: 他直辖的地亮起来, 他下面的封臣照常, 别的暗下去 (空 = 不选)
func set_focus_person(id: String) -> void:
	if id == focus_person:
		return
	focus_person = id
	refresh_colors()


## 这块地在选中的人下面吗 (主人是他, 或者主人一层层往上是他)
func _under(c: Dictionary, p: Person) -> int:
	var lord: Person = world.people[c.lord]
	if lord == p:
		return 2
	var up := world.liege_of(lord)
	for i in 4:
		if up == null:
			return 0
		if up == p:
			return 1
		up = world.liege_of(up)
	return 0


## 家族的颜色: 统治家族跟国家一样; 别的家族按名字算一个固定的颜色 (同一个家族每次一样)
func house_color(house: String) -> Color:
	if world.houses.has(house) and world.houses[house].color != Color(0.4, 0.4, 0.42):
		return world.houses[house].color
	return Color.from_hsv(fmod(float(hash(house) % 997) / 997.0 + 0.13, 1.0), 0.5, 0.72)


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
			Mode.HOUSE:
				var r2: Dictionary = world.realm_of(c)
				col = house_color(world.people[c.lord].house)
				group = r2.index
			_:
				group = 1
				col = EMPIRE_COLOR
		# 同一个国家里不同主人之间画细线 (国家、家族模式才分)
		var lord_code := group
		if mode in [Mode.REALM, Mode.HOUSE]:
			lord_code = _lord_codes.get(c.lord, 0)
			if lord_code == 0:
				lord_code = _lord_codes.size() + 1
				_lord_codes[c.lord] = lord_code
		# 选中了一个人: 他直辖的亮, 他的封臣照常, 同一个国家别的暗一些, 别的国家更暗
		if focus_person != "" and world.people.has(focus_person) and mode in [Mode.REALM, Mode.HOUSE]:
			var fp: Person = world.people[focus_person]
			match _under(c, fp):
				2:
					col = col.lightened(0.28)
				1:
					pass
				_:
					col = col.darkened(0.35 if c.holder == world.realm_of_person(fp) else 0.55)
		_lookup.set_pixel(c.index, 0, col)
		_lookup.set_pixel(c.index, 1, Color8(group >> 8, group & 255, 0))
		_lookup.set_pixel(c.index, 2, Color8(lord_code >> 8, lord_code & 255, 0))
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
		if z >= MapView.SHIELD_ZOOM and view.mode in [MapView.Mode.REALM, MapView.Mode.HOUSE]:
			for sh in shields():
				_shield(sh, z)
		if z < 1.35:
			var alpha := clampf((1.35 - z) / 0.35, 0.0, 1.0)
			for g in _groups():
				var size := clampf(sqrt(g.area) * 0.11, 18.0, 150.0)
				size = minf(size, g.width * 0.85 / maxf(1.0, g.text.length()))
				if size * z < 9.0:
					continue
				_label(font, g.pos + Vector2(0, size * 0.35), g.text, int(size), size * 0.08, alpha)

	## 每个有领地的人一个纹章, 放在他直辖的地中间: [{person, pos, king}]
	func shields() -> Array:
		var w := view.world
		var by_lord := {}
		for c in w.counties:
			if not by_lord.has(c.lord):
				by_lord[c.lord] = {"sum": Vector2.ZERO, "area": 0.0}
			var px := float(c.area_km2)
			by_lord[c.lord].sum += c.center * px
			by_lord[c.lord].area += px
		var out := []
		for id in by_lord:
			var p: Person = w.people[id]
			out.append({"person": p, "pos": by_lord[id].sum / by_lord[id].area, "king": p.realm != ""})
		return out

	## 一个纹章 (屏幕上大小不变): 国王画国家的纹章, 上面一顶小王冠; 封臣画家族的纹章
	func _shield(sh: Dictionary, z: float) -> void:
		var w := view.world
		var s := MapView.SHIELD_PX / z
		var p: Person = sh.person
		# 放大了领地名字在中间, 纹章画在名字上面; 国家名字还看得见时, 国王的纹章再往上挪, 不压住国家名字
		var lift := 1.1 if z >= 1.0 else 0.2
		if sh.king and z < 1.35:
			lift += 1.3
		var center: Vector2 = sh.pos - Vector2(0, s * lift)
		var r := Rect2(center - Vector2(s * 0.42, s * 0.5), Vector2(s * 0.84, s))
		var dim := view.focus_person != "" and view.focus_person != p.id and (w.liege_of(p) == null or w.liege_of(p).id != view.focus_person)
		if sh.king and w.realms.has(p.realm):
			Icons.realm_arms(self, r, w.realms[p.realm])
			Icons.draw(self, "crown", center - Vector2(0, s * 0.72), s * 0.62, Icons.GOLD)
		elif w.houses.has(p.house):
			var hs: Dictionary = w.houses[p.house]
			var col := view.house_color(p.house)
			Icons.arms(self, r, int(hs.design) % Icons.DESIGNS, col, Icons.charge_color(col, int(hs.design)))
		if dim:
			draw_rect(r.grow(s * 0.05), Color(0.05, 0.05, 0.06, 0.45))

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
				MapView.Mode.HOUSE:
					var lord: Person = w.people[c.lord]
					key = lord.house
					text = w.house_name(lord.house)
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
