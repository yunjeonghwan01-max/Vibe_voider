class_name Crossbowman
extends Enemy

## 제3부대 석궁병 — 한 자리를 지키며 수평으로 곧게 날아가는 은빛 볼트(PRCI 투사체)를 쏘는 견제병 (Phase1 필드몹).
## 루프: 경계(GUARD, 플레이어를 바라봄) → 플레이어가 같은 수평선에 있고 사선이 지형(world 충돌)에 막히지 않으면
##   조준(AIM): 실제 탄도를 따라 벽까지 길고 얇은 경고 BAR → 발사(RECOIL) → 장전(reload_time) → 다시 경계.
## 볼트(CrossbowBolt)는 WatcherNeedle을 상속한 실제 투사체 — 점프로 피하거나, 몸에 닿기 직전 금빛으로 빛나는
##   짧은 순간에 반격 키로 베어 지운다 (기존 PRCI 그대로, 석궁병에게 반격 피해는 없다).
## 경고 BAR와 볼트는 같은 직선이다: 둘 다 총구 높이에서 수평으로 나가고, BAR는 볼트가 부서질 첫 벽에서 끝난다.
## 플레이어가 retreat_trigger 안으로 붙으면 retreat_cooldown마다 한 번 뒤로 수평 순보해 물러난다.
##   뒤가 벽이면 벽 앞까지, 발밑이 끝나면 끝 앞까지만 가고, 그 거리가 retreat_min보다 짧으면 제자리를 지킨다.
## 근접 공격은 없다 (반격의 올려베기에는 다른 필드몹처럼 기절한다).

enum Atk { GUARD, AIM, RECOIL, RETREAT }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_crossbowman 순서)
enum Frame { IDLE_A, IDLE_B, AIM, RELOAD, RETREAT, HURT }

## 프레임별 손(석궁 회전축) 위치 — 시트 그림의 손 위치를 로컬 좌표로 옮긴 값 (오른쪽을 볼 때).
const HAND := [Vector2(12, -8), Vector2(12, -8), Vector2(14, -10), Vector2(8, -4), Vector2(6, -12), Vector2(4, -2)]
const MUZZLE := Vector2(51, -17)    # 조준 자세의 석궁 앞끝 = HAND[AIM] + (37, -7). 볼트와 경고 BAR가 여기서 나간다
const BODY_HALF := 13.0

@export_group("Shot")
@export var sight_height: float = 40.0        # 플레이어와의 높이 차이가 이 안일 때만 "같은 수평선"
@export var sight_range: float = 1100.0
@export var aim_time: float = 0.75            # 경고 BAR가 보이는 시간 (끝나면 발사)
@export var recoil_time: float = 0.2
@export var reload_time: float = 1.6          # 발사 후 다음 조준까지 (±20%)
@export var bolt_speed: float = 700.0
@export var bolt_damage: int = 10
@export var bolt_knockback: float = 200.0
@export var bolt_deflect_range: float = 100.0 # 볼트가 플레이어 중심까지 이 안으로 다가오는 동안만 반격으로 지울 수 있다
@export var bolt_lifetime: float = 3.5

@export_group("Retreat")
@export var retreat_trigger: float = 140.0    # 플레이어가 이 가로 거리 안으로 붙으면 물러난다
@export var retreat_distance: float = 190.0
@export var retreat_speed: float = 1300.0
@export var retreat_cooldown: float = 3.0
@export var retreat_min: float = 40.0         # 이보다 짧게밖에 못 물러나면 제자리를 지킨다

@export_group("Scenes")
@export var bolt_scene: PackedScene

@onready var crossbow: Sprite2D = $Visual/Crossbow
@onready var sfx_aim: AudioStreamPlayer2D = $Audio/Aim
@onready var sfx_shot: AudioStreamPlayer2D = $Audio/Shot
@onready var sfx_retreat: AudioStreamPlayer2D = $Audio/Retreat

var _atk: int = Atk.GUARD
var _atk_timer: float = 0.0
var _reload_t: float = 0.0
var _retreat_cd: float = 0.0
var _aim_dir: float = 1.0
var _dash_dir: float = 1.0
var _retreat_left: float = 0.0
var _bow_deg: float = 25.0
var _bar_glow: Line2D = null
var _bar_core: Line2D = null


func _on_ready() -> void:
	_reload_t = randf_range(0.6, 1.6)     # 첫 사격 시점을 흩뜨린다


func _enemy_ai(delta: float) -> void:
	_reload_t = maxf(_reload_t - delta, 0.0)
	_retreat_cd = maxf(_retreat_cd - delta, 0.0)
	match _atk:
		Atk.GUARD:
			_guard(delta)
		Atk.AIM:
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			_atk_timer -= delta
			_update_bar()
			if _atk_timer <= 0.0:
				_fire()
		Atk.RECOIL:
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk = Atk.GUARD
		Atk.RETREAT:
			_process_retreat(delta)


func _guard(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
	facing = dir_to_target()
	var t := get_target()
	if t == null or not is_on_floor():
		return
	var dx := absf(t.global_position.x - global_position.x)
	var level := absf(t.global_position.y - global_position.y) <= sight_height
	if _retreat_cd <= 0.0 and level and dx <= retreat_trigger:
		_retreat_cd = retreat_cooldown      # 물러나지 못해도 쿨다운은 돈다 — 매 프레임 재시도하지 않는다
		if _begin_retreat():
			return
	if _reload_t <= 0.0 and level and _has_clear_shot(t):
		_begin_aim()


## 같은 수평선 위에 있고, 총구 높이의 수평 직선이 플레이어까지 지형에 막히지 않는가.
func _has_clear_shot(t: Node2D) -> bool:
	var dx := t.global_position.x - global_position.x
	if absf(dx) > sight_range or absf(dx) < MUZZLE.x + 20.0:
		return false                        # 너무 가까우면 총구가 플레이어를 지나친다
	var from := _muzzle_global(signf(dx))
	return _ray(from, Vector2(t.global_position.x, from.y)).is_empty()


func _muzzle_global(dir: float) -> Vector2:
	return global_position + Vector2(dir * MUZZLE.x, MUZZLE.y)


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, CollisionLayers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q)


# ─────────────────────────── 조준 / 발사 ───────────────────────────
func _begin_aim() -> void:
	_atk = Atk.AIM
	_atk_timer = aim_time
	_aim_dir = facing
	_sfx(sfx_aim, 0.05)
	# 볼트가 실제로 갈 길: 총구에서 수평으로, 부서질 첫 벽(또는 사거리 끝)까지.
	var from := _muzzle_global(_aim_dir)
	var to := from + Vector2(_aim_dir * bolt_speed * bolt_lifetime, 0.0)
	var hit := _ray(from, to)
	if not hit.is_empty():
		to = hit.position
	_bar_glow = _make_bar(from, to, 7.0)
	_bar_core = _make_bar(from, to, 1.5)
	_update_bar()


func _make_bar(from: Vector2, to: Vector2, width: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.add_point(from - global_position)
	line.add_point(to - global_position)
	line.z_index = 4
	add_child(line)                         # 루트는 좌우 반전되지 않는다 — 점 좌표 그대로
	return line


## 조준이 진행될수록 BAR가 진해지고, 발사 직전(0.15초)에는 하얗게 굵어진다.
func _update_bar() -> void:
	if _bar_core == null:
		return
	var u := 1.0 - clampf(_atk_timer / aim_time, 0.0, 1.0)
	var imminent := _atk_timer <= 0.15
	_bar_glow.default_color = Color(0.45, 1.0, 0.6, 0.06 + 0.14 * u)
	_bar_core.default_color = Color(1.0, 1.0, 1.0, 0.95) if imminent else Color(0.7, 1.0, 0.78, 0.25 + 0.45 * u)
	_bar_core.width = 2.5 if imminent else 1.5


func _clear_bar() -> void:
	for line in [_bar_glow, _bar_core]:
		if line != null and is_instance_valid(line):
			line.queue_free()
	_bar_glow = null
	_bar_core = null


func _fire() -> void:
	_clear_bar()
	_atk = Atk.RECOIL
	_atk_timer = recoil_time
	_reload_t = reload_time * randf_range(0.8, 1.2)
	visual.scale = Vector2(0.86 * signf(facing), 1.12)
	_sfx(sfx_shot, 0.06)
	if bolt_scene == null:
		return
	var b := bolt_scene.instantiate() as CrossbowBolt
	b.source = self
	b.direction = Vector2(_aim_dir, 0.0)
	b.target = get_target()
	b.speed = bolt_speed
	b.damage = bolt_damage
	b.knockback = bolt_knockback
	b.deflect_range = bolt_deflect_range
	b.max_lifetime = bolt_lifetime
	_projectile_parent().add_child(b)
	b.global_position = _muzzle_global(_aim_dir)


func _projectile_parent() -> Node:
	var c := get_tree().get_first_node_in_group("projectiles")
	return c if c else get_parent()


# ─────────────────────────── 후퇴 순보 ───────────────────────────
func _begin_retreat() -> bool:
	var away := -dir_to_target()
	var d := _safe_retreat_distance(away)
	if d < retreat_min:
		return false                        # 뒤가 막혔다 — 제자리를 지킨다
	_atk = Atk.RETREAT
	_dash_dir = away
	_retreat_left = d
	facing = -away                          # 플레이어를 본 채로 뒤로 미끄러진다
	visual.scale = Vector2(1.25 * signf(facing), 0.82)
	_sfx(sfx_retreat, 0.08)
	_burst(Color(0.45, 0.9, 0.6, 1.0), 6, 30.0, 0.2, false)
	return true


## 뒤로 갈 수 있는 거리: 벽 앞까지, 발밑이 끝나기 전까지.
func _safe_retreat_distance(dir: float) -> float:
	var x := global_position.x
	var y := global_position.y
	var want := retreat_distance
	var wall := _ray(Vector2(x, y - 10.0), Vector2(x + dir * (want + BODY_HALF), y - 10.0))
	if not wall.is_empty():
		want = minf(want, absf(wall.position.x - x) - BODY_HALF - 4.0)
	var s := 12.0
	while s <= want:
		if _ray(Vector2(x + dir * s, y - 10.0), Vector2(x + dir * s, y + 60.0)).is_empty():
			return maxf(s - 16.0, 0.0)
		s += 12.0
	return maxf(want, 0.0)


func _process_retreat(delta: float) -> void:
	var spd := minf(retreat_speed, _retreat_left / maxf(delta, 0.0001))
	velocity.x = _dash_dir * spd
	_retreat_left -= spd * delta
	if _retreat_left <= 0.5 or is_on_wall():
		velocity.x = _dash_dir * 40.0
		_atk = Atk.GUARD
		_reload_t = maxf(_reload_t, 0.35)   # 물러나자마자 쏘지는 않는다


# ─────────────────────────── 피격 / 정리 ───────────────────────────
func _on_hurt(_source: Node) -> void:
	if _atk == Atk.RETREAT:
		velocity.x = _dash_dir * 60.0
	_clear_bar()                            # 맞으면 조준이 풀린다 — 쏘지 않을 경고선을 남기지 않는다
	_atk = Atk.GUARD
	_reload_t = maxf(_reload_t, 0.6)


func _on_parried_react(_from_pos: Vector2) -> void:
	_clear_bar()
	_atk = Atk.GUARD
	_reload_t = maxf(_reload_t, 0.8)


func _on_died() -> void:
	_clear_bar()
	super._on_died()


func _on_banished() -> void:
	_clear_bar()


# ─────────────────────────── 외형 ───────────────────────────
func _animate(delta: float) -> void:
	var frame_i: int = Frame.IDLE_A
	var target := 25.0
	var snap := false
	match state:
		State.HITSTUN, State.CARRIED, State.STAGGER:
			frame_i = Frame.HURT
			target = 60.0
		State.SPAWNING:
			frame_i = Frame.IDLE_A
		_:
			match _atk:
				Atk.AIM:
					frame_i = Frame.AIM
					target = 0.0
					snap = true
				Atk.RECOIL:
					frame_i = Frame.AIM
					target = -10.0
				Atk.RETREAT:
					frame_i = Frame.RETREAT
					target = 15.0
				_:
					if _reload_t > 0.0 and _reload_t > reload_time * 0.4:
						frame_i = Frame.RELOAD      # 아래로 숙여 다시 건다
						target = 65.0
					else:
						frame_i = Frame.IDLE_A + int(_anim_t * 2.0) % 2
						target = 25.0 + 3.0 * sin(_anim_t * 2.0)
	body.frame = frame_i
	if snap:
		_bow_deg = target
	else:
		_bow_deg = lerpf(_bow_deg, target, 1.0 - exp(-14.0 * delta))
	crossbow.position = HAND[frame_i]
	crossbow.rotation_degrees = _bow_deg
