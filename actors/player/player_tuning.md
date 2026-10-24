# 플레이어 — `actors/player/player.tscn`

> 단위: 시간 = 초, 거리 = px, 속도 = px/s. `.tscn`에서 덮어쓴 값이 있으면 그 값이 실제 적용값.

## 체력 / 자원
| 항목 | 값 | 위치 |
|---|---|---|
| 최대 체력 | 100 | `Combat/Health.max_hp` (기본값) |
| 피격 후 무적 | 0.5 | `Combat/Hurtbox.invincibility_duration` |
| 궁극기 게이지 최대 | 100 | `ultimate_max` |
| 게이지 충전: 반격 성공 | +34 | `ult_charge_on_parry` |
| 게이지 충전: 평타 적중 | +5 | `ult_charge_on_hit` |
| 게이지 충전: 피격 | +8 | `ult_charge_on_damaged` |
| 게이지 충전: 스킬 적중 | +3 | `ult_charge_on_skill_hit` |
| 게이지 충전: 패기 방출 | +50 | `haki_ult_gain` |

## 이동
| 항목 | 값 | 위치 |
|---|---|---|
| 달리기 속도 | 330 | `run_speed` |
| 점프 속도 / 2단 점프 | -560 / -520 | `jump_velocity` / `double_jump_velocity` |
| 공중 점프 횟수 | 1 | `air_jumps` |
| 중력 / 하강 배율 | 1500 / ×1.55 | `gravity` / `fall_gravity_mult` |
| 대시 속도 / 시간 | 760 / 0.15 | `dash_speed` / `dash_time` |
| 대시 쿨타임 | 0.30 | `dash_cooldown` |
| 공중 대시 횟수 | 1 | `air_dashes` |

## 평타 (3연타)
| 항목 | 값 | 위치 |
|---|---|---|
| 데미지 (1/2/3타) | 10 / 12 / 20 | `combo_damage` |
| 넉백 (1/2/3타) | 160 / 160 / 320 | `combo_knockback` |
| 예비 / 판정 / 후딜 | 0.035 / 0.11 / 0.10 | `swing_windup` / `swing_active` / `swing_recovery` |
| 콤보 유지 시간 | 0.32 | `combo_reset_time` |

## 반격 (카유공 패리)
| 항목 | 값 | 위치 |
|---|---|---|
| 반격 데미지 | 999 (즉사, 보스는 별도) | `counter_damage` |
| 헛반격 경직 / 재입력 금지 | 0.3 / 0.5 | `parry_whiff_time` / `parry_whiff_cooldown` |
| 연쇄 반격 입력 창 | 0.2 | `chain_window` |
| 패기 방출 조건 | 연쇄 3회마다 | `haki_every` |
| 패기 데미지 | 15 | `haki_damage` |

## 스킬
| 스킬 | 쿨타임 | 데미지 | 기타 | 위치 |
|---|---|---|---|---|
| 공허 구체 (Void Orb) | **4.0** | 7 × 최대 3타 | 속도 1725, 사거리 950 | `Combat/VoidOrb.cooldown`(tscn), `void_orb_projectile.gd` |
| 대시 참격 (Dash Slash) | **3.0** | 15 | 넉백 240, 대시 후 유예 0.12 | `Combat/DashSlash.cooldown`(tscn), `dash_slash_ability.gd`, `player.gd dash_slash_*` |
| 번개 (Lightning) | 2.0 | 20 | 반경 120, 넉백 220 | `lightning_ability.gd`, `lightning_bolt.gd` |
| 궁극기: 반달 참격 (Moon Slash) | 게이지 100 | 몸통 20 / 폭발 40 | 최대 거리 1500 | `moon_slash.gd`, `player.gd ult_*` |
