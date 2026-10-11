class_name Marriage
extends RefCounted
## 结婚的规矩 (第 4 块, 用户 2026-10-10 同意的):
##   16 岁成年才能结婚, 不到 16 岁可以先订婚; 一夫一妻 (多妻、情妇等第 13 块宗教再加); 女方嫁到男方家, 孩子算父亲的家族。
##   近亲结婚照 867 年的史实 (用户选的): 基督徒七代以内的血亲都不能结婚 (九世纪起教会的规矩),
##   继母、嫂子、岳母这类姻亲也不能 (601 年教皇格列高利答奥古斯丁); 维京人查不到史料, 先照三代: 可以娶堂表兄妹。
##   还没有宗教 (第 13 块), 先按文化算: 诺斯人、诺斯-盖尔人当作信北欧多神教, 别的当作基督徒。两边规矩不一样时照严的。
##   近亲生的孩子可能「近亲繁殖」(三代: 亲兄妹 15%, 同父异母 7.5%, 堂表兄妹更低)。
## 一夫一妻, 只有爱尔兰例外 (用户 2026-10-10 选的「按史料来」): 爱尔兰古法 (布雷恩法) 准男人娶不止一个妻子, 教会反对;
##   爱尔兰的盖尔人男人: 一个正妻再加最多两个次妻 (数字是我们定的; 弗兰·辛纳照史料前后娶了三个)。阿尔巴查不到史料, 不算。
## 两个国王的近亲 (本人、父母、子女、兄弟姐妹、祖父母、孙子女) 结了婚, 两国就是同盟。

const CHURCH_DEGREES := 7          # 基督徒: 往上数七代内有同一个祖先就不能结婚
const INBRED_PER_KINSHIP := 0.3    # 近亲繁殖的机会 = 亲缘系数 × 0.3 (亲兄妹 0.5 → 15%)
const NORSE := ["norse", "norse_gael"]
const STATUS_NAMES := ["平民", "贵族", "国王家的人", "国王"]
const IRISH_WIVES := 3             # 爱尔兰古法: 正妻 + 两个次妻


## 一个人最多同时有几个配偶
static func max_wives(p: Person) -> int:
	return IRISH_WIVES if not p.female and p.culture == "gaelic" and p.homeland == "ireland" else 1


## 还能不能再结婚 (女人: 没有活着的丈夫; 男人: 活着的妻子没到上限)
static func free_to_marry(w: World, p: Person) -> bool:
	if p.female:
		return not p.married()
	return w.wives_of(p).size() < max_wives(p)


## 先按文化代替宗教 (第 13 块有了宗教再改)
static func faith_of(culture: String) -> String:
	return "norse" if NORSE.has(culture) else "christian"


static func faith_name(faith: String) -> String:
	return "北欧多神教" if faith == "norse" else "基督教"


## 往上数的祖先: {祖先的 id: 隔几代 (父母 1, 祖父母 2……)}, 最多数七代。祖先生下来就定了, 算一次存起来
static func ancestors(w: World, p: Person) -> Dictionary:
	if w.ancestor_cache.has(p.id):
		return w.ancestor_cache[p.id]
	var found := {}
	var layer := [p]
	for gen in range(1, CHURCH_DEGREES + 1):
		var next := []
		for x in layer:
			for pid in [x.father, x.mother]:
				if pid != "" and w.people.has(pid) and not found.has(pid):
					found[pid] = gen
					next.append(w.people[pid])
		layer = next
	w.ancestor_cache[p.id] = found
	return found


## 两个人最近的共同祖先: [往上 a 隔几代, 往上 b 隔几代], 没有就是空的 (直系的: 一边是 0)
static func nearest_common(w: World, a: Person, b: Person) -> Array:
	var aa := ancestors(w, a)
	var bb := ancestors(w, b)
	if bb.has(a.id):
		return [0, bb[a.id]]
	if aa.has(b.id):
		return [aa[b.id], 0]
	var best := []
	for id in aa:
		if bb.has(id):
			var pair := [int(aa[id]), int(bb[id])]
			if best.is_empty() or maxi(pair[0], pair[1]) < maxi(best[0], best[1]) or \
					(maxi(pair[0], pair[1]) == maxi(best[0], best[1]) and pair[0] + pair[1] < best[0] + best[1]):
				best = pair
	return best


## 血亲叫什么 (给人看): [0, 1] 父母子女, [1, 1] 兄弟姐妹, [1, 2] 叔伯姑舅和侄甥, [2, 2] 堂表兄弟姐妹……
static func kin_name(pair: Array) -> String:
	if pair.is_empty():
		return ""
	var near: int = mini(pair[0], pair[1])
	var far: int = maxi(pair[0], pair[1])
	if near == 0:
		return ["", "父母子女", "祖孙", "曾祖孙"][far] if far <= 3 else "直系的长辈晚辈"
	if near == 1 and far == 1:
		return "兄弟姐妹"
	if near == 1 and far == 2:
		return "叔伯姑舅和侄子侄女"
	if near == 2 and far == 2:
		return "堂表兄弟姐妹"
	if near == 1:
		return "隔辈的亲戚"
	return "%d 代以内的远亲" % far


## 按 faith 的规矩, 这样的血亲能不能结婚
static func kin_forbidden(faith: String, pair: Array) -> bool:
	if pair.is_empty():
		return false
	var near: int = mini(pair[0], pair[1])
	var far: int = maxi(pair[0], pair[1])
	if near == 0:
		return true
	if faith == "christian":
		return far <= CHURCH_DEGREES
	# 北欧多神教 (照三代的「可以娶堂表兄妹」): 兄弟姐妹、叔侄这一辈不行, 堂表兄妹起可以
	return near == 1 and far <= 2


## 以前和现在的配偶 (死了的也算)
static func all_spouses(w: World, p: Person) -> Array:
	var ids: Array = p.former_spouses + p.secondary
	if p.spouse != "":
		ids.append(p.spouse)
	return ids.filter(func(id: String) -> bool: return w.people.has(id)).map(func(id: String) -> Person: return w.people[id])


## 两个人有什么亲戚关系不能结婚, 能结就是空的
static func kin_problem(w: World, a: Person, b: Person) -> String:
	var strict := "christian" if faith_of(a.culture) == "christian" or faith_of(b.culture) == "christian" else "norse"
	var pair := nearest_common(w, a, b)
	if kin_forbidden(strict, pair):
		if strict == "christian" and mini(pair[0], pair[1]) > 0 and not kin_forbidden("norse", pair):
			return "两人是%s: 教会不准七代以内的亲戚结婚" % kin_name(pair)
		return "两人是%s, 不能结婚" % kin_name(pair)
	if strict == "christian":
		# 姻亲: 配偶 (以前的也算) 的近亲也不能娶, 比如继母、嫂子、岳母
		for side in [[a, b], [b, a]]:
			for s in all_spouses(w, side[0]):
				var sp := nearest_common(w, s, side[1])
				if not sp.is_empty() and maxi(sp[0], sp[1]) <= 2:
					return "%s是%s以前的配偶%s的%s: 教会不准娶姻亲" % [side[1].name, side[0].name, s.name, kin_name(sp)]
	return ""


## 亲缘系数 (亲兄妹 0.5, 同父异母 0.25, 叔侄 0.25, 堂表兄妹 0.125……): 只算最近的共同祖先
static func kinship(w: World, a: Person, b: Person) -> float:
	var aa := ancestors(w, a)
	var bb := ancestors(w, b)
	if bb.has(a.id):
		return pow(0.5, bb[a.id])
	if aa.has(b.id):
		return pow(0.5, aa[b.id])
	var common := []
	for id in aa:
		if bb.has(id):
			common.append(id)
	var total := 0.0
	for id in common:
		# 这个祖先的孩子里已经有共同祖先了, 就不是「最近的」
		var nearer := common.any(func(other: String) -> bool:
			return other != id and ancestors(w, w.people[other]).has(id))
		if not nearer:
			total += pow(0.5, aa[id] + bb[id])
	return total


## 身份: 3 国王, 2 国王的近亲 (父母、子女、兄弟姐妹、孙子女) 或者有领地的封臣, 1 贵族, 0 平民
static func status(w: World, p: Person) -> int:
	if p.realm != "":
		return 3
	if w.ruler_kin(p) != "" or w.is_landed(p):
		return 2
	return 1 if p.rank != "" else 0


## 能不能结婚 (订婚也一样查, 只是不看岁数); 能就是空的
static func problem(w: World, a: Person, b: Person, day: int, betrothal := false) -> String:
	if a == b:
		return "同一个人"
	if not a.alive or not b.alive:
		return "人已经去世了"
	if a.female == b.female:
		return "两个人都是%s" % ("女的" if a.female else "男的")
	for p in [a, b]:
		if not free_to_marry(w, p):
			if max_wives(p) > 1:
				return "%s已经有 %d 个妻子了 (爱尔兰古法也最多 %d 个)" % [p.name, max_wives(p), max_wives(p)]
			return "%s已经结婚了" % p.name
		if p.betrothed != "" and p.betrothed != (b.id if p == a else a.id):
			return "%s已经订婚了" % p.name
	if not betrothal and not (a.adult(day) and b.adult(day)):
		return "还没满 16 岁 (可以先订婚)"
	if a.realm != "" and b.realm != "":
		return "两个国王不能结婚 (只有男人当国王)"
	for p in [a, b]:
		if p.prisoner_of != "":
			return "%s关在大牢里" % p.name
	return kin_problem(w, a, b)


## 女方愿不愿意 (或者男方家愿不愿意) 跟你家结亲: {total, parts}。total > 0 就答应
## me 是玩家, mine 是你家的人, theirs 是对方; 对方家里做主的是对方的国王 (没有就是本人)
static func acceptance(w: World, me: Person, mine: Person, theirs: Person, day: int) -> Dictionary:
	var parts := []
	var player_realm := w.realm_of_person(me)
	var head := w.head_of(theirs)
	parts.append(["说亲一般都愿意", 10])
	if head != me:
		var o := head.opinion_of(me)
		if o.total != 0:
			parts.append(["%s对你的好感 %+d" % [head.name, o.total], o.total / 2])
	var gap := status(w, mine) - status(w, theirs)
	if gap > 0:
		parts.append(["你家的%s身份比他家的高 (%s)" % [mine.name, STATUS_NAMES[status(w, mine)]], gap * 15])
	elif gap < 0:
		parts.append(["%s身份比你家的%s高 (%s)" % [theirs.name, mine.name, STATUS_NAMES[status(w, theirs)]], gap * 25])
	if theirs.realm != "":
		parts.append(["国王自己的婚事要慎重", -10])
	var husband0: Person = mine if not mine.female else theirs
	if husband0.married():
		parts.append(["嫁过去做次妻 (正妻是%s)" % husband0.living_spouse().name, -20])
	var their_realm := w.kin_realm(theirs)
	if their_realm != "" and their_realm != player_realm and w.ruler_kin(mine) != "":
		if w.allies(player_realm).has(their_realm):
			parts.append(["两国已经是同盟", 5])
		else:
			parts.append(["%s想跟你结盟" % w.realm_name(their_realm), 20])
	var husband: Person = mine if not mine.female else theirs
	var wife: Person = theirs if not mine.female else mine
	if wife.age(day) >= 40:
		parts.append(["%s过了生孩子的年纪" % wife.name, -40 if wife == mine else -10])
	if husband.age(day) - wife.age(day) > 25:
		parts.append(["年纪差得太多", -20])
	if faith_of(mine.culture) != faith_of(theirs.culture):
		parts.append(["信的教不一样 (%s / %s)" % [faith_name(faith_of(mine.culture)), faith_name(faith_of(theirs.culture))], -25])
	if w.historical_match(mine, theirs) != "":
		parts.append(["两家早有结亲的意思", 30])
	var total := 0
	for x in parts:
		total += int(x[1])
	return {"total": total, "parts": parts}


## 电脑给 seeker 挑对象时的分数 (越高越好)
static func ai_score(w: World, seeker: Person, cand: Person, day: int, rng: RandomNumberGenerator) -> float:
	var score := status(w, cand) * 10.0
	if w.historical_match(seeker, cand) != "":
		score += 1000.0
	var mine := w.kin_realm(seeker)
	var theirs := w.kin_realm(cand)
	if mine != "" and theirs != "" and mine != theirs:
		score += 15.0  # 能结盟
	if seeker.culture == cand.culture:
		score += 8.0
	if faith_of(seeker.culture) != faith_of(cand.culture):
		score -= 30.0
	score += seeker.opinion_of(cand).total / 5.0
	var wife: Person = cand if cand.female else seeker
	score -= absf(seeker.age(day) - cand.age(day) - (4 if not seeker.female else -4)) * 0.8
	if wife.age(day) >= 35:
		score -= 25.0
	return score + rng.randf() * 10.0
