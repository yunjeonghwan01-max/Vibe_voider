extends Node2D

## 화로 — 방의 따뜻한 광원. 흔들리는 불꽃(4프레임), 깜빡이는 빛 번짐, 불티, 장작 타는 소리.
## 충돌은 없다 (배경 소품).

@export var flame_fps: float = 11.0

@onready var flame: Sprite2D = $Visual/Flame
@onready var glow: Sprite2D = $Visual/Glow

var _t: float = 0.0
var _frame_t: float = 0.0
var _glow_scale: Vector2


func _ready() -> void:
	_t = randf() * 10.0
	_glow_scale = glow.scale
	flame.frame = randi() % flame.hframes


func _process(delta: float) -> void:
	_t += delta
	_frame_t += delta
	if _frame_t >= 1.0 / flame_fps:
		_frame_t = 0.0
		flame.frame = (flame.frame + 1) % flame.hframes
	var flick := 0.86 + 0.09 * sin(_t * 13.0) + 0.05 * sin(_t * 31.0 + 1.3)
	glow.modulate.a = flick
	glow.scale = _glow_scale * (0.97 + 0.04 * sin(_t * 9.0))
