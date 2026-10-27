class_name DrillRiseAbility
extends Node2D

## 드릴 상승 — 세 번째 스킬. 위(W)를 누른 채 스킬 키(E). 회전하는 드릴처럼 위로 솟구치며 경로의 적을 갈아 올린다.
## 이 노드는 쿨다운, 다단 판정(Hitbox — 상승 진행도에 맞춘 틱), 대상 분류(Sensor), 휩쓸린 적 운반, 드릴 이펙트를 맡는다.
## 자세(예비 동작/상승 속도/마무리/캔슬)는 Player 상태 머신(Action.DRILL)이 정한다.
##
## 대상 분류: Sensor(mask = enemy_body)가 몸체를 감지하고 그룹(태그)으로 나눈다.
##   - CARRY_GROUP("field_mob"): 드릴에 휩쓸려 끝까지 함께 올라간다 (Enemy.begin_carry) → 거의 모든 틱을 맞는다.
##   - 그 외: 붙잡지 않는다. 드릴이 지나가는 동안 겹친 틱만 맞는다.
## 데미지: tick_count번의 틱으로 나눠 매번 따로 receive_hit — 전부 맞으면 합이 total_damage.
## 틱은 시간이 아니라 상승 "진행도"에 맞춰 터지므로 속도/높이를 바꿔도 총 데미지는 그대로다.

signal hit_landed(hurtbox: HurtboxComponent, last_tick: bool)

const CARRY_GROUP := &"field_mob"

@export var cooldown: float = 1.0
@export var total_damage: int = 20                         # 전부 맞으면 평타 1타(10)의 2배
@export var tick_count: int = 10
@export var tick_knockback: Vector2 = Vector2(0.0, -30.0)  # 붙잡히지 않은 대상에게 틱마다 주는 약한 들림
@export var carry_offset_y: float = -52.0                  # 휩쓸린 적이 붙는 높이 (드릴 끝 쪽)

@onready var hitbox: HitboxComponent = $Hitbox
@onready var sensor: Area2D = $Sensor
@onready var effect: DrillRiseEffect = $Effect

var _cd: float = 0.0
var _caster: Node2D = null
var _active: bool = false
var _ticks_done: int = 0
var _carried: Array[Enemy] = []


func _ready() -> void:
	hitbox.monitoring = false
	hitbox.apply_on_contact = false      # 틱 타이밍은 이 노드가 직접 정한다
	sensor.monitoring = false


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func can_use() -> bool:
	return _cd <= 0.0


## 예비 동작 시작: 쿨다운을 걸고 판정·감지를 켠 뒤 드릴을 맺는다 (겹침 목록이 상승 전에 채워진다).
func begin(caster: Node2D, form_time: float) -> void:
	_cd = cooldown
	_caster = caster
	_active = true
	_ticks_done = 0
	_carried.clear()
	hitbox.source = caster
	hitbox.reset_hits()
	hitbox.monitoring = true
	sensor.monitoring = true
	effect.form_in(form_time)


## 상승 중 매 물리 프레임 호출. progress = 목표 높이 대비 올라간 비율(0..1).
func advance(progress: float) -> void:
	if not _active:
		return
	_grab_field_mobs()
	# 첫 틱은 솟구치는 순간(옆에 선 적도 한 방은 맞는다), 마지막 틱은 목표 높이 95% 지점.
	while _ticks_done < tick_count and progress >= 0.95 * _ticks_done / maxf(tick_count - 1, 1):
		_fire_tick()


## 상승 종료: 판정을 끄고 휩쓸린 적을 놓아준다(위로 살짝 튀어 오른 뒤 떨어진다). 여러 번 불러도 안전.
func finish(release_velocity: Vector2, break_time: float) -> void:
	if not _active:
		return
	_active = false
	hitbox.monitoring = false
	sensor.monitoring = false
	for e in _carried:
		if is_instance_valid(e):
			e.end_carry(release_velocity)
	_carried.clear()
	effect.break_out(break_time)


## 피격/사망 등으로 끊겼을 때 — 이펙트도 즉시 지운다.
func cancel() -> void:
	finish(Vector2.ZERO, 0.001)
	effect.hide_now()


func _grab_field_mobs() -> void:
	for body in sensor.get_overlapping_bodies():
		var enemy := body as Enemy
		if enemy == null or enemy in _carried or not enemy.is_in_group(CARRY_GROUP):
			continue
		if enemy.begin_carry(_caster, carry_offset_y):
			_carried.append(enemy)


func _fire_tick() -> void:
	var i := _ticks_done
	_ticks_done += 1
	# 정수 데미지를 틱마다 나눠도 합이 정확히 total_damage가 되게 누적 경계로 계산한다.
	var dmg := total_damage * (i + 1) / tick_count - total_damage * i / tick_count
	var last := _ticks_done >= tick_count
	for area in hitbox.get_overlapping_areas():
		var hurt := area as HurtboxComponent
		if hurt == null:
			continue
		if hurt.receive_hit(dmg, _caster, tick_knockback):
			hit_landed.emit(hurt, last)
