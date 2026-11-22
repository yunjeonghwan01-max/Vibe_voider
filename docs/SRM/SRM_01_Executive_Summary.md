# SRM_01 — Voider 리팩토링 전 감사: 핵심 요약

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` (Editor resave: refresh scene UIDs)
> **감사 유형**: Read-Only Static Audit — 기존 파일 변경 없음, Godot 에디터·빌드·실행·import 미수행, 쓰기는 `docs/SRM/` 신규 보고서만
> **최종 상태**: **Partial Audit** — 핵심 범위(구조·Scene·Player·의존성·위험·지침)는 충족, 일부 스크립트 본문(주로 그리기·애니메이션·보스 AI 일부)은 부분 정독. 상세는 [SRM_10](SRM_10_Audit_Coverage.md)
> **확실성 표기**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown

---

## 1. 보고서 목차

| 파일 | 내용 |
|---|---|
| **SRM_01_Executive_Summary.md** | 이 문서 — 요약, 핵심 발견, 위험, 한계, 후속 논의 |
| [SRM_02_Project_Architecture.md](SRM_02_Project_Architecture.md) | 폴더·파일 통계, 디렉터리 트리, 폴더 역할(의도 vs 실제), `project.godot`·Autoload·InputMap·Collision, 미사용 의심 파일 |
| [SRM_03_Scene_Architecture.md](SRM_03_Scene_Architecture.md) | 38개 Scene 인벤토리, 주요 Scene Tree, 상속·Override, Signal 연결, NodePath 의존, 정적 vs 동적 구조 |
| [SRM_04_Script_Inventory.md](SRM_04_Script_Inventory.md) | 측정 방법, GDScript 61+16개 인벤토리, 상위 15개, 책임 단위 분석 |
| [SRM_05_Player_Deep_Dive.md](SRM_05_Player_Deep_Dive.md) | `player.gd` 책임 지도·처리 위치·상태 변경 지점·전이·결합·분리 가능 영역 |
| [SRM_06_System_Dependencies.md](SRM_06_System_Dependencies.md) | 상속·참조·Signal·Autoload·Group·인스턴스·Resource·입력·레이어, 대표 실행 흐름 8개 |
| [SRM_07_Structural_Risks.md](SRM_07_Structural_Risks.md) | 위험 17개(위험도·확실성·근거), Preserve Candidates 15개 |
| [SRM_08_Convention_And_Instructions.md](SRM_08_Convention_And_Instructions.md) | 지침 문서 존재 여부, 규칙 분류(Pure Vibe/품질/인간 개입/충돌/SIC·VCAD), Structure V0 vs 실제 |
| [SRM_09_Refactoring_Candidates.md](SRM_09_Refactoring_Candidates.md) | 리팩토링 **검토 후보** 14개 (확정 작업 아님), 비권장 방향, 추가 조사 항목 |
| [SRM_10_Audit_Coverage.md](SRM_10_Audit_Coverage.md) | 조사 범위, 발견 vs 분석 파일 대조, 정적 검증 결과, 런타임 미검증 목록, Git 검증, 최종 체크리스트 |

---

## 2. 현재 프로젝트 한눈에 보기 [CS]

| 항목 | 값 |
|---|---|
| 정체 | Godot 4.7 (Compatibility 렌더러) 2D 액션 게임 **Voider** — 반격(MCI/RCI/PRCI/CCI) 중심 근접 전투 |
| 진입 | `project.godot` → `app/main.tscn`(Main 셸) → 기본 레벨 `Phase1`(숲), 치트 8로 `Arena`(달빛 성소) |
| 프로젝트 파일 | 404개 (`.git`·`.godot` 제외) — `.gd` 77(프로젝트 61 + 애드온 16), `.tscn` 38, `.tres` **0**, 튜닝 `.cfg` 12, PNG 35·WAV 50(대부분 코드 생성 placeholder) |
| 코드 규모 | 프로젝트 `.gd` 12,202 Code Lines / 830 함수. **게임 런타임 9,322줄**(오프라인 에셋 생성기 2,880줄 제외) |
| 콘텐츠 | Player 1 (스킬 9종 구현, 5종 장착), 필드몹 6종, 공중 원거리 적 1, 보스 2(Knight, Prince), 레벨 2 |
| 전역 | Autoload 1(`GameFeel`), static 2(`Main._level_index`, `GameCamera.current`) |
| 품질 장치 | 튜닝 파일 체계, 개발 치트 9종 · **자동 테스트·CI·Export preset 없음** |
| Git | 46커밋, `main` 단일 브랜치, merge 커밋 0. 작업 트리: `.vscode/settings.json` 수정, 미추적 3개(감사 전부터) |

---

## 3. 핵심 발견 사항

### 3.1 구조 (사실) [CS]
1. **폴더 구조는 Structure V0(`docs/structure.md`)와 거의 일치한다.** 12개 최상위 폴더 책임, 명명 규칙, Actor/Level 어휘, `.gitkeep` 규칙, `@export PackedScene` 참조(하드코딩 경로 0건)가 지켜진다.
2. **모든 피해가 `HitboxComponent → HurtboxComponent.receive_hit() → HealthComponent` 한 경로를 지난다.** 공용 컴포넌트는 68줄로 작고, `receive_hit()` 직접 호출 17곳도 같은 계약 안에 있다.
3. **에디터 Signal 연결은 0개, 모든 연결은 코드(55곳).** Actor 간 상호작용(반격 등)은 Signal이 아니라 **직접 메서드 호출 + Group 조회**로 이루어진다.
4. **Group이 서비스 로케이터 역할을 한다.** `player`·`enemy`·`fx`·`projectiles`는 **레벨 스크립트가 부여**하므로 Actor의 정상 동작이 레벨 코드에 의존한다.
5. **튜닝 파일 12개의 모든 섹션·키가 실제 노드·속성에 대응한다** (정적 검증, 불일치 0).
6. **`.tscn` UID 참조 불일치 8건** — 사람이 쓴 UID와 에디터 UID가 엇갈리며, 커밋 `8a26cf4`에서 고친 값이 최신 커밋 `f0f088a`에서 다시 바뀌었다.

### 3.2 Player (`actors/player/player.gd`) [CS]
- 실측 **1,920 Physical / 1,503 Code / 109 함수** ("약 2,000줄"보다 약간 적음). 개별 함수는 최대 50줄로 짧다.
- **19개 책임 영역**(이동·대시·콤보·반격 4종·연쇄·방어·이벤트 잠금·스킬 자세 6종·슬롯 라우팅·궁극기 2종·피격·사망·연출)이 한 클래스에 있다.
- 문제의 핵심은 길이가 아니라 **공유 상태**: `action`(쓰기 32곳), `hurtbox.invincible`(17곳 + 외부 4곳 + 컴포넌트 타이머), `player_parry` 입력(14곳에서 읽음), `_hitbox_live`(의미 재사용).
- 프로젝트 커밋의 **52%(24/46)가 이 파일을 수정** — 적·보스·스킬 작업이 대부분 Player 수정을 동반해 왔다.

### 3.3 보스·적 [CS]
- `Enemy` 기반 클래스의 템플릿 메서드 훅으로 9개 하위 클래스가 복제 없이 공통 동작을 공유한다 (잘 동작하는 구조).
- `Prince`는 `Player`의 내부(`Action` enum, `hurtbox.invincible`, `health.hp`)를 직접 다루는 **양방향 결합**을 가진다.
- 필드몹 3종(Infantry/Assassin/Giant)이 서로의 비공개 상태를 읽어 공격 간격을 맞추는데, **규칙 범위가 서로 다르고 문서(`structure.md:336`)와도 다르다**.

---

## 4. 주요 구조적 위험 (상위) — 전체는 [SRM_07](SRM_07_Structural_Risks.md)

| ID | 위험 | 위험도 | 확실성 |
|---|---|---|---|
| R-01 | Player 무적 플래그를 Hurtbox 타이머·Player 8개 기능·외부 3개 클래스가 소유권 없이 공동 사용 → 무적 구간이 서로를 끊을 수 있음 [SI/RU] | High | Medium |
| R-03 | Player 한 클래스의 19개 책임 + 넓은 공유 상태 + 높은 변경 빈도 | High | High |
| R-02 | 일부 반격 진입 경로(슬로모션 버퍼·연쇄 자동 발동)가 이전 액션 정리 없이 전이 → 판정·운반 잔류 가능 [SI/RU] | Medium | Medium |
| R-04 | 컴포넌트 내부 emit 순서·일시 플래그(`is_contact_hit`)에 기대는 암묵적 계약 | Medium | High |
| R-05 | Actor 동작이 레벨의 Group 부여에 의존 (누락 시 조용히 오동작) | Medium | High |
| R-06 | 필드몹 간 비공개 상태 교차 참조 + 비대칭 규칙 | Medium | High |
| R-07 | 세 가지 시간 기준 혼재, `hit_stop` 마지막 호출 우선 | Medium | Medium |
| R-08 | UID 참조 불일치 8건과 되돌림 이력 | Medium | High / 영향 Low |
| R-09~R-11 | 문자열 스킬 슬롯(오타 무경고), Prince↔Player 결합, **리팩토링 안전망 부재** | Medium | High |

**Critical: 해당 없음** (정적 증거 기준. 실행 검증은 하지 않았다).

---

## 5. 잘 설계된 부분 (Preserve Candidates 요약)

- **P-01 피해 단일 경로**, **P-02 Tuning 시스템**(인간이 코드 없이 수치를 바꾸는 통로), **P-03 Scene 참조 규칙**, **P-04 Collision Layer 체계**
- **P-05 Enemy 훅 구조**, **P-06 Ability 노드 패턴**, **P-07 PRCI 투사체 상속 재사용**(Player 수정 없이 확장)
- **P-08 Toolkit/Cheats 단방향 격리**, **P-09 비동기 흐름 토큰**, **P-12 Resource 공유 안전장치**, **P-13 PlayerVisual 분리**
- **P-14 코드 내 한국어 의도 주석** — 사람이 구조를 이해하는 데 실질적으로 도움

---

## 6. 지침 문서 (요약) — [SRM_08](SRM_08_Convention_And_Instructions.md)

- 발견: `AGENTS.md`, `CLAUDE.md`(Pure Vibe Development Protocol 포함), `docs/structure.md`(= **Structure V0**), `docs/cheats.txt`, 기획 문서(미추적).
- **발견되지 않음**: `AGENT.md`, README, "Voider Structure Refactor V0"라는 제목의 문서, 리팩토링 계획 문서, SIC·VCAD 정의 (VCAD는 언급 0건).
- 문서 ≠ 구현 12건 — 대표: `CLAUDE.md`가 이 저장소를 "게임이 아닌 템플릿"으로 설명 (C-1), crowd 간격 규칙(C-6), UID 관리(C-7).
- 인간 코드 개입 관련 규칙은 "금지"보다 **"AI가 인간에게 코드 이해를 요구하지 않는다"**는 형태이며, 튜닝 파일만이 인간 직접 편집을 전제한 표면이다. SIC 도입 시 `CLAUDE.md:71, 106, 111, 127`이 직접 충돌한다.

---

## 7. 조사 범위와 한계 — [SRM_10](SRM_10_Audit_Coverage.md)

- 프로젝트 파일 404개 전부를 인벤토리했고, 프로젝트 `.gd` 61개 중 **39개 전문 정독, 16개 부분 정독, 6개 구조 추출만**(대부분 `_draw` 그리기 코드). 모든 `.gd`의 **모든 줄**에 대해 의존 패턴(노드 경로·Group·Signal·인스턴스·전역·입력)을 기계 추출했다.
- 38개 `.tscn`은 정적 파서로 전부 구조 추출, 9개는 원문 정독.
- **런타임 동작은 검증하지 않았다** (Godot 미실행 — 감사 규칙). 타이밍 의존 위험(R-01, R-02, R-07)과 UID 로딩 결과(R-08)는 실행 확인이 필요하다.
- 애드온(`addons/godot_mcp`, 33파일)과 `.godot/` 캐시(249파일)는 상세 분석에서 제외했다.

---

## 8. 후속 논의가 필요한 사항 (인간 결정)

1. **리팩토링 안전망**: 회귀 확인 체크리스트/자동 검사를 먼저 둘 것인가? (RC-00)
2. **UID 방침**: 수기 UID 유지 vs 에디터 UID 통일 (RC-01)
3. **필드몹 간격 규칙**: 현재 비대칭이 의도인가? (RC-04)
4. **지침 동기화**: `CLAUDE.md`의 "템플릿, 게임 아님" 서술 등 낡은 문구를 고칠 것인가? (RC-05 — 지침 수정은 인간 승인 사항)
5. **Player 분리 범위**: 분리 가능성이 높은 영역(표시·연출, 연쇄 반격)부터 볼 것인가, 무적·전이 정합성(R-01, R-02)을 먼저 볼 것인가?
6. **SIC / VCAD**: 정의와 적용 범위 — 현재 `CLAUDE.md`는 SIC식 학습을 명시적으로 금지한다.
7. **미장착·구 콘텐츠**: Lightning·RisingSlash·MoonSlash, Arena와 구 적 4종을 유지할 것인가? (콘텐츠 결정)
8. **원본 일러스트**(`assets/characters/player/Voider Player01.png`)의 출처·사용권 기록.

> 이번 감사는 구조 변경을 결정하지 않는다. 위 사항과 SRM_09의 후보는 인간과 별도로 논의한 뒤 진행한다.
