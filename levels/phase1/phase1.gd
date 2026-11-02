class_name Phase1
extends Node2D

## Phase1 — 숲 속 첫 스테이지 (제3왕자 휘하 제3부대). 게임을 켜면 이 레벨이 돈다 (app/main.tscn).
## 분대 = 보병 squad_size명(플레이어 양쪽에서 걸어온다) + 암살자 assassin_count명(멀리서 순보로 파고든다)
##   + 석궁병 crossbow_count명(멀찍이 자리를 지키며 수평 볼트로 견제) + 거병 giant_count명(느리게 걸어오는 거구, 반동 2차 MCI).
## 분대를 모두 쓰러뜨리면 wave_delay 뒤 새 분대가 온다 (반복 플레이용 임시 흐름).
## 테스트: 시작 인원은 phase1_tuning.cfg, 치트 4(` + 4)는 보병 1 → 2 → 4 → 6 → 0명, 치트 5(` + 5)는 암살자 0 → 1 → 2 → 3명,
## 치트 6(` + 6)은 석궁병, 치트 7(` + 7)은 거병 0 → 1 → 2 → 3명
## — 누르면 지금 분대를 돌려보내고 새 인원으로 즉시 다시 부른다.
## 숲 배경은 코드로 그린 placeholder (toolkit/asset_gen/sprite_gen.gd의 _gen_forest) — 완성 아트가 아니다.

const SQUAD_PRESETS: Array[int] = [1, 2, 4, 6, 0]
const ASSASSIN_PRESETS: Array[int] = [0, 1, 2, 3]
const CROSSBOW_PRESETS: Array[int] = [0, 1, 2, 3]
const GIANT_PRESETS: Array[int] = [0, 1, 2, 3]

@export var infantry_scene: PackedScene
@export var assassin_scene: PackedScene
@export var crossbowman_scene: PackedScene
@export var giant_scene: PackedScene
@export_range(0, 6) var squad_size: int = 4
@export_range(0, 3) var assassin_count: int = 1
@export var assassin_spawn_distance: float = 700.0   # 암살자는 멀리서 나타나 순보로 다가온다
@export_range(0, 3) var crossbow_count: int = 1
@export var crossbow_spawn_distance: float = 520.0   # 석궁병은 이만큼 떨어진 자리에 서서 지킨다
@export_range(0, 3) var giant_count: int = 1
@export var giant_spawn_distance: float = 600.0
@export var wave_delay: float = 3.0
@export var min_spawn_distance: float = 360.0   # 플레이어 바로 옆에서 튀어나오지 않게
@export var spawn_row_gap: float = 90.0          # 같은 쪽에 서는 보병끼리의 등장 간격
@export var room_x: Vector2 = Vector2(-1100.0, 1100.0)   # 숲 벽 안쪽 면
@export var spawn_y: float = -40.0
@export var sky_parallax: float = 0.35           # 1보다 작을수록 멀리 있는 것처럼 느리게 움직인다
@export var foreground_parallax: float = 0.18    # 전경은 카메라보다 빠르게 지나간다

@onready var actors: Node2D = $Actors
@onready var effects: Node2D = $Effects
@onready var projectiles: Node2D = $Projectiles
@onready var camera: GameCamera = $GameCamera
@onready var player: Player = $Actors/Player
@onready var hud: CanvasLayer = $Hud
@onready var sky_layer: Node2D = $World/SkyLayer
@onready var foreground: Node2D = $World/Foreground
@onready var music: AudioStreamPlayer = $Audio/Music

var _alive: int = 0
var _wave_id: int = 0   # 치트로 분대를 바꾼 뒤 예전 분대의 "전멸" 예약이 새 분대를 또 부르지 않게


func _enter_tree() -> void:
	Tuning.apply(self)   # levels/phase1/phase1_tuning.cfg — 분대 인원 등


func _ready() -> void:
	# 적이 찾을 수 있도록 플레이어를 그룹에 넣고, VFX/투사체 컨테이너도 그룹에 등록한다.
	player.add_to_group("player")
	add_to_group("phase1")            # 개발 치트(toolkit/cheats.gd)가 분대를 바꿀 때 찾는다
	effects.add_to_group("fx")
	projectiles.add_to_group("projectiles")

	camera.target = player
	hud.bind(player)
	hud.set_tally(0, 0)               # 감시자 처치 수는 arena 전용 — 숨긴다
	music.finished.connect(music.play)
	_spawn_squad()


func _process(_delta: float) -> void:
	var cx := camera.global_position.x
	sky_layer.position.x = cx * (1.0 - sky_parallax)
	foreground.position.x = -cx * foreground_parallax


## 치트/테스트: 보병 인원을 다음 프리셋(1 → 2 → 4 → 6 → 0)으로 바꾸고 분대를 즉시 다시 부른다.
func cycle_squad() -> int:
	squad_size = SQUAD_PRESETS[(SQUAD_PRESETS.find(squad_size) + 1) % SQUAD_PRESETS.size()]
	_respawn_now()
	return squad_size


## 치트/테스트: 암살자 인원을 다음 프리셋(0 → 1 → 2 → 3)으로 바꾸고 분대를 즉시 다시 부른다.
func cycle_assassins() -> int:
	assassin_count = ASSASSIN_PRESETS[(ASSASSIN_PRESETS.find(assassin_count) + 1) % ASSASSIN_PRESETS.size()]
	_respawn_now()
	return assassin_count


## 치트/테스트: 석궁병 인원을 다음 프리셋(0 → 1 → 2 → 3)으로 바꾸고 분대를 즉시 다시 부른다.
func cycle_crossbows() -> int:
	crossbow_count = CROSSBOW_PRESETS[(CROSSBOW_PRESETS.find(crossbow_count) + 1) % CROSSBOW_PRESETS.size()]
	_respawn_now()
	return crossbow_count


## 치트/테스트: 거병 인원을 다음 프리셋(0 → 1 → 2 → 3)으로 바꾸고 분대를 즉시 다시 부른다.
func cycle_giants() -> int:
	giant_count = GIANT_PRESETS[(GIANT_PRESETS.find(giant_count) + 1) % GIANT_PRESETS.size()]
	_respawn_now()
	return giant_count


func _respawn_now() -> void:
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e != null:
			e.banish()
	_spawn_squad()


func _spawn_squad() -> void:
	_wave_id += 1
	_alive = 0
	for x in _squad_positions(squad_size):
		_spawn_enemy(infantry_scene, Vector2(x, spawn_y))
	var side := 1.0 if player.global_position.x < 0.0 else -1.0
	for i in assassin_count:
		var s := side if i % 2 == 0 else -side
		var x := clampf(player.global_position.x + s * (assassin_spawn_distance + floori(i / 2.0) * 120.0), room_x.x + 80.0, room_x.y - 80.0)
		_spawn_enemy(assassin_scene, Vector2(x, spawn_y))
	for i in crossbow_count:
		var s := -side if i % 2 == 0 else side
		var x := clampf(player.global_position.x + s * (crossbow_spawn_distance + floori(i / 2.0) * 160.0), room_x.x + 80.0, room_x.y - 80.0)
		_spawn_enemy(crossbowman_scene, Vector2(x, spawn_y))
	for i in giant_count:
		var s := side if i % 2 == 0 else -side
		var x := clampf(player.global_position.x + s * (giant_spawn_distance + floori(i / 2.0) * 160.0), room_x.x + 100.0, room_x.y - 100.0)
		_spawn_enemy(giant_scene, Vector2(x, spawn_y - 24.0))


## 플레이어 양쪽에 번갈아 세운다 (넓은 쪽부터). 한쪽이 벽에 막히면 반대편에 선다.
func _squad_positions(n: int) -> Array[float]:
	var out: Array[float] = []
	var px := player.global_position.x
	var lo := room_x.x + 80.0
	var hi := room_x.y - 80.0
	var first := 1.0 if px < 0.0 else -1.0
	var rows: Array[int] = [0, 0]     # 이미 선 인원: [오른쪽, 왼쪽]
	for i in n:
		var s := first if i % 2 == 0 else -first
		var x := px + s * (min_spawn_distance + rows[0 if s > 0.0 else 1] * spawn_row_gap)
		if x < lo or x > hi:
			s = -s
			x = px + s * (min_spawn_distance + rows[0 if s > 0.0 else 1] * spawn_row_gap)
		rows[0 if s > 0.0 else 1] += 1
		out.append(clampf(x, lo, hi))
	return out


func _spawn_enemy(scene: PackedScene, pos: Vector2) -> void:
	if scene == null:
		return
	var e := scene.instantiate() as Enemy
	e.position = pos                  # add_child 전에 위치를 정해야 등장 연출이 제자리에서 터진다
	actors.add_child(e)
	e.add_to_group("enemy")
	e.defeated.connect(_on_enemy_defeated.bind(_wave_id))
	_alive += 1


func _on_enemy_defeated(_e: Enemy, wave: int) -> void:
	if wave != _wave_id:
		return
	_alive -= 1
	if _alive > 0:
		return
	await get_tree().create_timer(wave_delay, false).timeout
	if is_inside_tree() and wave == _wave_id:
		_spawn_squad()
