class_name DiveAbility
extends Node2D

## 강하 — 슬롯 스킬 (1페이즈 배치: 아래 + E). 조금 떠올라 멈췄다가 머리부터 아래로 급강하해 땅에 꽂힌다.
## 이 노드는 쿨다운, 강하 중 몸 접촉 판정(Hitbox — 경로의 적마다 1회), 착지 폭발(DiveBlast) 스폰을 맡는다.
## 자세(떠오름/체공/급강하/착지 경직)는 Player 상태 머신(Action.DIVE)이 정한다.
##
## 피해 세 가지 (같은 적이 모두 맞을 수 있다):
##   1. 몸 접촉 — 강하 중 경로의 적을 관통하며 body_damage.
##   2. 작렬 — 땅에 닿았을 때만, 착지 지점 양옆 blast_half_width 안.
##   3. 지연 불꽃 — 착지 flame_delay초 뒤 같은 범위 전체에서 한꺼번에 솟는다 (작렬을 안 맞은 적도).
## 작렬 + 불꽃 합계는 떨어진 높이(시작 지점 → 착지 지점)에 따라 min_total → max_total, 작렬 몫은 impact_ratio.

signal hit_landed(hurtbox: HurtboxComponent)

@export var cooldown: float = 1.5
@export var body_damage: int = 10            # 몸 접촉 (미정 — 임시 1N, 작렬·불꽃 합계와 별도)
@export var body_knockback: float = 120.0
@export var min_total: int = 35              # 작렬 + 불꽃 합계 — 제자리(지상) 강하 (임시 3.5N)
@export var max_total: int = 55              # bonus_height 이상 떨어졌을 때 (임시 5.5N)
@export var bonus_height: float = 450.0      # 이만큼 이상 떨어지면 최대 피해 (그 사이는 직선 보정)
@export var impact_ratio: float = 0.7        # 합계 중 작렬 몫 (나머지는 불꽃) — 7:3
@export var impact_knockback: float = 340.0
@export var flame_delay: float = 0.35        # 착지 뒤 불꽃이 솟기까지 (플레이어는 그동안 행동 불가)
@export var blast_half_width: float = 150.0  # 착지 지점 양옆 판정 거리
@export var blast_scene: PackedScene
@export var impact_scene: PackedScene        # 지면 균열 연출 (공용 GroundImpact)

@onready var hitbox: HitboxComponent = $Hitbox

var _cd: float = 0.0


func _ready() -> void:
	hitbox.monitoring = false
	hitbox.apply_on_contact = true
	hitbox.damage = body_damage
	hitbox.hit_landed.connect(hit_landed.emit)


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func can_use() -> bool:
	return _cd <= 0.0


## 쿨다운은 시전 순간에 건다 — 떠오르는 동안 끊겨도 쿨다운은 돈다.
func start_cooldown() -> void:
	_cd = cooldown


## 급강하 중 몸 접촉 판정 on/off. dir = 강하 방향 (넉백도 그 방향으로 짓누른다).
func set_body_active(caster: Node2D, on: bool, dir: Vector2 = Vector2.DOWN) -> void:
	if on:
		hitbox.source = caster
		hitbox.reset_hits()
		hitbox.damage = body_damage
		hitbox.knockback_force = body_knockback
		hitbox.knockback_direction = dir
	hitbox.set_deferred("monitoring", on)


## 땅에 꽂혔다 — at = 착지 지점(바닥 윗면), drop = 시작 지점에서 내려온 높이. 작렬·불꽃 합계를 계산해 폭발을 스폰한다.
## 반환: 높이 보정 비율 (0 = 최소, 1 = 최대) — 쓰는 쪽이 손맛 세기에 쓴다.
func land(caster: Node2D, at: Vector2, drop: float) -> float:
	var k := clampf(drop / maxf(bonus_height, 1.0), 0.0, 1.0)
	var total := roundi(lerpf(float(min_total), float(max_total), k))
	var impact := roundi(total * impact_ratio)
	var fx := get_tree().get_first_node_in_group("fx")
	var parent: Node = fx if fx else owner.get_parent()
	if impact_scene != null:
		var g := impact_scene.instantiate() as GroundImpact
		parent.add_child(g)
		g.global_position = at
		g.crack_ground(lerpf(0.55, 1.0, k), 3.0)
	if blast_scene != null:
		var b := blast_scene.instantiate() as DiveBlast
		b.source = caster
		b.impact_damage = impact
		b.flame_damage = total - impact
		b.knockback = impact_knockback
		b.flame_delay = flame_delay
		b.half_width = blast_half_width
		b.power = k
		b.hit_landed.connect(hit_landed.emit)
		parent.add_child(b)
		b.global_position = at
	return k
