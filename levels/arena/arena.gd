extends Node2D

## 전투 연습장(아레나). 첫 플레이어블의 무대.
## 플레이어는 씬에 배치돼 있고, 적(잡몹 다수 + 듀얼리스트 1)은 코드로 스폰한다.
## 쓰러진 적은 잠시 뒤 다시 스폰해 전투 흐름이 끊기지 않게 한다.

@export var grunt_scene: PackedScene
@export var duelist_scene: PackedScene
@export var grunt_count: int = 3
@export var grunt_respawn_delay: float = 3.0
@export var duelist_respawn_delay: float = 5.0

@onready var actors: Node2D = $Actors
@onready var effects: Node2D = $Effects
@onready var camera: GameCamera = $GameCamera
@onready var player: Player = $Actors/Player
@onready var hud: CanvasLayer = $Hud

var _grunt_spawns: Array[Vector2] = [
	Vector2(-420, -80),
	Vector2(360, -80),
	Vector2(-140, -80),
]
var _duelist_spawn: Vector2 = Vector2(460, -80)


func _ready() -> void:
	# 적이 찾을 수 있도록 플레이어를 그룹에 넣고, VFX 컨테이너도 그룹에 등록한다.
	player.add_to_group("player")
	effects.add_to_group("fx")

	camera.target = player
	hud.bind(player)

	for i in grunt_count:
		_spawn_grunt(_grunt_spawns[i % _grunt_spawns.size()])
	_spawn_duelist(_duelist_spawn)


func _spawn_grunt(pos: Vector2) -> void:
	if grunt_scene == null:
		return
	var g := grunt_scene.instantiate() as Enemy
	actors.add_child(g)
	g.global_position = pos
	g.add_to_group("enemy")
	g.defeated.connect(_on_grunt_defeated)


func _spawn_duelist(pos: Vector2) -> void:
	if duelist_scene == null:
		return
	var d := duelist_scene.instantiate() as Enemy
	actors.add_child(d)
	d.global_position = pos
	d.add_to_group("enemy")
	d.defeated.connect(_on_duelist_defeated)


func _on_grunt_defeated(_e: Enemy) -> void:
	await get_tree().create_timer(grunt_respawn_delay).timeout
	if is_instance_valid(self) and is_inside_tree():
		_spawn_grunt(_grunt_spawns.pick_random())


func _on_duelist_defeated(_e: Enemy) -> void:
	await get_tree().create_timer(duelist_respawn_delay).timeout
	if is_instance_valid(self) and is_inside_tree():
		_spawn_duelist(_duelist_spawn)
