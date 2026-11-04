class_name PrinceAura
extends Node2D

## 횡단 돌진(패턴 2) 뒤에 길게 남는 초록 아우라 — 실제 피해 판정이 있다.
## 머리(왕자 위치)를 따라 늘어나고, 꼬리는 life초 전의 위치를 따라와 지나간 자리는 그 시간만큼만 뜨겁다.
## 대시 무적을 뚫는 공격이 아니다: 무적 동안에는 맞지 않지만, 무적이 끝난 뒤에도 아직 아우라 안에 있으면 맞는다.
## 그래서 진입 신호(area_entered) 대신 겹침을 매 프레임 확인하고, 돌진 한 번에 한 번만 맞힌다 (spent).
## 수치는 스폰하는 왕자가 add_child 전에 채운다 (prince_tuning.cfg).

const FADE_TIME := 0.3

@onready var hitbox: HitboxComponent = $Hitbox
@onready var _shape: CollisionShape2D = $Hitbox/CollisionShape2D

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var damage: int = 8
var knockback: float = 260.0
var life: float = 0.34
var height: float = 36.0
var floor_y: float = 0.0
var head_x: float = 0.0
## true면 이번 돌진은 더 맞히지 않는다 (이미 본체에 맞았거나, 돌진이 반격당했다).
var spent: bool = false

var _trail: Array[Vector2] = []     # (시각, 머리 x)
var _t: float = 0.0
var _released: bool = false
var _fade: float = 0.0
var _tail_x: float = 0.0


func _ready() -> void:
	global_position = Vector2(0.0, floor_y)
	hitbox.source = source
	hitbox.apply_on_contact = false
	_shape.shape = _shape.shape.duplicate()
	_tail_x = head_x
	_update_shape()                      # 첫 프레임부터 왕자 자리에 있어야 한다 (씬 기본 위치는 맵 중앙)


## 돌진이 끝났다 — 머리는 멈추고 꼬리가 따라와 사그라든다.
func release() -> void:
	_released = true


func _physics_process(delta: float) -> void:
	_t += delta
	if not _released:
		_trail.append(Vector2(_t, head_x))
	while _trail.size() > 1 and _t - _trail[1].x >= life:
		_trail.pop_front()
	if not _trail.is_empty():
		_tail_x = _trail[0].y
	var hot := _t - (_trail[-1].x if not _trail.is_empty() else _t) < life
	if hot and not spent:
		_update_shape()
		_try_hit()
	elif not hot:
		hitbox.set_deferred("monitoring", false)
		_fade += delta
		if _fade >= FADE_TIME:
			queue_free()
			return
	queue_redraw()


func _update_shape() -> void:
	var rect := _shape.shape as RectangleShape2D
	rect.size = Vector2(maxf(absf(head_x - _tail_x), 2.0), height)
	_shape.position = Vector2((head_x + _tail_x) * 0.5, -height * 0.5)


func _try_hit() -> void:
	for area in hitbox.get_overlapping_areas():
		var hb := area as HurtboxComponent
		if hb == null:
			continue
		var dir := signf(head_x - _tail_x)
		if hb.receive_hit(damage, source if is_instance_valid(source) else null, Vector2(dir, -0.5).normalized() * knockback):
			spent = true
			return


func _draw() -> void:
	var a := 1.0 - _fade / FADE_TIME
	var dir := signf(head_x - _tail_x)
	if dir == 0.0:
		return
	# 판정 높이와 같은 아우라 띠 + 흔들리는 불꽃 끝
	var steps := clampi(int(absf(head_x - _tail_x) / 28.0), 2, 48)
	var top := PackedVector2Array()
	for i in steps + 1:
		var u := float(i) / steps
		var x := lerpf(_tail_x, head_x, u)
		var wob := sin(_t * 26.0 + x * 0.05) * 5.0
		top.append(Vector2(x, -(height * (0.45 + 0.55 * u) + wob)))
	var poly := top.duplicate()
	poly.append(Vector2(head_x, 0.0))
	poly.append(Vector2(_tail_x, 0.0))
	draw_colored_polygon(poly, Color(0.25, 0.95, 0.45, 0.32 * a))
	draw_polyline(top, Color(0.6, 1.0, 0.68, 0.9 * a), 3.0)
	draw_line(Vector2(_tail_x, -3.0), Vector2(head_x, -3.0), Color(0.88, 1.0, 0.9, 0.85 * a), 4.0)
