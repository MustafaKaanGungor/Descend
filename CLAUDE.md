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
  - `HealthManager` (`Scripts/DataScripts/HealthManager.gd`, registered by `res://` path) holds player health and emits `health_changed`, `damaged` and `died`.
    - The player calls `HealthManager.register_landing(fall_speed)` in `_update_landing_feedback`.
    - Fall damage is tuned in metres of free fall: the landing speed is converted with the player's falling gravity (`WorldBasicRules` gravity × `MovementJump.player_weight` × `jump_fall_gravity_multiplier`). So a rope-slowed landing after a long swing doesn't count as a long fall.
    - No damage up to `safe_fall_height`, a full-health hit at `lethal_fall_height`, shaped by `fall_damage_curve`.
    - `reset_health()` grants `invulnerable_time_after_reset`.
  - `LoudnessManger` (misspelled, but every reference uses this name, so don't rename it casually) tracks the short-term noise meter with `register_jump/landing/sound` and `push_loudness`.
  - `TotalLoudnessManager` tracks the permanent level noise meter. LoudnessManger feeds it.
- Empty placeholders: `GameManager`, `MovementRules`, `PlayerMovementFeel`, `UiManager`.

If you add a new tunable, put it in the matching Movement/Feel autoload as an `@export` with a `##` doc comment. Don't hardcode it in `player.gd`. If you add a new autoload script, register it in `project.godot` under `[autoload]` with its `uid://` from the `.gd.uid` file or its `res://` path.

### Grappling hook
- `Scripts/Hook/grapple_hook.gd` (`Scenes/Hook/grapple_hook.tscn`) is the thrown hook. The player spawns it into `current_scene`. It runs its own state machine: `flying` → `retracting` → `anchored`, or `reeling` → `returned`, after which it frees itself. It emits `anchored(point)` and `returned`.
  - **flying:** arcs under gravity. Paid-out rope adds growing drag (`rope_payout_drag`). Past full length the rope acts as a stiff spring (`rope_stretch_*`), braking the hook over a short stretch and springing it back, so it never stops dead in the air. It then swings down on the rope. The `rope_snapped` signal drives a small camera tug.
  - **Instant catch:** the moment the hook settles on any upward-facing top surface (`catch_on_top_surfaces`), `_try_catch_on_surface` anchors it, ground included. There is no height rule, so a hook lying on the ground ahead, behind a wall or at your feet catches too.
    - If the straight line from the hand to that spot is blocked by the surface's own edge, it walks toward the hand (`surface_catch_lip_search_distance`) and anchors on that lip.
    - If the rope already bends over corners, they are handed to the player through `get_anchor_wraps()`.
  - **retracting (hanging, not caught yet):** there is no automatic pull. Since any top surface catches, this is mostly a hook hanging off a wall or ledge face. The rope pays out freely up to its full length and the hook lies or hangs where it landed.
    - Wall hits keep only `wall_hit_speed_keep` of their sliding speed, so the hook drops instead of skidding along walls.
    - Only while the player pulls (`set_pulling`, i.e. Shift held on an uncaught hook) is the rope reeled in at `retract_speed`. A pulled hook is dragged over tops, climbs walls the rope runs over, and catches on a top or lip on the way.
  - **Hook-side rope wrapping:** before anchoring, the hook keeps its own corner stack (`_hook_wraps`, ordered hand → hook) and runs the same wrap/unwrap logic as the player, using bisection plus a bend-side flip check. So the rope bends over walls between the hand and the hook.
    - Retracting pulls the hook toward the last corner, not the hand. A hook pulled within `wrap_pass_distance` of a corner is pulled over it.
    - Reeling follows the corners back.
    - On anchoring the hook's corners are cleared. On release, the player's corners are handed back to the hook so it reels along them.
    - `_raycast_rope` ignores the last `rope_contact_ignore_distance` before the hook, so a hook resting on a surface doesn't count as wrapped around it.
    - Wrap points are pushed back along the direction the rope swept in from this tick (last clear position minus current position), not along the bisected pair. That pair converges too tightly for float32 precision.
  - It also draws the rope mesh, using interpolated transforms. Slack rope sags as a parabola (`HookFeel` "Rope Look"); while anchored, the player sends the slack each tick through `set_rope_slack`.
- On the player side (the hook block at the end of `player.gd`):
  - Hold LMB to throw and stay attached; let go to release. Holding Shift on a hook that hasn't caught pulls it in (sprint is suppressed meanwhile).
  - When anchoring, `_adopt_hook_rope_wraps` takes over the hook's corners. If the body's attach line is blocked but the hand's line (which the hook checked) is clear, the rope starts from the hand so the grazed corner gets wrapped instead of breaking the rope.
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
- **`Scripts/Level/level_generator.gd`** (`@tool`) builds everything under a `Generated` child on `_ready`. About 0.5–1 s per level.
  - **Shaft shape:** one function, `_wall_radius(angle, y)`, describes the wall, and every check uses it.
    - Rings of flat wall pieces, `wall_band_height` tall and `wall_segments` around.
    - The radius follows a slow 1D noise along the depth (`_chamber_radius`, between `shaft_radius_min` and `shaft_radius_max`), giving wide chambers and narrow choke points.
    - On top of that, 3D noise around the circle adds bumpiness (`wall_bumpiness`).
    - Each ring is one `StaticBody3D` with a box shape per piece and one merged mesh, to keep draw calls low.
  - **Route:** `stage_count` (30) stations below a start platform, about 250 m deep.
    - Each station is either a **wall ledge** or a **hanging platform** (`mid_station_chance`).
    - A wall ledge comes in four styles: `box`, curved `arc` shelf, `stepped` (lower side steps) or `broken` (rubble chunks). Its hook beam on the wall above stretches so its lip sits over the ledge, and a backplate above the beam turns slightly-high throws into drops onto it.
    - A hanging platform has a far-side fence, which stops the swing the way the wall does, a girder above it with a backboard, and visual-only chains.
  - **Swing solve:** `_solve_swing` places each hook point so the swing from the closest standing spot on the previous station (`_closest_launch_point`) bottoms out `swing_landing_clearance` above the station: v = (s² − k²)/2k, where s is the horizontal launch-to-lip distance and k is drop − clearance. `min_anchor_height_above_hand` and `max_initial_rope_length` keep it hookable. `rope_attach_height`, `hook_throw_speed` and `hook_throw_gravity` mirror `MovementHook` values, because the `@tool` script can't read autoloads in the editor.
  - **Corridors:** each transition records the spaces the route needs: the rope at the catch, the hook's ballistic flight to its aim point (`_throw_flight_corridors`), the swing arc as body capsules, the rope's sweep during the swing, and the landing space.
    - A plan is accepted only if its corridors stay out of the wall and other solids, and its pieces stay out of solids and earlier corridors.
    - Corridors that end on the hook point (`ends_on_hook_point`) ignore that station's own hook pieces.
    - The launch station's floor (`floor_solids`: the slab, arc segments and steps up to 0.6 m down) is ignored, because you walk off it.
    - Solids are rotated boxes, checked with a separating-axis test (`_solids_overlap`). Solids and corridors are indexed by 8 m height slices (`_near`).
  - **Backtracking:** the route is planned as data first (`_reserve_station`). A dead end undoes the last station (`_unreserve_station`, up to `max_route_backtracks`). Nodes are built only once the route is final (`_build_station`).
  - **Structures, placed only where they miss every corridor:** pillars from the floor (with lit capitals), bridges spanning the shaft, tilted overhangs, thin ribs, buttresses, pipes with brackets, and extra beams. Bridges, capitals and ledges are `respawn_ground`.
  - **Seed:** `level_seed` 0 means a new random layout per run; any other value is repeatable. The seed, station count and depth are printed. Editor preview and the inspector "Regenerate" button use `@export_tool_button`.
  - **`get_stages()`** returns per-station data: type, y, landing rectangle, respawn_point, lip, anchor_y, launch, and for wall stations angle and style. `get_wall_radius()` and `get_floor_y()` expose the shape.
- **`Scripts/Level/descent_run.gd`** records the last `respawn_ground` collider the player stood on (its `respawn_point` meta), but not while dead, so the death spot never becomes the respawn point.
  - There is no fall respawn: falling is only punished by fall damage.
  - On `HealthManager.died` it waits `death_respawn_delay`, then calls `player.respawn_at()` on that ledge (or the start) and resets health.
  - On `goal_reached` it builds the next level (deferred), respawns the player at the new start and resets health.
- `player.respawn_at(position, yaw)` clears the hook and all movement states. Use it for any teleport.

### Weapons, props, UI
- The pistol has been removed from the game: it is no longer in `player.tscn`, and the ammo counter is gone from `ui.tscn`. Its scripts and scenes under `Weapons/` are kept but unreferenced.
- `Weapons/pistol.gd` aims through the screen center and spawns `projectile.tscn` into `current_scene`. It emits `fired` and `ammo_changed`, joins the group `player_weapons` (the HUD finds it there), uses a magazine with unlimited reserve and auto-reloads when empty, and pushes a loudness spike when it fires.
- `Weapons/projectile.gd` is a real moving bullet that raycasts its travel segment every tick. It belongs to the group `projectiles` and supports `stop/resume/redirect/time_scale` for future abilities. On a hit it calls `on_projectile_hit(hit_info)` on the collider if that method exists, and spawns `impact_decal.tscn` unless the collider is in `no_impact_decals`.
- `Props/shootable_target.gd` wobbles when hit, breaks into fragments (collision layer 2) and respawns. It builds its collision from the model mesh. `Props/physics_crate.gd` is a crate that reacts to physics.
- `UI/ui.tscn` (CanvasLayer `HudRoot`) holds, top to bottom, the health, total loudness, loudness, stamina and rope bars, plus the crosshair and a full-screen `DamageFlash`. The health, loudness and stamina bars connect to the manager autoload signals.
- `UI/health_bar.gd` follows `HealthManager.health_changed`. `UI/damage_flash.gd` flashes red on `HealthManager.damaged`, stronger for bigger hits.
- `UI/rope_bar.gd` (`rope_bar.tscn`) polls the player's `get_rope_used_length()` and `get_rope_max_length()` (found by searching the scene) and shows "Rope used / max m". The fill goes from rope-tan to orange to red as the rope runs out.

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
