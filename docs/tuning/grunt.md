# 졸개 (Grunt) — `actors/enemies/grunt/grunt.tscn`

| 항목 | 값 | 위치 |
|---|---|---|
| 최대 체력 | 36 | `Combat/Health.max_hp` (tscn) |
| 이동 속도 | 165 | `move_speed` (tscn) |
| 공격 데미지 | 10 | `attack_damage` |
| 공격 넉백 | 240 | `attack_knockback` |
| 공격 쿨타임 | 0.8 | `attack_cooldown` |
| 공격 사거리 | 82 | `attack_range` |
| 예비 동작 (+반짝임 0.4) | 0.14 | `windup_time` / `glint_duration` |
| 돌진 속도 / 시간 | 480 / 0.2 | `lunge_speed` / `lunge_time` |
| 후딜 | 0.32 | `recover_time` |
| 피격 경직 / 반격당한 경직 | 0.14 / 1.0 | `hitstun_time` / `parry_stagger_time` (enemy.gd 기본) |
