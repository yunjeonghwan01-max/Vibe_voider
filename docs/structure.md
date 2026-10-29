# Structure V0 — 폴더 / Scene Tree 규칙

- 이 문서는 **현재 코드 구조를 설명하는 규칙서**다. 구조를 바꾸면 이 문서도 같이 고친다.
- 이 템플릿에서 생성한 프로젝트도 이 규칙을 그대로 이어서 사용한다.

> **Scene은 필요한 역할만 가진다. 같은 역할은 프로젝트 어디에서나 같은 문법으로 표현한다.**
>
> **기능은 발산한다. 문법은 수렴한다.**

이 규칙은 부모 클래스나 강제 Schema가 아니라 **Convention / Preset**이다.
Godot 엔진의 실제 제약이 이 문서와 충돌하면 **엔진 제약이 우선**한다 (아래 "엔진 제약에 따른 예외" 참고).

---

## 0. 템플릿 정책

이 프로젝트는 **2D 액션 게임을 Claude Code와 함께 개발하기 위한 베이스 템플릿**이다. 범용(전 장르) 템플릿이 아니다.

| 정책 | 내용 |
|---|---|
| 공통 디렉터리는 미리 생성한다 | 아래 1장의 폴더/하위 폴더는 처음부터 존재한다 (빈 폴더는 `.gitkeep`). 폴더 구조 자체가 "새 파일을 어디에 두는가"의 명시적 아키텍처다. **실제 파일이 생기면 그 폴더의 `.gitkeep`은 삭제한다.** |
| 공통 Combat Pipeline은 기본 제공한다 | `combat/components/`의 `HitboxComponent` / `HurtboxComponent` / `HealthComponent` (4장) |
| 역할 Node는 선제 생성하지 않는다 | 폴더는 미리 있지만, 빈 `Visual` / `Audio` / `Sensors` Node, 빈 Level 씬, "나중에 필요할 것 같은" Manager/Component 스크립트는 만들지 않는다. 필요해지면 그때 생긴다 |
| 게임 전용 시스템/콘텐츠는 포함하지 않는다 | Player, Enemy, Ability, Projectile, Level, Collision Layer 체계, 게임 전용 입력 액션은 템플릿에서 생성한 각 프로젝트가 만든다 |
| 같은 문법을 계속 쓴다 | 폴더 구조와 Scene Tree Vocabulary는 새 프로젝트에서도 일관되게 사용한다. 새 이름/새 구조를 발명하기 전에 기존 Vocabulary를 먼저 찾는다 |

> 원본 구조 규칙서(V0)의 "빈 폴더를 미리 만들지 않는다"는 원칙은 **이 템플릿에 한해 폴더에 대해서만** 변경했다. Node·스크립트에 대해서는 원칙을 그대로 유지한다.

---

## 1. 최상위 폴더

| 폴더 | 책임 | 하위 폴더 / 현재 내용 |
|---|---|---|
| `app/` | 게임 최상위 Shell. Level 콘텐츠를 직접 두지 않는다 | `main.tscn`, `main.gd` |
| `actors/` | 자기 상태를 가지고 행동하는 존재 | `player/`, `enemies/<enemy>/`, `npcs/` |
| `combat/` | 어느 한 Actor에 종속되지 않는 **공용 전투 언어** | `components/` (`health/`, `hitbox/`, `hurtbox/`), `attacks/` (`x_slash/`), `projectiles/`, `effects/` (`slash/` `spark/` `glint/` `afterimage/` `hit_flash/` `counter_tell/` `ground_impact/`) |
| `world/` | 살아 있지 않은 World Object / World 리소스 | `tiles/`, `platforms/`, `hazards/`, `interactables/`, `props/`, `backgrounds/` |
| `levels/` | 부품을 조립한 실제 게임 공간 | `<level>/<level>.tscn` |
| `ui/` | 플레이어용 화면 UI (개발용 UI는 `toolkit/`) | `hud/`, `menus/`, `dialogue/`, `transitions/` |
| `camera/` | Camera 자체와 공용 Camera 기능 (Rig, Shake, Follow, Limit 등) | — |
| `managers/` | **게임 전체 범위**의 상태/흐름을 실제로 조율하는 고수준 관리자 (GameManager, SceneManager, SaveManager, AudioManager 등) | — |
| `toolkit/` | 개발자용 기능 (플레이어용 UI 아님). `tool_*` 입력 액션과 대응 | `toolkit.tscn`, `toolkit.gd`, `debug_hud.gd`, `cheats.gd` (개발 치트), `asset_gen/` (오프라인 에셋 생성기) |
| `core/` | 여러 영역이 공유하는 **저수준** 기반 | `physics/`, `state/`, `data/` |
| `assets/` | 원본 Asset (이미지, 오디오, 폰트) | `characters/`, `environment/`, `effects/`, `audio/`, `fonts/`, `temporary/` |
| `docs/` | 프로젝트 문서 (이 규칙서) | `structure.md` |

### 폴더별 주의

- `managers/`: `EnemyManager`, `DoorManager` 같은 객체별 Manager는 만들지 않는다. Manager는 `core/`가 아니다. Autoload로 등록할지는 실제 필요가 생길 때 결정한다.
- `core/`: "어디 둘지 모르겠다"의 대피소가 아니다. **특정 객체에 속하지 않으며 실제로 여러 영역에서 공통 사용되는가?**에 "예"일 때만 둔다. 그래서 `utils/`는 만들지 않았다.
- `assets/temporary/`: 임시/AI 생성/플레이스홀더 Asset을 정식 Asset과 섞지 않고 격리한다.
  - Voider의 현재 픽셀아트와 사운드는 전부 코드로 생성한 것이라 여기 있다 (`characters/`, `environment/`, `effects/`, `audio/`). 생성기는 `toolkit/asset_gen/` (`sprite_gen.gd`, `audio_gen.gd`, 헤드리스 `--script`로 실행, 고정 seed). 외부 에셋이 아니므로 라이선스 문제가 없다. 정식 아트로 교체하면 해당 카테고리 폴더로 옮긴다.
- `_scenes/`, `_scripts/`, `_resources/`처럼 **파일 형식으로 나누는 폴더**와 거대한 `systems/` 폴더는 만들지 않는다.

### 판단 기준

새 파일/Scene을 만들 때 이 순서로 판단한다.

1. **주된 정체성**은 무엇인가?
   행동하는 존재 → `actors` / 전투 공통 기능·공격 → `combat` / 환경 요소 → `world` / 실제 맵 → `levels` / 화면 UI → `ui` / 카메라 → `camera` / 게임 전역 흐름 → `managers` / 개발 도구 → `toolkit` / 정말 전역적인 저수준 기반 → `core`
   - 같은 객체라도 주된 정체성에 따라 갈린다. 처치 가능한 독 식물 → `actors/enemies/poison_plant/`, 맵에 고정된 함정 → `world/hazards/poison_plant/`.
2. **누가 / 왜** 이 공격을 쓰는가 → `actors/<actor>/abilities/<name>/`
   - Ability 폴더 하나가 기술 전체를 담는다: 사용하는 쪽 `<name>_ability.gd` (Actor의 `Combat/` 아래 노드: 입력/발동 조건, 쿨다운, 스폰) + 스폰되는 쪽 `<name>_projectile.gd/.tscn` 등. 스폰물이 없는 기술(근접공격 등)은 노드 스크립트 하나만 둔다.
   - 사용처가 하나뿐이면 그 Actor 아래에 둔다. 두 번째 사용처가 실제로 생기면 그때 `combat/attacks|projectiles|effects/`로 올린다 (복제하지 않는다 — `class_name` 중복).
3. 공격과 피격 **자체가 어떻게** 작동하는가 → `combat/`
4. Raw 이미지/오디오 → `assets/`, 그것을 사용하는 Godot 리소스(`.tres`)는 사용하는 쪽 (예: TileSet → `world/tiles/`)
5. 이미 같은 의미의 문법이 있는가? 있으면 재사용한다.
6. 정말 Component / Core / Base Class가 필요한가? 재사용 근거가 생긴 뒤 분리한다.

---

## 2. 파일 명명

- 같은 기능의 Scene과 Script는 **같은 basename**: `player.tscn` + `player.gd`. (`X.tscn.gd` 형식은 쓰지 않는다)
- 파일/폴더명은 `snake_case`.
- 조작 가능한 수치가 있는 객체 씬은 같은 폴더에 수치 파일 `<씬>_tuning.cfg`를 둔다. 이 파일이 수치의 단일 출처다 (규칙은 `AGENTS.md`의 Tuning Files).
- `.tscn`, `.gd`, `.tres`는 같은 기능이면 같은 기능 폴더에 둔다.
- `.uid` 파일은 Godot이 관리한다. 스크립트를 옮길 때는 `.uid`도 함께 옮기고, 손으로 편집하지 않는다.
- 이미지를 옮길 때는 `.import`도 함께 옮긴다 (UID 유지). Asset 파일명 자체는 불필요하게 바꾸지 않는다.
- 스크립트에 다른 파일의 `res://` 경로를 직접 쓰지 않는다. 상속은 `class_name`으로, Scene 참조는 `@export var ...: PackedScene`으로 받고 값은 `.tscn`에서 지정한다 (UID로 저장되어 파일 이동에 안전).

## 3. 노드 / 입력 명명

- 노드 이름은 **PascalCase**.
- **역할 노드는 역할 이름**: `Visual`, `BodyCollision`, `Collision`, `Combat`, `Health`, `Hurtbox`, `Hitbox`, `Sensors`, `Components`, `Audio`, `InteractionArea`.
- **역할 안의 단일 leaf는 타입 이름**: `CollisionShape2D`, `AnimatedSprite2D`, `Polygon2D`, `Sprite2D`.
- 입력 액션은 `snake_case`이고 namespace로 시작한다: 게임플레이 `player_*`, 개발 도구 `tool_*`.

---

## 4. Scene Tree Vocabulary

### Actor

```text
ActorRoot (CharacterBody2D)
├── Visual          보이는 요소. 좌우 반전은 여기서만 (판정 노드를 뒤집지 않는다)
├── BodyCollision   Actor ↔ World 물리 충돌. Hitbox/Hurtbox와 별개
├── Combat          Health, Hurtbox, Ability 노드(MeleeAttack/AttackHitbox 등), 공격 관련 Timer 등
├── Sensors         감지만 한다. 판단/행동은 Actor/State가 한다
├── Components      재사용 가치가 실제로 있는 행동 Component
└── Audio
```

전부 필수가 아니다. 예를 들어 Sensor와 Audio가 없는 적은 `Visual`, `BodyCollision`, `Combat`만 가진다.

- `Sensors`: Sensor는 정보를 제공하고 행동을 결정하지 않는다. (감지 → Sensor, 판단 → Actor/State, 행동 → Actor/Component)
- `Components`: 둘 이상의 객체에서 실제로 재사용하거나 Root의 책임을 명확하게 줄일 때만 분리한다.

### 그 외 Preset

```text
Environment:   Root ├ Visual └ Collision            (필요하면 Sensors 추가)
Hazard:        Root ├ Visual ├ Hitbox └ Collision(optional)
Interactable:  Root ├ Visual ├ InteractionArea └ Components
Projectile:    Root ├ Visual ├ Hitbox ├ Collision(optional) └ Lifetime
Attack:        Root ├ Hitbox ├ Visual(optional) └ Lifetime
```

- 폴더는 객체의 **주된 정체성**, Scene Tree는 객체의 **실제 역할 구성**을 표현한다. Environment가 Sensors를 갖거나 Actor가 InteractionArea를 갖는 것은 정상적인 Composition이다.
- 같은 의미의 역할을 객체마다 다른 이름(`DetectionArea`, `AggroRange`, `TriggerThing`…)으로 만들지 않는다. 그것이 진짜 구조 붕괴다.
- 추상 Container Node는 Root 아래 한 단계를 기본으로 하고 남발하지 않는다 (`Systems/Components/CombatSystems/...` 금지).

### 타격 / 피격 문법 (Hitbox → Hurtbox → Health) — 기본 제공

모든 데미지는 이 한 경로로만 흐른다. `combat/components/`.

```text
HitboxComponent (Area2D)  ──area_entered──▶  HurtboxComponent (Area2D)  ──▶  HealthComponent (Node)
  damage, source, knockback                    receive_hit(damage, source, knockback)    hp, take_damage()
  reset_hits() 사이 같은 Hurtbox 1회             hit_received 시그널 → Actor 반응           damaged / died 시그널
  hit_landed 시그널 → 공격 쪽 연출               invincibility_duration                    died → Actor가 처리
```

| Component | 파일 | 공개 API | Signal |
|---|---|---|---|
| `HealthComponent` (Node) | `health/health.gd` | `max_hp`, `hp`, `take_damage(amount) -> bool`, `is_dead()` | `damaged(amount)`, `died` |
| `HurtboxComponent` (Area2D) | `hurtbox/hurtbox.gd` | `health: HealthComponent`, `invincibility_duration`, `invincible`, `receive_hit(damage, source, knockback) -> bool` | `hit_received(damage, source, knockback)` |
| `HitboxComponent` (Area2D) | `hitbox/hitbox.gd` | `damage`, `knockback_force`, `knockback_direction`, `apply_on_contact`, `source`, `hit_targets`, `reset_hits()` | `hit_landed(hurtbox)`, `hurtbox_entered(hurtbox)` |

- 공격 쪽은 `HitboxComponent`를 가진다. 판정 on/off는 `monitoring`으로, 중복 방지는 Hitbox가 한다.
  다단히트처럼 공격 쪽이 타이밍/데미지를 직접 정하면 `apply_on_contact = false`로 두고 `hurtbox_entered`를 받아 `receive_hit()`을 직접 호출한다.
- `source`가 비어 있으면 Hitbox의 `owner`(씬 루트)가 공격자다. 투사체는 스폰한 Actor를 `source`에 넣는다.
- 맞는 쪽은 `Combat/Health` + `Combat/Hurtbox`(→ `health` export 연결)를 가진다. Actor 스크립트는 `take_damage()`를 갖지 않고 시그널로만 반응한다.
- 피격 대상을 `area.owner` / `has_method()`로 찾지 않는다. `HurtboxComponent` 타입으로 판별한다.
- 컴포넌트는 씬에 저장된 노드로 쓰는 것을 기본으로 한다. `owner`가 없으면(코드로만 생성) `HealthComponent` 로그와 `HurtboxComponent` 경고는 컴포넌트 자신의 노드 이름을 쓴다.
- `take_damage()`는 피격마다 `[Health] <owner> HP: x/y`를 `print`한다 (디버그 로그).

### Collision Layer 원칙

템플릿은 구체적인 레이어 번호/이름을 정하지 않는다 (게임마다 진영 구성이 다르다). 레이어를 정할 때 다음 원칙을 따른다.

- 레이어 이름은 `project.godot`의 `[layer_names]`에 정의한다. 코드에서 상수가 필요하면 `core/physics/collision_layers.gd`에 같은 번호로 둔다.
- "땅을 밟는 바디"와 "공격/피격 트리거"를 서로 다른 노드·레이어로 분리한다.
- 바디(CharacterBody2D)는 world만 mask한다.
- Hitbox(Area2D)는 상대 진영의 Hurtbox 레이어만 mask한다.
- Hurtbox(Area2D)는 layer만 가지고 mask는 0 (스스로 감지하지 않고 감지당하기만 한다).

#### 이 게임의 실제 레이어 배치 (Voider)

`project.godot`의 `[layer_names]`와 `core/physics/collision_layers.gd`(상수)에 정의한다.

| # | 이름 | 쓰는 곳 | layer | mask |
|---|---|---|---|---|
| 1 | `world` | Ground/Walls/Platforms (StaticBody2D) | 1 | 0 |
| 2 | `player_body` | Player (CharacterBody2D) | 2 | world |
| 3 | `enemy_body` | Enemy (CharacterBody2D) | 4 | world |
| 4 | `player_hurtbox` | Player Hurtbox | 8 | 0 |
| 5 | `enemy_hurtbox` | Enemy Hurtbox | 16 | 0 |
| 6 | `player_hitbox` | Player AttackHitbox | 32 | enemy_hurtbox |
| 7 | `enemy_hitbox` | Enemy AttackHitbox | 64 | player_hurtbox |

- 바디는 world만 mask → 플레이어와 적은 서로 밀지 않고 통과한다(근접전에서 몸싸움 노이즈 제거).
- **반격 불가 투사체**: 감시자의 바늘(`WatcherNeedle`)은 Hitbox layer를 0으로 둔다 (mask=`player_hurtbox`만). ParryBox가 감지하지 못하므로 반격 대상이 아니다 — 피해야 하는 공격.
- **패링 예외**: 플레이어 `Combat/ParryBox`(Area2D)는 mask=`enemy_hitbox`(64)로 적 공격 판정을 직접 감지한다. 패링 창이 열린 동안 적 Hitbox를 감지하면 패링 성공으로 처리한다. 적 Hitbox는 `enemy_hitbox` layer를 켜 두므로 ParryBox가 감지할 수 있다(이것이 Hurtbox가 아닌 Area2D가 상대 Hitbox를 감지하는 유일한 지점).
- 피격/패링 연결은 씬의 NodePath 직렬화에 의존하지 않고 Actor의 `_ready()`에서 `hurtbox.health = health`로 코드 연결한다(손으로 작성한 `.tscn`에서 노드 타입 export가 안정적으로 풀리지 않는 경우 대비).

### Level

```text
LevelRoot (Node2D)
├── World         TileMap, Platforms, Hazards, Interactables, Props, Background 등
├── Actors        Player, Enemies, NPCs
├── Projectiles   런타임 투사체 Container
├── Effects       런타임 이펙트 Container
├── SpawnPoints   (필요할 때)
├── Audio         레벨 배경 음악·환경음 (필요할 때)
└── CameraPoints  (필요할 때)
```

- 새 맵을 만들기 위해 `main.tscn`을 복제하지 않는다. `levels/<name>/<name>.tscn`을 만들고 Main 아래에 인스턴스한다.
- 런타임 스폰물(투사체/이펙트)은 생성 주체의 `get_parent()`에 붙이지 않고 Level의 `Projectiles` / `Effects` Container에 붙인다 (스폰 위치가 생성 주체의 부모 구조에 의존하지 않게).
  - Actor에 붙어 다녀야 하는 이펙트는 그 이펙트를 만든 노드(반전되지 않는 노드)의 자식으로 붙이고 좌우 반전은 값으로 넘긴다.
- 필요 없는 Container는 Scene의 목적에 따라 생략한다.

### Main

```text
Main (Node)
├── <CurrentLevel>   현재 Level 인스턴스 (Level이 생기면)
└── Toolkit          항상 켜진 개발 툴킷 (PROCESS_MODE_ALWAYS)
```

`CurrentLevel` 같은 분류용 컨테이너는 두지 않는다. 런타임 Level 교체 코드가 생겨서 삽입 지점이 실제로 필요해지면 그때 만든다.

---

## 5. 현재 실제 Scene Tree (Voider — 달빛 성소 한 방)

```text
Main (Node)                                   app/main.tscn   (run/main_scene)
├── Arena (Node2D)                            levels/arena/arena.tscn   (arena.gd)
│   ├── World (Node2D)
│   │   ├── SkyLayer (하늘+달, 시차 스크롤)     arena.gd가 카메라 x에 맞춰 느리게 움직인다
│   │   ├── Backwall / MoonBeams / Banners / Dust / BrazierLeft·Right (world/props/brazier/)
│   │   ├── Ground / LeftWall / RightWall      StaticBody2D: Visual(Sprite2D) + CollisionShape2D
│   │   ├── LedgeLeft / LedgeRight / LedgeTop  one-way 발판
│   │   └── Foreground (사슬, 시차 스크롤)
│   ├── Actors (Node2D) └ Player              actors/player/player.tscn
│   ├── Projectiles (Node2D, group "projectiles") 런타임 투사체 (장풍 구체)
│   ├── Effects (Node2D, group "fx")          슬래시/스파크/잔상이 여기 붙는다
│   ├── GameCamera (Camera2D)                 camera/game_camera.gd  (follow + lookahead + shake + room_limits + focus: 보스전엔 보스도 함께 화면에 담는다)
│   ├── Vignette (CanvasLayer 1)              화면 가장자리 어둡게
│   ├── Hud (CanvasLayer 2)                   ui/hud/hud.tscn  (초상화 + 체력/잔상 바 + 궁극기 바 + 감시자 처치 수 + 보스 체력 바)
│   └── Audio  Music(평소 루프) / BossMusic(보스전 루프) / Banish / Rumble
└── Toolkit (CanvasLayer)                     toolkit/toolkit.tscn  (디버그 HUD는 기본 숨김, F1 / Cheats: 백틱+숫자 개발 치트)

Player (CharacterBody2D)                       actors/player/player.gd
├── Visual (Node2D, player_visual.gd)          좌우 반전/스쿼시는 Visual에서만. hit_flash 머티리얼
│   ├── Body (Sprite2D, 9프레임 시트)           idle/run×4/jump/fall/hurt/dash
│   └── Sword (Sprite2D)                       따로 회전하는 검 — 콤보/반격/대시/궁극기 자세
├── BodyCollision (CollisionShape2D)
├── Trail (Line2D, top_level)                  대시/궁극기 잔광
├── Combat (Node2D)
│   ├── Health / Hurtbox(+CollisionShape2D)
│   ├── AttackHitbox(+CollisionShape2D)        콤보 판정 (code로 on/off·데미지)
│   ├── ParryBox (Area2D, 항상 monitoring)      반격 키를 누른 순간 반짝이는 적 Hitbox를 읽는다
│   ├── VoidOrb (Node2D, VoidOrbAbility)        장풍: 쿨다운 + 구체 스폰 (abilities/void_orb/)
│   ├── DashSlash (Node2D, DashSlashAbility)    대시 중 E 대시 참격: 쿨다운 + Hitbox(긴 사각형) + 궤적 (abilities/dash_slash/)
│   │   └── Hitbox(+CollisionShape2D)
│   ├── Lightning / RisingSlash                 벼락·승천 참격 — 1페이즈 슬롯에서는 빠져 있다 (장착하면 쓸 수 있다)
│   ├── SpinRise (Node2D, SpinRiseAbility)      회전 상승: Hitbox(틱) + Sensor(운반 대상) + Effect(회오리) (abilities/spin_rise/)
│   └── Dive (Node2D, DiveAbility)              강하: Hitbox(몸 접촉) + 착지 폭발 스폰 (abilities/dive/)
└── Audio (AudioStreamPlayer2D들)

Enemy (CharacterBody2D)  actors/enemies/enemy.gd (base) → grunt/, duelist/, watcher/, knight/(보스)
├── Visual (Node2D, hit_flash 머티리얼 local_to_scene)
│   ├── Body (Sprite2D, 9프레임 시트)
│   └── Blade (Sprite2D)                        듀얼리스트만
├── BodyCollision (CollisionShape2D)
├── Combat └ Health / Hurtbox / AttackHitbox
└── Audio  Glint / Swing·Lunge / Death / Spawn
```

- **반격(패링) 규칙**: 적의 모든 공격은 휘두르기 직전 `glint_duration`(0.4초) 동안 금빛으로 반짝인다 (`Enemy.begin_glint()/end_glint()/is_glinting()`, `combat/effects/glint/` 별빛 + glint 사운드). 플레이어가 그 순간 반격 키를 누르면 `ParryBox`에 겹친 반짝이는 적 중 **바라보는 쪽**(방향키를 함께 누르면 그쪽)의 가장 가까운 **하나**가 `on_parried()`로 경직된다 — 동시에 뜬 두 공격은 따로 눌러야 한다. 성공하면 앞쪽(`counter_sweep_reach` 95)으로 올려 베어 범위 안의 일반 적(그룹 `field_mob`, 다른 반짝임 제외)을 모두 기절시킨다(피해 없음). 반짝임이 없을 때 누르면 헛반격(무적 없음, 0.5초 재사용 대기 — 연타로는 못 맞춘다).
- **연쇄 반격**: 반격(근접 반짝임/카유공)에 성공하면 `chain_window`(0.2초, 게임 시간 — 반격 연출의 hit-stop 동안 줄지 않음) 동안 반격 키를 다시 누를 수 있다. 누르면 "예약"되어 창이 끝날 때까지 유효하고, 그 사이 반짝임/카유공이 생기면 자동으로 받아친다(받아칠 때마다 창이 다시 열려 계속 이어짐, 반격음이 점점 높아진다). 끝까지 대상이 없으면 헛반격 페널티 없이 끝난다. 예약 입력은 `player.gd`의 `_process`에서 읽어 hit-stop 중에도 놓치지 않는다. 처음 성공시킨 그 입력으로는 예약되지 않는다.
- **패기 방출**(`actors/player/abilities/haki/`, `HakiBurst`): 연쇄 반격이 `haki_every`(3)번째로 이어질 때마다(3·6·9…) 발동. 반격 연출 뒤에 스폰해 슬로모션이 덮이지 않게 한다. 화면을 덮지 않는 노바: 0.28초 모으기(플레이어 주변 핏빛 고리가 조여듦) → 방출(짧은 검붉은 번개 화살 32개가 한꺼번에 사방으로 + 같은 속도의 얇은 충격파 고리). 카메라 화면 안의 모든 적(그룹 `enemy`)이 고리가 닿는 순간 `receive_hit(haki_damage=20)`, 맞은 자리에서 작은 번개가 지직거린다. 궁극기 게이지 +50. 연출은 실제 시간으로 흐른다.
- 번쩍임(피격/반짝임/경직)은 `combat/effects/hit_flash/hit_flash.gdshader`를 Visual에 두고 자식은 `use_parent_material`로 칠한다 (어두운 픽셀아트는 modulate로는 밝아지지 않는다).
- 모든 아트는 "1 아트 픽셀 = 2px" 밀도이고 Sprite2D `scale = 2`로 쓴다. 프로젝트 기본 텍스처 필터는 Nearest.

- `GameFeel` (Autoload, `managers/game_feel.gd`): `hit_stop(duration)` 프리즈 프레임(실시간 복구 타이머), `shake(trauma)`는 `GameCamera.current`로 전달.
- 전투 손맛(hit-stop/shake/슬래시·스파크·잔상)은 명중·패링·사망 순간에 적용한다. VFX는 외부 이미지 없이 `_draw`로 그린다 (`combat/effects/slash|spark|afterimage/`).
- 입력 액션(추가분): `player_jump`(Space만) `player_attack` `player_parry` `player_dash` `player_skill`(E) `player_ultimate` + `player_move_left/right`에 A/D 추가, `player_move_up`(↑/W)·`player_move_down`(↓/S)은 스킬 슬롯을 고르는 방향 수식키. W/↑는 점프가 아니다. 점프는 공중에서 한 번 더 할 수 있다(더블 점프, `air_jumps` 1회, 착지 시 충전, 발밑 보랏빛 고리).
- `Toolkit` (`toolkit.gd`): `tool_toggle_hud` / `tool_restart` / `tool_pause` (`tool_cheat`를 누르고 있는 동안은 무시 — 숫자 보조 키 충돌 방지).
- **개발 치트** (`Toolkit/Cheats`, `toolkit/cheats.gd`, 목록은 `docs/cheats.txt`): `tool_cheat`(백틱 키)를 누른 채 숫자 키(물리 키 KEY_1~9로 읽고 입력을 소비). 1 = `Player.force_chain_burst()` (3단 연쇄 반격 → 패기 방출), 2 = `Arena.summon_boss_now()` (그룹 `arena`로 찾는다, 적 추방 후 지진 없이 곧장 낙하). 발동하면 화면 위에 이름을 잠깐 띄운다.
- **카유공(카운터 유도 공격)** — 감시자(`actors/enemies/watcher/`, 공중 원거리 중간 보스급 적 — 금장 갑각·가시 왕관·후광·칼날깃 날개, 잡몹보다 크다):
  - 평소: 플레이어 위쪽 옆(`hover_distance`/`hover_height`)을 떠다니며 바늘(`watcher_needle.gd/.tscn`, 반격 불가)을 쏜다. 날아다니므로 `_apply_gravity`를 감속으로 오버라이드하고 몸은 지형과 충돌하지 않는다(mask 0, `fly_bounds` 안에 머문다 — 레벨이 스폰 때 지정).
  - CHARGE 2초(금빛 입자가 점점 빠르게 몸 중앙으로, 공용 `combat/effects/counter_tell/` (`CounterTell`)) → WINDOW 0.4초(거대한 + 섬광 + 조준선) → 못 받아치면 히트스캔 광선(`watcher_beam.gd` 겉모습). CHARGE/WINDOW는 슈퍼아머.
  - 광선은 **확정 피격**: 맞히기 직전 대상 Hurtbox의 `invincible`을 끄고 `receive_hit()` (대시 무적/다른 적 반격 중 무적도 뚫는다). 지형에만 막히며, 그래서 CHARGE/WINDOW 동안 시야(world 레이, one-way 발판 포함)가 막히면 시야가 트이는 자리로 스스로 옮긴다.
  - 반격: `Enemy.is_counter_open()` / `Enemy.on_countered(from_pos)` (기본은 없음 — 감시자가 오버라이드)와 그룹 `counter_threat`. 플레이어가 반격 키를 누르면 ParryBox의 반짝이는 근접 공격을 먼저 처리하고, 그게 없을 때만 열린 카유공을 **방향·거리 무관**하게 받아친다 (= 다른 적 반격에 쓴 입력으로는 광선을 막지 못한다).
  - 받아친 카유공이 여럿이면 한 번에 가장 가까운 하나만. X자가 되돌아가는 길(플레이어 → 발사자 선분, 폭 `counter_path_width`)에 있던 다른 적은 `counter_path_damage`(20)를 입는다.
  - 반격 성공 → 공용 `combat/attacks/x_slash/` (`XSlash`): 세상을 거의 멈춘 채(GameFeel) 실제 시간으로 검보라 X자 두 획을 새기고 결정타 순간 `receive_hit()`. 데미지는 Player가 `enemy.counter_strike_damage(counter_damage=999)`로 묻는다 (감시자 = 즉사, 보스는 오버라이드, 0이면 X자 없이 경직만). XSlash는 보스도 쓴다(카유공 실패 시 플레이어 몸에 붉은 X자, `pierce_invincibility`).
- 적 전용 기술(돌진/참격)은 현재 각 적 스크립트 안에 있다. 두 번째 사용처가 생기면 `combat/attacks/`로 올린다.
- **추방**: `Enemy.banish()` — 쓰러뜨린 게 아니라 싸움 밖으로 내쫓는다(`defeated`를 보내지 않으므로 다시 나타나지 않는다). 공허로 빨려 들어가듯 위로 늘어나며 사라진다. 하위 클래스 정리 훅 `_on_banished()`.
- **보스 — 월식의 기사**(`actors/enemies/knight/`, `Knight`, 체력 1800, 플레이어의 약 3배 크기 갑옷 기사):
  - 등장(임시 흐름, `arena.gd`): 감시자를 `watchers_for_boss`(3)번 쓰러뜨리면 → 남은 적 추방 + 음악 끊김 → 지진(천장 부스러기, `rumble.wav`) → 떨어질 자리에 그림자가 짙어지며 하늘에서 "쿵"(바닥 균열·발판 금, `landed` 시그널) → 포효 → 보스 음악·보스 체력 바·카메라 `focus`. 보스를 쓰러뜨리면 4초 뒤 평소 음악과 적들이 돌아오고 처치 수가 0부터 다시 센다.
  - 패턴: ① 돌격 베기 — 어디든(공중 포함) 플레이어 바로 앞까지 미끄러져 와서 반짝임(0.4초) 후 베기, 가끔 2연격(ParryBox 반격) ② 카유공 검기 — 공중으로 떠올라 한 손을 들고 `CounterTell` 충전 2초 → + 섬광 0.4초(방향 무관 반격 → X자 180 피해 + 추락·경직 2.4초) → 실패 시 플레이어 몸에 붉은 `XSlash`(34, 무적 관통) ③ 반격 자세(쿨 6초) — 0.4초 은빛 초승달 방패, `Sensors/CounterGuard`(mask=player_hitbox)에 **켜져 있는** 플레이어 Hitbox가 닿으면 막고 → 역반격 창(`BAIT`, 실제 시간 0.5초, `GameFeel.hit_stop(0.5, 0.1)`로 세상이 거의 멈춤): 화면이 어두워지고 부딪힌 자리에 금·은빛 X자 문장 `KnightCross`(`knight_cross.tscn`, 연출 전용·실제 시간, 바깥 고리가 좁혀 들며 남은 시간 표시, `time_stop.wav`) — 그 사이 방향 무관 반격 = 역반격(X자 160 + 경직 2.8초, 문장이 부서짐). 슬로모션 중엔 물리 프레임이 드물어서 Player가 그 동안의 반격 입력을 `_process`에서 모아 둔다. 놓치면 문장이 붉게 식고 플레이어 머리 위로 순간이동 → 붉은 경고 기둥 0.38초 → 내려찍기(`SlamHitbox` + 착지 `ShockHitbox`, layer 0 = 반격 불가) ④ 돌진(쿨 12초) — 바닥 끝으로 미끄러져 물러남 → 웅크려 붉은 경로선 0.8초 → 가속 돌진(`RushHitbox`), 플레이어 바로 앞(같은 높이)에 다가오는 순간만 0.15초 반짝임(ParryBox·방향 무관 반격 둘 다 인정) → 반격 시 스턴 3.6초, 아니면 반대쪽 벽에 부딪혀 벽이 깨진다.
  - **랠리**(확률 구조, 입력은 아직 일반 반격 키): ③에서 반격 자세에 걸린 첫 맞부딪힘에서 `recounter_open_chance`(0.6)로 역반격 창이 열릴지 굴린다 (랠리로 보스가 다시 받아친 맞부딪힘은 항상 열린다). 안 열리면 X자 문장·슬로모션 없이 `closed_clash_time`(0.2초) 붉게 맞부딪힌 뒤 곧장 내려찍기 — 무엇을 눌러도 소용없다(`is_counter_open()`이 false). 열리면 창이 열리는 순간 "이번 역반격에 보스가 다시 받아칠지"(`_bait_rally`)를 `rally_chance`(0.3) + 오간 역반격 수 × `rally_chance_boost`(0.3) (최대 0.85)로 미리 굴려 X자 색으로 보여 준다(금·은 = 받아치면 무너짐, 푸른빛 = 다시 받아침). 다시 받아치면 X자 결정타 없이(`counter_strike_damage` 0) `on_countered()`가 새 맞부딪힘을 연다. `rally_max`(5)번 오가면 반드시 무너진다. 확률은 입력 전에 정해지므로 성공한 입력의 결과를 뒤집지 않는다. 수치는 `knight_tuning.cfg`.
  - 선택: 돌진이 준비되면 돌진, 반격 자세가 준비되고 플레이어가 가까우면 반격 자세, 그 외엔 근접:원거리 = 2:1 (섞인 주머니).
  - 보스는 항상 슈퍼아머(`_has_armor`)라 평타로는 경직되지 않는다 — 반짝임 반격·카유공 반격·돌진 반격으로만 무너진다. 날거나 순간이동할 때는 중력과 world 충돌을 끈다(`_set_float`). 방 바닥/좌우 끝/천장은 레벨이 스폰 때 넣는다.
  - 아트: `assets/temporary/characters/knight/` (`knight.png` 16프레임 + 따로 회전하는 `knight_sword.png`), 프레임별 손 위치는 생성기 `_gen_knight`와 `Knight.HAND_ART`가 같아야 한다.
- **지형 파괴 연출**: 공용 `combat/effects/ground_impact/` (`GroundImpact`, `_draw`): `crack_ground`(방사형 균열 — 처음엔 보랏빛으로 타오름 + 튀는 돌조각 + 흙먼지), `crack_wall`, `crack_ledge`, `rain_rubble`. 충돌 판정은 바꾸지 않는 겉모습이다.
- **궁극기 — 검격 날리기**(`actors/player/abilities/sword_wave/`, `SwordWave` + `VoidMark`, 1페이즈 `slot_ultimate`): 0.6초 시전(무적·체공, 검끝으로 빛이 모임) 뒤 반달 검기를 날린다 — 비행은 월아 참격과 같다(느리게 시작해 지수 가속). 첫 적·벽에 닿으면 원형 폭발(반지름 220, 50 피해, 넉백 0): 범위 안의 모든 적(그룹 `enemy`)에 `VoidMark`를 붙인다. 아무것도 맞히지 못하고 화면 밖으로 나가면 소멸. 표식은 적을 따라다니다 2초 뒤 터져 반지름 140 안의 모든 적에게 10 — 피해만(표식 노드가 그룹 `no_flinch`라 `Enemy`가 넉백·경직을 건너뛴다), 새 표식은 만들지 않고 겹친 폭발은 중복으로 들어간다. 표식이 붙은 적이 죽으면 `Enemy.hold_corpse()`로 시체가 표식이 터질 때까지 남는다. 피해는 `HakiBurst`처럼 각 적의 Hurtbox에 직접 `receive_hit()`.
- **궁극기 — 월아 참격**(`actors/player/abilities/moon_slash/`, `MoonSlash`, `slot_ultimate = "moon_slash"`로 장착): Player가 발사(`ult_windup` 0.14초 뒤, 시전 중 무적·공중 체공)만 하고 나머지는 투사체가 처리한다. 속도 = `start_speed × e^(growth × t)` (처음엔 느리다가 지수적으로 빨라짐, 최대 2600). 본체(`Body` Hitbox, 반달 앞쪽 캡슐 r44·h250)가 적에게 닿으면 그 순간 겹친 적 전부 1타 20(평타 2배) + 띄우기 후 처음 닿은 적의 자리에서 깨진다(벽이면 반달 몸통 자리, 사거리 끝은 그냥 소멸). 깨진 자리에 양옆으로 벌어지는 열린 회오리 `vortex_time`(0.32초) → 위로 긴 사각형 `Burst` Hitbox(340x540, 깨진 높이 아래 70 ~ 위 470)로 폭발, 2타 40(평타 4배) + 크게 띄우기. 두 Hitbox 모두 적마다 1회. 모양은 일부러 불완전하다: 반달 안쪽 날 톱니·바깥 날 이 빠짐·끊긴 흰 심, 기둥은 찢긴 가장자리·가시 왕관·옆 가시·균열선 (주기적으로 다시 흔든다).
- **에어본**: `Enemy`가 위쪽 넉백이 `LAUNCH_THRESHOLD`(-400)보다 강한 피격을 받으면 착지할 때까지 HITSTUN을 유지하고 몸이 뒤로 기운다 (나는 적은 `MAX_AIRBORNE` 1.4초 뒤 풀림, 슈퍼아머 중엔 띄워지지 않음). 컴포넌트 계약은 그대로 — 띄우기는 넉백 벡터의 크기로만 전달한다.
- 플레이어 전투 기술(콤보/패링/대시)은 지금은 `player.gd`에 모아 feel을 빠르게 튜닝한다. 스킬의 시전 자세(상태 머신)도 `player.gd`에 있고, 스킬 노드(`Combat/<Skill>`)는 쿨다운·판정·스폰만 맡는다.
- **스킬 슬롯**: 스킬 키(E)는 입력 슬롯으로 스킬을 고른다 — `slot_neutral` / `slot_up`(위+E) / `slot_down`(아래+E) / `slot_dash`(대시 중·대시와 동시·대시 직후 유예의 E, 방향키보다 우선) + 궁극기 키 `slot_ultimate`. 값은 스킬 이름 문자열이고 `player_tuning.cfg`에서 바꾼다 (1페이즈: 장풍 / 회전 상승 / 강하 / 대시 참격 / 검격 날리기). 방향 우선순위는 아래 > 위 > 기본, 쿨다운 중이면 다른 슬롯으로 새지 않는다. 평타 후딜·회전 상승 마무리에서도 같은 슬롯 규칙으로 이어 쓴다. 새 스킬은 `player.gd`의 `_can_cast_skill()` / `_cast_skill()`에 이름을 추가한다.
- 스폰물이 있는 스킬은 `actors/player/abilities/<name>/`에 둔다. 첫 스킬 **장풍**(`void_orb/`):
  - `void_orb_ability.gd` (`Combat/VoidOrb`): 쿨다운·발사. 입력 우선순위와 시전 자세(반동/공중 체공/캔슬)는 `player.gd`의 `Action.SKILL`이 정한다.
  - `void_orb_projectile.gd/.tscn` (Projectile 프리셋: `Visual` / `Hitbox` / `Collision` / `Audio`): 몸 중심에서 발사, 적 관통 + 다단히트(Hitbox `apply_on_contact = false`, 겹친 적을 `hit_interval`마다 최대 `max_hits_per_target`회 `receive_hit`, 히트당 25) + 적마다 첫 타 큰 넉백(`first_knockback`), 이후 짧은 넉백. `Collision`(mask=world)에 벽이 닿거나 카메라 화면 끝(진행 방향)을 넘으면 소멸하고, one-way 발판은 통과한다. 반격으로 시전을 언제든 끊을 수 있다.
- 두 번째 스킬 **대시 참격**(`dash_slash/`): 대시와 동시에, 또는 대시 중 E → 대시가 끝난 뒤 조금 더 파고들며 수평으로 긴 참격.
  - `dash_slash_ability.gd` (`Combat/DashSlash`, 자식 `Hitbox`): 쿨다운·판정 설정/on·off·궤적 스폰. 예약·전진·캔슬은 `player.gd`의 `Action.DASH_SLASH`.
  - `dash_slash_effect.gd/.tscn`: `_draw`로 그리는 길고 선명한 수평 칼빛(4겹 + 평행 잔상 + 베어낸 자국 + 끝점 별빛, 판정 길이와 맞춘 270px). 스폰물이라 기술 폴더에 둔다.
  - 판정: `Hitbox` 기본 260x50, 중심이 몸 앞 116px (앞으로 약 246px까지). 대시로 지나온 길도 벤다: Player가 대시 시작점을 기억해 지나온 거리(+여유 40, 최대 360)를 `begin(caster, dir, back)`으로 넘기면 판정 사각형과 칼빛이 그만큼 뒤쪽(대시 시작점)까지 늘어난다 (판정 Shape은 `_ready`에서 복제해 쓴다). 전용 사운드: 시전 `dash_slash.wav`(바람) + `dash_slash_ring.wav`(칼날 울림), 명중 `dash_slash_hit.wav`.
  - 입력 규칙: 대시 중 E는 장풍이 아니라 대시 참격 예약이다. E를 먼저 누르고 장풍이 나가기 전(0.06초)에 대시를 누르면 동시 입력으로 보고 대시 참격으로 바꾼다.
  - 유예 시간(코요테 타임식): 대시를 끝까지 탄 뒤 `dash_slash_grace`(0.12초) 안에 누른 E도 대시 참격이다. 그 뒤의 E는 방향 슬롯.
  - 대시 무적(대시 후 숨은 무적 포함)은 참격으로 이어지지 않는다. 반격으로 참격을 언제든 끊을 수 있다.
- **회전 상승**(`spin_rise/`, 1페이즈 위 슬롯): `spin_windup` 웅크림(체공) → 회오리에 잠겨 `spin_rise_height`(300)까지 상승(감속 도착) → 마무리. 좌우 입력은 수평 가속도(`spin_side_accel`, 관성 유지)이고 시작 지점 좌우 `spin_side_range`(90) 밖으로 못 나간다. 벽·천장에 닿으면 즉시 멈춘다. 예비 동작·상승 중 무적(`spin_invincible`, 실험값), 반격으로 끊으면 휩쓸린 적을 놓고 상승 관성은 남는다. 마무리 중엔 평타/대시/반격/스킬로 이어 쓸 수 있다(공중 반복).
  - `spin_rise_ability.gd`: 상승 "진행도"에 맞춘 틱(`tick_count` 10, 합계 `total_damage` 25 — 정수 누적 경계로 나눠 합이 정확). `Sensor`(mask=enemy_body)가 그룹 `field_mob` 적을 `Enemy.begin_carry()`로 몸 앞뒤에 휘말아 함께 올리고, 끝나면 `end_carry()`로 위로 튕겨 놓는다. 그 외(보스 등)는 겹친 틱만 맞는다. `spin_rise_effect.gd`: `_draw` 회오리(빛무리·나선 리본·입자), 회전하지 않는 `Combat` 아래.
  - `Enemy.State.CARRIED`: 위치를 운반자가 정하고 피격은 번쩍임만. 벽·발판에 걸려 운반자와 `CARRY_SNAG_DISTANCE` 이상 벌어지면 위쪽 관성을 남기고 빠진다.
- **강하**(`dive/`, 1페이즈 아래 슬롯): 살짝 떠오름 → 체공(자세 고정) → 머리부터 급강하(시작 순간 좌우 입력으로 `dive_angle` 20° 기울기, 이후 고정, 몸이 뒤집힌다) → 착지 후 불꽃이 솟을 때까지 행동 불가. 강하 중 맞으면 피해만 받고 계속한다(`_on_armored_hit`). 떠오름·체공·급강하는 반격으로 끊을 수 있다(`dive_counter_cancel`, 실험값).
  - `dive_ability.gd`: 급강하 중 몸 접촉 `Hitbox`(경로의 적마다 1회, `body_damage` 임시 10). `land()`가 떨어진 높이(시작 → 착지, `bonus_height` 450까지 직선)로 작렬+불꽃 합계 35~55를 정하고 7:3으로 나눠 `DiveBlast`와 공용 `GroundImpact` 균열을 스폰한다.
  - `dive_blast.gd/.tscn`: 착지 지점 양옆 `blast_half_width`(150) × 높이 150 판정. 작렬(겹친 적 전부, 바깥·위 넉백) → 바닥에서 불씨 예고 → `flame_delay`(0.35초) 뒤 범위 전체에서 불꽃이 한꺼번에 솟아 그때 겹친 적 전부 피해(작렬을 안 맞은 적도).
- 세 번째 스킬 **벼락**(`lightning/`): 위(W/↑)를 누른 채 E. 쿨다운 2초 (쿨다운 중이면 아무것도 나가지 않는다 — 장풍으로 새지 않게).
  - `lightning_ability.gd` (`Combat/Lightning`): 쿨다운·번개 스폰. 시전 자세는 `player.gd`의 `Action.LIGHTNING`: 이동 불가, 공중이면 `travel_time`(0.15초) 동안 떠 있다가 도달 후 `lightning_recovery`만큼 더 굳는다(반격으로만 끊김).
  - `lightning_bolt.gd/.tscn` (Attack 프리셋, Effects 컨테이너): 전조 → 도달 시 Hitbox on. 판정 = 하늘→도달점 기둥(`Hitbox/Path`) + 도달점 원(`Hitbox/Area`, r120), 적마다 1회 20 데미지(평타 2배), 바깥으로 넉백 + 맞은 적마다 약한 흔들림. 판정은 한 번이지만 번개는 `linger_time`(0.75초) 동안 남아 `PULSES`대로 몇 번 더 내리치듯 맥동하고, 갈래 번개가 자라며 도달점에서 전기 줄기가 위쪽·바닥을 따라 퍼진다. 번개 모양은 실제 시간으로 계속 다시 그려 hit-stop 중에도 요동친다.
- 스킬 입력 우선순위 정리: 궁극기 > 반격 > 대시 중/동시/직후 유예 시간의 E → 대시 슬롯 (방향키를 누르고 있어도) > 아래+E → 아래 슬롯 > 위+E → 위 슬롯 > E → 기본 슬롯.

---

## 6. 엔진 제약에 따른 예외

| 항목 | 내용 | 이유 |
|---|---|---|
| `BodyCollision` | 컨테이너가 아니라 `CollisionShape2D` 노드 자체의 이름 | CharacterBody2D의 충돌 모양은 직계 자식이어야 동작한다 |
| `Collision` (Area2D, 지형 감지용) | layer 0이어도 `monitorable`은 켜 둔다 | `monitorable = false`인 Area2D는 TileMap 바디를 감지하지 못한다 (Godot 4.7 확인) |
| `Lifetime` | 별도 노드가 필요할 만큼의 로직이 없으면 스크립트 변수(`max_lifetime` 등)로 대체해도 된다 | 빈 역할 Node를 만들지 않는다 |
| 반전되면 안 되는 표시 노드 (`Label` 등) | `Visual` 밖, Root 직속에 둔다 | `Visual` 아래에 두면 좌우 반전 때 글자가 뒤집힌다 |

## 7. 개정

이 문서는 영구 불변 규칙이 아니다. 특정 역할 Node가 계속 빈 Node가 되거나, 두 폴더의 책임 경계가 계속 애매하거나, AI가 규칙을 반복적으로 오해하면 개정한다.
수정 기준은 "더 이론적으로 아름다운가?"가 아니라 **"실제 제작 마찰을 줄이는가?"**다.
