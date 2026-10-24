# 수치표 (Tuning Sheets)

게임에서 조작 가능한 수치(체력, 데미지, 쿨타임, 자원, 주요 타이밍)를 **객체 씬 단위**로 정리한 표입니다.
실제 값은 각 씬(`.tscn`)과 스크립트(`.gd`)에 있고, 이 표는 그 값을 사람이 한눈에 보고 지시할 수 있게 한 거울입니다.

- 단위: 시간 = 초, 거리 = px, 속도 = px/s
- `.tscn`에서 덮어쓴 값이 있으면 그 값이 실제 적용값입니다 (표에는 실제 적용값을 적습니다).
- 기준: 플레이어 평타 1타 = 10

| 파일 | 씬 |
|---|---|
| [player.md](player.md) | `actors/player/player.tscn` (+ 스킬/투사체 씬) |
| [grunt.md](grunt.md) | `actors/enemies/grunt/grunt.tscn` |
| [duelist.md](duelist.md) | `actors/enemies/duelist/duelist.tscn` |
| [watcher.md](watcher.md) | `actors/enemies/watcher/watcher.tscn` (+ 바늘/광선) |
| [knight.md](knight.md) | `actors/enemies/knight/knight.tscn` (보스, 월식의 기사) |
