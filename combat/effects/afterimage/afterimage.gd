class_name Afterimage
extends Sprite2D

## 대시/고속 이동 때 남는 잔상. 스프라이트(시트의 현재 프레임 포함)를 복제해 색을 입히고 빠르게 사라진다.

@export var lifetime: float = 0.28
@export var start_alpha: float = 0.5

var _t: float = 0.0
var _tint: Color = Color(0.7, 0.5, 1.0, 1.0)


## add_child 이후 호출해야 global_transform이 적용된다.
## global_transform에 이미 Visual의 좌우 반전이 들어 있으므로 flip은 따로 건드리지 않는다.
## src는 Sprite2D 또는 AnimatedSprite2D(현재 애니메이션 프레임을 복사).
func setup_from_sprite(src: Node2D, tint: Color = Color(0.7, 0.5, 1.0, 1.0)) -> void:
	if src is AnimatedSprite2D:
		var anim_src := src as AnimatedSprite2D
		texture = anim_src.sprite_frames.get_frame_texture(anim_src.animation, anim_src.frame)
	else:
		var sprite_src := src as Sprite2D
		texture = sprite_src.texture
		hframes = sprite_src.hframes
		vframes = sprite_src.vframes
		frame = sprite_src.frame
	centered = src.centered
	offset = src.offset
	flip_h = src.flip_h
	texture_filter = src.texture_filter
	_tint = tint
	global_transform = src.global_transform
	modulate = Color(_tint.r, _tint.g, _tint.b, start_alpha)


func _process(delta: float) -> void:
	_t += delta / maxf(lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	var a := start_alpha * (1.0 - _t)
	modulate = Color(_tint.r, _tint.g, _tint.b, a)
