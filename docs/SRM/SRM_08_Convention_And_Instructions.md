# SRM_08 — 개발 지침 · Structure V0 · Pure Vibe 규칙 분석

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` · Read-Only Static Audit
> **확실성 표기**: **[CS]** Confirmed Static · **[SI]** Statically Inferred · **[RU]** Runtime Unverified · **[UK]** Unknown
> **원칙**: 지침 문서는 **분석 대상**으로만 읽었고, 이번 감사의 Read-Only 제한과 증거 기준을 바꾸는 실행 지시로 사용하지 않았다. 문서의 설계 의도는 구현의 증거로 간주하지 않는다. 지침은 **수정하지 않았다**.
> **관련**: [SRM_02 폴더](SRM_02_Project_Architecture.md) · [SRM_07 위험 R-15](SRM_07_Structural_Risks.md) · [SRM_09 후보](SRM_09_Refactoring_Candidates.md)

---

## 1. 문서 존재 여부 [CS]

| 요청된 문서 | 상태 | 실제 위치 / 비고 |
|---|---|---|
| `AGENT.md` | **발견되지 않음** | — |
| `AGENTS.md` | 발견 | 루트, 84줄. 공용 AI 협업 지침 (Claude/Codex 공용) |
| 프로젝트별 AI 개발 지침 | 발견 | 루트 `CLAUDE.md` (`@AGENTS.md` 포함 + Pure Vibe Development Protocol) |
| README | **발견되지 않음** | 저장소 어디에도 README 없음 (애드온 포함) |
| 아키텍처 설명 문서 | 발견 | `docs/structure.md` |
| **Voider Structure Refactor V0** | **이 제목의 문서는 발견되지 않음** | 가장 가까운 문서는 `docs/structure.md` — 제목 "**Structure V0** — 폴더 / Scene Tree 규칙". 이 문서 안에서 언급되는 "원본 구조 규칙서(V0)"(`structure.md:27`)는 저장소에 없다 [CS]. 이 보고서는 `docs/structure.md`를 Structure V0로 취급한다 |
| 기타 개발 규칙 | 발견 | `docs/cheats.txt` (치트 목록 + "치트를 바꾸면 이 파일도 고친다"), `*_tuning.cfg` 머리 주석(편집 규칙), 스크립트 머리 주석(기능 규칙) |
| 기획 문서 | 발견 (미추적) | `VOIDER_PHASE1_DESIGN_MEMORY_2026-10-28.md` — 1페이즈 전투 기획 인계본, "숫자는 대체로 임시값" |
| 리팩토링 관련 문서 | **발견되지 않음** | 과거 리팩토링 계획 문서 없음. `git log` 상 튜닝 체계 일원화 커밋만 존재 |
| SIC / VCAD 정의 | SIC: 정의 없음, `CLAUDE.md` 2곳에서 언급만 / **VCAD: 저장소 전체에서 언급 0건** | §6 |

참고 (저장소 밖, 분석 범위 밖): AI 도구의 사용자 메모리에 "worktree 금지·브랜치 유지", "Godot 실행 경로", "카운터 약어" 메모가 있으나 프로젝트 파일이 아니므로 규칙 분석에 포함하지 않았다.

### 1.1 문서 간 관계 [CS]

```text
CLAUDE.md ──@include──▶ AGENTS.md ──"read before structure changes"──▶ docs/structure.md (Structure V0)
    │                       ├─ Tuning Files 규칙 (단일 출처: <scene>_tuning.cfg)
    │                       └─ Counter Terminology (MCI/RCI/PRCI/CCI)
    └─ Pure Vibe Development Protocol: "AGENTS.md 승인/위험 규칙과 structure.md는 계속 권위를 가진다" (CLAUDE.md:115)
docs/cheats.txt ◀──"치트를 바꾸면 같이 고친다"── toolkit/cheats.gd (주석)
```

---

## 2. 문서별 주요 규칙 요약 [CS]

### 2.1 `AGENTS.md`
- **원칙**: 기존 구조 존중, 단순·테스트 가능한 구현, 요청 범위 밖 기능·새 레이어·Manager·Autoload·전역 이벤트 버스·범용 상태 머신 금지(구체적 이유 없이는) (9행), 전용 브랜치에서 빠르게 구현·플레이테스트 → 병합 또는 폐기 → 나중에 정리 (10행).
- **기능 명세 5필드**: Goal / Scope / Constraints / Context / Acceptance Criteria.
- **실행 절차**: Investigate → Plan → Approve(위험 기반) → Implement → Self-review → Verify. "통과하지 않은 테스트를 통과했다고 하지 말 것".
- **Godot 지침**: 노드/리소스/시그널을 기계적으로 강제하지 말 것, 프레임 비용·해제된 참조·`.tscn` 직렬화 주의.
- **완료 보고 4부**: Changes / Verification / Known Limitations / Next Decision.
- **Counter Terminology**: MCI/RCI/PRCI/CCI ↔ 코드 식별자 매핑 ("코드 식별자는 아직 이 이름을 쓰지 않는다").
- **Tuning Files**: 객체 씬당 `<scene>_tuning.cfg` 1개가 단일 출처, `Tuning.apply(self)`를 `_enter_tree`에서, 스폰물은 자체 파일 없이 스폰하는 쪽이 값 전달, Export preset에 `*_tuning.cfg` 포함.
- **의사소통**: 사용자와 한국어, 코드·식별자·용어는 영어.

### 2.2 `CLAUDE.md`
- **Project overview**: "IBBD Prototype Base … base template … not a game" (11행), 렌더러는 실제로 Compatibility.
- **Running**: CLI 빌드/테스트 파이프라인 없음, headless import/quit 점검, "자동화 테스트 없음" (27행).
- **Structure 요약**: 고정 최상위 폴더, 유형별 폴더 금지, 선제 생성 폴더 ≠ 선제 생성 콘텐츠, basename 규칙, `.uid`/`.import` 동반 이동, `res://` 하드코딩 금지.
- **Architecture**: Main 셸, Toolkit, 피해 단일 경로·컴포넌트 계약 유지, Actor 어휘, 스킬 위치 규칙, 새 레벨 추가 절차, 스폰물은 Level 컨테이너로.
- **Pure Vibe Development Protocol** (57행~): §3 참조.

### 2.3 `docs/structure.md` (Structure V0)
- 슬로건: "Scene은 필요한 역할만 가진다… 기능은 발산한다. 문법은 수렴한다." Convention/Preset이지 강제 Schema가 아니며, 엔진 제약이 우선.
- §0 템플릿 정책 · §1 최상위 폴더와 판단 기준 · §2 파일 명명 · §3 노드/입력 명명 · §4 Scene Tree Vocabulary(Actor/Environment/Hazard/Interactable/Projectile/Attack/Level/Main), 피해 문법, Collision Layer 원칙과 Voider 실제 배치 · §5 현재 실제 Scene Tree와 기능 규칙(반격·연쇄·패기·스킬 슬롯·보스·Phase1) · §6 엔진 제약 예외 · §7 개정 기준("실제 제작 마찰을 줄이는가?").
- 특징 [SI]: 규칙서이면서 동시에 **기능 명세서**(§5는 반격 규칙, 보스 패턴, 수치까지 기술). 20커밋에서 수정되어 Player 다음으로 변경이 잦다.

---

## 3. 규칙 분류

### 3.1 Pure Vibe 전용 규칙 [CS] — `CLAUDE.md` "Pure Vibe Development Protocol" (57~131행)

| 규칙 | 요지 |
|---|---|
| 목적 | 자연어 지시만으로 출시 가능한 게임까지 만든다. 핵심 메커닉 프로토타입에서 멈추지 않는다 |
| 역할 분담 | 인간 = 크리에이티브 디렉터·플레이테스터, AI = 자율 엔지니어링 팀 |
| **Core rule** | "The human decides WHAT and WHY; the AI decides HOW." (80행) |
| 자연어 우선 | 짧고 주관적인 요청도 유효한 입력. 기술 명세·코드 조각·구조 선택을 요구하지 않는다 |
| 자율 개발 루프 | 해석 → 계획 → 구현 → 검사 → 자율 수리 → 체감 기준 보고 |
| 보고 형식 | **Changed / Try / Caveats** — 짧고 비기술적으로 (106행) |
| 정직성 | 정적/headless 검사만 했으면 플레이테스트했다고 말하지 않는다 (102행) |
| 출시 지향 | 온보딩·메뉴·설정·일시정지·세이브·콘텐츠·밸런스·성능·접근성·빌드·엔딩까지 |
| 실험 무결성 | 프로그래밍 강좌화·SIC식 학습 재도입 금지 (127행) |

### 3.2 일반적인 코드 품질 · 구조 규칙 [CS]

| 출처 | 규칙 |
|---|---|
| `AGENTS.md` §1 | 기존 패턴 우선, 단순·테스트 가능, 투기적 추상화 금지, 새 Manager/Autoload/이벤트 버스/범용 상태 머신은 구체적 이유 필요 |
| `AGENTS.md` §3·5 | 조사→계획→위험 기반 승인→구현→자기 검토(중복·복잡도·패턴 위반·수명주기·시그널·해제된 참조·프레임 비용)→검증 / 완료 보고 4부 |
| `AGENTS.md` §4 | Godot: `.tscn`/`.tres` 직렬화·UID·경로 보존, 프레임 비용 주의 |
| `AGENTS.md` Tuning | 단일 출처 튜닝 파일, `Tuning.apply` 호출 위치, 경고 확인 |
| `structure.md` §1~4, §6 | 폴더 책임, 명명, 노드 어휘, 피해 단일 경로, `area.owner`/`has_method` 대상 탐색 금지, 레이어 원칙, 스폰물 컨테이너, 엔진 예외 |
| `CLAUDE.md` Structure/Architecture | 위 규칙의 요약 + 컴포넌트 API 안정 유지, 스킬은 두 번째 사용처가 생길 때 `combat/`로 |

### 3.3 인간의 직접적인 코드 개입을 제한(또는 불필요하게)하는 규칙 [CS]

| 위치 | 문구 요지 | 성격 |
|---|---|---|
| `CLAUDE.md:71` | 인간은 코드 에디터를 열거나, 소스를 읽거나, Godot 노드·속성을 검사하거나, 셸 명령을 실행하거나, 기술적 실패를 디버그할 **필요가 없다** | 요구 제거 (금지 아님) |
| `CLAUDE.md:80` | 인간은 WHAT/WHY, AI는 HOW | 역할 경계 |
| `CLAUDE.md:90` | 기술 명세·코드 조각·구조화된 프롬프트·구조 선택을 요구하지 말 것 | AI 행동 제약 |
| `CLAUDE.md:106-111` | 응답은 짧고 비기술적으로, 코드 워크스루·아키텍처 강의·역공학 과제·**SIC/Catch 학습 과제**를 일상적으로 제공하지 말 것, 구현 이해를 진행의 전제로 삼지 말 것 | 정보 제공 제한 |
| `CLAUDE.md:127` | 프로젝트를 프로그래밍 강좌로 만들지 말고 **필수 SIC식 학습을 몰래 재도입하지 말 것** | 명시적 금지 |
| 예외 — 인간 편집 통로 | `*_tuning.cfg`는 한국어 주석과 "이름은 바꾸지 말고 숫자만 바꾼다" 안내로 **인간의 직접 편집을 전제**한다 (`player_tuning.cfg:1-3`) | 허용된 유일한 수치 편집 경로 [SI] |

[SI] 이 규칙들은 "인간이 코드를 만지면 안 된다"고 금지하지는 않는다. 정확히는 **AI가 인간에게 코드 이해·참여를 요구하거나 유도하지 못하게** 막는다.

### 3.4 실제 코드베이스와 충돌하는 규칙 (문서 ≠ 구현) [CS]

| # | 규칙 (위치) | 실제 구현 | 영향 |
|---|---|---|---|
| C-1 | "IBBD Prototype Base … not a game … Player, enemies… are created in each project generated from this template" (`CLAUDE.md:11`) / "게임 전용 시스템/콘텐츠는 포함하지 않는다" (`structure.md:24`) | 저장소 자체가 게임 Voider (Player, 적 9종, 보스 2, 레벨 2, Collision 체계 확정) | AI가 지침을 문자 그대로 따르면 현재 콘텐츠를 "템플릿 위반"으로 오해할 수 있다 [SI] |
| C-2 | "holds the current level instance (none yet in the template)" (`CLAUDE.md:40`) | Phase1 인스턴스가 있다 | 낡은 기술 |
| C-3 | Toolkit 기능 목록 3개 (`CLAUDE.md:42-47`) | Cheats(치트 9종) + RallyDummy 추가됨 (`structure.md`·`cheats.txt`에는 반영) | 문서 간 불일치 |
| C-4 | "스폰물은 자체 튜닝 파일이 없다" (`AGENTS.md:81`) | `watcher_needle_tuning.cfg` 존재 (스폰하는 Watcher는 피해값을 넘기지 않음) | 예외 규칙 미기재 (R-16) |
| C-5 | "객체 씬마다 튜닝 파일" (`AGENTS.md:78`) | `arena.tscn`에는 튜닝 파일이 없고 수치(`watchers_for_boss`, 리스폰 지연 등)가 `.gd`/`.tscn`에 있다 | 부분 적용 |
| C-6 | "보병·암살자·거병은 다른 제3부대가 … 기다린다" (`structure.md:336`) | 보병은 보병만, 암살자는 보병·암살자만 확인 | R-06 |
| C-7 | "`.uid` 파일은 Godot이 관리, 손으로 편집하지 않는다" (`structure.md:79`) 및 UID 보존 (`AGENTS.md` §4) | 9개 `.tscn` 헤더에 사람이 쓴 형태의 UID, 19개는 헤더 UID 없음, 참조 불일치 8건 | R-08 |
| C-8 | Projectile 프리셋 "Root ├ Visual ├ Hitbox ├ Collision ├ Lifetime" (`structure.md:117`) | WatcherNeedle·CrossbowBolt·PrinceWave·MoonSlash·SwordWave는 `Visual` 노드 없이 루트 `_draw()`로 그린다 | 경미 — 엔진 예외 표(§6)에 없는 편차 |
| C-9 | `managers/` = 게임 전역 상태/흐름 관리자 (`structure.md:42`) | `GameFeel`(전투 손맛 유틸)만 존재. 게임 흐름은 레벨 스크립트가 가진다 | 해석 차이 |
| C-10 | "Workflow: … dedicated branches → merge" (`AGENTS.md:10`) | 원격·로컬 모두 `main`만, merge 커밋 0 | 확인 불가 (fast-forward 가능성) [UK] |
| C-11 | "서드파티/생성 에셋은 사용권 확인" (`CLAUDE.md:123`) | 코드 생성 에셋은 문서화되어 있으나 `assets/characters/player/Voider Player01.png`(원본 일러스트)의 출처·권리 기록 없음 | [UK] |
| C-12 | `Enemy` 헤더 "두 실사용자(Grunt, Duelist)" (`enemy.gd:4`) | 하위 클래스 9개 | 주석 노후 |

---

## 4. Structure V0 — 설계 의도 vs 실제 구현

### 4.1 일치하는 점 [CS]

| Structure V0 의도 | 실제 구현 근거 |
|---|---|
| 최상위 폴더 12개 책임 고정, 유형별 폴더·`systems/` 없음 | 폴더 구성 그대로 (SRM_02 §2) |
| 빈 역할 폴더는 `.gitkeep`, 파일이 생기면 삭제 | 15개 `.gitkeep` 모두 형제 파일 없음 |
| Scene/Script 같은 basename, `snake_case` 파일, `PascalCase` 노드 | 38개 씬 모두 준수 (예외: 원본 일러스트 파일명) |
| 입력 액션 `player_*` / `tool_*` 네임스페이스 | 17개 모두 준수 |
| Actor 어휘 `Visual`/`BodyCollision`/`Combat`/`Audio`, 필요할 때만 `Sensors` | Player·적 10종 모두 준수, `Sensors`는 Knight만 |
| `Visual`만 좌우 반전, 반전 안 되는 표시물은 루트 직속 | `Tell`(CounterTell)·Glint·석궁 BAR를 루트에 둔다 |
| 피해 단일 경로, `take_damage()`는 Actor에 없음, 대상은 `HurtboxComponent` 타입으로 판별 | 확인 (예외: 디버그 `Prince.debug_next_stage`가 `health.take_damage` 직접 호출 — 치트 전용, `prince.gd:990`) |
| 레이어 원칙 (바디는 world만, Hurtbox mask 0, Hitbox는 상대 Hurtbox만, Parry 예외) | 확인 (SRM_02 §4.4) |
| 스킬은 `actors/<actor>/abilities/<name>/`, 두 번째 사용처가 생기면 `combat/` | XSlash(Player+Knight)·CounterTell(3)·GroundImpact(4)는 `combat/`, 1곳 전용은 Actor 폴더 |
| Level 어휘 `World/Actors/Projectiles/Effects`, 런타임 스폰물은 컨테이너로 | Phase1·Arena 모두 준수 (컨테이너 미발견 시 부모로 대체하는 코드 존재) |
| Main 셸 + `levels` 배열 + `static var` 순번 + `_enter_tree` 교체 | `main.gd` 그대로 |
| 씬 참조는 `@export PackedScene`, `res://` 하드코딩 금지 | 게임 코드 0건 |
| 수치 단일 출처 (`<scene>_tuning.cfg`) | 12개 파일, 정적 검증 불일치 0 |

### 4.2 불일치 · 미구현 · 문서에 없는 구현

| 구분 | 내용 |
|---|---|
| 문서에 있으나 구현 없음 | `managers/`의 GameManager/SceneManager/SaveManager/AudioManager(예시로만 언급, 구현 의무 아님), `ui/menus` 등 빈 폴더의 기능, `world/tiles`(TileMap/TileSet 미사용 — 지형은 StaticBody2D+Sprite2D) |
| 구현되어 있으나 문서에 약하게만 있음 | 레벨 스크립트의 **group 부여 책임**(Actor 동작의 전제 조건), `Enemy` 접촉 피해용 런타임 `ContactArea`, `is_contact_hit` 일시 플래그 계약, 세 가지 시간 기준(SRM_06 §4), Player의 슬로모션 입력 버퍼 |
| 설계와 다르게 구현 | C-6 (crowd 간격), C-7 (UID), C-8 (Projectile `Visual`), C-4/C-5 (튜닝 예외) |
| 문서 구조상 특징 | §5 "현재 실제 Scene Tree"는 Arena 기준이고 Phase1은 뒤에 보충 — 기본 실행 레벨(Phase1) 기준 트리는 문서에 요약만 있다 |

---

## 5. 지침과 현재 코드 구조 사이의 긴장 (해석) [SI]

- **"새 Manager/Autoload/범용 상태 머신 금지(구체적 이유 없이)"** (`AGENTS.md:9`)와 **Player의 책임 집중**(R-03)은 연결되어 있다. 추상화를 억제하는 규칙이 "일단 Player에 넣는다"는 결과로 이어졌을 가능성이 있다 — `structure.md` §5도 "플레이어 전투 기술은 지금은 `player.gd`에 모아 feel을 빠르게 튜닝한다"고 명시한다. 즉 현재 구조는 **지침에 따른 의도적 선택**이며, 리팩토링은 이 규칙의 "구체적 이유" 조건을 충족하는 근거(SRM_07)를 갖고 판단해야 한다.
- **Self-review "Don't refactor working code just to find something to change"** (`AGENTS.md` §3-5)는 소프트 리팩토링의 범위 결정 시 그대로 적용 가능한 기준이다.
- `structure.md` §7 개정 기준("실제 제작 마찰을 줄이는가?")은 리팩토링 후보 평가 기준으로 재사용할 수 있다.

---

## 6. 향후 SIC / VCAD 적용 시 검토할 규칙

**전제 [CS/UK]**: 저장소 안에 SIC·VCAD의 **정의가 없다**. SIC는 `CLAUDE.md:111`("SIC/Catch learning tasks"), `CLAUDE.md:127`("mandatory SIC-style study")에 **금지 대상**으로만 등장하고, 문맥상 "인간이 코드를 학습·이해하는 과제" 계열로 읽힌다 [SI]. VCAD는 저장소 전체(애드온 포함)에서 언급이 0건이다 [UK]. 아래는 두 방법론의 정의를 가정하지 않고, **인간이 구현을 이해·검토·참여하는 방식이 도입될 경우** 재검토가 필요한 규칙을 정리한 것이다.

| 분류 | 규칙 (위치) | 검토 이유 |
|---|---|---|
| **직접 충돌** | SIC 학습 과제 제공 금지 (`CLAUDE.md:111`), 필수 SIC식 학습 재도입 금지 (`CLAUDE.md:127`) | SIC 도입 자체를 금지하는 문구 — 도입하려면 이 조항의 개정 또는 실험 단계 구분이 필요 |
| **직접 충돌** | 인간은 코드·노드·셸·디버깅이 필요 없다 (`CLAUDE.md:71`), 구현 이해를 진행 전제로 삼지 않는다 (`CLAUDE.md:111`) | 인간 검토·이해 단계를 넣으면 이 전제가 바뀐다 |
| **조정 필요** | 보고 형식 Changed/Try/Caveats, 비기술적 응답 (`CLAUDE.md:106`) | 구조 학습·검토용 보고(코드 근거·줄 번호)와 병행할 규칙 필요 |
| **조정 필요** | Core rule "WHAT/WHY는 인간, HOW는 AI" (`CLAUDE.md:80`) | 인간이 HOW(구조 결정)에 참여하는 범위 정의 필요 — 이번 감사의 "구조 변경은 인간과 별도 논의" 방침과도 연결 |
| **조정 필요** | 위험 기반 승인 (`AGENTS.md` §3-3) | 리팩토링 단계에서 누가 어떤 수준의 구조 결정을 승인하는지 |
| **재사용 가능** | 기능 명세 5필드, 실행 절차, 자기 검토 체크리스트, 완료 보고 4부 (`AGENTS.md`) | 사람이 읽고 검토하기 좋은 형식 — 그대로 활용 가능 |
| **재사용 가능** | Structure V0 어휘·폴더 규칙, Counter Terminology, 튜닝 파일 체계 | 이미 사람이 이해하도록 쓰인 문서·형식 |
| **재사용 가능** | 코드 머리 주석의 한국어 의도 설명 (P-14) | 인간 이해 자료로 직접 활용 가능 |
| **확인 필요** | "Don't refactor working code just to find something to change" / "새 추상화는 구체적 이유" (`AGENTS.md`) | 리팩토링 방법론이 추상화를 늘리는 방향이면 이 규칙과 충돌 여부 판단 필요 |

이번 감사는 위 규칙을 **수정하지 않았다**. 적용 여부와 문구는 인간과 별도로 결정할 사항이다.
