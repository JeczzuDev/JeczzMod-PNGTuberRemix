extends "res://Scripts/Objects/ObjectComponents/follow_scale.gd"
## Scale follow extensions (JeczzMod):
## - "Mouse X" (18) / "Mouse Y" (19): same math as "Mouse" (0), but Mouse X only
##   scales horizontally from the horizontal mouse position and Mouse Y only
##   vertically from the vertical one. With follow_mouse_velocity, that axis'
##   mouse speed moves the scale from min (still) to max (fast).
## - "Controller (Left/Right) X/Y" (20..23): the game's controller scale for that
##   stick axis only; the other scale axis stays at 1.
## - Secondary source (jz_follow_type3_b) layered on the vanilla result:
##   Sum adds its offset from rest (clamped to the configured range); Priority
##   and Last active ease between primary and secondary (see source_picker.gd).
## Values named *_val are the game's pre-swap scale values (scale = 1 - final).

const Shared := preload("res://mods/follow_ext/follow_shared.gd")
const SourcePicker := preload("res://mods/follow_ext/source_picker.gd")
const SEC_KEY := "jz_follow_type3_b"

var last_axis_coords : Vector2 = Vector2.ZERO
var vel_norm : Vector2 = Vector2.ZERO

var sec_on : bool = false
var sec_val : Vector2 = Vector2.ZERO
var sec_weight : float = 0.0
var last_primary : Vector2 = Vector2.ONE
var last_written : Vector2 = Vector2.ONE
var picker := SourcePicker.new()

func update_scale(delta: float) -> void:
	mouse_coords = %FollowPosition.follow_calculation()
	if actor.get_value("follow_mouse_velocity"):
		var moved := mouse_coords - last_axis_coords
		vel_norm = vel_norm.lerp(Vector2(tanh(abs(moved.x) / Shared.VEL_SPEED_PX), tanh(abs(moved.y) / Shared.VEL_SPEED_PX)), 0.5)
	last_axis_coords = mouse_coords

	var sec := Shared.sec_type(actor, SEC_KEY)
	if sec == Shared.NONE:
		sec_on = false
		_update_primary(delta)
		return

	if sec_on and modifier.scale.is_equal_approx(last_written):
		modifier.scale = last_primary
	else:
		sec_val = _scl_rest(sec)
		sec_weight = 0.0
		picker.reset()
	_update_primary(delta)
	last_primary = modifier.scale

	var t : float = clamp(actor.get_value("mouse_delay") * delta * 60.0, 0.0, 1.0)
	var mask := Shared.axis_mask(sec)
	var use_sec := picker.update(self, actor.get_value("follow_type3"), "follow_type3", sec, SEC_KEY, delta)
	sec_val = sec_val.lerp(_scl_raw(sec), t)

	var swap_x: bool = actor.get_value("scale_swap_x")
	var swap_y: bool = actor.get_value("scale_swap_y")
	var invert_x: bool = actor.get_value("scale_invert_x")
	var invert_y: bool = actor.get_value("scale_invert_y")
	var out : Vector2

	if Shared.blend_mode(actor) != Shared.BLEND_SUM:
		sec_weight = lerp(sec_weight, 1.0 if use_sec else 0.0, t)
		var sec_scale := Vector2.ONE - Shared.to_final(sec_val, swap_x, swap_y, invert_x, invert_y)
		var w := Shared.mask_to_final(mask, swap_x, swap_y) * sec_weight
		out = Vector2(lerp(last_primary.x, sec_scale.x, w.x), lerp(last_primary.y, sec_scale.y, w.y))
	else:
		var offset := - Shared.to_final((sec_val - _scl_rest(sec)) * mask, swap_x, swap_y, invert_x, invert_y)
		# Value range of one source: -lerp(max, min, n) for n in 0..1.
		var rx := Shared.sorted_range(- float(actor.get_value("scale_x_max")), - float(actor.get_value("scale_x_min")))
		var ry := Shared.sorted_range(- float(actor.get_value("scale_y_max")), - float(actor.get_value("scale_y_min")))
		var r := Shared.ranges_to_final(rx, ry, swap_x, swap_y, invert_x, invert_y)
		var sum := last_primary + offset
		out = Vector2(clamp(sum.x, 1.0 - r[0].y, 1.0 - r[0].x), clamp(sum.y, 1.0 - r[1].y, 1.0 - r[1].x))

	modifier.scale.x = GlobalCalculations.is_nan_or_inf(out.x)
	modifier.scale.y = GlobalCalculations.is_nan_or_inf(out.y)
	last_written = modifier.scale
	sec_on = true

## Vanilla update_scale(), plus Mouse X/Y and single stick axes (the other
## scale axis stays at 1).
func _update_primary(delta: float) -> void:
	var follow_type3: int = actor.get_value("follow_type3")
	var axis_val : Vector2
	if follow_type3 == Shared.MOUSE_X or follow_type3 == Shared.MOUSE_Y:
		axis_val = _mouse_val(follow_type3)
	elif follow_type3 in Shared.MOD_CONTROLLER_TYPES:
		axis_val = follow_controller_scale(Shared.input_axis(self, follow_type3, "follow_type3"))
	else:
		super.update_scale(delta)
		return

	var invert_x: bool = actor.get_value("scale_invert_x")
	var invert_y: bool = actor.get_value("scale_invert_y")
	var swap_x: bool = actor.get_value("scale_swap_x")
	var swap_y: bool = actor.get_value("scale_swap_y")

	var mask := Shared.axis_mask(follow_type3)
	var x_val: float = axis_val.x * mask.x
	var y_val: float = axis_val.y * mask.y

	# Tail of the original update_scale(), unchanged.
	target_scale = target_scale.lerp(Vector2(x_val, y_val), 0.15)

	var sw_x = y_val if swap_x else x_val
	var sw_y = x_val if swap_y else y_val

	if invert_x:
		sw_x *= -1
	if invert_y:
		sw_y *= -1

	final_target = Vector2(sw_x, sw_y)

	var target_sx: float = 1.0 - final_target.x
	var target_sy: float = 1.0 - final_target.y
	var t: float = clamp(actor.get_value("mouse_delay") * delta * 60.0, 0.0, 1.0)
	modifier.scale.x = GlobalCalculations.is_nan_or_inf(lerp(modifier.scale.x, target_sx, t))
	modifier.scale.y = GlobalCalculations.is_nan_or_inf(lerp(modifier.scale.y, target_sy, t))

## Pre-swap values from the mouse (both axes; callers pick the one they use).
func _mouse_val(kind: int) -> Vector2:
	if actor.get_value("follow_mouse_velocity"):
		var n := vel_norm
		if kind == Shared.MOUSE:
			n = Vector2(vel_norm.x, vel_norm.x)
		return Vector2(
			- lerp(float(actor.get_value("scale_x_min")), float(actor.get_value("scale_x_max")), n.x),
			- lerp(float(actor.get_value("scale_y_min")), float(actor.get_value("scale_y_max")), n.y))
	return follow_mouse_scale(mouse_coords, Global.main.get_node("%Marker"))

## Pre-swap values a secondary source asks for (before smoothing).
func _scl_raw(sec: int) -> Vector2:
	if sec in Shared.MOUSE_TYPES:
		return _mouse_val(sec)
	return follow_controller_scale(Shared.input_axis(self, sec, SEC_KEY))

## What a secondary source gives with no input (stick centered, no key, cursor
## on the sprite and still).
func _scl_rest(sec: int) -> Vector2:
	if sec in Shared.MOUSE_TYPES:
		if actor.get_value("follow_mouse_velocity"):
			return Vector2(- float(actor.get_value("scale_x_min")), - float(actor.get_value("scale_y_min")))
		return follow_mouse_scale(Vector2.ZERO, Global.main.get_node("%Marker"))
	return follow_controller_scale(Vector2.ZERO)
