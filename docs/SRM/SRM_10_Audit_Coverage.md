# SRM_10 — 감사 범위 · 커버리지 · 검증

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` · Read-Only Static Audit
> **확실성 표기**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown
> **최종 상태**: **Partial Audit** (§8)

---

## 1. 조사 범위와 방법

| 항목 | 내용 |
|---|---|
| 대상 | 프로젝트 루트 `C:\Dev\Godot\Vibe_voider` — `.git/`·`.godot/` 제외 404개 파일 |
| 방법 | 파일 직접 열람(Read/`cat`), `grep`/`awk`/`find` 패턴 추출, `git log`/`git show`/`git status`(읽기 전용), 감사용 임시 스크립트 4개 |
| 감사용 임시 스크립트 | `gd_struct.sh`(GDScript 구조·의존 패턴 추출), `tscn_tree.py`(Scene 트리 파서), `uid_check.py`(UID 대조), `tuning_check.py`(튜닝 키 대응) — **모두 프로젝트 밖 세션 scratchpad에 두었고 프로젝트 파일을 읽기만 했다** |
| 수행하지 않은 것 | Godot 에디터 실행, headless import/quit, 게임 실행, 빌드, 테스트, 파일 수정·이동·삭제, 지침 수정 |
| 쓰기 | `docs/SRM/` 디렉터리 생성(감사 시작 시 미존재 확인) + 신규 보고서 10개 |

---

## 2. 발견 파일 vs 분석 파일 대조 [CS]

### 2.1 분류별 집계 (프로젝트 파일 404개)

| 분류 | 파일 수 | 내역 |
|---|---:|---|
| **A. 직접 내용 확인 (전문)** | **64** | `.gd` 39 · `.tscn` 9 · 튜닝 `.cfg` 3 · `.md` 4 · `.txt` 2 · `.json` 2 · `.gdshader` 1 · `project.godot`·`.gitignore`·`.gitattributes`·`.editorconfig` 4 |
| **B. 부분 정독 + 전 줄 패턴 추출** | **16** | `.gd` 16 (§2.3) |
| **C. 정적 추출만 (본문 정독 없음)** | **44** | `.gd` 6 (패턴 추출) · `.tscn` 29 (파서) · 튜닝 `.cfg` 9 (섹션·키 대응 검증) |
| **D. 참조 관계만 확인** | **247** | `.uid` 62 (UID 대조에 사용) · `.import` 85 (UID 추출) · PNG 35 · WAV 50 (존재·참조 여부) · `.gitkeep` 15 (존재·형제 파일) |
| **E. 읽기 실패 · 분석 불가** | **0** | 프로젝트 파일 중 읽기에 실패한 파일 없음 |
| **F. 명시적 제외** | **33** | `addons/godot_mcp/` 전체 — `plugin.cfg` 내용 확인, `.gd` 16개는 줄 수·함수 수만 측정, `.gd.uid` 16 |
| **합계** | **404** | 발견 파일 수와 일치 |

프로젝트 밖 제외: `.git/`(저장소 메타데이터 — 명령으로만 조회), `.godot/` 249개(에디터 캐시·import 결과, `.gitignore` 대상 — 목록만 확인, `uid_cache.bin`은 바이너리라 해석하지 않음 [UK]).

### 2.2 A. 전문 정독한 `.gd` 39개

`app/main.gd` · `core/data/tuning.gd` · `core/physics/collision_layers.gd` · `managers/game_feel.gd` · `camera/game_camera.gd` · `ui/hud/hud.gd` · `world/props/brazier/brazier.gd` · `levels/phase1/phase1.gd` · `levels/arena/arena.gd` · `toolkit/toolkit.gd` · `toolkit/debug_hud.gd` · `toolkit/cheats.gd` · `toolkit/rally_dummy/rally_dummy.gd` · `combat/components/{health,hitbox,hurtbox}.gd` · `combat/attacks/x_slash/x_slash.gd` · `combat/effects/{glint,slash,spark,afterimage}.gd` · `actors/player/player.gd` · `actors/player/player_visual.gd` · `actors/player/abilities/{void_orb_ability, void_orb_projectile, dash_slash_ability, lightning_ability, rising_slash_ability, spin_rise_ability, dive_ability, void_mark}.gd` · `actors/enemies/enemy.gd` · `grunt.gd` · `infantry.gd` · `watcher_needle.gd` · `crossbow_bolt.gd` · `prince_wave.gd` · `prince_health.gd` · `prince_clash.gd`

`.tscn` 원문 정독 9개: `app/main.tscn`, `toolkit/toolkit.tscn`, `toolkit/rally_dummy/rally_dummy.tscn`, `actors/player/player.tscn`(1–247행 원문 + 나머지 파서), `combat/attacks/x_slash/x_slash.tscn`, `combat/effects/{glint,slash,spark,afterimage}.tscn`. 레벨 2개는 인스턴스 오버라이드 구간 원문 확인.

### 2.3 B. 부분 정독 16개 (정독 구간)

| 파일 | 정독 구간 | 미정독 구간의 성격 |
|---|---|---|
| `knight.gd` (1,147) | 153–377, 535–704, 780–944 | 선언부(구조 추출로 확인), 패턴 선택·근접·상승(378–534), 착지·후퇴(705–779), 연출·애니메이션·그리기(945–1147) |
| `prince.gd` (1,150) | 1–30, 205–270, 785–999 | 선언부(구조 추출), 패턴 1~4 진행(271–784), 애니메이션·그리기(1000–1150) |
| `watcher.gd` (358) | 195–300 | 비행·시야(1–194), 반격당함·애니메이션(301–358) |
| `assassin.gd` (384) | 147–157, 215–245 | 순보 AI·애니메이션 |
| `giant.gd` (404) | 205–232, 290–332 | 행군·돌진·애니메이션 |
| `crossbowman.gd` (297) | 100–195 | 경계·후퇴·애니메이션 |
| `moon_slash.gd` (378) | 46–217 | 그리기(218–378) |
| `sword_wave.gd` (244) | 57–181 | 그리기 |
| `haki_burst.gd` (217) | 26–125 | 그리기 |
| `lightning_bolt.gd` (270) | 37–146 | 그리기 |
| `dive_blast.gd` (159) | 22–95 | 그리기 |
| `prince_aura.gd` (103) | 1–84 | 그리기 |
| `counter_tell.gd` (96) | 1–58 | 그리기 |
| `watcher_beam.gd` (64) | 1–30 | 그리기 |
| `sprite_gen.gd` (2,312) | 1–45 + 함수 목록 | 그림 생성 함수 본문 |
| `audio_gen.gd` (1,125) | 1–25 + 함수 목록 | 소리 합성 함수 본문 |

C의 `.gd` 6개 (본문 정독 없이 구조 추출만): `duelist.gd`, `knight_cross.gd`, `prince_quake.gd`, `ground_impact.gd`, `dash_slash_effect.gd`, `spin_rise_effect.gd`.

**보완**: B·C에 속한 22개 파일도 `gd_struct.sh`로 **모든 줄**에서 다음 패턴을 추출했다 — `class_name/extends`, `signal`, `enum/const`, `@export`, `@onready`·`$Path`·`get_node`·`get_parent`·`owner`, 함수 선언, Group 조작·조회, `connect/emit`, `instantiate/add_child/queue_free/.new()`, `preload/load/res://`, `GameFeel`·`Engine.time_scale`·`Input`·`static var`. 따라서 **의존 관계 분석(SRM_06)은 61개 전 파일에 대해 완료**되었고, 미정독 구간은 주로 그리기·애니메이션·보스 AI 세부 분기다 [SI].

---

## 3. 측정 방법 (요약 — 상세는 SRM_04 §1)

- Physical Lines = 전체 줄, Code Lines = 공백·주석 전용 줄 제외, Function Count = `func 이름` 선언(람다 제외).
- 줄 번호는 감사 시점 소스 기준. `git log` 변경 빈도는 `git log --name-only` 집계.

---

## 4. 정적 검증 결과 [CS]

| 검증 | 결과 |
|---|---|
| GDScript 인벤토리 | 발견 77 = 프로젝트 61 + 애드온 16, **61개 전부 SRM_04 인벤토리에 기재** |
| Scene 인벤토리 | 발견 38 = SRM_03 인벤토리 38 |
| `class_name` 중복 | 0 |
| 게임 코드의 하드코딩 리소스 경로 | 0 (예외: `tuning.gd` 경로 계산, 에셋 생성기 출력 경로) |
| `area.owner` / `has_method()` 대상 탐색 | 0 |
| 에디터 `[connection]` | 0 (코드 `connect` 55, `disconnect` 0) |
| 튜닝 파일 섹션·키 ↔ 노드·속성 | 12개 파일 · 키 389개 — **불일치 0** |
| `.tscn` ext_resource 대상 파일 존재 | 314개 참조 중 누락 0 |
| UID 참조 일치 | uid 표기 64개 중 **불일치 8** (SRM_07 R-08), 헤더 UID 없는 `.tscn` 19개 |
| `assets/temporary/` 미참조 에셋 | 0 / 미참조: `assets/characters/player/Voider Player01.png` 1개 |
| `.gitkeep` 규칙 | 15개 모두 형제 파일 없음 (위반 0) |
| 미사용 입력 액션 | 3 (`player_confirm`, `player_cancel`, `player_interaction`) |

---

## 5. 런타임 미검증 사항 [RU]

| 항목 | 관련 |
|---|---|
| 무적 플래그 경합으로 무적 구간이 끊기는지 | R-01 |
| 정리 없는 상태 전이로 판정·운반이 남는지 | R-02 |
| `hit_stop` 중첩 시 슬로모션 조기 종료 여부 | R-07 |
| UID 불일치 참조의 로딩 결과·에디터 경고 | R-08 |
| `Tuning.apply` 실행 시 `[Tuning]` 경고 유무 | P-02 |
| 예상 런타임 Scene Tree (SRM_03 §7.2) | SRM_03 |
| 실행 흐름 A~H의 실제 순서·타이밍 (물리 콜백 순서 포함) | SRM_06 §10 |
| 성능(프레임 비용 — 매 프레임 Group 순회, `_draw` 재그리기) | 측정하지 않음 |
| 게임플레이 체감 (난이도·손맛) | 감사 범위 밖 |

---

## 6. Git 상태 및 변경 여부 검증 [CS]

### 6.1 시작 시점 (감사 첫 명령)

```text
branch main · HEAD f0f088a
 M .vscode/settings.json
?? .archify/dd.txt
?? .claude/settings.json
?? VOIDER_PHASE1_DESIGN_MEMORY_2026-10-28.md
docs/SRM/ : 존재하지 않음 (충돌 없음)
```

### 6.2 종료 시점 (보고서 작성 후)

```text
branch main · HEAD f0f088a (변화 없음)
 M .vscode/settings.json                       ← 감사 전부터 존재 (diff 동일: 1 insertion, 1 deletion)
?? .archify/dd.txt                              ← 감사 전부터
?? .claude/settings.json                        ← 감사 전부터
?? VOIDER_PHASE1_DESIGN_MEMORY_2026-10-28.md    ← 감사 전부터
?? docs/SRM/SRM_01_Executive_Summary.md … SRM_10_Audit_Coverage.md   ← 이번 감사가 만든 신규 파일 10개
```

- 추적 파일 diff: `.vscode/settings.json` 1건뿐이며 감사 시작 전과 동일하다 → **기존 추적 파일 변경 없음**.
- 감사 시간대(20:00 이후) 수정 파일 검색(`find -newermt`, `.git` 제외): `docs/SRM/` 보고서 외에 **`.godot/editor/` 3개**(`editor_layout.cfg`, `main.tscn-editstate-….cfg`, `script_editor_cache.cfg`, 모두 20:04:06)가 갱신되었다.
  - 이 감사는 Godot을 실행하지 않았다. 감사 시점에 사용자 환경에서 **Godot 에디터 프로세스가 실행 중**(`Godot.exe`, PID 7088)이었으므로, 에디터가 자신의 상태 캐시를 저장한 것으로 판단한다 [SI]. 세 파일은 `.gitignore` 대상(`.godot/`) 에디터 상태 캐시이며 프로젝트 소스·Scene·Resource·설정이 아니다.
  - **주의**: 에디터가 열려 있는 상태이므로, 이후 에디터에서 저장하면 `.tscn` UID 등이 다시 바뀔 수 있다 (R-08과 같은 현상). 이는 감사 범위 밖의 변경이다.
- 덮어쓰기·삭제한 기존 파일: 없음. `docs/SRM/` 파일명 충돌: 없음.

---

## 7. 최종 검증 체크리스트

| # | 항목 | 결과 | 근거 |
|---:|---|---|---|
| 1 | 전체 파일 통계와 실제 인벤토리 일치 | **예** | 404 = 확장자별 합계 = 분류 A~F 합계 (SRM_02 §1, 본 문서 §2.1) |
| 2 | 발견한 모든 GDScript 인벤토리 포함 | **예** | 프로젝트 61개 전부 SRM_04 §4, 애드온 16개 SRM_04 §4.6 |
| 3 | 주요 Scene 정적 Node 구조·Script 연결 확인 | **예** | 38개 전부 파서 추출, 핵심 9개 원문 (SRM_03) |
| 4 | Player 책임·주요 상태 변경 지점 분석 | **예** | `player.gd` 전문 정독 (SRM_05) |
| 5 | 핵심 시스템 의존 관계·대표 실행 흐름 추적 | **예** (정적) | 흐름 A~H (SRM_06 §10), 타이밍은 RU |
| 6 | 구조적 위험에 실제 코드 근거 제시 | **예** | 위험 17개 모두 파일·줄 번호 (SRM_07) |
| 7 | 유지할 가치가 있는 기존 구조 검토 | **예** | Preserve Candidates 15개 (SRM_07 §4) |
| 8 | Structure V0 설계 의도와 실제 구현 구별 | **예** | SRM_08 §4 (일치 / 불일치·미구현 / 문서에 없는 구현) |
| 9 | 기존 개발 지침의 존재 여부·주요 규칙 확인 | **예** | 발견·미발견 목록 + 분류 (SRM_08 §1–3) |
| 10 | 분석하지 못한 파일·검증할 수 없는 동작 명시 | **예** | 본 문서 §2.3, §5 |
| 11 | 사실·추론·제안 구분 | **예** | [CS]/[SI]/[RU]/[UK] 표기, 제안은 SRM_09에만 |
| 12 | 허용된 보고서 외 프로젝트 파일 변경 없음 | **예** (조건부 설명) | 추적 파일 diff 불변, 신규 파일은 `docs/SRM/` 10개뿐. `.godot/editor/` 캐시 3개 갱신은 실행 중인 사용자 Godot 에디터에 의한 것으로 판단 (§6.2) |

---

## 8. 최종 감사 상태: **Partial Audit**

**충족한 범위**: 파일 인벤토리 404/404, GDScript 인벤토리 61/61(+애드온 규모), Scene 구조 38/38, Player 전문 분석, 전 파일 의존 패턴 추출, 위험·Preserve 분석, 지침 분석, Git 무변경 검증.

**미완료 항목과 이유**:
1. 프로젝트 `.gd` 61개 중 **22개는 본문을 부분 정독(16) 또는 구조 추출만(6)** 했다 — 대부분 `_draw()` 그리기·애니메이션 코드와 보스 AI 세부 분기(Knight 378–534·705–779, Prince 271–784)다. 의존 패턴은 전 줄 추출로 보완했으나, 이 구간에 숨은 논리 결함은 확인하지 못했다.
2. `.tscn` 29개는 원문 대신 정적 파서로 구조만 확인했다 (모든 속성 값은 검토하지 않음).
3. 적 튜닝 파일 9개는 내용을 개별 검토하지 않고 섹션·키 대응만 검증했다.
4. 런타임 동작은 감사 규칙상 검증하지 않았다 (§5).
5. 애드온·`.godot/` 캐시는 명시적으로 제외했다.

위 항목이 리팩토링 결정에 필요하면, 해당 파일의 정독 또는 실행 검증을 별도 작업으로 진행할 것을 제안한다.
