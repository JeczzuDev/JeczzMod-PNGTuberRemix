extends Node
## Adds a "+ Secondary" selector under each Follow Option selector of the
## Movement panel, plus one "Combine" selector, and stores their values per
## state with undo/redo, the same way whyisntthisworking.gd does for vanilla.

const Shared := preload("res://mods/follow_ext/follow_shared.gd")
const ROW_PREFIX := "JzSecondaryRow"
const BLEND_ROW := "JzBlendRow"

## Primary selector name -> sprite_data key of its secondary.
const ROWS := {
	"FollowOption": "jz_follow_type_b",
	"FollowOption2": "jz_follow_type2_b",
	"FollowOption3": "jz_follow_type3_b",
}
## [follow type, label(, suffix)]; type -1 is a separator. Labels starting with
## TR_ are the game's own translation keys.
const SOURCES := [
	[15, "TR_UDP_ITEM_NONE"],
	[0, "TR_MOUSE"], [18, "TR_MOUSE", " X"], [19, "TR_MOUSE", " Y"],
	[-1, ""],
	[1, "TR_CONTROLLER_LEFT"], [2, "TR_CONTROLLER_RIGHT"],
	[20, "TR_CONTROLLER_LEFT", " X"], [21, "TR_CONTROLLER_LEFT", " Y"],
	[22, "TR_CONTROLLER_RIGHT", " X"], [23, "TR_CONTROLLER_RIGHT", " Y"],
	[10, "R1 + L1"], [11, "R2 + L2"], [12, "R3 + L3"],
	[-1, ""],
	[3, "TR_WASD_WS"], [4, "TR_WASD_AD"], [5, "TR_WASD"],
	[6, "TR_ARROW_KEYS_UD"], [7, "TR_ARROW_KEYS_LR"], [8, "TR_ARROW_KEYS"],
]

var selectors := {}
var blend_option : OptionButton
var should_change : bool = false

## Builds the rows next to the vanilla selectors. Returns false if the panel
## isn't the expected one (then nothing is added).
func build(vbox: Container) -> bool:
	var anchors := {}
	for sel_name in ROWS:
		var ob := vbox.find_child(sel_name, true, false)
		if ob == null or not ob.get_parent() in vbox.get_children():
			return false
		anchors[sel_name] = ob.get_parent()

	var i := 0
	for sel_name in ROWS:
		i += 1
		var ob := _make_option()
		for s in SOURCES:
			if s[0] < 0:
				ob.add_separator()
				# Separators get their index as id, which would clash with follow types.
				ob.set_item_id(ob.item_count - 1, -100 - ob.item_count)
			else:
				ob.add_item(_label(s[1]) + (s[2] if s.size() > 2 else ""), s[0])
		ob.tooltip_text = "Secondary source, combined with the one above (see Combine)."
		ob.item_selected.connect(_on_secondary_selected.bind(ob, ROWS[sel_name]))
		selectors[ROWS[sel_name]] = ob
		_insert_row(vbox, anchors[sel_name], ROW_PREFIX + str(i), "  + Secondary", ob)

	blend_option = _make_option()
	blend_option.add_item("Last active", Shared.BLEND_LAST_ACTIVE)
	blend_option.add_item("Sum", Shared.BLEND_SUM)
	blend_option.add_item("Secondary priority", Shared.BLEND_PRIORITY)
	blend_option.tooltip_text = "Last active: only the source used most recently (stick, key, moving mouse) drives the sprite; the other is ignored until it's used.\nSum: both sources add up, within the min/max range.\nSecondary priority: while the secondary is in use it takes over; when released, the sprite returns to the main source."
	blend_option.item_selected.connect(_on_blend_selected)
	_insert_row(vbox, vbox.get_node(ROW_PREFIX + str(i)), BLEND_ROW, "  Combine", blend_option)

	Global.reinfo.connect(enable)
	Global.deselect.connect(nullify)
	if Global.held_sprites.is_empty():
		nullify()
	else:
		enable()
	return true

func _make_option() -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.focus_mode = Control.FOCUS_NONE
	return ob

func _insert_row(vbox: Container, after: Node, row_name: String, text: String, ob: OptionButton) -> void:
	var row := HBoxContainer.new()
	row.name = row_name
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	row.add_child(ob)
	vbox.add_child(row)
	vbox.move_child(row, after.get_index() + 1)

func _label(key: String) -> String:
	return tr(key) if key.begins_with("TR_") else key

func enable() -> void:
	var sp = Global.held_sprites[0] if not Global.held_sprites.is_empty() else null
	if sp == null or not is_instance_valid(sp):
		nullify()
		return
	should_change = false
	for key in selectors:
		var ob : OptionButton = selectors[key]
		ob.disabled = false
		ob.select(ob.get_item_index(Shared.sec_type(sp, key)))
	blend_option.disabled = false
	blend_option.select(blend_option.get_item_index(Shared.blend_mode(sp)))
	should_change = true

func nullify() -> void:
	for key in selectors:
		selectors[key].disabled = true
	blend_option.disabled = true

func _on_secondary_selected(index: int, ob: OptionButton, key: String) -> void:
	if !should_change: return
	_apply(key, ob.get_item_id(index), Shared.NONE)

func _on_blend_selected(index: int) -> void:
	if !should_change: return
	_apply(Shared.BLEND_KEY, blend_option.get_item_id(index), Shared.BLEND_DEFAULT)

func _apply(key: String, value: int, default: int) -> void:
	var undo_redo_data : Array = []
	for i in Global.held_sprites:
		if i == null or !is_instance_valid(i):
			continue
		_ensure_key(i, key, default)
		undo_redo_data.append({
			node = i,
			action = key,
			state = Global.current_state,
			value = i.sprite_data[key],
			new_val = value,
		})
		i.sprite_data[key] = value
		StateButton.multi_edit(value, key, i, i.states)
		i.save_state(Global.current_state)
	if not undo_redo_data.is_empty():
		UndoRedoManager.push_data(undo_redo_data)

## Old models (and new sprites) don't have the mod's keys; undo/redo skips keys
## that get_value() can't find, and other states need them for multi_edit.
func _ensure_key(sp, key: String, default: int) -> void:
	if not sp.sprite_data.has(key):
		sp.sprite_data[key] = default
	for st in sp.states:
		if st is Dictionary and not st.is_empty() and not st.has(key):
			st[key] = default
