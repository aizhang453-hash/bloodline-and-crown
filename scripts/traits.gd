class_name Traits
extends RefCounted
## 人物的特点和本事: 读 data/traits.json, 随机挑性格、天生的特点、教育。
## 特点用 id 记: 性格和天生的就是 traits.json 里的 id; 教育记在 Person.education 里 ({skill, level})。

const FILE := "res://data/traits.json"
const SKILLS := ["diplomacy", "martial", "stewardship", "intrigue", "learning", "prowess"]

static var _data: Dictionary
static var _by_id := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		for t in _data.personality:
			t.kind = "personality"
			_by_id[t.id] = t
		for t in _data.congenital:
			t.kind = "congenital"
			_by_id[t.id] = t
	return _data


## 一个特点 (性格或者天生的)
static func get_trait(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


static func skill_info(id: String) -> Dictionary:
	for s in data().skills:
		if s.id == id:
			return s
	return {}


static func education_name(edu: Dictionary) -> String:
	if edu.is_empty() or int(edu.level) == 0:
		return ""
	for t in data().education.tracks:
		if t.skill == edu.skill:
			return "%s (%s)" % [t.name, data().education.levels[int(edu.level) - 1]]
	return ""


static func education_bonus(level: int) -> int:
	return 0 if level <= 0 else int(data().education.bonus[level - 1])


## 两个性格是不是相反的 (相反的不能同时有, 别人对你的好感也减)
static func opposite(a: String, b: String) -> bool:
	var t := get_trait(a)
	return not t.is_empty() and t.get("opposite", []).has(b)


## 随机挑性格 (先放 forced 里的, 不够 count 个再随机补, 不挑相反的)
static func random_personality(rng: RandomNumberGenerator, count := 3, forced: Array = []) -> Array:
	var chosen: Array = forced.duplicate()
	var pool: Array = data().personality.map(func(t: Dictionary) -> String: return t.id)
	var tries := 0
	while chosen.size() < count and tries < 200:
		tries += 1
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if chosen.has(id) or chosen.any(func(c: String) -> bool: return opposite(c, id) or opposite(id, c)):
			continue
		chosen.append(id)
	return chosen


## 随机天生的特点: 每一组 (聪明、长相、身体……) 最多一个, 大多数人一个都没有
static func random_congenital(rng: RandomNumberGenerator) -> Array:
	var chosen := []
	var used := {}
	for t in data().congenital:
		if used.has(t.group):
			continue
		if rng.randf() * 100.0 < float(t.chance):
			chosen.append(t.id)
			used[t.group] = true
	return chosen


## 随机教育: 五种里挑一种, 四档 (国王家的孩子请得起好老师, 好一点)
static func random_education(rng: RandomNumberGenerator, rank := "") -> Dictionary:
	var tracks: Array = data().education.tracks
	var odds: Array = data().education.odds.duplicate()
	if rank == "king":
		odds = [10, 35, 35, 20]
	var total := 0
	for o in odds:
		total += int(o)
	var roll := rng.randi_range(1, total)
	var level := 1
	for i in odds.size():
		roll -= int(odds[i])
		if roll <= 0:
			level = i + 1
			break
	return {"skill": tracks[rng.randi_range(0, tracks.size() - 1)].skill, "level": level}
