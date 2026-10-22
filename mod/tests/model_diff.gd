extends Node
## Read-only model comparison (test installs only). Reads two .pngRemix files as
## data (never loads them into the app) and writes mods/_tests/diff.log with
## every differing value path (sprites are matched by sprite_id).
## Run: "PNGTube Remix.console.exe" -- --jz-diff-a=<model> --jz-diff-b=<model>

const MAX_LINES := 300

var out_file : FileAccess
var lines := 0

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--jz-diff-") and "=" in a:
			args[a.get_slice("=", 0).trim_prefix("--jz-diff-")] = a.get_slice("=", 1).trim_prefix("\"").trim_suffix("\"")
	if not (args.has("a") and args.has("b")):
		return
	out_file = FileAccess.open(OS.get_executable_path().get_base_dir() + "/mods/_tests/diff.log", FileAccess.WRITE)
	var a = read_model(args.a)
	var b = read_model(args.b)
	if a == null or b == null:
		out("DONE (unreadable model)")
		return
	out("A=%s\nB=%s" % [args.a, args.b])
	var sa := index_sprites(a)
	var sb := index_sprites(b)
	for id in sa:
		if not sb.has(id):
			out("sprite only in A: %s" % sa[id].sprite_name)
	for id in sb:
		if not sa.has(id):
			out("sprite only in B: %s" % sb[id].sprite_name)
		else:
			diff(sa[id], sb[id], "sprite[%s]" % sb[id].sprite_name)
	for k in a:
		if k != "sprites_array":
			diff(a.get(k), b.get(k), k)
	for k in b:
		if not a.has(k):
			out("%s: only in B" % k)
	out("DONE differences=%d" % lines)

func read_model(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out("can't open %s: %s" % [path, FileAccess.get_open_error()])
		return null
	var data = f.get_var(true)
	return data if data is Dictionary else null

func index_sprites(model: Dictionary) -> Dictionary:
	var by_id := {}
	for sp in model.get("sprites_array", []):
		by_id[sp.sprite_id] = sp
	return by_id

func diff(x, y, path: String) -> void:
	if x is Dictionary and y is Dictionary:
		for k in x:
			if not y.has(k):
				report("%s.%s: only in A (%s)" % [path, k, short(x[k])])
			else:
				diff(x[k], y[k], "%s.%s" % [path, k])
		for k in y:
			if not x.has(k):
				report("%s.%s: only in B (%s)" % [path, k, short(y[k])])
	elif x is Array and y is Array:
		if x.size() != y.size():
			report("%s: size %d vs %d" % [path, x.size(), y.size()])
		for i in min(x.size(), y.size()):
			diff(x[i], y[i], "%s[%d]" % [path, i])
	elif x is Object and y is Object and x != null and y != null:
		# Separately decoded objects (InputEvents) are different instances; compare content.
		if var_to_str(x) != var_to_str(y):
			report("%s: %s -> %s" % [path, short(x), short(y)])
	elif typeof(x) != typeof(y) or x != y:
		if (typeof(x) in [TYPE_INT, TYPE_FLOAT]) and (typeof(y) in [TYPE_INT, TYPE_FLOAT]) and is_equal_approx(float(x), float(y)):
			return
		report("%s: %s -> %s" % [path, short(x), short(y)])

func short(v) -> String:
	var s := str(v) if not (v is PackedByteArray) else "<%d bytes>" % v.size()
	return s if s.length() < 80 else s.substr(0, 77) + "..."

func report(line: String) -> void:
	lines += 1
	if lines <= MAX_LINES:
		out(line)

func out(line: String) -> void:
	print("[JeczzDiff] ", line)
	if out_file:
		out_file.store_line(line)
		out_file.flush()
