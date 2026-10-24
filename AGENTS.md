# AGENTS.md

Shared AI development collaboration guidelines for this repository (Claude Code, Codex, and any other coding agent). Tool-specific setup lives in each tool's own file (e.g. `CLAUDE.md`), which should reference this document for shared workflow rules rather than repeating them.

## 1. Principles

- Respect the existing code, scene, and resource structure. Before introducing a new pattern, check how the project already solves similar problems.
- Prefer simple, testable implementations over speculative or generalized architectures. An experimental implementation is not an excuse for obvious bugs or unsafe code.
- Do not add features outside the requested scope, or introduce new layers, managers, Autoloads, global event buses, generic state machines, or other broad abstractions without a concrete, stated reason.
- Workflow: implement and playtest features quickly on dedicated branches → merge if worthwhile, otherwise discard the branch → do focused cleanup/refactoring later.

## 2. Feature Specification (Five Fields)

Use these fields to define *what to build*. Investigation, planning, implementation, and verification are separate execution stages, not specification fields.

1. **Goal** — the observable behavior or problem to solve.
2. **Scope** — what is included / explicitly excluded (non-goals).
3. **Constraints** — performance, engine/API, compatibility, architectural restrictions.
4. **Context** — relevant scenes, scripts, and existing systems (investigate first if unknown).
5. **Acceptance Criteria** — reproducible checks and conditions for success.

## 3. Execution Workflow

1. **Investigate** (read-only): find relevant files and similar features; identify existing Node/Scene/Resource/Signal patterns, dependencies, and naming conventions. Base decisions on the codebase, not assumptions.
2. **Plan**: for larger or multi-file changes, briefly state affected files, responsibilities, data flow, implementation order, and risks. Do not modify files at this stage.
3. **Approve (risk-based, not mandatory)**:
   - Trivial, low-risk changes: implement directly.
   - Small, well-understood tasks: state the approach in a short text plan and proceed without waiting.
   - Changes with significant architectural impact, unclear requirements, or high regression risk: present a plan and wait for approval before implementing. Use a dedicated planning mode when deeper exploration helps.
   - Once a scope is approved, work autonomously within it — don't re-request approval for decisions already approved, and don't interrupt flow with unnecessary approval requests.
4. **Implement**: change only what is within the approved scope; reuse existing systems. Flag unexpected major design changes before proceeding. Preserve references and serialized integrity in Godot scene (`.tscn`) and resource (`.tres`) files.
5. **Self-review**: review the diff without adding more features. Check for duplication, unnecessary complexity, violations of established patterns, node lifecycle issues, signal connection/disconnection, null or freed-instance access, and avoidable per-frame work. Don't refactor working code just to find something to change.
6. **Verify**: run available checks and give manual-test steps for anything that must be checked in the Godot editor. Never claim an unrun test passed. Help decide whether to merge or discard the branch based on verification results.

## 4. Godot Architecture Guidelines

- Use Nodes for scene behavior/composition, Resources for reusable configuration/data, Signals when decoupling is useful — don't enforce any of these mechanically.
- Watch for per-frame costs, physics-update costs, stale/freed Node references, and lifecycle issues during scene transitions or deletion.
- Take special care with `.tscn`/`.tres` serialization — preserve node paths, UIDs, and resource references exactly.

## 5. Completion Report

Keep it concise, four parts only:
- **Changes** — files added/modified and their main role.
- **Verification** — checks actually run, failures or unrun checks, manual test steps.
- **Known Limitations** — non-goals, risks, temporary code.
- **Next Decision** — merge readiness and possible follow-up refactoring (if relevant).

## 6. Reusable Prompt Template

```
[Goal] Feature or problem to address:
[Scope] What to include / exclude:
[Constraints] Technical, performance, and design requirements:
[Context] Relevant scenes/files/systems (or "investigate first"):
[Acceptance Criteria] Observable conditions for completion:
```
## Project Structure

Before adding or restructuring Godot scenes, scripts,
or resources, read `docs/structure.md`.

## Communication

Communicate with the user in Korean. Keep code, identifiers, and technical terminology in English.

## Tuning Files

Player-facing tunable values (HP, damage, cooldowns, resources such as the ultimate gauge, key timings) live in one tuning file per object scene: `<scene>_tuning.cfg` next to `<scene>.tscn` (e.g. `actors/enemies/grunt/grunt_tuning.cfg`). It is the **single source of truth**: the scene root calls `Tuning.apply(self)` (`core/data/tuning.gd`) in `_enter_tree()`, which overwrites node properties before any child `_ready()`. File values win over `.gd` defaults and `.tscn` overrides.
- Format: Godot `ConfigFile`. Section = node path from the scene root (`[.]` = root, `[Combat/Health]`), key = property name. Comments (`;`) are in Korean so the human can read and edit the file directly.
- To change a tunable value, edit the tuning file — not the `.gd` default or the `.tscn`. Unknown nodes/properties log a `[Tuning]` warning; check for it after edits.
- Projectiles/effects spawned by an object (e.g. the player's orb or ultimate) have no tuning file of their own: the spawner exports their values and passes them on spawn, so all of an object's numbers (especially every damage source) are in its one file.
- When adding a tunable value or a new object scene, add it to (or create) the tuning file and hook `Tuning.apply(self)`. When moving or removing a scene, move or remove its tuning file with it.
- When the human asks to change a number by name ("보스 체력 올려"), find it in the tuning file.
- When an export preset is created, include `*_tuning.cfg` in its non-resource export filter, or the values will be missing from builds.
