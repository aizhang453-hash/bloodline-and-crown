class_name Succession
extends RefCounted
## 继承: 国王死了谁接 (第 3 块, 用户 2026-10-10 同意的规矩)。按文化分三种继承法, 只有男人能继承:
##   长者继承 (盎格鲁-撒克逊): 家族里年纪最大的男人, 常常是哥哥死了弟弟接
##   平分继承 (威尔士、康沃尔、坎布里亚、诺斯): 长子拿主要的王国, 手里别的王国分给下面的儿子, 各自当国王
##   推举继承 (盖尔人, 也叫塔尼斯特里): 家族里的男人推举一个, 一般是成年、本事好的, 不一定是儿子

const NAMES := {"seniority": "长者继承", "partition": "平分继承", "tanistry": "推举继承"}
const DESCS := {
	"seniority": "家族里年纪最大的男人继承 (哥哥死了常常是弟弟接, 不是年幼的儿子)",
	"partition": "儿子们分家: 长子拿主要的王国, 手里别的王国分给下面的儿子, 各自当国王",
	"tanistry": "家族里的男人推举继承人, 一般选成年、本事好的, 不一定是儿子",
}


static func law_of(culture: String) -> String:
	match culture:
		"anglo_saxon":
			return "seniority"
		"gaelic":
			return "tanistry"
		_:
			return "partition"


## 能继承的人, 排好先后 (第一个就是继承人)。ruler 是现在的国王 (或者刚死的国王), 他自己不算
static func candidates(w: World, realm_id: String, ruler: Person, day: int) -> Array:
	return candidates_for(w, ruler, law_of(w.realms[realm_id].culture), day)


## 照 law 这种继承法, 谁来接 holder 的东西 (国王的国家, 或者封臣的领地; 第 5 块)
static func candidates_for(w: World, ruler: Person, law: String, day: int) -> Array:
	var house: String = ruler.house
	var men: Array = w.house_members(house).filter(func(p: Person) -> bool:
		return p.alive and not p.female and p.id != ruler.id and house != "")
	match law:
		"seniority":
			men.sort_custom(func(a: Person, b: Person) -> bool: return a.birth_day < b.birth_day)
		"tanistry":
			var scores := {}
			for m in men:
				scores[m.id] = tanist_score(m, day)
			men.sort_custom(func(a: Person, b: Person) -> bool:
				var sa: int = scores[a.id]
				var sb: int = scores[b.id]
				return sa > sb if sa != sb else a.birth_day < b.birth_day)
		_:
			# 平分: 先儿子 (大的在前), 再兄弟, 再家族里别的男人 (都是年纪大的在前)
			men.sort_custom(func(a: Person, b: Person) -> bool:
				var ra := _partition_rank(a, ruler)
				var rb := _partition_rank(b, ruler)
				return ra < rb if ra != rb else a.birth_day < b.birth_day)
	return men


## 推举时的分数: 成年人优先, 再看本事和年纪
static func tanist_score(p: Person, day: int) -> int:
	var score := 0 if p.adult(day) else -1000
	for s in ["martial", "diplomacy", "stewardship"]:
		score += p.skill(s, day)
	return score + mini(p.age(day), 50) / 5


static func _partition_rank(p: Person, ruler: Person) -> int:
	if p.father == ruler.id:
		return 0
	if ruler.father != "" and p.father == ruler.father:
		return 1
	return 2


static func heir(w: World, realm_id: String, day: int) -> Person:
	var c := candidates(w, realm_id, w.ruler(realm_id), day)
	return c[0] if not c.is_empty() else null
