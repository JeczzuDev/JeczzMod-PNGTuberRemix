extends "res://Scripts/Objects/ObjectComponents/follow_rotation.gd"
## Adds "Mouse X" (18) / "Mouse Y" (19) to the rotation Follow Option.
## Mouse X uses the same math as "Mouse" (0); Mouse Y does it with the vertical
## mouse position (top -> rot_min, bottom -> rot_max).
## With follow_mouse_velocity, the chosen axis' mouse speed drives the rotation
## (vanilla's velocity rotation never receives a velocity, so it stays at 0).

const MOUSE_X := 18
const MOUSE_Y := 19
## Mouse movement per physics frame (px) that maps to ~76% of the range.
const VEL_SPEED_PX := 20.0

var last_axis_coords : Vector2 = Vector2.ZERO
var axis_vel_norm : float = 0.0

func update_rotation(delta: float) -> void:
	var follow_type2 = actor.get_value("follow_type2")
	if follow_type2 != MOUSE_X and follow_type2 != MOUSE_Y:
		super(delta)
		return

	var use_y : bool = follow_type2 == MOUSE_Y
	mouse_coords = %FollowPosition.follow_calculation()
	var normalized_mouse : float

	if actor.get_value("follow_mouse_velocity"):
		var moved := mouse_coords - last_axis_coords
		var speed : float = tanh((moved.y if use_y else moved.x) / VEL_SPEED_PX)
		axis_vel_norm = lerp(axis_vel_norm, speed, 0.5)
		normalized_mouse = axis_vel_norm
	else:
		var screen_size = Global.main.get_node("%Marker").get_screen_size()
		var coord : float = mouse_coords.y if use_y else mouse_coords.x
		var half : float = (screen_size.y if use_y else screen_size.x) / 2
		normalized_mouse = clamp(coord / half, -1.0, 1.0)
	last_axis_coords = mouse_coords

	var rotation_factor = lerp_angle(float(actor.get_value("rot_min")), float(actor.get_value("rot_max")), max((normalized_mouse + 1) / 2, 0.0))
	var target_rot = GlobalCalculations.is_nan_or_inf(clamp_rotations(rotation_factor))

	var t = actor.get_value("mouse_delay") * delta * 60.0
	t = clamp(t, 0.0, 1.0)
	modifier.rotation = lerp_angle(modifier.rotation, target_rot, t)
