# SRM_06 — 시스템 의존 관계와 실행 흐름

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` · Read-Only Static Audit
> **확실성 표기**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown
> **주의**: 모든 흐름은 소스 코드를 따라간 **정적 추적**이다. 실제 실행 순서·타이밍은 검증하지 않았다 [RU]. Godot 엔진 내부 동작(물리 콜백 순서 등)에 의존하는 단계는 [SI]로 표시한다.
> **관련**: [SRM_03 Scene](SRM_03_Scene_Architecture.md) · [SRM_05 Player](SRM_05_Player_Deep_Dive.md) · [SRM_07 위험](SRM_07_Structural_Risks.md)

---

## 1. 상속 · `class_name` 관계 [CS]

### 1.1 상속 트리

```text
CharacterBody2D
├── Player
└── Enemy                                  (actors/enemies/enemy.gd — 씬 없음)
    ├── Grunt · Duelist · Watcher           (Arena)
    ├── Infantry · Assassin · Crossbowman · Giant   (Phase1 필드몹)
    ├── Knight ── (rally_dummy.gd, class_name 없음)
    └── Prince
Node        ── HealthComponent ── PrinceHealth
Area2D      ── HitboxComponent, HurtboxComponent
Node2D      ── WatcherNeedle ── CrossbowBolt, PrinceWave
            ── PlayerVisual, 각 Ability(6), 스폰물(MoonSlash, SwordWave, VoidMark, HakiBurst, LightningBolt, DiveBlast,
               DashSlashEffect, SpinRiseEffect, VoidOrbProjectile), 이펙트(Slash, Spark, Glint, CounterTell, GroundImpact),
               XSlash, KnightCross, PrinceAura, PrinceQuake, PrinceClash, WatcherBeam, Arena, Phase1
Sprite2D    ── Afterimage
Camera2D    ── GameCamera
Node        ── Main, (GameFeel — class_name 없음)
RefCounted  ── Tuning, CollisionLayers
SceneTree   ── sprite_gen.gd, audio_gen.gd (오프라인 도구)
```

- `class_name` 중복 없음. `class_name` 없는 스크립트: `game_feel.gd`(Autoload 이름으로 접근), `hud.gd`, `toolkit.gd`, `debug_hud.gd`, `cheats.gd`, `brazier.gd`, `rally_dummy.gd`, 생성기 2개.
- 스크립트 상속 깊이 최대 3 (`CharacterBody2D → Enemy → Knight → rally_dummy`).

### 1.2 Enemy 훅 오버라이드 현황 [CS]

| 하위 클래스 | 오버라이드 |
|---|---|
| Grunt / Infantry / Assassin | `_on_ready`, `_enemy_ai`, `_animate`, `_on_hurt`, `_on_parried_react`, `_on_stagger_end` |
| Duelist | 위 + `_has_armor` |
| Crossbowman | 위(−`_on_stagger_end`) + `_on_banished`, `_on_died`(super 호출) |
| Giant | 위 + `_has_armor`, **`on_parried`(공개 메서드 오버라이드 — 2단 MCI 분기)** |
| Watcher | `_apply_gravity`, `_has_armor`, `_on_banished`, `is_counter_open`, `on_countered` + 사망은 **`health.died`에 별도 핸들러 연결** (`_on_watcher_died`) |
| Knight | `_begin_spawn`, `_apply_gravity`, `_can_contact`, `_die_dissolve`, `_has_armor`, `is_counter_open`, `on_countered`, `counter_strike_damage` + 사망은 **별도 핸들러 연결** (`_on_knight_died`) + `hit_received`에 두 번째 핸들러 |
| Prince | `_apply_gravity`, `_can_contact`, `_has_armor`, `_on_banished`, `_on_died`(super), `is_counter_open`, `on_countered`, `counter_strike_damage`, `is_guard_open`, `on_guarded`, **`on_parried`** |

[SI] 사망 처리 확장이 두 방식(`_on_died` 오버라이드 vs `health.died` 추가 연결)으로 나뉘어 있다 — SRM_07 R-12.

---

## 2. 직접 참조 · Resource 로딩 [CS]

### 2.1 `preload()` / `load()` / `res://`

- 게임 런타임 스크립트에서 **다른 파일 경로를 하드코딩한 곳: 0건.** 씬은 전부 `@export var …: PackedScene`로 받는다 (Structure V0 §2 규칙 준수).
- 예외: `core/data/tuning.gd:16-20` (씬 경로에서 `_tuning.cfg` 경로를 계산해 `ConfigFile.load`), `toolkit/asset_gen/*`의 출력 경로 상수 `res://assets/temporary/…` (도구).

### 2.2 타입(클래스)으로 직접 참조하는 관계 — 주요

| 참조하는 쪽 | 참조 대상 (타입·필드·메서드) |
|---|---|
| `Player` | `Enemy`(+`Enemy.State`), `WatcherNeedle`, `HitboxComponent`, `HurtboxComponent`, `HealthComponent`, `PlayerVisual`, Ability 6종, `XSlash`, `HakiBurst`, `MoonSlash`, `SwordWave`, `SlashEffect`, `SparkEffect`, `Afterimage`, `Tuning`, `GameFeel` |
| `Prince` | **`Player`**(`Player.Action`, `action`, `hurtbox`, `health`, 공개 메서드 4개), `PrinceHealth`, `PrinceWave`, `PrinceAura`, `PrinceQuake`, `PrinceClash`, `CounterTell`, `CollisionLayers` |
| `Assassin` | **`Player`**(`facing`), **`Infantry`**(`_atk`, `_atk_elapsed`, `Infantry.Atk`) |
| `Giant` | **`Infantry`**, **`Assassin`** (비공개 `_atk`, `_atk_elapsed`) |
| `Infantry` | 다른 `Infantry` 인스턴스의 비공개 `_atk`, `_atk_elapsed` |
| `SpinRiseAbility` | `Enemy.begin_carry` / `end_carry` |
| `VoidMark`, `SwordWave`, `HakiBurst` | `Enemy.state`, `Enemy.hurtbox`, `Enemy.hold_corpse`, `Enemy.NO_FLINCH_GROUP` |
| `Phase1` | `Player`, `Prince`(`room_x`, `floor_y`, `debug_next_stage`, `health`), `Enemy`(`banish`, `defeated`), `GameCamera`(`target`, `room_limits`, `focus`) |
| `Arena` | `Player`, `Knight`(`floor_y`, `room_x`, `ceiling_y`, `landed`), `Watcher`(`fly_bounds`), `Enemy`, `WatcherNeedle`, `GroundImpact` |
| `Hud` | `Player`(시그널 + `health`, `ult_charge`, `ultimate_max`, `is_ultimate_ready`), `HealthComponent` |
| `Cheats` | `Player`, `Arena`, `Phase1`, `Main` (공개 메서드만) |
| `GameFeel` ↔ `GameCamera` | `GameCamera.current.add_trauma()` |

### 2.3 순환 의존 [CS 참조 / SI 해석]

- **`Player` ↔ `Prince`**: Player는 `Enemy` API(`is_guard_open`, `on_guarded`)를 부르고, Prince는 `Player` 타입·내부 필드를 부른다 — 클래스 수준 양방향 의존. GDScript는 `class_name` 순환을 허용하므로 컴파일 문제는 아니지만, 두 파일이 서로의 내부 구현에 묶인다.
- **`Player` ↔ `Enemy`** (약한 순환): Player → `Enemy` 반격 API, Enemy → Player의 `is_contact_hit` 판독 계약(Enemy가 공개 플래그를 세우고 Player가 시그널 핸들러에서 읽음). Enemy는 Player 타입을 직접 참조하지 않는다(group `"player"`로 `Node2D` 취급).
- **필드몹 간 상호 참조**: `Giant → Assassin → Infantry`, `Giant → Infantry` — 단방향이지만 비공개 필드 의존.

---

## 3. Signal 기반 통신 [CS]

- 선언 24개 (§3.1), 코드 연결 55곳, 에디터 `[connection]` 0곳, `disconnect` 0곳. 연결 해제는 노드 해제에 맡긴다.

### 3.1 선언된 Signal

| Signal | 선언 | 수신자 |
|---|---|---|
| `HealthComponent.damaged(amount)` | `health.gd:7` | Prince, Hud(보스 바), RallyDummy |
| `HealthComponent.died` | `health.gd:8` | Player, Enemy, Knight, Watcher |
| `HurtboxComponent.hit_received(damage, source, knockback)` | `hurtbox.gd:8` | Player, Enemy, Knight(두 번째 핸들러) |
| `HitboxComponent.hit_landed(hurtbox)` | `hitbox.gd:11` | Player(평타), Ability 4종(재방출), WatcherNeedle(자기 파괴), Prince(RushHitbox) |
| `HitboxComponent.hurtbox_entered(hurtbox)` | `hitbox.gd:12` | VoidOrbProjectile, LightningBolt, MoonSlash(2), SwordWave |
| Ability/스폰물 `hit_landed` (7종) | void_orb(2), dash_slash, dive(2), lightning(2), rising_slash, spin_rise(+`last_tick`) | Ability가 스폰물 것을 재방출 → Player |
| `VoidOrbAbility.ready_again` | `void_orb_ability.gd:9` | Player (쿨다운 끝 반짝임) |
| `PlayerVisual.footstep` | `player_visual.gd:9` | Player |
| `Player.health_changed / ultimate_changed / ultimate_ready_changed` | `player.gd:34-36` | Hud |
| `Player.died` | `player.gd:37` | Phase1 (Arena는 연결하지 않음) |
| `Enemy.defeated(enemy)` | `enemy.gd:17` | Phase1, Arena |
| `Knight.landed` | `knight.gd:30` | Arena |
| `PrinceClash.pressed / finished(won)` | `prince_clash.gd:9-10` | Prince |

### 3.2 Signal 사용 특징 [SI]

- **Signal은 "아래 → 위" 통지(컴포넌트 → Actor, Actor → 레벨/HUD)에 쓰이고, "위 → 아래" 또는 "Actor ↔ Actor"는 직접 메서드 호출**이다. Player ↔ Enemy 반격 상호작용은 Signal을 쓰지 않는다.
- 동일 Signal에 핸들러 순서를 전제한 곳: `Knight._soften_hit_squash`는 "기반 핸들러 다음에 불린다"는 연결 순서를 전제한다 (`knight.gd:188-189`). `RallyDummy._refill`은 `HealthComponent.take_damage`가 `damaged`를 `died` 판정 전에 emit한다는 내부 순서를 전제한다 (`rally_dummy.gd:29-32`, `health.gd:29-36`).

---

## 4. Autoload · 전역 상태 · 시간 [CS]

| 전역 요소 | 쓰는 곳 | 읽는 곳 |
|---|---|---|
| Autoload `GameFeel` | — | `GameFeel.*` 호출 **120줄 / 16개 파일** (주석 줄 제외; Player 43, Knight·Prince·스폰물·XSlash·Enemy 등) |
| `Engine.time_scale` | `GameFeel.hit_stop`만 (`game_feel.gd:45,50`) | Player `_process` (304, 307) |
| `static var GameCamera.current` | `GameCamera._ready/_exit_tree` | `GameFeel.shake` |
| `static var Main._level_index` | `Main.cycle_level` | `Main._enter_tree` (씬 재로드 후에도 유지) |
| 실제 시간(`Time.get_ticks_*`) 기반 로직 | XSlash, HakiBurst, LightningBolt, KnightCross, Knight(역반격 창 `_bait_end_ms`), Enemy(`hold_corpse`), GameCamera(흔들림 노이즈) | — |

**시간 기준이 세 가지다** [CS/SI]: ① 물리/게임 시간(`delta`, `time_scale`에 비례), ② 실제 시간(`Time.get_ticks_usec`, `create_timer(…, ignore_time_scale=true)`), ③ hit-stop 중에도 도는 `_process` 입력 수집. Knight의 역반격 창은 ②로 재고, Player는 ③으로 입력을 모아 ①의 다음 물리 프레임에 소비한다. 이 계약은 코드 주석으로만 기술되어 있다 (`player.gd:306`, `knight.gd:172`, `structure.md` §5).
`GameFeel.hit_stop`은 마지막 호출이 이전 복구를 무효화하는 토큰 방식이라(`game_feel.gd:43-50`), 긴 슬로모션(역반격 창 `hit_stop(0.5, 0.1)`) 도중 다른 짧은 `hit_stop`이 호출되면 time_scale과 복구 시점이 바뀐다 [SI/RU].

---

## 5. Group 사용 [CS]

| Group | 부여하는 곳 | 조회하는 곳 | 용도 |
|---|---|---|---|
| `player` | **레벨** `phase1.gd:77`, `arena.gd:59` | `enemy.gd:182`, `cheats.gd:53` | 적의 타깃 |
| `enemy` | **레벨** 스폰 시 (`phase1.gd:182,255`, `arena.gd:101,111,122,218`) | Player(`_strike_counter_path`), SwordWave, VoidMark, HakiBurst, Phase1/Arena(추방) — 7곳 | 범위 피해·추방 대상 |
| `field_mob` | 각 필드몹 `.tscn` (6종) | Player `_counter_sweep`, SpinRise(운반), Infantry/Assassin/Giant(간격 조정) — 5곳 | 일반 적 분류 |
| `counter_threat` | Knight·Watcher **코드** (`_on_ready`), Prince **씬** | Player `_open_counter_threats` | RCI 후보 |
| `guard_threat` | Prince **씬** | Player `_open_guard_threat` | 방어 경로 후보 |
| `deflectable` | WatcherNeedle **코드** (`_ready`) | Player `_deflectable_needles` | PRCI 후보 |
| `no_flinch` (`Enemy.NO_FLINCH_GROUP`) | VoidMark 코드 | Enemy `_on_hit_received` (source의 group) | 경직 없는 피해 |
| `fx` | **레벨** (`Effects` 노드) | `get_first_node_in_group("fx")` 9곳 + 대체 경로 | VFX 컨테이너 |
| `projectiles` | **레벨** (`Projectiles` 노드) | VoidOrbAbility, Watcher, Crossbowman, Prince — 4곳 | 투사체 컨테이너 |
| `main` / `arena` / `phase1` | 각 스크립트 자신 | Cheats | 치트 진입점 |

[SI] Group이 사실상 **서비스 로케이터 + 이벤트 없는 질의 시스템** 역할을 한다. `player`/`enemy`/`fx`/`projectiles`는 레벨 스크립트가 부여하므로, Actor 씬의 정상 동작이 "레벨 스크립트가 그룹을 붙여 줬다"는 전제에 의존한다 (SRM_07 R-05). 같은 개념(`counter_threat`)이 씬 선언(Prince)과 코드(Knight, Watcher) 두 방식으로 부여된다.

---

## 6. Scene 인스턴스 생성과 제거 [CS]

| 생성 주체 | 생성물 | 부모 | 제거 |
|---|---|---|---|
| Phase1 / Arena | 적 (`instantiate` → `position` → `add_child` → `add_to_group("enemy")` → `defeated.connect`) | `Actors` | 사망: `Enemy._die_dissolve` 트윈 → `queue_free` / 추방: `banish` 트윈 → `queue_free` |
| Player | 이펙트·XSlash·HakiBurst·MoonSlash·SwordWave | `fx` (없으면 Player 부모) | 각자 수명 후 `queue_free` |
| Ability 노드 | 투사체/스폰물 | `projectiles` 또는 `fx` (없으면 `owner.get_parent()`) | 각자 |
| 적·보스 | 바늘/볼트/웨이브 → `projectiles`, 연출 → `fx`, Glint·조준 BAR → 자기 루트 | | 각자 (Prince는 `_quake_fx`, `_clash`를 직접 `queue_free`) |
| Main | Arena (Phase1 `free()`) | Main | 씬 재로드 |
| SwordWave | `VoidMark.new()` (코드 전용) | SwordWave의 부모 | 폭발 후 `queue_free` |

- 오브젝트 풀링 없음. 스폰물은 대부분 `_draw()` 기반이라 인스턴스 비용이 작다 [SI].
- 레벨 정리: `Phase1._clear_field`는 `projectiles.get_children()`를 모두 `queue_free`, Arena는 `WatcherNeedle`만 골라 지운다 — 같은 "필드 정리" 개념의 다른 구현 (`phase1.gd:226-232`, `arena.gd:166-172`).

---

## 7. Resource 공유 상태 [CS]

- 적 `Visual`의 hit_flash `ShaderMaterial`은 9개 적 씬 모두 `resource_local_to_scene = true` — 인스턴스마다 번쩍임이 독립적이다. Player 것은 local이 아니지만 인스턴스가 하나라 문제없다.
- 크기를 실행 중 바꾸는 Shape는 공유 Resource를 건드리지 않도록 `duplicate()`한다: DashSlashAbility(`dash_slash_ability.gd:27`), DiveBlast(`dive_blast.gd:43`), PrinceAura(`prince_aura.gd:37`). LightningBolt는 새 Shape를 생성. RisingSlashAbility는 **복제 없이** `CircleShape2D.radius`를 직접 바꾼다(`rising_slash_ability.gd:40`) — Player 인스턴스가 하나라 현재 영향은 없음 [SI].
- `Enemy._build_contact_area`는 `BodyCollision.shape`를 그대로 공유(읽기만) (`enemy.gd:545`).

---

## 8. InputMap과 입력 처리 구조 [CS]

```text
InputMap (project.godot)
├── player_* ──▶ Player (polling: Input.is_action_just_pressed / is_action_pressed / get_axis — 39곳)
│               └─ player_parry 예외: PrinceClash._process도 직접 polling (Player는 LOCKED로 무시)
├── tool_*   ──▶ Toolkit._unhandled_input (tool_cheat를 누르는 동안 무시)
└── 숫자 키   ──▶ Cheats._unhandled_input (physical_keycode, set_input_as_handled)
```

- 게임플레이 입력은 **이벤트 기반(`_unhandled_input`)이 아니라 폴링**이며, 입력 → 의도(intent) 변환 계층이 없다. 우선순위는 `_process_free`의 `if` 순서(`player.gd:398-427`)와 각 액션 함수의 캔슬 순서로만 표현된다.
- 입력 버퍼링: 점프 버퍼(`_jump_buffer`), 콤보 버퍼(`_attack_buffered`), 대시 참격 예약(`_dash_slash_queued`) + 유예(`_dash_slash_window`), 연쇄 반격 예약(`_chain_armed`), 슬로모션 반격 버퍼(`_counter_buffered`) — 각각 별도 변수.

---

## 9. Collision Layer / Mask 사용 [CS]

레이어 정의는 SRM_02 §4.4. 코드에서 마스크를 바꾸는 곳:
- `Knight._set_float` / `Prince._set_float`: `collision_mask = 0 | CollisionLayers.WORLD` (비행·순간이동 중 지형 무시).
- `Knight._begin_slam_fall`: `collision_mask = 0` (발판 관통 낙하).
- `Enemy._on_died` / `banish`: `collision_layer = 0`, Hurtbox `monitoring/monitorable` 끔.
- 레이캐스트: `Watcher._fire_beam` (WORLD | PLAYER_HURTBOX, areas 포함), `Assassin/Crossbowman/Giant._ray` (WORLD), `Knight._find_target_hurtbox` (점 쿼리, PLAYER_HURTBOX).
- 판정 겹침 직접 조회: Player `parry_box.get_overlapping_areas()`, SpinRise `sensor.get_overlapping_bodies()`/`hitbox.get_overlapping_areas()`, DiveBlast·PrinceAura `get_overlapping_areas()`, Knight `counter_guard.get_overlapping_areas()`(+`hb.monitoring` 확인), VoidOrbProjectile `hitbox.overlaps_area()`.

---

## 10. 대표 실행 흐름 (파일 · 함수 단위)

### 흐름 A — 플레이어 평타: 입력 → 공격 판단 → 판정 활성 → 충돌 → 피해 → 피격 반응 [CS / 물리 콜백 SI]

| # | 단계 | 파일 : 함수 (줄) | 상태·통신 |
|---|---|---|---|
| 1 | 입력 | `player.gd : _process_free` (421) | `Input.is_action_just_pressed("player_attack")` 폴링 |
| 2 | 공격 판단 | `player.gd : _start_attack` (619–640) | `action = ATTACK`, `_combo_index`, `AttackHitbox`의 `position/damage/knockback_*` 직접 설정, `reset_hits()`, `visual.play`, Slash VFX 스폰(`fx`) |
| 3 | 판정 활성 | `player.gd : _process_attack` (659–664) | 경과 시간이 windup~active 사이면 `attack_hitbox.monitoring = true` (공격 "객체"를 생성하지 않고 상주 Area2D를 켠다) |
| 4 | 충돌 감지 | Godot 물리 → `Area2D.area_entered` → `hitbox.gd : _on_area_entered` (32) | L=32/M=16 ↔ 적 Hurtbox L=16. `area as HurtboxComponent`, `hit_targets` 중복 검사 [엔진 콜백 SI] |
| 5 | 피해 적용 | `hitbox.gd:43` → `hurtbox.gd : receive_hit` (17–31) → `health.gd : take_damage` (24–38) | 무적·사망 검사 → `hit_received.emit` → `hp` 감소 → `damaged.emit` → (0이면) `died.emit` |
| 6 | 피격 반응 (적) | `enemy.gd : _on_hit_received` (353–383) → 하위 `_on_hurt` | 번쩍임, 넉백(`velocity +=`), HITSTUN/에어본, 하던 공격 취소 (`attack_hitbox.monitoring = false`, `end_glint`) |
| 7 | 사망 (적) | `enemy.gd : _on_died` (420–435) → `defeated.emit` → `phase1.gd : _on_enemy_defeated` (187) | 레벨이 분대 전멸·다음 웨이브·보스 구역 판단 |
| 8 | 공격자 손맛 | `hitbox.gd:45 hit_landed.emit` → `player.gd : _on_attack_landed` (698–709) | `GameFeel.hit_stop/shake`, SFX, `_add_ultimate` → `ultimate_changed` → `hud.gd` |
| 9 | 콤보 연결 | `player.gd : _process_attack` (682–687) | `_attack_buffered`면 `_start_attack(index+1)` |

### 흐름 B — 적 근접 공격과 MCI 반격 [CS]

| # | 단계 | 파일 : 함수 (줄) |
|---|---|---|
| 1 | 예고 → 반짝임 | `infantry.gd : _enemy_ai` RAISE→FLASH (72–78) → `enemy.gd : begin_glint` (206–216): `_glinting = true`, GlintEffect 스폰 |
| 2 | 반격 입력 | `player.gd : _process_free`(403) 또는 각 액션의 캔슬 분기 → `_start_parry` (1185) |
| 3 | 대상 판정 | `player.gd : _glinting_attackers` (1231–1246): `ParryBox`(M=64)와 겹친 `HitboxComponent`의 `source as Enemy` 중 `is_glinting()` + 바라보는 방향 |
| 4 | 성공 처리 | `_open_chain`(1381) → `hurtbox.invincible = true` → `_trigger_parry_success`(1451): `GameFeel`, `_add_ultimate(34)`, **`enemy.on_parried()` 직접 호출** → `_counter_sweep`(1259: `field_mob` 앞쪽 범위 기절) → `_check_haki`(1390) |
| 5 | 적 반응 | `enemy.gd : on_parried` (397–412) → STAGGER, `_on_parried_react` 훅 (Giant/Prince는 `on_parried` 자체 오버라이드) |
| 6 | 실패 시 | FLASH 종료 → `infantry.gd : _begin_strike` (156–170) `attack_hitbox.monitoring = true` → 흐름 A의 4~6을 반대 방향으로 (Player 쪽: `player.gd : _on_hit_received` 1668 → HURT, `_stop_abilities`) |

### 흐름 C — 카유공(RCI): Watcher [CS]

1. `watcher.gd : _begin_charge` (217) → CHARGE 2초 (`CounterTell` 표시) → `_begin_window` (226) → `is_counter_open()` true 0.4초 (238).
2. Player 반격: `_start_parry` → 반짝임 없음 → `_open_counter_threats` (group `counter_threat`) → `_start_counter([nearest])` (1323).
3. `enemy.counter_strike_damage(999)` → `enemy.on_countered()` (Watcher 304) → `_spawn_counter_slash` (1367): `XSlash` 생성(`fx`) → `x_slash.gd : _process` 실제 시간 0.14초 → `_strike` (61): `target.receive_hit(damage)` → Watcher 사망. 동시에 `_strike_counter_path` (1352): group `enemy` 중 선분 근처 적에게 `receive_hit(20)`.
4. 실패: `watcher.gd : _fire_beam` (247): 레이캐스트 → `hurt.invincible = false` → `hurt.receive_hit(35)` (무적 관통).

### 흐름 D — 튕겨내기(PRCI) [CS]

`watcher_needle.gd : _update_glint` (61: 플레이어와의 거리 ≤ `deflect_range`) → `is_deflectable()` → `player.gd : _deflectable_needles` (group `deflectable`) → `_deflect_needle` (1301) → `needle.deflect()` (75) → `queue_free`. CrossbowBolt·PrinceWave는 `WatcherNeedle` 상속으로 같은 경로를 탄다.

### 흐름 E — 스킬(장풍): 입력 → 투사체 생성 → 다단 피해 → 궁극기 충전 [CS]

| # | 파일 : 함수 (줄) |
|---|---|
| 1 | `player.gd : _process_free` (415) → `_held_skill_slot()` → `"void_orb"` → `_can_cast_skill` → `void_orb.can_cast()` |
| 2 | `_cast_skill` (457) → `_start_skill` (713) → `_process_skill` (727) → windup 후 `_fire_skill` (760) |
| 3 | `void_orb_ability.gd : cast` (36–49): 쿨다운, `projectile_scene.instantiate()`, 수치 7개 대입, `hit_landed` 재방출 연결, `projectiles` group 노드에 `add_child` |
| 4 | `void_orb_projectile.gd : _physics_process` (51) 이동 → Hitbox(`apply_on_contact=false`) `hurtbox_entered` → `_on_hurtbox_entered` (79) → `_try_hit` (98): `hurt.receive_hit()` 직접 → `_tick_multi_hits`가 `hit_interval`마다 반복 |
| 5 | `hit_landed.emit` → `VoidOrbAbility.hit_landed` → `player.gd : _on_skill_hit` (772) → `_add_ultimate(3)` |
| 6 | 소멸: 벽(`Collision.body_shape_entered`, one-way 발판 제외) / 화면 끝(`_past_screen_edge`) / 거리 → `_dissipate` → 소리 끝나면 `queue_free` |

### 흐름 F — 레벨 전환과 오브젝트 생성 [CS]

```text
게임 시작: project.godot main_scene → Main._enter_tree (_level_index 0 → 그대로) → Phase1._enter_tree (Tuning.apply)
         → Player/… _enter_tree·_ready → Phase1._ready: group 부여 → camera.target · hud.bind · 음악 → _spawn_squad()
레벨 전환(치트 8): Cheats._run(KEY_8) → Main.cycle_level() → _level_index = 1 → reload_current_scene.call_deferred()
         → 새 Main._enter_tree: Phase1 free() → Arena instantiate → add_child/move_child → Arena._ready → _spawn_wave()
Phase1 웨이브: Enemy.defeated → _on_enemy_defeated(_wave_id 토큰) → _alive==0 → await wave_delay → squads_for_boss 도달?
         ├ 아니오 → _spawn_squad()
         └ 예 → _enter_boss_zone(): _clear_field(banish) → 음악 정지 → _set_gates(true) → camera.room_limits
               → _place_fighters_and_summon(): Player 위치 직접 이동 → await → _spawn_prince() → hud.show_boss · camera.focus
Prince 처치 → _on_prince_defeated(_fight_counter 토큰) → await → 게이트 열기 → _spawn_squad()
Player 사망 → Player.died → Phase1._on_player_died → await boss_retry_delay → Prince banish → 재소환 (Player는 자체 _respawn_after(1.4)로 부활)
```
- 씬 전환은 `reload_current_scene` 하나뿐이다. SceneManager·로딩 화면·세이브는 없다 [CS].

### 흐름 G — Prince 패턴 4 방어 경로 (Player ↔ Prince 양방향) [CS]

1. `prince.gd : _do_quake` → `_open_quake_flash` → `_guard_open = true` → `is_guard_open()` (840).
2. Player: `_process`(time_scale<1, 304) 또는 `_physics_process`(325) → `_try_guard` (1471) → group `guard_threat` → `enemy.on_guarded()` → Prince `_guarded = true` (845).
3. 충격 순간 `prince.gd : _quake_impact` (785): 막았으면 `p.on_guard_impact(strength)` (812, Player 공개 메서드) / 못 막았으면 `p.hurtbox.invincible = false`(819, `quake_pierce`) → `p.hurtbox.receive_hit(...)` (821).
4. 패턴 5: `_begin_clash` (921) → `p.begin_event_lock()` → `PrinceClash`가 `player_parry`를 직접 폴링 → `finished(won)` → 승리 `p.event_final_strike(self, health.hp)` / 패배 `p.end_event_lock()` + `p.hurtbox.receive_hit(p.health.hp, …)` (971).

### 흐름 H — Knight 반격 자세 → 역반격(CCI) 랠리 [CS 코드 / RU 타이밍]

1. `knight.gd : _begin_guard` (595): `hurtbox.invincible = true`, `CounterGuard.monitoring = true`.
2. `_enemy_ai` GUARD (314) → `_guard_was_hit` (607): `CounterGuard`에 **monitoring이 켜진** `HitboxComponent`가 겹침 → `_guard_triggered` → `_clash` (631).
3. `_clash`: 창 개방 확률(`recounter_open_chance`) → 열리면 `_bait_rally` 미리 결정 → `GameFeel.hit_stop(bait_time=0.5, 0.1)` (세상 10% 속도) → `KnightCross` 스폰 → `_bait_end_ms` = 실제 시간 기준 마감.
4. Player: 느린 세상에서 `_process`가 반격 입력을 `_counter_buffered`로 모음 (307) → 다음 물리 프레임 `_start_parry` → `_open_counter_threats`(Knight `is_counter_open`: BAIT & `_bait_open`) → `_start_counter` → `counter_strike_damage`(랠리면 0) → `on_countered` (860): 랠리면 `_clash()` 재진입, 아니면 STAGGER(2.8초) + XSlash(160).
5. 마감 경과: `_end_bait` (670) → BLINK → `_appear_above_target` → HANG → `_begin_slam_fall` → `SlamHitbox`/`ShockHitbox`(layer 0 = 반격 불가).

---

## 11. 정적 분석으로 확정하기 어려운 동적 의존 [UK/RU]

| 항목 | 이유 |
|---|---|
| `hud.bind()`, `hud.show_boss()` 등 | `Hud`에 `class_name`이 없고 레벨은 `CanvasLayer` 타입으로 들고 있어 정적 타입 검사가 없다 — 메서드 존재는 코드로 확인했으나 연결 실패는 런타임에만 드러난다 |
| `target.get("facing")` (GameCamera) | duck typing |
| group 조회 전체 | 어떤 노드가 그룹에 있는지는 런타임 상태 |
| `Tuning.apply`의 노드 경로·속성 | 정적 스크립트로 12개 파일 전부 대응 확인 (SRM_10 §4) — 실행 시 경고 유무는 RU |
| `hit_stop` 중첩, `_process`/`_physics_process` 입력 경합, 무적 플래그 경합 | 타이밍 의존 (SRM_07 R-01, R-02, R-07) |
| UID 불일치 참조 8건의 로딩 결과 | Godot이 경로로 대체 로드하는지, 경고만 내는지 실행으로 확인 필요 (SRM_07 R-08) |
