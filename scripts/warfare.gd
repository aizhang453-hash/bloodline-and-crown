class_name Warfare
extends RefCounted
## 打仗的过程 (第 6 块): 宣战、军队 (征兵、行军、坐船)、打仗、围城、战争分数、谈和、停战、电脑怎么打。规矩和数字在 War。
## 一方是「人」: 国王带着他的国家; 造反的封臣带着他自己的地。军队、战争都是字典, 存档方便。
## 时间每过一天 daily 一次 (行军、打仗、围城、电脑带兵), 每个月 monthly 一次 (养兵、补兵、战争分数、电脑宣战谈和、史料里的仗)。

var w: World
var armies := {}          # 编号 -> {id, owner, commander, levy, special, full, loc, path, leg, leg_days, sea, gather, retreat, landed, battle}
var wars: Array = []      # [{id, cb, attacker, defender, attackers, defenders, target, targets, claimant, label, start, battle, tick, months}]
var battles := {}         # 编号 -> {id, war, loc, a, b, a_side, day, adv_a, adv_b, start_a, start_b, routed_a, routed_b, lost_a, lost_b}
var sieges := {}          # 领地 id -> {progress, days, starve, sick, by}
var truces := {}          # "国家|国家" -> 到哪天
var history_done: Array = []   # 史料里的仗哪几场已经到时候了 (下标)
var reinforce_done: Array = [] # 史料里的援兵哪几批已经来了 (下标)
var next_id := 1
var _graph := {}          # 领地 id -> [[去哪, 几天, 坐不坐船], ...]
var _rebels := {}         # 正在打独立战争的封臣
static var _graph_all := {}   # 地图不变: 路和最短路算一次, 开几局都用这一份
static var _paths := {}       # 从哪 -> [天数, 上一步]


func _init(p_world: World) -> void:
	w = p_world


# ---- 地图上怎么走 ----

## 挨着的地走路, 靠海的地之间 (一次不超过 War.SEA_MAX_KM) 可以坐船
func build_graph() -> void:
	if not _graph_all.is_empty():
		_graph = _graph_all
		return
	_graph = {}
	var coastal := []
	for c in w.counties:
		var edges := []
		for n in c.neighbors:
			edges.append([n, maxf(1.0, _km(c, w.by_id[n]) / War.LAND_KM), false])
		_graph[c.id] = edges
		if c.coastal:
			coastal.append(c)
	for a in coastal:
		for b in coastal:
			if a == b or a.neighbors.has(b.id):
				continue
			var km := _km(a, b)
			if km <= War.SEA_MAX_KM:
				_graph[a.id].append([b.id, km * 1.2 / War.SEA_KM + War.EMBARK_DAYS, true])
	_graph_all = _graph
	_paths = {}


func _km(a: Dictionary, b: Dictionary) -> float:
	return (a.seat as Vector2).distance_to(b.seat) * w.km_per_px


## 从 from 出发到每块地最少几天: [天数, 上一步] (算过的存起来, 地图不会变)
func _dijkstra(from: String) -> Array:
	if _paths.has(from):
		return _paths[from]
	var dist := {from: 0.0}
	var prev := {}
	var open := [from]
	var done := {}
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best]]:
				best = i
		var cur: String = open[best]
		open.remove_at(best)
		if done.has(cur):
			continue
		done[cur] = true
		for e in _graph[cur]:
			var nd: float = dist[cur] + e[1]
			if not dist.has(e[0]) or nd < dist[e[0]]:
				dist[e[0]] = nd
				prev[e[0]] = [cur, e]
				open.append(e[0])
	_paths[from] = [dist, prev]
	return _paths[from]


## 从 from 到 to 的路: [[领地 id, 天数, 坐不坐船], ...] (不含起点); 走不到是空的
func route(from: String, to: String) -> Array:
	if from == to:
		return []
	var prev: Dictionary = _dijkstra(from)[1]
	if not prev.has(to):
		return []
	var path := []
	var at := to
	while at != from:
		var p: Array = prev[at]
		path.push_front(p[1])
		at = p[0]
	return path


func days_between(from: String, to: String) -> float:
	var dist: Dictionary = _dijkstra(from)[0]
	return dist.get(to, INF)


# ---- 谁跟谁是一方 ----

## 这块地本来归谁 (不算被占领): 造反的封臣管自己 (和他下面封臣) 的地, 别的归国王
func party(c: Dictionary) -> String:
	if not _rebels.is_empty():
		var p: Person = w.people[c.lord]
		for i in 4:
			if p == null:
				break
			if _rebels.has(p.id):
				return p.id
			p = w.liege_of(p)
	return w.realms[c.holder].ruler_id


## 这块地现在归谁管 (被占领了就是占领的人)
func controller(c: Dictionary) -> String:
	return c.occupier if c.occupier != "" else party(c)


func war_between(a: String, b: String) -> Dictionary:
	if a == b:
		return {}
	for war in wars:
		if (war.attackers.has(a) and war.defenders.has(b)) or (war.defenders.has(a) and war.attackers.has(b)):
			return war
	return {}


func hostile(a: String, b: String) -> bool:
	return not war_between(a, b).is_empty()


## 在这场仗里是哪一方: 1 进攻方, -1 防守方, 0 不在
func side(war: Dictionary, pid: String) -> int:
	if war.attackers.has(pid):
		return 1
	if war.defenders.has(pid):
		return -1
	return 0


## 自己人: 同一个人, 或者在哪场仗里是同一方
func friendly(a: String, b: String) -> bool:
	if a == b:
		return true
	for war in wars:
		var s := side(war, a)
		if s != 0 and s == side(war, b):
			return true
	return false


func wars_of(pid: String) -> Array:
	return wars.filter(func(war: Dictionary) -> bool: return side(war, pid) != 0)


func is_at_war(pid: String) -> bool:
	for war in wars:
		if side(war, pid) != 0:
			return true
	return false


func war_by_id(id: int) -> Dictionary:
	for war in wars:
		if int(war.id) == id:
			return war
	return {}


func _rebuild_rebels() -> void:
	_rebels = {}
	for war in wars:
		if war.cb == "independence":
			_rebels[war.attacker] = true


func is_rebel(pid: String) -> bool:
	return _rebels.has(pid)


func _truce_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## 两个国家还在停战吗 (返回到哪天, 没有是 0)
func truce_until(ra: String, rb: String) -> int:
	return int(truces.get(_truce_key(ra, rb), 0))


# ---- 城墙和守军 ----

func fort(c: Dictionary) -> int:
	var lv: int = War.FORT_BASE + int(c.fort_bonus)
	if w.realms.has(c.holder) and w.realms[c.holder].get("capital", "") == c.id:
		lv += 1
	return lv


func max_garrison(c: Dictionary) -> float:
	var base := float(fort(c) * War.GARRISON_PER_FORT)
	if w.council != null and w.realms.has(c.holder) and w.realms[c.holder].has("ruler_id"):
		base *= 1.0 + Councils.ORGANIZE_GARRISON * w.council.task_skill(w.ruler(c.holder), "organize")
	return base


## 围下来要多少进度 (守军不满的城快一些, 照三代)
func siege_needed(c: Dictionary) -> float:
	return (War.SIEGE_BASE + War.SIEGE_PER_FORT * fort(c)) * clampf(c.garrison / max_garrison(c), 0.25, 1.0)


# ---- 军队 ----

func soldiers(a: Dictionary) -> float:
	return a.levy + a.special


func army_of(pid: String) -> Dictionary:
	for a in armies.values():
		if a.owner == pid:
			return a
	return {}


func armies_at(loc: String) -> Array:
	return armies.values().filter(func(a: Dictionary) -> bool: return a.loc == loc)


## 能征多少兵: full 满员的农民兵 (直辖 + 封臣交的), levy 现在补到几成的, special 不用养的兵 (维京大军)
func levy_of(p: Person) -> Dictionary:
	var inc := w.income(p)
	var levy: float = inc.levy
	if _rebels.has(p.id):
		levy = inc.own_levy + inc.from_levy  # 造反了, 不再交兵给国王
	else:
		for v in w.vassals_of(p):
			if _rebels.has(v.id):
				levy -= w.income(v).paid_levy
	var special := 0.0
	if p.realm != "" and w.realms.has(p.realm):
		special = float(w.realms[p.realm].get("special", 0))
	levy = maxf(0.0, levy)
	return {"full": levy, "levy": levy * p.levy_ratio, "special": special}


## 在哪集合: 都城 (封臣是他自己的第一块地), 那里有敌军就换一块自己的地
func rally_point(p: Person) -> String:
	var mine := w.lands_of(p).filter(func(c: Dictionary) -> bool: return c.occupier == "")
	for c in mine:
		if not _enemy_army_at(p.id, c.id):
			return c.id
	return ""


func _enemy_army_at(pid: String, loc: String) -> bool:
	for a in armies.values():
		if a.loc == loc and hostile(pid, a.owner):
			return true
	return false


func can_raise(p: Person) -> String:
	if not army_of(p.id).is_empty():
		return "军队已经征起来了"
	if not p.alive:
		return "人已经去世了"
	if p.prisoner_of != "":
		return "关在大牢里, 征不了兵"
	if p.realm == "" and not _rebels.has(p.id):
		return "你是封臣, 兵按合同交给了上面"
	var lv := levy_of(p)
	if lv.levy + lv.special < 50.0:
		return "现在没有兵可征 (刚打完仗的兵还在慢慢补)"
	if rally_point(p) == "":
		return "自己的地都被占了, 没地方集合"
	return ""


## 征兵: 在都城集合 (国家越大集合越久), 每月花钱养
func raise(p: Person, day: int) -> Dictionary:
	var why := can_raise(p)
	if why != "":
		return {"ok": false, "text": why}
	var lv := levy_of(p)
	var loc := rally_point(p)
	var size := w.counties_of(w.realm_of_person(p)).size()
	var a := {"id": next_id, "owner": p.id, "commander": "", "levy": lv.levy, "special": lv.special, "full": lv.full,
			"loc": loc, "path": [], "leg": 0.0, "leg_days": 0.0, "sea": false,
			"gather": War.GATHER_DAYS + mini(12, size / 3), "retreat": 0, "landed": -100, "battle": -1}
	next_id += 1
	armies[a.id] = a
	if p.realm != "" and w.realms.has(p.realm):
		w.realms[p.realm].special = 0  # 不用养的兵跟着军队走
	var cands := commander_candidates(p)
	if not cands.is_empty():
		a.commander = p.id if cands.has(p) and p.id == w.player else cands[0].id
	return {"ok": true, "text": "征了 %d 个兵, 在%s集合 (要 %d 天), 每月养兵 %.1f 金币" % [int(soldiers(a)), w.by_id[loc].name, int(a.gather), upkeep(a)]}


func upkeep(a: Dictionary) -> float:
	var k := 1.0 - Councils.ORGANIZE_UPKEEP * w.council.task_skill(w.people.get(a.owner), "organize")
	return a.levy / 1000.0 * War.UPKEEP_PER_1000 * maxf(0.5, k)


func can_disband(a: Dictionary) -> String:
	if int(a.battle) != -1:
		return "正在打仗, 不能解散"
	if _enemy_army_at(a.owner, a.loc):
		return "敌人就在这里, 不能解散"
	return ""


## 解散: 剩下的兵回家 (下次征兵按剩下的几成算, 每月补一成); 不用养的兵回到国家
func disband(a: Dictionary) -> Dictionary:
	var why := can_disband(a)
	if why != "":
		return {"ok": false, "text": why}
	var p: Person = w.people[a.owner]
	if a.full > 0.0:
		p.levy_ratio = clampf(a.levy / a.full, 0.0, 1.0)
	if p.realm != "" and w.realms.has(p.realm):
		w.realms[p.realm].special = int(a.special)
	armies.erase(a.id)
	return {"ok": true, "text": "解散了军队 (%d 人回家)" % int(soldiers(a))}


## 军队没了 (全军覆没、走光了): 农民兵都没了, 要从头慢慢补; 不用养的兵也没了
func _destroy(a: Dictionary) -> void:
	armies.erase(a.id)
	if w.people.has(a.owner):
		w.people[a.owner].levy_ratio = 0.0


## 能带兵的人: 他自己、家里的成年男人、封臣、住在他那里的人 (没在带别的兵的), 军事好的在前
func commander_candidates(p: Person) -> Array:
	var day := w.today
	var realm := w.realm_of_person(p)
	var busy := {}
	for a in armies.values():
		if a.owner != p.id and a.commander != "":
			busy[a.commander] = true
	var list := []
	var add := func(q: Person) -> void:
		if q != null and not list.has(q) and not busy.has(q.id) and can_command(q, day):
			list.append(q)
	add.call(p)
	for q in w.house_members(p.house):
		if not w.is_landed(q) and (w.home_realm(q) == realm or w.relation(p, q) != ""):
			add.call(q)
	for v in w.vassals_of(p):
		add.call(v)
	for q in w.living.values():
		if q.liege_realm == realm and not w.is_landed(q) and q.house != p.house:
			add.call(q)
	list.sort_custom(func(x: Person, y: Person) -> bool: return x.skill("martial", day) > y.skill("martial", day))
	return list


func can_command(q: Person, day: int) -> bool:
	return q.alive and not q.female and q.adult(day) and q.prisoner_of == ""


func set_commander(a: Dictionary, q: Person) -> Dictionary:
	if not can_command(q, w.today):
		return {"ok": false, "text": "%s带不了兵" % q.name}
	a.commander = q.id
	return {"ok": true, "text": "%s带兵 (军事 %d)" % [q.name, q.skill("martial", w.today)]}


## 让军队走到 to (正在打仗、撤退、集合的不行)。坐船要花钱, 上船时付
func order_move(a: Dictionary, to: String) -> Dictionary:
	if int(a.battle) != -1:
		return {"ok": false, "text": "正在打仗, 走不了"}
	if int(a.retreat) > 0:
		return {"ok": false, "text": "正在撤退, 管不住"}
	var start: String = a.loc
	var keep: Array = []
	if not a.path.is_empty() and a.leg > a.leg_days / 2.0:
		keep = [a.path[0]]  # 走了一半多了, 先走到那一块 (照三代)
		start = a.path[0][0]
	if start == to and keep.is_empty():
		a.path = []
		a.leg = 0.0
		return {"ok": true, "text": "停在这里"}
	var path := keep + route(start, to)
	if path.is_empty() or path[path.size() - 1][0] != to:
		return {"ok": false, "text": "走不到那里"}
	if keep.is_empty():
		a.leg = 0.0
	a.path = path
	a.leg_days = path[0][1]
	a.sea = path[0][2]
	var days: float = -a.leg
	var ships := 0
	for e in path:
		days += e[1]
		if e[2]:
			ships += 1
	var text := "去%s, 要 %d 天%s" % [w.by_id[to].name, ceili(days), "" if int(a.gather) <= 0 else " (集合完再走)"]
	if ships > 0:
		text += ", 坐 %d 次船 (每次 %d 金币)" % [ships, ceili(soldiers(a) / 100.0 * War.SHIP_GOLD)]
	return {"ok": true, "text": text}


## 军队在地图上的位置 (走在路上的在两块地中间)
func army_pos(a: Dictionary) -> Vector2:
	var here: Vector2 = w.by_id[a.loc].seat
	if a.path.is_empty() or a.leg_days <= 0.0:
		return here
	var there: Vector2 = w.by_id[a.path[0][0]].seat
	return here.lerp(there, clampf(a.leg / a.leg_days, 0.0, 1.0))


# ---- 每天 ----

func daily(day: int, events: Array) -> void:
	if armies.is_empty() and wars.is_empty():
		return
	for bid in battles.keys():
		if battles.has(bid):
			_battle_day(battles[bid], day, events)
	for id in armies.keys():
		if armies.has(id):
			_move_day(armies[id], day, events)
	for id in armies.keys():
		if armies.has(id) and int(armies[id].battle) == -1 and int(armies[id].retreat) == 0:
			_check_battle(armies[id], day, events)
	_siege_day(day, events)
	_ai_armies(day, events)


func _move_day(a: Dictionary, day: int, events: Array) -> void:
	if int(a.gather) > 0:
		a.gather = int(a.gather) - 1
		return
	if int(a.battle) != -1 or a.path.is_empty():
		if int(a.retreat) > 0 and a.path.is_empty():
			a.retreat = 0
		return
	if a.leg == 0.0 and a.sea:
		var p: Person = w.people[a.owner]
		p.gold -= soldiers(a) / 100.0 * War.SHIP_GOLD
	a.leg += 1.5 if int(a.retreat) > 0 else 1.0
	if a.leg < a.leg_days:
		return
	var e: Array = a.path.pop_front()
	var from: String = a.loc
	a.loc = e[0]
	a.leg = 0.0
	if e[2]:
		a.landed = day
	if not a.path.is_empty():
		a.leg_days = a.path[0][1]
		a.sea = a.path[0][2]
	else:
		a.retreat = 0
	_attrition(a, from, events, day)


## 在敌人的地上往前走 (不挨着自己人的地): 掉 5% 的兵, 最少 100
func _attrition(a: Dictionary, from: String, events: Array, day: int) -> void:
	if int(a.retreat) > 0:
		return
	var here: Dictionary = w.by_id[a.loc]
	if not (hostile(a.owner, controller(w.by_id[from])) and hostile(a.owner, controller(here))):
		return
	for n in here.neighbors:
		if friendly(a.owner, controller(w.by_id[n])):
			return
	_lose(a, maxf(100.0, soldiers(a) * War.ATTRITION_MOVE))
	if soldiers(a) < 1.0:
		events.append({"type": "army_lost", "owner": a.owner, "loc": a.loc, "day": day})
		_destroy(a)


## 军队少了 n 个兵 (农民兵和不用养的兵按比例)
func _lose(a: Dictionary, n: float) -> void:
	var total := soldiers(a)
	if total <= 0.0:
		return
	var k := clampf(1.0 - n / total, 0.0, 1.0)
	a.levy *= k
	a.special *= k


func _gain(list: Array, n: float) -> void:
	var total := 0.0
	for a in list:
		total += soldiers(a)
	for a in list:
		var share := soldiers(a) / total if total > 0.0 else 1.0 / list.size()
		var add := n * share
		var s := soldiers(a)
		if s > 0.0:
			a.special += add * a.special / s
			a.levy += add * a.levy / s
		else:
			a.levy += add


# ---- 打仗 ----

func _check_battle(a: Dictionary, day: int, events: Array) -> void:
	for b in battles.values():
		if b.loc == a.loc:
			var war := war_by_id(int(b.war))
			var s := side(war, a.owner)
			if s != 0:
				var mine: Array = b.a if s == int(b.a_side) else b.b
				mine.append(a.id)
				a.battle = b.id
				a.path = []
			return
	var foe := {}
	for o in armies.values():
		if o.loc == a.loc and int(o.retreat) == 0 and hostile(a.owner, o.owner):
			foe = o
			break
	if foe.is_empty():
		return
	var war := war_between(a.owner, foe.owner)
	var s_a := side(war, a.owner)
	var side_a := []
	var side_b := []
	for o in armies.values():
		if o.loc != a.loc or int(o.retreat) > 0:
			continue
		var s := side(war, o.owner)
		if s == s_a:
			side_a.append(o.id)
		elif s == -s_a:
			side_b.append(o.id)
	var b := {"id": next_id, "war": war.id, "loc": a.loc, "a": side_a, "b": side_b, "a_side": s_a, "day": 0,
			"adv_a": 0, "adv_b": 0, "start_a": 0.0, "start_b": 0.0, "routed_a": 0.0, "routed_b": 0.0, "lost_a": 0.0, "lost_b": 0.0}
	next_id += 1
	for id in side_a + side_b:
		armies[id].battle = b.id
		armies[id].path = []
		armies[id].leg = 0.0
	b.start_a = _side_men(b.a)
	b.start_b = _side_men(b.b)
	battles[b.id] = b
	_roll(b, day)


func _side(ids: Array) -> Array:
	var list := []
	for id in ids:
		if armies.has(id):
			list.append(armies[id])
	return list


func _side_men(ids: Array) -> float:
	var n := 0.0
	for a in _side(ids):
		n += soldiers(a)
	return n


## 一方的优势: 带兵的人军事最好的那个 (国王亲自带 +5), 集合时 -10, 欠钱 -10, 刚从船上下来 -30, 再掷一个 1–10 的骰子
func _advantage(list: Array, day: int, moved_in: bool) -> int:
	return advantage_parts(list, day, moved_in).total + w.rng.randi_range(1, 10)


## 优势的每一项 (不算骰子): {total, parts: [[说明, 加减], ...]}
func advantage_parts(list: Array, day: int, moved_in: bool) -> Dictionary:
	var parts := []
	var best := 0
	var best_name := ""
	var gathering := false
	var debt := false
	var landed := false
	for a in list:
		if a.commander != "" and w.people.has(a.commander):
			var c: Person = w.people[a.commander]
			var v := c.skill("martial", day)
			if v > best:
				best = v
				best_name = "%s的军事" % c.name
			if c.id == a.owner and c.realm != "" and v + War.ADV_LIEGE > best:
				best = v + War.ADV_LIEGE
				best_name = "%s的军事, 国王亲自带兵 +%d" % [c.name, War.ADV_LIEGE]
		gathering = gathering or int(a.gather) > 0
		debt = debt or w.people[a.owner].gold < 0.0
		landed = landed or (moved_in and int(a.landed) >= day - 1)
	if best > 0:
		parts.append([best_name, best])
	if gathering:
		parts.append(["还在集合", War.ADV_GATHERING])
	if debt:
		parts.append(["欠着钱", War.ADV_DEBT])
	if landed:
		parts.append(["刚从船上下来", War.ADV_SEA])
	var total := 0
	for p in parts:
		total += int(p[1])
	return {"total": total, "parts": parts}


func _roll(b: Dictionary, day: int) -> void:
	b.adv_a = _advantage(_side(b.a), day, true)
	b.adv_b = _advantage(_side(b.b), day, false)


## 元帅「训练将领」: 一边的兵打仗强多少 (这边几个主人里最好的那个元帅)
func _trained(side: Array) -> float:
	var best := 0
	for a in side:
		best = maxi(best, w.council.task_skill(w.people.get(a.owner), "train"))
	return 1.0 + Councils.TRAIN_DAMAGE * best


## 一方垮了: 剩下不到开打时的两成
func _broken(men: float, start: float) -> bool:
	return men < 1.0 or men <= start * War.BREAK_AT


func _battle_day(b: Dictionary, day: int, events: Array) -> void:
	b.day = int(b.day) + 1
	var A := _side(b.a)
	var B := _side(b.b)
	if A.is_empty() or B.is_empty():
		_end_battle(b, not A.is_empty(), day, events)
		return
	if int(b.day) <= War.MANEUVER_DAYS:
		return
	if (int(b.day) - War.MANEUVER_DAYS) % War.ROLL_DAYS == 0:
		_roll(b, day)
	var sa := _side_men(b.a)
	var sb := _side_men(b.b)
	var width := 0.5 * (sa + sb)
	var adv: int = int(b.adv_a) - int(b.adv_b)
	var dmg_a := minf(sa, width) * War.DAMAGE * War.DAMAGE_SCALE * (1.0 + War.ADV_BONUS * maxi(0, adv)) * _trained(A)
	var dmg_b := minf(sb, width) * War.DAMAGE * War.DAMAGE_SCALE * (1.0 + War.ADV_BONUS * maxi(0, -adv)) * _trained(B)
	var lose_b := minf(sb, dmg_a / War.TOUGHNESS)
	var lose_a := minf(sa, dmg_b / War.TOUGHNESS)
	_take(A, lose_a)
	_take(B, lose_b)
	b.lost_a += lose_a * War.KILLED_SHARE
	b.routed_a += lose_a * (1.0 - War.KILLED_SHARE)
	b.lost_b += lose_b * War.KILLED_SHARE
	b.routed_b += lose_b * (1.0 - War.KILLED_SHARE)
	var ba := _broken(_side_men(b.a), b.start_a)
	var bb := _broken(_side_men(b.b), b.start_b)
	if ba or bb:
		var a_won := not ba or (bb and _side_men(b.a) / maxf(1.0, b.start_a) > _side_men(b.b) / maxf(1.0, b.start_b))
		_end_battle(b, a_won, day, events)


func _take(list: Array, n: float) -> void:
	var total := 0.0
	for a in list:
		total += soldiers(a)
	if total <= 0.0:
		return
	for a in list:
		_lose(a, n * soldiers(a) / total)


## 打完了: 赢的那边逃散的兵回来; 输的那边逃散的兵被追着砍死三分之一 (头 12 天就垮了的全军覆没), 剩下的跟着撤退
func _end_battle(b: Dictionary, a_won: bool, day: int, events: Array) -> void:
	battles.erase(b.id)
	var war := war_by_id(int(b.war))
	var W := _side(b.a if a_won else b.b)
	var L := _side(b.b if a_won else b.a)
	var w_routed: float = b.routed_a if a_won else b.routed_b
	var l_routed: float = b.routed_b if a_won else b.routed_a
	var wiped := int(b.day) - War.MANEUVER_DAYS <= War.EARLY_DAYS
	var chased := l_routed if wiped else l_routed * War.PURSUIT
	if not W.is_empty():
		_gain(W, w_routed)
	if not L.is_empty():
		_gain(L, l_routed - chased)
	var lost_w: float = b.lost_a if a_won else b.lost_b
	var lost_l: float = (b.lost_b if a_won else b.lost_a) + chased
	for a in W + L:
		a.battle = -1
	var winner := _owner_of(W)
	var loser := _owner_of(L)
	# 战争分数: 输的一方这仗死的兵, 占他们一共能征的兵的几成 (照三代: 打仗最多算 50 分)
	if not war.is_empty() and loser != "":
		var lside := side(war, loser)
		var pool := 0.0
		for pid in (war.attackers if lside == 1 else war.defenders):
			if w.people.has(pid):
				var lv := levy_of(w.people[pid])
				pool += lv.full + lv.special
				var ar := army_of(pid)
				if not ar.is_empty():
					pool += ar.special
		war.battle = float(war.battle) - lside * 100.0 * lost_l / maxf(pool, 1.0)
	for a in W:
		if w.people.has(a.owner):
			w.people[a.owner].prestige += War.BATTLE_PRESTIGE
	var dead := []
	var captured := []
	for a in W + L:
		if a.commander == "" or not w.people.has(a.commander):
			continue
		var c: Person = w.people[a.commander]
		var lost: bool = L.has(a)
		var k := maxf(0.1, (30.0 - c.skill("prowess", day)) / 30.0)
		if lost and winner != "" and w.rng.randf() < War.CAPTURE * k * (0.5 if c.has_trait("craven") else (2.0 if c.has_trait("brave") else 1.0)):
			captured.append(c.id)
		elif w.rng.randf() < (War.DIE_LOSE if lost else War.DIE_WIN) * k:
			dead.append(c.id)
	var ev := {"type": "battle", "war": int(b.war), "loc": b.loc, "winner": winner, "loser": loser, "lost_w": int(lost_w), "lost_l": int(lost_l),
			"wiped": wiped and not L.is_empty(), "dead": dead, "captured": captured, "day": day,
			"winners": W.map(func(x: Dictionary) -> String: return x.owner), "losers": L.map(func(x: Dictionary) -> String: return x.owner),
			"winner_commanders": W.map(func(x: Dictionary) -> String: return x.commander)}
	for a in L:
		if soldiers(a) < 1.0:
			_destroy(a)
		else:
			_retreat(a)
	for a in W:
		a.path = []
		a.leg = 0.0
	events.append(ev)
	for id in captured:
		var c: Person = w.people[id]
		c.prisoner_of = winner
		c.dungeon = false
		for a in armies.values():
			if a.commander == id:
				a.commander = ""
	for id in dead:
		if w.people[id].alive:
			w.kill(w.people[id], day, events, "在%s战死了" % w.by_id[b.loc].name)


## 输了往回撤: 撤到最近的自己人的地 (那里没有敌军), 路上走得快一些、不会再被拦住打
func _retreat(a: Dictionary) -> void:
	var dist: Dictionary = _dijkstra(a.loc)[0]
	var best := ""
	var best_d := INF
	for c in w.counties:
		if c.id == a.loc or not friendly(a.owner, controller(c)) or _enemy_army_at(a.owner, c.id):
			continue
		var d: float = dist.get(c.id, INF)
		if d < best_d:
			best_d = d
			best = c.id
	a.path = route(a.loc, best) if best != "" else []
	a.leg = 0.0
	if not a.path.is_empty():
		a.leg_days = a.path[0][1]
		a.sea = a.path[0][2]
		a.retreat = 1
	else:
		a.retreat = 0


# ---- 围城 ----

func _siege_day(day: int, events: Array) -> void:
	var by_loc := {}
	for a in armies.values():
		if int(a.battle) != -1 or int(a.retreat) > 0 or int(a.gather) > 0 or not a.path.is_empty():
			continue
		if not hostile(a.owner, controller(w.by_id[a.loc])):
			continue
		if not by_loc.has(a.loc):
			by_loc[a.loc] = []
		by_loc[a.loc].append(a)
	for loc in sieges.keys():
		if not by_loc.has(loc):
			sieges.erase(loc)
	for loc in by_loc:
		var c: Dictionary = w.by_id[loc]
		var busy := false
		for b in battles.values():
			if b.loc == loc:
				busy = true
		if busy:
			continue
		var list: Array = by_loc[loc]
		var men := 0.0
		for a in list:
			men += soldiers(a)
		if men <= c.garrison:
			sieges.erase(loc)
			continue
		if not sieges.has(loc):
			sieges[loc] = {"progress": 0.0, "days": 0, "starve": 0, "sick": 0, "by": list[0].owner}
		var s: Dictionary = sieges[loc]
		s.days = int(s.days) + 1
		var rate := War.SIEGE_DAILY + War.SIEGE_PER_200 * floorf((men - c.garrison) / 200.0)
		rate *= 1.0 + 0.1 * int(s.sick) + 0.1 * int(s.starve)
		s.progress += rate
		if int(s.days) % War.SIEGE_EVENT_DAYS == 0:
			# 照三代: 没动静 20、有人逃出城 20、断粮 15、闹病 15 (我们没有投石机, 打不破城墙)
			var r := w.rng.randi_range(1, 70)
			if r > 20 and r <= 40:
				s.progress += 5.0
			elif r > 40 and r <= 55:
				s.starve = mini(2, int(s.starve) + 1)
			elif r > 55:
				s.sick = mini(2, int(s.sick) + 1)
		if s.progress >= siege_needed(c):
			sieges.erase(loc)
			_occupy(c, _owner_of(list), day, events)


func _owner_of(list: Array) -> String:
	var best := ""
	var men := -1.0
	for a in list:
		if soldiers(a) > men:
			men = soldiers(a)
			best = a.owner
	return best


## 围下来了: 敌人的地被占领 (不出钱不出兵), 自己人的地收回来; 打下的是都城, 城里的人可能被抓
func _occupy(c: Dictionary, by: String, day: int, events: Array) -> void:
	var real := party(c)
	var was := controller(c)
	var liberated := friendly(by, real)
	c.occupier = "" if liberated else by
	c.garrison = max_garrison(c) * 0.25
	var ev := {"type": "siege", "county": c.id, "by": by, "from": was, "liberated": liberated, "captured": [], "day": day}
	if not liberated:
		for rid in w.realm_order:
			if w.realms[rid].get("capital", "") != c.id:
				continue
			var k := w.ruler(rid)
			var inside := [k]
			for f in w._close_family(k):
				if not w.is_landed(f) and f.prisoner_of == "":
					inside.append(f)
			for p in inside:
				if p.prisoner_of != "" or not army_of(p.id).is_empty() or _commanding(p.id):
					continue
				var chance := War.CAPTURE_IN_CAPITAL - minf(0.2, p.skill("intrigue", day) * 0.01) - minf(0.15, p.skill("prowess", day) * 0.005)
				if w.rng.randf() < chance:
					p.prisoner_of = by
					p.dungeon = false
					ev.captured.append(p.id)
	events.append(ev)


func _commanding(pid: String) -> bool:
	for a in armies.values():
		if a.commander == pid:
			return true
	return false


# ---- 战争分数 ----

## 战争分数 (进攻方看的, -100 到 100): {total, parts: [[说明, 分数], ...]}
func score(war: Dictionary) -> Dictionary:
	var parts := []
	var bs := clampf(war.battle, -War.BATTLE_CAP, War.BATTLE_CAP)
	if absf(bs) >= 0.5:
		parts.append(["打仗", bs])
	var count := {1: 0, -1: 0}
	var occ := {1: 0.0, -1: 0.0}
	var occ_n := {1: 0, -1: 0}
	for c in w.counties:
		var sp := side(war, party(c))
		if sp != 0:
			count[sp] += 1
	for c in w.counties:
		if c.occupier == "":
			continue
		var sp := side(war, party(c))
		var so := side(war, c.occupier)
		if sp != 0 and so == -sp:
			occ[so] += 2.0 if war.targets.has(c.id) else 1.0
			occ_n[so] += 1
	for s in [1, -1]:
		if occ_n[s] > 0:
			var v: float = 100.0 * occ[s] / maxf(1.0, float(count[-s]) + war.targets.size())
			parts.append(["%s占了对方 %d 块地" % [side_label(war, s), occ_n[s]], v * s])
	for s in [1, -1]:
		var leader: String = war.defender if s == 1 else war.attacker
		if not w.people.has(leader):
			continue
		var lp: Person = w.people[leader]
		var cap := ""
		if lp.realm != "" and w.realms.has(lp.realm):
			cap = w.realms[lp.realm].get("capital", "")
		elif w.is_landed(lp) and not w.lands_of(lp).is_empty():
			cap = w.lands_of(lp)[0].id
		if cap != "" and w.by_id[cap].occupier != "" and side(war, w.by_id[cap].occupier) == s:
			parts.append(["占了%s的都城" % lp.name, War.CAPITAL_SCORE * s])
		if lp.prisoner_of != "" and side(war, lp.prisoner_of) == s:
			parts.append(["抓到了%s" % lp.name, War.LEADER_CAPTURED * s])
		if lp.realm != "" and w.realms.has(lp.realm):
			var h := w.heir(lp.realm, w.today)
			if h != null and h.prisoner_of != "" and side(war, h.prisoner_of) == s:
				parts.append(["抓到了%s的继承人%s" % [lp.name, h.name], War.HEIR_CAPTURED * s])
	if absf(war.tick) >= 0.5:
		parts.append(["占着要的地" if war.tick > 0 else "一直没占下要的地", war.tick])
	var total := 0.0
	for p in parts:
		total += p[1]
	return {"total": clampf(total, -100.0, 100.0), "parts": parts}


## 一方叫什么 (带头的国家的名字, 造反的封臣是他的名字)
func side_label(war: Dictionary, s: int) -> String:
	var pid: String = war.attacker if s == 1 else war.defender
	if not w.people.has(pid):
		return "进攻方" if s == 1 else "防守方"
	var p: Person = w.people[pid]
	return w.realm_name(p.realm) if p.realm != "" and w.realms.has(p.realm) else p.name


# ---- 宣战 ----

## 他手下能替他去要地的人 (他自己、家里没领地的男人、住在他那里的人): [人, 威望倍数]。
## 女人的宣称用不了 (我们只有男人能继承), 但会传给她的孩子
func claimants(p: Person) -> Array:
	var out := [[p, 1.0]]
	var realm := w.realm_of_person(p)
	for q in w.house_members(p.house):
		if q != p and not q.female and _has_claims(q) and not w.is_landed(q) and (w.home_realm(q) == realm or w.relation(p, q) != ""):
			out.append([q, War.CLAIM_FAMILY])
	for q in w.living.values():
		if q.liege_realm == realm and not q.female and _has_claims(q) and not w.is_landed(q) and q.house != p.house:
			out.append([q, War.CLAIM_OTHER])
	return out


func _has_claims(q: Person) -> bool:
	return not q.claims.is_empty() or not q.weak_claims.is_empty()


## 能对 def 宣战的理由: [{cb, target, targets, claimant, cost, label, ok, why}]
func cb_options(att: Person, def: Person) -> Array:
	var out := []
	if att == def or not att.alive or not def.alive:
		return out
	var ar := att.realm
	var dr := def.realm
	if ar == "" and dr != "" and att.liege_realm == dr and w.is_landed(att) and (w.liege_of(att) == def or w.viceroy_duchy(att) != ""):
		out.append(_opt(att, def, "independence", "", [w.realms[dr].capital], "", War.COST_INDEPENDENCE, "不再听%s的" % def.name))
	if ar == "" or dr == "" or not w.realms.has(ar) or not w.realms.has(dr):
		return out
	var mine := w.counties_of(ar)
	var theirs := w.counties_of(dr)
	if theirs.is_empty():
		return out
	for pair in claimants(att):
		var q: Person = pair[0]
		var mult: float = pair[1]
		for claim in q.claims + q.weak_claims:
			if claim == "realm:" + dr:
				out.append(_opt(att, def, "claim", claim, [w.realms[dr].capital], q.id, War.COST_CLAIM_REALM * mult,
						"%s要%s的王位" % ["你" if q == att else q.name, w.realm_name(dr)]))
			elif claim.begins_with("county:"):
				var cid: String = claim.substr(7)
				if w.by_id.has(cid) and w.by_id[cid].holder == dr:
					out.append(_opt(att, def, "claim", claim, [cid], q.id, War.COST_CLAIM_COUNTY * mult,
							"%s要%s" % ["你" if q == att else q.name, w.by_id[cid].name]))
	for t in w.realm_duchies(ar):
		var cs := theirs.filter(func(c: Dictionary) -> bool: return c.duchy == t)
		if not cs.is_empty():
			out.append(_opt(att, def, "de_jure", "duchy:" + t, cs.map(func(c: Dictionary) -> String: return c.id), "",
					War.COST_DE_JURE * cs.size(), "要回%s公国里的%s" % [w.duchies[t].name, "、".join(cs.map(func(c: Dictionary) -> String: return c.name))]))
	var af := Marriage.faith_of(att.culture)
	var df := Marriage.faith_of(def.culture)
	if af == "norse" or af != df:
		# 维京人坐船也能打; 基督徒只打挨着自己的地 (9 世纪英格兰、爱尔兰、威尔士几乎没有水军, 阿尔弗雷德 875 年才造船)
		var kind := "conquest" if af == "norse" else "holy"
		var near := theirs.filter(func(c: Dictionary) -> bool: return _reachable(mine, c, kind == "conquest"))
		var by_duchy := {}
		for c in near:
			var cost := War.COST_CONQUEST + War.COST_CONQUEST_PER_OWN * mine.size() if kind == "conquest" else War.COST_HOLY
			out.append(_opt(att, def, kind, c.id, [c.id], "", cost, "抢%s" % c.name))
			if not by_duchy.has(c.duchy):
				by_duchy[c.duchy] = true
		for d in by_duchy:
			var cs := theirs.filter(func(c: Dictionary) -> bool: return c.duchy == d)
			if cs.size() < 2:
				continue
			var cost := War.COST_CONQUEST_DUCHY + War.COST_CONQUEST_DUCHY_PER_OWN * mine.size() if kind == "conquest" else War.COST_HOLY_DUCHY
			out.append(_opt(att, def, kind, "duchy:" + d, cs.map(func(c: Dictionary) -> String: return c.id), "", cost,
					"抢他在%s公国的 %d 块地" % [w.duchies[d].name, cs.size()]))
	return out


## 这块地够得着吗 (挨着自己的地; by_sea: 坐船够得着也算)
func _reachable(mine: Array, c: Dictionary, by_sea: bool) -> bool:
	for m in mine:
		for e in _graph[m.id]:
			if e[0] == c.id and (by_sea or not e[2]):
				return true
	return false


func _opt(att: Person, def: Person, cb: String, target: String, targets: Array, claimant: String, cost: float, label: String) -> Dictionary:
	var o := {"cb": cb, "target": target, "targets": targets, "claimant": claimant, "cost": roundf(cost), "label": label,
			"defender": def.id, "ok": true, "why": "", "truce": false}
	var rd := def.realm if def.realm != "" else def.liege_realm
	var ra := att.realm if att.realm != "" else att.liege_realm
	if truce_until(ra, rd) > w.today and cb != "independence":
		o.truce = true
		o.cost += War.TRUCE_BREAK
	var why := ""
	if not att.adult(w.today):
		why = "还不满 16 岁"
	elif att.prisoner_of != "":
		why = "关在大牢里"
	elif att.gold < 0.0:
		why = "欠着钱 (金钱是负的), 不能宣战"
	elif hostile(att.id, def.id):
		why = "已经在跟他打了"
	elif w.intrigue != null and w.intrigue.held_by(att, def):
		why = "%s攥着你的把柄, 不能对他宣战" % def.name
	elif att.prestige < o.cost:
		why = "威望不够 (有 %d, 要 %d)" % [int(att.prestige), int(o.cost)]
	o.ok = why == ""
	o.why = why
	return o


## 宣战 (option 是 cb_options 里的一个)。forced: 史料里的仗, 不花威望、不管停战
func declare(att: Person, opt: Dictionary, day: int, events: Array, forced := false) -> Dictionary:
	var def: Person = w.people[opt.defender]
	if not forced and not opt.ok:
		return {"ok": false, "text": opt.why}
	if not forced:
		att.prestige -= opt.cost
		if opt.truce:
			truces.erase(_truce_key(att.realm if att.realm != "" else att.liege_realm, def.realm if def.realm != "" else def.liege_realm))
			for rid in w.realm_order:
				var k := w.ruler(rid)
				if k != att:
					k.remember(att.id, "背弃停战", -20, day + 3 * GameDate.YEAR_DAYS)
	var war := {"id": next_id, "cb": opt.cb, "attacker": att.id, "defender": def.id, "attackers": [att.id], "defenders": [def.id],
			"target": opt.target, "targets": opt.targets.duplicate(), "claimant": opt.claimant, "label": opt.label,
			"start": day, "battle": 0.0, "tick": 0.0, "months": 0}
	next_id += 1
	wars.append(war)
	_rebuild_rebels()
	def.remember(att.id, "向我宣战", -30, day + 10 * GameDate.YEAR_DAYS)
	events.append({"type": "war", "war": war.id, "attacker": att.id, "defender": def.id, "cb": opt.cb, "label": opt.label, "day": day})
	_call_allies(war, -1, day, events)
	_call_allies(war, 1, day, events)
	return {"ok": true, "text": "向%s宣战 (%s: %s)" % [def.name, War.cb_name(opt.cb), opt.label]}


## 一方的同盟 (国王) 来不来帮忙: 电脑看好感 (保卫战好说话); 玩家弹窗问
func _call_allies(war: Dictionary, s: int, day: int, events: Array) -> void:
	var leader: Person = w.people[war.attacker if s == 1 else war.defender]
	if leader.realm == "" or not w.realms.has(leader.realm):
		return
	var other: Person = w.people[war.defender if s == 1 else war.attacker]
	for rid in w.allies(leader.realm):
		if not w.realms.has(rid):
			continue
		var q := w.ruler(rid)
		if side(war, q.id) != 0 or q == other or (other.realm != "" and w.allies(rid).has(other.realm)):
			continue
		if q.id == w.player:
			events.append({"type": "ally_call", "war": war.id, "ally": q.id, "leader": leader.id, "side": s, "day": day})
		elif ally_accepts(q, leader, s):
			join(war, q, s)


func ally_accepts(q: Person, leader: Person, s: int) -> bool:
	if not q.alive or q.prisoner_of != "" or q.gold < 0.0:
		return false
	var o: int = q.opinion_of(leader).total
	return o >= (-20 if s == -1 else 20)


func join(war: Dictionary, q: Person, s: int) -> void:
	if side(war, q.id) != 0:
		return
	(war.attackers if s == 1 else war.defenders).append(q.id)


## 玩家不去帮盟友: 盟友记着 (进攻 -20 五年, 防守 -40 十年)
func decline(war: Dictionary, q: Person, s: int, day: int) -> void:
	var leader: Person = w.people[war.attacker if s == 1 else war.defender]
	if s == 1:
		leader.remember(q.id, "不来帮我打仗", War.DECLINE_ATTACK, day + 5 * GameDate.YEAR_DAYS)
	else:
		leader.remember(q.id, "我挨打时不来帮忙", War.DECLINE_DEFEND, day + 10 * GameDate.YEAR_DAYS)


## 玩家叫盟友来帮忙 (电脑自己决定)
func call_ally(war: Dictionary, me: Person, q: Person) -> Dictionary:
	var s := side(war, me.id)
	if side(war, q.id) != 0:
		return {"ok": false, "text": "%s已经在这场仗里了" % q.name}
	if ally_accepts(q, me, s):
		join(war, q, s)
		return {"ok": true, "text": "%s答应来帮忙" % q.name}
	return {"ok": false, "text": "%s不肯来 (他对你的好感 %+d, %s要 %+d 以上)" % [q.name, q.opinion_of(me).total, "进攻" if s == 1 else "防守", 20 if s == 1 else -20]}


# ---- 谈和 ----

## 结束一场仗。result: attacker 进攻方赢 / defender 防守方赢 / white 平局 / bought 花钱求和 / invalid 打不下去了
func end_war(war: Dictionary, result: String, day: int, events: Array, price := 0) -> void:
	if not wars.has(war):
		return
	wars.erase(war)
	_rebuild_rebels()
	var att: Person = w.people.get(war.attacker)
	var def: Person = w.people.get(war.defender)
	var ra := w.realm_of_person(att) if att != null else ""
	var rd := w.realm_of_person(def) if def != null else ""
	var gained := []
	if att != null and def != null:
		match result:
			"attacker":
				gained = _apply_win(war, att, def, day, events)
			"defender":
				_apply_loss(war, att, def, day)
			"white":
				if war.cb == "conquest":
					att.prestige -= War.WHITE_CONQUEST
			"bought":
				def.gold -= price
				att.gold += price
	if ra != "" and rd != "" and ra != rd:
		truces[_truce_key(ra, rd)] = day + War.TRUCE_YEARS * GameDate.YEAR_DAYS
	for c in w.counties:
		if c.occupier != "" and not hostile(c.occupier, party(c)):
			c.occupier = ""
	for b in battles.values():
		var A := _side(b.a)
		var B := _side(b.b)
		if not A.is_empty() and not B.is_empty() and not hostile(A[0].owner, B[0].owner):
			battles.erase(b.id)
			for a in A + B:
				a.battle = -1
	events.append({"type": "war_end", "war": war.duplicate(true), "result": result, "price": price, "gained": gained, "day": day})


## 进攻方赢了: 照宣战理由办。返回拿到的领地
func _apply_win(war: Dictionary, att: Person, def: Person, day: int, events: Array) -> Array:
	att.prestige += War.WIN_PRESTIGE
	def.remember(att.id, "打赢了我", -20, day + 10 * GameDate.YEAR_DAYS)
	var got := []
	match war.cb:
		"claim":
			var q: Person = w.people.get(war.claimant, att)
			if not q.alive:
				q = att
			q.claims.erase(war.target)
			q.weak_claims.erase(war.target)
			if war.target.begins_with("realm:"):
				var rid: String = war.target.substr(6)
				if w.realms.has(rid) and w.ruler(rid) == def:
					w.crown_claimant(rid, q, att, day, events)
					got = w.counties_of(w.realm_of_person(q)).map(func(c: Dictionary) -> String: return c.id)
			else:
				var c: Dictionary = w.by_id[war.target.substr(7)]
				if c.holder == w.realm_of_person(def) and att.realm != "" and w.realms.has(att.realm):
					w.transfer_county(c, att.realm, q, day, events)
					got.append(c.id)
		"de_jure", "conquest", "holy":
			for cid in war.targets:
				var c: Dictionary = w.by_id[cid]
				if c.holder == def.realm and att.realm != "" and w.realms.has(att.realm):
					w.transfer_county(c, att.realm, att, day, events)
					got.append(cid)
			if war.target.begins_with("duchy:") and att.realm != "" and w.realms.has(att.realm):
				var d: String = war.target.substr(6)
				if w.counties_in_duchy(d).all(func(c: Dictionary) -> bool: return c.holder == att.realm):
					for rid in w.realm_order:
						if rid != att.realm:
							w.realms[rid].titles.erase(d)
					if not w.realms[att.realm].titles.has(d):
						w.realms[att.realm].titles.append(d)
		"independence":
			w.make_independent(att, day, events)
			got = w.lands_of(att).map(func(c: Dictionary) -> String: return c.id)
		"punitive":
			var pay := War.loser_pays(w.income(def).gold)
			def.gold -= pay
			att.gold += pay
			def.prestige -= War.DEFEND_PRESTIGE
	return got


func _apply_loss(war: Dictionary, att: Person, def: Person, day: int) -> void:
	def.prestige += War.DEFEND_PRESTIGE
	match war.cb:
		"claim":
			var q: Person = w.people.get(war.claimant, att)
			q.claims.erase(war.target)
			q.weak_claims.erase(war.target)
		"independence":
			att.prisoner_of = def.id
			att.dungeon = false
			att.crimes["造反"] = day + Feudal.CRIME_YEARS * GameDate.YEAR_DAYS
		_:
			var pay := War.loser_pays(w.income(att).gold)
			att.gold -= pay
			def.gold += pay


## 谈和的价钱: 防守方花钱求和要多少
func price_of(war: Dictionary) -> int:
	var def: Person = w.people[war.defender]
	return War.peace_price(w.income(def).gold, score(war).total)


## 电脑 (进攻方) 收不收钱走人: 维京人 (征服) 好说话; 快赢了的不收
func takes_money(war: Dictionary) -> bool:
	var s: float = score(war).total
	if s >= 90.0:
		return false
	return war.cb in ["conquest", "punitive"] or s < 50.0


## 电脑收不收平局: 自己没占上风就收 (打了三个月以后)
func takes_white(war: Dictionary, ai_side: int) -> bool:
	var s: float = score(war).total * ai_side
	return int(war.months) >= 3 and s <= 10.0


# ---- 每个月 ----

## 开局: 867 年 1 月就在打的仗 (史料里的仗那一条开着才有)
func monthly_history_only(day: int) -> void:
	_history_wars(day, [])


func monthly(day: int, events: Array) -> void:
	for a in armies.values():
		var p: Person = w.people[a.owner]
		p.gold -= upkeep(a)
		if sieges.has(a.loc):
			_lose(a, soldiers(a) * War.ATTRITION_SIEGE)
	for p in w.living.values():
		if p.levy_ratio < 1.0 and army_of(p.id).is_empty():
			p.levy_ratio = minf(1.0, p.levy_ratio + War.LEVY_REFILL * (1.0 + Councils.ORGANIZE_REFILL * w.council.task_skill(p, "organize")))
	for c in w.counties:
		if not sieges.has(c.id):
			c.garrison = minf(max_garrison(c), c.garrison + max_garrison(c) * War.GARRISON_REFILL)
	for war in wars.duplicate():
		if wars.has(war):
			_war_month(war, day, events)
	for k in truces.keys():
		if int(truces[k]) <= day:
			truces.erase(k)
	_history_wars(day, events)
	_history_reinforcements(day, events)
	_ai_declare(day, events)
	_ai_prisoners(day)


func _war_month(war: Dictionary, day: int, events: Array) -> void:
	war.months = int(war.months) + 1
	var att: Person = w.people.get(war.attacker)
	var def: Person = w.people.get(war.defender)
	if att == null or def == null or not att.alive or not def.alive or att == def or not w.is_landed(att) or not w.is_landed(def):
		end_war(war, "invalid", day, events)
		return
	if war.cb == "independence" and w.liege_of(att) == null and att.realm != "":
		end_war(war, "invalid", day, events)
		return
	var held := 0
	for cid in war.targets:
		if side(war, controller(w.by_id[cid])) == 1:
			held += 1
	if held == war.targets.size() and held > 0:
		war.tick = minf(100.0, war.tick + War.TARGET_TICK)
	elif held == 0 and int(war.months) > War.TARGET_GRACE:
		war.tick = maxf(-100.0, war.tick - War.TARGET_TICK)
	var s: float = score(war).total
	var att_ai := att.id != w.player
	var def_ai := def.id != w.player
	if s >= 100.0 and att_ai:
		end_war(war, "attacker", day, events)
	elif s <= -100.0 and def_ai:
		end_war(war, "defender", day, events)
	elif att_ai and def_ai:
		var r := w.rng.randf()
		if int(war.months) >= 24 and absf(s) < 25.0 and r < 1.0 / 6.0:
			end_war(war, "white", day, events)
		elif int(war.months) >= 60 and absf(s) < 60.0:
			end_war(war, "white", day, events)
		elif s >= 40.0 and r < 0.15 and def.gold >= price_of(war) and takes_money(war):
			end_war(war, "bought", day, events, price_of(war))
		elif s <= -60.0 and r < 0.2:
			end_war(war, "defender", day, events)
		elif s >= 60.0 and r < 0.2 and army_of(def.id).is_empty():
			end_war(war, "attacker", day, events)
	elif def_ai:
		# 玩家进攻: 快输光的电脑认输; 打不过的电脑出钱求和 (半年问一次)
		if s >= 100.0 and w.rng.randf() < 0.25:
			end_war(war, "attacker", day, events)
		elif s >= 50.0 and int(war.months) % 6 == 0 and def.gold >= price_of(war):
			events.append({"type": "peace_offer", "war": war.id, "price": price_of(war), "day": day})
	elif att_ai:
		if s <= -100.0 and w.rng.randf() < 0.25:
			end_war(war, "defender", day, events)


## 史料里的仗: 到了那年那月, 两个国家都还在、电脑那一方去宣战 (玩家是进攻方就不管; 开局设置「历史上的仗」能关)
func _history_wars(day: int, events: Array) -> void:
	if w.rules.get("wars", "on") != "on":
		return
	var d := GameDate.from_day(day)
	for i in w.history_wars.size():
		if history_done.has(i):
			continue
		var hw: Dictionary = w.history_wars[i]
		if int(d[0]) < int(hw.year) or (int(d[0]) == int(hw.year) and int(d[1]) < int(hw.month)):
			continue
		history_done.append(i)
		if not w.realms.has(hw.attacker) or not w.realms.has(hw.defender):
			continue
		var att := w.ruler(hw.attacker)
		var def := w.ruler(hw.defender)
		if (att.id == w.player and day > w.start_day) or hostile(att.id, def.id) or not att.alive or not def.alive:
			continue
		var targets := []
		var t: String = hw.target
		if t.begins_with("duchy:"):
			targets = w.counties_of(hw.defender).filter(func(c: Dictionary) -> bool: return c.duchy == t.substr(6)).map(func(c: Dictionary) -> String: return c.id)
		elif w.by_id[t].holder == hw.defender:
			targets = [t]
		if targets.is_empty():
			continue
		var label := ""
		match hw.cb:
			"de_jure":
				label = "要回%s" % w.by_id[targets[0]].name
			"punitive":
				label = "教训%s" % w.realm_name(hw.defender)
			_:
				label = "抢%s" % ("、".join(targets.map(func(id: String) -> String: return w.by_id[id].name)))
		declare(att, {"cb": hw.cb, "target": t, "targets": targets, "claimant": "", "cost": 0.0, "label": label,
				"defender": def.id, "ok": true, "why": "", "truce": false}, day, events, true)


## 史料里维京人的援兵 (871 年夏季大军来到雷丁): 到了那年那月, 这个国家还在, 就多一批不用养的兵 (军队征着就直接加进军队)
func _history_reinforcements(day: int, events: Array) -> void:
	var d := GameDate.from_day(day)
	for i in w.history_reinforcements.size():
		if reinforce_done.has(i):
			continue
		var hr: Dictionary = w.history_reinforcements[i]
		if int(d[0]) < int(hr.year) or (int(d[0]) == int(hr.year) and int(d[1]) < int(hr.month)):
			continue
		reinforce_done.append(i)
		if not w.realms.has(hr.realm):
			continue
		var k := w.ruler(hr.realm)
		var n := float(hr.special)
		var a := army_of(k.id)
		if not a.is_empty():
			a.special += n
		else:
			w.realms[hr.realm].special = int(w.realms[hr.realm].get("special", 0)) + int(n)
		events.append({"type": "reinforce", "realm": hr.realm, "ruler": k.id, "men": int(n), "where": hr.get("where", ""), "day": day})


## 电脑宣战: 平均四年想一次 (维京人一年半一次), 找个自己打得过 (加上盟友; 基督徒要强一半, 维京人差不多就敢) 又有理由的;
## 封臣对国王很不满又兵多就造反
func _ai_declare(day: int, events: Array) -> void:
	for rid in w.realm_order.duplicate():
		if not w.realms.has(rid):
			continue
		var k := w.ruler(rid)
		if k.id == w.player or not k.alive or k.prisoner_of != "" or not k.adult(day) or k.gold < 0.0 or is_at_war(k.id):
			continue
		var norse := Marriage.faith_of(k.culture) == "norse"
		var chance := 1.0 / (18.0 if norse else 48.0)
		if k.has_trait("ambitious"):
			chance *= 1.5
		if k.has_trait("content"):
			chance *= 0.5
		if k.has_trait("craven"):
			chance *= 0.6
		if w.rng.randf() >= chance:
			continue
		var mine := strength(k)
		var best := {}
		var best_v := 0.0
		for other in w.realm_order:
			if other == rid or not w.realms.has(other) or w.allies(rid).has(other) or truce_until(rid, other) > day:
				continue
			var d := w.ruler(other)
			var theirs := strength(d)
			for ally in w.allies(other):
				if w.realms.has(ally):
					theirs += strength(w.ruler(ally)) * 0.5
			var ratio := mine / maxf(1.0, theirs)
			if ratio < (1.0 if norse else 1.5):
				continue
			for o in cb_options(k, d):
				if not o.ok or o.truce or o.cb == "independence":
					continue
				var v: float = ratio * (1.0 + o.targets.size() * 0.2) / (1.0 + o.cost / 100.0)
				if v > best_v:
					best_v = v
					best = o
		if not best.is_empty():
			declare(k, best, day, events)
	for rid in w.realm_order.duplicate():
		if not w.realms.has(rid):
			continue
		var k := w.ruler(rid)
		for v in w.vassals_of(k):
			if v.id == w.player or is_at_war(v.id) or v.prisoner_of != "" or not v.adult(day) or w.rng.randf() >= 1.0 / 24.0:
				continue
			if v.opinion_of(k).total > -30:
				continue
			var inc := w.income(v)
			if inc.own_levy + inc.from_levy < 0.5 * strength(k):
				continue
			for o in cb_options(v, k):
				if o.cb == "independence" and o.ok:
					declare(v, o, day, events)
					break


## 打得过打不过: 能征的兵 (补到几成的) + 不用养的兵 (军队征着就看军队)
func strength(p: Person) -> float:
	var a := army_of(p.id)
	if not a.is_empty():
		return soldiers(a)
	var lv := levy_of(p)
	return lv.levy + lv.special


## 电脑关着的别国的人 (打仗抓的): 不打了以后, 每月有机会要赎金放人 (拿不出就过一阵白放)
func _ai_prisoners(day: int) -> void:
	for p in w.living.values():
		if p.prisoner_of == "" or not w.people.has(p.prisoner_of):
			continue
		var jailer: Person = w.people[p.prisoner_of]
		var home := w.home_realm(p)
		if jailer.id == w.player or home == w.realm_of_person(jailer) or hostile(jailer.id, p.id):
			continue
		if w.realms.has(home) and hostile(jailer.id, w.ruler(home).id):
			continue
		var r := w.rng.randf()
		if r < 1.0 / 12.0:
			if w.ransom(jailer, p, day).ok:
				continue
		if r < 1.0 / 36.0:
			w.release(jailer, p, day)


# ---- 电脑带兵 ----

func _ai_armies(day: int, events: Array) -> void:
	for war in wars:
		for pid in war.attackers + war.defenders:
			if pid != w.player and w.people.has(pid) and army_of(pid).is_empty() and (day % 7 == 0 or day - int(war.start) < 2):
				var p: Person = w.people[pid]
				# 电脑等兵补回一半再征 (不然十几个人的小军队一出来就被吃掉)
				if can_raise(p) == "" and (p.levy_ratio >= 0.5 or levy_of(p).special > 0.0):
					raise(p, day)
	for id in armies.keys():
		var a: Dictionary = armies[id]
		if a.owner != w.player and not is_at_war(a.owner) and can_disband(a) == "":
			disband(a)
	if day % 3 != 0:
		return
	for id in armies.keys():
		if not armies.has(id):
			continue
		var a: Dictionary = armies[id]
		if a.owner == w.player or int(a.battle) != -1 or int(a.retreat) > 0 or int(a.gather) > 0:
			continue
		_ai_order(a)


## 一支电脑军队: 打得过的敌军就去打; 打不过的敌军靠近了就退回都城; 不然去围城 (要的地、都城优先, 近的优先)
func _ai_order(a: Dictionary) -> void:
	var me := soldiers(a)
	var dist: Dictionary = _dijkstra(a.loc)[0]
	var chase := {}
	var chase_d := INF
	var threat := false
	for o in armies.values():
		if not hostile(a.owner, o.owner) or int(o.retreat) > 0:
			continue
		var d: float = dist.get(o.loc, INF)
		var them := soldiers(o)
		if them > me * 1.3 and d <= 8.0:
			threat = true
		elif them <= me * 1.05 and d <= 25.0 and d < chase_d:
			chase = o
			chase_d = d
	var owner: Person = w.people[a.owner]
	if threat and chase.is_empty():
		var home := rally_point(owner)
		if home != "" and home != a.loc and (a.path.is_empty() or a.path[a.path.size() - 1][0] != home):
			order_move(a, home)
		return
	if not chase.is_empty():
		var to: String = chase.loc
		if to != a.loc and (a.path.is_empty() or a.path[a.path.size() - 1][0] != to):
			order_move(a, to)
		return
	if sieges.has(a.loc) and a.path.is_empty():
		return
	if not a.path.is_empty():
		return
	var best := ""
	var best_v := INF
	var targets := {}
	for war in wars_of(a.owner):
		if side(war, a.owner) == 1:
			for cid in war.targets:
				targets[cid] = true
	for c in w.counties:
		var ctl := controller(c)
		if not hostile(a.owner, ctl) or c.garrison >= me:
			continue
		var d: float = dist.get(c.id, INF)
		if d == INF:
			continue
		var v := d + (0.0 if targets.has(c.id) else 15.0)
		var lp: Person = w.people[ctl]
		if lp.realm != "" and w.realms.has(lp.realm) and w.realms[lp.realm].get("capital", "") == c.id:
			v -= 10.0
		if v < best_v:
			best_v = v
			best = c.id
	if best != "" and best != a.loc:
		order_move(a, best)


# ---- 有人死了 ----

## 一个人死了 (World.kill 叫的): 他在仗里的位置、他的军队、他占的地都归继承人; 没有继承人这场仗就打不下去了
func on_death(p: Person, heir: Person, day: int, events: Array) -> void:
	for war in wars.duplicate():
		if not wars.has(war):
			continue
		for key in ["attacker", "defender"]:
			var list: Array = war.attackers if key == "attacker" else war.defenders
			var i: int = list.find(p.id)
			if i < 0:
				continue
			var takes := heir != null and side(war, heir.id) == 0
			if takes:
				list[i] = heir.id
			else:
				list.remove_at(i)
			if war[key] == p.id:
				war[key] = heir.id if takes else ""
		if war.claimant == p.id and war.claimant != war.attacker:
			war.claimant = ""
		if war.attacker == "" or war.defender == "" or war.attacker == war.defender or (war.cb == "claim" and war.claimant == "" and war.target != ""):
			end_war(war, "invalid", day, events)
	for id in armies.keys():
		var a: Dictionary = armies[id]
		if a.commander == p.id:
			a.commander = ""
		if a.owner == p.id:
			if heir != null and army_of(heir.id).is_empty():
				a.owner = heir.id
			else:
				_destroy(a)
	for c in w.counties:
		if c.occupier == p.id:
			c.occupier = heir.id if heir != null else ""
	_rebuild_rebels()


# ---- 存档 ----

func to_save() -> Dictionary:
	return {"armies": armies.values(), "wars": wars, "battles": battles.values(), "sieges": sieges, "truces": truces,
			"next_id": next_id, "history_done": history_done, "reinforce_done": reinforce_done}


func from_save(d: Dictionary) -> void:
	armies = {}
	for a in d.get("armies", []):
		a.id = int(a.id)
		a.gather = int(a.gather)
		a.retreat = int(a.retreat)
		a.landed = int(a.landed)
		a.battle = int(a.battle)
		armies[a.id] = a
	wars = d.get("wars", [])
	for war in wars:
		war.id = int(war.id)
		war.start = int(war.start)
		war.months = int(war.months)
	battles = {}
	for b in d.get("battles", []):
		b.id = int(b.id)
		b.war = int(b.war)
		b.day = int(b.day)
		b.a_side = int(b.a_side)
		b.adv_a = int(b.adv_a)
		b.adv_b = int(b.adv_b)
		b.a = b.a.map(func(x: Variant) -> int: return int(x))
		b.b = b.b.map(func(x: Variant) -> int: return int(x))
		battles[b.id] = b
	sieges = d.get("sieges", {})
	for k in sieges:
		sieges[k].days = int(sieges[k].days)
		sieges[k].starve = int(sieges[k].starve)
		sieges[k].sick = int(sieges[k].sick)
	truces = {}
	for k in d.get("truces", {}):
		truces[k] = int(d.truces[k])
	next_id = int(d.get("next_id", 1))
	history_done = d.get("history_done", []).map(func(x: Variant) -> int: return int(x))
	reinforce_done = d.get("reinforce_done", []).map(func(x: Variant) -> int: return int(x))
	_rebuild_rebels()
