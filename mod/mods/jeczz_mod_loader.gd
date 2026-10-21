extends Node
## Jeczz mod loader for PNGTube Remix 1.4.5 (Godot 4.6).
## Registered as an autoload from override.cfg, so it runs after every game
## autoload and before the Menu scene is ready.
##
## Game scenes (base_object.tscn) and their scripts are already cached when this
## runs, so scripts can't be replaced by path. Instead, every node that enters the
## tree with one of the original scripts gets its script swapped for a mod
## subclass before its _ready, keeping all script variable values.

const MOD_VERSION := "1.0.0"
const MOD_DIR := "res://mods"
const LOG_PREFIX := "[JeczzMod] "
## The subclasses copy parts of these exact game scripts; on any other game
## version the mod stays off so the app runs vanilla instead of breaking.
const SUPPORTED_GAME_VERSIONS := ["1.4.5"]

## Original script path -> mod subclass path.
const SCRIPT_SWAPS := {
	"res://Scripts/Objects/ObjectComponents/follow_component.gd": "res://mods/follow_mouse_axis/follow_position_axis.gd",
	"res://Scripts/Objects/ObjectComponents/follow_rotation.gd": "res://mods/follow_mouse_axis/follow_rotation_axis.gd",
	"res://Scripts/Objects/ObjectComponents/follow_scale.gd": "res://mods/follow_mouse_axis/follow_scale_axis.gd",
}

## Follow selectors (unique names in movement.tscn). The game stores the selected
## item INDEX, so new options must be appended after the 18 built-in items.
const FOLLOW_SELECTORS := ["FollowOption", "FollowOption2", "FollowOption3"]
const VANILLA_ITEM_COUNT := 18
const MOUSE_X := 18
const MOUSE_Y := 19

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
		_add_mouse_axis_items(n)

func _swap_script(n: Node, sub: Script) -> void:
	var values := {}
	for p in n.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values[p.name] = n.get(p.name)
	n.set_script(sub)
	for k in values:
		n.set(k, values[k])

func _add_mouse_axis_items(ob: OptionButton) -> void:
	if ob.item_count != VANILLA_ITEM_COUNT:
		return
	var mouse := tr("TR_MOUSE")
	ob.add_item(mouse + " X", MOUSE_X)
	ob.add_item(mouse + " Y", MOUSE_Y)

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
