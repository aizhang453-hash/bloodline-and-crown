class_name World
extends RefCounted
## 世界: 读 data/world_867.json (领地、公国、王国、开局的国家、家族、家人) 和 data/generated/map.json (地图工具算好的形状)。
## 爵位一层层: 帝国 > 王国 > 公国 > 领地 (伯爵领)。867 年的「国王」其实是小国王, 地盘相当于公爵领。
## 时间往前走时每个月过一次: 有人会死, 国王死了照继承法换人 (见 Succession), 孩子长到 16 岁有了性格, 国王涨威望。

const WORLD_FILE := "res://data/world_867.json"
const MAP_FILE := "res://data/generated/map.json"
const NAMES_FILE := "res://data/names.json"

var start_day: int
var empire: Dictionary
var kingdoms := {}       # id -> {id, name}
var duchies := {}        # id -> {id, name, kingdom}
var counties: Array = [] # 第 i 个是编号 i + 1 的领地 (领地图上的编号从 1 开始, 0 是海)
var by_id := {}          # 领地 id -> 领地
var realms := {}         # 国家 id -> {id, ruler (名字), ruler_id, title, color, culture, house, titles, random, index}
var realm_order: Array = []
var people := {}         # 人的 id -> Person (死了的也留着, 家谱要用)
var houses := {}         # 家族 id -> {id, name, desc, color, design}
var map_size: Vector2i
var km_per_px: float
var coastline: Array = [] # 每个岛一圈 PackedVector2Array (领地图上的像素坐标)

var rng := RandomNumberGenerator.new()  # 开局以后的随机事 (谁什么时候死……)
var names: Dictionary
var _next_index := 1     # 新国家的编号 (地图上色用, 只增不减)
var _next_id := 1        # 新人、新家族的编号


## seed: 随机的东西 (查不到的人的名字、长相基因、生日、性格, 开局以后谁什么时候死) 用的种子, 每局开新游戏换一个
static func load_867(name_seed: int = 867) -> World:
	var w := World.new()
	w._load(_read_json(WORLD_FILE), _read_json(MAP_FILE), _read_json(NAMES_FILE), name_seed)
	return w


static func _read_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "读不了 " + path)
	return data


func _load(data: Dictionary, map: Dictionary, p_names: Dictionary, name_seed: int) -> void:
	names = p_names
	var d: Array = data.start_date
	start_day = GameDate.to_day(int(d[0]), int(d[1]), int(d[2]))
	empire = data.empire
	for k in data.kingdoms:
		kingdoms[k.id] = k
	for du in data.duchies:
		duchies[du.id] = du
	var setup := RandomNumberGenerator.new()
	setup.seed = name_seed
	rng.seed = name_seed * 7919 + 1
	for h in data.get("houses", []):
		houses[h.id] = {"id": h.id, "name": h.name, "desc": h.desc, "color": Color(0.4, 0.4, 0.42), "design": houses.size()}
	for r in data.realms:
		var realm := {
			"id": r.id, "title": r.title, "color": Color(r.color), "culture": r.culture,
			"random": r.ruler == null, "index": _next_index, "titles": r.get("titles", []).duplicate(),
		}
		_next_index += 1
		var ruler := Person.new()
		ruler.id = "ruler_" + r.id
		ruler.culture = r.culture
		ruler.rank = "king"
		ruler.realm = r.id
		ruler.father = r.get("father", "")
		ruler.mother = r.get("mother", "")
		var born: int
		if r.ruler == null:
			# 史料查不到: 名字从当地当时的名字里挑, 年纪随机
			ruler.name = random_name(setup, r.culture, false)
			born = setup.randi_range(812, 845)
			ruler.birth_estimated = true
			ruler.note = "史料里查不到这时候是谁在管, 统治者是随机生成的"
		else:
			ruler.name = r.ruler
			born = int(r.born)
			ruler.birth_estimated = r.born_estimated
			ruler.note = r.get("note", "")
		# 只知道哪一年生的, 生日那天随机
		ruler.birth_day = GameDate.to_day(born, 1, 1) + setup.randi_range(0, GameDate.YEAR_DAYS - 1)
		ruler.dna = Portrait.random_dna(setup, r.culture)
		ruler.dna.merge(r.get("looks", {}), true)  # 史料里讲到的长相盖过随机的
		# 性格、天生的特点、教育、本事的底子: 史料里写了的照着给 (world_867.json), 没写的随机
		ruler.traits = Traits.random_personality(setup, 3, r.get("personality", []))
		ruler.traits.append_array(r.get("congenital", Traits.random_congenital(setup)))
		ruler.education = r.get("education", Traits.random_education(setup, "king"))
		_random_skills(setup, ruler)
		ruler.base_skills.merge(r.get("base_skills", {}), true)
		if r.has("house"):
			ruler.house = r.house
		else:
			ruler.house = _new_house(ruler, "史料查不到, 随机生成的家族")
		realm.house = ruler.house
		houses[ruler.house].color = realm.color  # 统治家族的纹章跟国家一样
		houses[ruler.house].design = realm.index
		people[ruler.id] = ruler
		realm.ruler = ruler.name
		realm.ruler_id = ruler.id
		realms[r.id] = realm
		realm_order.append(r.id)
	for f in data.get("family", []):
		_add_family(setup, f)
	for p in people.values():  # 配偶两边都记上
		if p.spouse != "" and people.has(p.spouse):
			people[p.spouse].spouse = p.id

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


## 有记载的家人 (world_867.json 的 family)
func _add_family(setup: RandomNumberGenerator, f: Dictionary) -> void:
	var p := Person.new()
	p.id = f.id
	p.female = f.female
	p.culture = f.culture
	p.name = f.name if f.name != null else random_name(setup, f.culture, f.female)
	p.house = f.house
	p.father = f.get("father", "")
	p.mother = f.get("mother", "")
	p.spouse = f.get("spouse", "")
	p.note = f.get("note", "")
	p.birth_estimated = true
	p.birth_day = GameDate.to_day(int(f.born), 1, 1) + setup.randi_range(0, GameDate.YEAR_DAYS - 1)
	if f.has("died"):
		p.alive = false
		p.death_day = GameDate.to_day(int(f.died), 1, 1) + setup.randi_range(0, GameDate.YEAR_DAYS - 1)
	var rank := "noble"
	if p.father != "" and people.has(p.father) and people[p.father].realm != "":
		rank = "noble"
	p.rank = rank
	p.dna = _child_dna(setup, p)
	p.traits = Traits.random_congenital(setup)
	_random_skills(setup, p)
	if p.adult(start_day):
		p.traits = Traits.random_personality(setup) + p.traits
		p.education = Traits.random_education(setup, "king")
	people[p.id] = p


## 孩子的长相: 爸爸妈妈有记载的, 每样从爸爸或妈妈那里拿一个 (不知道的那边随机)
func _child_dna(setup: RandomNumberGenerator, p: Person) -> Dictionary:
	var dna := Portrait.random_dna(setup, p.culture)
	var dad: Dictionary = people[p.father].dna if people.has(p.father) else {}
	var mum: Dictionary = people[p.mother].dna if people.has(p.mother) else {}
	if dad.is_empty() and mum.is_empty():
		return dna
	for gene in ["skin", "hair", "eyes", "face_w", "jaw", "nose", "eye_gap", "brows", "brow_arch", "mouth", "greying"]:
		var from: Dictionary = dad if setup.randf() < 0.5 else mum
		if not from.is_empty():
			dna[gene] = from[gene]
	return dna


func _random_skills(r: RandomNumberGenerator, p: Person) -> void:
	for s in Traits.SKILLS:
		p.base_skills[s] = r.randi_range(2, 7)


func random_name(r: RandomNumberGenerator, culture: String, female: bool) -> String:
	var list: Dictionary = names.female if female else names.male
	var pool: Array = list.get(culture, list[Portrait.style(culture)])
	return pool[r.randi_range(0, pool.size() - 1)]


func _new_house(founder: Person, desc: String) -> String:
	var id := "house_%d" % _next_id
	_next_id += 1
	houses[id] = {"id": id, "name": founder.name + "家族", "desc": desc,
			"color": Color.from_hsv(rng.randf(), 0.45, 0.6), "design": rng.randi_range(0, 40)}
	return id


# ---- 查东西 ----

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


func house_name(id: String) -> String:
	return houses[id].name if houses.has(id) else "家族不详"


func children_of(p: Person) -> Array:
	var list := people.values().filter(func(c: Person) -> bool: return c.father == p.id or c.mother == p.id)
	list.sort_custom(func(a: Person, b: Person) -> bool: return a.birth_day < b.birth_day)
	return list


func siblings_of(p: Person) -> Array:
	var list := people.values().filter(func(c: Person) -> bool:
		return c.id != p.id and ((p.father != "" and c.father == p.father) or (p.mother != "" and c.mother == p.mother)))
	list.sort_custom(func(a: Person, b: Person) -> bool: return a.birth_day < b.birth_day)
	return list


## other 是 p 的什么人 (父亲、妻子、弟弟……), 不是家人返回空的
func relation(p: Person, other: Person) -> String:
	if other.id == p.father:
		return "父亲"
	if other.id == p.mother:
		return "母亲"
	if other.id == p.spouse:
		return "妻子" if other.female else "丈夫"
	if other.father == p.id or other.mother == p.id:
		return "女儿" if other.female else "儿子"
	if siblings_of(p).has(other):
		var older := other.birth_day < p.birth_day
		if other.female:
			return "姐姐" if older else "妹妹"
		return "哥哥" if older else "弟弟"
	return ""


## 继承人 (照这个国家的继承法, 现在国王死了会是谁)
func heir(realm_id: String, day: int) -> Person:
	return Succession.heir(self, realm_id, day)


# ---- 时间往前走 ----

## 过了几天 (today 是走完以后的那天)。返回这段时间出的事: [{type: "death" / "succession" / "extinct", ...}]
func advance(days: int, today: int) -> Array:
	var events := []
	for p in people.values():
		if p.alive:
			p.pass_days(days)
	var from := _month_index(today - days)
	for m in range(from + 1, _month_index(today) + 1):
		_monthly(m, events)
	return events


func _month_index(day: int) -> int:
	var d := GameDate.from_day(day)
	return int(d[0]) * 12 + int(d[1]) - 1


func _monthly(month: int, events: Array) -> void:
	var day := GameDate.to_day(month / 12, month % 12 + 1, 1)
	for p in people.values().duplicate():
		if not p.alive:
			continue
		if p.adult(day) and p.personality().is_empty():
			# 长到 16 岁: 有了性格, 教育也定下来了
			p.traits = Traits.random_personality(rng) + p.traits
			p.education = Traits.random_education(rng, "king" if p.rank != "" else "")
		if p.realm != "":
			p.prestige += 1.0
		var monthly := 1.0 - pow(1.0 - p.yearly_death_chance(day), 1.0 / 12.0)
		if rng.randf() < monthly:
			kill(p, day, events)


## 一个人死了 (国王死了就照继承法换人)
func kill(p: Person, day: int, events: Array) -> void:
	p.alive = false
	p.death_day = day
	events.append({"type": "death", "person": p.id, "day": day, "was_ruler": p.realm != ""})
	if p.realm != "":
		_succeed(p.realm, p, day, events)


func _succeed(realm_id: String, dead: Person, day: int, events: Array) -> void:
	var realm: Dictionary = realms[realm_id]
	var law := Succession.law_of(realm.culture)
	var heirs := Succession.candidates(self, realm_id, dead, day)
	dead.realm = ""
	var ev := {"type": "succession", "realm": realm_id, "realm_name": realm_name(realm_id), "dead": dead.id,
			"law": law, "splits": [], "merged_into": "", "day": day}
	if heirs.is_empty():
		# 家族绝后: 当地贵族推举一个新国王 (随机生成的人, 新家族)
		var newp := _new_random_ruler(realm_id, day)
		ev.type = "extinct"
		ev.heir = newp.id
		events.append(ev)
		return
	var heir: Person = heirs[0]
	ev.heir = heir.id
	if heir.realm != "" and heir.realm != realm_id:
		# 继承人已经是别的国家的国王: 两个国家归到他一个人手里
		var target: String = heir.realm
		for c in counties:
			if c.holder == realm_id:
				c.holder = target
		realms[target].titles.append_array(realm.titles)
		_remove_realm(realm_id)
		ev.merged_into = target
		events.append(ev)
		return
	_set_ruler(realm_id, heir)
	if law == "partition" and realm.titles.size() > 1:
		# 平分: 主要的王国给继承人, 别的王国一个儿子一个
		var sons := heirs.filter(func(s: Person) -> bool: return s.father == dead.id and s.id != heir.id and s.realm == "")
		var extra: Array = realm.titles.slice(1)
		for i in mini(extra.size(), sons.size()):
			ev.splits.append([_split_realm(realm_id, extra[i], sons[i]), sons[i].id])
	events.append(ev)


func _set_ruler(realm_id: String, p: Person) -> void:
	var realm: Dictionary = realms[realm_id]
	realm.ruler_id = p.id
	realm.ruler = p.name
	realm.random = false
	p.realm = realm_id
	p.rank = "king"


## 从一个国家里分出一个王国 (平分继承), 给 son; 返回新国家的 id
func _split_realm(realm_id: String, title: String, son: Person) -> String:
	var parent: Dictionary = realms[realm_id]
	var id := "%s_%d" % [title, _next_index]
	var c: Color = parent.color
	var realm := {
		"id": id, "title": duchies[title].name + "国王", "culture": parent.culture, "house": son.house,
		"color": Color.from_hsv(fmod(c.h + 0.07 * (1 + _next_index % 3), 1.0), c.s, clampf(c.v * 0.9, 0.3, 0.9)),
		"random": false, "index": _next_index, "titles": [title],
	}
	_next_index += 1
	realms[id] = realm
	realm_order.append(id)
	for county in counties:
		if county.holder == realm_id and county.duchy == title:
			county.holder = id
	parent.titles.erase(title)
	parent.title = "和".join(parent.titles.map(func(t: String) -> String: return duchies[t].name)) + "国王"
	_set_ruler(id, son)
	return id


func _remove_realm(realm_id: String) -> void:
	realms.erase(realm_id)
	realm_order.erase(realm_id)


func _new_random_ruler(realm_id: String, day: int) -> Person:
	var realm: Dictionary = realms[realm_id]
	var p := Person.new()
	p.id = "person_%d" % _next_id
	_next_id += 1
	p.culture = realm.culture
	p.name = random_name(rng, p.culture, false)
	p.birth_day = day - rng.randi_range(25, 50) * GameDate.YEAR_DAYS - rng.randi_range(0, 364)
	p.birth_estimated = true
	p.dna = Portrait.random_dna(rng, p.culture)
	p.traits = Traits.random_personality(rng) + Traits.random_congenital(rng)
	p.education = Traits.random_education(rng, "king")
	_random_skills(rng, p)
	p.note = "原来的家族绝后了, 当地贵族推举的新国王 (随机生成的)"
	p.house = _new_house(p, "%s的贵族推举出来的新王族 (随机生成的)" % realm_name(realm_id))
	houses[p.house].color = realm.color
	houses[p.house].design = realm.index
	people[p.id] = p
	realm.house = p.house
	_set_ruler(realm_id, p)
	realm.random = true
	return p
