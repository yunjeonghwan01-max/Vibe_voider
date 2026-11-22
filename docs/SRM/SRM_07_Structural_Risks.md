# SRM_07 — 구조적 위험 요소와 Preserve Candidates

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` · Read-Only Static Audit
> **확실성 표기 (근거)**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown
> **위험도**: Critical / High / Medium / Low — 실제 책임, 결합도, 공유 상태, 변경 영향 범위를 기준으로 했다. **코드가 길다는 이유만으로 위험으로 분류하지 않았다.**
> **분석 확실성** (항목별): High / Medium / Low
> **관련**: [SRM_05 Player](SRM_05_Player_Deep_Dive.md) · [SRM_06 흐름](SRM_06_System_Dependencies.md) · [SRM_09 후보](SRM_09_Refactoring_Candidates.md)

---

## 0. 위험 목록 요약

| ID | 제목 | 위험도 | 분석 확실성 | 주 근거 위치 |
|---|---|---|---|---|
| R-01 | Player 무적 플래그의 다중 작성자 · 소유권 부재 | **High** | Medium | `hurtbox.gd:34-37`, `player.gd` 17곳, `watcher.gd:272`, `x_slash.gd:69`, `prince.gd:819,970` |
| R-02 | Player 액션 전이의 정리(exit) 경로 비일관 | Medium | Medium | `player.gd:321-324, 1413-1416, 1185-1226` |
| R-03 | Player 한 클래스에 19개 책임 · 높은 변경 빈도 | **High** | High | `player.gd` 전체, `git log` 24/46 |
| R-04 | 컴포넌트 내부 순서·일시 플래그에 기대는 암묵적 계약 | Medium | High | `hurtbox.gd:26-27`, `player.gd:1669,1684`, `enemy.gd:563-565`, `rally_dummy.gd:29-32`, `knight.gd:188` |
| R-05 | Actor 동작이 레벨 스크립트의 Group 부여에 의존 | Medium | High | `phase1.gd:77-80,182`, `arena.gd:59-62,101…`, `enemy.gd:182` |
| R-06 | 필드몹 간 비공개 상태 교차 참조 + 비대칭 간격 규칙 | Medium | High | `infantry.gd:135-142`, `assassin.gd:221-232`, `giant.gd:212-226` |
| R-07 | 시간 기준 혼재와 hit-stop 덮어쓰기 | Medium | Medium | `game_feel.gd:40-50`, `player.gd:299-315`, `knight.gd:326,656` |
| R-08 | `.tscn` UID 참조 불일치 8건 · 재저장 시 되돌림 이력 | Medium | High(불일치) / Low(영향) | SRM_03 §1, 커밋 `8a26cf4` ↔ `f0f088a` |
| R-09 | 스킬 슬롯의 문자열 라우팅 + Ability API 비일관 | Medium | High | `player.gd:101-105, 442-485`, Ability 6종 |
| R-10 | Prince ↔ Player 양방향 결합 | Medium | High | `prince.gd:249-250, 806-821, 924-971` |
| R-11 | 리팩토링 안전망(자동 테스트·빌드 설정) 부재 | Medium | High | 저장소 전체 |
| R-12 | 같은 개념을 서로 다른 방식으로 처리 | Low | High | §상세 |
| R-13 | 명명과 실제 역할의 불일치 | Low | High | `watcher_needle.gd`, `player.gd:232,279,1575` |
| R-14 | 코드 중복 (헬퍼·궁극기 그리기·레벨 골격) | Low | High | `moon_slash.gd`↔`sword_wave.gd`, `_ray` ×3, `_spark` 계열 |
| R-15 | 설계 문서·주석과 구현의 불일치 | Low | High | `CLAUDE.md`, `enemy.gd:4`, `structure.md:336` |
| R-16 | 튜닝 값의 그림자 사본과 예외 규칙 | Low | High | `player.tscn:140`, `watcher_needle_tuning.cfg`, `tuning.gd` |
| R-17 | 정적 타입 밖의 동적 호출 (HUD·Camera) | Low | High | `phase1.gd:55,83-84`, `game_camera.gd:52` |

**Critical: 해당 없음.** 빌드 불가·데이터 손실·즉시 재현되는 치명적 결함의 정적 증거는 찾지 못했다. (실행 검증을 하지 않았으므로 런타임 치명 결함이 없다는 뜻은 아니다.)

---

## 1. High

### R-01 — Player 무적 플래그(`HurtboxComponent.invincible`)의 다중 작성자 · 소유권 부재

- **위험도** High · **분석 확실성** Medium (코드 사실 [CS], 결과 [SI], 체감 [RU])
- **관련 코드**
  - `combat/components/hurtbox/hurtbox.gd:34-37` `_start_invincibility()`: 피격 후 `invincibility_duration`(Player 0.8초) 뒤 **조건 없이** `invincible = false`.
  - `actors/player/player.gd` 17곳: 385(대시 후 해제), 572(대시), 871·955·965(회전 상승), 1111(대시 참격), 1221·1309·1330(반격 성공), 1447(반격 종료), 1479(방어), 1526·1535(이벤트 잠금), 1579·1608(궁극기), 1754(사망), 1776(부활).
  - 외부 작성자: `watcher.gd:272`, `x_slash.gd:69`, `prince.gd:819`, `prince.gd:970`.
- **근거**: 하나의 bool을 Hurtbox 타이머, Player의 8개 기능, 외부 3개 클래스가 서로 모른 채 켜고 끈다. 참조 카운트·이유별 플래그·우선순위가 없다.
- **문제가 되는 이유 [SI]**: (a) 피격 직후 0.8초 안에 회전 상승(`spin_invincible`)·궁극기·반격 성공을 시작하면 이전 피격의 타이머가 그 동작의 무적을 중간에 끌 수 있다. (b) 대시 후 숨은 무적 해제(385)가 피격 무적을 예정보다 일찍 끌 수 있다. (c) 무적 관통 공격은 "무적을 끈다"로 구현되어 있어, 관통 직후 Player가 기대하던 무적 상태(예: 반격 자세)가 복구되지 않는다.
- **영향 기능**: 반격(MCI/RCI/PRCI) 성공 무적, 대시 무적, 회전 상승, 궁극기, 이벤트 잠금, 보스 무적 관통 공격 — 게임의 핵심 손맛.
- **유지보수 위험**: 무적이 필요한 새 기능을 넣을 때마다 다른 작성자와의 충돌을 수작업으로 따져야 한다.
- **추가 검증 필요**: 실제 플레이에서 "피격 → 0.8초 안에 회전 상승/궁극기/반격 성공" 직후 피해를 받는지 확인. 시간 무적을 쓰는 Hurtbox는 Player 것뿐이다(적에는 `invincibility_duration` 미설정 [CS]).

### R-03 — Player 한 클래스에 19개 책임 · 높은 변경 빈도

- **위험도** High · **분석 확실성** High
- **관련 코드**: `actors/player/player.gd` (1,920줄 / 109함수 / 상태 43 / `@export` 105 / `action` 쓰기 32곳 / `Input.*` 39곳 / `GameFeel.*` 43곳). 책임 지도는 SRM_05 §2.
- **근거 [CS]**: 이동, 대시, 콤보, 반격 4종(MCI·RCI·PRCI·방어), 연쇄·패기, 이벤트 잠금, 스킬 자세 6종, 슬롯 라우팅, 궁극기 2종, 피격·사망·부활, 표시·VFX가 한 클래스에 있다. `git log`상 46커밋 중 24커밋(52%)이 이 파일을 수정했다.
- **문제가 되는 이유 [SI]**: 길이 자체보다 **공유 상태**(`action`, `_action_time`, `velocity`, `facing`, `hurtbox.invincible`, `_parry_cd`, `_hitbox_live`, `trail`)를 거의 모든 책임이 직접 읽고 쓰는 점이 문제다. 한 기능의 수정이 다른 기능의 캔슬 규칙·무적·입력 우선순위를 바꿀 수 있고, 그 영향 범위를 코드 검색만으로 확정하기 어렵다. 적·보스의 새 반격 유형도 Player 수정을 요구한다(SRM_05 §9.3).
- **영향 범위**: 모든 전투 기능, HUD, 레벨(Phase1이 Player 위치·속도 직접 조작), 보스(Prince).
- **유지보수 위험**: 동시 작업 충돌, 회귀 위험, 새 기능 추가 비용 증가. 다만 개별 함수는 짧고(최대 50줄) 섹션 주석이 명확해 **읽기 난이도는 낮다** — 이 점은 장점으로 함께 기록한다.
- **추가 검증**: 불필요 (정적 사실). 분리 여부는 인간 결정 사항 (SRM_09).

---

## 2. Medium

### R-02 — Player 액션 전이의 정리(exit) 경로 비일관

- **위험도** Medium · **분석 확실성** Medium ([CS] 코드 경로, [SI] 결과, [RU] 발생 빈도)
- **관련 코드**: `player.gd:321-324` (슬로모션 버퍼 반격 → `_start_parry()`), `player.gd:1413-1416` (`_tick_chain` → `_start_parry()`, 현재 `action` 검사 없음), `player.gd:1185-1226` (`_start_parry`에 이전 액션 정리 없음), `player.gd:1700-1709` (`_stop_abilities`는 피격·사망·이벤트 잠금에서만 호출).
- **근거**: 일반 캔슬 경로는 `_end_attack(); _start_parry()`처럼 정리 후 전이한다(668–669, 1018–1019, 1153–1154 등). 위 두 경로는 정리 없이 전이한다.
- **문제가 되는 이유 [SI]**: ATTACK 중이면 `AttackHitbox.monitoring`이 켜진 채 남고, SPIN_RISE 중이면 운반 중인 적(`Enemy.State.CARRIED`)이 해제되지 않아 Player를 계속 따라갈 수 있으며(`enemy.gd:339-349`), DASH/DIVE 중이면 궤적·몸 접촉 판정이 남을 수 있다. 튕겨내기 성공 자세(0.16초)가 연쇄 창(0.2초)보다 짧은 것(`player.gd:1308`, `chain_window`)이 이 틈을 만든다.
- **영향 기능**: 연쇄 반격, Knight 역반격(슬로모션 입력 버퍼), 회전 상승 운반.
- **추가 검증 필요**: 슬로모션 중 공격·회전 상승 상태에서 반격 입력, 튕겨내기 직후 0.04초 안 행동 후 연쇄 발동 시 판정·운반 잔류 여부.

### R-04 — 컴포넌트 내부 순서와 일시 플래그에 기대는 암묵적 계약

- **위험도** Medium · **분석 확실성** High
- **관련 코드 [CS]**
  1. `hurtbox.gd:26-27`: `hit_received.emit()`이 `health.take_damage()`보다 먼저. → `player.gd:1669` 치명타 판정 `health.hp - damage <= 0`, `1684/1717/1726` HUD용 `health_changed.emit(health.hp - damage, …)`는 "아직 깎이지 않은 hp"를 전제한다.
  2. `enemy.gd:563-565`: `is_contact_hit = true` → `receive_hit()` → `false`. Player는 동기 시그널 핸들러 안에서 `enemy.is_contact_hit`를 읽는다 (`player.gd:1676-1678`).
  3. `rally_dummy.gd:29-32`: `HealthComponent.take_damage`가 `damaged`를 `died` 판정 전에 emit한다는 순서(`health.gd:29-36`)를 이용해 사망을 막는다.
  4. `knight.gd:188-189`: `hit_received`의 두 번째 핸들러가 "기반 핸들러 다음에 불린다"는 연결 순서를 전제.
  5. `PrinceHealth.floor_hp`로 깎인 피해량을 Player는 모른다 — Player의 예측 HP 방식은 Player 자신에게만 적용되므로 현재는 무해 [SI].
- **문제가 되는 이유**: 계약이 코드 주석에만 있고 타입·API로 표현되지 않는다. `AGENTS.md`/`CLAUDE.md`가 "컴포넌트 API와 동작을 안정적으로 유지"하라고 하므로 현재는 지켜지지만, 컴포넌트 수정 시 4개 파일의 동작이 조용히 바뀐다.
- **영향**: HUD 체력 표시, 치명타 처리, 접촉 피해 반응, 랠리 더미, Knight 피격 연출.

### R-05 — Actor 동작이 레벨 스크립트의 Group 부여에 의존

- **위험도** Medium · **분석 확실성** High
- **관련 코드 [CS]**: `"player"`·`"fx"`·`"projectiles"`는 `phase1.gd:77-80`, `arena.gd:59-62`가, `"enemy"`는 레벨 스폰 함수(`phase1.gd:182,255`, `arena.gd:101,111,122,218`)가 부여한다. 조회: `enemy.gd:182`(타깃), `player.gd:1355`(반격 경로 피해), `sword_wave.gd:153`, `void_mark.gd:53`, `haki_burst.gd:83`.
- **문제가 되는 이유 [SI]**: 새 레벨이나 테스트 씬에서 이 부여를 빠뜨리면 — 적이 타깃을 못 찾고(`get_target()` null), 궁극기·패기·반격 경로 피해가 적을 무시하며(그룹 `enemy` 미포함), VFX는 대체 경로(Player 부모)에 붙는다. 오류 메시지 없이 "조용히" 동작이 달라진다. Phase1과 Arena가 같은 부여 코드를 각자 가진다.
- **영향**: 새 레벨 추가, 레벨 단위 테스트 씬, 씬 재구성.

### R-06 — 필드몹 간 비공개 상태 교차 참조 + 비대칭 간격 규칙

- **위험도** Medium · **분석 확실성** High
- **관련 코드 [CS]**: `infantry.gd:135-142` (Infantry만 확인), `assassin.gd:221-232` (Infantry + Assassin 확인), `giant.gd:212-226` (Infantry + Assassin + Giant 확인). 모두 다른 클래스의 **비공개** `_atk`, `_atk_elapsed`와 내부 enum(`Infantry.Atk.RAISE` 등)을 읽는다. `infantry.gd:123-131 _ally_ahead`도 같은 방식.
- **설계 문서와 불일치**: `docs/structure.md:336` "보병·암살자·거병은 **다른 제3부대가** 막 공격을 치켜들었으면 `crowd_attack_gap`만큼 기다린다". 실제로는 보병은 보병만, 암살자는 거병을 기다리지 않는다.
- **문제가 되는 이유**: 같은 규칙이 3곳에 다른 범위로 복제되어 있고, 새 필드몹 추가 시 기존 3개 파일 모두를 고쳐야 규칙이 대칭이 된다. 한 클래스의 내부 상태 이름 변경이 다른 클래스를 깨뜨린다.
- **영향**: Phase1 전투 가독성(반짝임 겹침), 새 필드몹 추가 비용.
- **추가 검증**: 비대칭이 의도인지(디자인 판단) 인간 확인 필요 [UK].

### R-07 — 시간 기준 혼재와 hit-stop 덮어쓰기

- **위험도** Medium · **분석 확실성** Medium
- **관련 코드 [CS]**: `game_feel.gd:40-50` (토큰 방식: 마지막 `hit_stop`이 이전 복구를 무효화), `player.gd:299-315` (`Engine.time_scale < 1.0`일 때 `_process`에서 입력 수집), `knight.gd:326,651,656-658` (역반격 창을 실제 시간 `Time.get_ticks_msec()`로 측정, `hit_stop(0.5, 0.1)`), 실제 시간 연출: `x_slash.gd`, `haki_burst.gd`, `lightning_bolt.gd`, `knight_cross.gd`.
- **문제가 되는 이유 [SI]**: 물리 시간 / 실제 시간 / `_process` 입력 수집 세 기준이 섞인 계약이 주석으로만 존재한다. 역반격 창(0.5초, 10% 속도) 동안 다른 `hit_stop` 호출(같은 순간의 다른 명중·연출 등, `scale` 기본값 0)이 들어오면 time_scale이 그 값으로 바뀌고, **그 호출의 짧은 지속시간이 끝날 때 1.0으로 복구되어 슬로모션이 조기 종료**될 수 있다 (창 길이 자체는 실제 시간 `_bait_end_ms`로 재므로 유지된다). 실제로 그런 중첩이 발생하는 플레이 상황이 있는지는 확인하지 않았다. 반대로 패기 방출(`hit_stop(0.28, 0.12)`)이 반격 연출 hit-stop을 덮지 않도록 호출 순서를 맞춘 코드도 있다(`player.gd:1388-1389` 주석).
- **영향**: Knight CCI 랠리, 연쇄 반격, 모든 타격감 연출.
- **추가 검증 필요**: 역반격 창 중 다른 명중 발생 시 슬로모션 유지 여부.

### R-08 — `.tscn` UID 참조 불일치 8건 · 재저장 시 되돌림 이력

- **위험도** Medium · **분석 확실성** High(불일치 존재) / Low(로딩 영향)
- **관련 코드 [CS]** (참조하는 쪽 `uid=` ≠ 대상 씬 헤더 UID):
  - `actors/player/player.tscn` → slash.tscn(`ccyhs5hooem53` ≠ `bslashvfx00001`), spark.tscn(`cgygv5hooem53` ≠ `bsparkvfx00001`), afterimage.tscn(`dikf12agie0xw` ≠ `bafterimg00001`)
  - `dive_blast.tscn`, `sword_wave.tscn`, `void_orb_projectile.tscn` → spark.tscn (`cgygv5hooem53`)
  - `app/main.tscn` → arena.tscn (`c2gt8w17qxv41` ≠ `carenavoider01`)
  - `levels/phase1/phase1.tscn` → hud.tscn (`cfmdhfvl16emi` ≠ `chudvoider0001`)
- **이력 [CS]**: 커밋 `8a26cf4`("Restore Arena scene UID in main scene — An editor re-save swapped the reference to a UID arena.tscn does not declare")가 `carenavoider01`로 되돌렸으나, 최신 커밋 `f0f088a`("Editor resave: refresh scene UIDs")에서 다시 `c2gt8w17qxv41`로 바뀌었다. 불일치 대상 5개 씬은 모두 **사람이 쓴 형태의 헤더 UID**를 가진다.
- **문제가 되는 이유 [SI]**: 수기 UID와 에디터가 관리하는 UID가 엇갈려, 에디터 재저장 때마다 참조가 바뀌는 diff가 생기고 리팩토링(파일 이동) 시 UID 기반 안전성이 약해진다. 실제 로딩은 Godot이 경로로 대체할 가능성이 높으나 확인하지 않았다 [RU]. `.godot/uid_cache.bin`은 바이너리라 감사에서 해석하지 않았다 [UK].
- **추가 검증 필요**: 에디터 출력의 UID 경고, 새로 clone한 환경(캐시 없음)에서의 로딩.

### R-09 — 스킬 슬롯의 문자열 라우팅 + Ability API 비일관

- **위험도** Medium · **분석 확실성** High
- **관련 코드 [CS]**: `player.gd:101-105` (`@export_enum` 문자열), `442-468` (`match skill:` 2곳), `475-485`, `1589`, `1598-1604` (`slot_ultimate == "sword_wave"` 비교 3곳). Ability API: `can_cast()`(VoidOrb, Lightning) / `can_use()`(DashSlash, SpinRise, Dive, RisingSlash); 시작 `cast()`/`begin()`/`start_cooldown()`+`begin_charge()`/`sweep()`; 종료 `set_active(false)`/`cancel()`/`finish()`/`set_body_active(false)`.
- **문제가 되는 이유 [SI]**: `Tuning.apply`는 문자열 값을 검증하지 않으므로(`tuning.gd:33-41`) `player_tuning.cfg`에 오타가 있으면 그 슬롯은 **경고 없이 아무것도 하지 않는다** (`_can_cast_skill`이 `false` 반환). 새 스킬 하나에 Player의 여러 지점(SRM_05 §9.3)을 손대야 한다. 기획 문서는 "스킬을 갈아끼우는 시스템"을 핵심으로 정의한다(`VOIDER_PHASE1_DESIGN_MEMORY` §0).
- **영향**: 스킬 추가·교체 작업 비용, 튜닝 파일 편집 실수의 발견성.

### R-10 — Prince ↔ Player 양방향 결합

- **위험도** Medium · **분석 확실성** High
- **관련 코드 [CS]**: `prince.gd:249-250` (`get_target() as Player`, `p.action == Player.Action.DEAD`), `806-821` (`p.on_guard_impact()`, `p.hurtbox.invincible = false`, `p.hurtbox.receive_hit()`), `924-971` (`p.begin_event_lock()`, `p.event_final_strike(self, health.hp)`, `p.end_event_lock()`, `p.health.hp`). 반대 방향: Player `_try_guard`/`_open_guard_threat`(1471–1499)가 `is_guard_open`/`on_guarded` 호출.
- **문제가 되는 이유 [SI]**: 보스가 Player의 내부 상태 enum·컴포넌트를 직접 조작한다. Player의 `Action` 구성이나 무적 처리 방식을 바꾸면 Prince가 깨지고, Prince 패턴 변경이 Player 공개 API를 늘린다(이벤트 잠금 3개 메서드는 Prince 전용). 다른 보스가 비슷한 이벤트를 원하면 같은 방식의 결합이 늘어난다.
- **영향**: Phase1 보스전 전체 (패턴 4·5, 재시작).

### R-11 — 리팩토링 안전망 부재

- **위험도** Medium · **분석 확실성** High
- **근거 [CS]**: 자동화 테스트 없음(`CLAUDE.md` "There are no automated tests in this repo"), CI 없음, `export_presets.cfg` 없음, 브랜치는 `main`만 존재하고 merge 커밋 0 (`git log`). 검증 수단은 headless import/quit와 수동 플레이뿐.
- **문제가 되는 이유 [SI]**: R-01·R-02·R-07처럼 **타이밍 의존 동작**이 많은 코드를 구조 변경하면, 회귀를 플레이테스트로만 잡아야 한다. 곧 진행할 소프트 리팩토링의 가장 큰 실무 위험이다.
- **참고**: fast-forward 병합은 merge 커밋을 남기지 않으므로 "전용 브랜치 작업" 여부는 이력만으로 판단할 수 없다 [UK].

---

## 3. Low

### R-12 — 같은 개념을 서로 다른 방식으로 처리 [CS]

| 개념 | 방식 A | 방식 B |
|---|---|---|
| 적 사망 추가 처리 | `_on_died` 오버라이드 + `super` (Crossbowman, Prince) | `health.died`에 핸들러 추가 연결 (Watcher `_on_watcher_died`, Knight `_on_knight_died`) |
| `counter_threat` 그룹 | 씬 선언 (Prince) | 코드 `add_to_group` (Knight, Watcher) |
| 필드 정리 | Phase1: `projectiles` 자식 전부 `queue_free` | Arena: `WatcherNeedle`만 골라 삭제 |
| 스폰 컨테이너 대체 경로 | `owner.get_parent()` (Ability 4종) | `get_parent()` (Player, Enemy, 투사체) |
| 반격 대상 탐색 | MCI: 물리 겹침(`ParryBox`) | RCI/PRCI/방어: group 순회 + 상태 질의 |
| 일시정지 중 타이머 | `create_timer(t)` (process_always 기본 true — Arena 리스폰, Player 부활, Hurtbox 무적) | `create_timer(t, false)` (Phase1 웨이브, Enemy 시체 유지) |

영향은 작지만, 새 코드 작성 시 어떤 방식을 따라야 할지 기준이 없다.

### R-13 — 명명과 실제 역할의 불일치 [CS]

- `WatcherNeedle`: 실제로는 감시자 구체·석궁 볼트·왕자 검격 공용 **PRCI 투사체 기반 클래스**. Player도 이 타입으로 튕겨낼 대상을 찾는다 (`player.gd:1282-1296`).
- `_hitbox_live`: 평타·대시 참격에서는 "판정 켜짐", 궁극기에서는 "발사했는가" (`player.gd:1575` 주석).
- `_on_lightning_hit`: 승천 참격의 명중에도 연결 (`player.gd:279`).
- `counter_slash_scene`(Player) = `xslash_scene`(Knight) = 같은 `XSlash`.
- "parry"(`ParryBox`, `_start_parry`, `parry_*` 수치)가 MCI·RCI·PRCI 전체 진입점을 뜻한다. 사람이 쓰는 용어(MCI/RCI/PRCI/CCI)는 코드 식별자에 아직 없다 (`AGENTS.md` Counter Terminology에 명시된 현재 상태).

### R-14 — 코드 중복 [CS]

- `moon_slash.gd` ↔ `sword_wave.gd`: 상수 5개 동일(`RADIUS`, `HALF_ANGLE`, `THICK`, `ARC_STEPS`, `RESHAPE_EVERY`), 가속 비행식·벽 판정·`_reshape` 일부·`_draw_crescent`/`_draw_shards`(44줄 블록 중 가시 그리기 등 일부만 다름).
- `_ray()` 3중복 (assassin:178, crossbowman:117, giant:194 — 본문 동일), `_projectile_parent()` 2곳, `_spark()`류 헬퍼 5곳(haki, lightning, moon, sword_wave, x_slash 루프), `_past_screen_edge()` 2곳, `_visible_world_rect()`, `_a()` 색상 헬퍼 3곳, `_spawn_slash()` 6곳.
- Phase1/Arena: group 부여·카메라 target·HUD bind·음악 루프 연결·시차 배경 코드가 거의 같다.
- 중복의 대부분은 짧은 헬퍼와 그리기 코드이며 **현재 사용처마다 미세하게 다르다** — 통합 이득은 제한적이다 [SI].

### R-15 — 설계 문서·주석과 구현의 불일치 [CS]

- `CLAUDE.md` Project overview: "template … not a game … Game-specific systems (player, enemies…) are created in each project", "holds the current level instance (none yet in the template)" — 실제로는 완성 중인 게임 Voider이며 레벨 2개·적 9종이 있다.
- `CLAUDE.md` Architecture: Toolkit 기능 목록에 치트(`cheats.gd`)가 없다.
- `enemy.gd:4` "두 실사용자(Grunt, Duelist)" — 실제 하위 클래스 9개.
- `docs/structure.md:336` crowd 규칙 — R-06.
- 상세 비교는 SRM_08.

### R-16 — 튜닝 값의 그림자 사본과 예외 규칙 [CS]

- 튜닝 파일이 이기므로 `.gd` 기본값·`.tscn` 값은 실행에 쓰이지 않는 사본이다 (예: `player.tscn:140 invincibility_duration = 0.5` vs 튜닝 0.8, `void_orb_ability.gd:12 cooldown = 0.9` vs 튜닝 4.0). 사람이 코드나 씬을 보고 값을 오해할 수 있다.
- `AGENTS.md`는 "스폰물은 자체 튜닝 파일이 없다"고 하지만 `watcher_needle_tuning.cfg`가 예외로 존재한다. 그 하위 클래스(`CrossbowBolt`, `PrinceWave`)는 스폰하는 쪽이 값을 넣는데, `WatcherNeedle._enter_tree`의 `Tuning.apply`가 `add_child` **이후** 실행되므로, 누군가 `crossbow_bolt_tuning.cfg`를 만들면 스폰 값이 조용히 덮인다 [SI].
- 정적 검증 결과 12개 튜닝 파일의 섹션·키는 전부 실제 노드·속성에 대응한다 — 현재 깨진 키는 없다 (SRM_10 §4).

### R-17 — 정적 타입 밖의 동적 호출 [CS]

- `Hud`에 `class_name`이 없어 레벨이 `CanvasLayer` 타입 변수로 `bind()`, `set_tally()`, `show_boss()`, `hide_boss()`를 부른다 (`phase1.gd:55,83-84,257,284`, `arena.gd:36,65,74…`). 메서드 이름 변경 시 정적 오류가 나지 않는다.
- `GameCamera`가 `target.get("facing")`로 Player 필드를 읽는다 (`game_camera.gd:52`).
- HUD의 "WATCHERS" 처치 수 표시는 Arena 전용 개념이 공용 HUD에 들어간 사례 (`hud.gd:43-45`).
- 미사용 입력 액션 3개(`player_confirm`, `player_cancel`, `player_interaction` — 마지막은 ↓ 키를 `player_move_down`과 공유).

---

## 4. Preserve Candidates — 유지할 가치가 있는 구조

책임이 명확하고, 의존성이 단순하며, 변경 영향이 제한적인 구조. **리팩토링 시 깨지 않도록 보호할 대상**으로 제안한다.

| ID | 구조 | 근거 [CS] | 유지 가치 |
|---|---|---|---|
| P-01 | **공용 피해 파이프라인** `Hitbox → Hurtbox → Health` | 3개 파일 68 Code Lines. 모든 피해(17개 직접 호출 포함)가 `HurtboxComponent.receive_hit()`을 지난다. 대상 판별은 `area as HurtboxComponent` 타입 검사 (`area.owner`/`has_method` 사용 0건). | 단일 경로라 디버깅·밸런싱 지점이 명확하다 |
| P-02 | **Tuning 시스템** (`core/data/tuning.gd` + `*_tuning.cfg` 12개) | 32줄. 정적 검증 결과 섹션·키 불일치 0건. 한국어 주석으로 사람이 직접 편집 가능. 타입 배열 처리까지 고려. | 인간이 코드를 열지 않고 수치를 바꾸는 통로 — Pure Vibe 운영의 핵심 |
| P-03 | **Scene 참조 규칙** (`@export PackedScene` + `.tscn` 지정) | 게임 코드의 하드코딩 경로 0건 | 파일 이동에 강하다 (UID 문제 R-08은 별개) |
| P-04 | **Collision Layer 체계** | `[layer_names]` ↔ `CollisionLayers` 상수 일치, 38개 씬에서 일관 적용, 예외(ParryBox·CounterGuard·layer 0 공격)는 문서화 | 반격 가능/불가 공격을 레이어로 구분하는 설계가 명확 |
| P-05 | **Enemy 템플릿 메서드 기반 클래스** | 9개 하위 클래스가 훅만 오버라이드. 피격·스태거·에어본·추방·운반·접촉 피해를 복제 없이 공유 | 적 추가 비용이 낮다 (필드몹 1종 200~330줄) |
| P-06 | **Ability 노드 패턴** (쿨다운·판정·스폰 = `Combat/<Skill>`, 수치는 스폰물에 전달) | 6종 모두 Player 씬 노드 + 자체 스크립트, 스폰물에 수치 전달로 "객체당 튜닝 파일 1개" 유지 | 이미 Player에서 절반쯤 분리된 구조 — 확장의 출발점 |
| P-07 | **PRCI 투사체 상속 재사용** (`WatcherNeedle` ← `CrossbowBolt` 16줄, `PrinceWave` 32줄) | 새 투사체가 Player 수정 없이 튕겨내기 경로를 탄다 | 이름(R-13)과 별개로 메커니즘은 효과적 |
| P-08 | **Toolkit / Cheats 격리** | 본편 → 툴킷 의존 0, 툴킷 → 본편은 공개 메서드만. `rally_dummy/`는 폴더째 삭제 가능하도록 설계(`cheats.txt`) | 개발 도구가 게임 코드를 오염시키지 않는다 |
| P-09 | **비동기 흐름 토큰** (`_wave_id`, `_fight_counter`, `GameFeel._hitstop_token`) | `await` 후 상태가 바뀌었으면 무시 (`phase1.gd:195,242,269,288`) | 재시작·치트로 흐름이 꼬이는 것을 막는 단순한 장치 |
| P-10 | **자급식 `_draw` 이펙트 노드** | Slash/Spark/Glint/Afterimage/GroundImpact 등 외부 에셋 없이 스스로 수명 관리 후 `queue_free` | 이펙트 추가·삭제가 국소적 |
| P-11 | **결정적 오프라인 에셋 생성기** | 고정 seed, 게임 런타임 의존 0, 부분 재생성 인자 지원 | 라이선스 문제 없는 placeholder 파이프라인 |
| P-12 | **Resource 공유 안전장치** | 적 hit_flash 머티리얼 `resource_local_to_scene` 9/9, 실행 중 크기를 바꾸는 Shape는 `duplicate()` | 인스턴스 간 시각·판정 간섭 방지 |
| P-13 | **`PlayerVisual` 분리** | 애니메이션 키프레임·프레임 선택이 별도 클래스(134줄), Player는 `play()`/`tick()`만 호출 | Player 분리 시 참고할 수 있는 기존 선례 |
| P-14 | **코드 내 한국어 의도 주석** | 대부분의 스크립트 머리에 규칙·의도·수치 근거가 기술됨 | 사람이 구조를 이해하는 데 실제로 도움 — 유지보수 비용을 낮춘다 |
| P-15 | **Main 레벨 교체 방식** | `_enter_tree`에서 자식이 트리에 들어가기 전에 교체 (기본 레벨이 한 프레임도 돌지 않음), 22 Code Lines | 단순하고 부작용이 작다 |
