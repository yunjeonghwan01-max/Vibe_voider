# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

Shared development workflow, approval/risk policy, and Godot collaboration principles are defined there and apply here too. Use Claude Code's Plan Mode selectively for complex or high-risk work per that policy — it is not required for every task.

## Project overview

IBBD Prototype Base is a base template for building 2D action games in Godot 4.7 with Claude Code. It is not a genre-agnostic template and not a game: it ships the folder architecture, the Scene Tree vocabulary, a developer toolkit, and a shared combat pipeline. Game-specific systems and content (player, enemies, abilities, levels, collision layer scheme) are created in each project generated from this template.

Engine settings worth knowing:
- The effective renderer is **Compatibility** (`renderer/rendering_method="gl_compatibility"`), even though `config/features` still lists `"Forward Plus"`.
- 2D physics uses Godot's default 2D engine. `3d/physics_engine="Jolt Physics"` only affects 3D.

## Running and editing

This is a Godot Engine project — there is no CLI build/test/lint pipeline. Open and run it through the Godot 4.7 editor (`.vscode/settings.json` holds the editor path for the VS Code Godot extension; adjust it per machine). The main scene is `app/main.tscn` (set via `run/main_scene` in `project.godot`, referenced by UID).

To sanity-check the project from the terminal (replace `godot` with the local Godot 4.7 executable):
```
godot --path . --headless --import   # parse/import all resources
godot --path . --headless --quit     # load the project and exit
```

There are no automated tests in this repo.

## Project structure

The structure rules — template policy, folder responsibilities, file/node/input naming, Scene Tree vocabulary and presets, the combat pipeline contract, collision layer principles, engine-constraint exceptions — are defined in **`docs/structure.md`**. Read it before adding or restructuring scenes, scripts, or resources, and update it when the structure changes.

Key points (details in `docs/structure.md`):
- Top-level folders are fixed by responsibility: `app/ actors/ combat/ world/ levels/ ui/ camera/ managers/ toolkit/ core/ assets/`. They and their role subfolders exist from the start (empty ones hold a `.gitkeep`; delete it once a real file lands there). Never group files by type (`_scenes/`, `_scripts/`) or in a catch-all `systems/`.
- Pre-created folders do not license pre-created content: no empty role nodes (`Visual`, `Audio`, `Sensors`…), empty level scenes, or speculative Manager/Component scripts.
- A scene and its script share a basename (`player.tscn` + `player.gd`); files are `snake_case`, nodes are `PascalCase`, input actions are `player_*` (gameplay) or `tool_*` (developer tools). Move `.uid` (scripts) and `.import` (images) files together with their source file; never hand-edit them. Do not hard-code another file's `res://` path in scripts: inherit via `class_name`, and take scenes as `@export var ...: PackedScene` assigned in the `.tscn`.

## Architecture

`app/main.tscn` is a plain `Node` shell. It holds the current level instance (none yet in the template) and the `Toolkit`. Level content (TileMap, actors, world objects) never goes directly into Main.

`toolkit/toolkit.tscn` (`toolkit/toolkit.gd`) is a `CanvasLayer` that provides an always-on developer toolkit, independent of the game's pause state (`process_mode = PROCESS_MODE_ALWAYS`). It listens for dedicated `tool_*` input actions (defined in `project.godot`, distinct from the `player_*` gameplay actions) and currently supports:
- `tool_toggle_hud` — show/hide the debug HUD
- `tool_restart` — reload the current scene
- `tool_pause` — toggle `get_tree().paused`

The debug HUD (`toolkit/debug_hud.gd`, the `DebugHud` `Control` under the toolkit's `CanvasLayer`) renders FPS, frame time, and current scene name into `InfoLabel` every `_process` frame.

All damage flows through one path, provided in `combat/components/`: `HitboxComponent` → `HurtboxComponent.receive_hit(damage, source, knockback)` → `HealthComponent.take_damage()`. Attackers own a `HitboxComponent` (toggled via `monitoring`; it dedupes per `reset_hits()`; `apply_on_contact = false` hands hit timing to the attacker via `hurtbox_entered`); defenders own `Combat/Health` + `Combat/Hurtbox` (with the `health` export wired) and react only through the `hit_received` / `damaged` / `died` signals — actor scripts have no `take_damage()`, and targets are never looked up via `area.owner` or `has_method()`. Keep the components' API and behavior stable; game-specific attack logic belongs in the game's own actors/abilities, not in these components.

Actors follow the vocabulary in `docs/structure.md`: `Visual` (only this flips with facing), `BodyCollision` (the `CollisionShape2D` itself — must be a direct child of the body), `Combat`, and `Sensors` / `Components` / `Audio` only when actually needed. An actor-specific skill lives in `actors/<actor>/abilities/<name>/` and moves to `combat/` only once a second user exists.

To add a new level, create it under `levels/<name>/` with the level vocabulary (`World`, `Actors`, `Projectiles`, `Effects` as needed) and instance it as a child of `Main` in `app/main.tscn`. Runtime projectiles/effects are added to the level's `Projectiles` / `Effects` containers, not to the spawner's parent.

`addons/godot_mcp/` is the Godot MCP editor plugin (enabled in `project.godot` under `[editor_plugins]`). It is tooling, not game content — leave it out of the folder conventions in `docs/structure.md`.
