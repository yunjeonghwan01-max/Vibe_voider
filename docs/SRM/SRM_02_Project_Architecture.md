# SRM_02 — 프로젝트 아키텍처 (폴더 · 파일 · 전역 구성)

> **감사 기준**: 2026-11-19 · branch `main` · HEAD `f0f088a` (Editor resave: refresh scene UIDs) · Read-Only Static Audit
> **확실성 표기**: **[CS]** Confirmed Static (파일 내용으로 직접 확인) · **[SI]** Statically Inferred (여러 코드 경로로 추론) · **[RU]** Runtime Unverified (실행 검증 필요) · **[UK]** Unknown (증거 부족)
> **관련 문서**: [SRM_01 요약](SRM_01_Executive_Summary.md) · [SRM_03 Scene](SRM_03_Scene_Architecture.md) · [SRM_04 Script](SRM_04_Script_Inventory.md) · [SRM_08 지침](SRM_08_Convention_And_Instructions.md) · [SRM_10 범위](SRM_10_Audit_Coverage.md)

---

## 1. 파일 통계

### 1.1 총계 [CS]

| 범위 | 파일 수 | 비고 |
|---|---:|---|
| 디스크 전체 (`.git/` 제외) | 653 | |
| `.godot/` (에디터 캐시, `.gitignore` 대상) | 249 | 존재·역할만 확인, 상세 분석 제외 (SRM_10) |
| **프로젝트 파일** (`.git/`·`.godot/` 제외) | **404** | **이 보고서 통계의 기준 집합** |
| └ Git 추적 파일 (`git ls-files`) | 401 | |
| └ 미추적 파일 | 3 | `.archify/dd.txt`(0 byte), `.claude/settings.json`, `VOIDER_PHASE1_DESIGN_MEMORY_2026-10-28.md` |
| └ 추적 중 수정됨 | 1 | `.vscode/settings.json` (Godot 경로 `/Applications/Godot.app` → Windows 경로) |

> 이 수치는 감사 시작 시점 기준이며, 이번 감사로 생성한 `docs/SRM/` 보고서는 포함하지 않는다.

### 1.2 확장자별 (프로젝트 파일 404개) [CS]

| 확장자 | 개수 | 주 위치 / 비고 |
|---|---:|---|
| `.gd` | 77 | 프로젝트 61 + `addons/godot_mcp/` 16 |
| `.gd.uid` | 77 | 스크립트마다 1개 (Godot 관리) |
| `.wav` | 50 | 전부 `assets/temporary/audio/` (코드 합성) |
| `.wav.import` | 50 | |
| `.tscn` | 38 | |
| `.png` | 35 | `assets/temporary/` 34 (코드 생성) + `assets/characters/player/Voider Player01.png` 1 |
| `.png.import` | 35 | |
| `.gitkeep` | 15 | 빈 역할 폴더 표식 |
| `.cfg` | 13 | `*_tuning.cfg` 12 + `addons/godot_mcp/plugin.cfg` 1 |
| `.md` | 4 | `AGENTS.md`, `CLAUDE.md`, `docs/structure.md`, `VOIDER_PHASE1_DESIGN_MEMORY_2026-10-28.md` |
| `.txt` | 2 | `docs/cheats.txt`, `.archify/dd.txt`(빈 파일) |
| `.json` | 2 | `.vscode/settings.json`, `.claude/settings.json` |
| `.gdshader` / `.gdshader.uid` | 1 / 1 | `combat/effects/hit_flash/` |
| `project.godot`, `.gitignore`, `.gitattributes`, `.editorconfig` | 각 1 | |
| **`.tres`** | **0** | **독립 Resource 파일이 하나도 없다.** 모든 Resource는 `.tscn` 내부 `sub_resource`이거나 코드에서 생성(`RectangleShape2D.new()` 등)된다 |
| `export_presets.cfg` | 0 | 빌드(Export) 설정 없음 |

### 1.3 최상위 폴더별 [CS]

| 폴더 | 파일 수 | 주요 내용 |
|---|---:|---|
| `assets/` | 174 | PNG/WAV + `.import` |
| `actors/` | 109 | player 17 `.gd` · enemies 19 `.gd` · 씬 · 튜닝 |
| `addons/` | 33 | `godot_mcp` 에디터 플러그인 |
| `combat/` | 29 | 공용 전투 컴포넌트·공격·이펙트 |
| `toolkit/` | 14 | 개발 툴킷, 치트, 에셋 생성기 |
| `world/` | 8 | brazier 소품 + 빈 폴더 5 |
| `levels/` | 7 | phase1, arena |
| `ui/` | 6 | hud + 빈 폴더 3 |
| `core/` | 5 | tuning, collision_layers |
| `app/` | 3 | main |
| `camera/`, `managers/`, `docs/` | 각 2 | |
| 루트 파일 | 7 | `project.godot`, 지침 md 3, git/editor 설정 3 |
| `.vscode/`, `.claude/`, `.archify/` | 각 1 | 도구 설정 |

### 1.4 GDScript 규모 요약 [CS]

| 구분 | 파일 | Physical Lines | Code Lines | 함수 수 |
|---|---:|---:|---:|---:|
| 전체 `.gd` | 77 | 20,379 | 15,903 | 1,024 |
| 애드온 (`addons/godot_mcp`) | 16 | 4,897 | 3,701 | 194 |
| **프로젝트 `.gd`** | **61** | **15,482** | **12,202** | **830** |
| └ 오프라인 에셋 생성기 (`toolkit/asset_gen`) | 2 | 3,437 | 2,880 | 125 |
| └ **게임 런타임 코드** | **59** | **12,045** | **9,322** | **705** |

측정 방법·상위 15개 표는 [SRM_04](SRM_04_Script_Inventory.md) 참조.

---

## 2. 실제 디렉터리 트리 (의미 단위) [CS]

```text
Vibe_voider/
├── project.godot                        엔진 설정 · main scene = app/main.tscn · Autoload GameFeel
├── AGENTS.md · CLAUDE.md                AI 개발 지침 (SRM_08)
├── VOIDER_PHASE1_DESIGN_MEMORY_2026-10-28.md   (미추적) 1페이즈 전투 기획 인계 문서
│
├── app/                    main.gd · main.tscn        최상위 셸 + 레벨 교체 (static var)
├── actors/
│   ├── player/             player.gd (1,920줄) · player_visual.gd · player.tscn · player_tuning.cfg
│   │   └── abilities/
│   │       ├── void_orb/       장풍          ability.gd + projectile.gd/.tscn      [장착: 기본 E]
│   │       ├── spin_rise/      회전 상승     ability.gd + effect.gd (씬 없음)       [장착: 위+E]
│   │       ├── dive/           강하          ability.gd + blast.gd/.tscn           [장착: 아래+E]
│   │       ├── dash_slash/     대시 참격     ability.gd + effect.gd/.tscn          [장착: 대시 중 E]
│   │       ├── sword_wave/     검격 날리기   sword_wave.gd/.tscn + void_mark.gd    [장착: 궁극기]
│   │       ├── haki/           패기 방출     haki_burst.gd/.tscn                   [연쇄 반격 3회마다]
│   │       ├── moon_slash/     월아 참격     moon_slash.gd/.tscn                   [미장착 — 궁극기 대안]
│   │       ├── lightning/      벼락          ability.gd + bolt.gd/.tscn            [미장착]
│   │       └── rising_slash/   승천 참격     ability.gd (씬 없음)                   [미장착]
│   ├── enemies/
│   │   ├── enemy.gd                       공통 기반 클래스 Enemy (씬 없음)
│   │   ├── grunt/ duelist/ watcher/ knight/         Arena용 (구 적 4종 + 보스 "월식의 기사")
│   │   └── infantry/ assassin/ crossbowman/ giant/ prince/   Phase1용 (제3부대 + 보스 "제3왕자")
│   └── npcs/               (.gitkeep만)
├── combat/
│   ├── components/  health/ hitbox/ hurtbox/          공용 피해 파이프라인 (스크립트만, 씬 없음)
│   ├── attacks/     x_slash/                          X자 참격 (Player 반격 + Knight 사용)
│   ├── effects/     slash/ spark/ glint/ afterimage/ counter_tell/ ground_impact/ hit_flash(.gdshader)
│   └── projectiles/ (.gitkeep만)
├── levels/
│   ├── phase1/      phase1.gd/.tscn/_tuning.cfg       기본 실행 레벨 (숲) — Main.levels[0]
│   └── arena/       arena.gd/.tscn                     구 레벨 (달빛 성소) — 치트 8로 전환
├── camera/          game_camera.gd                     (씬 없음 — 레벨 씬의 Camera2D에 부착)
├── ui/              hud/ (hud.gd/.tscn) · menus/ dialogue/ transitions/ (.gitkeep만)
├── managers/        game_feel.gd                       Autoload: hit-stop · shake · 화면 flash
├── core/            data/tuning.gd · physics/collision_layers.gd · state/ (.gitkeep만)
├── world/           props/brazier/ · tiles/ platforms/ hazards/ interactables/ backgrounds/ (.gitkeep만)
├── toolkit/         toolkit.gd/.tscn · debug_hud.gd · cheats.gd · rally_dummy/ · asset_gen/
├── assets/          temporary/ (characters 18 PNG · environment 15 · effects 1 · audio 50 WAV)
│                    characters/player/"Voider Player01.png" · audio/ effects/ environment/ fonts/ (.gitkeep만)
├── docs/            structure.md (= Structure V0) · cheats.txt
├── addons/godot_mcp/    에디터 MCP 플러그인 (서드파티 툴링)
└── .godot/ · .vscode/ · .claude/ · .archify/    캐시 · IDE · 도구 설정
```

**주요 파일 위치 요약**

| 종류 | 위치 |
|---|---|
| `.gd` (게임) | `actors/` 36, `combat/` 10, `toolkit/` 6, `levels/` 2, `core/` 2, `app/` 1, `camera/` 1, `managers/` 1, `ui/` 1, `world/` 1 |
| `.tscn` | `actors/` 25 (player 1 + abilities 7 + enemies 17), `combat/` 6, `levels/` 2, `toolkit/` 2, `app/` 1, `ui/` 1, `world/` 1 — 합계 38 (상세 SRM_03) |
| `*_tuning.cfg` | 객체 씬 옆: player, phase1, 적 9종(grunt/duelist/watcher/knight/infantry/assassin/crossbowman/giant/prince), watcher_needle — 12개 |
| `.tres` | 없음 |

---

## 3. 폴더별 역할 — 설계 의도 vs 실제 구현

설계 의도는 `docs/structure.md` §1 (이하 Structure V0). 상세 비교는 [SRM_08](SRM_08_Convention_And_Instructions.md).

| 폴더 | 설계 의도 (Structure V0) | 실제 포함 기능 [CS] | 판정 |
|---|---|---|---|
| `app/` | 최상위 Shell, Level 콘텐츠 직접 두지 않음 | `Main`: Phase1 인스턴스 + Toolkit. `levels` 배열·`static var _level_index`로 레벨 교체 | 일치 |
| `actors/` | 자기 상태를 가지고 행동하는 존재 | Player + 적 9종 + 보스 2종. 적 전용 투사체/연출(needle, beam, bolt, wave, aura, quake, clash, cross)도 사용 Actor 폴더 안 | 일치 (사용처 1곳 규칙 준수) |
| `combat/` | 어느 Actor에도 종속되지 않는 공용 전투 언어 | Health/Hitbox/Hurtbox, XSlash, 이펙트 7종 | 일치. XSlash·CounterTell·GroundImpact·Afterimage는 실제 2곳 이상 사용 확인 |
| `world/` | 살아 있지 않은 World Object | brazier 1종. 지형(Ground/Wall/Ledge/BossGate)은 레벨 씬 안 `StaticBody2D`로 직접 존재 | 일치 (콘텐츠 적음) |
| `levels/` | 부품을 조립한 실제 게임 공간 | phase1, arena — 둘 다 스폰·보스 흐름·음악·카메라 제어까지 담당 | 일치 (레벨 스크립트 책임은 큼 — SRM_07) |
| `ui/` | 플레이어용 화면 UI | HUD 1종. 메뉴·설정·대화·전환 화면 없음 | 일치 (미구현 영역 다수) |
| `camera/` | Camera와 공용 Camera 기능 | `GameCamera` (follow, look-ahead, trauma shake, room_limits, focus) | 일치 |
| `managers/` | 게임 전체 범위 상태/흐름 관리자 | `GameFeel`만 (hit-stop/shake/flash 라우터). Game/Scene/Save/Audio Manager 없음 | 부분 일치 — "전투 손맛 유틸"에 가깝다 [SI] |
| `toolkit/` | 개발자용 기능 | 디버그 HUD, 툴 단축키, 치트 9종, 랠리 더미, 오프라인 에셋 생성기 | 일치 |
| `core/` | 여러 영역이 공유하는 저수준 기반 | `Tuning`(Player·모든 Enemy·Phase1·WatcherNeedle 사용), `CollisionLayers` | 일치 |
| `assets/` | 원본 Asset | 전부 `temporary/` (코드 생성 placeholder) + 원본 일러스트 1장 | 일치 (정식 에셋 없음) |
| `docs/` | 프로젝트 문서 | structure.md, cheats.txt | 일치 |

---

## 4. 프로젝트 전역 구성

### 4.1 `project.godot` [CS]

| 항목 | 값 | 비고 |
|---|---|---|
| `config/name` | `pure_vibe_Voider` | |
| `run/main_scene` | `uid://b6iyiseqvt13n` | = `app/main.tscn` 헤더 UID (일치) |
| `config/features` | `"4.7", "Forward Plus"` | 실제 렌더러와 다름 (아래) |
| `renderer/rendering_method` | `gl_compatibility` | **실효 렌더러 = Compatibility** |
| `rendering_device/driver.windows` | `d3d12` | RenderingDevice 계열 렌더러용 설정 — Compatibility에서는 쓰이지 않는 것으로 추정 [SI] |
| `textures/canvas_textures/default_texture_filter` | `0` (Nearest) | 픽셀아트 |
| `display/window` | 1280×720, stretch `canvas_items` / `expand` | |
| `3d/physics_engine` | `Jolt Physics` | 3D 전용 — 2D 게임에 영향 없음 |
| `[editor_plugins]` | `res://addons/godot_mcp/plugin.cfg` | 에디터 전용 |

### 4.2 Autoload 및 전역 상태 [CS]

| 이름 | 스크립트 | 역할 |
|---|---|---|
| `GameFeel` | `managers/game_feel.gd` | `hit_stop(duration, scale)`(= `Engine.time_scale` 변경), `shake(trauma)`(→ `GameCamera.current`), `flash(color, …)` (런타임에 CanvasLayer 90 + ColorRect 생성) |

Autoload 외 전역 상태 (상세 SRM_06):
- `static var Main._level_index` — 씬 재로드를 넘어 유지되는 레벨 순번 (`app/main.gd:16`)
- `static var GameCamera.current` — 현재 카메라 싱글턴 참조 (`camera/game_camera.gd:8`)
- `Engine.time_scale` — `GameFeel`만 씀 (`managers/game_feel.gd:45,50`), 그러나 Player가 `_process`에서 직접 읽어 입력 분기에 사용 (`actors/player/player.gd:304,307`)

### 4.3 Input Map [CS]

| 액션 | 키 / 패드 | 읽는 코드 |
|---|---|---|
| `player_move_left/right` | ←/A, →/D, 스틱 X | `player.gd` |
| `player_move_up/down` | ↑/W, ↓/S, 스틱 Y | `player.gd` (스킬 슬롯 방향 수식) |
| `player_jump` | Space, 패드 0 | `player.gd` |
| `player_attack` | J, 마우스 L, 패드 2 | `player.gd` |
| `player_parry` | K, 마우스 R, 패드 축 4 | `player.gd`, `prince_clash.gd` |
| `player_dash` | L, Shift, 패드 축 5 | `player.gd` |
| `player_skill` | E, 패드 1 | `player.gd` |
| `player_ultimate` | U, Q, 패드 3 | `player.gd` |
| `player_confirm` | X | **어디서도 읽지 않음** |
| `player_cancel` | Esc | **어디서도 읽지 않음** |
| `player_interaction` | ↓ (`player_move_down`과 같은 물리 키) | **어디서도 읽지 않음** |
| `tool_toggle_hud` | F1, 1 | `toolkit.gd` |
| `tool_restart` | F5, 5, 패드 4 | `toolkit.gd` |
| `tool_pause` | F6, 6, 패드 6 | `toolkit.gd` |
| `tool_cheat` | ` (백틱) | `cheats.gd`, `toolkit.gd` |

- 치트 숫자 키는 입력 액션이 아니라 `InputEventKey.physical_keycode`(KEY_1~9)로 직접 읽는다 (`toolkit/cheats.gd:42-46`).
- 입력 처리는 Player에 집중되어 있다: `player.gd`의 `Input.*` 호출 39회, 그중 `player_parry` 읽기 14곳 (SRM_05).

### 4.4 Collision Layer [CS]

`project.godot [layer_names]`와 `core/physics/collision_layers.gd` 상수가 일치한다.

| # | 이름 | bit | 실제 사용 (씬 정적 선언 기준) |
|---|---|---:|---|
| 1 | `world` | 1 | 레벨 StaticBody2D (Ground/Walls/Ledges/BossGates) |
| 2 | `player_body` | 2 | Player (mask = world) |
| 3 | `enemy_body` | 4 | 모든 Enemy (mask = world; Watcher는 mask 0, Knight/Prince는 비행 시 코드로 0) |
| 4 | `player_hurtbox` | 8 | Player Hurtbox (mask 0) |
| 5 | `enemy_hurtbox` | 16 | Enemy Hurtbox (mask 0) |
| 6 | `player_hitbox` | 32 | Player 공격 Hitbox 전부 (mask 16) |
| 7 | `enemy_hitbox` | 64 | 반격 가능한 적 공격 (AttackHitbox, Knight RushHitbox) — mask 8 |

예외(설계 문서에 명시된 것): 반격 불가 적 공격은 layer 0 (Knight Slam/Shock, Prince Rush, 모든 적 투사체·아우라), Player `ParryBox` mask 64, Knight `Sensors/CounterGuard` mask 32, Player `SpinRise/Sensor` mask 4, 투사체 `Collision` mask 1. 런타임 생성 `ContactArea`는 mask = `CollisionLayers.PLAYER_HURTBOX` (`enemy.gd:542`).

### 4.5 기타 구성 파일 [CS]

| 파일 | 내용 | 비고 |
|---|---|---|
| `.gitignore` | `.godot/`, `/android/`, `.DS_Store` | |
| `.gitattributes` | `* text=auto eol=lf` | |
| `.editorconfig` | `charset = utf-8` | |
| `.vscode/settings.json` | Godot 실행 경로 | 작업 트리에서 수정됨 (미커밋) |
| `.claude/settings.json` | `{"worktree": {"bgIsolation": "none"}}` | 미추적 |
| `.archify/dd.txt` | 0 byte | 미추적, 용도 불명 [UK] |
| `addons/godot_mcp/plugin.cfg` | "Godot MCP" v0.1.0 (Signal Compose) | 에디터 플러그인 |

자동화 테스트, CI 설정, Export preset은 **존재하지 않는다** [CS].

---

## 5. 임시 · 레거시 · 미사용 의심 파일

| 대상 | 분류 | 근거 | 확실성 |
|---|---|---|---|
| `assets/characters/player/Voider Player01.png` (+`.import`, 456 KB) | 미사용 (원본 참조 일러스트) | 어떤 `.tscn`/`.gd`도 참조하지 않음. `sprite_gen.gd:170` 주석에서만 언급. 파일명에 공백·대문자 (snake_case 규칙 예외) | CS |
| `actors/player/abilities/lightning/`, `rising_slash/`, `moon_slash/` | 현재 미장착 기능 (레거시 후보이자 교체 가능 스킬) | `player_tuning.cfg`의 `slot_*`에 없음. 그러나 `player.gd`의 `_can_cast_skill`/`_cast_skill`/궁극기 분기와 `player.tscn` 노드에 살아 있음 | 미장착 CS / 유지 여부는 인간 결정 |
| `actors/enemies/grunt/`, `duelist/`, `watcher/`, `knight/` + `levels/arena/` | Phase1 이전 콘텐츠 — 치트 8로만 도달 | `main.tscn` `levels = [Phase1, Arena]`, 기본은 Phase1 | CS |
| `toolkit/rally_dummy/` | 개발 치트 3 전용 가짜 보스 | `cheats.gd:62`, 본편 코드는 참조하지 않음 | CS |
| 입력 액션 `player_confirm`, `player_cancel`, `player_interaction` | 미사용 (템플릿 잔재로 추정) | 어떤 `.gd`도 읽지 않음. `player_interaction`은 ↓ 키를 `player_move_down`과 공유 | 미사용 CS / 잔재 여부 SI |
| `.archify/dd.txt` | 빈 미추적 파일 | 0 byte | 용도 UK |
| `VOIDER_PHASE1_DESIGN_MEMORY_2026-10-28.md` | 미추적 기획 문서 (루트 위치) | `git status ??` | CS |
| 빈 역할 폴더 15개 (`.gitkeep`) | 규칙상 정상 (선제 생성 폴더) | 15개 모두 형제 파일 없음 — "실제 파일이 생기면 `.gitkeep` 삭제" 규칙 위반 없음 | CS |
| `.tscn` UID 참조 불일치 8건 | 프로젝트 무결성 경고 후보 | 참조 쪽 `uid=`가 대상 씬 헤더 UID와 다름 (SRM_07 R-08) | 불일치 CS / 로딩 영향 RU |

과거 삭제 이력(참고, `git log --diff-filter=D`): `docs/tuning/*.md`, `actors/**/*_tuning.md`, `moon_slash_tuning.cfg`, `void_orb_projectile_tuning.cfg` 등이 튜닝 체계 일원화 과정에서 삭제되었다 — 현재 잔존 파일 없음 [CS].
