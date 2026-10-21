extends RefCounted
## Decides each frame whether a follow component's secondary source drives the
## sprite, for the "Secondary priority" and "Last active" Combine modes.
##
## Last active: the source that was used most recently drives the sprite and the
## other one is ignored until it's used. A source that starts being used takes
## over; if the driving source goes idle while the other is still in use, the
## other takes over; when both are idle, the last one used keeps driving.

const Shared := preload("res://mods/follow_ext/follow_shared.gd")

var primary_mouse := Shared.MouseActivity.new()
var secondary_mouse := Shared.MouseActivity.new()
var use_secondary : bool = false
var _was_p : bool = false
var _was_s : bool = false

func reset() -> void:
	use_secondary = false
	_was_p = false
	_was_s = false

## Call every frame while a secondary is set (keeps the mouse trackers current).
## `pkey`/`skey` are the sprite_data keys holding `ptype`/`sec`.
func update(comp, ptype: int, pkey: String, sec: int, skey: String, delta: float) -> bool:
	primary_mouse.update(Shared.axis_mask(ptype), delta)
	secondary_mouse.update(Shared.axis_mask(sec), delta)
	var s : bool = Shared.source_activity(comp, sec, skey, secondary_mouse) == 1
	var p_activity := Shared.source_activity(comp, ptype, pkey, primary_mouse)

	if Shared.blend_mode(comp.actor) == Shared.BLEND_PRIORITY:
		use_secondary = s
	else:
		# A primary whose use can't be detected (UDP) gets the sprite back when
		# the secondary is released, like Priority.
		var p : bool = (not s) if p_activity < 0 else p_activity == 1
		if s and not _was_s:
			use_secondary = true
		elif p and not _was_p:
			use_secondary = false
		elif use_secondary and not s and p:
			use_secondary = false
		elif not use_secondary and not p and s:
			use_secondary = true
		_was_p = p
	_was_s = s
	return use_secondary
