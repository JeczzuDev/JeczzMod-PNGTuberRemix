extends Node
## Read-only model inspector (test installs only). Reads a .pngRemix file as data
## (never loads it into the app) and writes mods/_tests/inspect.log with the
## sprite tree and each sprite's Follow Movement and physics settings (state 0,
## plus which keys differ in other states).
## Run: "PNGTube Remix.console.exe" -- --jz-inspect=<path to .pngRemix>

const FOLLOW_NAMES := {0: "Mouse", 1: "Controller L", 2: "Controller R", 3: "WASD W/S", 4: "WASD A/D",
	5: "WASD", 6: "Arrows U/D", 7: "Arrows L/R", 8: "Arrows", 10: "R1+L1", 11: "R2+L2", 12: "R3+L3",
	15: "None", 17: "UDP", 18: "Mouse X", 19: "Mouse Y", 20: "Ctrl L X", 21: "Ctrl L Y",
	22: "Ctrl R X", 23: "Ctrl R Y", 24: "D-pad", 25: "Face buttons"}
const FOLLOW_KEYS := ["follow_type", "follow_type2", "follow_type3", "jz_follow_type_b", "jz_follow_type2_b", "jz_follow_type3_b", "jz_follow_blend",
	"pos_x_min", "pos_x_max", "pos_y_min", "pos_y_max", "rot_min", "rot_max", "scale_x_min", "scale_x_max", "scale_y_min", "scale_y_max",
	"mouse_delay", "follow_mouse_velocity", "snap_pos", "pos_swap_x", "pos_swap_y", "pos_invert_x", "pos_invert_y", "use_object_pos"]
const PHYSICS_KEYS := ["physics", "dragSpeed", "stretchAmount", "rdragStr", "rLimitMin", "rLimitMax", "phys_eff",
	"xAmp", "xFrq", "yAmp", "yFrq", "rot_frq", "should_rotate", "ignore_bounce", "pause_movement", "static_obj"]

var out_file : FileAccess

func _ready() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--jz-inspect="):
			path = a.trim_prefix("--jz-inspect=").trim_prefix("\"").trim_suffix("\"")
	if path == "":
		return
	out_file = FileAccess.open(OS.get_executable_path().get_base_dir() + "/mods/_tests/inspect.log", FileAccess.WRITE)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out("can't open %s: %s" % [path, FileAccess.get_open_error()])
		return
	var data = f.get_var(true)
	f.close()
	if not data is Dictionary or not data.has("sprites_array"):
		out("not a .pngRemix save: " + path)
		return
	out("model version=%s sprites=%d states=%d" % [data.get("version"), data.sprites_array.size(), data.settings_dict.get("states", []).size() if data.settings_dict.get("states") is Array else -1])

	var by_id := {}
	for sp in data.sprites_array:
		by_id[sp.sprite_id] = sp
	var children := {}
	for sp in data.sprites_array:
		children.get_or_add(sp.parent_id, []).append(sp)
	for sp in data.sprites_array:
		if not by_id.has(sp.parent_id):
			dump_sprite(sp, children, 0)
	out("DONE")

func dump_sprite(sp: Dictionary, children: Dictionary, depth: int) -> void:
	var st : Dictionary = sp.states[0] if not sp.states.is_empty() else {}
	var pad := "  ".repeat(depth)
	out("%s- %s  [id %s, %s, rest_mode %s]" % [pad, sp.sprite_name, sp.sprite_id, sp.sprite_type, sp.get("rest_mode")])
	var f := []
	for k in ["follow_type", "follow_type2", "follow_type3"]:
		var v = st.get(k)
		var sec = st.get("jz_" + k + "_b")
		f.append("%s=%s%s" % [k.replace("follow_type", "ft"), FOLLOW_NAMES.get(v, v), " +%s" % FOLLOW_NAMES.get(sec, sec) if sec != null and sec != 15 else ""])
	out("%s    follow: %s" % [pad, ", ".join(f)])
	if [st.get("follow_type"), st.get("follow_type2"), st.get("follow_type3")].any(func(v): return v != null and v != 15):
		out("%s    follow cfg: %s" % [pad, pick(st, FOLLOW_KEYS.slice(3))])
	out("%s    physics: %s" % [pad, pick(st, PHYSICS_KEYS)])
	var diff := []
	for i in range(1, sp.states.size()):
		for k in FOLLOW_KEYS + PHYSICS_KEYS:
			if sp.states[i] is Dictionary and sp.states[i].has(k) and sp.states[i][k] != st.get(k):
				diff.append("state%d.%s=%s" % [i, k, sp.states[i][k]])
	if not diff.is_empty():
		out("%s    other states differ: %s" % [pad, ", ".join(diff.slice(0, 12)) + (" ..." if diff.size() > 12 else "")])
	for c in children.get(sp.sprite_id, []):
		dump_sprite(c, children, depth + 1)

func pick(st: Dictionary, keys: Array) -> String:
	var parts := []
	for k in keys:
		if st.has(k):
			parts.append("%s=%s" % [k, st[k]])
	return ", ".join(parts)

func out(line: String) -> void:
	print("[JeczzInspect] ", line)
	if out_file:
		out_file.store_line(line)
		out_file.flush()
