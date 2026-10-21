extends "res://Scripts/Objects/ObjectComponents/follow_component.gd"
## Position follow extensions (JeczzMod):
## - "Mouse X" (18) / "Mouse Y" (19) for the Follow Option selector: same math as
##   "Mouse" (0) but only the chosen mouse axis drives the sprite.
## - Secondary source (jz_follow_type_b) layered on the vanilla result:
##   Sum adds its offset from rest (clamped to the configured range); Priority
##   and Last active ease between primary and secondary (see source_picker.gd).
## - Sticks and keys reach each side's configured limit, like the mouse does.
##   Vanilla uses (|min| + max) / 2 as their reach, so with a one-sided or
##   asymmetric range (e.g. min 0, max 36) a full stick only got halfway.

const Shared := preload("res://mods/follow_ext/follow_shared.gd")
const SourcePicker := preload("res://mods/follow_ext/source_picker.gd")
const SEC_KEY := "jz_follow_type_b"
const BIG := 1.0e9
## m_dist for sticks/keys: like a mouse far away in the stick's direction, so the
## result is the deflection times that side's limit.
const STICK_REACH := Vector2(BIG, BIG)

var axis_last_dist : Vector2 = Vector2.ZERO

var sec_on : bool = false
var sec_target : Vector2 = Vector2.ZERO
var sec_weight : float = 0.0
var last_primary : Vector2 = Vector2.ZERO
var last_written : Vector2 = Vector2.ZERO
var picker := SourcePicker.new()

func update_position(dir: Vector2, dist: float, _delta: float) -> void:
	if actor.get_value("follow_mouse_velocity"):
		# Like process_follow(), but per axis (only that axis' speed counts).
		var axis_vel := Vector2(tanh(mouse_delta.x), tanh(mouse_delta.y))
		axis_last_dist.x = lerp(axis_last_dist.x, - axis_vel.x * actor.get_value("look_at_mouse_pos"), 0.5)
		axis_last_dist.y = lerp(axis_last_dist.y, - axis_vel.y * actor.get_value("look_at_mouse_pos_y"), 0.5)

	var sec := Shared.sec_type(actor, SEC_KEY)
	if sec == Shared.NONE or not _follow_moves_position():
		sec_on = false
		_update_primary(dir, dist, _delta)
		return

	# Undo last frame's blend so the vanilla smoothing continues from its own
	# value; if something else moved the modifier (reset/rest), start over.
	if sec_on and modifier.position.is_equal_approx(last_written):
		modifier.position = last_primary
	else:
		sec_target = Vector2.ZERO
		sec_weight = 0.0
		picker.reset()
	_update_primary(dir, dist, _delta)
	last_primary = modifier.position

	var delay = actor.get_value("mouse_delay")
	var mask := Shared.axis_mask(sec)
	var use_sec := picker.update(self, actor.get_value("follow_type"), "follow_type", sec, SEC_KEY, _delta)
	var raw := _secondary_raw(sec) * mask
	if actor.get_value("snap_pos") and not sec in Shared.MOUSE_TYPES:
		# Position Snap: keep the last position on an axis the stick/keys released,
		# as follow_position_calculations() does for a primary.
		var axis := Shared.input_axis(self, sec, SEC_KEY)
		if axis.x == 0:
			raw.x = sec_target.x
		if axis.y == 0:
			raw.y = sec_target.y
	sec_target = sec_target.lerp(raw, delay)

	var swap_x: bool = actor.get_value("pos_swap_x")
	var swap_y: bool = actor.get_value("pos_swap_y")
	var invert_x: bool = actor.get_value("pos_invert_x")
	var invert_y: bool = actor.get_value("pos_invert_y")
	var sec_final := Shared.to_final(sec_target, swap_x, swap_y, invert_x, invert_y)
	var out : Vector2

	if Shared.blend_mode(actor) != Shared.BLEND_SUM:
		sec_weight = lerp(sec_weight, 1.0 if use_sec else 0.0, delay)
		var w := Shared.mask_to_final(mask, swap_x, swap_y) * sec_weight
		out = Vector2(lerp(last_primary.x, sec_final.x, w.x), lerp(last_primary.y, sec_final.y, w.y))
	else:
		# Position rest is 0, so the secondary target is already its offset.
		var lo := _pos_raw(Vector2(-1, -1), Vector2(BIG, BIG))
		var hi := _pos_raw(Vector2(1, 1), Vector2(BIG, BIG))
		var r := Shared.ranges_to_final(Shared.sorted_range(lo.x, hi.x), Shared.sorted_range(lo.y, hi.y), swap_x, swap_y, invert_x, invert_y)
		var sum := last_primary + sec_final
		out = Vector2(clamp(sum.x, r[0].x, r[0].y), clamp(sum.y, r[1].x, r[1].y))

	modifier.position = out
	last_written = out
	sec_on = true

## Vanilla update_position(), plus Mouse X / Mouse Y and full stick/key reach.
func _update_primary(dir: Vector2, dist: float, _delta: float) -> void:
	var follow_type: int = actor.get_value("follow_type")
	if follow_type in Shared.CONTROLLER_TYPES or follow_type in Shared.KEYBOARD_TYPES:
		follow_position_calculations(Shared.input_axis(self, follow_type, "follow_type"), STICK_REACH)
		_apply_target(_delta)
		return
	if follow_type != Shared.MOUSE_X and follow_type != Shared.MOUSE_Y:
		super.update_position(dir, dist, _delta)
		return

	var m := _mouse_input(follow_type)
	follow_position_calculations(m[0], m[1])

	# snap_pos leaves an axis untouched when its dir is 0; ease the unused one home.
	var delay = actor.get_value("mouse_delay")
	if follow_type == Shared.MOUSE_X:
		target_pos.y = lerp(target_pos.y, 0.0, delay)
	else:
		target_pos.x = lerp(target_pos.x, 0.0, delay)

	_apply_target(_delta)

## [dir, m_dist] for follow_position_calculations() from the mouse, limited to
## the axis of `kind` (Mouse / Mouse X / Mouse Y).
func _mouse_input(kind: int) -> Array:
	var mask := Shared.axis_mask(kind)
	var coords := mouse_coords * mask
	var d := coords.normalized() if coords.length() > 0.0001 else Vector2.ZERO
	var m_dist : Vector2
	if actor.get_value("follow_mouse_velocity"):
		m_dist = last_dist if kind == Shared.MOUSE else axis_last_dist * mask
	else:
		var l := coords.length()
		m_dist = Vector2(l, l)
	# Vector2.ZERO makes follow_position_calculations() jump to the full range.
	if m_dist == Vector2.ZERO:
		m_dist = mask * 0.000001
	return [d, m_dist]

## Pre-swap position target a secondary source asks for (before smoothing).
func _secondary_raw(sec: int) -> Vector2:
	if sec in Shared.MOUSE_TYPES:
		var m := _mouse_input(sec)
		return _pos_raw(m[0], m[1])
	return _pos_raw(Shared.input_axis(self, sec, SEC_KEY), STICK_REACH)

## The clamping part of follow_position_calculations(), without smoothing.
func _pos_raw(dir: Vector2, m_dist: Vector2 = Vector2.ZERO) -> Vector2:
	var dist = dir

	var min_x = actor.get_value("pos_x_min")
	var max_x = actor.get_value("pos_x_max")

	var min_y = actor.get_value("pos_y_min")
	var max_y = actor.get_value("pos_y_max")

	if m_dist != Vector2.ZERO:
		dist = m_dist
	else:
		dist = Vector2(abs(min_x) + max_x, abs(min_y) + max_y) * 0.5

	var clamped_x_min = 0.0
	var clamped_y_min = 0.0

	if min_x != 0 && max_x == 0:
		if dir.x <= 0:
			clamped_x_min = dir.x * min(dist.x, abs(min_x))

	elif min_x == 0 && max_x != 0:
		if dir.x >= 0:
			clamped_x_min = dir.x * min(dist.x, max_x)
	else:
		var clm_x = clamp(dir.x * dist.x, - abs(dir.x * max_x), abs(dir.x * min_x))
		clamped_x_min = clm_x


	if min_y != 0 && max_y == 0:
		if dir.y >= 0:
			clamped_y_min = dir.y * clamp(dist.y, 0, abs(min_y))

	elif min_y == 0 && max_y != 0:
		if dir.y <= 0:
			clamped_y_min = dir.y * clamp(dist.y, 0, max_y)

	else:
		var clm_y = clamp(dir.y * dist.y, - abs(dir.y * max_y), abs(dir.y * min_y))
		clamped_y_min = clm_y

	return Vector2(clamped_x_min, clamped_y_min)

## False when the game itself keeps this sprite's position out of Follow Movement.
func _follow_moves_position() -> bool:
	if actor.sprite_type == "Sprite2D" && actor.get_value("animate_to_mouse") && actor.get_value("non_animated_sheet") && !actor.get_value("animate_to_mouse_track_pos"):
		return false
	if actor.sprite_type == "Mesh" && mesh != null && is_instance_valid(mesh) && !actor.get_value("move_with_follow"):
		return false
	return true

## Tail of the original update_position(), unchanged.
func _apply_target(_delta: float) -> void:
	var invert_x: bool = actor.get_value("pos_invert_x")
	var invert_y: bool = actor.get_value("pos_invert_y")
	var swap_x: bool = actor.get_value("pos_swap_x")
	var swap_y: bool = actor.get_value("pos_swap_y")

	var sw_x = target_pos.y if swap_x else target_pos.x
	var sw_y = target_pos.x if swap_y else target_pos.y

	if invert_x:
		sw_x *= -1
	if invert_y:
		sw_y *= -1

	final_target = Vector2(sw_x, sw_y)

	if actor.sprite_type == "Sprite2D" && actor.get_value("animate_to_mouse") && actor.get_value("non_animated_sheet"):
		update_sprite_animation(current_dir, current_dist, _delta)
		if !actor.get_value("animate_to_mouse_track_pos"):
			modifier.position = modifier.position.lerp(Vector2.ZERO, actor.get_value("mouse_delay"))
			return
	if actor.sprite_type == "Mesh" && mesh != null && is_instance_valid(mesh):
		if !actor.get_value("move_with_follow"):
			modifier.position = modifier.position.lerp(Vector2.ZERO, actor.get_value("mouse_delay"))
			return

	modifier.position = final_target
