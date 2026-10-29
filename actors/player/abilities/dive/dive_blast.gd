class_name DiveBlast
extends Node2D

## 강하 착지 폭발. 노드 위치 = 착지 지점 (y = 바닥 윗면). 스폰하는 쪽(DiveAbility)이 수치를 채운다.
##   0             작렬: 판정 안의 적 전부 impact_damage + 바깥·위로 넉백. 바닥을 따라 양옆으로 충격파가 퍼진다.
##   ~ flame_delay 착지 범위 바닥에서 검보라 불씨가 일렁인다 (곧 불꽃이 솟는다는 예고).
##   flame_delay   지연 불꽃: 범위 전체에서 한꺼번에 불꽃이 솟고, 그 순간 범위 안의 적 전부 flame_damage.
## 같은 적이 작렬과 불꽃을 모두 맞을 수 있다. Hitbox는 apply_on_contact = false — 겹친 적에게 직접 receive_hit()한다.

signal hit_landed(hurtbox: HurtboxComponent)

const HEIGHT := 150.0            # 판정 높이 (바닥에서 위로)
const SHOCK_TIME := 0.28
const FLAME_LIFE := 0.5
const TONGUES := 11
const COLOR_GLOW := Color(0.55, 0.2, 0.95, 0.35)
const COLOR_BODY := Color(0.16, 0.03, 0.28, 1.0)
const COLOR_EDGE := Color(0.75, 0.45, 1.0, 1.0)
const COLOR_CORE := Color(1.0, 0.94, 1.0, 1.0)

@export var spark_scene: PackedScene

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var impact_damage: int = 25
var flame_damage: int = 10
var knockback: float = 340.0
var flame_delay: float = 0.35
var half_width: float = 150.0
var power: float = 0.0           # 높이 보정 비율 (0..1) — 연출 크기

@onready var hitbox: HitboxComponent = $Hitbox

var _t: float = 0.0
var _frames: int = 0
var _impacted: bool = false
var _flamed: bool = false
var _tongues: Array[Vector3] = []   # (x, 높이 배율, 흔들림 위상)


func _ready() -> void:
	var cs := $Hitbox/CollisionShape2D as CollisionShape2D
	var shape := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
	shape.size = Vector2(half_width * 2.0, HEIGHT)
	cs.shape = shape
	hitbox.position = Vector2(0.0, -HEIGHT * 0.5)
	hitbox.source = source
	hitbox.apply_on_contact = false
	hitbox.monitoring = true
	for i in TONGUES:
		var u := (float(i) + randf_range(-0.3, 0.3)) / float(TONGUES - 1)
		_tongues.append(Vector3(lerpf(-half_width, half_width, clampf(u, 0.0, 1.0)), randf_range(0.6, 1.0), randf() * TAU))


func _physics_process(delta: float) -> void:
	_t += delta
	_frames += 1
	# 겹침 목록은 판정이 켜진 다음 물리 프레임부터 채워진다
	if not _impacted and _frames >= 2:
		_impacted = true
		_hit_all(impact_damage, true)
	if not _flamed and _t >= flame_delay:
		_flamed = true
		_hit_all(flame_damage, false)
		GameFeel.shake(0.3 + 0.15 * power)
		_spark_row()
	if _t >= flame_delay + FLAME_LIFE:
		queue_free()
	queue_redraw()


func _hit_all(dmg: int, knock: bool) -> void:
	for area in hitbox.get_overlapping_areas():
		var hurt := area as HurtboxComponent
		if hurt == null:
			continue
		var kb := Vector2.ZERO
		if knock:
			var side := signf(hurt.global_position.x - global_position.x)
			kb = Vector2(side if side != 0.0 else 1.0, -0.7).normalized() * knockback
		if hurt.receive_hit(dmg, source, kb):
			hit_landed.emit(hurt)


func _spark_row() -> void:
	if spark_scene == null:
		return
	var fx := get_tree().get_first_node_in_group("fx")
	for i in 3:
		var s := spark_scene.instantiate() as SparkEffect
		(fx if fx else get_parent()).add_child(s)
		s.global_position = global_position + Vector2((i - 1) * half_width * 0.6, -20.0)
		s.burst(COLOR_EDGE, 8, 50.0, -90.0, 70.0, 0.3)


func _draw() -> void:
	_draw_shock()
	if not _flamed:
		_draw_embers()
	else:
		_draw_flames(clampf((_t - flame_delay) / FLAME_LIFE, 0.0, 1.0))


## 작렬 충격파: 바닥을 따라 양옆으로 퍼지는 빛줄기 + 착지점의 납작한 고리.
func _draw_shock() -> void:
	var u := _t / SHOCK_TIME
	if u >= 1.0:
		return
	var e := 1.0 - pow(1.0 - u, 3.0)
	var a := 1.0 - u
	var reach := half_width * (0.3 + 0.8 * e)
	for side in [-1.0, 1.0]:
		var tip := Vector2(side * reach, -4.0)
		draw_line(Vector2(side * reach * 0.2, -4.0), tip, Color(COLOR_EDGE, 0.8 * a), 10.0 * a + 2.0)
		draw_line(Vector2(side * reach * 0.35, -4.0), tip, Color(COLOR_CORE, a), 3.0)
	draw_set_transform(Vector2(0.0, -6.0), 0.0, Vector2(1.0, 0.3))
	draw_arc(Vector2.ZERO, 30.0 + 90.0 * e * (1.0 + power * 0.5), 0.0, TAU, 40, Color(COLOR_EDGE, 0.7 * a), 6.0 * a + 1.0)
	draw_set_transform(Vector2.ZERO)


## 불꽃 예고: 범위 바닥에서 불씨가 점점 밝게 일렁인다.
func _draw_embers() -> void:
	var k := clampf(_t / maxf(flame_delay, 0.01), 0.0, 1.0)
	for tg in _tongues:
		var flick := 0.5 + 0.5 * sin(_t * 40.0 + tg.z)
		var h := 6.0 + 14.0 * k * flick
		draw_line(Vector2(tg.x, 0.0), Vector2(tg.x, -h), Color(COLOR_EDGE, 0.25 + 0.5 * k), 4.0)
		draw_circle(Vector2(tg.x, -h), 2.5, Color(COLOR_CORE, 0.4 + 0.5 * k * flick))


## 지연 불꽃: 범위 전체에서 혀 모양 불꽃이 확 솟았다가 가늘어지며 사라진다.
func _draw_flames(u: float) -> void:
	var rise := minf(u / 0.15, 1.0)
	var fade := 1.0 - clampf((u - 0.35) / 0.65, 0.0, 1.0)
	var h_base := HEIGHT * (1.0 + 0.3 * power)
	var w := half_width / float(TONGUES) * 1.6
	for tg in _tongues:
		var h := h_base * tg.y * (1.0 - pow(1.0 - rise, 3.0)) * (0.6 + 0.4 * fade)
		var sway := sin(_t * 22.0 + tg.z) * 10.0
		_tongue(tg.x, w * 1.5, h * 1.08, sway, Color(COLOR_GLOW, COLOR_GLOW.a * fade))
		_tongue(tg.x, w, h, sway, Color(COLOR_BODY, fade))
		_tongue(tg.x, w * 0.55, h * 0.8, sway * 0.8, Color(COLOR_EDGE, 0.85 * fade))
		_tongue(tg.x, w * 0.2, h * 0.5, sway * 0.6, Color(COLOR_CORE, fade))


## 바닥(y=0)에서 솟는 불꽃 혀 하나: 아래는 넓고 위로 갈수록 휘며 뾰족해진다.
func _tongue(x: float, half_w: float, h: float, sway: float, col: Color) -> void:
	if h < 2.0 or col.a <= 0.01:
		return
	var pts := PackedVector2Array([
		Vector2(x - half_w, 0.0),
		Vector2(x - half_w * 0.7 + sway * 0.3, -h * 0.4),
		Vector2(x - half_w * 0.25 + sway * 0.7, -h * 0.75),
		Vector2(x + sway, -h),
		Vector2(x + half_w * 0.3 + sway * 0.6, -h * 0.7),
		Vector2(x + half_w * 0.7 + sway * 0.2, -h * 0.35),
		Vector2(x + half_w, 0.0),
	])
	draw_colored_polygon(pts, col)
