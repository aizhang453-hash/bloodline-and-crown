extends SceneTree
## 跑全部测试。
## 运行方法: 在游戏文件夹里输入
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run_tests.gd
## 新拿到的仓库 (没有 .godot 文件夹) 要先跑一次 Godot --headless --path . --import, 让 Godot 认识各个脚本
## (Windows 上把前面换成 Godot 的路径)。全部通过最后一行是「全部通过」。
## 脚本出错 (SCRIPT ERROR) 也算不对 (用 ErrorCounter 数出来)。

var errors := ErrorCounter.new()


func _initialize() -> void:
	# 等第一帧开始再跑: 那时候把游戏放进场景树, 游戏的 _ready 才会马上执行
	_run_all.call_deferred()


func _run_all() -> void:
	OS.add_logger(errors)
	var here: String = get_script().resource_path.get_base_dir()
	var total := 0
	var failures: Array = []
	var files := Array(DirAccess.get_files_at(here))
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var load_errors := errors.messages.size()
		var script: GDScript = load(here + "/" + file)
		if script == null or not script.can_instantiate() or errors.messages.size() > load_errors:
			failures.append("%s: 读不进来 (脚本写错了) %s" % [file, " ".join(errors.messages.slice(load_errors))])
			print("%s: 读不进来!" % file)
			continue
		var methods := []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_") and not methods.has(m.name):
				methods.append(m.name)
		for m in methods:
			var t = script.new()
			t.current_test = "%s %s" % [file.get_basename(), m]
			var errors_before := errors.messages.size()
			if t.has_method("before_each"):
				t.before_each()
			t.call(m)
			if t.has_method("after_each"):
				t.after_each()
			total += 1
			failures.append_array(t.failures)
			for e in errors.messages.slice(errors_before):
				failures.append("%s: 脚本出错 %s" % [t.current_test, e])
		print("%s: %d 条" % [file, methods.size()])
	for f in failures:
		print("  ✗ ", f)
	if failures.is_empty():
		print("一共 %d 条测试, 全部通过" % total)
	else:
		print("一共 %d 条测试, %d 处不对" % [total, failures.size()])
	OS.remove_logger(errors)
	quit(0 if failures.is_empty() else 1)


## 把 Godot 打印的脚本错误记下来
class ErrorCounter:
	extends Logger

	var messages: Array = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		messages.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		_lock.unlock()
