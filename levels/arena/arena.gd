extends Node2D

## 달빛 성소 — 한 방짜리 전투 공간.
## 플레이어는 씬에 배치돼 있고, 적(잡몹 무리 + 듀얼리스트 1)은 코드로 스폰한다.
## 쓰러진 적은 잠시 뒤 플레이어에게서 떨어진 지점에 다시 나타나 전투 흐름이 끊기지 않게 한다.
## 창문 너머 하늘과 전경 사슬은 카메라 위치에 맞춰 다른 속도로 움직여 깊이감을 준다.

@export var grunt_scene: PackedScene
@export var duelist_scene: PackedScene
@export var grunt_count: int = 4
@export var grunt_respawn_delay: float = 2.5
@export var duelist_respawn_delay: float = 6.0
@export var sky_parallax: float = 0.35          # 1보다 작을수록 멀리 있는 것처럼 느리게 움직인다
@export var foreground_parallax: float = 0.18   # 전경은 카메라보다 빠르게 지나간다
@export var min_spawn_distance: float = 280.0   # 플레이어 바로 옆에서 튀어나오지 않게

@onready var actors: Node2D = $Actors
@onready var effects: Node2D = $Effects
@onready var projectiles: Node2D = $Projectiles
@onready var camera: GameCamera = $GameCamera
@onready var player: Player = $Actors/Player
@onready var hud: CanvasLayer = $Hud
@onready var sky_layer: Node2D = $World/SkyLayer
@onready var foreground: Node2D = $World/Foreground
@onready var music: AudioStreamPlayer = $Audio/Music

var _spawn_points: Array[Vector2] = [
	Vector2(-660, -30), Vector2(-380, -30), Vector2(380, -30), Vector2(660, -30), Vector2(-120, -30), Vector2(120, -30),
]
var _duelist_spawn_points: Array[Vector2] = [Vector2(560, -40), Vector2(-560, -40)]


func _ready() -> void:
	# 적이 찾을 수 있도록 플레이어를 그룹에 넣고, VFX/투사체 컨테이너도 그룹에 등록한다.
	player.add_to_group("player")
	effects.add_to_group("fx")
	projectiles.add_to_group("projectiles")

	camera.target = player
	hud.bind(player)
	# 루프 정보가 없는 환경에서도 음악이 끊기지 않게 한 번 더 보장한다.
	music.finished.connect(music.play)

	for i in grunt_count:
		_spawn_grunt(_spawn_points[[0, 3, 1, 2][i % 4]])
	_spawn_duelist(_duelist_spawn_points[0])


func _process(_delta: float) -> void:
	var cx := camera.global_position.x
	sky_layer.position.x = cx * (1.0 - sky_parallax)
	foreground.position.x = -cx * foreground_parallax


func _pick_spawn(points: Array[Vector2]) -> Vector2:
	var far: Array[Vector2] = []
	for p in points:
		if absf(p.x - player.global_position.x) >= min_spawn_distance:
			far.append(p)
	return (far if not far.is_empty() else points).pick_random()


func _spawn_grunt(pos: Vector2) -> void:
	if grunt_scene == null:
		return
	var g := grunt_scene.instantiate() as Enemy
	g.position = pos                 # add_child 전에 위치를 정해야 등장 연출이 제자리에서 터진다
	actors.add_child(g)
	g.add_to_group("enemy")
	g.defeated.connect(_on_grunt_defeated)


func _spawn_duelist(pos: Vector2) -> void:
	if duelist_scene == null:
		return
	var d := duelist_scene.instantiate() as Enemy
	d.position = pos
	actors.add_child(d)
	d.add_to_group("enemy")
	d.defeated.connect(_on_duelist_defeated)


func _on_grunt_defeated(_e: Enemy) -> void:
	await get_tree().create_timer(grunt_respawn_delay).timeout
	if is_instance_valid(self) and is_inside_tree():
		_spawn_grunt(_pick_spawn(_spawn_points))


func _on_duelist_defeated(_e: Enemy) -> void:
	await get_tree().create_timer(duelist_respawn_delay).timeout
	if is_instance_valid(self) and is_inside_tree():
		_spawn_duelist(_pick_spawn(_duelist_spawn_points))
