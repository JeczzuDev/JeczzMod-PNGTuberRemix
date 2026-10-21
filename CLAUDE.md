# JeczzMod: working notes

Mod for the installed **PNGTube Remix 1.4.5** build (Godot 4.6-stable, PCK v3, unencrypted, scripts as `.gdc`). The user talks in Spanish; code, comments and commits are in English. `README.md` explains the layout and workflow.

## Rules
- Develop and test only in `../PNGTubeRemix Windows MODS` (test install). Touch `../PNGTubeRemix Windows` (daily install) only when the user asks. Before that:
  - the app must be closed (ask the user, never kill it);
  - back up their model and `Preferences.pRDat` to `backups/`;
  - check that `override.cfg` only holds the mod's line;
  - verify the installed files' hashes against `dist/`.
- The app saves over the loaded model on exit (save_on_exit) and on auto-save. The test install keeps `mods/SANDBOX`, so the loader redirects auto-load to `TestModels/<name>_test.pngRemix`. Kill test instances only by path (`Get-Process | ? Path -like "<MODS>\*"`), never other PNGTube processes.
- Base new code on `recovered_1.4.5/` (GDRE output), not on the upstream repo source: the upstream 1.4.7 differs.
- Run `deploy_to_test.sh` / `build_package.sh` from Bash (`sh ...`), and `run_selftest.ps1` from PowerShell.
- Workflow the user approved: investigate in 1.4.5 → plan with options → implement → self-test (0 fails) → user's manual test in MODS → package → install to the daily install with a backup.

## How the mod hooks in
- `override.cfg` `[autoload] JeczzModLoader="*res://mods/jeczz_mod_loader.gd"`. Loose `res://mods/...` files next to the exe load fine. Override autoloads run after all game autoloads and before `Menu._ready`.
- `base_object.tscn` and the follow scripts are **already cached** when the mod starts:
  - `take_over_path` is useless;
  - `GDScript.source_code` + `reload()` is silently ignored (binary tokens).
- What works: on `get_tree().node_added`, `set_script()` the node to a subclass (`extends "res://.../follow_*.gd"`), re-assigning every `PROPERTY_USAGE_SCRIPT_VARIABLE` value. This happens before `_ready`, and scene signal connections survive.
- The loader is gated by `SUPPORTED_GAME_VERSIONS` (`application/config/version`); on mismatch nothing loads.
- UI is built at runtime: the selectors' extra items come from `follow_shared.gd` `EXTRA_PRIMARY_ITEMS`; `secondary_ui.gd` is added deferred once `FollowOption3` exists.

## Game facts (1.4.5)
- **Selectors:** Follow selectors store the item **index** in `sprite_data.follow_type{,2,3}`.
  - 0 Mouse, 1/2 Controller L/R, 3-8 keyboard, 10-12 R1+L1/R2+L2/R3+L3, 15 None, 17 UDP.
  - Mod: 18/19 Mouse X/Y, 20-23 stick L X, L Y, R X, R Y.
  - Only append new options; never shift indices.
- **Per-state storage:** `sprite_data` is saved whole per state, so extra keys persist and vanilla ignores them.
  - Undo/redo (`UndoRedoManager`) skips keys that `get_value()` returns null for, so `secondary_ui._ensure_key()` adds missing keys to every state before editing.
- **Mod keys:**
  - `jz_follow_type{,2,3}_b` = secondary source (default 15 = None);
  - `jz_follow_blend` = 2 Last active (default), 0 Sum, 1 Secondary priority.
- **Quirks:**
  - Position with a stick/keys uses `(|min| + max) / 2` as reach, so one-sided ranges got half. The mod passes `STICK_REACH`.
  - Rotation/scale "follow mouse velocity" never receives a velocity (`dir_vel_anim` unused).
  - Controller scale at rest = 1 + max.
- **Input:** controller actions have deadzone 0.2 and `Input.get_vector` remaps by it. Use strength 1.0 when simulating in tests.

## Secondary layer technique
Each frame, in each `*_ext.gd`:
1. If the modifier still holds what the mod wrote last frame, restore the vanilla value. If something else changed it (reset, rest mode), start over.
2. Run the vanilla (primary) update.
3. Blend in the secondary:
   - **Sum:** add the secondary's offset from its rest value, clamped to the range envelope.
   - **Priority / Last active:** ease a weight toward the secondary (`source_picker.gd` decides which source drives).

## GDScript pitfalls met here
- Dictionaries have no `.items()`.
- `:=` on untyped (Variant) expressions is a parse error: give an explicit type.
- `res://` is read-only in the exported app: write logs via `OS.get_executable_path().get_base_dir()`.
- `OptionButton.add_separator()` gives the separator its index as id: reassign it, or it clashes with follow types.
- `lerp_angle` wraps: compare angles with `angle_difference`.
- PowerShell 5.1 zip tools write `\` in entry names: `make_zip.ps1` writes `/`.
