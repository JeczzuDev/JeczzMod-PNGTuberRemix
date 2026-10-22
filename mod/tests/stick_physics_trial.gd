extends Node
## One-shot trial (test installs only, needs mods/SANDBOX): on the loaded test
## model, adds "+ Secondary: Controller (Left) X" (Last active) to the root
## sprite's Position and Rotation and to the head's Rotation, in every state;
## then moves a simulated left stick and logs how much the physics react
## (root stretch, children's rotational drag); then saves the test model.
## Names come from the command line:
##   -- --jz-root=<sprite name> --jz-head=<sprite name> --jz-watch=<name>,<name>...

const P := "[JeczzTrial] "
const CTRL_LEFT_X := 20
const LAST_ACTIVE := 2

var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--jz-") and "=" in a:
			args[a.get_slice("=", 0).trim_prefix("--jz-")] = a.get_slice("=", 1)
	if not args.has("root"):
		return
	await get_tree().create_timer(4.0).timeout
	var base := OS.get_executable_path().get_base_dir()
	if not FileAccess.file_exists(base + "/mods/SANDBOX") or not Global.save_path.begins_with(base):
		print(P, "ABORT: not a sandboxed test install or model outside it: ", Global.save_path)
		return

	var by_name := {}
	for sp in get_tree().get_nodes_in_group("Sprites"):
		by_name[sp.sprite_name] = sp
	var root = by_name.get(args.root)
	var head = by_name.get(args.get("head", ""))
	if root == null:
		print(P, "ABORT: no sprite named ", args.root)
		return

	set_all_states(root, {"jz_follow_type_b": CTRL_LEFT_X, "jz_follow_type2_b": CTRL_LEFT_X, "jz_follow_blend": LAST_ACTIVE})
	if head != null:
		set_all_states(head, {"jz_follow_type2_b": CTRL_LEFT_X, "jz_follow_blend": LAST_ACTIVE})
	print(P, "configured root '", args.root, "'", " and head '", args.get("head"), "'" if head != null else " (head not found)")

	var watch := [root] + Array(args.get("watch", "").split(",", false)).map(func(n): return by_name.get(n)).filter(func(s): return s != null)
	await measure("still (no input)", watch, [], 0.6)
	await measure("stick right", watch, ["ControllerRight"], 0.4)
	await measure("release", watch, [], 0.6)
	await measure("stick left", watch, ["ControllerLeft"], 0.4)
	await measure("release", watch, [], 0.6)
	await measure("stick quick flicks", watch, ["ControllerRight", "", "ControllerLeft", "", "ControllerRight", ""], 0.9)

	SaveAndLoad.save_file(Global.save_path)
	print(P, "saved test model: ", Global.save_path)
	print(P, "DONE")

func set_all_states(sp, values: Dictionary) -> void:
	for k in values:
		sp.sprite_data[k] = values[k]
		for st in sp.states:
			if st is Dictionary and not st.is_empty():
				st[k] = values[k]

## Holds each action in `sequence` for an equal share of `seconds` ("" = none)
## and logs, per watched sprite, the root follow offset range and the physics
## peaks (rotational drag on %Modifier, stretch on %Modifier scale).
func measure(label: String, watch: Array, sequence: Array, seconds: float) -> void:
	var peaks := {}
	for sp in watch:
		peaks[sp] = {"x_min": INF, "x_max": -INF, "rot": 0.0, "stretch": 0.0}
	var steps : Array = sequence if not sequence.is_empty() else [""]
	for action in steps:
		for a in ["ControllerLeft", "ControllerRight"]:
			Input.action_release(a)
		if action != "":
			Input.action_press(action, 1.0)
		var t := 0.0
		while t < seconds / steps.size():
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			for sp in watch:
				var pk : Dictionary = peaks[sp]
				var m1 : Node2D = sp.get_node("%Modifier1")
				var m : Node2D = sp.get_node("%Modifier")
				pk.x_min = min(pk.x_min, m1.position.x)
				pk.x_max = max(pk.x_max, m1.position.x)
				pk.rot = max(pk.rot, abs(rad_to_deg(m.rotation)))
				pk.stretch = max(pk.stretch, abs(m.scale.y - 1.0))
	for a in ["ControllerLeft", "ControllerRight"]:
		Input.action_release(a)
	var parts := []
	for sp in watch:
		var pk : Dictionary = peaks[sp]
		parts.append("%s: follow x %.1f..%.1f, drag rot %.2f deg, stretch %.3f" % [sp.sprite_name, pk.x_min, pk.x_max, pk.rot, pk.stretch])
	print(P, label, " -> ", " | ".join(parts))
