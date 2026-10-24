# 결투가 (Duelist) — `actors/enemies/duelist/duelist.tscn`

> 단위: 시간 = 초, 거리 = px, 속도 = px/s. `.tscn`에서 덮어쓴 값이 있으면 그 값이 실제 적용값.

| 항목 | 값 | 위치 |
|---|---|---|
| 최대 체력 | 220 | `Combat/Health.max_hp` (tscn) |
| 접촉 피해 / 넉백 | 6 / 220 | `contact_damage` / `contact_knockback` (enemy.gd 기본) |
| 이동 속도 | 140 | `move_speed` (tscn) |
| 넉백 저항 | 0.4 | `knockback_resist` (tscn) |
| 공격 데미지 | 18 | `attack_damage` |
| 공격 넉백 | 300 | `attack_knockback` |
| 공격 사거리 / 교전 거리 | 100 / 260 | `strike_range` / `engage_range` |
| 예비 동작 (첫 타 / 연격) | 0.2 / 0.1 | `windup_time` / `windup2_time` |
| 후딜 | 0.3 | `recover_time` |
| 연격 확률 / 최대 추가 타수 | 0.6 / 2 | `combo_chance` / `max_combo` |
| 피격 경직 / 반격당한 경직 | 0.12 / 1.1 | `hitstun_time` / `parry_stagger_time` (tscn) |
