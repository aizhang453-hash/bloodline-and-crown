class_name World
extends RefCounted
## 世界: 读 data/world_867.json (领地、公国、王国、开局的国家) 和 data/generated/map.json (地图工具算好的形状)。
## 爵位一层层: 帝国 > 王国 > 公国 > 领地 (伯爵领)。867 年的「国王」其实是小国王, 地盘相当于公爵领。

const WORLD_FILE := "res://data/world_867.json"
const MAP_FILE := "res://data/generated/map.json"
const NAMES_FILE := "res://data/names.json"

var start_day: int
var empire: Dictionary
var kingdoms := {}       # id -> {id, name}
var duchies := {}        # id -> {id, name, kingdom}
var counties: Array = [] # 第 i 个是编号 i + 1 的领地 (领地图上的编号从 1 开始, 0 是海)
var by_id := {}          # 领地 id -> 领地
var realms := {}         # 国家 id -> {id, ruler (名字), ruler_id, title, color, culture, random, index}
var people := {}         # 人的 id -> Person
var realm_order: Array = []
var map_size: Vector2i
var km_per_px: float
var coastline: Array = [] # 每个岛一圈 PackedVector2Array (领地图上的像素坐标)


## seed: 随机的东西 (查不到的统治者的名字、长相基因、生日) 用的种子, 每局开新游戏换一个
static func load_867(name_seed: int = 867) -> World:
	var w := World.new()
	w._load(_read_json(WORLD_FILE), _read_json(MAP_FILE), _read_json(NAMES_FILE), name_seed)
	return w


static func _read_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "读不了 " + path)
	return data


func _load(data: Dictionary, map: Dictionary, names: Dictionary, name_seed: int) -> void:
	var d: Array = data.start_date
	start_day = GameDate.to_day(int(d[0]), int(d[1]), int(d[2]))
	empire = data.empire
	for k in data.kingdoms:
		kingdoms[k.id] = k
	for du in data.duchies:
		duchies[du.id] = du
	var rng := RandomNumberGenerator.new()
	rng.seed = name_seed
	for r in data.realms:
		var realm := {
			"id": r.id, "title": r.title, "color": Color(r.color), "culture": r.culture,
			"random": r.ruler == null, "index": realm_order.size() + 1,
		}
		var ruler := Person.new()
		ruler.id = "ruler_" + r.id
		ruler.culture = r.culture
		ruler.rank = "king"
		ruler.realm = r.id
		var born: int
		if r.ruler == null:
			# 史料查不到: 名字从当地当时的名字里挑, 年纪随机
			var pool: Array = names.male.get(r.culture, names.male[Portrait.style(r.culture)])
			ruler.name = pool[rng.randi_range(0, pool.size() - 1)]
			born = rng.randi_range(812, 845)
			ruler.birth_estimated = true
			ruler.note = "史料里查不到这时候是谁在管, 统治者是随机生成的"
		else:
			ruler.name = r.ruler
			born = int(r.born)
			ruler.birth_estimated = r.born_estimated
			ruler.note = r.get("note", "")
		# 只知道哪一年生的, 生日那天随机
		ruler.birth_day = GameDate.to_day(born, 1, 1) + rng.randi_range(0, GameDate.YEAR_DAYS - 1)
		ruler.dna = Portrait.random_dna(rng, r.culture)
		ruler.dna.merge(r.get("looks", {}), true)  # 史料里讲到的长相盖过随机的
		# 性格、天生的特点、教育、本事的底子: 史料里写了的照着给 (world_867.json), 没写的随机
		ruler.traits = Traits.random_personality(rng, 3, r.get("personality", []))
		ruler.traits.append_array(r.get("congenital", Traits.random_congenital(rng)))
		ruler.education = r.get("education", Traits.random_education(rng, "king"))
		for s in Traits.SKILLS:
			ruler.base_skills[s] = rng.randi_range(2, 7)
		ruler.base_skills.merge(r.get("base_skills", {}), true)
		people[ruler.id] = ruler
		realm.ruler = ruler.name
		realm.ruler_id = ruler.id
		realms[r.id] = realm
		realm_order.append(r.id)

	map_size = Vector2i(int(map.width), int(map.height))
	km_per_px = map.km_per_px
	var shapes := {}
	for s in map.counties:
		shapes[s.id] = s
	for i in data.counties.size():
		var c: Dictionary = data.counties[i]
		var s: Dictionary = shapes[c.id]
		assert(int(s.index) == i + 1, "地图和领地表对不上, 要重新跑 tools/make_map.py")
		var rect: Array = s.rect
		counties.append({
			"id": c.id, "name": c.name, "duchy": c.duchy, "holder": c.holder, "index": i + 1,
			"seat": Vector2(s.seat[0], s.seat[1]), "center": Vector2(s.center[0], s.center[1]),
			"area_km2": int(s.area_km2), "rect": Rect2i(rect[0], rect[1], rect[2], rect[3]),
			"neighbors": s.neighbors, "coastal": s.coastal,
		})
		by_id[c.id] = counties[i]
	for ring in map.coastline:
		var pts := PackedVector2Array()
		for k in range(0, ring.size(), 2):
			pts.append(Vector2(ring[k], ring[k + 1]))
		coastline.append(pts)


## 编号 -> 领地 (编号 0 是海, 返回空的)
func county_at(index: int) -> Dictionary:
	return counties[index - 1] if index >= 1 and index <= counties.size() else {}


func duchy_of(c: Dictionary) -> Dictionary:
	return duchies[c.duchy]


func kingdom_of(c: Dictionary) -> Dictionary:
	return kingdoms[duchies[c.duchy].kingdom]


func realm_of(c: Dictionary) -> Dictionary:
	return realms[c.holder]


func counties_of(realm_id: String) -> Array:
	return counties.filter(func(c: Dictionary) -> bool: return c.holder == realm_id)


func counties_in_duchy(duchy_id: String) -> Array:
	return counties.filter(func(c: Dictionary) -> bool: return c.duchy == duchy_id)


## 过了几天 (每个人的压力慢慢降……以后还有变老生病)
func advance(days: int) -> void:
	for p in people.values():
		p.pass_days(days)


## 这个国家的统治者
func ruler(realm_id: String) -> Person:
	return people[realms[realm_id].ruler_id]


## 国家的全称, 比如「威塞克斯国王 埃塞尔雷德一世」
func ruler_text(realm_id: String) -> String:
	var r: Dictionary = realms[realm_id]
	return "%s %s" % [r.title, r.ruler]


## 国家的名字 (头衔去掉最后的「国王」「首领」这些), 用在地图上
func realm_name(realm_id: String) -> String:
	var t: String = realms[realm_id].title
	t = t.split("、")[t.split("、").size() - 1]
	for tail in ["国王", "首领", "领主", "之王"]:
		if t.ends_with(tail):
			return t.substr(0, t.length() - tail.length())
	return t
