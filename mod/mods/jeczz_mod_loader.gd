extends Node
## Jeczz mod loader for PNGTube Remix 1.4.5 (Godot 4.6).
## Registered as an autoload from override.cfg, so it runs after every game
## autoload and before the Menu scene is ready.
##
## Game scenes (base_object.tscn) and their scripts are already cached when this
## runs, so scripts can't be replaced by path. Instead, every node that enters the
## tree with one of the original scripts gets its script swapped for a mod
## subclass before its _ready, keeping all script variable values.

const MOD_VERSION := "1.3.0"
const MOD_DIR := "res://mods"
const LOG_PREFIX := "[JeczzMod] "
## The subclasses copy parts of these exact game scripts; on any other game
## version the mod stays off so the app runs vanilla instead of breaking.
const SUPPORTED_GAME_VERSIONS := ["1.4.5"]

## Original script path -> mod subclass path.
const SCRIPT_SWAPS := {
	"res://Scripts/Objects/ObjectComponents/follow_component.gd": "res://mods/follow_ext/follow_position_ext.gd",
	"res://Scripts/Objects/ObjectComponents/follow_rotation.gd": "res://mods/follow_ext/follow_rotation_ext.gd",
	"res://Scripts/Objects/ObjectComponents/follow_scale.gd": "res://mods/follow_ext/follow_scale_ext.gd",
}
const SECONDARY_UI := "res://mods/follow_ext/secondary_ui.gd"
const FOLLOW_SHARED := "res://mods/follow_ext/follow_shared.gd"

## Follow selectors (unique names in movement.tscn). The game stores the selected
## item INDEX, so new options must be appended after the 18 built-in items.
const FOLLOW_SELECTORS := ["FollowOption", "FollowOption2", "FollowOption3"]
const VANILLA_ITEM_COUNT := 18

var _swaps := {}
var _enabled := false

func _init() -> void:
	var game_version := str(ProjectSettings.get_setting("application/config/version", ""))
	if game_version not in SUPPORTED_GAME_VERSIONS:
		push_warning(LOG_PREFIX + "v%s supports PNGTube Remix %s, found '%s': mod disabled" % [MOD_VERSION, ", ".join(SUPPORTED_GAME_VERSIONS), game_version])
		return
	_enabled = true
	for original in SCRIPT_SWAPS:
		var sub : Script = load(SCRIPT_SWAPS[original])
		if sub == null:
			push_error(LOG_PREFIX + "could not load " + SCRIPT_SWAPS[original])
			continue
		_swaps[original] = sub
	# Sticks only answer to sticks; D-pad and A/B/X/Y become their own sources.
	load(FOLLOW_SHARED).split_controller_buttons()
	print(LOG_PREFIX, "v", MOD_VERSION, " loaded ", _swaps.size(), "/", SCRIPT_SWAPS.size(), " script swaps")

func _enter_tree() -> void:
	if _enabled:
		get_tree().node_added.connect(_on_node_added)

func _ready() -> void:
	# Catch anything that entered the tree before the signal was connected.
	if _enabled:
		_scan(get_tree().root)
	if FileAccess.file_exists(MOD_DIR + "/SANDBOX"):
		_sandbox_guard()

func _scan(node: Node) -> void:
	_on_node_added(node)
	for c in node.get_children():
		_scan(c)

func _on_node_added(n: Node) -> void:
	var s : Script = n.get_script()
	if s != null and _swaps.has(s.resource_path):
		_swap_script(n, _swaps[s.resource_path])
	elif n is OptionButton and String(n.name) in FOLLOW_SELECTORS:
		_add_extra_items(n)
		if n.name == FOLLOW_SELECTORS[-1]:
			# The panel is still adding children; build once it's done.
			_attach_secondary_ui.call_deferred(n)

func _swap_script(n: Node, sub: Script) -> void:
	var values := {}
	for p in n.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values[p.name] = n.get(p.name)
	n.set_script(sub)
	for k in values:
		n.set(k, values[k])

## Appends Mouse X/Y and the single-axis stick options; each one's index in the
## selector is its follow type.
func _add_extra_items(ob: OptionButton) -> void:
	if ob.item_count != VANILLA_ITEM_COUNT:
		return
	for item in load(FOLLOW_SHARED).EXTRA_PRIMARY_ITEMS:
		if ob.item_count != item[0]:
			push_error(LOG_PREFIX + "unexpected item index for follow type %d" % item[0])
			return
		ob.add_item(tr(item[1]) + item[2], item[0])

func _attach_secondary_ui(last_selector: OptionButton) -> void:
	if not is_instance_valid(last_selector) or not last_selector.is_inside_tree():
		return
	var vbox := last_selector.get_parent().get_parent() as Container
	var ui_script : Script = load(SECONDARY_UI)
	if vbox == null or ui_script == null or vbox.has_node(ui_script.BLEND_ROW):
		return
	var ui = ui_script.new()
	ui.name = "JzSecondaryUI"
	vbox.add_child(ui)
	if not ui.build(vbox):
		push_warning(LOG_PREFIX + "Movement panel layout not recognized; secondary selectors not added")
		ui.queue_free()

## Test installs only (enabled by a mods/SANDBOX file): never auto-load a model
## from outside this install's folder, because save_on_exit/auto_save write back
## to the loaded file. Redirects to TestModels/<name>_test.pngRemix.
func _sandbox_guard() -> void:
	# Settings fills theme_settings.path ~0.1s after start; Menu loads it ~0.1s later.
	var base := OS.get_executable_path().get_base_dir()
	var frames := 0
	while Settings.theme_settings.path == "" and frames < 300:
		await get_tree().process_frame
		frames += 1
	var p : String = Settings.theme_settings.path
	if p == "" or p.begins_with(base):
		return
	var test_path := base + "/TestModels/" + p.get_file().get_basename() + "_test.pngRemix"
	if FileAccess.file_exists(test_path):
		Settings.theme_settings.path = test_path
		print(LOG_PREFIX, "sandbox: ", p, " -> ", test_path)
	else:
		Settings.theme_settings.auto_load = false
		print(LOG_PREFIX, "sandbox: auto_load disabled (no test copy for ", p, ")")
