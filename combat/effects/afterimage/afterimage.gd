class_name Afterimage
extends Sprite2D

## 대시/고속 이동 때 남는 잔상. 스프라이트를 복제해 색을 입히고 빠르게 사라진다.

@export var lifetime: float = 0.28
@export var start_alpha: float = 0.5

var _t: float = 0.0
var _tint: Color = Color(0.7, 0.5, 1.0, 1.0)


func setup(tex: Texture2D, world_xform: Transform2D, flipped: bool, tint: Color = Color(0.7, 0.5, 1.0, 1.0)) -> void:
	texture = tex
	flip_h = flipped
	_tint = tint
	# add_child 이후 호출되어야 global_transform이 적용된다.
	global_transform = world_xform


func _process(delta: float) -> void:
	_t += delta / maxf(lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	var a := start_alpha * (1.0 - _t)
	modulate = Color(_tint.r, _tint.g, _tint.b, a)
