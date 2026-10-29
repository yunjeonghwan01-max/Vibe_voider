class_name VoidMark
extends Node2D

## 검격 날리기의 표식. 대상 적을 따라다니다가 delay초 뒤 터져 반지름 radius 안의 모든 적(대상 포함)에게 damage.
## 표식 폭발은 피해만 준다 — 넉백·경직 없음 (이 노드가 Enemy.NO_FLINCH_GROUP에 들어가 source로 쓰인다).
## 표식 폭발은 새 표식을 만들지 않는다. 같은 적에 표식이 여럿 붙으면 각각 따로 터진다 (피해 중복 허용).
## 대상이 죽어도 시체가 표식이 터질 때까지 남는다 (Enemy.hold_corpse). 대상이 사라지면 마지막 자리에서 터진다.
## 스폰하는 쪽(SwordWave)이 add_child 전에 target/damage/radius/delay를 채운다.

const POP_TIME := 0.35
const COLOR_EDGE := Color(0.86, 0.62, 1.0, 1.0)
const COLOR_CORE := Color(1.0, 0.97, 1.0, 1.0)
const COLOR_BODY := Color(0.2, 0.04, 0.34, 1.0)

var target: Enemy = null
var damage: int = 10
var radius: float = 140.0
var delay: float = 2.0

var _t: float = 0.0
var _popped: bool = false
var _spin: float = 0.0


func _ready() -> void:
	add_to_group(Enemy.NO_FLINCH_GROUP)
	z_index = 6
	_spin = randf() * TAU
	if is_instance_valid(target):
		target.hold_corpse(delay + 0.05)
		global_position = _anchor()


func _physics_process(delta: float) -> void:
	_t += delta
	if not _popped:
		if is_instance_valid(target):
			global_position = _anchor()
		if _t >= delay:
			_pop()
	elif _t >= delay + POP_TIME:
		queue_free()
	queue_redraw()


func _anchor() -> Vector2:
	return target.hurtbox.global_position


func _pop() -> void:
	_popped = true
	GameFeel.shake(0.18)
	for n in get_tree().get_nodes_in_group("enemy"):
		var enemy := n as Enemy
		if enemy == null or enemy.state == Enemy.State.DEAD:
			continue
		if enemy.hurtbox.global_position.distance_to(global_position) <= radius:
			enemy.hurtbox.receive_hit(damage, self, Vector2.ZERO)


func _draw() -> void:
	if _popped:
		var u := clampf((_t - delay) / POP_TIME, 0.0, 1.0)
		var r := radius * (1.0 - pow(1.0 - u, 3.0))
		var a := 1.0 - u
		draw_circle(Vector2.ZERO, r, Color(COLOR_BODY, 0.45 * a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(COLOR_EDGE, a), 4.0 * a + 1.0)
		return
	# 표식: 도는 고리 + 남은 시간만큼 채워지는 호. 터질 때가 가까울수록 빨리 돌고 빨리 깜빡인다.
	var k := clampf(_t / delay, 0.0, 1.0)
	var spin := _spin + _t * (2.0 + 10.0 * k * k)
	var blink := 0.65 + 0.35 * sin(_t * (8.0 + 40.0 * k * k))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(COLOR_EDGE, 0.35 * blink), 2.0)
	draw_arc(Vector2.ZERO, 26.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color(COLOR_CORE, 0.9 * blink), 3.0)
	for i in 4:
		var d := Vector2.from_angle(spin + i * PI * 0.5)
		draw_line(d * 14.0, d * 22.0, Color(COLOR_EDGE, blink), 3.0)
	draw_circle(Vector2.ZERO, 4.0 + 3.0 * k, Color(COLOR_CORE, blink))
