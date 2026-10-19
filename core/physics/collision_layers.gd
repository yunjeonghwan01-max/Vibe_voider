class_name CollisionLayers
extends RefCounted

## Collision layer bit values, matching [layer_names] in project.godot.
## Layer N (1-based in the editor) has bit value 1 << (N - 1).
##
## 원칙 (docs/structure.md): 바디는 world만 mask. Hitbox는 상대 진영 Hurtbox만 mask.
## Hurtbox는 layer만 가지고 mask는 0 (감지당하기만 한다). 단, Parry는 상대 Hitbox를
## 감지해야 하므로 적 Hitbox에 enemy_hitbox 레이어를 켜고 플레이어 ParryBox가 그것을 mask한다.

const WORLD: int = 1 << 0          # layer 1
const PLAYER_BODY: int = 1 << 1    # layer 2
const ENEMY_BODY: int = 1 << 2     # layer 3
const PLAYER_HURTBOX: int = 1 << 3 # layer 4
const ENEMY_HURTBOX: int = 1 << 4  # layer 5
const PLAYER_HITBOX: int = 1 << 5  # layer 6
const ENEMY_HITBOX: int = 1 << 6   # layer 7
