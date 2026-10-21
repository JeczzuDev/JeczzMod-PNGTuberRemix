extends RefCounted
## Constants and helpers shared by the JeczzMod follow extensions.
## Follow types are the game's selector indices (sprite_data "follow_type*").

const NONE := 15
const MOUSE := 0
const MOUSE_X := 18
const MOUSE_Y := 19
const MOUSE_TYPES := [MOUSE, MOUSE_X, MOUSE_Y]
const CONTROLLER_TYPES := [1, 2, 10, 11, 12]
const KEYBOARD_TYPES := [3, 4, 5, 6, 7, 8]

## Secondary source per selector, stored per state in sprite_data like the
## vanilla keys. Missing (old models) means NONE.
const SEC_KEYS := {
	"follow_type": "jz_follow_type_b",
	"follow_type2": "jz_follow_type2_b",
	"follow_type3": "jz_follow_type3_b",
}
const BLEND_KEY := "jz_follow_blend"
const BLEND_SUM := 0
const BLEND_PRIORITY := 1
const BLEND_LAST_ACTIVE := 2
## Used when a sprite has no BLEND_KEY yet.
const BLEND_DEFAULT := BLEND_LAST_ACTIVE

## Stick/key strength that counts as using a controller/keyboard source.
const DEADZONE := 0.15
## Cursor movement (px per physics frame) that counts as using the mouse.
const MOUSE_MOVE_PX := 1.5
## The mouse stays "in use" this long after the cursor stops.
const MOUSE_IDLE_SEC := 0.5
## Mouse movement per physics frame (px) that maps to ~76% of a velocity range.
const VEL_SPEED_PX := 20.0

static func sec_type(actor, key: String) -> int:
	var v = actor.get_value(key)
	if v == null or not is_supported_secondary(int(v)):
		return NONE
	return int(v)

static func blend_mode(actor) -> int:
	var v = actor.get_value(BLEND_KEY)
	if v == null or not int(v) in [BLEND_SUM, BLEND_PRIORITY, BLEND_LAST_ACTIVE]:
		return BLEND_DEFAULT
	return int(v)

## 1 if source `t` is in use, 0 if not, -1 if it can't be told (UDP, custom).
## `key` is the sprite_data key holding `t`; `mouse` is a MouseActivity that
## the caller updates every frame with axis_mask(t).
static func source_activity(comp, t: int, key: String, mouse: MouseActivity) -> int:
	if t in MOUSE_TYPES:
		return 1 if mouse.is_active() else 0
	if t in CONTROLLER_TYPES or t in KEYBOARD_TYPES:
		return 1 if input_axis(comp, t, key).length() > DEADZONE else 0
	return -1

static func is_supported_secondary(t: int) -> bool:
	return t in MOUSE_TYPES or t in CONTROLLER_TYPES or t in KEYBOARD_TYPES

## Which pre-swap axes a source drives.
static func axis_mask(t: int) -> Vector2:
	match t:
		MOUSE_X: return Vector2(1, 0)
		MOUSE_Y: return Vector2(0, 1)
	return Vector2.ONE

## Controller / keyboard axis for a follow type. `comp` is a follow component
## (has axis_* filled by update_controller_inputs()); `key` is the sprite_data
## key holding `t`, which the game's keyboard helper reads back.
static func input_axis(comp, t: int, key: String) -> Vector2:
	match t:
		1: return comp.axis_left
		2: return comp.axis_right
		10: return comp.axis_shoulderl
		11: return comp.axis_shoulderr
		12: return comp.axis_lr_3
	if t in KEYBOARD_TYPES:
		return GlobalCalculations.some_keyboard_calc_wasd(key, comp.actor)
	return Vector2.ZERO

## Swap/Invert as the game applies them after computing a pre-swap target.
static func to_final(v: Vector2, swap_x: bool, swap_y: bool, invert_x: bool, invert_y: bool) -> Vector2:
	var f := Vector2(v.y if swap_x else v.x, v.x if swap_y else v.y)
	if invert_x:
		f.x *= -1
	if invert_y:
		f.y *= -1
	return f

## Which final axes are driven by the pre-swap `mask`.
static func mask_to_final(mask: Vector2, swap_x: bool, swap_y: bool) -> Vector2:
	return Vector2(mask.y if swap_x else mask.x, mask.x if swap_y else mask.y)

## Pre-swap per-axis ranges (x = low, y = high) to final-space ranges.
static func ranges_to_final(rx: Vector2, ry: Vector2, swap_x: bool, swap_y: bool, invert_x: bool, invert_y: bool) -> Array:
	var fx := ry if swap_x else rx
	var fy := rx if swap_y else ry
	if invert_x:
		fx = Vector2(- fx.y, - fx.x)
	if invert_y:
		fy = Vector2(- fy.y, - fy.x)
	return [fx, fy]

static func sorted_range(a: float, b: float) -> Vector2:
	return Vector2(min(a, b), max(a, b))

## Tracks recent real cursor movement on the axes of `mask`.
class MouseActivity:
	var last := Vector2.INF
	var idle := INF

	func update(mask: Vector2, delta: float) -> void:
		var m := Vector2(DisplayServer.mouse_get_position())
		if last != Vector2.INF and ((m - last) * mask).length() > MOUSE_MOVE_PX:
			idle = 0.0
		else:
			idle += delta
		last = m

	func is_active() -> bool:
		return idle < MOUSE_IDLE_SEC
