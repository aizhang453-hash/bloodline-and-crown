class_name Traits
extends RefCounted
## 人物的特点和本事: 读 data/traits.json, 随机挑性格、天生的特点、教育。
## 特点用 id 记: 性格、天生的、小时候的性格 (3 岁到 16 岁) 就是 traits.json 里的 id; 教育记在 Person.education 里 ({skill, level})。
## 第 4 块: 天生的特点会遗传, 教育看老师 (监护人) 教得好不好, 长大以后的性格跟小时候的性格、老师有关。

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
		for t in _data.childhood:
			t.kind = "childhood"
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


static func education_level_name(level: int) -> String:
	return data().education.levels[level - 1] if level >= 1 else ""


static func track_name(skill: String) -> String:
	for t in data().education.tracks:
		if t.skill == skill:
			return t.name
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
static func random_congenital(rng: RandomNumberGenerator, skip: Dictionary = {}) -> Array:
	var chosen := []
	var used := skip.duplicate()
	for t in data().congenital:
		if used.has(t.group) or float(t.chance) <= 0.0:
			continue
		if rng.randf() * 100.0 < float(t.chance):
			chosen.append(t.id)
			used[t.group] = true
	return chosen


## 孩子天生的特点: 先看爸妈遗传 (爸妈一个有, 孩子有 inherit% 的机会也有; 两个都有翻倍), 没遗传到的组再照常随机
static func inherit_congenital(rng: RandomNumberGenerator, father: Person, mother: Person) -> Array:
	var chosen := []
	var used := {}
	var groups := {}  # 组 -> 爸妈身上这一组的特点
	for parent in [father, mother]:
		if parent == null:
			continue
		for t in parent.congenital():
			var info := get_trait(t)
			if int(info.get("inherit", 0)) > 0:
				groups[info.group] = groups.get(info.group, []) + [t]
	for g in groups:
		var have: Array = groups[g]
		var chance := float(get_trait(have[0]).inherit) * have.size() / 100.0
		if rng.randf() < chance:
			chosen.append(have[rng.randi_range(0, have.size() - 1)])
			used[g] = true
	return chosen + random_congenital(rng, used)


# ---- 小时候 (第 4 块) ----

## 3 岁有的「小时候的性格」(五种里随机一种)
static func random_childhood(rng: RandomNumberGenerator) -> String:
	var list: Array = data().childhood
	return list[rng.randi_range(0, list.size() - 1)].id


## 6 岁开始学什么: 多半挑小时候的性格擅长的那样, 不然随机
static func pick_focus(rng: RandomNumberGenerator, childhood: String) -> String:
	var info := get_trait(childhood)
	if not info.is_empty() and rng.randf() < 0.7:
		return info.focus[rng.randi_range(0, info.focus.size() - 1)]
	var tracks: Array = data().education.tracks
	return tracks[rng.randi_range(0, tracks.size() - 1)].skill


## 学的这样合不合小时候的性格
static func focus_fits(childhood: String, focus: String) -> bool:
	return get_trait(childhood).get("focus", []).has(focus)


## 学了几年攒下的分数 -> 16 岁时教育的档次 (1 差 2 一般 3 好 4 出色)
const EDU_STEPS := [4.0, 8.0, 12.0]


static func education_level(points: float) -> int:
	var level := 1
	for step in EDU_STEPS:
		if points >= step:
			level += 1
	return level


## 16 岁定性格: 小时候的性格多半变成一样 (60%), 老师教的每样一半机会留下, 不够 3 个随机补 (都不挑相反的)
static func grown_personality(rng: RandomNumberGenerator, childhood: String, taught: Array) -> Array:
	var forced := []
	var info := get_trait(childhood)
	if not info.is_empty() and rng.randf() < 0.6:
		forced.append(info.grows_into[rng.randi_range(0, info.grows_into.size() - 1)])
	for t in taught:
		if forced.size() < 3 and not forced.has(t) and rng.randf() < 0.5 \
				and not forced.any(func(f: String) -> bool: return opposite(f, t) or opposite(t, f)):
			forced.append(t)
	return random_personality(rng, 3, forced)


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
