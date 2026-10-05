# CLAUDE.md

This file guides Claude Code (claude.ai/code) when it works in this repository.

## Project

**Descend** is a first-person 3D parkour and FPS prototype built in **Godot 4.7** (Forward+ renderer, D3D12 on Windows, Jolt Physics, physics interpolation on). Everything is written in GDScript. The project has no build step, test suite or linter. You run and check it in the Godot editor; `.vscode/settings.json` points the godot-tools extension at the Steam install of Godot.

- Main scene: `res://Scenes/Levels/descent_level.tscn`, a procedurally generated descent shaft (see "Descent levels" below).
- `res://Scenes/main.tscn` is the old greybox test level, made of CSG boxes plus a shooting range with targets and crates (the targets are unused now that the pistol is gone).
- Input actions in `project.godot`: `move_forward/backward/left/right` (WASD), `move_jump` (Space), `move_sprint` (Shift), `move_crouch` (Ctrl), `hook` (LMB), `reload` (R). `shoot` still exists but has no binding. Code reads these only through the `InputManager` autoload, never with raw action strings.
- Don't edit `.godot/`; it is the generated cache and is gitignored.

## Architecture

### The player is one big state machine
`Scripts/player.gd` (`CharacterBody3D`, about 2900 lines) owns all movement state as private `_vars`. `_physics_process` runs in a fixed order: update timers and feedback, read input through `InputManager`, update states (slide, crouch, sprint, climb, edge hold, wall run), then apply **exactly one** movement branch. The branch priority is:

edge pull-over → edge hold → climb → hook swing → slide → wall run → wall-run release → ground → air

After that it applies vertical motion, spends stamina and updates loudness. If you add a movement mode, fit it into this priority chain and give it a matching `_stop_*` path so the modes stay mutually exclusive.

The player exposes read-only state through public getters (`get_horizontal_speed()`, `get_slide_blend()`, `is_wall_running()`, …). One-shot events use `consume_*()` methods (`consume_landing_impact()`, `consume_jump_feedback()`, …), which return a value and reset it. Short-lived "recent" values use `get_recent_*()`.

### Presentation nodes poll the player by method name
`head.gd` (yaw/pitch and eye height), `playercamera.gd` (FOV, bob, roll, impulses), and `hands.gd` (viewmodel sway and poses) don't depend on the player's type. Each one declares `const METHOD_*: StringName = &"..."` and calls `player.has_method(...)` / `player.call(...)`. **If you rename or remove a player getter, update these constants in every consumer.** A plain grep for the method name finds them.

Player scene tree: `Player` → `Head` → `Camera3D` → `Hands`.

### Autoloads hold tuning data and logic (no player state)
`project.godot` registers about 30 autoloads, all `extends Node`. Most are referenced by UID; `MovementHook` and `HookFeel` are referenced by `res://` path. They fall into three groups:

- **`Scripts/Movement/Movement*.gd`** (Walk, Run, Jump, Crouch, Slide, WallRun, Climb, Hook) plus `Scripts/MovementEdgeHelp.gd` hold movement tuning as `@export` vars grouped with `@export_group` and documented with `##` comments. They also provide pure helper functions such as `MovementWallRun.can_start_wall_run(...)` and `MovementRun.get_sprint_ramp_speed(t)`. Some cache a small amount of context, for example combo speed through `set_*_context`.
- **`Scripts/Feel/*Feel.gd`** hold "game feel" tuning: camera kicks, FOV, bob, roll and hand motion for each movement type. `SpeedEffectController.gd` is *not* an autoload. It is the script on the `speed_shader.tscn` CanvasLayer (a full-screen speed-lines shader).
- **Systems:**
  - `InputManager` handles input actions, hold-to-sprint and the double-tap-forward sprint.
  - `WorldBasicRules` holds gravity, terminal fall speed and the spawn offset.
  - `StaminaManager` lives at the **project root**, not in `Scripts/`. It handles drain per movement type and instant costs, emits `stamina_changed` and `stamina_depleted`, and provides `can_*()` gates.
  - `LoudnessManger` (misspelled, but every reference uses this name, so don't rename it casually) tracks the short-term noise meter with `register_jump/landing/sound` and `push_loudness`.
  - `TotalLoudnessManager` tracks the permanent level noise meter. LoudnessManger feeds it.
- Empty placeholders: `GameManager`, `MovementRules`, `PlayerMovementFeel`, `UiManager`.

If you add a new tunable, put it in the matching Movement/Feel autoload as an `@export` with a `##` doc comment. Don't hardcode it in `player.gd`. If you add a new autoload script, register it in `project.godot` under `[autoload]` with its `uid://` from the `.gd.uid` file or its `res://` path.

### Grappling hook
- `Scripts/Hook/grapple_hook.gd` (`Scenes/Hook/grapple_hook.tscn`) is the thrown hook. The player spawns it into `current_scene`. It runs its own state machine: `flying` → `retracting` → `anchored`, or `reeling` → `returned`, after which it frees itself. It emits `anchored(point)` and `returned`.
  - **flying:** arcs under gravity. Paid-out rope adds growing drag (`rope_payout_drag`). Past full length the rope acts as a stiff spring (`rope_stretch_*`), braking the hook over a short stretch and springing it back, so it never stops dead in the air. It then swings down on the rope. The `rope_snapped` signal drives a small camera tug.
  - **retracting:** the rope is pulled in slowly. A hook lying on a top surface is dragged toward the player. A wall between the hook and the player gets climbed, since the rope runs over it. When the hook reaches a lip with a real drop, sitting above the hand and with a clear line to it, it anchors there.
  - **Hook-side rope wrapping:** before anchoring, the hook keeps its own corner stack (`_hook_wraps`, ordered hand → hook) and runs the same wrap/unwrap logic as the player, using bisection plus a bend-side flip check. So the rope bends over walls between the hand and the hook.
    - Retracting pulls the hook toward the last corner, not the hand. A hook pulled within `wrap_pass_distance` of a corner is pulled over it.
    - Reeling follows the corners back.
    - On anchoring the hook's corners are cleared. On release, the player's corners are handed back to the hook so it reels along them.
    - `_raycast_rope` ignores the last `rope_contact_ignore_distance` before the hook, so a hook resting on a surface doesn't count as wrapped around it.
    - Wrap points are pushed back along the direction the rope swept in from, not off the old rope line, which is degenerate at the corner.
  - It also draws the rope mesh, using interpolated transforms. Slack rope sags as a parabola (`HookFeel` "Rope Look"); while anchored, the player sends the slack each tick through `set_rope_slack`.
- On the player side (the hook block at the end of `player.gd`):
  - Hold LMB to throw and stay attached; let go to release.
  - While anchored, Shift reels in (drains stamina) and Ctrl lets out, replacing sprint and crouch.
  - WASD pumps the swing; Space releases with a boost.
  - The rope is an inextensible constraint applied around `move_and_slide()`: outward velocity is removed beforehand, and stretch is corrected with `move_and_collide` afterwards.
  - Swing gravity is a constant `MovementHook.swing_gravity_multiplier`, because the jump arc's rise/fall gravity split would pump energy into the pendulum.
  - Starting a climb, edge hold or edge pull-over releases the hook.
  - **Ledge climb from the rope:** `_try_hook_ledge_climb` runs while hanging, holding Shift or W, with the rope's hold point within `ledge_grab_max_distance` of the anchor or corner.
    - It probes for the ledge with `_find_climb_edge_hold_result(..., MovementHook.ledge_grab_reach)`; the optional third parameter extends the reach to arms-overhead height.
    - It then hands off to the normal `_apply_climb_edge_result` climb-over, pushed `ledge_climb_pull_distance` further onto the ledge.
    - The regular climb checks can't trigger while hanging: they need a jump press, horizontal speed and recent floor contact.
  - The rope's pull-back correction slides along walls (`move_and_collide`, then slide the remainder) so reeling up a wall face doesn't stall.
  - **Rope wrapping:** the player keeps a stack of wrap points (`_hook_wrap_points`) from the anchor toward the body. The swing pivots on the last point, and the free length is the total `_rope_length` minus the fixed wrapped segments.
    - **Wrap:** when the rope to the pivot gets blocked, a bisection between last tick's clear rope and this tick's blocked rope finds the corner, which is pushed out by `wrap_point_offset`.
    - **Unwrap:** a corner is removed once the rope's bend direction at it flips and the line to the previous point is clear.
    - The rope only breaks (after `rope_blocked_break_time`) if no clean corner is found.
    - The hook draws one rope segment per span through the points sent with `set_wrap_points`.
- **Catch sound:** `Assets/Audio/hook_catch_1..3.wav` are synthesized steel-on-stone clanks. The hook scene's `CatchSound` (`AudioStreamPlayer3D`) plays a random one with random pitch and volume when it anchors. Volume and variation live in `HookFeel` "Sound".
- Tuning lives in `MovementHook` and `HookFeel`. `StaminaManager` has `can_hook_reel` and `drain_hook_reel`.

### Descent levels
- `Scenes/Levels/descent_level.tscn` is a root using `main.gd` (spawns the player at `PlayerSpawn`). Its children are `WorldEnvironment`, a `Sun`, the UI and speed shader, `LevelGenerator` and `DescentRun`.
- **`Scripts/Level/level_generator.gd`** (`@tool`) builds everything under a `Generated` child on `_ready`:
  - **Shaft:** a round shaft of flat wall boxes (`shaft_radius`, `wall_segments`) with a start platform at y=0.
  - **Ledges:** `stage_count` ledges spiral down the wall, each with a lamp.
  - **Beams:** a hook beam sits on the wall above each ledge. Its lip has a glowing, visual-only strip.
  - **Bottom:** a floor with a goal ring and `Area3D`.
  - **Seed:** `level_seed` 0 means a new random layout per run; any other value is repeatable. The seed is printed. Editor preview and the inspector "Regenerate" button use `@export_tool_button`.
  - **Beam height** is solved per stage (`_plan_stage`) so that hooking the lip from the previous ledge's edge and swinging bottoms out `swing_landing_clearance` above the next ledge: v = (s² − k²)/2k, where s is the horizontal launch-to-lip distance and k is drop − clearance.
  - **Constraints:** `min_anchor_height_above_hand` and `max_initial_rope_length` keep it hookable. `rope_attach_height` must match `MovementHook.body_attach_height`.
  - **Overlaps** are rejected with a cylindrical-coordinate check (`_overlaps_piece`). Stages retry 160 times, alternating spiral direction.
  - `get_stages()` returns the ledge and anchor data.
- **`Scripts/Level/descent_run.gd`** records the last `respawn_ground` collider the player stood on (its `respawn_point` meta). It calls `player.respawn_at()` after a fall of `respawn_fall_distance` below it. On `goal_reached` it builds the next level (deferred) and respawns the player at the new start.
- `player.respawn_at(position, yaw)` clears the hook and all movement states. Use it for any teleport.

### Weapons, props, UI
- The pistol has been removed from the game: it is no longer in `player.tscn`, and the ammo counter is gone from `ui.tscn`. Its scripts and scenes under `Weapons/` are kept but unreferenced.
- `Weapons/pistol.gd` aims through the screen center and spawns `projectile.tscn` into `current_scene`. It emits `fired` and `ammo_changed`, joins the group `player_weapons` (the HUD finds it there), uses a magazine with unlimited reserve and auto-reloads when empty, and pushes a loudness spike when it fires.
- `Weapons/projectile.gd` is a real moving bullet that raycasts its travel segment every tick. It belongs to the group `projectiles` and supports `stop/resume/redirect/time_scale` for future abilities. On a hit it calls `on_projectile_hit(hit_info)` on the collider if that method exists, and spawns `impact_decal.tscn` unless the collider is in `no_impact_decals`.
- `Props/shootable_target.gd` wobbles when hit, breaks into fragments (collision layer 2) and respawns. It builds its collision from the model mesh. `Props/physics_crate.gd` is a crate that reacts to physics.
- `UI/ui.tscn` (CanvasLayer `HudRoot`) holds the total loudness, loudness and stamina bars, and the crosshair. The bars connect to the manager autoload signals.

### Collision and import
- Level geometry and movement raycasts use **collision layer 1**.
- `Scripts/Import/add_static_collision.gd` is an `EditorScenePostImport` script. Set it as the Import Script on level models to auto-add trimesh `StaticBody3D`s.
- Assets in `Assets/Models/` are Kenney packs: Characters, Props (GLB) and Weapons (`blaster-b.glb` is the pistol).
- Root-level `sample_2.tscn` points at a missing `Assets/Sample 2.fbx`, so it is a stale leftover.

## Code conventions
- Static typing everywhere: `var x: float = 0.0`, typed function signatures, and `-> void` returns.
- Use `minf/maxf/clampf` rather than the untyped `min/max/clamp`.
- Use `StringName` literals (`&"name"`) for method names, groups, actions and states, declared as `const` at the top of the file.
- Exported tuning is organized with `@export_group(...)` and each export gets a `##` doc comment.
- Private members start with `_`. Leave two blank lines between functions.
- Files use the cross-node `get_node_or_null(path) as Type` pattern with exported `NodePath`s and null checks rather than hard `$` paths, except for nodes that belong to the script's own scene.
- Some comments are in Turkish (for example in `StaminaManager.gd`). Leave them as they are.
