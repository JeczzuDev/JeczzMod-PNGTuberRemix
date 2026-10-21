extends "res://Scripts/Objects/ObjectComponents/follow_component.gd"
## Adds "Mouse X" (18) / "Mouse Y" (19) to the position Follow Option.
## Same math as "Mouse" (0), but only the chosen mouse axis drives the sprite;
## the other axis eases back to 0. Swap/Invert X/Y still apply afterwards.

const MOUSE_X := 18
const MOUSE_Y := 19

var axis_last_dist : Vector2 = Vector2.ZERO

func update_position(dir: Vector2, dist: float, _delta: float) -> void:
	var follow_type: int = actor.get_value("follow_type")
	if follow_type != MOUSE_X and follow_type != MOUSE_Y:
		super(dir, dist, _delta)
		return

	var mask := Vector2(1, 0) if follow_type == MOUSE_X else Vector2(0, 1)
	var axis_coords := mouse_coords * mask
	var axis_dir := axis_coords.normalized() if axis_coords.length() > 0.0001 else Vector2.ZERO

	if actor.get_value("follow_mouse_velocity"):
		# Like process_follow(), but the speed only comes from the chosen axis.
		var axis_vel := Vector2(tanh(mouse_delta.x), tanh(mouse_delta.y)) * mask
		axis_last_dist.x = lerp(axis_last_dist.x, - axis_vel.x * actor.get_value("look_at_mouse_pos"), 0.5)
		axis_last_dist.y = lerp(axis_last_dist.y, - axis_vel.y * actor.get_value("look_at_mouse_pos_y"), 0.5)
		var m_dist := axis_last_dist * mask
		# Vector2.ZERO makes follow_position_calculations() jump to the full range.
		if m_dist == Vector2.ZERO:
			m_dist = mask * 0.000001
		follow_position_calculations(axis_dir, m_dist)
	else:
		var d : float = abs(axis_coords.x + axis_coords.y)
		follow_position_calculations(axis_dir, Vector2(d, d) if d > 0.0 else mask * 0.000001)

	# snap_pos leaves an axis untouched when its dir is 0; ease the unused one home.
	var delay = actor.get_value("mouse_delay")
	if follow_type == MOUSE_X:
		target_pos.y = lerp(target_pos.y, 0.0, delay)
	else:
		target_pos.x = lerp(target_pos.x, 0.0, delay)

	_apply_target(_delta)

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
