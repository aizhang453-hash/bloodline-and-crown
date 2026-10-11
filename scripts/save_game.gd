class_name SaveGame
extends RefCounted
## 存档 (照三代: 随时能存、能读, 每年自动存一次)。一个存档一个 JSON 文件, 放在 dir 文件夹里。
## 测试要把 dir 换成临时文件夹, 不碰玩家真的存档。

const AUTO := "autosave"   # 自动存档的文件名 (每次盖掉上一次)
const VERSION := 1

static var dir := "user://saves"


## 存一个档: 世界、日期、速度、玩家、地图看哪里。name 是给人看的名字; file 不给就按名字和时间起一个
static func write(label: String, world: World, clock: Clock, extra: Dictionary, file := "") -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	if file == "":
		file = "save_%d" % int(Time.get_unix_time_from_system() * 1000.0)
	var path := dir.path_join(file + ".json")
	var me: Person = world.me()
	var data := {
		"version": VERSION, "label": label, "saved_at": Time.get_datetime_string_from_system(false, true),
		"day": clock.day, "speed": clock.speed, "who": ("%s %s" % [world.title_of(me), me.name]) if me != null else "",
		"world": world.to_save(), "extra": extra,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false, true))  # 不重排、小数存全 (读档以后接着走跟没存过一样)
	f.close()
	return path


static func read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	return data if data is Dictionary else {}


## 所有存档, 新的在前: [{path, label, saved_at, day, who, auto}]
static func list() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json"):
			continue
		var path := dir.path_join(file)
		var d := read(path)
		if d.is_empty():
			continue
		out.append({"path": path, "label": d.get("label", file), "saved_at": d.get("saved_at", ""), "day": int(d.get("day", 0)),
				"who": d.get("who", ""), "auto": file == AUTO + ".json"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_at > b.saved_at)
	return out


static func remove(path: String) -> void:
	DirAccess.remove_absolute(path)
