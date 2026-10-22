extends Node
## Self-test for the follow extensions (Mouse X / Mouse Y, secondary source).
## Test installs only (registered as a second autoload in the test override.cfg).
## Does not move the real cursor: mouse results are checked against the mouse
## coordinates the component used in that same physics frame, and controller
## sticks are simulated with Input.action_press.

const P := "[JeczzTest] "
const POS_SUB := "res://mods/follow_ext/follow_position_ext.gd"
const ROT_SUB := "res://mods/follow_ext/follow_rotation_ext.gd"
const SCL_SUB := "res://mods/follow_ext/follow_scale_ext.gd"
const STICK_ACTIONS := ["ControllerLeft", "ControllerRight", "ControllerUp", "ControllerDown",
		"ControllerOne", "ControllerTwo", "ControllerThree", "ControllerFour"]
const BIG := 100000.0
const ROT := 0.5
const SCL := 0.3

var fails := 0

func _ready() -> void:
	await get_tree().create_timer(4.0).timeout
	var sprites := get_tree().get_nodes_in_group("Sprites")
	print(P, "sprites=", sprites.size())

	# 1. Script swaps
	var ok_swaps := 0
	for sp in sprites:
		var fp = sp.get_node_or_null("FollowPosition")
		var fr = sp.get_node_or_null("FollowRotation")
		var fs = sp.get_node_or_null("FollowScale")
		if fp and fr and fs and fp.get_script().resource_path == POS_SUB and fr.get_script().resource_path == ROT_SUB and fs.get_script().resource_path == SCL_SUB:
			ok_swaps += 1
	check("all sprites swapped (%d/%d)" % [ok_swaps, sprites.size()], ok_swaps == sprites.size() and ok_swaps > 0)

	# 2. Selector items
	var selectors := {}
	for n in ["FollowOption", "FollowOption2", "FollowOption3"]:
		var found := get_tree().root.find_children(n, "OptionButton", true, false)
		check("selector %s found once" % n, found.size() == 1)
		if found.size() == 1:
			var ob : OptionButton = found[0]
			selectors[n] = ob
			var extra := range(18, ob.item_count).map(func(i): return "[%d]=%s" % [i, ob.get_item_text(i)])
			check("%s has 26 items: %s" % [n, ", ".join(extra)], ob.item_count == 26 and range(18, 26).all(func(i): return ob.get_item_id(i) == i))
	if sprites.is_empty() or selectors.size() < 3:
		finish()
		return

	var sp = sprites[0]
	for s in sprites:
		if s.is_visible_in_tree() and s.rest_mode != 5:
			sp = s
			break
	var fp = sp.get_node("FollowPosition")
	var fr = sp.get_node("FollowRotation")
	var fs = sp.get_node("FollowScale")
	print(P, "test sprite=", sp.name, " static_view=", Global.static_view, " visible=", sp.is_visible_in_tree(), " rest_mode=", sp.rest_mode)

	# 3. UI path: select sprite, pick Mouse X/Y in each selector like a user would
	Global.held_sprites = [sp]
	Global.reinfo.emit()
	await get_tree().process_frame
	var ui := {"FollowOption": ["follow_type", 18], "FollowOption2": ["follow_type2", 19], "FollowOption3": ["follow_type3", 18]}
	for n in ui:
		var ob : OptionButton = selectors[n]
		ob.select(ui[n][1])
		ob.item_selected.emit(ui[n][1])
		check("UI %s stored %s=%d (got %s)" % [n, ui[n][0], ui[n][1], sp.sprite_data[ui[n][0]]], sp.sprite_data[ui[n][0]] == ui[n][1])
	Global.reinfo.emit()
	await get_tree().process_frame
	for n in ui:
		check("UI %s shows index %d after reinfo (got %d)" % [n, ui[n][1], selectors[n].selected], selectors[n].selected == ui[n][1])

	# 4. Math. Instant response (mouse_delay 1), no clamping for position.
	print(P, "physics_ticks=", Engine.physics_ticks_per_second, " -> 60 for the test")
	Engine.physics_ticks_per_second = 60
	var d : Dictionary = sp.sprite_data
	var setup := {"pos_x_min": -BIG, "pos_x_max": BIG, "pos_y_min": -BIG, "pos_y_max": BIG,
			"rot_min": -ROT, "rot_max": ROT, "scale_x_min": -SCL, "scale_x_max": SCL,
			"scale_y_min": -SCL, "scale_y_max": SCL, "mouse_delay": 1.0, "snap_pos": false,
			"follow_mouse_velocity": false, "pos_swap_x": false, "pos_swap_y": false,
			"pos_invert_x": false, "pos_invert_y": false, "scale_swap_x": false, "scale_swap_y": false,
			"scale_invert_x": false, "scale_invert_y": false, "animate_to_mouse": false,
			"shared_movement": true}
	for k in setup:
		d[k] = setup[k]

	var van := await sample(sp, fp, fr, fs, 0, 0, 0)
	check("vanilla pos == used mouse coords (test model sanity) %s vs %s" % [van.pos, van.pos_in], van.pos.is_equal_approx(van.pos_in))
	check("vanilla rot matches X formula", near_angle(van.rot, exp_rot(van.rot_in.x, 0)))

	var mx := await sample(sp, fp, fr, fs, 18, 18, 18)
	print(P, "mouseX=", mx)
	check("pos Mouse X: x == mouse x", near(mx.pos.x, mx.pos_in.x))
	check("pos Mouse X: y == 0", near(mx.pos.y, 0.0))
	check("rot Mouse X matches X formula", near_angle(mx.rot, exp_rot(mx.rot_in.x, 0)))
	check("scale Mouse X: x matches formula", near(mx.scl.x, exp_scl(mx.scl_in.x, 0)))
	check("scale Mouse X: y == 1", near(mx.scl.y, 1.0))

	var my := await sample(sp, fp, fr, fs, 19, 19, 19)
	print(P, "mouseY=", my)
	check("pos Mouse Y: y == mouse y", near(my.pos.y, my.pos_in.y))
	check("pos Mouse Y: x == 0", near(my.pos.x, 0.0))
	check("rot Mouse Y matches Y formula", near_angle(my.rot, exp_rot(my.rot_in.y, 1)))
	check("scale Mouse Y: y matches formula", near(my.scl.y, exp_scl(my.scl_in.y, 1)))
	check("scale Mouse Y: x == 1", near(my.scl.x, 1.0))

	# 5. Swap crosses axes
	d.pos_swap_x = true
	d.pos_swap_y = true
	d.scale_swap_x = true
	d.scale_swap_y = true
	var sw := await sample(sp, fp, fr, fs, 18, 18, 18)
	check("pos Mouse X + swap: y == mouse x, x == 0", near(sw.pos.y, sw.pos_in.x) and near(sw.pos.x, 0.0))
	check("scale Mouse X + swap: y follows X, x == 1", near(sw.scl.y, exp_scl(sw.scl_in.x, 0)) and near(sw.scl.x, 1.0))
	for k in ["pos_swap_x", "pos_swap_y", "scale_swap_x", "scale_swap_y"]:
		d[k] = false

	# 6. Velocity mode with whatever the cursor does: finite values, unused axis at rest
	d.follow_mouse_velocity = true
	d.pos_x_min = -50.0
	d.pos_x_max = 50.0
	d.pos_y_min = -50.0
	d.pos_y_max = 50.0
	d.look_at_mouse_pos = 50.0
	d.look_at_mouse_pos_y = 50.0
	var vel := await sample(sp, fp, fr, fs, 18, 19, 18, 30)
	print(P, "velocity=", vel)
	check("velocity values finite", is_finite(vel.pos.x) and is_finite(vel.pos.y) and is_finite(vel.rot) and is_finite(vel.scl.x) and is_finite(vel.scl.y))
	check("velocity Mouse X: pos y == 0, scale y == 1", near(vel.pos.y, 0.0) and near(vel.scl.y, 1.0))
	d.follow_mouse_velocity = false

	# 7. Secondary UI: rows, storing per state, undo/redo
	var rows := get_tree().root.find_children("JzSecondaryRow*", "HBoxContainer", true, false)
	var blend_rows := get_tree().root.find_children("JzBlendRow", "HBoxContainer", true, false)
	check("3 secondary rows + 1 combine row (got %d + %d)" % [rows.size(), blend_rows.size()], rows.size() == 3 and blend_rows.size() == 1)
	if rows.size() != 3 or blend_rows.size() != 1:
		finish()
		return
	var sec_ob : OptionButton = rows[0].get_child(1)
	var blend_ob : OptionButton = blend_rows[0].get_child(1)
	# Make the test sprite look like an old model (no mod keys), in memory only.
	for st in sp.states + [d]:
		if st is Dictionary:
			for k in ["jz_follow_type_b", "jz_follow_type2_b", "jz_follow_type3_b", "jz_follow_blend"]:
				st.erase(k)
	Global.reinfo.emit()
	await get_tree().process_frame
	check("secondary shows None for an old model (got id %d)" % sec_ob.get_selected_id(), sec_ob.get_selected_id() == 15)
	check("combine shows Last active by default (got id %d)" % blend_ob.get_selected_id(), blend_ob.get_selected_id() == 2)
	Global.held_sprites = [sp]
	Global.reinfo.emit()
	await get_tree().process_frame
	var idx := sec_ob.get_item_index(1)
	sec_ob.select(idx)
	sec_ob.item_selected.emit(idx)
	check("UI stored jz_follow_type_b=1 (got %s)" % d.get("jz_follow_type_b"), d.get("jz_follow_type_b") == 1)
	var all_states : bool = sp.states.all(func(st): return st.is_empty() or st.has("jz_follow_type_b"))
	check("key present in every state", all_states)
	UndoRedoManager.undo()
	await get_tree().process_frame
	check("undo -> 15 and UI shows None (got %s / %d)" % [d.get("jz_follow_type_b"), sec_ob.get_selected_id()], d.get("jz_follow_type_b") == 15 and sec_ob.get_selected_id() == 15)
	UndoRedoManager.redo()
	await get_tree().process_frame
	check("redo -> 1 and UI shows it (got %s / %d)" % [d.get("jz_follow_type_b"), sec_ob.get_selected_id()], d.get("jz_follow_type_b") == 1 and sec_ob.get_selected_id() == 1)
	var bidx := blend_ob.get_item_index(1)
	blend_ob.select(bidx)
	blend_ob.item_selected.emit(bidx)
	check("UI stored jz_follow_blend=1", d.get("jz_follow_blend") == 1)

	# 8. Layering with simulated sticks: primary = right stick, secondary = left stick
	var layer_setup := {"pos_x_min": -50.0, "pos_x_max": 50.0, "pos_y_min": -50.0, "pos_y_max": 50.0, "snap_scale": false, "snap_rot": false}
	for k in layer_setup:
		d[k] = layer_setup[k]
	set_secondary(d, 1, 0)
	release_sticks()
	var s := await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("sum, nothing pressed", s, Vector2(0, 0), 0.0, Vector2(1.3, 1.3))
	Input.action_press("ControllerRight", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("sum, secondary right", s, Vector2(50, 0), 0.5, Vector2(0.7, 1.3))
	Input.action_press("ControllerFour", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("sum, primary left + secondary right", s, Vector2(0, 0), 0.001, Vector2(0.7, 1.3))
	var s2 := await sample(sp, fp, fr, fs, 2, 2, 2, 30)
	check("sum stays stable over 30 frames (no drift)", s2.pos.is_equal_approx(s.pos) and near_angle(s2.rot, s.rot) and s2.scl.is_equal_approx(s.scl))
	fp.reset_modifier()
	fr.reset_modifier()
	fs.reset_modifier()
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("sum after an external reset", s, Vector2(0, 0), 0.001, Vector2(0.7, 1.3))
	set_secondary(d, 1, 1)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("priority, both pressed -> secondary", s, Vector2(50, 0), 0.5, Vector2(0.7, 1.3))
	Input.action_release("ControllerRight")
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("priority, secondary released -> primary", s, Vector2(-50, 0), -0.499, Vector2(0.7, 1.3))
	Input.action_press("ControllerRight", 1.0)
	set_secondary(d, 15, 0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("secondary None -> vanilla primary only", s, Vector2(-50, 0), -0.499, Vector2(0.7, 1.3))
	release_sticks()

	# 8b. Last active: only the most recently used source counts
	set_secondary(d, 1, 2)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("last active, nothing pressed", s, Vector2(0, 0), 0.0, Vector2(1.3, 1.3))
	Input.action_press("ControllerFour", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("last active, primary used -> primary", s, Vector2(-50, 0), -0.499, Vector2(0.7, 1.3))
	Input.action_press("ControllerRight", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("last active, secondary used while primary held -> secondary only", s, Vector2(50, 0), 0.5, Vector2(0.7, 1.3))
	Input.action_release("ControllerRight")
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check_layer("last active, secondary released, primary still held -> primary", s, Vector2(-50, 0), -0.499, Vector2(0.7, 1.3))
	release_sticks()

	# 8c. Last active with the mouse as primary: a released stick keeps the sprite
	# (its rest) instead of jumping back to the mouse, until the mouse moves.
	s = await sample(sp, fp, fr, fs, 0, 0, 0)
	var mouse_pos : Vector2 = s.pos
	Input.action_press("ControllerRight", 1.0)
	s = await sample(sp, fp, fr, fs, 0, 0, 0)
	check("last active, mouse primary + stick -> stick only (pos %s)" % s.pos, s.pos.is_equal_approx(Vector2(50, 0)))
	Input.action_release("ControllerRight")
	s = await sample(sp, fp, fr, fs, 0, 0, 0, 12)
	if fp.picker.primary_mouse.is_active():
		print(P, "SKIP last active stick-rest check: the cursor moved during the test")
	else:
		check("last active, stick released + still mouse -> stick rest (pos %s, mouse alone was %s)" % [s.pos, mouse_pos], s.pos.is_equal_approx(Vector2.ZERO))
	release_sticks()

	# 8d. One-sided range (x 0..36, like the user's sprite): a full stick reaches
	# 36 like the mouse (vanilla stopped at (0 + 36) / 2 = 18); Position Snap
	# keeps a released secondary stick where it was.
	d.pos_x_min = 0.0
	d.pos_x_max = 36.0
	d.pos_y_min = -10.0
	d.pos_y_max = 10.0
	set_secondary(d, 15, 2)
	Input.action_press("ControllerTwo", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check("one-sided range, primary stick right reaches 36 (pos %s)" % s.pos, s.pos.is_equal_approx(Vector2(36, 0)))
	release_sticks()
	set_secondary(d, 1, 2)
	Input.action_press("ControllerRight", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check("one-sided range, secondary stick right reaches 36 (pos %s)" % s.pos, s.pos.is_equal_approx(Vector2(36, 0)))
	Input.action_press("ControllerDown", 1.0)
	Input.action_release("ControllerRight")
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check("one-sided range, secondary stick down reaches 10 (pos %s)" % s.pos, s.pos.is_equal_approx(Vector2(0, 10)))
	release_sticks()
	s = await sample(sp, fp, fr, fs, 2, 2, 2)  # back to center before turning Snap on
	d.snap_pos = true
	Input.action_press("ControllerRight", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	Input.action_release("ControllerRight")
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check("Position Snap keeps a released secondary stick in place (pos %s)" % s.pos, s.pos.is_equal_approx(Vector2(36, 0)))
	d.snap_pos = false
	s = await sample(sp, fp, fr, fs, 2, 2, 2)
	check("without Position Snap it returns to center (pos %s)" % s.pos, s.pos.is_equal_approx(Vector2(0, 0)))
	d.pos_x_min = -50.0
	d.pos_x_max = 50.0
	d.pos_y_min = -50.0
	d.pos_y_max = 50.0
	release_sticks()

	# 9. Mouse X as secondary with swap: the mouse X offset lands on Y
	set_secondary(d, 18, 0)
	d.pos_swap_x = true
	d.pos_swap_y = true
	var m := await sample(sp, fp, fr, fs, 2, 2, 2)
	check("sum, secondary Mouse X + swap: y == clamp(mouse x), x == 0 (%s, in %s)" % [m.pos, m.pos_in], near(m.pos.y, clamp(m.pos_in.x, -50.0, 50.0)) and near(m.pos.x, 0.0))
	d.pos_swap_x = false
	d.pos_swap_y = false
	set_secondary(d, 15, 0)

	# 10. Single stick axes (20..23) as primary: [type, action, pos, rot, scale]
	release_sticks()
	var axis_cases := [
		[20, "ControllerDown", Vector2(0, 0), 0.0, Vector2(1.3, 1.0)],
		[20, "ControllerRight", Vector2(50, 0), 0.5, Vector2(0.7, 1.0)],
		[21, "ControllerRight", Vector2(0, 0), 0.0, Vector2(1.0, 1.3)],
		[21, "ControllerDown", Vector2(0, 50), 0.5, Vector2(1.0, 0.7)],
		[21, "ControllerUp", Vector2(0, -50), -0.499, Vector2(1.0, 0.7)],
		[22, "ControllerTwo", Vector2(50, 0), 0.5, Vector2(0.7, 1.0)],
		[22, "ControllerRight", Vector2(0, 0), 0.0, Vector2(1.3, 1.0)],
		[23, "ControllerThree", Vector2(0, 50), 0.5, Vector2(1.0, 0.7)],
	]
	for c in axis_cases:
		Input.action_press(c[1], 1.0)
		s = await sample(sp, fp, fr, fs, c[0], c[0], c[0])
		check_layer("stick axis %d + %s" % [c[0], c[1]], s, c[2], c[3], c[4])
		Input.action_release(c[1])

	# 11. Stick axes as secondary: listed in the UI; with Last active, moving the
	# stick on the other axis doesn't take over from the mouse.
	check("secondary list has stick axes 20..23", range(20, 24).all(func(i): return sec_ob.get_item_index(i) >= 0))
	set_secondary(d, 21, 2)
	s = await sample(sp, fp, fr, fs, 0, 0, 0)
	Input.action_press("ControllerRight", 1.0)
	s = await sample(sp, fp, fr, fs, 0, 0, 0)
	check("last active + Left Y secondary: horizontal stick doesn't take over", not fp.picker.use_secondary)
	Input.action_release("ControllerRight")
	Input.action_press("ControllerDown", 1.0)
	s = await sample(sp, fp, fr, fs, 0, 0, 0)
	check("last active + Left Y secondary: vertical stick takes over Y only (pos %s, in %s)" % [s.pos, s.pos_in],
		fp.picker.use_secondary and near(s.pos.y, 50.0) and near(s.pos.x, clamp(s.pos_in.x, -50.0 * abs(s.pos_in.normalized().x), 50.0 * abs(s.pos_in.normalized().x))))
	release_sticks()
	set_secondary(d, 15, 0)

	# 12. D-pad and A/B/X/Y are split from the sticks. Real joypad button events
	# (parse_input_event) go through the InputMap like a physical controller.
	var has_button := func(action: String, index: int) -> bool:
		return InputMap.action_get_events(action).any(func(e): return e is InputEventJoypadButton and e.button_index == index)
	var has_motion := func(action: String) -> bool:
		return InputMap.action_get_events(action).any(func(e): return e is InputEventJoypadMotion)
	check("InputMap: A moved from ControllerThree to JzFaceDown, stick axis kept",
		not has_button.call("ControllerThree", 0) and has_button.call("JzFaceDown", 0) and has_motion.call("ControllerThree"))
	check("InputMap: D-pad up moved from ControllerUp to JzDpadUp, stick axis kept",
		not has_button.call("ControllerUp", 11) and has_button.call("JzDpadUp", 11) and has_motion.call("ControllerUp"))
	var button_cases := [
		# [follow type, button index, pos, rot, scale]
		[2, 0, Vector2(0, 0), 0.0, Vector2(1.3, 1.3)],      # Controller (Right) ignores A
		[1, 11, Vector2(0, 0), 0.0, Vector2(1.3, 1.3)],     # Controller (Left) ignores D-pad up
		[25, 0, Vector2(0, 50), 0.0, Vector2(1.3, 0.7)],    # Face buttons: A = down
		[25, 1, Vector2(50, 0), 0.5, Vector2(0.7, 1.3)],    # Face buttons: B = right
		[24, 11, Vector2(0, -50), 0.0, Vector2(1.3, 0.7)],  # D-pad up
		[24, 14, Vector2(50, 0), 0.5, Vector2(0.7, 1.3)],   # D-pad right
	]
	for c in button_cases:
		press_button(c[1], true)
		s = await sample(sp, fp, fr, fs, c[0], c[0], c[0])
		check_layer("type %d + joypad button %d" % [c[0], c[1]], s, c[2], c[3], c[4])
		press_button(c[1], false)
	set_secondary(d, 2, 2)
	s = await sample(sp, fp, fr, fs, 0, 0, 0)
	press_button(0, true)
	s = await sample(sp, fp, fr, fs, 0, 0, 0)
	check("last active + Controller (Right) secondary: pressing A doesn't take over", not fp.picker.use_secondary)
	press_button(0, false)
	check("secondary list has D-pad and Face buttons", sec_ob.get_item_index(24) >= 0 and sec_ob.get_item_index(25) >= 0)

	# 13. Taking over doesn't dip toward the secondary's rest first (smooth
	# mouse_delay, like real sprites): both sources push to the same spot.
	d.mouse_delay = 0.1
	set_secondary(d, 1, 2)
	Input.action_press("ControllerTwo", 1.0)
	s = await sample(sp, fp, fr, fs, 2, 2, 2, 120)
	var settled : Vector2 = s.pos
	Input.action_press("ControllerRight", 1.0)
	var min_x := INF
	var min_rot := INF
	var max_scl_x := -INF
	for i in 60:
		await get_tree().physics_frame
		min_x = min(min_x, fp.modifier.position.x)
		min_rot = min(min_rot, fr.modifier.rotation)
		max_scl_x = max(max_scl_x, fs.modifier.scale.x)
	check("no dip when the secondary takes over: pos x settled %.2f, min %.2f; rot min %.3f; scale x max %.3f" % [settled.x, min_x, min_rot, max_scl_x],
		settled.x > 49.0 and min_x > settled.x - 0.5 and min_rot > 0.49 and max_scl_x < 0.71)
	release_sticks()
	d.mouse_delay = 1.0
	set_secondary(d, 15, 0)
	finish()

func press_button(index: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

func set_secondary(d: Dictionary, sec: int, blend: int) -> void:
	d.jz_follow_type_b = sec
	d.jz_follow_type2_b = sec
	d.jz_follow_type3_b = sec
	d.jz_follow_blend = blend

func release_sticks() -> void:
	for a in STICK_ACTIONS:
		Input.action_release(a)

func check_layer(label: String, s: Dictionary, pos: Vector2, rot: float, scl: Vector2) -> void:
	check("%s: pos %s rot %.3f scale %s" % [label, s.pos, s.rot, s.scl],
		s.pos.is_equal_approx(pos) and near_angle(s.rot, rot) and abs(s.scl.x - scl.x) < 0.001 and abs(s.scl.y - scl.y) < 0.001)

## Sets follow types, runs physics frames and returns the outputs of the last
## frame together with the mouse coords each component used in that frame.
func sample(sp, fp, fr, fs, t1: int, t2: int, t3: int, frames := 6) -> Dictionary:
	sp.sprite_data.follow_type = t1
	sp.sprite_data.follow_type2 = t2
	sp.sprite_data.follow_type3 = t3
	var pos_in : Vector2
	for i in frames:
		# Resumes before nodes process: FollowPosition will use this value.
		pos_in = fp.mouse_coords
		await get_tree().physics_frame
	return {
		pos = fp.modifier.position, pos_in = pos_in,
		rot = fr.modifier.rotation, rot_in = fr.mouse_coords,
		scl = fs.modifier.scale, scl_in = fs.mouse_coords,
	}

func screen() -> Vector2:
	return Vector2(Global.main.get_node("%Marker").get_screen_size())

func exp_rot(c: float, axis: int) -> float:
	var n = clamp(c / (screen()[axis] / 2), -1.0, 1.0)
	return clamp(lerp_angle(-ROT, ROT, max((n + 1) / 2, 0.0)), -ROT, ROT)

func exp_scl(c: float, axis: int) -> float:
	var center : float = screen()[axis] * 0.5
	var norm = clamp(abs(abs(c) - center) / center, 0.0, 1.0)
	return 1.0 + lerp(SCL, -SCL, norm)

func near(a: float, b: float) -> bool:
	return abs(a - b) < 0.001

func check(label: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print(P, "PASS " if ok else "FAIL ", label)

func finish() -> void:
	print(P, "DONE fails=", fails)

func near_angle(a: float, b: float) -> bool:
	return abs(angle_difference(a, b)) < 0.001
