# SRM_03 — Scene 아키텍처 (Scene Tree · Node · 참조 관계)

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` · Read-Only Static Audit
> **확실성 표기**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown
> **방법**: 38개 `.tscn` 전부를 정적 파서(감사용 임시 스크립트, 프로젝트 밖 scratchpad)로 `[node]`·`[ext_resource]`·`[connection]`·`script`·`collision_layer/mask`·`groups`·`NodePath`를 추출했고, 핵심 씬(`main`, `player`, `toolkit`, `x_slash`, 이펙트 4종, `rally_dummy`)은 원문을 직접 읽었다. **아래 트리는 모두 Scene 파일에 선언된 정적 구조**이며, 실행 중 생성 구조는 §7에서 따로 다룬다.
> **관련**: [SRM_05 Player](SRM_05_Player_Deep_Dive.md) · [SRM_06 의존성](SRM_06_System_Dependencies.md) · [SRM_07 위험](SRM_07_Structural_Risks.md)

---

## 1. Scene 인벤토리 (38개) [CS]

| Scene | Root (타입) | Root Script | 노드 수 | 헤더 UID | 정적으로 참조하는 곳 |
|---|---|---|---:|---|---|
| `app/main.tscn` | Main (Node) | `app/main.gd` | 3 | 있음 | `project.godot` main_scene |
| `levels/phase1/phase1.tscn` | Phase1 (Node2D) | `phase1.gd` | 45 | 있음 | main (인스턴스 + `levels[0]`) |
| `levels/arena/arena.tscn` | Arena (Node2D) | `arena.gd` | 51 | 수기 UID | main (`levels[1]`) |
| `toolkit/toolkit.tscn` | Toolkit (CanvasLayer) | `toolkit.gd` | 5 | 있음 | main (인스턴스) |
| `toolkit/rally_dummy/rally_dummy.tscn` | RallyDummy (**knight.tscn 상속**) | `rally_dummy.gd` | 1(override) | 없음 | toolkit `Cheats.rally_dummy_scene` |
| `ui/hud/hud.tscn` | Hud (CanvasLayer) | `hud.gd` | 25 | 수기 UID | phase1, arena (인스턴스) |
| `actors/player/player.tscn` | Player (CharacterBody2D) | `player.gd` | 51 | 있음 | phase1, arena (인스턴스) |
| `actors/player/abilities/void_orb/void_orb_projectile.tscn` | VoidOrbProjectile (Node2D) | ✓ | 9 | 있음 | player `Combat/VoidOrb.projectile_scene` |
| `.../dash_slash/dash_slash_effect.tscn` | DashSlashEffect (Node2D) | ✓ | 1 | 없음 | player `Combat/DashSlash.effect_scene` |
| `.../lightning/lightning_bolt.tscn` | LightningBolt (Node2D) | ✓ | 6 | 없음 | player `Combat/Lightning.bolt_scene` |
| `.../dive/dive_blast.tscn` | DiveBlast (Node2D) | ✓ | 3 | 없음 | player `Combat/Dive.blast_scene` |
| `.../haki/haki_burst.tscn` | HakiBurst (Node2D) | ✓ | 3 | 없음 | player `haki_scene` |
| `.../moon_slash/moon_slash.tscn` | MoonSlash (Node2D) | ✓ | 10 | 없음 | player `moon_slash_scene` |
| `.../sword_wave/sword_wave.tscn` | SwordWave (Node2D) | ✓ | 8 | 없음 | player `sword_wave_scene` |
| `actors/enemies/grunt/grunt.tscn` | Grunt (CharacterBody2D) | ✓ | 15 | 수기 UID | arena `grunt_scene` |
| `.../duelist/duelist.tscn` | Duelist (CharacterBody2D) | ✓ | 16 | 수기 UID | arena `duelist_scene` |
| `.../watcher/watcher.tscn` | Watcher (CharacterBody2D) | ✓ | 16 | 없음 | arena `watcher_scene` |
| `.../watcher/watcher_needle.tscn` | WatcherNeedle (Node2D) | ✓ | 5 | 없음 | watcher `needle_scene` |
| `.../watcher/watcher_beam.tscn` | WatcherBeam (Node2D) | ✓ | 1 | 없음 | watcher `beam_scene` |
| `.../knight/knight.tscn` | Knight (CharacterBody2D) | ✓ | 35 | 없음 | arena `knight_scene`, rally_dummy (상속) |
| `.../knight/knight_cross.tscn` | KnightCross (Node2D) | ✓ | 4 | 없음 | knight `cross_scene` |
| `.../infantry/infantry.tscn` | Infantry (CharacterBody2D) | ✓ | 18 | 있음 | phase1 `infantry_scene` |
| `.../assassin/assassin.tscn` | Assassin (CharacterBody2D) | ✓ | 18 | 있음 | phase1 `assassin_scene` |
| `.../crossbowman/crossbowman.tscn` | Crossbowman (CharacterBody2D) | ✓ | 15 | 있음 | phase1 `crossbowman_scene` |
| `.../crossbowman/crossbow_bolt.tscn` | CrossbowBolt (Node2D) | ✓ | 5 | 있음 | crossbowman `bolt_scene` |
| `.../giant/giant.tscn` | Giant (CharacterBody2D) | ✓ | 20 | 있음 | phase1 `giant_scene` |
| `.../prince/prince.tscn` | Prince (CharacterBody2D) | ✓ | 28 | 없음 | phase1 `prince_scene` |
| `.../prince/prince_wave.tscn` | PrinceWave (Node2D) | ✓ | 5 | 없음 | prince `wave_scene` |
| `.../prince/prince_aura.tscn` | PrinceAura (Node2D) | ✓ | 3 | 없음 | prince `aura_scene` |
| `.../prince/prince_quake.tscn` | PrinceQuake (Node2D) | ✓ | 1 | 없음 | prince `quake_scene` |
| `.../prince/prince_clash.tscn` | PrinceClash (Node2D) | ✓ | 1 | 없음 | prince `clash_scene` |
| `combat/attacks/x_slash/x_slash.tscn` | XSlash (Node2D) | ✓ | 3 | 없음 | player `counter_slash_scene`, knight `xslash_scene` |
| `combat/effects/slash/slash.tscn` | Slash (Node2D) | ✓ | 1 | 수기 UID | player, infantry·assassin·giant·duelist·knight·prince |
| `combat/effects/spark/spark.tscn` | Spark (Node2D) | ✓ | 1 | 수기 UID | player, 모든 적, 투사체·공격 다수 |
| `combat/effects/glint/glint.tscn` | Glint (Node2D) | ✓ | 1 | 수기 UID | 근접 반짝임을 쓰는 적 (Watcher 제외) |
| `combat/effects/afterimage/afterimage.tscn` | Afterimage (Sprite2D) | ✓ | 1 | 수기 UID | player, knight, prince |
| `combat/effects/ground_impact/ground_impact.tscn` | GroundImpact (Node2D) | ✓ | 1 | 없음 | player Dive, knight, prince, arena |
| `world/props/brazier/brazier.tscn` | Brazier (Node2D) | ✓ | 8 | 수기 UID | arena (인스턴스 ×2) |

- **스크립트 없는 씬 없음** (모든 루트에 스크립트 연결) [CS].
- "헤더 UID 없음" 19개, 사람이 쓴 형태의 UID(`uid://cgruntvoider01` 등) 9개 — 손으로 작성한 `.tscn`의 흔적 [SI]. UID 참조 불일치 8건은 SRM_07 R-08.
- `combat/effects/counter_tell/`·`hit_flash/`는 씬이 없다: `CounterTell`은 Knight/Watcher/Prince 씬의 `Tell` 노드에 스크립트로 붙고, `hit_flash.gdshader`는 각 Actor `Visual`의 ShaderMaterial로 쓰인다.

---

## 2. 정적 Scene 참조 그래프 [CS]

```text
project.godot ─run/main_scene─▶ app/main.tscn
app/main.tscn
├─ instance ─▶ levels/phase1/phase1.tscn          (levels[0] = 기본)
├─ export   ─▶ levels/arena/arena.tscn            (levels[1], 치트 8)
└─ instance ─▶ toolkit/toolkit.tscn ─export─▶ toolkit/rally_dummy/rally_dummy.tscn ─inherits─▶ knight.tscn

levels/phase1/phase1.tscn
├─ instance ─▶ actors/player/player.tscn, ui/hud/hud.tscn
└─ export   ─▶ infantry · assassin · crossbowman(─▶ crossbow_bolt) · giant · prince(─▶ wave · aura · quake · clash)

levels/arena/arena.tscn
├─ instance ─▶ player.tscn, hud.tscn, world/props/brazier/brazier.tscn ×2
└─ export   ─▶ grunt · duelist · watcher(─▶ needle · beam) · knight(─▶ knight_cross · x_slash) · ground_impact

actors/player/player.tscn
├─ root export ─▶ slash · spark · afterimage · x_slash · haki_burst · moon_slash · sword_wave
└─ Combat/* export ─▶ void_orb_projectile · dash_slash_effect · lightning_bolt · dive_blast · ground_impact
```

모든 Scene 참조는 `@export var …: PackedScene` + `.tscn` 지정 방식이다 (`preload()`/`load()`로 다른 파일 경로를 하드코딩한 곳 0건 — SRM_06) [CS].

---

## 3. 주요 Scene Tree (정적 선언)

표기: `[script]`, `L=layer M=mask`, `mon=monitoring`. Audio 노드는 묶어서 표기.

### 3.1 Main — 게임 진입 [CS]

```text
Main (Node)                          app/main.gd   export levels=[Phase1, Arena], level → NodePath("Phase1")
├── Phase1 (instance phase1.tscn)    오버라이드 없음
└── Toolkit (instance toolkit.tscn)
```
- 역할: 레벨 1개 + 개발 툴킷을 담는 셸. `_enter_tree()`에서 `_level_index`가 1이면 Phase1 노드를 `free()`하고 Arena를 같은 인덱스에 끼운다 (`app/main.gd:19-30`).

### 3.2 Phase1 — 기본 레벨 (World) [CS]

```text
Phase1 (Node2D) [phase1.gd]  export: infantry/assassin/crossbowman/giant/prince_scene
├── World (Node2D)
│   ├── SkyLayer ├ Far(Sprite2D) └ MoonGlow      ← phase1.gd가 매 프레임 x를 시차 이동
│   ├── Trees · LightShafts(Polygon2D×3) · Fireflies(CPUParticles2D)
│   ├── Ground / LeftWall / RightWall (StaticBody2D, L=1 기본, M=0) ├ Visual(Sprite2D) └ CollisionShape2D
│   ├── BossGateLeft / BossGateRight (StaticBody2D)  ← phase1.gd가 visible·충돌 on/off
│   └── Foreground ├ LeavesA~C └ FernA~D           ← 시차 이동
├── Actors (Node2D)
│   └── Player (instance player.tscn)   override: position=(0,-30)
├── Projectiles (Node2D)                ← 런타임에 group "projectiles" 부여
├── Effects (Node2D)                    ← 런타임에 group "fx" 부여
├── GameCamera (Camera2D) [game_camera.gd]  override: room_limits=Rect2(-1140,-800,2280,950)
├── Vignette (CanvasLayer) └ Shade(TextureRect)
├── Hud (instance hud.tscn)
└── Audio (Node) ├ Music └ BossMusic (AudioStreamPlayer)
```

### 3.3 Arena — 구 레벨 (요약) [CS]

Phase1과 같은 Level 골격(`World / Actors / Projectiles / Effects / GameCamera / Vignette / Hud / Audio`). 차이: World에 Backwall·MoonBeams·Banners·Dust·Brazier×2(인스턴스)·Ledge×3(one-way 발판), Audio에 Banish·Rumble 추가, `room_limits = Rect2(-840,-800,1680,950)`. 적은 씬에 없고 `arena.gd`가 스폰.

### 3.4 Player [CS] (상세 책임은 SRM_05)

```text
Player (CharacterBody2D) [player.gd]  L=2 M=1(기본)  z=2
│   export: slash/spark/afterimage/counter_slash(=x_slash)/haki/moon_slash/sword_wave _scene
├── Visual (Node2D) [player_visual.gd]  material=ShaderMaterial(hit_flash)   ← 좌우 반전·스쿼시는 player.gd가 씀
│   ├── Body (Sprite2D, 9프레임 시트, use_parent_material)
│   └── Sword (Sprite2D, use_parent_material)                                 ← player_visual.gd가 회전
├── BodyCollision (CollisionShape2D, Capsule r15 h54)
├── Trail (Line2D)                                    ← 코드에서 top_level=true
├── Combat (Node2D)
│   ├── Health (Node) [health.gd]
│   ├── Hurtbox (Area2D) [hurtbox.gd]  L=8 M=0 mon=false  health → NodePath("../Health")  invincibility_duration=0.5(→ tuning 0.8)
│   ├── AttackHitbox (Area2D) [hitbox.gd]  L=32 M=16 mon=false  (Circle r36)
│   ├── ParryBox (Area2D, 스크립트 없음)  L=0 M=64 monitorable=false  (Circle r72)
│   ├── VoidOrb (Node2D) [void_orb_ability.gd]  projectile_scene, cooldown=4.0
│   ├── DashSlash (Node2D) [dash_slash_ability.gd]  effect_scene, cooldown=3.0
│   │   └── Hitbox (Area2D) [hitbox.gd]  L=32 M=16  damage=15  (Rect 260×50)
│   ├── Lightning (Node2D) [lightning_ability.gd]  bolt_scene                  ← 현재 미장착
│   ├── RisingSlash (Node2D) [rising_slash_ability.gd]                        ← 현재 미장착
│   │   └── Hitbox (Area2D) [hitbox.gd]  L=32 M=16  (Circle r120)
│   ├── SpinRise (Node2D) [spin_rise_ability.gd]
│   │   ├── Hitbox (Area2D) [hitbox.gd]  L=32 M=16 apply_on_contact=false
│   │   ├── Sensor (Area2D)  L=0 M=4 (enemy_body)
│   │   └── Effect (Node2D) [spin_rise_effect.gd]
│   └── Dive (Node2D) [dive_ability.gd]  blast_scene, impact_scene
│       └── Hitbox (Area2D) [hitbox.gd]  L=32 M=16
└── Audio (Node2D) — AudioStreamPlayer2D ×19 (Swing1~3, Hit, HitHeavy, Parry, ParryWhiff, Dash, Jump, Land, Step,
                     Hurt, Death, UltCast, UltHit, OrbCast, DashSlash, DashSlashRing, DashSlashHit)
```
- Player 씬 자체에는 group이 없다. `"player"` group은 **레벨 스크립트가 런타임에 부여**한다 (`phase1.gd:77`, `arena.gd:59`) [CS].
- `Combat/ParryBox`, `SpinRise/Sensor`는 스크립트 없는 Area2D — Player/SpinRiseAbility가 `get_overlapping_*()`로 직접 읽는다.

### 3.5 Enemy — 대표 필드몹 (Infantry) [CS]

Phase1 필드몹 4종(Infantry/Assassin/Crossbowman/Giant)과 Arena 필드몹 2종(Grunt/Duelist)은 같은 골격이다.

```text
Infantry (CharacterBody2D) [infantry.gd → extends Enemy]  groups=["field_mob"]  L=4 M=1
│   export: spark_scene, glint_scene, slash_scene
├── Visual (Node2D, hit_flash ShaderMaterial)
│   ├── Body (Sprite2D 시트)
│   └── Blade (Sprite2D)         ← 종류별 무기 이름: Blade / Dagger / Crossbow / Axe (Grunt는 없음)
├── BodyCollision (CollisionShape2D)
├── Combat (Node2D)
│   ├── Health (Node) [health.gd]
│   ├── Hurtbox (Area2D) [hurtbox.gd]  L=16 M=0  health → ../Health
│   └── AttackHitbox (Area2D) [hitbox.gd]  L=64 M=8      ← Crossbowman에는 없음 (원거리 전용)
└── Audio (Node2D) — Glint · Raise · Swing · Step · Death · Spawn …
```
- `Enemy` 기반 스크립트가 이름으로 요구하는 노드: `Visual`, `Visual/Body`, `Combat/Health`, `Combat/Hurtbox` (필수, `@onready $…`), `Combat/AttackHitbox`, `Audio/Glint|Death|Spawn` (선택, `get_node_or_null`), `BodyCollision`(접촉 피해용, 선택) — `enemy.gd:51-58, 536` [CS].

### 3.6 보스 — Knight (Arena) / Prince (Phase1) [CS]

```text
Knight (CharacterBody2D) [knight.gd]  L=4 M=1  (group 없음 — counter_threat는 코드로 부여)
├── Visual ├ Body └ Sword
├── BodyCollision
├── Tell (Node2D) [counter_tell.gd]          ← Visual 밖 (반전 방지), 카유공 예고
├── Combat
│   ├── Health · Hurtbox(L=16)
│   ├── AttackHitbox (L=64 M=8)             ← 근접 베기 (MCI 대상)
│   ├── SlamHitbox (L=0 M=8) · ShockHitbox (L=0 M=8)   ← 반격 불가
│   └── RushHitbox (L=64 M=8)               ← 돌진 (반짝임 순간 MCI 대상)
├── Sensors └ CounterGuard (Area2D, L=0 M=32, 스크립트 없음)   ← 플레이어 Hitbox 감지 (CCI 시작)
└── Audio — 13개

Prince (CharacterBody2D) [prince.gd]  groups=["counter_threat","guard_threat"]  L=4 M=1
├── Visual ├ Body └ Sword
├── Tell [counter_tell.gd]
├── BodyCollision
├── Combat
│   ├── Health (Node) [prince_health.gd → extends HealthComponent]   ← floor_hp로 페이즈 경계 고정
│   ├── Hurtbox (L=16) · AttackHitbox (L=64 M=8)
│   └── RushHitbox (L=0 M=8)
└── Audio — 13개
```

### 3.7 Watcher (공중 원거리 중간 보스급) [CS]

```text
Watcher (CharacterBody2D) [watcher.gd]  L=4 M=0 (지형 충돌 없음)   export needle_scene, beam_scene (glint_scene 없음)
├── Visual └ Body
├── BodyCollision
├── Tell [counter_tell.gd]
├── Combat ├ Health └ Hurtbox(L=16)       ← AttackHitbox 없음 (광선은 레이캐스트 히트스캔)
└── Audio — Needle · Charge · Cue · Beam · Death · Spawn
```

### 3.8 Projectile / Skill 대표 [CS]

```text
VoidOrbProjectile (Node2D) [void_orb_projectile.gd]           WatcherNeedle (Node2D) [watcher_needle.gd]
├── Visual └ Sprite2D                                         ├── Hitbox (Area2D) [hitbox.gd] L=0 M=8
├── Hitbox (Area2D) [hitbox.gd] L=32 M=16                     └── Collision (Area2D) L=0 M=1  ← 벽 감지
├── Collision (Area2D) L=0 M=1(기본)  ← 벽 감지                (CrossbowBolt, PrinceWave = 같은 골격 + 스크립트 상속)
└── Audio └ Hit

MoonSlash (Node2D)                                            SwordWave (Node2D)
├── Body (Area2D) [hitbox.gd] L=32 M=16                       ├── Body (Area2D) [hitbox.gd] L=32 M=16
├── Burst (Area2D) [hitbox.gd] L=32 M=16 mon=false            ├── Collision (Area2D) L=0 M=1
├── Collision (Area2D) L=0 M=1                                └── Audio ├ Fly └ Burst
└── Audio ├ Fly └ Burst

LightningBolt: Hitbox(L=32 M=16) ├ Path · Area (CollisionShape2D — shape는 코드에서 생성) + Audio/Strike
DiveBlast:     Hitbox(L=32 M=16) (shape를 코드에서 복제·크기 변경)
HakiBurst / XSlash: Hitbox 없음 — 그룹 탐색 후 receive_hit() 직접 호출 + Audio
```

### 3.9 UI / 툴킷 / Camera [CS]

```text
Hud (CanvasLayer) [hud.gd]                         Toolkit (CanvasLayer) [toolkit.gd]
└── Root (Control)                                 ├── DebugHud (Control) [debug_hud.gd] └ InfoLabel
    ├── Portrait (Panel) └ Face                    └── Cheats (Control) [cheats.gd]  rally_dummy_scene └ Toast (Label)
    ├── HealthBar ├ Frame Back Lag Fill Shine Label
    ├── UltBar ├ Frame Back Fill ReadyLabel        GameCamera: 별도 씬 없음. 각 레벨의 Camera2D 노드에
    ├── Hint · Tally (Label)                         camera/game_camera.gd 부착 (target은 레벨 스크립트가 코드로 지정)
    └── BossBar ├ Frame Back Lag Fill Shine Name
```

---

## 4. Scene 상속과 Property Override [CS]

| 유형 | 대상 | 내용 |
|---|---|---|
| **Scene 상속** | `rally_dummy.tscn` ← `knight.tscn` | 루트 오버라이드: `script = rally_dummy.gd`(Knight 상속), `tuning_scene = knight.tscn`. 프로젝트 유일의 씬 상속 |
| 인스턴스 오버라이드 | phase1/arena의 `Actors/Player` | `position = (0, -30)` |
| | arena의 `BrazierLeft/Right` | `position`, `z_index = -11` |
| | `GameCamera` (인스턴스 아님, 직접 선언) | `room_limits` (레벨마다 다름) |
| 씬 값 vs 튜닝 파일 | `player.tscn Combat/Hurtbox.invincibility_duration = 0.5` | `player_tuning.cfg`의 `0.8`이 런타임에 덮어씀 — 씬 값은 사실상 무효 (Tuning 규칙상 의도된 동작) |
| | `player.tscn VoidOrb.cooldown = 4.0`, `DashSlash.cooldown = 3.0`, `DashSlash/Hitbox.damage = 15` | 튜닝 파일에도 같은 값 존재 (튜닝 우선) |
| 스크립트 상속 (씬 아님) | `CrossbowBolt`, `PrinceWave` ← `WatcherNeedle` / `PrinceHealth` ← `HealthComponent` / 적 9종 ← `Enemy` / `rally_dummy.gd` ← `Knight` | SRM_06 §1 |

---

## 5. Signal 연결 [CS]

- **에디터(`.tscn`)에 선언된 `[connection]`: 0건.** 모든 Signal 연결은 스크립트의 `.connect()`로 이루어진다 (55곳, `disconnect` 0곳).
- 주요 연결 (전체 목록과 흐름은 SRM_06 §3):

| 발신 (Signal) | 수신 | 연결 위치 |
|---|---|---|
| `HurtboxComponent.hit_received` | `Player._on_hit_received`, `Enemy._on_hit_received`, `Knight._soften_hit_squash` | `player.gd:271`, `enemy.gd:87`, `knight.gd:189` |
| `HealthComponent.died` | `Player._on_died`, `Enemy._on_died`, `Knight._on_knight_died`, `Watcher._on_watcher_died` | `player.gd:272`, `enemy.gd:88`, `knight.gd:187`, `watcher.gd:68` |
| `HealthComponent.damaged` | `Prince._on_damaged`, `Hud._on_boss_damaged`, `RallyDummy._refill` | `prince.gd:215`, `hud.gd:53`, `rally_dummy.gd:21` |
| `HitboxComponent.hit_landed` / 각 Ability `hit_landed` | Player의 명중 반응 7개 | `player.gd:273-281` |
| `Player.health_changed / ultimate_changed / ultimate_ready_changed` | `Hud` | `hud.gd:86-88` |
| `Player.died` | `Phase1._on_player_died` | `phase1.gd:87` |
| `Enemy.defeated` | Phase1/Arena 스폰·보스 흐름 | `phase1.gd:183,256`, `arena.gd:102-123,220` |
| `Knight.landed` | `Arena._on_knight_landed` | `arena.gd:219` |
| `PrinceClash.pressed / finished` | `Prince` | `prince.gd:939-940` |

---

## 6. NodePath · 노드 이름 직접 의존 [CS]

`$Path` / `get_node()` 사용 횟수 (정적 카운트, 상위):

| 파일 | 횟수 | 의존하는 경로 예 |
|---|---:|---|
| `actors/player/player.gd` | 31 | `$Visual`, `$Trail`, `$Combat/Health|Hurtbox|AttackHitbox|ParryBox|VoidOrb|DashSlash|Lightning|RisingSlash|SpinRise|Dive`, `$Audio/…` 19개 (`player.gd:184-213`) |
| `actors/enemies/knight/knight.gd` | 18 | `$Visual/Sword`, `$Tell`, `$Combat/SlamHitbox|ShockHitbox|RushHitbox`, `$Sensors/CounterGuard`, `$Audio/…` |
| `levels/arena/arena.gd` | 15 | `$Actors/Player`, `$World/SkyLayer|Foreground|LedgeLeft|LedgeRight|LedgeTop`, `$Audio/…` |
| `actors/enemies/prince/prince.gd` | 14 | `$Combat/Health`(→ `PrinceHealth` 타입 가정), `$Combat/RushHitbox`, `$Tell`, `$Audio/…` |
| `levels/phase1/phase1.gd` | 13 | `$Actors/Player`, `$World/BossGateLeft|Right`, `gate.get_node("CollisionShape2D")` (`phase1.gd:301`) |
| `ui/hud/hud.gd` | 10 | `$Root/HealthBar/Fill` 등 |
| `actors/enemies/enemy.gd` | 10 | `$Visual`, `$Visual/Body`, `$Combat/Health|Hurtbox`, `$Combat`(런타임 자식 추가), `get_node_or_null("Combat/AttackHitbox"|"Audio/…"|"BodyCollision")` |
| `moon_slash.gd` / `sword_wave.gd` | 9 / 7 | `$Body/CollisionShape2D`, `$Collision/CollisionShape2D`를 `_ready`와 실행 중에도 재조회 |

부모 구조 의존 (`get_parent()` / `owner.get_parent()`) — 대부분 그룹 `fx`/`projectiles`가 없을 때의 **대체 경로**다:
`player.gd:1870`, `enemy.gd:517`, `void_orb_ability.gd:54`(owner.get_parent), `dash_slash_ability.gd:66`, `lightning_ability.gd:36`, `dive_ability.gd:72`, `watcher.gd:213`, `crossbowman.gd:192`, `void_orb_projectile.gd:155`, `watcher_needle.gd:84,107`, `dive_blast.gd:91`.
예외적으로 **대체 경로가 아니라 항상 부모에 붙이는** 곳: `x_slash.gd:79`, `moon_slash.gd:213`, `sword_wave.gd:152,176`, `haki_burst.gd:121`, `lightning_bolt.gd:151` (스폰된 이펙트가 자기 부모 = 보통 `Effects`에 스파크·표식을 붙임) [SI — 부모가 Effects라는 전제].

---

## 7. 정적 구조 vs 실행 중 동적 구조

### 7.1 런타임에 생성·변경되는 노드 [CS = 코드 존재 / 실제 트리 모양은 RU]

| 생성 주체 (파일:줄) | 생성물 | 붙는 곳 |
|---|---|---|
| `GameFeel._build_flash_layer` (`game_feel.gd:18-26`) | CanvasLayer(90) + ColorRect | `/root/GameFeel` 아래 |
| `Main._enter_tree` (`main.gd:24-30`) | Arena 인스턴스 (Phase1 `free()`) | Main |
| `Phase1._spawn_enemy` / `_spawn_prince` (`phase1.gd:176-184, 247-256`) | Infantry/Assassin/Crossbowman/Giant/Prince | `Actors` + group `"enemy"` |
| `Arena._spawn_*` (`arena.gd:95-123, 207-220`) | Grunt/Duelist/Watcher/Knight(또는 RallyDummy) | `Actors` + group `"enemy"` |
| `Enemy._build_contact_area` (`enemy.gd:533-549`) | `ContactArea`(Area2D) + CollisionShape2D (BodyCollision shape 공유) | `Combat/` |
| `Enemy.begin_glint` (`enemy.gd:211-216`) | GlintEffect | 적 루트 (반전 방지) |
| `Crossbowman._make_bar` (`crossbowman.gd:139-146`) | Line2D ×2 (경고 BAR) | 적 루트 |
| `Assassin._spawn_blink_trail/_ghost` | Line2D, Sprite2D | `fx` |
| Player `_spawn_*`, `_check_haki`, `_fire_*` (`player.gd:1367-1920`) | Slash, Spark, Afterimage, XSlash, HakiBurst, MoonSlash, SwordWave | `fx` (없으면 Player 부모) |
| Abilities | VoidOrbProjectile → `projectiles`; DashSlashEffect, LightningBolt, DiveBlast, GroundImpact → `fx` | |
| `SwordWave._explode` (`sword_wave.gd:159-164`) | `VoidMark.new()` (씬 없는 코드 전용 노드) | SwordWave의 부모 |
| `LightningBolt._ready` / `DiveBlast._ready` / `DashSlashAbility._ready` / `PrinceAura._ready` | Shape 리소스 생성·복제 | 자기 CollisionShape2D |
| Knight / Prince | KnightCross, XSlash, GroundImpact, Afterimage / PrinceAura, PrinceQuake, PrinceClash → `fx`; PrinceWave → `projectiles` | |
| 레벨 `_ready` | group 부여: Player `"player"`, Effects `"fx"`, Projectiles `"projectiles"`, 레벨 `"phase1"`/`"arena"` | |
| Knight/Watcher `_on_ready` | group `"counter_threat"` 부여 (Prince는 씬에 선언) | |

### 7.2 예상 런타임 트리 (Phase1 전투 중, 정적 분석 기반 예상 구조) [SI / RU]

```text
/root
├── GameFeel (Node, Autoload)
│   └── CanvasLayer (layer 90) └── ColorRect                     ← 런타임 생성
└── Main
    ├── Phase1                                                   group "phase1"
    │   ├── World …                                              (정적)
    │   ├── Actors
    │   │   ├── Player                                           group "player"
    │   │   ├── Infantry ×N / Assassin ×N / Crossbowman ×N / Giant ×N   group "enemy" + "field_mob"
    │   │   │   ├── Combat/ContactArea                           ← 런타임 생성
    │   │   │   ├── Glint (공격 직전 0.4초)                       ← 런타임 생성/삭제
    │   │   │   └── Line2D ×2 (석궁병 조준 중)
    │   │   └── Prince (보스 구역에서만)                          group "enemy" + "counter_threat" + "guard_threat"
    │   ├── Projectiles                                          group "projectiles"
    │   │   └── VoidOrbProjectile · CrossbowBolt · PrinceWave …
    │   ├── Effects                                              group "fx"
    │   │   └── Slash · Spark · Afterimage · XSlash · HakiBurst · SwordWave · VoidMark · DashSlashEffect
    │   │       · LightningBolt · DiveBlast · GroundImpact · PrinceAura · PrinceQuake · PrinceClash …
    │   ├── GameCamera · Vignette · Hud · Audio
    └── Toolkit (DebugHud, Cheats)
```

- 이 구조는 **정적 분석에 따른 예상**이며 실제 실행 트리를 캡처해 검증하지 않았다 [RU].
- 레벨 스크립트가 group을 부여하지 않는 다른 씬에 Player/Enemy를 두면 `"player"`/`"enemy"`/`"fx"` 탐색이 실패하거나 대체 경로로 동작한다 (SRM_07 R-05) [SI].
