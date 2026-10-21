extends Node
## Read-only diagnostic (test installs only). Writes to mods/_tests/diag.log:
## - controller setup (action deadzones, connected joypads),
## - follow settings of every sprite that uses a secondary source, and how far
##   each source can reach with them (full stick vs. mouse far away),
## - once per second while a stick is moved: the strongest stick input of that
##   second (raw axes and what the game reads) and the selected sprite's
##   position values.

const P := "[JeczzDiag] "
const STICKS := {
	"left": ["ControllerLeft", "ControllerRight", "ControllerUp", "ControllerDown"],
	"right": ["ControllerFour", "ControllerTwo", "ControllerOne", "ControllerThree"],
}

var log_file : FileAccess
var acc_time := 0.0
var max_raw := {}
var max_game := {}
var peak := {}

func _ready() -> void:
	# res:// is read-only in an exported app; write next to the exe instead.
	log_file = FileAccess.open(OS.get_executable_path().get_base_dir() + "/mods/_tests/diag.log", FileAccess.WRITE)
	if log_file == null:
		push_error(P + "can't write diag.log: " + str(FileAccess.get_open_error()))
		return
	await get_tree().create_timer(4.0).timeout
	out("PNGTube Remix " + str(ProjectSettings.get_setting("application/config/version")) + " / " + Time.get_datetime_string_from_system())
	for stick in STICKS:
		for a in STICKS[stick]:
			out("action %s deadzone=%s" % [a, InputMap.action_get_deadzone(a) if InputMap.has_action(a) else "missing"])
	for j in Input.get_connected_joypads():
		out("joypad %d '%s'" % [j, Input.get_joy_name(j)])
	if Input.get_connected_joypads().is_empty():
		out("no joypad connected")

	for sp in get_tree().get_nodes_in_group("Sprites"):
		var d : Dictionary = sp.sprite_data
		var secs := [d.get("jz_follow_type_b"), d.get("jz_follow_type2_b"), d.get("jz_follow_type3_b")]
		if secs.all(func(v): return v == null or v == 15):
			continue
		out("---- sprite '%s' types=%s secondary=%s blend=%s" % [d.get("sprite_name", sp.name), [d.follow_type, d.follow_type2, d.follow_type3], secs, d.get("jz_follow_blend")])
		for k in ["pos_x_min", "pos_x_max", "pos_y_min", "pos_y_max", "rot_min", "rot_max", "scale_x_min", "scale_x_max", "scale_y_min", "scale_y_max", "mouse_delay", "snap_pos", "pos_swap_x", "pos_swap_y", "pos_invert_x", "pos_invert_y", "follow_mouse_velocity", "shared_movement", "use_object_pos"]:
			out("   %s = %s" % [k, sp.get_value(k)])
		var fp = sp.get_node("FollowPosition")
		var far := Vector2(1.0e6, 1.0e6)
		out("   reach stick: right=%s left=%s down=%s up=%s diag=%s" % [fp._pos_raw(Vector2(1, 0)), fp._pos_raw(Vector2(-1, 0)), fp._pos_raw(Vector2(0, 1)), fp._pos_raw(Vector2(0, -1)), fp._pos_raw(Vector2(1, 1).normalized())])
		out("   reach mouse: right=%s left=%s down=%s up=%s diag=%s" % [fp._pos_raw(Vector2(1, 0), far), fp._pos_raw(Vector2(-1, 0), far), fp._pos_raw(Vector2(0, 1), far), fp._pos_raw(Vector2(0, -1), far), fp._pos_raw(Vector2(1, 1).normalized(), far)])
	out("---- live (one line per second while a stick moves; select a sprite to see its values)")

func _physics_process(delta: float) -> void:
	if log_file == null:
		return
	for j in Input.get_connected_joypads():
		for axis in 4:
			var v := Input.get_joy_axis(j, axis)
			var k := "j%d.a%d" % [j, axis]
			if abs(v) > abs(max_raw.get(k, 0.0)):
				max_raw[k] = v
	for stick in STICKS:
		var a : Array = STICKS[stick]
		var v := Input.get_vector(a[0], a[1], a[2], a[3])
		if v.length() > max_game.get(stick, Vector2.ZERO).length():
			max_game[stick] = v
	var sp = Global.held_sprites[0] if not Global.held_sprites.is_empty() else null
	if sp != null and is_instance_valid(sp) and sp.has_node("FollowPosition"):
		var fp = sp.get_node("FollowPosition")
		var pos : Vector2 = fp.modifier.position
		if pos.length() > peak.get("pos", Vector2.ZERO).length():
			peak = {"pos": pos, "use_secondary": fp.picker.use_secondary if "picker" in fp else null,
				"sec_target": fp.sec_target if "sec_target" in fp else null, "sprite": sp.sprite_data.get("sprite_name", sp.name)}

	acc_time += delta
	if acc_time < 1.0:
		return
	acc_time = 0.0
	var moved := max_game.values().any(func(v): return v.length() > 0.05)
	if moved:
		var game := {}
		for k in max_game:
			game[k] = "%s len=%.2f" % [max_game[k], max_game[k].length()]
		out("stick raw=%s game=%s sprite_peak=%s" % [max_raw, game, peak])
	max_raw = {}
	max_game = {}
	peak = {}

func out(line: String) -> void:
	print(P, line)
	log_file.store_line(line)
	log_file.flush()
