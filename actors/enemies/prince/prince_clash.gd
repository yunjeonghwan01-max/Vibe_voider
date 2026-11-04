class_name PrinceClash
extends Node2D

## 마지막 일격(패턴 5)의 힘겨루기 QTE. 게이지는 계속 줄고, 반격 키를 연타할 때마다 찬다.
## 끝까지 채우면 승리, 비면 패배. 입력은 여기서만 읽는다 — 그동안 Player는 이벤트 잠금(Action.LOCKED)이라
## 같은 키가 반격으로 나가지 않는다. 판정은 finished(won) 하나로 끝나며, 바 표시는 실제 gauge 값 그대로다.
## 수치는 스폰하는 왕자가 add_child 전에 채운다 (prince_tuning.cfg).

signal pressed
signal finished(won: bool)

const BAR_SIZE := Vector2(300.0, 22.0)

## 스폰하는 쪽이 add_child 전에 채운다.
var gauge: float = 0.5
var drain: float = 0.16
var gain: float = 0.085

var _done: bool = false
var _pop: float = 0.0


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 6.0, 0.0)
	queue_redraw()
	if _done:
		return
	gauge -= drain * delta
	if Input.is_action_just_pressed("player_parry"):
		gauge += gain
		_pop = 1.0
		pressed.emit()
	if gauge >= 1.0 or gauge <= 0.0:
		_done = true
		gauge = clampf(gauge, 0.0, 1.0)
		finished.emit(gauge >= 1.0)


func _draw() -> void:
	var size := BAR_SIZE * (1.0 + 0.06 * _pop)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect.grow(5.0), Color(0.03, 0.05, 0.04, 0.9))
	draw_rect(rect, Color(0.24, 0.1, 0.1, 1.0))
	var fill := Rect2(rect.position, Vector2(rect.size.x * clampf(gauge, 0.0, 1.0), rect.size.y))
	var col := Color(0.95, 0.35, 0.3).lerp(Color(0.45, 1.0, 0.55), clampf(gauge * 1.4, 0.0, 1.0))
	draw_rect(fill, col)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 5.0)), Color(1.0, 1.0, 1.0, 0.45))
	draw_rect(rect.grow(5.0), Color(1.0, 0.93, 0.58, 0.6 + 0.4 * _pop), false, 2.0)
