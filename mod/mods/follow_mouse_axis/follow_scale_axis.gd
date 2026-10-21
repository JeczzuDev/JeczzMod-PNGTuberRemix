extends "res://Scripts/Objects/ObjectComponents/follow_scale.gd"
## Adds "Mouse X" (18) / "Mouse Y" (19) to the scale Follow Option.
## Same math as "Mouse" (0), but only one scale axis follows: Mouse X scales
## horizontally from the horizontal mouse position, Mouse Y scales vertically
## from the vertical one. Swap/Invert X/Y still apply, so Swap can cross them.
## With follow_mouse_velocity, the chosen axis' mouse speed moves the scale from
## min (still) to max (fast) (vanilla's velocity scale never receives a velocity).

const MOUSE_X := 18
const MOUSE_Y := 19
## Mouse movement per physics frame (px) that maps to ~76% of the range.
const VEL_SPEED_PX := 20.0

var last_axis_coords : Vector2 = Vector2.ZERO
var axis_vel_norm : float = 0.0

func update_scale(delta: float) -> void:
	var follow_type3: int = actor.get_value("follow_type3")
	if follow_type3 != MOUSE_X and follow_type3 != MOUSE_Y:
		super(delta)
		return

	var use_y : bool = follow_type3 == MOUSE_Y
	var main_marker = Global.main.get_node("%Marker")
	var invert_x: bool = actor.get_value("scale_invert_x")
	var invert_y: bool = actor.get_value("scale_invert_y")
	var swap_x: bool = actor.get_value("scale_swap_x")
	var swap_y: bool = actor.get_value("scale_swap_y")

	mouse_coords = %FollowPosition.follow_calculation()
	var axis_val : Vector2

	if actor.get_value("follow_mouse_velocity"):
		var moved := mouse_coords - last_axis_coords
		var speed : float = tanh(abs(moved.y if use_y else moved.x) / VEL_SPEED_PX)
		axis_vel_norm = lerp(axis_vel_norm, speed, 0.5)
		axis_val = Vector2(
			- lerp(float(actor.get_value("scale_x_min")), float(actor.get_value("scale_x_max")), axis_vel_norm),
			- lerp(float(actor.get_value("scale_y_min")), float(actor.get_value("scale_y_max")), axis_vel_norm))
	else:
		axis_val = follow_mouse_scale(mouse_coords, main_marker)
	last_axis_coords = mouse_coords

	var x_val: float = axis_val.x if not use_y else 0.0
	var y_val: float = axis_val.y if use_y else 0.0

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
