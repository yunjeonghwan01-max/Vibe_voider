# SRM_05 — Player 심층 분석 (`actors/player/player.gd`)

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` · Read-Only Static Audit
> **확실성 표기**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown
> **범위**: `player.gd` 1~1920줄 **전체 정독**, `player_visual.gd` 전체, `player.tscn` 원문, `player_tuning.cfg` 전체, Player가 호출하는 Ability/Enemy API 원문.
> **주의**: 이 문서는 현재 구조를 기록한다. 코드 분리나 새 Player 구조 설계는 하지 않는다. §8의 "분리 가능 영역"은 관찰에 근거한 **검토 후보**일 뿐이다.
> **관련**: [SRM_03 §3.4 씬 트리](SRM_03_Scene_Architecture.md) · [SRM_06 실행 흐름](SRM_06_System_Dependencies.md) · [SRM_07 위험](SRM_07_Structural_Risks.md) · [SRM_09 후보](SRM_09_Refactoring_Candidates.md)

---

## 1. 실측 [CS]

| 항목 | 값 |
|---|---|
| Physical / Code Lines | **1,920 / 1,503** ("약 2,000줄"이라는 기존 인식보다 약간 적다) |
| 함수 | 109개 — 외부 공개 메서드 6개(`force_chain_burst`, `on_guard_impact`, `begin_event_lock`, `end_event_lock`, `event_final_strike`, `is_ultimate_ready`) + 엔진 콜백 4개 + 비공개 99개 |
| 최장 함수 | `_process_spin_rise` 50줄, `_update_visual` 48, `_process_attack` 47, `_physics_process` 47, `_start_parry` 46 — **개별 함수는 짧다** |
| Signal | 4 (`health_changed`, `ultimate_changed`, `ultimate_ready_changed`, `died`) |
| enum | `Action` 14값, `SpinPhase` 3, `DivePhase` 4 |
| `@export` | 105 (14개 `@export_group`) — 그중 67개가 `player_tuning.cfg`의 `[.]` 섹션에서 덮어써짐 (파일 전체 키는 자식 노드 섹션 포함 97개) |
| `@onready` 노드 참조 | 29 (`$Visual`, `$Trail`, `$Combat/*` 10, `$Audio/*` 19) |
| 멤버 상태 변수 | 43 (`facing`, `action`, `ult_charge` 공개 + 40 비공개) |
| 변경 이력 | 전체 46커밋 중 **24커밋(52%)이 이 파일을 수정** (`git log` 기준, 프로젝트 최다) |

---

## 2. 책임 지도 — 무엇을 어디서 하는가 [CS]

줄 범위는 섹션 구분 주석(`# ─── … ───`) 기준. 줄 수는 해당 구간의 물리 줄(근사).

| # | 책임 | 줄 범위 | ≈줄 | 관련 함수 |
|---:|---|---|---:|---|
| 0 | 선언부: 문서 주석, 시그널, enum, `@export` 105개, `@onready` 29개, 상태 변수 43개 | 1–262 | 262 | — |
| 1 | 수명주기·프레임 분배·타이머 | 264–394 | 131 | `_enter_tree`(Tuning), `_ready`(시그널 11개 연결), `_process`, `_physics_process`(Action 디스패치), `_tick_timers` |
| 2 | 자유 상태 입력 중재 + 스킬 슬롯 라우팅 | 396–498 | 103 | `_process_free`, `_held_skill_slot`, `_can_cast_skill`, `_cast_skill`, `_dash_slot_ready`, `_can_ultimate`, `_ult_windup`, `_ult_total`, `_up_held`, `_down_held`, `_move_input` |
| 3 | 이동 (가감속·중력·점프·더블 점프) | 500–549, 971–976 | 56 | `_apply_horizontal`, `_apply_gravity`, `_try_jump`, `_double_jump`, `_apply_gravity_no_cut` |
| 4 | 대시 | 551–616 | 66 | `_can_dash`, `_start_dash`, `_process_dash`, `_end_dash` |
| 5 | 평타 3연 콤보 | 618–710 | 93 | `_start_attack`, `_process_attack`, `_end_attack`, `_on_attack_landed` |
| 6 | 스킬: 장풍 (자세) | 712–780 | 69 | `_start_skill`, `_process_skill`, `_fire_skill`, `_on_skill_hit`, `_on_skill_ready` |
| 7 | 스킬: 벼락 (미장착) | 782–816, 855–857 | 38 | `_start_lightning`, `_process_lightning`, `_on_lightning_hit`(승천 참격과 공용) |
| 8 | 스킬: 승천 참격 (미장착) | 818–853 | 36 | `_start_rising_slash`, `_process_rising_slash` |
| 9 | 스킬: 회전 상승 | 859–994 | 136 | `_start_spin_rise`, `_process_spin_rise`, `_steer_spin_rise`, `_launch_spin_rise`, `_end_spin_rise`, `_cancel_spin_rise`, `_on_spin_rise_hit` |
| 10 | 스킬: 강하 | 996–1096 | 101 | `_start_dive`, `_process_dive`, `_launch_dive`, `_land_dive`, `_end_dive`, `_on_dive_hit` |
| 11 | 스킬: 대시 참격 | 1098–1182 | 85 | `_queue_dash_slash`, `_start_dash_slash`, `_process_dash_slash`, `_end_dash_slash`, `_on_dash_slash_landed` |
| 12 | **반격 (MCI · RCI · PRCI 판정·보상)** | 1184–1377, 1438–1465 | 222 | `_start_parry`(진입·분기), `_glinting_attackers`(MCI), `_open_counter_threats`(RCI), `_deflectable_needles`/`_nearest_needle`/`_deflect_needle`(PRCI), `_nearest`, `_counter_sweep`, `_start_counter`, `_strike_counter_path`, `_spawn_counter_slash`, `_process_parry`, `_trigger_parry_success` |
| 13 | 연쇄 반격(CC) · 패기 방출 | 1379–1436 | 58 | `_open_chain`, `_check_haki`, `force_chain_burst`(치트), `_tick_chain`, `_can_take_counter_press`, `_has_counter_target`, `_cancel_chain` |
| 14 | 방어 입력 (Prince 패턴 4·5 전용 경로) | 1467–1516 | 50 | `_try_guard`, `_open_guard_threat`, `on_guard_impact` |
| 15 | 이벤트 잠금 (Prince 패턴 5) | 1518–1555 | 38 | `begin_event_lock`, `end_event_lock`, `event_final_strike` |
| 16 | 궁극기 (게이지 + 2종 분기) | 1557–1665 | 109 | `is_ultimate_ready`, `_add_ultimate`, `_start_ultimate`, `_process_ultimate`, `_fire_moon_slash`, `_sword_wave_charge_fx`, `_fire_sword_wave` |
| 17 | 피격 · 사망 · 부활 | 1667–1784 | 118 | `_on_hit_received`, `_stop_abilities`, `_on_armored_hit`, `_on_contact_hit`, `_process_hurt`, `_on_died`, `_respawn_after` |
| 18 | 표시 (방향·스쿼시·기울기·번쩍임·궤적·발소리) | 1786–1865 | 80 | `_update_facing_from_input`, `_update_visual`, `_set_flash`, `_update_trail`, `_on_footstep`, `_sfx` |
| 19 | VFX 스폰 헬퍼 | 1867–1920 | 54 | `_fx_parent`, `_spawn_slash`, `_spawn_spark`, `_spawn_parry_spark`, `_spawn_parry_stance`, `_spawn_afterimage` |

**요약 [SI]**: 19개 책임 영역이 한 클래스에 있다. 그중 **"전투 시스템 규칙" 성격(12~16: 반격 4종·연쇄·방어·이벤트 잠금·궁극기)이 약 480줄**로 가장 크고, Player 밖의 적·보스 설계 변경에 가장 자주 함께 바뀐 영역이다 (§9).

---

## 3. 처리 위치 — 입력 / 이동 / 전투 / 스킬 / 피격 / 애니메이션 [CS]

| 관심사 | 실제 처리 위치 | 비고 |
|---|---|---|
| **입력** | `player.gd` 안에 분산: `_process`(304, 307, 313), `_physics_process`(325), `_process_free`(400–425), 그리고 **각 액션 처리 함수 안** (`_process_dash` 590–596, `_process_attack` 646–676, `_process_skill` 739–752, `_process_lightning` 810, `_process_rising_slash` 839, `_process_spin_rise` 881–920, `_process_dive` 1017, `_process_dash_slash` 1152–1157, `_process_hurt` 1743), `_start_dash`(579), `_try_jump`(530), `_apply_gravity`(518) | `Input.*` 39회. `player_parry`만 **14곳**에서 읽는다. 입력 → 의도 변환 계층 없음 |
| **이동** | `_apply_horizontal`, `_apply_gravity`, `_try_jump`, `_double_jump` + 각 액션 함수가 `velocity`를 직접 씀 | `velocity` 쓰기 65곳. `move_and_slide()`는 `_physics_process` 358에서 1회 |
| **근접 전투** | `_start_attack`/`_process_attack`가 `Combat/AttackHitbox`의 위치·피해·넉백·`monitoring`을 직접 설정 | 명중 반응은 `HitboxComponent.hit_landed` → `_on_attack_landed` |
| **반격** | `_start_parry`가 MCI(`ParryBox` 겹침) → RCI(group `counter_threat`) → PRCI(group `deflectable`) 순으로 판정하고 **적 메서드를 직접 호출** (`on_parried`, `counter_strike_damage`, `on_countered`, `deflect`) | 판정 데이터는 적이 소유 (`is_glinting`, `is_counter_open`, `is_deflectable`) |
| **스킬** | 시전 자세·캔슬 규칙 = `player.gd`의 `Action.*` 처리 함수 / 쿨다운·판정·스폰 = `Combat/<Skill>` Ability 노드 | 슬롯 → 스킬은 문자열 `match` (`_can_cast_skill` 442, `_cast_skill` 457) |
| **피격** | `Combat/Hurtbox.hit_received` → `_on_hit_received`(1668): 강하 중 아머 / 접촉 피해(`enemy.is_contact_hit`) / 일반 경직 3분기 | `take_damage` 없음 (규칙 준수). HP 표시는 예측값 `health.hp - damage`로 emit |
| **사망·부활** | `Combat/Health.died` → `_on_died` → `_respawn_after(1.4)` (await, 스폰 위치로 복귀·HP 직접 대입) | `health.hp = health.max_hp` 직접 대입 (1773) |
| **애니메이션** | 상태 → `visual.play(&"이름")` 35곳 (Player) / 프레임·검 각도 = `PlayerVisual.tick()` / 반전·스쿼시·기울기·투명도·번쩍임 = `Player._update_visual`(1794) | AnimationPlayer 미사용. 애니메이션 이름은 문자열(StringName) 계약 — `player_visual.gd:14-37` `KEYS`와 맞아야 함 |
| **연출(손맛)** | `GameFeel.*` 43회, `_sfx` 35회, `_spawn_*` 36회, `_set_flash` 28회, `_squash =` 26회 | 각 액션 함수 안에 인라인 |

---

## 4. 프레임 처리 순서 [CS]

```text
_process(delta)                                   ← 화면 프레임 (hit-stop 중에도 돈다)
  1. 피격 깜빡임 (_iframe_t)                                            300-302
  2. time_scale < 1 이고 parry 눌림 → _try_guard()                       304-305
  3. time_scale < 1 이고 parry 눌림 + 받아칠 RCI/PRCI 있음 → _counter_buffered = true   307-308
  4. 연쇄 창(_chain_t) 안 parry 눌림 → _chain_armed = true               313-315

_physics_process(delta)                           ← 물리 프레임 (time_scale에 비례해 드물어진다)
  1. _tick_timers   (코요테·버퍼·쿨다운·대시 후 무적 해제·콤보 리셋…)   319
  2. _tick_chain    (예약된 연쇄 → 대상 생기면 _start_parry())           320
  3. _counter_buffered 소비 → _start_parry()                           321-324
  4. parry 눌림 → _try_guard()                                         325-326
  5. match action → _process_<action>()  (NONE이면 _process_free)       328-356
  6. move_and_slide()                                                  358
  7. _update_facing_from_input → _update_visual → _update_trail          359-361
```

[SI] 같은 `player_parry` 입력이 한 프레임 안에서 `_process`(2·3·4), `_physics_process`(3·4), 그리고 액션 함수(5)까지 **최대 다섯 경로**에서 해석될 수 있다. 이를 막기 위해 `_parry_cd = GUARD_PRESS_LOCK(0.02)`, `_chain_skip_press`, `_counter_buffered` 같은 보조 플래그가 존재한다 — 입력 소유권이 한 곳에 있지 않다는 신호다.

---

## 5. 상태 변수와 변경 지점

### 5.1 상태 그룹 [CS]

| 그룹 | 변수 | 주 소유 책임 |
|---|---|---|
| 핵심 공유 | `action`, `_action_time`, `facing`, `velocity`(엔진), `hurtbox.invincible`(컴포넌트) | **여러 책임이 공동으로 씀** (§5.2) |
| 이동 | `_coyote`, `_jump_buffer`, `_air_jumps_left`, `_was_on_floor`, `_run_bob` | 이동 |
| 대시 | `_dash_cd`, `_air_dashes_left`, `_dash_iframe_t`, `_dash_start_pos` | 대시 (+대시 참격이 읽음) |
| 콤보 | `_combo_index`, `_combo_timer`, `_attack_buffered`, `_attack_hitbox_base_pos` | 콤보 |
| 판정 플래그 | `_hitbox_live` | **평타·대시 참격·궁극기가 의미를 바꿔 재사용** (궁극기에서는 "발사했는가", 1575 주석) |
| 반격 | `_parry_cd`, `_parry_success`, `_counter_buffered` | 반격 (+방어·이벤트 잠금이 `_parry_cd` 씀) |
| 연쇄 | `_chain_t`, `_chain_armed`, `_chain_skip_press`, `_chain_count` | 연쇄 (+사운드 음높이가 `_chain_count` 읽음) |
| 방어 | `_guard_pose_t`, `_guard_hop` | 방어 (+`_apply_gravity`가 `_guard_hop` 읽음) |
| 스킬별 | `_skill_fired`, `_dash_slash_queued`, `_dash_slash_window`, `_lightning_struck`, `_rising_up`, `_spin_phase`, `_spin_start`, `_spin_ticks_hit`, `_dive_phase`, `_dive_start_y`, `_dive_tilt` | 각 스킬 (+`_rising_up`은 중력·접촉 피격이 읽음) |
| 궁극기 | `ult_charge` (공개) | 궁극기 (+HUD가 직접 읽음) |
| 피격·표시 | `_iframe_t`, `_squash`, `_flash_amount`, `_flash_color`, `_spawn_position` | 표시/피격 |

### 5.2 여러 책임이 공유·직접 변경하는 상태 [CS]

| 상태 | 쓰기 횟수 | 쓰는 곳 (함수 / 줄) | 읽는 곳 |
|---|---:|---|---|
| `action` | **32** | 모든 `_start_*`(561, 620, 714, 785, 822, 863, 1000, 1107, 1186, 1573), 모든 `_end_*`/종료 분기(610, 693, 756, 814, 852, 909–925, 967, 1089, 1171, 1446, 1609, 1747), `_try_guard`(1481), `begin/end_event_lock`(1524, 1534), `_on_hit_received`(1692), `_on_died`(1752), `_respawn_after`(1775) | 디스패치(328), `_tick_timers`(384), `_can_take_counter_press`(1425), `_update_*`, **외부: `Prince._target_down`(prince.gd:250)** |
| `hurtbox.invincible` | **17** (+ Hurtbox 자체 타이머, + Watcher/XSlash/Prince 외부 쓰기) | 대시(572), 대시 후 해제(385), 회전 상승(871, 955, 965), 대시 참격(1111), 반격 성공(1221, 1309, 1330), 반격 종료(1447), 방어(1479), 이벤트 잠금(1526, 1535), 궁극기(1579, 1608), 사망(1754), 부활(1776) | `HurtboxComponent.receive_hit` |
| `_action_time` | 17 | 모든 액션 시작·단계 전환, `_deflect_needle`(1308: 튕겨내기 자세를 짧게 하려고 **시작값을 조작**) | 모든 `_process_*` |
| `facing` | 10 | 대시·평타·장풍·강하·반격·튕겨내기·카유공 반격·궁극기 시작, `_update_facing_from_input` | 표시, 판정 위치, **외부: GameCamera(look-ahead), Assassin(`_player_look`)** |
| `_parry_cd` | 7 | 헛반격(1210), 성공(1219, 1306, 1325), 방어(1482), 이벤트 종료(1536), 타이머 | 모든 액션의 반격 캔슬 조건 (`and _parry_cd <= 0.0` 14곳) |
| `trail.visible` | 13 | 대시·회전 상승·강하·대시 참격 시작/종료, `_stop_abilities` | `_update_trail` |
| `_hitbox_live` | 17 사용 | 평타(622–692), 대시 참격(1113–1169), **궁극기(1575–1643, 다른 의미)** | 각 처리 함수 |
| `_dash_slash_window` | 5 | 대시 종료(606), 회전 상승·강하·대시 참격 시작(868, 1005, 1108), 타이머 | `_process_free`(411) |

---

## 6. 액션 상태 전이 [CS]

`Action` 14값: `NONE, ATTACK, PARRY, DASH, SKILL, DASH_SLASH, LIGHTNING, RISING_SLASH, SPIN_RISE, DIVE, ULTIMATE, HURT, DEAD, LOCKED`. 중앙 전이표나 상태 객체는 없고, 각 `_process_*` 함수가 자기 탈출 조건을 직접 갖는다.

| 현재 | 전이 가능 대상 (조건) | 위치 |
|---|---|---|
| NONE | ULTIMATE > PARRY > DASH+DASH_SLASH(동시) > DASH_SLASH(유예) > 슬롯 스킬 > DASH > ATTACK; 점프는 상태 변화 없음 | 400–427 |
| DASH | ATTACK(예약 없을 때), PARRY, 종료 시 DASH_SLASH(예약) 또는 NONE+유예 | 590–606 |
| ATTACK | PARRY(언제나), DASH(판정 시작 후), 슬롯 스킬(후딜), 다음 콤보, NONE | 646–687 |
| SKILL(장풍) | PARRY(언제나), 발사 전 DASH→DASH_SLASH, 발사 후 DASH, NONE | 739–757 |
| LIGHTNING | PARRY(낙뢰 후), NONE | 810–815 |
| RISING_SLASH | PARRY(웅크림 중), NONE(도약 후 자유) | 838–852 |
| SPIN_RISE | PARRY(마무리 전, 취소 처리 포함), 마무리 중 ATTACK/DASH/PARRY/슬롯 스킬, NONE | 881–925 |
| DIVE | PARRY(`dive_counter_cancel` & 착지 전), NONE | 1016–1047 |
| DASH_SLASH | PARRY, ATTACK(후딜), NONE | 1152–1164 |
| ULTIMATE | NONE만 (캔슬 불가) | 1607–1610 |
| PARRY | NONE (지속시간 후) | 1444–1448 |
| HURT | DASH, NONE | 1743–1748 |
| (모든 상태) | HURT(`_on_hit_received`), DEAD(`_on_died`), LOCKED(`begin_event_lock`) | 1692, 1752, 1524 |
| (상태 검사 약함) | **PARRY**: `_tick_chain`(1414–1415, 현재 action 검사 없음) · `_counter_buffered` 소비(321–324, `_can_take_counter_press`만 검사) / **NONE**: `_try_guard`(1480–1481, PARRY·HURT에서 강제) | §7 |

---

## 7. 책임 간 의존 방식과 위험한 경로

### 7.1 의존 그래프 (책임 단위) [SI]

```text
                     ┌──────────── 입력 (Input.* 39곳, 각 상태 함수에 분산) ────────────┐
                     ▼                                                                    ▼
  [2 자유 상태 입력 중재] ──문자열 slot──▶ [6~11 스킬 자세들] ──호출──▶ Combat/<Ability> 노드
          │                                     │  ▲ hit_landed → _add_ultimate (16)
          ▼                                     ▼  │
  [4 대시] ◀──_dash_start_pos·_dash_slash_window── [11 대시 참격]
          │
          ▼ (거의 모든 상태에서 parry 입력으로 진입)
  [12 반격 MCI/RCI/PRCI] ──_open_chain──▶ [13 연쇄·패기] ──_add_ultimate──▶ [16 궁극기 게이지]
          ▲         │                           ▲
          │         └── Enemy API 직접 호출 (on_parried / on_countered / counter_strike_damage / deflect)
  [14 방어] ──_cancel_chain, _parry_cd──┘        │
  [15 이벤트 잠금] ──_stop_abilities────────────┘
  [17 피격·사망] ──_stop_abilities (공격판정·대시참격·승천·회전상승·강하·연쇄·궤적 일괄 정리)
          │
  모든 책임 ──▶ [18 표시] (_squash, _set_flash, visual.play, trail) ──▶ PlayerVisual
  모든 책임 ──▶ [19 VFX 스폰] + GameFeel
```

### 7.2 상태 전이 정리(exit cleanup)가 경로마다 다르다 [CS 코드 / SI 결과 / RU 체감]

정상 경로는 "`_end_<현재>()` 또는 `_cancel_<현재>()` → `_start_<다음>()`" 패턴이다 (예: `_process_attack` 668–669 `_end_attack(); _start_parry()`). 그러나 다음 세 경로는 **현재 액션의 정리 없이** 상태를 바꾼다:

| 경로 | 위치 | 정리되지 않을 수 있는 것 (추론) |
|---|---|---|
| 슬로모션 중 버퍼된 반격 → `_start_parry()` | `_physics_process` 321–324 | ATTACK 중이면 `AttackHitbox.monitoring`이 켜진 채 남음, SPIN_RISE 중이면 `SpinRise` 판정·운반(`Enemy.State.CARRIED`) 미해제, DASH 중이면 `trail`·대시 무적 정리 생략, DIVE 중이면 몸 접촉 Hitbox 유지 |
| 연쇄 예약 자동 발동 → `_start_parry()` | `_tick_chain` 1414–1415 (현재 `action` 검사 없음) | 위와 같음. 특히 튕겨내기(PRCI) 성공 후 PARRY 자세(0.16초)가 연쇄 창(0.2초)보다 짧아, 그 0.04초 사이 시작한 다른 액션이 정리 없이 끊길 수 있다 (`player.gd:1308`, `chain_window`) |
| 방어 입력 → `action = NONE` | `_try_guard` 1478–1481 | PARRY/HURT에서만 강제 전환 — 이 둘은 정리할 판정이 거의 없어 영향은 작다 |

`_stop_abilities()`(1700–1709)라는 일괄 정리 함수가 있지만 피격·사망·이벤트 잠금에서만 쓰인다. 위 경로들이 실제 플레이에서 문제를 일으키는지는 **실행 검증이 필요하다** [RU]. → SRM_07 R-02.

### 7.3 무적(`hurtbox.invincible`) 소유권 [CS 코드 / SI 결과]

- Player 안에서 17곳이 쓰고, `HurtboxComponent._start_invincibility`(`hurtbox.gd:34-37`)가 피격 0.8초 후 **조건 없이** `false`로 되돌리며, 외부에서도 `Watcher`(272), `XSlash`(69), `Prince`(819, 970)가 `false`로 쓴다.
- 결과로 추론되는 상황: 피격 직후 0.8초 안에 무적 동작(회전 상승·궁극기·반격 성공)을 시작하면, Hurtbox 타이머가 그 동작의 무적을 중간에 해제할 수 있다. 반대로 대시 후 무적 해제(385)가 피격 무적을 일찍 끝낼 수도 있다 [SI/RU]. 시간 무적을 쓰는 Hurtbox는 Player 것뿐이다 (적은 `invincibility_duration` 미설정) [CS]. → SRM_07 R-01.

### 7.4 예측 HP emit [CS]

`_on_hit_received`는 `hit_received`가 `take_damage` **전에** 발생한다는 `HurtboxComponent` 내부 순서에 맞춰 `health_changed.emit(health.hp - damage, …)`로 미리 계산한 값을 보낸다 (1684, 1717, 1726). 치명타 판정도 `health.hp - damage <= 0`(1669). 컴포넌트의 emit 순서가 바뀌면 HUD 표시와 치명타 분기가 함께 틀어진다 [SI]. → SRM_07 R-04.

---

## 8. 독립 책임으로 분리 가능성이 관찰되는 영역 (검토 후보 — 설계 아님)

판단 근거: (a) 다른 책임과 공유하는 상태의 수, (b) 진입/탈출 지점의 수, (c) 외부 시스템과의 계약 여부.

| 영역 | 현재 결합 | 분리 가능성 관찰 | 분리 시 위험한 결합 |
|---|---|---|---|
| **표시/연출** (18·19: `_update_visual`, `_set_flash`, `_spawn_*`, `_sfx`) | 읽기 위주: `action`, `_spin_phase`, `_dive_phase`, `_dive_tilt`, `_iframe_t`, `velocity`, `facing` | **높음** — 상태를 거의 쓰지 않고 읽기만 한다. 이미 `PlayerVisual`로 일부 분리된 선례 | `_squash`·`_set_flash`를 모든 액션 함수가 즉석에서 쓰므로(54곳) 호출 지점이 많다. `visual.modulate.a`를 `_process`(302)와 `_update_visual`(1818–1822)이 함께 씀 |
| **연쇄 반격·패기** (13) | 상태 4개 소유 (`_chain_*`), 진입점 `_open_chain` 3곳, `_cancel_chain` 2곳 | **중간~높음** — 상태가 응집되어 있음 | `_process`의 입력 읽기(313)와 `_tick_chain`이 `_start_parry()`를 직접 부름 (§7.2). `_chain_count`를 반격음 음높이(1316, 1337, 1457)가 읽음 |
| **방어 경로 / 이벤트 잠금** (14·15) | Prince 전용 공개 API 4개 | **중간** — 문서상 "일반 반격과 분리된 경로"로 의도됨 | `_parry_cd`(헛반격 쿨다운)를 일반 반격과 공유, `action`을 PARRY/HURT/LOCKED로 강제 변경, Prince가 Player 내부(`hurtbox`, `health`, `action`)를 직접 만짐 |
| **궁극기 게이지** (16 중 `_add_ultimate`, `is_ultimate_ready`) | `ult_charge` + 시그널 2개, 충전 호출 10곳 | **중간** — 순수 자원 로직 | HUD가 `ult_charge`·`ultimate_max`를 직접 읽음 (`hud.gd:91`) |
| **궁극기 시전 2종** (`_fire_moon_slash`, `_fire_sword_wave`) | `slot_ultimate` 문자열 분기 3곳, 스폰 수치 전달 | **중간** — Ability 노드 패턴(쿨다운·스폰)과 다르게 Player에 스폰 코드가 직접 있음 | `_hitbox_live` 의미 재사용, Player `@export`에 궁극기 수치 13개 |
| **스킬 자세들** (6~11) | `action`, `_action_time`, `velocity`, `facing`, `hurtbox.invincible`, `trail`, `_parry_cd` 공유 | **낮음~중간** — Ability 노드는 이미 분리, 남은 "자세"는 이동·중력·캔슬 규칙과 강하게 얽힘 | 각 자세 함수가 다른 상태로의 전이(PARRY/DASH/ATTACK)를 직접 호출. 캔슬 규칙이 스킬마다 다름(설계 의도) |
| **반격 판정** (12) | Enemy 5개 메서드 + WatcherNeedle 2개 + group 3개, `hurtbox.invincible`, `_parry_cd`, `_chain_*`, `ult_charge` | **낮음** — 게임 정체성의 핵심이며 가장 많이 결합됨 | 우선순위(MCI → RCI → PRCI → 헛반격)와 "입력 1회 = 대상 1개" 규칙이 `_start_parry` 한 함수의 분기 순서로만 표현됨 |
| **이동·대시·콤보** (3·4·5) | 모든 액션이 `velocity`/`_apply_gravity`를 공유 | **낮음** — Player의 본체 | `_apply_gravity`가 `_rising_up`, `_guard_hop`(다른 기능 플래그)을 읽음 (518) |

---

## 9. Player 변경이 다른 시스템에 미치는 영향 [CS 참조 / SI 영향]

### 9.1 외부가 의존하는 Player 표면

| 사용처 | 의존하는 것 |
|---|---|
| `ui/hud/hud.gd:85-92` | 시그널 3개, `player.health.hp/max_hp`, `player.ult_charge`, `player.ultimate_max`, `is_ultimate_ready()` |
| `levels/phase1/phase1.gd` | `$Actors/Player` 경로·타입, `died` 시그널, `global_position`/`velocity`/`is_on_floor()` 직접 조작(237–239) |
| `levels/arena/arena.gd` | `$Actors/Player` 경로·타입, `global_position` |
| `camera/game_camera.gd:52` | `target.get("facing")` (duck typing) |
| `actors/enemies/assassin/assassin.gd:150-152` | `(t as Player).facing` |
| `actors/enemies/prince/prince.gd` | `Player.Action.DEAD`, `action`, `hurtbox`, `health`, `on_guard_impact`, `begin_event_lock`, `end_event_lock`, `event_final_strike` |
| `actors/enemies/enemy.gd:182` | group `"player"` (레벨이 부여) |
| `toolkit/cheats.gd:53-55` | group `"player"`, `force_chain_burst()` |

### 9.2 Player가 의존하는 외부 계약

| 대상 | 계약 |
|---|---|
| `Enemy` | `is_glinting`, `on_parried`, `is_counter_open`, `on_countered`, `counter_strike_damage`, `is_guard_open`, `on_guarded`, `state`(+`Enemy.State.DEAD`), `hurtbox`, `is_contact_hit`, `global_position` |
| `WatcherNeedle` | `is_deflectable`, `deflect` (튕겨낼 수 있는 모든 투사체는 이 클래스를 상속해야 함) |
| Ability 노드 6종 | 서로 다른 메서드 이름 (`can_cast`/`can_use`, `cast`/`begin`/`start_cooldown`/`sweep`, `set_active`/`cancel`/`finish`/`set_body_active`, `advance`, `land`, `travel_time`, `flame_delay`) |
| group | `field_mob`, `counter_threat`, `deflectable`, `enemy`, `guard_threat`, `fx` |
| `GameFeel` / `Engine.time_scale` | hit-stop 중 `_process` 입력 수집이라는 시간 계약 (Knight 역반격 창 0.5초, `bait_time_scale` 0.1) |
| `HurtboxComponent` | `hit_received` → `take_damage` 순서 (§7.4), `invincibility_duration` 타이머 |
| `PlayerVisual` | 애니메이션 이름 문자열 21종 (`KEYS`) + `locomotion`, `body`, `play()`, `tick()`, `set_flash()`, `footstep` |

### 9.3 변경 영향 관찰 [SI]

- 적에게 새로운 반격 유형을 추가하면 지금 구조에서는 **Player의 `_start_parry` 분기·`_has_counter_target`·`_process`의 버퍼 조건 3곳**을 함께 고쳐야 한다 (CrossbowBolt·PrinceWave는 `WatcherNeedle` 상속으로 이 수정을 피했다).
- 새 스킬 추가는 `@export_enum` 목록(101–105) + `_can_cast_skill` + `_cast_skill` + `Action` enum + `_physics_process` match + `_start/_process/_end` 3함수 + `_stop_abilities` + `_ready` 시그널 연결 + `player.tscn` 노드 + `player_tuning.cfg`를 건드린다 (structure.md §5 "새 스킬은 `_can_cast_skill()`/`_cast_skill()`에 이름을 추가한다"로 문서화된 절차).
- `git log` 기준 Player는 프로젝트 커밋의 52%에 등장한다 — 적·보스·스킬 작업이 대부분 이 파일 수정을 동반해 왔다는 객관적 신호다.
