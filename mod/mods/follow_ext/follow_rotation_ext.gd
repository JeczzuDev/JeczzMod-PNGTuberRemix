extends "res://Scripts/Objects/ObjectComponents/follow_rotation.gd"
## Rotation follow extensions (JeczzMod):
## - "Mouse X" (18) / "Mouse Y" (19): Mouse X is the same math as "Mouse" (0);
##   Mouse Y uses the vertical mouse position (top -> rot_min, bottom -> rot_max).
##   With follow_mouse_velocity, that axis' mouse speed drives the rotation
##   (vanilla's velocity rotation never receives a velocity, so it stays at 0).
## - "Controller (Left/Right) X/Y" (20..23): X is the game's controller rotation;
##   Y rotates with the vertical stick axis (up -> rot_min, down -> rot_max).
## - Secondary source (jz_follow_type2_b) layered on the vanilla result:
##   Sum adds its offset from rest (clamped to rot_min..rot_max); Priority and
##   Last active ease between primary and secondary (see source_picker.gd).

const Shared := preload("res://mods/follow_ext/follow_shared.gd")
const SourcePicker := preload("res://mods/follow_ext/source_picker.gd")
const SEC_KEY := "jz_follow_type2_b"

var last_axis_coords : Vector2 = Vector2.ZERO
var vel_norm : Vector2 = Vector2.ZERO

var sec_on : bool = false
var sec_rot : float = 0.0
var sec_out : float = 0.0
var sec_weight : float = 0.0
var last_primary : float = 0.0
var last_written : float = 0.0
var picker := SourcePicker.new()

func update_rotation(delta: float) -> void:
	mouse_coords = %FollowPosition.follow_calculation()
	if actor.get_value("follow_mouse_velocity"):
		var moved := mouse_coords - last_axis_coords
		vel_norm = vel_norm.lerp(Vector2(tanh(moved.x / Shared.VEL_SPEED_PX), tanh(moved.y / Shared.VEL_SPEED_PX)), 0.5)
	last_axis_coords = mouse_coords

	var sec := Shared.sec_type(actor, SEC_KEY)
	if sec == Shared.NONE:
		sec_on = false
		_update_primary(delta)
		return

	if sec_on and is_equal_approx(modifier.rotation, last_written):
		modifier.rotation = last_primary
	else:
		sec_rot = _rot_rest(sec)
		sec_weight = 0.0
		picker.reset()
	_update_primary(delta)
	last_primary = modifier.rotation

	var t : float = clamp(actor.get_value("mouse_delay") * delta * 60.0, 0.0, 1.0)
	var use_sec := picker.update(self, actor.get_value("follow_type2"), "follow_type2", sec, SEC_KEY, delta)
	sec_rot = lerp_angle(sec_rot, _rot_raw(sec), t)
	var out : float

	if Shared.blend_mode(actor) != Shared.BLEND_SUM:
		# While the secondary isn't driving, its output follows the sprite, so
		# taking over starts from the sprite's current angle instead of its rest.
		if sec_weight < Shared.WEIGHT_IDLE:
			sec_out = last_primary
		sec_out = lerp_angle(sec_out, _rot_raw(sec), t)
		sec_weight = lerp(sec_weight, 1.0 if use_sec else 0.0, t)
		out = lerp_angle(last_primary, sec_out, sec_weight)
	else:
		out = _clamp_to_range(last_primary + angle_difference(_rot_rest(sec), sec_rot))

	modifier.rotation = out
	last_written = out
	sec_on = true

## Vanilla update_rotation(), plus Mouse X/Y and single stick axes.
func _update_primary(delta: float) -> void:
	var follow_type2 = actor.get_value("follow_type2")
	var target_rot
	if follow_type2 == Shared.MOUSE_X or follow_type2 == Shared.MOUSE_Y:
		target_rot = _mouse_rotation(follow_type2)
	elif follow_type2 in Shared.MOD_CONTROLLER_TYPES:
		target_rot = _input_rotation(follow_type2, "follow_type2")
	else:
		super.update_rotation(delta)
		return

	var t = actor.get_value("mouse_delay") * delta * 60.0
	t = clamp(t, 0.0, 1.0)
	modifier.rotation = lerp_angle(modifier.rotation, target_rot, t)

## Rotation target from the mouse on the axis of `kind` (Mouse uses X).
func _mouse_rotation(kind: int) -> float:
	var use_y : bool = kind == Shared.MOUSE_Y
	var normalized_mouse : float
	if actor.get_value("follow_mouse_velocity"):
		normalized_mouse = vel_norm.y if use_y else vel_norm.x
	else:
		var screen_size = Global.main.get_node("%Marker").get_screen_size()
		var coord : float = mouse_coords.y if use_y else mouse_coords.x
		var half : float = (screen_size.y if use_y else screen_size.x) / 2
		normalized_mouse = clamp(coord / half, -1.0, 1.0)
	return _norm_to_rotation(normalized_mouse)

func _norm_to_rotation(normalized_mouse: float) -> float:
	var rotation_factor = lerp_angle(float(actor.get_value("rot_min")), float(actor.get_value("rot_max")), max((normalized_mouse + 1) / 2, 0.0))
	return GlobalCalculations.is_nan_or_inf(clamp_rotations(rotation_factor))

## Rotation from a stick/keys, like the game's controller rotation (which uses
## the horizontal axis); the Y options use the vertical one instead (up ->
## rot_min, down -> rot_max).
func _input_rotation(t: int, key: String) -> float:
	var axis := Shared.input_axis(self, t, key)
	return follow_controller_rotation(Vector2(axis.y if t in Shared.Y_AXIS_TYPES else axis.x, 0))

## Rotation target a secondary source asks for (before smoothing).
func _rot_raw(sec: int) -> float:
	if sec in Shared.MOUSE_TYPES:
		return _mouse_rotation(sec)
	return _input_rotation(sec, SEC_KEY)

## What a secondary source gives with no input (stick centered, no key, cursor
## on the sprite and still).
func _rot_rest(sec: int) -> float:
	if sec in Shared.MOUSE_TYPES:
		return _norm_to_rotation(0.0)
	return follow_controller_rotation(Vector2.ZERO)

## Clamps to rot_min..rot_max, picking the equivalent angle closest to the range.
func _clamp_to_range(a: float) -> float:
	var r := Shared.sorted_range(float(actor.get_value("rot_min")), float(actor.get_value("rot_max")))
	if r.y - r.x >= TAU:
		return a
	var center := (r.x + r.y) * 0.5
	return clamp(center + wrapf(a - center, - PI, PI), r.x, r.y)
