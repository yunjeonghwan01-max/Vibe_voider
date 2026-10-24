# 감시자 (Watcher) — `actors/enemies/watcher/watcher.tscn`

> 단위: 시간 = 초, 거리 = px, 속도 = px/s. `.tscn`에서 덮어쓴 값이 있으면 그 값이 실제 적용값.

| 항목 | 값 | 위치 |
|---|---|---|
| 최대 체력 | 40 | `Combat/Health.max_hp` (tscn) |
| 접촉 피해 / 넉백 | 6 / 220 | `contact_damage` / `contact_knockback` (enemy.gd 기본) |
| 이동 속도 | 190 | `move_speed` (tscn) |
| 넉백 저항 | 0.3 | `knockback_resist` (tscn) |
| 유지 거리 / 높이 | 300 / 180 | `hover_distance` / `hover_height` |

## 바늘 (watcher_needle)
| 항목 | 값 | 위치 |
|---|---|---|
| 발사 간격 | 1.5 | `needle_interval` |
| 조준 시간 | 0.35 | `aim_time` |
| 데미지 / 넉백 | 8 / 170 | `watcher_needle.gd` + tscn Hitbox |
| 속도 / 사거리 | 620 / 760 | `speed` / `needle_range` |

## 카유공 광선 (watcher_beam)
| 항목 | 값 | 위치 |
|---|---|---|
| 첫 발동 / 쿨타임 | 4.0 / 8.0 | `counter_first_delay` / `counter_interval` |
| 충전 시간 | 2.0 | `charge_time` |
| 반격 창 | 0.4 | `window_time` |
| 데미지 / 넉백 | 35 / 520 | `beam_damage` / `beam_knockback` |
| 후딜 | 0.9 | `recover_time` |
