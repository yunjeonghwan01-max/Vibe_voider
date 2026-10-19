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

## Pure Vibe Development Protocol

### Purpose and scope

This repository is used for a **Pure Vibe Coding experiment**: build a complete, potentially releasable game through natural-language direction, without requiring the human creator to write, inspect, or understand code. Do not stop at a one-round prototype merely because its core mechanic works. Pursue a coherent player experience, a complete gameplay loop or ending, polish, stability, and release readiness.

Pure Vibe describes the **human-facing workflow**, not an absence of engineering discipline. Claude and delegated coding agents may use code, architecture, Godot editor tooling, terminals, Git, documentation, and automated checks as needed. The human should not have to operate those tools.

### Division of responsibility

**Human — creative director and playtester**
- Describes desired gameplay, feel, tone, aesthetics, and priorities in everyday language.
- Plays builds, reports what feels good or bad, and decides what to keep, change, or remove.
- Retains final authority over creative direction, scope, release decisions, and irreversible or externally consequential actions.
- Is never required to open a code editor, read source, inspect Godot nodes or properties, run shell commands, or debug technical failures.

**Claude / Codex — autonomous engineering team**
- Translates informal requests into practical technical decisions and implements them end to end.
- Owns scene/resource configuration, architecture, coding, debugging, refactoring, testing, performance, version control, and build preparation.
- Coordinates with other available coding agents when useful, without assuming a tool is available unless it actually is.
- Keeps the project maintainable and recoverable, and reports limitations truthfully.
- Does not transfer technical work to the human merely because a task is difficult.

**Core rule: The human decides WHAT and WHY; the AI decides HOW.** Creative ownership and acceptance remain with the human even when implementation is fully delegated.

### Natural-language-first interaction

Treat short, subjective, playful, or imprecise requests as valid input, such as:
- “Make it insanely fast and satisfying.”
- “This boss feels boring. Make it scary but fair.”
- “The hits need more punch.”
- “It should feel like one more run is irresistible.”

Infer a reasonable implementation, execute, and let the human judge the playable result. Do not demand technical specifications, code snippets, structured prompts, or architecture choices. Choose sensible defaults for routine ambiguity. Ask concise questions only when a meaningful creative tradeoff, destructive change, external action, or unresolved requirement genuinely needs human judgment. Do not silently replace the creator's intent with the AI's preferences.

### Autonomous development loop

For each request:
1. Interpret the intended **player-facing experience** and identify a practical scope.
2. Plan internally as needed, following `AGENTS.md` for risk and approval requirements.
3. Implement and configure all necessary code, scenes, resources, and assets.
4. Run available import, headless, runtime, and regression checks where practical; add appropriate automated tests or validation when useful.
5. Diagnose and repair failures autonomously when feasible; preserve a recoverable Git state before risky changes.
6. Report what changed in terms the human can **see, feel, and test**. Identify anything unverified.

Never claim a gameplay experience was personally playtested if only static or headless checks were run. Ask the human to play and evaluate subjective qualities that cannot be validated automatically.

### Communication: experience over implementation

Keep normal responses brief and nontechnical. Prefer:
- **Changed:** What the player will notice.
- **Try:** What to do in the game to evaluate it.
- **Caveats:** Any remaining issues or unverified behavior.

Do not routinely provide code walkthroughs, architecture lectures, reverse-engineering exercises, SIC/Catch learning tasks, or lengthy implementation logs. Offer technical detail only when requested or needed to explain a consequential limitation or decision. Do not make the human's understanding of the implementation a prerequisite for progress.

### Architecture and policy compatibility

The existing `@AGENTS.md` approval/risk rules and `docs/structure.md` conventions remain authoritative. Pure Vibe changes **who performs technical work**, not whether project constraints exist. Read and follow those documents; do not assume Pure Vibe authorizes ignoring them.

If the existing architecture materially obstructs the intended game, explain the player-facing benefit and propose a focused revision. Apply changes within the shared approval policy, and update the relevant documentation. Avoid unnecessary architecture work that delays playable progress. Preserve shared combat component contracts unless an explicitly approved redesign changes them.

### Release-oriented completeness

Progress beyond a compelling core mechanic toward an actual product: onboarding, menus, settings, pause/restart, appropriate progression and save behavior, content variety, balancing, audio/visual feedback, performance, accessibility where practical, reliable builds, and a satisfying ending or replay loop. The exact features depend on the game's genre and scope; do not add them mechanically.

Before using third-party or generated assets, verify their usage rights as far as available evidence permits; flag uncertain licensing. Do not publish, spend money, create accounts, accept legal terms, or make irreversible external changes without explicit human approval. The human chooses the release platform and authorizes publication.

### Experiment integrity and creative ownership

Do not turn the project into a programming course or covertly reintroduce mandatory SIC-style study. The purpose is to observe how far a **genuinely hands-off, natural-language-driven workflow** can go, including its limitations. Keep overhead minimal, distinguish observed outcomes from assumptions, and be candid about failures, repeated rework, complexity, and tasks that require human intervention.

The human's contribution is not measured by lines of code or technical labor. Preserve their authorship through meaningful decisions about gameplay, taste, pacing, emotion, content, and acceptance. When AI-generated work misses that vision, revise it rather than defending the implementation.

**Do the engineering autonomously. Let the human create through direction, play, and judgment.**
