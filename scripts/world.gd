class_name World
extends RefCounted
## 世界: 读 data/world_867.json (领地、公国、王国、开局的国家、家族、家人) 和 data/generated/map.json (地图工具算好的形状)。
## 爵位一层层: 帝国 > 王国 > 公国 > 领地 (伯爵领)。867 年的「国王」其实是小国王, 地盘相当于公爵领。
## 时间往前走时每个月过一次: 有人会死, 国王死了照继承法换人 (见 Succession), 国王涨威望;
## 第 4 块: 夫妻会怀孕生孩子, 孩子 3 岁有小时候的性格、6 岁开始跟老师学、16 岁成年 (定教育和性格);
## 电脑给国王家的人说亲, 史料里的婚事照着安排 (data 的 history), 史料里有名字的孩子用真名。结婚的规矩见 Marriage。
## 第 5 块: 每块领地有个主人 (lord): 国王自己管的是直辖领地, 别的是封臣 (郡长、小国王、雅尔、领主、副王) 的; 每月收钱,
## 封臣按合同给上面交钱交兵; 封地、收回、关大牢、送礼、改合同。规矩见 Feudal。
## 第 6 块: 打仗 (军队、打仗、围城、战争) 在 warfare (Warfare), 规矩见 War; 每天走一次。领地被占领 (occupier) 时不出钱不出兵。
## 第 7 块: 阴谋 (暗杀、拉拢、秘密、把柄) 在 intrigue (Intrigue), 规矩见 Schemes; 每天走一次。

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
var living := {}         # 活着的人 (每个月只看这些)
var kids_of := {}        # 父母的 id -> [孩子的 id, ...] (按出生先后)
var ancestor_cache := {} # 人的 id -> 祖先 (Marriage.ancestors 算好存这里, 祖先不会变)
var history_marriages: Array = []  # 史料里开局以后的婚事 [{a, b, year, note}]
var history_children: Array = []   # 史料里开局以后出生的孩子 [{father, mother?, kids: [{id, name, female, note}]}]
var history_wars: Array = []       # 史料里开局以后的仗 [{year, month, attacker, defender, cb, target, note}] (第 6 块)
var history_reinforcements: Array = []  # 史料里维京人的援兵 [{year, month, realm, special, note}] (871 年的夏季大军)
var warfare: Warfare               # 打仗 (第 6 块)
var intrigue: Intrigue             # 阴谋 (第 7 块)
var story: StoryEvents             # 随机事件和压力崩溃 (第 8 块)
var history_schemes: Array = []    # 史料里的阴谋 [{year, month, schemer, target, kind, note}] (872 年阿特加尔被杀)
var rules := Rules.defaults()  # 开局设置 (照三代的游戏规则; 开局前选好)
var generated_by := {}         # 开局生成的家人: 一家之主的 id -> [妻子、孩子的 id] (「只给电脑」时玩家选的人要拿掉)
var player := ""         # 玩家这个人的 id (电脑不替玩家家里的人说亲, 不收回玩家的地); main 每一帧同步
var today := 0           # 现在是哪天 (advance 时更新; 算直辖上限、收入要用)
var houses := {}         # 家族 id -> {id, name, desc, color, design}
var map_size: Vector2i
var km_per_px: float
var coastline: Array = [] # 每个岛一圈 PackedVector2Array (领地图上的像素坐标)

var rng := RandomNumberGenerator.new()  # 开局以后的随机事 (谁什么时候死……)
var names: Dictionary
var _next_index := 1     # 新国家的编号 (地图上色用, 只增不减)
var _next_id := 1        # 新人、新家族的编号
var _kin := {}           # 国王的近亲 -> [哪几个国家的国王的近亲] (结婚、生孩子、死人以后重算)
var _kin_dirty := true
var _by_house := {}      # 家族 -> [活着的人] (有人出生、去世就重算)
var _lands := {}         # 人的 id -> [他管的领地] (领地换主人就重算)
var _vice := {}          # 副王的 id -> [国家, 公国]
var _vassals := {}       # 人的 id -> [他直接的封臣]
var _feudal_dirty := true
var _house_dirty := true

const CONCEPTION := 0.042     # 夫妻每个月怀上的机会 (再乘两个人的系数, 见 Person.fertility)
const PREGNANCY_DAYS := 270
const AFTER_BIRTH_DAYS := 90  # 生完三个月内不会又怀上
const TWINS := 0.02
const SELF_STUDY := 2         # 没有老师, 自己学 (相当于老师的本事 2)
const MAX_WARDS := 3          # 一个老师最多带几个孩子
const TEACH_TRAIT := 0.1      # 每学一年老师把一个性格传给孩子的机会
const STUDY_YEARS := 10       # 6 岁学到 15 岁


## seed: 随机的东西 (查不到的人的名字、长相基因、生日、性格, 开局以后谁什么时候死) 用的种子, 每局开新游戏换一个
static func load_867(name_seed: int = 867, p_rules: Dictionary = {}) -> World:
	var w := World.new()
	w.name_seed = name_seed
	w.rules.merge(p_rules, true)
	Person.child_health = Rules.CHILD_HEALTH.get(w.rules.child_death, Rules.CHILD_HEALTH.normal)
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
	for k in data.get("titular_kingdoms", []):
		kingdoms[k.id] = k  # 特别决议才建立的王国 (第 8 块)
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
			ruler.note = ""
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
			ruler.house = _new_house(ruler, "")
		realm.house = ruler.house
		houses[ruler.house].color = realm.color  # 统治家族的纹章跟国家一样
		houses[ruler.house].design = realm.index
		ruler.prestige = War.START_PRESTIGE_KING
		_register(ruler)
		realm.special = int(r.get("special_troops", 0))  # 不用养、死了不补的兵 (维京大军)
		if realm.titles.is_empty() and duchies.has(r.id):
			realm.titles = [r.id]  # 自己那个公国 (法理宣战要用)
		realm.ruler = ruler.name
		realm.ruler_id = ruler.id
		realms[r.id] = realm
		realm_order.append(r.id)
	for f in data.get("family", []):
		_add_family(setup, f)
	_link_spouses()
	var history: Dictionary = data.get("history", {}) if rules.history == "on" else {}
	history_marriages = history.get("marriages", [])
	history_children = history.get("children", [])
	history_wars = data.get("history", {}).get("wars", []) if rules.get("wars", "on") == "on" else []
	history_reinforcements = data.get("history", {}).get("reinforcements", []) if rules.get("wars", "on") == "on" else []
	history_schemes = data.get("history", {}).get("schemes", []) if rules.get("wars", "on") == "on" else []
	_setup_children(setup)

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
			"occupier": "", "garrison": 0.0, "fort_bonus": int(data.get("forts", {}).get(c.id, 0)),
		})
		by_id[c.id] = counties[i]
	for ring in map.coastline:
		var pts := PackedVector2Array()
		for k in range(0, ring.size(), 2):
			pts.append(Vector2(ring[k], ring[k + 1]))
		coastline.append(pts)
	_setup_homelands()
	today = start_day
	_setup_vassals(setup, data.get("vassals", []))
	_link_spouses()  # 封臣在家人后面读, 家人里有封臣的妻子 (埃德伯)
	_generate_families(setup)
	for p in living.values():
		if p.realm == "" and is_landed(p):
			p.prestige = War.START_PRESTIGE_VASSAL
	warfare = Warfare.new(self)
	warfare.build_graph()
	intrigue = Intrigue.new(self)
	story = StoryEvents.new(self)
	for c in counties:
		c.garrison = warfare.max_garrison(c)
	warfare.monthly_history_only(start_day)  # 开局就在打的仗 (867 年 1 月)


# ---- 存档 (照三代: 随时能存、能读, 每年自动存一次) ----

var name_seed := 867     # 开局用的种子 (读档时先照它把地图、名字表这些读出来, 再盖上存档里的)


func to_save() -> Dictionary:
	var ps := []
	for p in people.values():
		ps.append(p.to_save())
	var rs := {}
	for rid in realms:
		var r: Dictionary = realms[rid].duplicate(true)
		r.color = r.color.to_html()
		rs[rid] = r
	var hs := {}
	for hid in houses:
		var h: Dictionary = houses[hid].duplicate()
		h.color = h.color.to_html()
		hs[hid] = h
	var cs := []
	for c in counties:
		cs.append([c.holder, c.lord, c.occupier, c.garrison])
	return {"name_seed": name_seed, "today": today, "player": player, "rules": rules, "warfare": warfare.to_save(), "intrigue": intrigue.to_save(),
			"dejure": dejure_changes, "story": story.to_save(),
			"next_index": _next_index, "next_id": _next_id, "rng_seed": str(rng.seed), "rng_state": str(rng.state),
			"realm_order": realm_order, "realms": rs, "houses": hs, "counties": cs, "people": ps}


## 读档: 先照开局的种子读出地图、名字表、史料这些不变的东西, 再换成存档里的人、国家、家族、领地
static func from_save(s: Dictionary) -> World:
	var w := World.load_867(int(s.name_seed), s.get("rules", {}))
	w.people = {}
	w.living = {}
	w.kids_of = {}
	w.ancestor_cache = {}
	for d in s.people:  # 照存的先后放回去 (每个月一个个看人的先后一样, 读档以后接着走跟没存过一样)
		w._register(Person.from_save(d))
	w._link_spouses()
	w.realms = {}
	for rid in s.realms:
		var r: Dictionary = s.realms[rid]
		r.color = Color(r.color)
		r.index = int(r.index)
		w.realms[rid] = r
	w.realm_order = s.realm_order.duplicate()
	w.houses = {}
	for hid in s.houses:
		var h: Dictionary = s.houses[hid]
		h.color = Color(h.color)
		h.design = int(h.design)
		w.houses[hid] = h
	for i in w.counties.size():
		var cs: Array = s.counties[i]
		w.counties[i].holder = cs[0]
		w.counties[i].lord = cs[1]
		w.counties[i].occupier = cs[2] if cs.size() > 2 else ""
		w.counties[i].garrison = float(cs[3]) if cs.size() > 3 else w.warfare.max_garrison(w.counties[i])
	w.today = int(s.today)
	w.player = s.player
	w.generated_by = {}
	w._next_index = int(s.next_index)
	w._next_id = int(s.next_id)
	w.rng.seed = int(s.rng_seed)
	w.rng.state = int(s.rng_state)
	w._kin_dirty = true
	w._house_dirty = true
	w._feudal_dirty = true
	w.warfare.from_save(s.get("warfare", {}))
	w.intrigue.from_save(s.get("intrigue", {}))
	for d in s.get("dejure", {}):
		w._set_dejure(d, s.dejure[d])
	w.story.from_save(s.get("story", {}))
	return w


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
	p.former_spouses = f.get("former_spouses", []).duplicate()
	p.note = f.get("note", "")
	p.liege_realm = f.get("court", "")  # 住在哪个国王那里 (没领地; 奥斯伯特)
	for c in f.get("claims", []):
		p.claims.append("realm:" + c)
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
	_register(p)


## 每个人出身哪个王国: 国王看自己的国家, 别人看家族的国家、父母, 都没有就按文化
const CULTURE_HOME := {"anglo_saxon": "england", "cornish": "england", "welsh": "wales", "cumbric": "scotland", "gaelic": "ireland"}


func _setup_homelands() -> void:
	var house_realm := {}
	for rid in realm_order:
		house_realm[realms[rid].house] = rid
	for round in 3:  # 父母在名单后面的, 多走几遍
		for p in people.values():
			if p.homeland != "":
				continue
			var rid: String = p.realm if p.realm != "" else house_realm.get(p.house, "")
			if rid != "":
				p.homeland = realm_kingdom(rid)
			else:
				for pid in [p.father, p.mother]:
					if p.homeland == "" and people.has(pid):
						p.homeland = people[pid].homeland
				if p.homeland == "" and round == 2:
					p.homeland = CULTURE_HOME.get(p.culture, "")


## 这个国家在哪个王国 (按法理, 看它的第一块领地)
func realm_kingdom(realm_id: String) -> String:
	var cs := counties_of(realm_id)
	return kingdom_of(cs[0]).id if not cs.is_empty() else ""


## 配偶两边都记上
func _link_spouses() -> void:
	for p in people.values():
		if p.spouse != "" and people.has(p.spouse):
			people[p.spouse].spouse = p.id
	for p in people.values():
		if p.spouse != "" and people.has(p.spouse):
			p.spouse_ref = weakref(people[p.spouse])


## 开局时的小孩: 3 岁以上有小时候的性格, 6 岁以上已经在跟老师学 (照学了几年先攒好分数)
func _setup_children(setup: RandomNumberGenerator) -> void:
	for p in people.values():
		if p.alive and not p.adult(start_day):
			_setup_child(setup, p)


func _setup_child(setup: RandomNumberGenerator, p: Person) -> void:
	var a: int = p.age(start_day)
	if a >= 3:
		p.traits.append(Traits.random_childhood(setup))
	if a >= 6:
		p.focus = Traits.pick_focus(setup, p.childhood())
		p.guardian = pick_guardian(p, start_day)
		p.edu_years = a - 6
		p.edu_points = p.edu_years * _study_per_year(p, start_day)


## 开局设置「生成家人」选了「只给电脑」: 玩家选了一个开局生成过家人的人, 把这些家人拿掉
func remove_generated_family(head_id: String) -> void:
	if not generated_by.has(head_id):
		return
	var gone: Array = generated_by[head_id]
	for id in gone:
		if not people.has(id):
			continue
		var p: Person = people[id]
		people.erase(id)
		living.erase(id)
		kids_of.erase(id)
		for pid in [p.father, p.mother]:
			if kids_of.has(pid):
				kids_of[pid].erase(id)
	var head: Person = people[head_id]
	head.spouse = ""
	head.spouse_ref = null
	for q in living.values():
		if gone.has(q.guardian):
			q.guardian = ""
	generated_by.erase(head_id)
	ancestor_cache = {}
	_kin_dirty = true
	_house_dirty = true
	_feudal_dirty = true


## 开局「生成家人」(照三代的游戏规则, 三代默认开): 有领地、但没有记载家人 (没配偶、没孩子) 的人,
## 配一个妻子和一个能继承的儿子; 妻子 25 岁以上再一个孩子, 33 岁以上再一个 (名字照当时当地)
func _generate_families(setup: RandomNumberGenerator) -> void:
	if rules.generate_families == "off":
		return
	for p in living.values().duplicate():
		if not is_landed(p) or p.female or p.spouse != "" or not p.former_spouses.is_empty() or not kids_of.get(p.id, []).is_empty():
			continue
		var a: int = p.age(start_day)
		if a < Person.ADULT:
			continue
		var wife_age := clampi(a - setup.randi_range(0, 10), 16, 45) if a <= 55 else setup.randi_range(30, 45)
		var wife := make_noble(p.culture, true, wife_age, start_day)
		wife.homeland = p.homeland
		_register(wife)
		marry(p, wife, start_day, [])
		generated_by[p.id] = [wife.id]
		var count := 1 + (1 if wife_age > 25 else 0) + (1 if wife_age > 33 else 0)
		var age := setup.randi_range(0, clampi(wife_age - 17, 0, 20))
		for i in count:
			if age < 0:
				break
			var kid := _new_child(p, wife, start_day - age * GameDate.YEAR_DAYS - setup.randi_range(0, 300), 0 if i == 0 else -1)
			generated_by[p.id].append(kid.id)
			if kid.adult(start_day):
				kid.traits = Traits.random_personality(setup) + kid.traits
				kid.education = Traits.random_education(setup, "king")
			else:
				_setup_child(setup, kid)
			age -= setup.randi_range(1, 4)


func _register(p: Person) -> void:
	people[p.id] = p
	if p.alive:
		living[p.id] = p
	_house_dirty = true
	for pid in [p.father, p.mother]:
		if pid != "":
			if not kids_of.has(pid):
				kids_of[pid] = []
			kids_of[pid].append(p.id)
			kids_of[pid].sort_custom(func(a: String, b: String) -> bool: return people[a].birth_day < people[b].birth_day)
	_kin_dirty = true


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
	for tail in ["至尊王", "国王", "首领", "领主", "之王", "皇帝"]:
		if t.ends_with(tail):
			return t.substr(0, t.length() - tail.length())
	return t


func house_name(id: String) -> String:
	return houses[id].name if houses.has(id) else "家族不详"


func children_of(p: Person) -> Array:
	return kids_of.get(p.id, []).map(func(id: String) -> Person: return people[id])


func siblings_of(p: Person) -> Array:
	var ids := {}
	for pid in [p.father, p.mother]:
		if pid != "":
			for id in kids_of.get(pid, []):
				if id != p.id:
					ids[id] = true
	var list := ids.keys().map(func(id: String) -> Person: return people[id])
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
	if p.secondary.has(other.id):
		return "次妻"
	if other.id == p.betrothed:
		return "未婚妻" if other.female else "未婚夫"
	if p.former_spouses.has(other.id):
		return "前妻" if other.female else "前夫"
	if other.father == p.id or other.mother == p.id:
		return "女儿" if other.female else "儿子"
	for c in [other.father, other.mother]:
		if people.has(c) and (people[c].father == p.id or people[c].mother == p.id):
			return ("孙女" if other.female else "孙子") if c == other.father else ("外孙女" if other.female else "外孙")
	for c in [p.father, p.mother]:
		if people.has(c) and (other.id == people[c].father or other.id == people[c].mother):
			return ("祖母" if other.female else "祖父") if c == p.father else ("外祖母" if other.female else "外祖父")
	# 叔伯姑舅姨: 父母的兄弟姐妹; 侄子外甥: 兄弟姐妹的孩子
	for c in [p.father, p.mother]:
		if people.has(c) and siblings_of(people[c]).has(other):
			if c == p.father:
				return "姑姑" if other.female else "叔伯"
			return "姨妈" if other.female else "舅舅"
	for c in [other.father, other.mother]:
		if people.has(c) and siblings_of(p).has(people[c]):
			if people[c].female:
				return "外甥女" if other.female else "外甥"
			return "侄女" if other.female else "侄子"
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
func advance(days: int, now: int) -> Array:
	var events := []
	for p in living.values():
		p.pass_days(days)
	var month := _month_index(now - days)
	for d in range(now - days + 1, now + 1):
		var m := _month_index(d)
		if m != month:
			month = m
			_monthly(m, events)
		today = d
		warfare.daily(d, events)  # 打仗每天走 (行军、打仗、围城)
		intrigue.daily(d, events)  # 阴谋每天攒机会
	today = now
	story.watch(events)
	return events


func _month_index(day: int) -> int:
	var d := GameDate.from_day(day)
	return int(d[0]) * 12 + int(d[1]) - 1


func _monthly(month: int, events: Array) -> void:
	var day := GameDate.to_day(month / 12, month % 12 + 1, 1)
	today = day
	for p in living.values():
		if not p.alive:
			continue
		if not p.memories.is_empty():
			p.memories = p.memories.filter(func(m: Dictionary) -> bool: return int(m.until) > day)
		if not p.conditions.is_empty():
			p.conditions = p.conditions.filter(func(c: Dictionary) -> bool: return int(c.until) > day)
		if not p.boons.is_empty():
			p.boons = p.boons.filter(func(c: Dictionary) -> bool: return int(c.until) > day)
		if p.tyranny > 0.0:
			p.tyranny = maxf(0.0, p.tyranny - Feudal.TYRANNY_DECAY)
		if p.prisoner_of != "" and rng.randf() < Feudal.escape_chance(p, day):
			events.append({"type": "escape", "person": p.id, "jailer": p.prisoner_of, "day": day})
			p.prisoner_of = ""
			p.dungeon = false
		if not p.adult(day):
			_grow(p, day, events)
		elif p.education.is_empty() and p.personality().is_empty():
			_come_of_age(p, day, events)
		if p.realm != "":
			p.prestige += 1.0 + 0.5 * rank_bonus(p)  # 大国王、皇帝多涨一些 (第 8 块)
		if not p.pregnant.is_empty() and day >= int(p.pregnant.due):
			_give_birth(p, day, events)
		var monthly := 1.0 - pow(1.0 - p.yearly_death_chance(day), 1.0 / 12.0)
		if p.alive and rng.randf() < monthly:
			kill(p, day, events)
		if p.alive and p.female and p.pregnant.is_empty():
			_try_conceive(p, day)
	_betrothals_due(day, events)
	_history_marriages(day, events)
	if month % 3 == 0:
		_ai_marriages(day, events)  # 三个月算一次 (每次机会是一个月的三倍, 平均一样)
	_economy()
	_ai_grants(day, events)
	warfare.monthly(day, events)
	intrigue.monthly(day, events)
	Decisions.ai_monthly(self, day, events)
	story.monthly(day, events)


## 一个人死了 (国王死了就照继承法换人)。cause: 怎么死的 (空 = 生病老死这些)
func kill(p: Person, day: int, events: Array, cause := "") -> void:
	p.alive = false
	p.death_day = day
	living.erase(p.id)
	_house_dirty = true
	p.pregnant = {}
	if p.betrothed != "" and people.has(p.betrothed) and people[p.betrothed].betrothed == p.id:
		people[p.betrothed].betrothed = ""
	p.betrothed = ""
	if p.female and people.has(p.spouse):
		var h: Person = people[p.spouse]
		if h.secondary.has(p.id):
			h.secondary.erase(p.id)
			h.former_spouses.append(p.id)
		elif h.spouse == p.id:
			_promote_wife(h)
	_kin_dirty = true
	if p.prisoner_of != "":
		p.prisoner_of = ""
	events.append({"type": "death", "person": p.id, "day": day, "was_ruler": p.realm != "", "cause": cause})
	var was_realm := p.realm
	var lands := lands_of(p)
	if p.realm != "":
		_succeed(p.realm, p, day, events)
	elif is_landed(p):
		_hand_down(p, day, events)
	else:
		_move_prisoners(p, null)
	# 接他班的人 (国王: 国家的新国王; 封臣: 他第一块地的新主人)
	var heir: Person = null
	if was_realm != "":
		if realms.has(was_realm):
			heir = ruler(was_realm)
		elif not lands.is_empty() and people.has(lands[0].lord):
			heir = people[lands[0].lord]
	elif not lands.is_empty() and lands[0].lord != p.id and people.has(lands[0].lord):
		heir = people[lands[0].lord]
	if heir == p:
		heir = null
	# 照三代: 没接上班的子女 (不分男女) 对父母的国家 (封臣是领地) 有宣称; 父母自己的宣称传给子女 (弱一档, 不再往下传)
	var titles := []
	if was_realm != "" and realms.has(was_realm):
		titles.append("realm:" + was_realm)
	elif was_realm == "":
		for c in lands:
			titles.append("county:" + c.id)
	for child in children_of(p):
		if not child.alive:
			continue
		for t: String in titles:
			var holder: String = ruler(t.substr(6)).id if t.begins_with("realm:") and realms.has(t.substr(6)) else (by_id[t.substr(7)].lord if t.begins_with("county:") else "")
			if child.id != holder and not child.claims.has(t):
				child.claims.append(t)
		for t in p.claims:
			if not child.claims.has(t) and not child.weak_claims.has(t):
				child.weak_claims.append(t)
	_grieve(p)
	warfare.on_death(p, heir, day, events)
	intrigue.on_death(p)


const GRIEF_CHILD := 40.0   # 孩子死了, 父母压力涨多少 (第 8 块; 三代也有亲人去世涨压力, 数字是我们定的)
const GRIEF_SPOUSE := 30.0
const GRIEF_PARENT := 15.0  # 父母死了, 成年的子女


## 家里人去世, 亲人难过 (压力涨): 仁慈的多一半, 冷酷、残忍的少一半
func _grieve(p: Person) -> void:
	var hit := {}
	for id in [p.father, p.mother]:
		if id != "" and people.has(id) and people[id].alive:
			hit[id] = GRIEF_CHILD
	for id in [p.spouse] + p.secondary:
		if id != "" and people.has(id) and people[id].alive:
			hit[id] = GRIEF_SPOUSE
	for c in children_of(p):
		if c.alive and c.adult(today):
			hit[c.id] = GRIEF_PARENT
	for id in hit:
		var q: Person = people[id]
		var k := 1.5 if q.has_trait("compassionate") else (0.5 if q.has_trait("callous") or q.has_trait("sadistic") else 1.0)
		q.add_stress(float(hit[id]) * k)


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
		_move_domain(dead, newp)
		_move_prisoners(dead, newp)
		ev.type = "extinct"
		ev.heir = newp.id
		events.append(ev)
		return
	var heir: Person = heirs[0]
	ev.heir = heir.id
	if heir.realm != "" and heir.realm != realm_id:
		# 继承人已经是别的国家的国王: 两个国家归到他一个人手里 (封臣也跟过去)
		var target: String = heir.realm
		for c in counties:
			if c.holder == realm_id:
				c.holder = target
		for p in living.values():
			if p.liege_realm == realm_id:
				p.liege_realm = target
		realms[target].titles.append_array(realm.titles)
		realms[target].viceroys.merge(realm.viceroys)
		_merge_high_titles(target, realm)
		_move_domain(dead, heir)
		_move_prisoners(dead, heir)
		_remove_realm(realm_id)
		ev.merged_into = target
		events.append(ev)
		return
	_take_throne(realm_id, heir, day, events)
	_move_domain(dead, heir)
	_move_prisoners(dead, heir)
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
	p.liege_realm = ""
	p.contract = 1
	_kin_dirty = true
	_feudal_dirty = true


## 从一个国家里分出一个王国 (平分继承), 给 son; 返回新国家的 id
func _split_realm(realm_id: String, title: String, son: Person) -> String:
	var parent: Dictionary = realms[realm_id]
	var id := "%s_%d" % [title, _next_index]
	var c: Color = parent.color
	var realm := {
		"id": id, "title": duchies[title].name + "国王", "culture": parent.culture, "house": son.house, "ruler_id": son.id, "ruler": son.name,
		"color": Color.from_hsv(fmod(c.h + 0.07 * (1 + _next_index % 3), 1.0), c.s, clampf(c.v * 0.9, 0.3, 0.9)),
		"random": false, "index": _next_index, "titles": [title], "viceroys": {}, "capital": "",
	}
	_next_index += 1
	realms[id] = realm
	realm_order.append(id)
	for county in counties:
		if county.holder == realm_id and county.duchy == title:
			county.holder = id
			if county.lord == parent.ruler_id:
				county.lord = son.id  # 分出去的王国里, 国王直辖的领地归儿子
	_feudal_dirty = true
	for p in living.values():
		if p.liege_realm == realm_id and not lands_of(p).is_empty() and lands_of(p)[0].holder == id:
			p.liege_realm = id    # 那里的封臣跟着去
	_feudal_dirty = true
	parent.titles.erase(title)
	parent.title = "和".join(parent.titles.map(func(t: String) -> String: return duchies[t].name)) + "国王"
	_take_throne(id, son, today, [])
	_set_ruler(id, son)
	var mine := counties.filter(func(cc: Dictionary) -> bool: return cc.holder == id)
	realm.capital = mine[0].id if not mine.is_empty() else ""
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
	p.note = ""
	p.house = _new_house(p, "%s的贵族推举出来的新王族" % realm_name(realm_id))
	p.homeland = realm_kingdom(realm_id) if not counties_of(realm_id).is_empty() else ""
	houses[p.house].color = realm.color
	houses[p.house].design = realm.index
	_register(p)
	realm.house = p.house
	_set_ruler(realm_id, p)
	realm.random = true
	return p


# ---- 长大 (第 4 块) ----

## 不满 16 岁的孩子每个月: 3 岁有小时候的性格, 6 岁起跟老师学 (老师死了换一个; 找不到老师的大约一年再找一次)。
## 每过一个生日学一年 (6 岁到 15 岁, 一共 10 年): 攒分数, 老师有 10% 的机会把一个性格传给他
func _grow(p: Person, day: int, events: Array) -> void:
	var a := p.age(day)
	if a >= 3 and p.childhood() == "":
		p.traits.append(Traits.random_childhood(rng))
	if a < 6:
		return
	if p.focus == "":
		p.focus = Traits.pick_focus(rng, p.childhood())
	# 照三代 (也是第 4 块清单写的「你家孩子你挑, 电脑家的自动挑」): 学什么自动选, 玩家家里孩子的老师要玩家自己请 (有提醒)
	var mine := is_player_court(p)
	if p.guardian != "" and not people[p.guardian].alive:
		var old := p.guardian
		p.guardian = "" if mine else pick_guardian(p, day)
		events.append({"type": "guardian", "child": p.id, "old": old, "new": p.guardian, "day": day})
	elif p.guardian == "" and not mine and (p.edu_years == 0 or rng.randf() < 1.0 / 12.0):
		p.guardian = pick_guardian(p, day)
	while p.edu_years < mini(a - 5, STUDY_YEARS):
		p.edu_points += _study_per_year(p, day)
		p.edu_years += 1
		if p.guardian != "" and rng.randf() < TEACH_TRAIT:
			var choices: Array = people[p.guardian].personality().filter(func(t: String) -> bool: return not p.taught.has(t))
			if not choices.is_empty():
				p.taught.append(choices[rng.randi_range(0, choices.size() - 1)])


## 一年攒多少分: 老师这一样本事的十分之一; 学的东西合小时候的性格再加一点
func _study_per_year(p: Person, day: int) -> float:
	var g := teacher_skill(p, day)
	return (g + (2.0 if Traits.focus_fits(p.childhood(), p.focus) else 0.0)) / 10.0


## 老师教这一样的本事 (没有老师: 自己学, 算 2)
func teacher_skill(p: Person, day: int) -> int:
	if p.guardian == "" or not people.has(p.guardian) or p.focus == "":
		return SELF_STUDY
	return people[p.guardian].skill(p.focus, day)


## 能给这个孩子当老师的人: 家族里、母亲家族里的大人, 父母, 他家国王; 每个老师最多带 3 个孩子
func teacher_candidates(child: Person, day: int) -> Array:
	var houses_ok := {}
	if child.house != "":
		houses_ok[child.house] = true
	if people.has(child.mother) and people[child.mother].house != "":
		houses_ok[people[child.mother].house] = true
	var extra := [child.father, child.mother]
	var r := kin_realm(child)
	if r != "":
		extra.append(realms[r].ruler_id)
	var wards := _ward_counts()
	var list := []
	for p in living.values():
		if not p.alive or p == child or not p.adult(day):
			continue
		if not (houses_ok.has(p.house) or extra.has(p.id)):
			continue
		if p.id != child.guardian and int(wards.get(p.id, 0)) >= MAX_WARDS:
			continue
		list.append(p)
	return list


## 每个老师带着几个孩子
func _ward_counts() -> Dictionary:
	var counts := {}
	for p in living.values():
		if p.alive and p.guardian != "":
			counts[p.guardian] = int(counts.get(p.guardian, 0)) + 1
	return counts


func wards_of(teacher: Person) -> int:
	return int(_ward_counts().get(teacher.id, 0))


## 电脑挑老师: 学的那一样本事最好的
func pick_guardian(child: Person, day: int) -> String:
	var best: Person = null
	for p in teacher_candidates(child, day):
		if best == null or p.skill(child.focus, day) > best.skill(child.focus, day):
			best = p
	return best.id if best != null else ""


## 满 16 岁: 教育的档次看攒的分数 (再看聪不聪明、运气), 性格跟小时候的性格和老师有关
func _come_of_age(p: Person, day: int, events: Array) -> void:
	var ch := p.childhood()
	p.traits.erase(ch)
	if p.focus != "":
		var smart := 0.0
		for t in p.congenital():
			smart += float(Traits.get_trait(t).get("skills", {}).get("learning", 0)) / 2.0
		p.education = {"skill": p.focus, "level": Traits.education_level(p.edu_points + smart + rng.randf_range(-2.0, 2.0))}
	else:
		p.education = Traits.random_education(rng, "king" if p.rank != "" else "")
	p.traits = Traits.grown_personality(rng, ch, p.taught) + p.traits
	p.guardian = ""
	events.append({"type": "grew_up", "person": p.id, "day": day})


# ---- 生孩子 (第 4 块) ----

func _try_conceive(p: Person, day: int) -> void:
	var h := p.living_spouse()
	if h == null or day - p.last_birth < AFTER_BIRTH_DAYS:
		return
	if rng.randf() < CONCEPTION * p.fertility(day) * h.fertility(day):
		p.pregnant = {"father": h.id, "due": day + PREGNANCY_DAYS + rng.randi_range(-10, 10)}


func _give_birth(mother: Person, day: int, events: Array) -> void:
	var father: Person = people.get(mother.pregnant.father)
	mother.pregnant = {}
	mother.last_birth = day
	var kids := []
	for i in (2 if rng.randf() < TWINS else 1):
		kids.append(_new_child(father, mother, day).id)
	var died := rng.randf() < mother.childbirth_death_chance(day)
	events.append({"type": "birth", "children": kids, "mother": mother.id, "father": father.id if father else "",
			"mother_died": died, "day": day})
	if died:
		kill(mother, day, events, "生孩子时去世")


## force_female: -1 随机, 0 男孩, 1 女孩 (开局生成家人时第一个要能继承, 是男孩)
func _new_child(father: Person, mother: Person, day: int, force_female := -1) -> Person:
	var p := Person.new()
	p.female = rng.randf() < 0.5 if force_female < 0 else force_female == 1
	var doc := _history_kid(father, mother, p.female)
	p.id = doc.id if not doc.is_empty() else _new_person_id()
	p.father = father.id if father else ""
	p.mother = mother.id
	p.culture = father.culture if father else mother.culture
	p.name = doc.name if not doc.is_empty() else random_name(rng, p.culture, p.female)
	p.note = doc.get("note", "")
	p.house = father.house if father and father.house != "" else mother.house
	p.homeland = father.homeland if father else mother.homeland
	p.birth_day = day
	p.rank = "noble" if (father and father.rank != "") or mother.rank != "" else ""
	_register(p)
	p.dna = _child_dna(rng, p)
	p.traits = Traits.inherit_congenital(rng, father, mother)
	if father and rng.randf() < Marriage.kinship(self, father, mother) * Marriage.INBRED_PER_KINSHIP:
		p.traits.append("inbred")
	_random_skills(rng, p)
	return p


func _new_person_id() -> String:
	var id := "person_%d" % _next_id
	_next_id += 1
	return id


## 史料里这对父母的孩子 (这个性别下一个还没出生的); 先找写了母亲的, 再找只写了父亲的。没有就是空的
func _history_kid(father: Person, mother: Person, female: bool) -> Dictionary:
	if father == null:
		return {}
	for with_mother in [true, false]:
		for e in history_children:
			if e.father != father.id or e.has("mother") != with_mother:
				continue
			if with_mother and e.mother != mother.id:
				continue
			for k in e.kids:
				if bool(k.female) == female and not people.has(k.id):
					return k
	return {}


## 史料里这两个人是不是夫妻 (是就返回说明, 不是返回空的)
func historical_match(a: Person, b: Person) -> String:
	for m in history_marriages:
		if (m.a == a.id and m.b == b.id) or (m.a == b.id and m.b == a.id):
			return m.note
	return ""


# ---- 结婚 (第 4 块) ----

func is_player_family(p: Person) -> bool:
	if player == "" or not people.has(player) or p.house == "":
		return false
	return p.house == people[player].house


## 归玩家管的人 (三代: 婚事由这个人所在宫廷的主人做主; 我们还没有宫廷, 先这样算, 用户 2026-10-10 选的):
## 玩家自己, 和玩家家族里没有领地的人。封了领地的家里人有自己的宫廷, 自己做主 (电脑替他说亲), 他的孩子也归他管
func is_player_court(p: Person) -> bool:
	if player == "":
		return false
	if p.id == player:
		return true
	if not is_player_family(p) or is_landed(p):
		return false
	var dad: Person = people.get(p.father)
	return not (dad != null and dad.alive and dad.id != player and is_landed(dad))


## 玩家这个人 (还没选是 null)
func me() -> Person:
	return people.get(player) if player != "" else null


func marry(a: Person, b: Person, day: int, events: Array, note := "") -> void:
	var before_a := kin_realm(a)
	var before_b := kin_realm(b)
	_marriage_prestige(a, b)
	var husband := a if not a.female else b
	var wife := b if husband == a else a
	var second := husband.married()  # 爱尔兰古法: 已经有正妻, 这个是次妻
	for pair in [[husband, wife], [wife, husband]]:
		var x: Person = pair[0]
		if x == husband and second:
			x.secondary.append(wife.id)
		else:
			if x.spouse != "" and x.spouse != pair[1].id:
				x.former_spouses.append(x.spouse)
			x.spouse = pair[1].id
			x.spouse_ref = weakref(pair[1])
		x.betrothed = ""
	_kin_dirty = true
	var alliance := []
	if before_a != "" and before_b != "" and before_a != before_b:
		alliance = [before_a, before_b]
	events.append({"type": "marriage", "husband": husband.id, "wife": wife.id, "day": day, "history": note,
			"alliance": alliance, "secondary": second})


## 正妻去世: 最早娶的次妻当正妻
func _promote_wife(h: Person) -> void:
	for id in h.secondary.duplicate():
		if people[id].alive:
			h.secondary.erase(id)
			if h.spouse != "":
				h.former_spouses.append(h.spouse)
			h.spouse = id
			h.spouse_ref = weakref(people[id])
			return


## 活着的妻子 (正妻在前, 再是次妻); 女人就是活着的丈夫
func wives_of(p: Person) -> Array:
	var list := []
	var s := p.living_spouse()
	if s != null:
		list.append(s)
	for id in p.secondary:
		if people.has(id) and people[id].alive:
			list.append(people[id])
	return list


## 娶 / 嫁身份高的人: 身份低的那家的国王涨威望 (每高一档 25)
func _marriage_prestige(a: Person, b: Person) -> void:
	for pair in [[a, b], [b, a]]:
		var gain := Marriage.status(self, pair[1]) - Marriage.status(self, pair[0])
		var head := head_of(pair[0])
		if gain > 0 and head.realm != "":
			head.prestige += gain * 25.0


func betroth(a: Person, b: Person, day: int, events: Array) -> void:
	a.betrothed = b.id
	b.betrothed = a.id
	events.append({"type": "betrothal", "a": a.id, "b": b.id, "day": day})


## 订了婚的两个人都满 16 岁就成亲 (中间出了别的事不能结了就退婚)
func _betrothals_due(day: int, events: Array) -> void:
	for p in living.values():
		if not p.alive or p.female or p.betrothed == "":
			continue
		var other: Person = people[p.betrothed]
		if not (p.adult(day) and other.adult(day)):
			continue
		if Marriage.problem(self, p, other, day) == "":
			marry(p, other, day, events)
		else:
			p.betrothed = ""
			other.betrothed = ""


## 玩家给自家的人说亲: 对方答应就结婚 (有一个不满 16 岁就订婚)。返回 {ok, text}
func propose(mine: Person, theirs: Person, day: int, events: Array) -> Dictionary:
	var betrothal := not (mine.adult(day) and theirs.adult(day))
	var why := Marriage.problem(self, mine, theirs, day, betrothal)
	if why != "":
		return {"ok": false, "text": why}
	var acc := Marriage.acceptance(self, me(), mine, theirs, day)
	if acc.total <= 0:
		return {"ok": false, "text": "%s家不答应 (鼠标指着那一行看为什么)" % theirs.name}
	if acc.get("hook", 0) > 0 and acc.total - int(acc.hook) <= 0:
		intrigue.use_hook(me(), head_of(theirs), day)  # 不用把柄不答应: 用掉把柄 (强的五年后才能再用)
	if not people.has(theirs.id):
		if theirs.homeland == "":
			theirs.homeland = mine.homeland  # 本地贵族家的
		_register(theirs)
	if betrothal:
		betroth(mine, theirs, day, events)
		return {"ok": true, "text": "%s和%s订婚了, 两个人都满 16 岁就成亲" % [mine.name, theirs.name]}
	marry(mine, theirs, day, events)
	return {"ok": true, "text": "%s和%s结婚了" % [mine.name, theirs.name]}


## 本地贵族家的人 (随机生成的, 还没放进世界; 说亲选上了才放进去)
func make_noble(culture: String, female: bool, age: int, day: int) -> Person:
	var p := Person.new()
	p.id = _new_person_id()
	p.female = female
	p.culture = culture
	p.name = random_name(rng, culture, female)
	p.birth_day = day - age * GameDate.YEAR_DAYS - rng.randi_range(0, GameDate.YEAR_DAYS - 1)
	p.birth_estimated = true
	p.rank = "noble"
	p.dna = Portrait.random_dna(rng, culture)
	p.traits = Traits.random_congenital(rng)
	if age >= Person.ADULT:
		p.traits = Traits.random_personality(rng) + p.traits
		p.education = Traits.random_education(rng)
	elif age >= 3:
		p.traits.append(Traits.random_childhood(rng))
	_random_skills(rng, p)
	p.house = _new_house(p, "本地的贵族家族")
	p.note = ""
	return p


## 史料里的婚事: 到了年份, 两个人都在、都能结 (不是玩家家里的人), 电脑照史料安排 (平均半年内)
func _history_marriages(day: int, events: Array) -> void:
	var year: int = GameDate.from_day(day)[0]
	for m in history_marriages:
		if year < int(m.year) or not people.has(m.a) or not people.has(m.b):
			continue
		var a: Person = people[m.a]
		var b: Person = people[m.b]
		if a.spouse == b.id or is_player_court(a) or is_player_court(b):
			continue
		if Marriage.problem(self, a, b, day) == "" and rng.randf() < 1.0 / 6.0:
			marry(a, b, day, events, m.note)


## 这个人在等史料里的婚事吗 (对方在、也能结): 返回对方的 id, 不等返回空的
func _reserved_for(p: Person, day: int) -> String:
	for m in history_marriages:
		var other := ""
		if m.a == p.id:
			other = m.b
		elif m.b == p.id:
			other = m.a
		if other == "" or not people.has(other):
			continue
		var o: Person = people[other]
		if o.alive and Marriage.free_to_marry(self, o) and o.betrothed == "" and Marriage.kin_problem(self, p, o) == "":
			return other
	return ""


## 电脑说亲: 国王和国王的近亲没结婚的, 平均一年里找一个对象 (找不到合适的就娶本地贵族家的)
func _ai_marriages(day: int, events: Array) -> void:
	var men := []
	var women := []
	for p in living.values():
		if p.alive and p.adult(day) and not p.married() and p.betrothed == "" and p.prisoner_of == "" and not is_player_court(p) and Marriage.status(self, p) >= 2:
			(women if p.female else men).append(p)
	var heirs := {}
	for rid in realm_order:
		var h := heir(rid, day)
		if h:
			heirs[h.id] = true
	# 爱尔兰古法: 电脑的爱尔兰国王没有活着的儿子, 会再娶一个 (平均两年里)
	var more := []
	for rid in realm_order:
		var k := ruler(rid)
		if k.married() and Marriage.free_to_marry(self, k) and not is_player_court(k) and k.age(day) <= 55 \
				and not children_of(k).any(func(c: Person) -> bool: return c.alive and not c.female) and rng.randf() < 0.5:
			more.append(k)
	for seeker in men + women + more:
		if not Marriage.free_to_marry(self, seeker) or not _wants_spouse(seeker, day, heirs) or rng.randf() >= 3.0 / 12.0:
			continue
		var best: Person = null
		var best_score := -INF
		for c in (women if not seeker.female else men):
			if c.married() or c.betrothed != "" or not _age_fits(seeker, c, day):
				continue
			var reserved := _reserved_for(c, day)
			if reserved != "" and reserved != seeker.id:
				continue
			if Marriage.problem(self, seeker, c, day) != "":
				continue
			var score := Marriage.ai_score(self, seeker, c, day, rng)
			if score > best_score:
				best_score = score
				best = c
		if best == null or best_score < 15.0 or rng.randf() < 0.25:
			var age: int = seeker.age(day)
			var their_age := clampi(age - rng.randi_range(0, 8), 16, 30) if not seeker.female else clampi(age + rng.randi_range(0, 8), 17, 55)
			best = make_noble(seeker.culture, not seeker.female, their_age, day)
			best.homeland = seeker.homeland
			_register(best)
		marry(seeker, best, day, events)


## 电脑给谁说亲: 国王本人、国王的孩子和兄弟姐妹、继承人 (孙子侄子这些等他父亲当了国王再说, 不然人太多)
func _wants_spouse(p: Person, day: int, heirs: Dictionary) -> bool:
	if p.age(day) > (40 if p.female else 60) or _reserved_for(p, day) != "":
		return false
	if p.realm != "" or heirs.has(p.id) or is_landed(p):
		return true
	for pid in [p.father, p.mother]:
		if pid != "":
			for sib in kids_of.get(pid, []) + [pid]:
				if people[sib].alive and people[sib].realm != "":
					return true
	return false


## 年纪合不合适 (男的一般比女的大; 女的 35 岁以上电脑不太找)
func _age_fits(seeker: Person, c: Person, day: int) -> bool:
	var husband := seeker if not seeker.female else c
	var wife := c if husband == seeker else seeker
	var gap := husband.age(day) - wife.age(day)
	return wife.age(day) <= 35 and gap >= -5 and gap <= 25


# ---- 国王的近亲和同盟 (第 4 块) ----

## 国王的近亲: 本人、父母、祖父母、兄弟姐妹、子女、孙子女 (活着的)。-> {人的 id: [哪几个国家]}
func _kin_map() -> Dictionary:
	if not _kin_dirty:
		return _kin
	_kin = {}
	for rid in realm_order:
		var r := ruler(rid)
		var close := [r]
		for pid in [r.father, r.mother]:
			if people.has(pid):
				var parent: Person = people[pid]
				close.append(parent)
				for gid in [parent.father, parent.mother]:
					if people.has(gid):
						close.append(people[gid])
		close.append_array(siblings_of(r))
		for c in children_of(r):
			close.append(c)
			close.append_array(children_of(c))
		for p in close:
			if p.alive:
				if not _kin.has(p.id):
					_kin[p.id] = []
				if not _kin[p.id].has(rid):
					_kin[p.id].append(rid)
	_kin_dirty = false
	return _kin


## 家族里活着的人
func house_members(house: String) -> Array:
	if _house_dirty:
		_by_house = {}
		for p in living.values():
			if p.house != "":
				if not _by_house.has(p.house):
					_by_house[p.house] = []
				_by_house[p.house].append(p)
		_house_dirty = false
	return _by_house.get(house, [])


## 这个人是哪个国王的近亲 (国王本人就是自己的国家), 不是就返回空的
func kin_realm(p: Person) -> String:
	if p.realm != "":
		return p.realm
	var list: Array = _kin_map().get(p.id, [])
	return list[0] if not list.is_empty() else ""


## 这个人跟国王是什么关系 (国王的弟弟、国王的女儿……), 不是国王的近亲就是空的
func ruler_kin(p: Person) -> String:
	var rid := kin_realm(p)
	if rid == "":
		return ""
	if p.realm != "":
		return "国王"
	var rel := relation(ruler(rid), p)
	return "%s的%s" % [realms[rid].ruler, rel if rel != "" else "亲人"]


## 给这个人的婚事做主的人: 他是哪个国王的近亲, 就是那个国王; 不是就是他自己
func head_of(p: Person) -> Person:
	var rid := kin_realm(p)
	return ruler(rid) if rid != "" else p


## 同盟: 两个国王的近亲 (或者国王本人) 结了婚, 两国就是同盟
func allies(realm_id: String) -> Array:
	var kin := _kin_map()
	var found := []
	for id in kin:
		if not kin[id].has(realm_id):
			continue
		for partner in wives_of(people[id]):
			for other in kin.get(partner.id, []):
				if other != realm_id and not found.has(other):
					found.append(other)
	return found


# ---- 封臣 (第 5 块) ----

## 开局: 每块领地先归国王; 史料里有记载的封臣用真名; 三块领地以上的国家, 国王留都城和上限以内的, 多的给随机生成的封臣
func _setup_vassals(setup: RandomNumberGenerator, known: Array) -> void:
	for rid in realm_order:
		var cs := counties_of(rid)
		realms[rid].capital = cs[0].id if not cs.is_empty() else ""
		realms[rid].viceroys = {}
	for c in counties:
		c.lord = realms[c.holder].ruler_id
	for v in known:
		_add_vassal(setup, v)
	for rid in realm_order:
		var cs := counties_of(rid)
		if cs.size() <= 2:
			continue
		var k := ruler(rid)
		var mine := cs.filter(func(c: Dictionary) -> bool: return c.lord == k.id)
		var limit := Feudal.domain_limit(k, start_day, rank_bonus(k))
		for i in range(limit, mine.size()):
			_new_vassal_noble(setup, rid, mine[i])
	_feudal_dirty = true


## 史料里有记载的封臣 (world_867.json 的 vassals)
func _add_vassal(setup: RandomNumberGenerator, v: Dictionary) -> void:
	var c: Dictionary = by_id[v.county]
	var p := Person.new()
	p.id = v.id
	p.name = v.name
	p.culture = v.culture
	p.house = v.house
	p.note = v.get("note", "")
	p.rank = "noble"
	p.birth_estimated = true
	p.birth_day = GameDate.to_day(int(v.born), 1, 1) + setup.randi_range(0, GameDate.YEAR_DAYS - 1)
	p.dna = Portrait.random_dna(setup, p.culture)
	p.traits = Traits.random_personality(setup) + Traits.random_congenital(setup)
	p.education = Traits.random_education(setup, "king")
	_random_skills(setup, p)
	p.liege_realm = c.holder
	p.homeland = realm_kingdom(c.holder)
	c.lord = p.id
	_register(p)


## 查不到的封臣: 随机生成一个当地的贵族 (名字照当时当地)
func _new_vassal_noble(setup: RandomNumberGenerator, rid: String, c: Dictionary) -> Person:
	var realm: Dictionary = realms[rid]
	var p := Person.new()
	p.id = _new_person_id()
	p.culture = realm.culture
	# 同一个国家的封臣尽量不重名 (名字表就那么些, 试几次)
	var taken := {}
	for q in living.values():
		if q.liege_realm == rid or q.realm == rid:
			taken[q.name] = true
	p.name = random_name(setup, p.culture, false)
	for k in 6:
		if not taken.has(p.name):
			break
		p.name = random_name(setup, p.culture, false)
	p.rank = "noble"
	p.birth_estimated = true
	p.birth_day = start_day - setup.randi_range(22, 55) * GameDate.YEAR_DAYS - setup.randi_range(0, 364)
	p.dna = Portrait.random_dna(setup, p.culture)
	p.traits = Traits.random_personality(setup) + Traits.random_congenital(setup)
	p.education = Traits.random_education(setup, "king")
	_random_skills(setup, p)
	p.house = _new_house(p, "%s的贵族家族" % realm_name(rid))
	p.note = ""
	p.liege_realm = rid
	p.homeland = realm_kingdom(rid)
	c.lord = p.id
	_register(p)
	return p


func _feudal_index() -> void:
	if not _feudal_dirty:
		return
	_lands = {}
	_vice = {}
	_vassals = {}
	for c in counties:
		if not _lands.has(c.lord):
			_lands[c.lord] = []
		_lands[c.lord].append(c)
	for rid in realm_order:
		var vr: Dictionary = realms[rid].get("viceroys", {})
		for d in vr:
			_vice[vr[d]] = [rid, d]
	_feudal_dirty = false
	for id in _lands.keys() + _vice.keys():
		if not people.has(id):
			continue
		var l := liege_of(people[id])
		if l != null:
			if not _vassals.has(l.id):
				_vassals[l.id] = []
			if not _vassals[l.id].has(people[id]):
				_vassals[l.id].append(people[id])


## 他管的领地 (国王的都城在最前面)
func lands_of(p: Person) -> Array:
	_feudal_index()
	var list: Array = _lands.get(p.id, []).duplicate()
	if p.realm != "" and realms.has(p.realm):
		var cap: String = realms[p.realm].capital
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id == cap and b.id != cap)
	return list


## 是副王的话: 哪个公国, 不是就是空的
func viceroy_duchy(p: Person) -> String:
	_feudal_index()
	return _vice[p.id][1] if _vice.has(p.id) else ""


func is_landed(p: Person) -> bool:
	if p.realm != "":
		return true
	_feudal_index()
	return _lands.has(p.id) or _vice.has(p.id)


## 这个人属于哪个国家 (国王是自己的国家, 封臣是他效忠的国家)
func realm_of_person(p: Person) -> String:
	return p.realm if p.realm != "" else p.liege_realm


## 他在哪个国家 (国王、封臣看头衔; 别人看他是哪个国王的近亲)
func home_realm(p: Person) -> String:
	var r := realm_of_person(p)
	return r if r != "" else kin_realm(p)


## 他的上级 (封臣的国王或者副王); 国王和没领地的人是 null
func liege_of(p: Person) -> Person:
	if p.realm != "" or p.liege_realm == "" or not realms.has(p.liege_realm) or not realms[p.liege_realm].has("ruler_id"):
		return null
	var realm: Dictionary = realms[p.liege_realm]
	if viceroy_duchy(p) != "":
		return ruler(p.liege_realm)
	var ls: Array = _lands.get(p.id, [])
	if ls.is_empty():
		return null
	var vr: Dictionary = realm.get("viceroys", {})
	var d: String = ls[0].duchy
	if vr.has(d) and vr[d] != p.id and people.has(vr[d]):
		return people[vr[d]]
	return ruler(p.liege_realm)


func vassals_of(p: Person) -> Array:
	_feudal_index()
	return _vassals.get(p.id, []).duplicate()


## 头衔: 「威塞克斯国王」「伯克郡郡长」「肯特副王」; 没领地是空的
func title_of(p: Person) -> String:
	if p.realm != "" and realms.has(p.realm):
		return realms[p.realm].title
	var d := viceroy_duchy(p)
	if d != "":
		return duchies[d].name + "副王"
	var ls := lands_of(p)
	if ls.is_empty():
		return ""
	return ls[0].name + Feudal.kind(self, p.liege_realm)


func vassal_kind(p: Person) -> String:
	if viceroy_duchy(p) != "":
		return "副王"
	return Feudal.kind(self, p.liege_realm)


## 一个月的收入: 直辖领地 (上限以内) 出的 + 封臣交上来的, 封臣再按合同交一部分给上面。
## memo: 一次算很多人时存已经算过的 (每月收钱时用)
func income(p: Person, memo: Dictionary = {}) -> Dictionary:
	if memo.has(p.id):
		return memo[p.id]
	var dom := lands_of(p)
	var limit := Feudal.domain_limit(p, today, rank_bonus(p))
	var held := 0  # 被敌人占领的地不出钱不出兵 (第 6 块)
	for c in dom:
		if c.occupier == "":
			held += 1
	var active := mini(held, limit)
	var own_gold := active * Feudal.GOLD_PER_COUNTY
	var own_levy := active * Feudal.LEVY_PER_COUNTY
	var from_gold := 0.0
	var from_levy := 0
	for v in vassals_of(p):
		var iv := income(v, memo)
		from_gold += iv.paid_gold
		from_levy += iv.paid_levy
	var paid_gold := 0.0
	var paid_levy := 0
	if p.realm == "" and liege_of(p) != null:
		paid_gold = (own_gold + from_gold) * Feudal.TAX_SHARE[p.contract]
		paid_levy = roundi((own_levy + from_levy) * Feudal.LEVY_SHARE[p.contract])
	var boons := 0.0  # 一阵子多收 (少收) 的钱: 集市、金匠、强盗…… (第 8 块的事件)
	for b in p.boons:
		boons += float(b.gold)
	var result := {"domain": dom.size(), "limit": limit, "active": active, "own_gold": own_gold, "own_levy": own_levy,
			"from_gold": from_gold, "from_levy": from_levy, "paid_gold": paid_gold, "paid_levy": paid_levy, "boons": boons,
			"gold": own_gold + from_gold - paid_gold + boons, "levy": own_levy + from_levy - paid_levy}
	memo[p.id] = result
	return result


func _set_lord(c: Dictionary, p: Person) -> void:
	c.lord = p.id
	_feudal_dirty = true


## 国王死了: 他直辖的领地归新国王
func _move_domain(from: Person, to: Person) -> void:
	for c in counties:
		if c.lord == from.id:
			c.lord = to.id
	_feudal_dirty = true


## 关在 from 大牢里的人改关在 to 那里 (to 是 null 就放了)
func _move_prisoners(from: Person, to: Person) -> void:
	for p in living.values():
		if p.prisoner_of == from.id:
			p.prisoner_of = to.id if to != null and to.alive else ""


## 当上国王: 以前是副王的, 公国头衔还给国家; 在别的国家有领地的, 那些地传给他家里别人
func _take_throne(realm_id: String, heir: Person, day: int, events: Array) -> void:
	var d := viceroy_duchy(heir)
	if d != "":
		var vrid: String = _vice[heir.id][0]
		realms[vrid].viceroys.erase(d)
		if vrid == realm_id:
			realms[realm_id].titles.append(d)
		_feudal_dirty = true
	if heir.liege_realm != "" and heir.liege_realm != realm_id and not lands_of(heir).is_empty():
		_hand_down(heir, day, events)


## 封臣去世 (或者当了别国的国王): 领地照他家的继承法传; 家里没人就归上面
func _hand_down(p: Person, day: int, events: Array) -> void:
	var rid := p.liege_realm
	var liege := liege_of(p)
	var lands := lands_of(p)
	var vice := viceroy_duchy(p)
	var law := Succession.law_of(p.culture)
	var heirs: Array = Succession.candidates_for(self, p, law, day).filter(func(h: Person) -> bool:
		return h.alive and h.realm == "" and h.prisoner_of == "" and (h.liege_realm == "" or h.liege_realm == rid or lands_of(h).is_empty()))
	_move_prisoners(p, heirs[0] if not heirs.is_empty() else liege)
	if heirs.is_empty():
		var to := liege if liege != null else (ruler(rid) if realms.has(rid) else null)
		if to != null:
			for c in lands:
				_set_lord(c, to)
		if vice != "" and realms.has(rid):
			realms[rid].viceroys.erase(vice)
			realms[rid].titles.append(vice)
		_feudal_dirty = true
		events.append({"type": "escheat", "dead": p.id, "to": to.id if to != null else "", "realm": rid,
				"counties": lands.map(func(c: Dictionary) -> String: return c.id), "day": day})
		return
	var heir: Person = heirs[0]
	heir.liege_realm = rid
	heir.contract = p.contract
	var sons: Array = heirs.filter(func(h: Person) -> bool: return h.father == p.id and h != heir)
	for i in lands.size():
		var to: Person = heir
		if law == "partition" and i > 0 and i - 1 < sons.size():
			to = sons[i - 1]  # 平分: 多出来的领地分给下面的儿子
			to.liege_realm = rid
		_set_lord(lands[i], to)
	if vice != "":
		realms[rid].viceroys[vice] = heir.id
	_feudal_dirty = true
	events.append({"type": "vassal_succession", "dead": p.id, "heir": heir.id, "realm": rid, "law": law, "day": day})


## 每个月: 收钱 (直辖的 + 封臣交的), 封臣的威望
func _economy() -> void:
	var memo := {}
	for p in living.values():
		if p.alive and is_landed(p):
			p.gold += income(p, memo).gold
			if p.realm == "":
				p.prestige += 0.5


## 电脑的国王: 直辖超过上限, 把多的 (不是都城) 封给家里没领地的成年男人, 没有就封给本地贵族 (平均三个月封一块)
func _ai_grants(day: int, events: Array) -> void:
	for rid in realm_order.duplicate():
		var k := ruler(rid)
		if k.id == player or rng.randf() >= 1.0 / 3.0:
			continue
		var dom := lands_of(k)
		if dom.size() <= Feudal.domain_limit(k, day, rank_bonus(k)):
			continue
		var c: Dictionary = dom[dom.size() - 1]
		if c.id == realms[rid].capital:
			continue
		var pick: Person = null
		for m in house_members(k.house):
			if m != k and not m.female and m.adult(day) and m.prisoner_of == "" and not is_landed(m) and m.id != player:
				pick = m
				break
		if pick == null:
			pick = make_noble(realms[rid].culture, false, rng.randi_range(25, 45), day)
			pick.homeland = realm_kingdom(rid)
			_register(pick)
		grant_county(k, c, pick, day, events)


# ---- 国王 (或者副王) 对人做的事 (第 5 块): 都返回 {ok, text} ----

## 把直辖的一块领地封给别人 (都城不能封)
func grant_county(liege: Person, c: Dictionary, target: Person, day: int, events: Array) -> Dictionary:
	var rid := realm_of_person(liege)
	if c.lord != liege.id:
		return {"ok": false, "text": "这块领地不是你直辖的"}
	if realms.has(rid) and c.id == realms[rid].capital:
		return {"ok": false, "text": "都城不能封出去"}
	var why := grant_problem(liege, target, day)
	if why != "":
		return {"ok": false, "text": why}
	if not people.has(target.id):
		_register(target)
	target.liege_realm = rid
	if target.homeland == "":
		target.homeland = realm_kingdom(rid)
	_set_lord(c, target)
	target.remember(liege.id, "封给我领地", 40, day + 20 * GameDate.YEAR_DAYS)
	_kin_dirty = true
	events.append({"type": "grant", "liege": liege.id, "target": target.id, "county": c.id, "day": day})
	return {"ok": true, "text": "把%s封给了%s, 他现在是%s" % [c.name, target.name, title_of(target)]}


func grant_problem(liege: Person, target: Person, day: int) -> String:
	if not target.alive:
		return "人已经去世了"
	if not target.adult(day):
		return "%s还不满 16 岁" % target.name
	if target.female:
		return "领地只封给男人 (继承法只有男人能继承)"
	if target.realm != "":
		return "%s是别国的国王" % target.name
	if target.prisoner_of != "":
		return "%s关在大牢里" % target.name
	if target.liege_realm != "" and target.liege_realm != realm_of_person(liege) and not lands_of(target).is_empty():
		return "%s在别的国家有领地" % target.name
	return ""


## 把一个公国头衔封给家里人当副王: 那个公国里国王直辖的领地都归他, 那里的封臣也归他管
func grant_viceroy(king: Person, duchy: String, target: Person, day: int, events: Array) -> Dictionary:
	var rid := king.realm
	if rid == "" or not realms[rid].titles.has(duchy) or realms[rid].titles[0] == duchy:
		return {"ok": false, "text": "只有国王手里多出来的公国头衔能封 (主要的那个不能)"}
	var why := grant_problem(king, target, day)
	if why != "":
		return {"ok": false, "text": why}
	if target.house != king.house:
		return {"ok": false, "text": "副王只封给自己家族的人"}
	target.liege_realm = rid
	for c in counties:
		if c.lord == king.id and c.duchy == duchy and c.id != realms[rid].capital:
			c.lord = target.id
	realms[rid].titles.erase(duchy)
	realms[rid].viceroys[duchy] = target.id
	_feudal_dirty = true
	target.remember(king.id, "封我当副王", 60, day + 20 * GameDate.YEAR_DAYS)
	events.append({"type": "grant", "liege": king.id, "target": target.id, "duchy": duchy, "day": day})
	return {"ok": true, "text": "%s当了%s副王" % [target.name, duchies[duchy].name]}


## 收回封臣的领地 (他可能不肯: 对你好感小于 0 就不肯, 算抗命; 关在大牢里的不能不肯)
func revoke(liege: Person, target: Person, day: int, events: Array) -> Dictionary:
	if liege_of(target) != liege:
		return {"ok": false, "text": "%s不是你的封臣" % target.name}
	var o := target.opinion_of(liege)
	var hooked: bool = target.prisoner_of == "" and o.total < 0 and intrigue.held_by(target, liege) and intrigue.hook_ready(liege, target, day)
	if hooked:
		intrigue.use_hook(liege, target, day)  # 用把柄逼他交出来
	if target.prisoner_of == "" and o.total < 0 and not hooked:
		target.crimes["抗命"] = day + Feudal.CRIME_YEARS * GameDate.YEAR_DAYS
		events.append({"type": "refused", "liege": liege.id, "target": target.id, "day": day})
		return {"ok": false, "text": "%s不肯交出领地 (他对你的好感 %+d)。他这是抗命, 你现在有理由把他关起来" % [target.name, o.total]}
	var tyr := Feudal.revoke_tyranny(self, target, day)
	var k := vassal_kind(target)
	liege.tyranny += tyr
	var vice := viceroy_duchy(target)
	if vice != "":
		var rid: String = _vice[target.id][0]
		realms[rid].viceroys.erase(vice)
		realms[rid].titles.append(vice)
	for c in lands_of(target):
		c.lord = liege.id
	_feudal_dirty = true
	var years := day + 20 * GameDate.YEAR_DAYS
	target.remember(liege.id, "收回了我的领地", -30 if k == "郡长" else -40, years)
	for f in _close_family(target):
		f.remember(liege.id, "收回了家里人的领地", -15, day + 10 * GameDate.YEAR_DAYS)
	events.append({"type": "revoke", "liege": liege.id, "target": target.id, "tyranny": tyr, "day": day})
	var note := "撤换郡长不算暴政" if k == "郡长" and tyr == 0.0 else ("有正当理由, 不算暴政" if tyr == 0.0 else "暴政 +%d" % int(tyr))
	return {"ok": true, "text": "收回了%s的领地 (%s)" % [target.name, note]}


## 关大牢: 有理由 (犯过罪) 不算暴政; 可能抓不到
func arrest(jailer: Person, target: Person, day: int, events: Array) -> Dictionary:
	var why := arrest_problem(jailer, target)
	if why != "":
		return {"ok": false, "text": why}
	var forced: bool = intrigue.held_by(target, jailer) and intrigue.hook_ready(jailer, target, day)
	var bonus := 0.0
	if not forced and intrigue.hook_ready(jailer, target, day):
		bonus = Schemes.HOOK_ARREST_WEAK
	if forced or bonus > 0.0:
		intrigue.use_hook(jailer, target, day)
	if not forced and rng.randf() >= Feudal.arrest_chance(jailer, target, day) + bonus:
		target.remember(jailer.id, "想抓我", -40, day + 10 * GameDate.YEAR_DAYS)
		events.append({"type": "arrest_failed", "jailer": jailer.id, "target": target.id, "day": day})
		return {"ok": false, "text": "没抓到%s! 他知道你想抓他, 很恨你" % target.name}
	var just := Feudal.has_crime(target, day)
	if not just:
		jailer.tyranny += Feudal.TYRANNY
	target.prisoner_of = jailer.id
	target.dungeon = false
	target.betrothed = ""
	for f in _close_family(target):
		f.remember(jailer.id, "关了我的家人", -20, day + 10 * GameDate.YEAR_DAYS)
	events.append({"type": "arrest", "jailer": jailer.id, "target": target.id, "day": day})
	return {"ok": true, "text": "把%s关起来了 (软禁; %s)" % [target.name, "他有罪, 不算暴政" if just else "没理由, 暴政 +%d" % int(Feudal.TYRANNY)]}


func arrest_problem(jailer: Person, target: Person) -> String:
	if target == jailer:
		return "不能抓自己"
	if intrigue.held_by(jailer, target):
		return "%s攥着你的把柄, 关不了他" % target.name
	if not target.alive:
		return "人已经去世了"
	if target.prisoner_of != "":
		return "%s已经关在大牢里了" % target.name
	if target.realm != "":
		return "%s是别国的国王 (打仗抓住才行, 第 6 块)" % target.name
	var mine := realm_of_person(jailer)
	if mine == "" or home_realm(target) != mine:
		return "%s不在你的国家里" % target.name
	return ""


func release(jailer: Person, prisoner: Person, day: int) -> Dictionary:
	prisoner.prisoner_of = ""
	prisoner.dungeon = false
	prisoner.remember(jailer.id, "放了我", 20, day + 10 * GameDate.YEAR_DAYS)
	return {"ok": true, "text": "放了%s" % prisoner.name}


## 要赎金: 他自己出, 不够就他家里做主的人出
func ransom(jailer: Person, prisoner: Person, day: int) -> Dictionary:
	var cost := Feudal.ransom(self, prisoner)
	var payer := prisoner if prisoner.gold >= cost else head_of(prisoner)
	if payer == jailer or payer.gold < cost:
		return {"ok": false, "text": "%s家拿不出 %d 金币" % [prisoner.name, cost]}
	payer.gold -= cost
	jailer.gold += cost
	prisoner.prisoner_of = ""
	prisoner.dungeon = false
	prisoner.remember(jailer.id, "要了赎金才放我", -10, day + 10 * GameDate.YEAR_DAYS)
	return {"ok": true, "text": "%s付了 %d 金币赎金, 放了%s" % [payer.name, cost, prisoner.name]}


func execute(jailer: Person, prisoner: Person, day: int, events: Array) -> Dictionary:
	if not Feudal.has_crime(prisoner, day):
		jailer.tyranny += Feudal.TYRANNY_EXECUTE
	jailer.add_stress(execute_stress(jailer, prisoner, day))
	for f in _close_family(prisoner):
		f.remember(jailer.id, "处死了我的家人", -50, day + 30 * GameDate.YEAR_DAYS)
	var name := prisoner.name
	kill(prisoner, day, events, "被处死了")
	return {"ok": true, "text": "处死了%s" % name}


## 处死人违背性格涨压力 (第 8 块): 仁慈 +30、宽恕 +20, 没罪的还让公正的 +20; 残忍的反而 -10
static func execute_stress(jailer: Person, prisoner: Person, day: int) -> float:
	var v := 0.0
	if jailer.has_trait("compassionate"):
		v += 30.0
	if jailer.has_trait("forgiving"):
		v += 20.0
	if jailer.has_trait("just") and not Feudal.has_crime(prisoner, day):
		v += 20.0
	if jailer.has_trait("sadistic"):
		v -= 10.0
	return v


func toggle_dungeon(prisoner: Person) -> Dictionary:
	prisoner.dungeon = not prisoner.dungeon
	return {"ok": true, "text": "把%s%s" % [prisoner.name, "关进了地牢" if prisoner.dungeon else "改成了软禁"]}


func gift(giver: Person, target: Person, day: int) -> Dictionary:
	if giver.gold < Feudal.GIFT:
		return {"ok": false, "text": "钱不够 (要 %d 金币)" % int(Feudal.GIFT)}
	giver.gold -= Feudal.GIFT
	target.gold += Feudal.GIFT
	target.remember(giver.id, "收了礼", 20, day + 5 * GameDate.YEAR_DAYS, true)
	return {"ok": true, "text": "给%s送了 %d 金币的礼" % [target.name, int(Feudal.GIFT)]}


## 改合同: 让他多交算暴政, 让他少交他高兴
func set_contract(liege: Person, vassal: Person, level: int, day: int) -> Dictionary:
	if liege_of(vassal) != liege:
		return {"ok": false, "text": "%s不是你的封臣" % vassal.name}
	level = clampi(level, 0, Feudal.CONTRACTS.size() - 1)
	if level == vassal.contract:
		return {"ok": false, "text": "合同没变"}
	var years := day + 10 * GameDate.YEAR_DAYS
	if level > vassal.contract:
		liege.tyranny += Feudal.TYRANNY
		vassal.remember(liege.id, "让我多交", -20, years, true)
	else:
		vassal.remember(liege.id, "让我少交", 15, years, true)
	vassal.contract = level
	return {"ok": true, "text": "%s的合同改成「%s」(交税 %d%%、交兵 %d%%)" % [vassal.name, Feudal.CONTRACTS[level], int(Feudal.TAX_SHARE[level] * 100), int(Feudal.LEVY_SHARE[level] * 100)]}


# ---- 头衔: 建立公国、王国、帝国, 篡夺 (第 8 块, 照三代) ----

const TITLE_COST := {"duchy": 100, "kingdom": 250, "empire": 500}           # 金币 (三代 250 / 500 / 1000, 按我们的收入缩小)
const TITLE_PRESTIGE := {"duchy": 150.0, "kingdom": 300.0, "empire": 400.0}
const TITLE_SHARE := {"duchy": 0.5, "kingdom": 0.5, "empire": 0.8}          # 要控制这么多以上 (照三代: 公国王国一半以上, 帝国八成以上)
const SPECIAL_COST := {"k_isles": 150, "k_cumbria": 150}                    # 特别决议花的金币
const DANELAW_PRESTIGE := 100.0
var dejure_changes := {}   # 公国改了归哪个王国 (特别决议改的; 存档要存)


## 一个头衔法理上的领地 (公国 / 王国 / 帝国)
func title_counties(kind: String, id: String) -> Array:
	match kind:
		"duchy":
			return counties_in_duchy(id)
		"kingdom":
			return counties.filter(func(c: Dictionary) -> bool: return duchies[c.duchy].kingdom == id)
	return counties.duplicate()


func title_name(kind: String, id: String) -> String:
	match kind:
		"duchy":
			return duchies[id].name + "公国"
		"kingdom":
			return kingdoms[id].name + "王国"
	return empire.name + "帝国"


## 谁拿着这个头衔 (国家 id; 没人是空的)
func title_holder(kind: String, id: String) -> String:
	for rid in realm_order:
		var r: Dictionary = realms[rid]
		match kind:
			"duchy":
				if r.titles.has(id):
					return rid
			"kingdom":
				if r.get("kingdoms", []).has(id):
					return rid
			_:
				if r.get("empire", false):
					return rid
	return ""


## 这个国家控制了这个头衔的几块地 (国王直辖的和封臣的都算): [控制的, 一共]
func title_control(kind: String, id: String, rid: String) -> Array:
	var all := title_counties(kind, id)
	var mine := all.filter(func(c: Dictionary) -> bool: return c.holder == rid)
	return [mine.size(), all.size()]


## 大国王直辖上限 +1、皇帝 +2 (照三代)
func rank_bonus(p: Person) -> int:
	if p.realm == "" or not realms.has(p.realm):
		return 0
	var r: Dictionary = realms[p.realm]
	if r.get("empire", false):
		return 2
	return 1 if not r.get("kingdoms", []).is_empty() else 0


## 能不能建立 (或者从别人手里篡夺) 这个头衔; 空 = 能
func create_problem(p: Person, kind: String, id: String) -> String:
	if p.realm == "" or not realms.has(p.realm):
		return "只有独立的国王能建立"
	if not p.adult(today) or p.prisoner_of != "":
		return "现在做不了 (没成年或者关在大牢里)"
	var rid := p.realm
	if title_holder(kind, id) == rid:
		return "已经是你的了"
	var r: Dictionary = realms[rid]
	var ctl := title_control(kind, id, rid)
	if ctl[1] == 0 or float(ctl[0]) <= ctl[1] * TITLE_SHARE[kind]:
		return "控制了 %d/%d 块地, 要%s以上" % [ctl[0], ctl[1], "八成" if kind == "empire" else "一半"]
	match kind:
		"duchy":
			if counties_of(rid).size() < 2:
				return "至少要有两块领地"
		"kingdom":
			if r.titles.size() < 2:
				return "手里至少要有两个公国头衔"
		"empire":
			if r.get("kingdoms", []).size() < 2:
				return "手里至少要有两个王国头衔"
	if p.gold < TITLE_COST[kind]:
		return "钱不够 (要 %d 金币, 有 %d)" % [TITLE_COST[kind], int(p.gold)]
	return ""


func create_title(p: Person, kind: String, id: String, day: int, events: Array) -> Dictionary:
	var why := create_problem(p, kind, id)
	if why != "":
		return {"ok": false, "text": why}
	var rid := p.realm
	var old := title_holder(kind, id)
	if old != "":
		_drop_title(old, kind, id)
		ruler(old).remember(p.id, "篡夺了我的头衔", -40, day + 20 * GameDate.YEAR_DAYS)
	var r: Dictionary = realms[rid]
	match kind:
		"duchy":
			r.titles.append(id)
		"kingdom":
			if not r.has("kingdoms"):
				r.kingdoms = []
			r.kingdoms.append(id)
		_:
			r.empire = true
	p.gold -= TITLE_COST[kind]
	p.prestige += TITLE_PRESTIGE[kind]
	_update_title(rid)
	_feudal_dirty = true
	events.append({"type": "title", "realm": rid, "person": p.id, "kind": kind, "id": id, "usurped": old, "day": day})
	return {"ok": true, "text": "%s了%s, 你现在是%s。威望 +%d" % ["篡夺" if old != "" else "建立", title_name(kind, id), r.title, int(TITLE_PRESTIGE[kind])]}


func _drop_title(rid: String, kind: String, id: String) -> void:
	var r: Dictionary = realms[rid]
	match kind:
		"duchy":
			r.titles.erase(id)
		"kingdom":
			r.get("kingdoms", []).erase(id)
		_:
			r.empire = false
	_update_title(rid)


## 国家的头衔跟着最高的头衔走: 皇帝 > 大国王 > 原来的叫法
func _update_title(rid: String) -> void:
	var r: Dictionary = realms[rid]
	if not r.has("base_title"):
		r.base_title = r.title
	if r.get("empire", false):
		r.title = empire.name + "皇帝"
	elif not r.get("kingdoms", []).is_empty():
		r.title = kingdom_ruler_title(r.kingdoms[0])
	else:
		r.title = r.base_title


## 大国王的叫法: 爱尔兰叫至尊王 (史实: ard rí), 别的叫某某国王
func kingdom_ruler_title(k: String) -> String:
	return "爱尔兰至尊王" if k == "ireland" else kingdoms[k].name + "国王"


## 两个国家合成一个: 王国、帝国头衔也跟过去
func _merge_high_titles(target: String, from: Dictionary) -> void:
	var t: Dictionary = realms[target]
	for k in from.get("kingdoms", []):
		if not t.has("kingdoms"):
			t.kingdoms = []
		if not t.kingdoms.has(k):
			t.kingdoms.append(k)
	if from.get("empire", false):
		t.empire = true
	_update_title(target)


## 一个公国改归哪个王国 (特别决议用)
func _set_dejure(duchy: String, kingdom: String) -> void:
	duchies[duchy].kingdom = kingdom
	dejure_changes[duchy] = kingdom


# ---- 当地的特别决议 (第 8 块, 用户选的 a 丹麦法区、b 群岛王国、c 坎布里亚王国) ----

const SPECIALS := {
	"danelaw": ["划出丹麦法区", "维京国王跟英格兰的国王谈判划界: 你在英格兰占着的那些公国归你的「丹麦法区王国」, 他当英格兰国王, 两边停战 25 年"],
	"k_isles": ["建立群岛王国", "把马恩岛和赫布里底群岛升成正式的王国 (奥克尼、加洛韦有你的地也算进来)"],
	"k_cumbria": ["建立坎布里亚王国", "斯特拉斯克莱德往南扩到加洛韦、卡莱尔, 升成坎布里亚王国, 还多 1000 个不用养的兵"],
}


func _norse(p: Person) -> bool:
	return Marriage.faith_of(p.culture) == "norse"


## 丹麦法区的谈判对象: 英格兰地最多的基督徒国王 (有英格兰王国头衔的优先)
func danelaw_partner(p: Person) -> Person:
	var best: Person = null
	var most := -1
	for rid in realm_order:
		if rid == p.realm:
			continue
		var k := ruler(rid)
		if _norse(k):
			continue
		var n: int = title_control("kingdom", "england", rid)[0]
		if realms[rid].get("kingdoms", []).has("england"):
			n += 1000
		if n > most and n > 0:
			most = n
			best = k
	return best


func special_problem(p: Person, id: String) -> String:
	if p.realm == "" or not realms.has(p.realm):
		return "只有独立的国王能做"
	if not p.adult(today) or p.prisoner_of != "":
		return "现在做不了"
	var rid := p.realm
	var r: Dictionary = realms[rid]
	if title_holder("kingdom", id) != "":
		return "%s已经有了" % title_name("kingdom", id)
	match id:
		"danelaw":
			if not _norse(p):
				return "只有信北欧旧神的维京国王能做"
			var n: int = title_control("kingdom", "england", rid)[0]
			if n < 3:
				return "要在英格兰占着至少 3 块地 (现在 %d)" % n
			if warfare.is_at_war(p.id):
				return "正在打仗, 谈不了"
			if danelaw_partner(p) == null:
				return "英格兰没有能谈判的国王"
			if p.prestige < DANELAW_PRESTIGE:
				return "威望不够 (要 %d)" % int(DANELAW_PRESTIGE)
			if int(p.decision_used.get("danelaw", -100000)) + 5 * GameDate.YEAR_DAYS > today:
				return "刚谈过, 五年内不能再谈"
		"k_isles":
			if not _norse(p):
				return "只有信北欧旧神的人能做"
			var c := title_control("duchy", "isles", rid)
			if c[0] < c[1]:
				return "要控制整个群岛公国 (现在 %d/%d)" % [c[0], c[1]]
		"k_cumbria":
			if p.culture != "cumbric":
				return "只有坎布里亚人 (斯特拉斯克莱德) 能做"
			for d in ["strathclyde", "galloway"]:
				var c := title_control("duchy", d, rid)
				if c[0] < c[1]:
					return "要控制整个%s (现在 %d/%d)" % [title_name("duchy", d), c[0], c[1]]
			if by_id.carlisle.holder != rid:
				return "还要控制卡莱尔"
	if SPECIAL_COST.has(id) and p.gold < SPECIAL_COST[id]:
		return "钱不够 (要 %d 金币)" % SPECIAL_COST[id]
	return ""


func special_decision(p: Person, id: String, day: int, events: Array) -> Dictionary:
	var why := special_problem(p, id)
	if why != "":
		return {"ok": false, "text": why}
	var rid := p.realm
	match id:
		"danelaw":
			var partner := danelaw_partner(p)
			p.decision_used["danelaw"] = day
			if partner.id == player:
				events.append({"type": "danelaw_ask", "person": p.id, "partner": partner.id, "day": day})
				return {"ok": true, "text": "派人去跟%s谈, 等他回话" % partner.name}
			var mine := warfare.strength(p)
			var theirs := warfare.strength(partner)
			if mine < theirs * 0.7 and partner.opinion_of(p).total < 20:
				partner.remember(p.id, "想跟我划界", -10, day + 5 * GameDate.YEAR_DAYS)
				return {"ok": false, "text": "%s不肯 (他比你强得多, 也不喜欢你)" % partner.name}
			return danelaw_apply(p, partner, day, events)
		"k_isles":
			p.gold -= SPECIAL_COST[id]
			for d in ["isles", "orkney", "galloway"]:
				if d == "isles" or title_control("duchy", d, rid)[0] > 0:
					_set_dejure(d, "k_isles")
			return _grant_kingdom(p, "k_isles", 200.0, day, events)
		"k_cumbria":
			p.gold -= SPECIAL_COST[id]
			for d in ["strathclyde", "galloway"]:
				_set_dejure(d, "k_cumbria")
			realms[rid].special = int(realms[rid].get("special", 0)) + 1000
			return _grant_kingdom(p, "k_cumbria", 200.0, day, events)
	return {"ok": false, "text": "没有这个决议"}


## 丹麦法区谈成了: 你在英格兰有地的公国 (他都城那个公国除外) 归丹麦法区; 他没有英格兰王国头衔的话给他; 停战 25 年, 互相好感 +50
func danelaw_apply(p: Person, partner: Person, day: int, events: Array) -> Dictionary:
	p.prestige -= DANELAW_PRESTIGE
	var cap_duchy := ""
	if partner.realm != "" and realms.has(partner.realm) and realms[partner.realm].capital != "":
		cap_duchy = by_id[realms[partner.realm].capital].duchy
	for d in duchies:
		if duchies[d].kingdom == "england" and d != cap_duchy and title_control("duchy", d, p.realm)[0] > 0:
			_set_dejure(d, "danelaw")
	if partner.realm != "" and title_holder("kingdom", "england") == "":
		if not realms[partner.realm].has("kingdoms"):
			realms[partner.realm].kingdoms = []
		realms[partner.realm].kingdoms.append("england")
		_update_title(partner.realm)
	warfare.truces[warfare._truce_key(p.realm, partner.realm)] = day + 25 * GameDate.YEAR_DAYS
	p.remember(partner.id, "跟我划界讲和", 50, day + 25 * GameDate.YEAR_DAYS)
	partner.remember(p.id, "跟我划界讲和", 50, day + 25 * GameDate.YEAR_DAYS)
	return _grant_kingdom(p, "danelaw", 0.0, day, events)


func _grant_kingdom(p: Person, k: String, prestige: float, day: int, events: Array) -> Dictionary:
	var r: Dictionary = realms[p.realm]
	if not r.has("kingdoms"):
		r.kingdoms = []
	r.kingdoms.append(k)
	p.prestige += prestige
	_update_title(p.realm)
	_feudal_dirty = true
	events.append({"type": "title", "realm": p.realm, "person": p.id, "kind": "kingdom", "id": k, "usurped": "", "day": day})
	return {"ok": true, "text": "建立了%s, 你现在是%s" % [title_name("kingdom", k), r.title]}


# ---- 让位 (第 8 块: 压力崩溃第 3 档, 照三代) ----

## 头衔照继承法传给继承人 (玩家接着玩继承人); 他丢 100 威望 (三代 500, 按我们的威望缩小), 对原来的国家有宣称, 留下来当没领地的人
func abdicate(p: Person, day: int, events: Array) -> void:
	var was := p.realm
	var lands := lands_of(p)
	p.prestige -= 100.0
	var n := events.size()
	if was != "":
		if not p.claims.has("realm:" + was):
			p.claims.append("realm:" + was)
		_succeed(was, p, day, events)
	elif is_landed(p):
		_hand_down(p, day, events)
	else:
		return
	for i in range(n, events.size()):
		if events[i].type in ["succession", "extinct", "vassal_succession", "escheat"] and events[i].get("dead", "") == p.id:
			events[i].abdicated = true
	var heir: Person = null
	if was != "" and realms.has(was):
		heir = ruler(was)
	elif not lands.is_empty() and people.has(lands[0].lord) and lands[0].lord != p.id:
		heir = people[lands[0].lord]
	warfare.on_death(p, heir, day, events)
	intrigue.on_death(p)


# ---- 打仗以后领地换主人 (第 6 块) ----

## 一个国家法理上的公国: 手里的公国头衔 (开局没写的就是跟国家同名的那个), 加上手里王国 (帝国) 头衔下面的公国 (第 8 块)
func realm_duchies(realm_id: String) -> Array:
	if not realms.has(realm_id):
		return []
	var r: Dictionary = realms[realm_id]
	var out: Array = r.titles.duplicate()
	var ks: Array = r.get("kingdoms", [])
	for d in duchies:
		if (r.get("empire", false) or ks.has(duchies[d].kingdom)) and not out.has(d):
			out.append(d)
	return out


## 一块领地归了别的国家 (打赢了抢来的): 原来的主人丢了这块地; 原来的国家一块地都没有了就没了
func transfer_county(c: Dictionary, to_realm: String, to_lord: Person, day: int, events: Array) -> void:
	var from_realm: String = c.holder
	var old: Person = people[c.lord]
	c.holder = to_realm
	c.lord = to_lord.id
	c.occupier = ""
	if to_lord.realm == "":
		to_lord.liege_realm = to_realm
		if to_lord.homeland == "":
			to_lord.homeland = realm_kingdom(to_realm)
	_feudal_dirty = true
	_kin_dirty = true
	if old != to_lord and realms.has(to_realm):
		old.remember(ruler(to_realm).id, "抢了我的地", -40, day + 20 * GameDate.YEAR_DAYS)
	if not realms.has(from_realm):
		return
	var left := counties_of(from_realm)
	if left.is_empty():
		_destroy_realm(from_realm, day, events)
		return
	if realms[from_realm].capital == c.id:
		var k := ruler(from_realm)
		var mine := left.filter(func(x: Dictionary) -> bool: return x.lord == k.id)
		realms[from_realm].capital = (mine[0] if not mine.is_empty() else left[0]).id


## 国家一块地都没有了: 国王成了没领地的人
func _destroy_realm(rid: String, day: int, events: Array) -> void:
	var k := ruler(rid)
	var name := realm_name(rid)
	k.realm = ""
	k.liege_realm = ""
	for p in living.values():
		if p.liege_realm == rid:
			p.liege_realm = ""
	_remove_realm(rid)
	_feudal_dirty = true
	_kin_dirty = true
	events.append({"type": "realm_gone", "realm": rid, "name": name, "ruler": k.id, "day": day})


## 封臣打赢了独立战争: 他的地和他下面封臣的地成了一个新国家, 他当国王
func make_independent(p: Person, day: int, events: Array) -> String:
	var old_rid := p.liege_realm
	if not realms.has(old_rid):
		return ""
	var vice := viceroy_duchy(p)
	var mine := []
	for c in counties:
		if c.holder != old_rid:
			continue
		var q: Person = people[c.lord]
		for i in 4:
			if q == null:
				break
			if q == p:
				mine.append(c)
				break
			q = liege_of(q)
	if mine.is_empty():
		return ""
	var parent: Dictionary = realms[old_rid]
	var id := "%s_%d" % [mine[0].id, _next_index]
	var col: Color = parent.color
	var realm := {
		"id": id, "title": (duchies[vice].name + "国王") if vice != "" else mine[0].name + "领主",
		"culture": p.culture, "house": p.house, "ruler_id": p.id, "ruler": p.name,
		"color": Color.from_hsv(fmod(col.h + 0.11 * (1 + _next_index % 4), 1.0), clampf(col.s, 0.35, 0.8), clampf(col.v * 0.95, 0.35, 0.9)),
		"random": false, "index": _next_index, "titles": [vice] if vice != "" else [], "viceroys": {}, "capital": "", "special": 0,
	}
	_next_index += 1
	if vice != "":
		parent.viceroys.erase(vice)
	realms[id] = realm
	realm_order.append(id)
	for c in mine:
		c.holder = id
	_feudal_dirty = true
	for q in living.values():
		if q != p and q.liege_realm == old_rid and not lands_of(q).is_empty() and lands_of(q)[0].holder == id:
			q.liege_realm = id
	_set_ruler(id, p)
	var own := mine.filter(func(c: Dictionary) -> bool: return c.lord == p.id)
	realm.capital = (own[0] if not own.is_empty() else mine[0]).id
	if houses.has(p.house):
		houses[p.house].color = realm.color
		houses[p.house].design = realm.index
	if counties_of(old_rid).is_empty():
		_destroy_realm(old_rid, day, events)
	events.append({"type": "independent", "realm": id, "from": old_rid, "person": p.id, "day": day})
	return id


## 宣称王位的仗打赢了: 宣称的人当这个国家的国王 (原来的国王下台, 留在国内当没领地的贵族);
## 宣称的人本来就是别国的国王, 两个国家合成一个
func crown_claimant(rid: String, q: Person, att: Person, day: int, events: Array) -> void:
	var old := ruler(rid)
	var realm: Dictionary = realms[rid]
	if q.realm != "" and q.realm != rid and realms.has(q.realm):
		var target := q.realm
		for c in counties:
			if c.holder == rid:
				c.holder = target
				if c.lord == old.id:
					c.lord = q.id
		for p in living.values():
			if p.liege_realm == rid:
				p.liege_realm = target
		realms[target].titles.append_array(realm.titles)
		realms[target].viceroys.merge(realm.viceroys)
		_merge_high_titles(target, realm)
		old.realm = ""
		_move_prisoners(old, q)
		_remove_realm(rid)
	else:
		_take_throne(rid, q, day, events)
		_move_domain(old, q)
		_move_prisoners(old, q)
		old.realm = ""
		old.liege_realm = rid
		_set_ruler(rid, q)
		realm.house = q.house
		if houses.has(q.house):
			houses[q.house].color = realm.color
			houses[q.house].design = realm.index
	old.remember(q.id, "抢了我的王位", -60, day + 30 * GameDate.YEAR_DAYS)
	_feudal_dirty = true
	_kin_dirty = true
	events.append({"type": "crowned", "realm": rid if realms.has(rid) else q.realm, "person": q.id, "old": old.id, "by": att.id, "day": day})


## 近亲 (父母、配偶、子女、兄弟姐妹), 活着的
func _close_family(p: Person) -> Array:
	var list := []
	for id in [p.father, p.mother, p.spouse]:
		if id != "" and people.has(id) and people[id].alive:
			list.append(people[id])
	for c in children_of(p) + siblings_of(p):
		if c.alive and not list.has(c):
			list.append(c)
	return list
