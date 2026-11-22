# SRM_04 — GDScript 인벤토리 (규모 · 책임 · 의존성)

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` · Read-Only Static Audit
> **확실성 표기**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown
> **관련**: [SRM_05 Player](SRM_05_Player_Deep_Dive.md) · [SRM_06 의존성](SRM_06_System_Dependencies.md) · [SRM_07 위험](SRM_07_Structural_Risks.md) · [SRM_10 범위](SRM_10_Audit_Coverage.md)

---

## 1. 측정 방법

| 지표 | 정의 | 도구 |
|---|---|---|
| **Physical Lines** | 파일의 전체 물리적 줄 수 (`awk 'END{print NR}'`) | 셸 (읽기 전용) |
| **Code Lines** | 공백 전용 줄과 주석 전용 줄(`^\s*#`, `##` 문서 주석 포함)을 제외한 줄 (`grep -cvE '^\s*(#.*)?$'`) | 셸 |
| **Function Count** | `^\s*(static\s+)?func\s+이름` 선언 수. 익명 람다 `func(...)`는 제외 (별도 집계: player 0, knight 2, ground_impact 2 등) | 셸 |

예외·한계:
- 코드 뒤에 붙은 주석(`x = 1  # 설명`)은 Code Line으로 센다.
- 여러 줄 문자열 안의 `#` 줄을 주석으로 오인할 수 있으나, 이 프로젝트에서 그런 문자열은 확인되지 않았다 [SI].
- 줄 번호는 감사 시점(HEAD `f0f088a` + 작업 트리 변경 없음) 소스 기준이다.
- 측정에 쓴 셸/파이썬 스크립트는 프로젝트 밖(scratchpad)에 두었고 프로젝트 파일을 쓰지 않았다.

---

## 2. 규모 요약 [CS]

| 구분 | 파일 | Physical | Code | 함수 |
|---|---:|---:|---:|---:|
| 전체 `.gd` | 77 | 20,379 | 15,903 | 1,024 |
| 애드온 `addons/godot_mcp` (분석 제외) | 16 | 4,897 | 3,701 | 194 |
| 프로젝트 `.gd` | 61 | 15,482 | 12,202 | 830 |
| └ 오프라인 에셋 생성기 (`toolkit/asset_gen`) | 2 | 3,437 | 2,880 | 125 |
| └ **게임 런타임** | **59** | **12,045** | **9,322** | **705** |

폴더별 Code Lines (프로젝트, 애드온 제외):

| 폴더 | Code Lines | 파일 |
|---|---:|---:|
| `actors/enemies` | 4,520 | 19 |
| `actors/player` | 3,387 | 17 |
| `toolkit` (asset_gen 2,880 포함) | 3,011 | 6 |
| `combat` | 548 | 10 |
| `levels` | 445 | 2 |
| `ui` / `camera` / `core` / `managers` / `app` / `world` | 104 / 71 / 41 / 33 / 22 / 20 | 1 / 1 / 2 / 1 / 1 / 1 |

해석 [SI]: 게임 런타임 코드의 **약 85%(7,907 / 9,322)가 `actors/`**에 있고, 그중 Player 폴더가 3,387줄, `player.gd` 한 파일이 1,503줄(런타임 코드의 16%)이다. 공용 `combat/`은 548줄로 작다 — 공용 파이프라인은 얇고, 기능 로직은 Actor 쪽에 모여 있는 구조다.

---

## 3. Code Lines 상위 15개

### 3.1 프로젝트 스크립트 (애드온 제외) [CS]

| # | 파일 | Physical | Code | 함수 | 성격 |
|---:|---|---:|---:|---:|---|
| 1 | `toolkit/asset_gen/sprite_gen.gd` | 2,312 | 1,951 | 68 | 오프라인 픽셀아트 생성기 (게임 실행에 불필요) |
| 2 | **`actors/player/player.gd`** | **1,920** | **1,503** | **109** | Player 전체 (SRM_05) |
| 3 | `actors/enemies/knight/knight.gd` | 1,147 | 947 | 61 | 보스: 월식의 기사 (Arena) |
| 4 | `actors/enemies/prince/prince.gd` | 1,150 | 940 | 70 | 보스: 제3왕자 (Phase1) |
| 5 | `toolkit/asset_gen/audio_gen.gd` | 1,125 | 929 | 57 | 오프라인 사운드 합성기 |
| 6 | `actors/enemies/enemy.gd` | 570 | 406 | 46 | 적 공통 기반 |
| 7 | `actors/enemies/giant/giant.gd` | 404 | 328 | 20 | 필드몹: 거병 |
| 8 | `actors/enemies/assassin/assassin.gd` | 384 | 311 | 20 | 필드몹: 암살자 |
| 9 | `actors/player/abilities/moon_slash/moon_slash.gd` | 378 | 307 | 16 | 궁극기(미장착): 월아 참격 |
| 10 | `actors/enemies/watcher/watcher.gd` | 358 | 276 | 23 | 공중 원거리 적 (RCI) |
| 11 | `levels/phase1/phase1.gd` | 301 | 236 | 20 | 기본 레벨 흐름 |
| 12 | `actors/enemies/crossbowman/crossbowman.gd` | 297 | 229 | 20 | 필드몹: 석궁병 |
| 13 | `actors/enemies/duelist/duelist.gd` | 258 | 211 | 15 | 필드몹: 듀얼리스트 (Arena) |
| 14 | `levels/arena/arena.gd` | 269 | 209 | 18 | 구 레벨 흐름 |
| 15 | `actors/enemies/infantry/infantry.gd` | 257 | 208 | 13 | 필드몹: 보병 |

### 3.2 애드온을 포함한 전체 기준 [CS]

전체 77개 기준이면 상위 15에 애드온 4개가 들어온다: `node_handler.gd`(657, 6위), `script_handler.gd`(577, 7위), `project_handler.gd`(445, 8위), `audio_handler.gd`(289, 13위)·`animation_handler.gd`(284, 14위). 이 경우 프로젝트 쪽 `giant`~`infantry` 일부가 밀려난다. 애드온은 서드파티 에디터 툴링이므로 이하 분석에서 제외한다.

### 3.3 규모에 대한 해석 [SI]

- `player.gd`는 "약 2,000줄"로 알려져 있었으나 **실측 1,920 Physical / 1,503 Code / 109 함수**다.
- 길이 상위 5개 중 2개(`sprite_gen`, `audio_gen`)는 게임 런타임과 무관한 **도구 스크립트**이고, 함수 대부분이 그림/소리 하나씩을 만드는 독립 함수라 결합도가 낮다. 길이만으로 위험하다고 볼 근거가 없다.
- `knight.gd`/`prince.gd`의 길이는 각각 21개·29개 공격 상태(`enum Atk`)를 가진 보스 AI와 프레임별 애니메이션(`_animate` 64줄/95줄)에서 온다. 함수 최대 길이는 `Knight._enemy_ai` 126줄, `Prince._animate` 95줄이다.
- `player.gd`의 가장 긴 함수는 50줄(`_process_spin_rise`)로, **개별 함수는 짧다**. 문제는 함수 길이가 아니라 책임의 폭과 공유 상태다 (SRM_05).

---

## 4. 전체 인벤토리 — 프로젝트 61개 [CS: 규모·선언 / 책임 서술은 코드 열람 기반]

열: Phys = Physical, Code = Code Lines, Fn = 함수 수. "의존"은 다른 프로젝트 스크립트·Autoload·group에 대한 직접 의존.

### 4.1 app / core / managers / camera / ui / world / levels

| 파일 | class_name ← extends | Phys | Code | Fn | 주요 책임 | 주요 상태 | 의존 |
|---|---|---:|---:|---:|---|---|---|
| `app/main.gd` | Main ← Node | 39 | 22 | 2 | 레벨 슬롯 교체, 레벨 순환 (`cycle_level`) | `static var _level_index`, `level` | group `main` 부여, SceneTree reload |
| `core/data/tuning.gd` | Tuning ← RefCounted | 41 | 32 | 1 | `<scene>_tuning.cfg`를 읽어 노드 속성 덮어쓰기 (`static apply`) | 없음 (정적 함수) | ConfigFile, 호출자: Player·Enemy·WatcherNeedle·Phase1·RallyDummy |
| `core/physics/collision_layers.gd` | CollisionLayers ← RefCounted | 17 | 9 | 0 | 레이어 비트 상수 | 상수 | 사용: enemy, assassin, crossbowman, giant, knight, prince, watcher |
| `managers/game_feel.gd` | (Autoload `GameFeel`) ← Node | 56 | 33 | 5 | hit-stop(`Engine.time_scale`), 카메라 shake 라우팅, 화면 flash | `_hitstop_token`, `_flash_rect` | `GameCamera.current`; 호출처 다수 (SRM_06) |
| `camera/game_camera.gd` | GameCamera ← Camera2D | 98 | 71 | 6 | follow + look-ahead, trauma shake, room_limits, focus(보스 동시 프레이밍) | `static current`, `target`, `focus`, `_trauma` | `target.get("facing")` (duck typing) |
| `ui/hud/hud.gd` | (없음) ← CanvasLayer | 135 | 104 | 10 | 체력/궁극기 바, 보스 체력 바, 감시자 처치 수 | `_boss_health`, tween들 | `Player` 시그널·필드(`health`, `ult_charge`), `HealthComponent.damaged` |
| `world/props/brazier/brazier.gd` | (없음) ← Node2D | 30 | 20 | 2 | 화로 불꽃 애니메이션 | `_t` | 없음 |
| `levels/phase1/phase1.gd` | Phase1 ← Node2D | 301 | 236 | 20 | 분대 스폰·웨이브, 왕자 보스 구역(게이트·카메라·음악·재시작), 시차 배경, 치트 API | `_alive`, `_wave_id`, `_squads_cleared`, `_boss_active`, `_prince`, `_fight_counter` | Player, Prince, Enemy, GameCamera, Hud(동적 호출), GameFeel, group 부여 |
| `levels/arena/arena.gd` | Arena ← Node2D | 269 | 209 | 18 | 적 리스폰, 감시자 처치 수→Knight 등장 연출, 음악 페이드, 치트 API | `_watcher_kills`, `_boss_phase` | Player, Knight, Watcher, Enemy, WatcherNeedle, GroundImpact, Hud, GameFeel |

### 4.2 combat (공용)

| 파일 | class_name ← extends | Phys | Code | Fn | 주요 책임 | 주요 상태 | 의존 |
|---|---|---:|---:|---:|---|---|---|
| `components/health/health.gd` | HealthComponent ← Node | 38 | 20 | 3 | HP 증감, `damaged`/`died` 통지, 디버그 print | `hp`, `max_hp` | 없음 |
| `components/hitbox/hitbox.gd` | HitboxComponent ← Area2D | 45 | 26 | 3 | `area_entered` → `HurtboxComponent.receive_hit`, 1회 중복 방지, `apply_on_contact=false` 시 `hurtbox_entered`만 알림 | `damage`, `source`, `knockback_*`, `hit_targets` | HurtboxComponent |
| `components/hurtbox/hurtbox.gd` | HurtboxComponent ← Area2D | 37 | 22 | 2 | `receive_hit()` → `hit_received` emit → `health.take_damage()` → 선택적 시간 무적 | `invincible`, `health` | HealthComponent, SceneTree timer |
| `attacks/x_slash/x_slash.gd` | XSlash ← Node2D | 135 | 101 | 6 | X자 결정타 연출(실제 시간) + 0.14초에 `target.receive_hit()`; `pierce_invincibility` | `target`, `damage`, `_t` | GameFeel, SparkEffect |
| `effects/slash/slash.gd` | SlashEffect | 61 | 43 | 3 | `_draw` 초승달 궤적 | | |
| `effects/spark/spark.gd` | SparkEffect | 67 | 50 | 4 | `_draw` 방사형 스파크 + 링 | | |
| `effects/glint/glint.gd` | GlintEffect | 41 | 31 | 2 | 반짝임 별빛 (= 반격 가능 시간 시각화) | `lifetime` | |
| `effects/afterimage/afterimage.gd` | Afterimage ← Sprite2D | 35 | 25 | 2 | 스프라이트 복제 잔상 | | |
| `effects/counter_tell/counter_tell.gd` | CounterTell | 96 | 71 | 5 | 카유공(RCI) CHARGE/WINDOW 예고 연출; 소유 Actor가 매 프레임 `mode/progress/aim_point` 기입 | `mode`, `progress` | 사용: Knight, Watcher, Prince |
| `effects/ground_impact/ground_impact.gd` | GroundImpact | 196 | 159 | 9 | 균열·파편·먼지 연출 (`crack_ground/wall/ledge`, `rain_rubble`) | | 사용: Dive, Knight, Prince, Arena |

### 4.3 actors/player

| 파일 | class_name | Phys | Code | Fn | 주요 책임 | 의존 |
|---|---|---:|---:|---:|---|---|
| `player.gd` | Player ← CharacterBody2D | 1,920 | 1,503 | 109 | 입력·이동·대시·콤보·반격 4종·연쇄·방어·이벤트 잠금·스킬 슬롯·궁극기·피격·사망·연출 (**SRM_05**) | Enemy, WatcherNeedle, 모든 Ability, XSlash, HakiBurst, MoonSlash, SwordWave, 이펙트, GameFeel, Tuning, group 6종 |
| `player_visual.gd` | PlayerVisual ← Node2D | 163 | 134 | 4 | 몸통 프레임·검 각도 키프레임 애니메이션, `footstep`, hit_flash 파라미터 | 없음 (Player가 `play()`/`tick()` 호출) |
| `abilities/void_orb/void_orb_ability.gd` | VoidOrbAbility | 54 | 38 | 4 | 쿨다운, 구체 스폰·수치 전달, `ready_again` | VoidOrbProjectile, group `projectiles` |
| `abilities/void_orb/void_orb_projectile.gd` | VoidOrbProjectile | 179 | 136 | 11 | 직진·관통·다단히트(대상별 기록), 벽/화면 끝 소멸 | HurtboxComponent, GameFeel, viewport |
| `abilities/dash_slash/dash_slash_ability.gd` | DashSlashAbility | 69 | 44 | 6 | 쿨다운, Hitbox 크기·위치(지나온 길 포함), 궤적 스폰 | DashSlashEffect, group `fx` |
| `abilities/dash_slash/dash_slash_effect.gd` | DashSlashEffect | 102 | 67 | 7 | `_draw` 수평 칼빛 | |
| `abilities/spin_rise/spin_rise_ability.gd` | SpinRiseAbility | 114 | 74 | 9 | 진행도 기반 틱 피해, Sensor로 `field_mob` 운반(`Enemy.begin_carry/end_carry`) | Enemy, SpinRiseEffect |
| `abilities/spin_rise/spin_rise_effect.gd` | SpinRiseEffect | 189 | 143 | 11 | `_draw` 회오리 | |
| `abilities/dive/dive_ability.gd` | DiveAbility | 90 | 60 | 6 | 쿨다운, 몸 접촉 Hitbox, 낙하 높이→피해 계산, DiveBlast·GroundImpact 스폰 | DiveBlast, GroundImpact |
| `abilities/dive/dive_blast.gd` | DiveBlast | 159 | 123 | 9 | 착지 작렬 + 지연 불꽃 (겹친 Hurtbox에 직접 `receive_hit`) | GameFeel |
| `abilities/lightning/lightning_ability.gd` | LightningAbility | 37 | 24 | 3 | 쿨다운, 번개 스폰 (미장착) | LightningBolt |
| `abilities/lightning/lightning_bolt.gd` | LightningBolt | 270 | 203 | 15 | 기둥+원 판정, 맥동 연출(실제 시간) | GameFeel |
| `abilities/rising_slash/rising_slash_ability.gd` | RisingSlashAbility | 145 | 107 | 10 | 원형 베기 판정·그리기 (미장착) | |
| `abilities/moon_slash/moon_slash.gd` | MoonSlash | 378 | 307 | 16 | 가속 반달 → 회오리 → 기둥 폭발 2타 (미장착 궁극기) | GameFeel |
| `abilities/sword_wave/sword_wave.gd` | SwordWave | 244 | 195 | 14 | 가속 반달 → 원형 폭발 + 범위 적에 VoidMark (현재 궁극기) | Enemy, VoidMark, group `enemy`, GameFeel |
| `abilities/sword_wave/void_mark.gd` | VoidMark | 78 | 58 | 5 | 적 추적 표식 → 2초 뒤 범위 피해 (no_flinch) | Enemy(`hold_corpse`, `hurtbox`, `state`), group `enemy` |
| `abilities/haki/haki_burst.gd` | HakiBurst | 217 | 171 | 11 | 연쇄 반격 보상: 화면 안 적 전체에 시간차 피해 | Enemy, group `enemy`, GameFeel, viewport |

### 4.4 actors/enemies

| 파일 | class_name ← extends | Phys | Code | Fn | 주요 책임 | 주요 상태 / 특이점 |
|---|---|---:|---:|---:|---|---|
| `enemy.gd` | Enemy ← CharacterBody2D | 570 | 406 | 46 | 상태(SPAWNING/ACTIVE/HITSTUN/STAGGER/DEAD/CARRIED), 중력, 피격 반응·넉백·에어본, 반짝임(MCI) API, 카유공/방어 훅, 추방·사망·시체 유지, 접촉 피해 Area 생성 | `state`, `facing`, `_glinting`, `is_contact_hit`(공개 일시 플래그) |
| `grunt/grunt.gd` | Grunt | 139 | 110 | 9 | 돌진 물기 AI (Arena) | `_atk` |
| `duelist/duelist.gd` | Duelist | 258 | 211 | 15 | 거리 유지 + 연격 AI (Arena) | `_has_armor` 오버라이드 |
| `watcher/watcher.gd` | Watcher | 358 | 276 | 23 | 비행·시야 확보, 바늘 사격, 카유공(RCI) CHARGE→WINDOW→히트스캔 광선 | `counter_threat` group 코드 부여, 광선이 대상 `invincible=false` 강제 |
| `watcher/watcher_needle.gd` | WatcherNeedle | 127 | 92 | 9 | 투사체 + PRCI(`is_deflectable`/`deflect`) | **자체 튜닝 파일** 사용, group `deflectable` |
| `watcher/watcher_beam.gd` | WatcherBeam | 64 | 46 | 4 | 광선 겉모습 | |
| `knight/knight.gd` | Knight | 1,147 | 947 | 61 | 보스 4패턴 (돌격 베기 MCI / 카유공 RCI / 반격 자세→CCI 랠리 / 돌진), 등장 연출, `landed` | 21개 `Atk` 상태, `_bait_*`, `_rally_count` |
| `knight/knight_cross.gd` | KnightCross | 159 | 122 | 8 | 역반격 창 X자 문장 (실제 시간) | |
| `infantry/infantry.gd` | Infantry | 257 | 208 | 13 | 행군 + 단일 MCI 내려베기, 동료 간격 | 다른 Infantry의 `_atk`/`_atk_elapsed` 읽음 |
| `assassin/assassin.gd` | Assassin | 384 | 311 | 20 | 순보 접근·등 뒤 잡기 + MCI 찌르기 | Infantry·Assassin 비공개 필드 읽음, `Player.facing` 읽음 |
| `crossbowman/crossbowman.gd` | Crossbowman | 297 | 229 | 20 | 사선 확인 → 경고 BAR → 볼트, 후퇴 순보 | Line2D 동적 생성 |
| `crossbowman/crossbow_bolt.gd` | CrossbowBolt ← WatcherNeedle | 26 | 16 | 1 | `_draw`만 오버라이드 (PRCI 경로 재사용) | |
| `giant/giant.gd` | Giant | 404 | 328 | 20 | 돌진 + 2단 MCI (`on_parried` 오버라이드) | Infantry·Assassin·Giant 비공개 필드 읽음 |
| `prince/prince.gd` | Prince | 1,150 | 940 | 70 | 보스 5패턴 + 2페이즈, 방어 경로(guard), 힘겨루기 | 29개 `Atk` 상태, **Player 공개 API·내부 필드 직접 호출** |
| `prince/prince_health.gd` | PrinceHealth ← HealthComponent | 11 | 5 | 1 | `floor_hp` 아래로 HP가 내려가지 않게 `take_damage` 오버라이드 | |
| `prince/prince_wave.gd` | PrinceWave ← WatcherNeedle | 46 | 32 | 2 | 가속 + `_draw` | |
| `prince/prince_aura.gd` | PrinceAura | 103 | 77 | 6 | 돌진 잔류 아우라 피해 (겹침 매 프레임 확인, 1회) | |
| `prince/prince_quake.gd` | PrinceQuake | 170 | 130 | 10 | 패턴 4 신호·결과 연출 | |
| `prince/prince_clash.gd` | PrinceClash | 48 | 34 | 2 | 패턴 5 힘겨루기 QTE (`player_parry` 직접 읽음) | |

### 4.5 toolkit

| 파일 | extends | Phys | Code | Fn | 책임 | 의존 |
|---|---|---:|---:|---:|---|---|
| `toolkit.gd` | CanvasLayer | 25 | 16 | 3 | `tool_*` 단축키 (HUD 토글/재시작/일시정지), PROCESS_MODE_ALWAYS | `$DebugHud` |
| `debug_hud.gd` | Control | 16 | 11 | 1 | FPS·프레임 시간·씬 이름 | |
| `cheats.gd` | Control | 109 | 87 | 4 | 치트 1~9 (group으로 Player/Arena/Phase1/Main 탐색 후 공개 메서드 호출) | Player, Arena, Phase1, Main |
| `rally_dummy/rally_dummy.gd` | Knight | 32 | 17 | 4 | 반격 자세만 쓰는 불사 보스 (치트 3) | Knight 내부 메서드 `_decide`/`_begin_guard` 오버라이드·호출, `Tuning.apply(self, path)` |
| `asset_gen/sprite_gen.gd` | SceneTree | 2,312 | 1,951 | 68 | 고정 seed 픽셀아트 PNG 생성 → `assets/temporary/` | Image API |
| `asset_gen/audio_gen.gd` | SceneTree | 1,125 | 929 | 57 | 고정 seed WAV 합성 → `assets/temporary/audio/` | |

### 4.6 애드온 (분석 제외, 규모만 기록) [CS]

`addons/godot_mcp/` 16개 — `plugin.gd`(335/253), `job_manager.gd`(130/96), `handlers/` 14개(node 845/657, script 750/577, project 584/445, animation 392/284, audio 382/289, filesystem 325/239, scene 248/185, runtime 201/140, classdb 180/148, resource 139/104, undoredo 110/81, theme 102/80, selection 96/72, task 78/51). 제외 사유: 에디터용 서드파티 플러그인이며 `CLAUDE.md`가 구조 규칙 대상에서 명시적으로 제외한다.

---

## 5. 책임 단위 분석 (주요 스크립트)

### 5.1 공용 전투 컴포넌트 — `Health` / `Hitbox` / `Hurtbox` [CS]

- **책임**: 피해 한 경로. `HitboxComponent._on_area_entered`(`hitbox.gd:32-45`) → `HurtboxComponent.receive_hit`(`hurtbox.gd:17-31`) → `HealthComponent.take_damage`(`health.gd:24-38`).
- **소유 상태**: Health `hp`; Hurtbox `invincible`(공개 bool), `health` 참조; Hitbox `hit_targets`, `source`.
- **중요한 순서 계약**: `receive_hit()`은 `hit_received`를 **`take_damage()` 전에** emit한다 (`hurtbox.gd:26-27`). Player는 이 순서를 전제로 `health.hp - damage`를 "곧 될 HP"로 계산한다 (`player.gd:1669,1684,1717,1726`) — SRM_07 R-04.
- **다른 스크립트와 상호작용**: `hitbox.gd` 밖에서 `receive_hit()`을 **직접 호출하는 코드가 17곳(14개 파일)**이다 — VoidOrbProjectile, SpinRiseAbility, DiveBlast, LightningBolt, MoonSlash(2), SwordWave, VoidMark, HakiBurst, XSlash, Player(반격 경로·이벤트 피니시 2), Watcher 광선, Prince(충격·피니시 2), PrinceAura, Enemy 접촉 피해. 이는 Structure V0가 허용한 "공격 쪽이 타이밍을 정하는 문법"(`apply_on_contact = false`)의 사용이며, 모든 피해가 결국 `HurtboxComponent.receive_hit()`을 지난다는 계약은 지켜진다 [CS].

### 5.2 `Enemy` 기반 클래스 (`enemy.gd`) [CS]

- **책임**: 9개 하위 클래스의 공통 상태 머신과 피격/반격당함/사망/추방/운반/접촉 피해, 반격 API(`is_glinting`, `on_parried`, `is_counter_open`, `on_countered`, `counter_strike_damage`, `is_guard_open`, `on_guarded`).
- **확장 방식**: 템플릿 메서드 훅 — `_on_ready`, `_enemy_ai`, `_animate`, `_on_hurt`, `_on_parried_react`, `_on_stagger_end`, `_has_armor`, `_on_banished`, `_can_contact`. 하위 클래스별 오버라이드 현황은 SRM_06 §1.3.
- **소유 상태**: `state`(공개), `facing`, `_glinting`, `_flash_*`, `_carrier`, `_airborne`, `is_contact_hit`(공개).
- **외부 의존**: group `"player"`(타깃 탐색 `enemy.gd:182`), `"fx"`, `GameFeel`, `CollisionLayers`, `Tuning`.
- **문서와 다른 점**: 헤더 주석은 "두 실사용자(Grunt, Duelist)"라고 하지만 실제 하위 클래스는 9개 (+RallyDummy) — 주석이 오래됨 (`enemy.gd:4`).

### 5.3 `Knight` (`knight.gd`) [CS — 일부 구간 정독, 나머지는 구조 추출]

- **책임**: 패턴 선택(`_decide` 주머니), 4패턴 실행, 반격 자세 → 맞부딪힘 → 확률적 역반격 창/랠리(CCI), 비행·순간이동(`_set_float`가 `collision_mask` 직접 변경), 등장 낙하 연출, 사망 연출, 손 위치 아트 상수(`HAND_ART` — 생성기 `_gen_knight`와 수동 동기화 필요).
- **상호작용**: `XSlash`를 스폰해 플레이어 Hurtbox를 물리 쿼리로 찾아(`_find_target_hurtbox`, `knight.gd:581-591`) 무적 관통 피해. `GameFeel.hit_stop(bait_time, 0.1)`으로 세상을 느리게 만들고 Player가 `_process`에서 그 입력을 모으도록 기대한다 (Player ↔ Knight 시간 계약, SRM_06).
- **주요 상태**: `_atk`(21종), `_t`, `_bait_open`, `_bait_rally`, `_rally_count`, `_rush_window`, `_cross`.

### 5.4 `Prince` (`prince.gd`) [CS — 일부 구간 정독, 나머지는 구조 추출]

- **책임**: 1·2페이즈 패턴 1~3 반복, 체력 경계(`PrinceHealth.floor_hp`)에서 패턴 4(천지분쇄, 방어 경로) → 패턴 5(마지막 일격, 이벤트 잠금 + PrinceClash QTE), 후속 반격(RECOIL/RERAISE) 확률, 디버그 강제 패턴.
- **Player와의 직접 결합**: `get_target() as Player` 후 `p.action == Player.Action.DEAD`(`prince.gd:250`), `p.on_guard_impact()`(812), `p.hurtbox.invincible = false`(819, 970), `p.hurtbox.receive_hit()`(821, 971), `p.begin_event_lock()`(929), `p.event_final_strike()`(963), `p.end_event_lock()`(965), `p.health.hp`(971) — SRM_07 R-03.
- **주요 상태**: `_atk`(29종), `phase`, `_guard_open`, `_guarded`, `_quake_done`, `_finale_started`, `_clash`.

### 5.5 Watcher 계열 [CS]

- `Watcher`: 비행(중력 오버라이드, mask 0), 시야 레이캐스트로 자리 옮기기, 바늘 사격, RCI 광선(대상 Hurtbox `invincible=false` 강제 후 `receive_hit` — `watcher.gd:272-274`).
- `WatcherNeedle`: PRCI의 단일 구현. `CrossbowBolt`, `PrinceWave`가 상속해 **Player가 `WatcherNeedle` 타입으로만 튕겨낼 대상을 찾는 구조**를 재사용한다 (`player.gd:1282-1288`). 이름("바늘")과 실제 용도(구체·볼트·검격 공용 PRCI 투사체)가 어긋나 있다 — SRM_07 R-13.

### 5.6 필드몹 (Infantry / Assassin / Crossbowman / Giant / Grunt / Duelist) [CS]

- 공통 패턴: `_atk` enum 상태 머신 + `begin_glint/end_glint`로 MCI 창 + `attack_hitbox` on/off.
- **중복 구현**: `_ray()` 3중복 (assassin:178, crossbowman:117, giant:194 — 본문 동일), `_spawn_slash()` 6곳, `_crowd_allows_attack()` 3곳(서로 다른 규칙 — SRM_07 R-06), `_projectile_parent()` 2곳(crossbowman, watcher).

### 5.7 레벨 스크립트 (`phase1.gd`, `arena.gd`) [CS]

- **책임 범위가 넓다**: 스폰, 웨이브/리스폰 타이머, 보스 등장 연출, 게이트·카메라 제한·focus, 음악, HUD 바인딩, **group 부여(Player `"player"`, Effects `"fx"`, Projectiles `"projectiles"`)**, 시차 배경, 치트용 공개 API.
- **비동기 흐름**: `await create_timer` 13곳 + `_wave_id`/`_fight_counter` 토큰으로 오래된 대기 흐름을 무효화하는 패턴 (phase1).
- 두 레벨이 같은 골격 코드를 각자 가진다 (그룹 부여·카메라·HUD 바인딩·음악 루프·시차) — SRM_07 R-11.

### 5.8 Player Ability 노드들 [CS]

- 공통 패턴: 각자 `_cd`를 `_physics_process`에서 감소, 판정 노드 소유, 스폰물에 수치 전달. 시전 자세(상태 머신)는 Player가 가진다.
- **API 이름이 통일되지 않음**: `can_cast()`(VoidOrb, Lightning) vs `can_use()`(DashSlash, SpinRise, Dive, RisingSlash); 쿨다운 시작 `cast()`/`begin()`/`start_cooldown()`; 종료 `set_active(false)`/`cancel()`/`finish()`/`set_body_active(false)` — Player의 문자열 `match`(`player.gd:442-468`)가 이 차이를 흡수한다 (SRM_07 R-09).

### 5.9 GameFeel / GameCamera / HUD / Toolkit [CS]

- `GameFeel`: 상태는 토큰 하나. `hit_stop`은 마지막 호출이 이긴다(토큰 비교) — 동시에 걸린 느린 시간(예: Knight 역반격 창 0.5초)을 짧은 hit-stop이 **덮어쓸 수 있다** [SI] (`game_feel.gd:40-50`).
- `GameCamera`: static `current` 싱글턴, `target.get("facing")`로 Player 필드를 duck typing으로 읽는다.
- `Hud`: `class_name` 없음. 레벨은 `CanvasLayer` 타입 변수로 `hud.bind()`, `hud.show_boss()` 등을 호출 — 정적 타입 검사 밖의 동적 호출 [CS]. `set_tally` 문구 "WATCHERS"는 Arena 전용 개념이 공용 HUD에 들어 있는 사례.
- `Cheats`: group 탐색 → 레벨·플레이어 공개 메서드 호출. 본편 코드는 Cheats를 모른다 (단방향) — 양호.
