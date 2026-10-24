# 월식의 기사 (Eclipse Knight, 보스) — `actors/enemies/knight/knight.tscn`

| 항목 | 값 | 위치 |
|---|---|---|
| 최대 체력 | 1800 | `Combat/Health.max_hp` (tscn) |
| 이동 속도 | 110 | `move_speed` (tscn) |
| 넉백 저항 | 0.8 | `knockback_resist` (tscn) |
| 반격당한 경직 | 1.3 | `parry_stagger_time` (tscn) |

## 근접 베기
| 항목 | 값 | 위치 |
|---|---|---|
| 데미지 / 넉백 | 22 / 460 | `melee_damage` / `melee_knockback` |
| 예비 (첫 타 / 연격) | 0.28 / 0.14 | `windup_time` / `windup2_time` |
| 후딜 | 0.5 | `recover_time` |
| 연격 확률 | 0.45 | `combo_chance` |
| 돌진 속도 | 1500 | `dash_speed` |

## 원거리 X자 (카유공)
| 항목 | 값 | 위치 |
|---|---|---|
| 충전 / 반격 창 | 2.0 / 0.4 | `charge_time` / `window_time` |
| X자 데미지 | 34 | `xmark_damage` |
| 반격 성공 시 보스가 받는 데미지 / 기절 | 180 / 2.4 | `countered_damage` / `countered_stun` |

## 반격 자세 → 내려찍기
| 항목 | 값 | 위치 |
|---|---|---|
| 첫 발동 / 쿨타임 | 5.0 / 6.0 | `stance_first` / `stance_cooldown` |
| 자세 시간 / 감지 거리 | 0.4 / 340 | `stance_time` / `stance_range` |
| 내려찍기 데미지 | 26 (충격파 15 = ×0.6) | `slam_damage` |
| 내려찍기 판정 폭 | 200 (발판 관통) | tscn `Rect_slam` |
| 충격파 폭 / 넉백 | 1100 / 480 | `shock_width` + tscn `Rect_shock` |
| 내려찍기 후딜 | 0.85 | `slam_recover` |
| 역반격 창 (실제 시간) / 슬로모 배율 | 0.5 / 0.1 | `bait_time` / `bait_time_scale` |
| 역반격 성공 데미지 / 기절 | 160 / 2.8 | `bait_counter_damage` / `bait_stun` |

## 돌진
| 항목 | 값 | 위치 |
|---|---|---|
| 첫 발동 / 쿨타임 | 9.0 / 12.0 | `rush_first` / `rush_cooldown` |
| 예비 동작 | 0.8 | `rush_windup` |
| 최고 속도 | 1900 | `rush_max_speed` |
| 데미지 / 넉백 | 26 / 620 | `rush_damage` / `rush_knockback` |
| 반격 창 / 반격 시 기절 | 0.15 / 3.6 | `rush_counter_window` / `rush_stun` |
