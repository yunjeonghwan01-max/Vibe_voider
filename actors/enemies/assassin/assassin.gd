class_name Assassin
extends Enemy

## 제3부대 암살자 — 걷지 않고 수평 순보를 반복해 플레이어 곁으로 파고든다 (Phase1 필드몹, 그룹 field_mob).
## 루프: 대기(STALK, 쿨다운) → 멀면 순보(SHUNPO, 한 번에 shunpo_distance까지, shunpo_interval 간격으로 반복)로
##   blink_range 안까지 다가온다 → 가까워지면 순간이동처럼 보일 만큼 빠른 순보(blink)로 플레이어 등 뒤를 잡는다
##   (플레이어가 어느 쪽을 보든, 둘이 같은 방향을 보고 있어도 항상 "플레이어가 등진 쪽")
##   → 도착 자세(SETTLE) → 단검을 치켜듦(RAISE, 반격 불가 예고 + 소리) → FLASH(이때만 반격) → 찌르기 → 후딜 → 다시 추격.
## 뒤잡기는 마법적 순간이동이 아니라 실제로 지나가는 이동이다: 경로에 잔상 줄이 남고, 순보 중에도 언제나 맞는다(무적·투명화 없음).
## 공격 자체는 보병처럼 읽기 쉬운 단일 MCI — 등 뒤에서 오므로 플레이어는 돌아서며(방향키 + 반격) 받아친다.
## 안전: 목표 지점은 플레이어에서 벽까지 광선으로 재서 벽 속을 피하고, 발밑이 없거나 플레이어와 겹칠 만큼 좁으면
## 반대편(플레이어 앞)을 쓴다. 둘 다 안 되거나 높이가 다르면(발판 위 등) 순보하지 않고 기다린다. 순보 중 벽에 닿으면 멈춘다.

enum Atk { STALK, SHUNPO, SETTLE, RAISE, FLASH, STRIKE, RECOVER }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_assassin 순서)
enum Frame { IDLE_A, IDLE_B, DASH, CROUCH, RAISE, STAB, HURT }

## 프레임별 손(단검 회전축) 위치 — 시트 그림의 손 위치를 로컬 좌표로 옮긴 값 (오른쪽을 볼 때).
const HAND := [
	Vector2(10, -8), Vector2(10, -8), Vector2(-8, -6), Vector2(10, -2), Vector2(-6, -44), Vector2(24, -14), Vector2(4, 0),
]
const DAGGER_REACH := 26.0
const IDLE_DEG := 70.0          # 평소: 단검 끝이 앞쪽 아래
const DASH_DEG := 165.0         # 순보: 단검을 뒤로 끌며 달린다
const RAISED_DEG := -125.0      # 치켜듦: 칼끝이 머리 위 뒤쪽
const STAB_DEG := -4.0          # 찌르기: 앞으로 곧게
const BODY_HALF := 14.0
const MIN_PLAYER_GAP := 40.0    # 도착 지점이 플레이어와 이보다 가까우면(겹침) 쓰지 않는다

@export_group("Shunpo")
@export var engage_range: float = 1000.0      # 이 거리 안에 들어오면 추격을 시작한다
@export var shunpo_speed: float = 1500.0
@export var shunpo_distance: float = 260.0    # 순보 한 번의 최대 거리
@export var shunpo_interval: float = 0.22     # 연속 순보 사이 멈춤
@export var approach_stop: float = 200.0      # 멀 때의 순보는 플레이어에게서 이 거리까지만 다가온다 (blink_range보다 작게)
@export var blink_range: float = 280.0        # 플레이어와 가로 거리가 이 안이면 뒤잡기 순보
@export var blink_speed: float = 7000.0       # 뒤잡기 순보 속도 — 순간이동처럼 보일 만큼 (1~3프레임)
@export var arrive_offset: float = 72.0       # 플레이어 등 뒤 이 거리에 도착한다
@export var arrive_tolerance: float = 28.0    # 목표와 이만큼 가까우면 도착으로 친다
@export var attack_height: float = 90.0       # 플레이어와의 세로 차이가 이보다 크면 순보·공격하지 않고 기다린다

@export_group("Stab")
@export var settle_time: float = 0.15         # 도착 후 자세를 잡는 시간
@export var raise_time: float = 0.5           # 단검을 치켜드는 예고 (이 동안은 반격해도 헛반격)
@export var strike_time: float = 0.12
@export var strike_lunge: float = 300.0
@export var recover_time: float = 0.7
@export var attack_cooldown: float = 1.0
@export var crowd_attack_gap: float = 0.35    # 다른 제3부대가 공격을 치켜든 지 이 시간이 안 됐으면 기다린다
@export var attack_damage: int = 12
@export var attack_knockback: float = 220.0

@export_group("Scenes")
@export var slash_scene: PackedScene

@onready var _atk_shape_pos: Vector2 = attack_hitbox.position
@onready var dagger: Sprite2D = $Visual/Dagger
@onready var sfx_shunpo: AudioStreamPlayer2D = $Audio/Shunpo
@onready var sfx_raise: AudioStreamPlayer2D = $Audio/Raise
@onready var sfx_stab: AudioStreamPlayer2D = $Audio/Stab

var _atk: int = Atk.STALK
var _atk_timer: float = 0.0
var _atk_elapsed: float = 0.0   # 이번 공격(치켜듦)을 시작한 뒤 흐른 시간 — 다른 적이 간격을 재는 데 쓴다
var _cd: float = 0.0
var _dash_dir: float = 1.0
var _blinking: bool = false     # 지금 순보가 뒤잡기인가 (끝나면 곧바로 자세를 잡는다)
var _shunpo_left: float = 0.0
var _ghost_t: float = 0.0
var _dagger_deg: float = IDLE_DEG


func _on_ready() -> void:
	_cd = randf_range(0.2, 0.8)
	_atk_timer = randf_range(0.2, 0.5)


func _enemy_ai(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_atk_elapsed += delta
	match _atk:
		Atk.STALK:
			_stalk(delta)
		Atk.SHUNPO:
			_process_shunpo(delta)
		Atk.SETTLE:
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_begin_raise()
		Atk.RAISE:
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk = Atk.FLASH
				_atk_timer = glint_duration
				begin_glint(HAND[Frame.RAISE] + Vector2.from_angle(deg_to_rad(RAISED_DEG)) * DAGGER_REACH)
		Atk.FLASH:
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_begin_strike()
		Atk.STRIKE:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk = Atk.RECOVER
				_atk_timer = recover_time
				attack_hitbox.monitoring = false
		Atk.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_restart_chase(attack_cooldown * randf_range(0.8, 1.2), 0.1)


# ─────────────────────────── 추격 / 순보 ───────────────────────────
func _stalk(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
	facing = dir_to_target()
	_atk_timer -= delta
	var t := get_target()
	if _atk_timer > 0.0 or _cd > 0.0 or t == null or not is_on_floor():
		return
	if absf(t.global_position.y - global_position.y) > attack_height:
		return                          # 높이가 다르다 — 막무가내로 가지 않고 기다린다
	if distance_to_target() > engage_range:
		return
	var dx_player := t.global_position.x - global_position.x
	if absf(dx_player) > blink_range:
		# 멀다: 내 쪽에서 approach_stop 거리까지 순보로 좁힌다 (여러 번 이어질 수 있다)
		_begin_shunpo(dx_player - signf(dx_player) * approach_stop, false)
		return
	if not _crowd_allows_attack():
		return                          # 다른 제3부대가 막 치켜들었다 — 반짝임이 겹치지 않게 잠깐 기다린다
	var goal := _safe_goal_x(t, -_player_look(t))
	if is_nan(goal):
		return                          # 안전하게 설 자리가 없다 — 기다린다
	var dx := goal - global_position.x
	if absf(dx) > arrive_tolerance:
		_begin_shunpo(dx, true)
	else:
		_begin_settle()


## 플레이어가 바라보는 쪽 (+1 오른쪽 / -1 왼쪽).
func _player_look(t: Node2D) -> float:
	var p := t as Player
	if p != null and p.facing != 0.0:
		return signf(p.facing)
	return -signf(t.global_position.x - global_position.x)


## 도착 지점 x. 원하는 쪽(보통 플레이어 등 뒤)이 벽에 막혀 플레이어와 겹치거나 발밑이 없으면 반대쪽, 둘 다 안 되면 NAN.
func _safe_goal_x(t: Node2D, want_side: float) -> float:
	var y := global_position.y
	for side in [want_side, -want_side]:
		var gx: float = t.global_position.x + side * arrive_offset
		var wall := _ray(Vector2(t.global_position.x, y - 10.0), Vector2(gx + side * BODY_HALF, y - 10.0))
		if not wall.is_empty():
			gx = wall.position.x - side * (BODY_HALF + 4.0)
		if absf(gx - t.global_position.x) < MIN_PLAYER_GAP:
			continue
		if _ray(Vector2(gx, y - 10.0), Vector2(gx, y + 60.0)).is_empty():
			continue
		return gx
	return NAN


func _begin_settle() -> void:
	_atk = Atk.SETTLE
	_atk_timer = settle_time
	facing = dir_to_target()


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, CollisionLayers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q)


func _begin_shunpo(dx: float, blink: bool) -> void:
	_atk = Atk.SHUNPO
	_blinking = blink
	_dash_dir = signf(dx)
	_shunpo_left = absf(dx) if blink else minf(absf(dx), shunpo_distance)
	facing = _dash_dir
	_ghost_t = 0.0
	visual.scale = Vector2(1.3 * signf(facing), 0.8)
	_sfx(sfx_shunpo, 0.08)
	sfx_shunpo.pitch_scale *= 1.35 if blink else 1.0
	_burst(Color(0.45, 0.9, 0.6, 1.0), 6, 30.0, 0.2, false)
	if blink:
		_spawn_blink_trail(_dash_dir * _shunpo_left)


func _process_shunpo(delta: float) -> void:
	# 마지막 프레임은 남은 거리만큼만 — 목표를 지나치지 않는다. 벽에 닿으면 그 자리에서 멈춘다.
	var spd := minf(blink_speed if _blinking else shunpo_speed, _shunpo_left / maxf(delta, 0.0001))
	velocity.x = _dash_dir * spd
	_shunpo_left -= spd * delta
	_ghost_t -= delta
	if _ghost_t <= 0.0 and not _blinking:
		_ghost_t = 0.035
		_spawn_ghost(global_position, 0.45)
	if _shunpo_left <= 0.5 or is_on_wall():
		velocity.x = _dash_dir * 60.0
		if _blinking:
			_blinking = false
			visual.scale = Vector2(0.8 * signf(_dash_dir), 1.2)
			_burst(Color(0.45, 0.9, 0.6, 1.0), 8, 36.0, 0.22, true)
			_begin_settle()             # 등 뒤를 잡았다 — 돌아서서 곧바로 자세를 잡는다 (피해는 예고 뒤에)
		else:
			_atk = Atk.STALK
			_atk_timer = shunpo_interval
			facing = dir_to_target()


## 다른 제3부대(보병/암살자)가 방금 공격을 치켜들었으면 기다린다 — FLASH가 완전히 겹치지 않게 하는 가독성 조정.
func _crowd_allows_attack() -> bool:
	for n in get_tree().get_nodes_in_group("field_mob"):
		var e := n as Enemy
		if e == null or e == self or e.state != State.ACTIVE:
			continue
		var inf := e as Infantry
		if inf != null and (inf._atk == Infantry.Atk.RAISE or inf._atk == Infantry.Atk.FLASH) and inf._atk_elapsed < crowd_attack_gap:
			return false
		var asn := e as Assassin
		if asn != null and (asn._atk == Atk.RAISE or asn._atk == Atk.FLASH) and asn._atk_elapsed < crowd_attack_gap:
			return false
	return true


# ─────────────────────────── 찌르기 (근접 카유공 MCI) ───────────────────────────
func _begin_raise() -> void:
	_atk = Atk.RAISE
	_atk_timer = raise_time
	_atk_elapsed = 0.0
	facing = dir_to_target()            # 방향은 여기서 고정 — 치켜든 뒤 등 뒤로 돌아가면 헛찌른다
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	visual.scale = Vector2(0.85 * signf(facing), 1.18)
	_sfx(sfx_raise, 0.05)


func _begin_strike() -> void:
	end_glint()
	_atk = Atk.STRIKE
	_atk_timer = strike_time
	visual.scale = Vector2(1.3 * signf(facing), 0.84)
	if is_on_floor():
		velocity.x = facing * strike_lunge
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = attack_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.25).normalized()
	attack_hitbox.monitoring = true
	_sfx(sfx_stab, 0.08)
	_spawn_slash()


## 다음 추격을 처음부터.
func _restart_chase(cooldown: float, wait: float) -> void:
	_atk = Atk.STALK
	_atk_timer = wait
	_cd = maxf(_cd, cooldown)
	_blinking = false


func _on_hurt(_source: Node) -> void:
	# 순보 중에도 맞는다 — 맞으면 순보가 끊기고 남은 돌진 속도를 버린다 (넉백만 남는다).
	if _atk == Atk.SHUNPO:
		velocity.x = -_dash_dir * 140.0
	_restart_chase(attack_cooldown * 0.5, 0.35)


func _on_parried_react(_from_pos: Vector2) -> void:
	_restart_chase(attack_cooldown, 0.4)


func _on_stagger_end() -> void:
	_restart_chase(attack_cooldown * 0.5, 0.25)


# ─────────────────────────── 외형 ───────────────────────────
func _animate(delta: float) -> void:
	var frame_i: int = Frame.IDLE_A
	var target := IDLE_DEG
	var snap := false
	match state:
		State.HITSTUN, State.CARRIED:
			frame_i = Frame.HURT
			target = 110.0
		State.STAGGER:
			frame_i = Frame.HURT
			target = 120.0
		State.SPAWNING:
			frame_i = Frame.IDLE_A
		_:
			match _atk:
				Atk.SHUNPO:
					frame_i = Frame.DASH
					target = DASH_DEG
					snap = true
				Atk.SETTLE:
					frame_i = Frame.CROUCH
				Atk.RAISE:
					frame_i = Frame.RAISE
					var u := 1.0 - clampf(_atk_timer / raise_time, 0.0, 1.0)
					target = lerpf(IDLE_DEG, RAISED_DEG, 1.0 - pow(1.0 - u, 2.0))   # 앞 → 위 → 머리 뒤
					snap = true
				Atk.FLASH:
					frame_i = Frame.RAISE
					target = RAISED_DEG
					snap = true
				Atk.STRIKE:
					frame_i = Frame.STAB
					target = STAB_DEG
					snap = true
				Atk.RECOVER:
					frame_i = Frame.STAB if _atk_timer > recover_time * 0.5 else Frame.CROUCH
					target = STAB_DEG + 20.0
				_:
					frame_i = Frame.IDLE_A + int(_anim_t * 2.5) % 2
					target = IDLE_DEG + 4.0 * sin(_anim_t * 3.0)
	body.frame = frame_i
	if snap:
		_dagger_deg = target
	else:
		_dagger_deg = lerpf(_dagger_deg, target, 1.0 - exp(-14.0 * delta))
	dagger.position = HAND[frame_i]
	dagger.rotation_degrees = _dagger_deg


## 뒤잡기 순보의 경로 연출: 지나갈 길 위에 잔상들과 가는 초록 궤적을 미리 깔고 빠르게 지운다.
## 실제 이동은 그 길을 1~3프레임에 지나간다 (경로상에서 맞을 수 있다).
func _spawn_blink_trail(offset_x: float) -> void:
	var from := global_position
	var count := clampi(int(absf(offset_x) / 34.0), 2, 8)
	for i in count:
		var u := float(i) / count
		_spawn_ghost(from + Vector2(offset_x * u, 0.0), 0.15 + 0.4 * u)
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.6, 1.0, 0.72, 0.8)
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2(offset_x, 0.0))
	_fx_parent().add_child(line)
	line.global_position = from + Vector2(0.0, -14.0)
	var tw := line.create_tween()
	tw.set_parallel(true)
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_property(line, "width", 0.5, 0.16)
	tw.chain().tween_callback(line.queue_free)


## 순보 잔상 — 지나간 자리에 초록빛 그림자가 잠깐 남는다 (본체는 계속 보이고 맞는다).
func _spawn_ghost(at: Vector2, alpha: float) -> void:
	var g := Sprite2D.new()
	g.texture = body.texture
	g.hframes = body.hframes
	g.frame = body.frame
	g.centered = false
	g.offset = body.offset
	g.scale = Vector2(2.0 * signf(facing), 2.0)
	g.frame = Frame.DASH
	g.modulate = Color(0.4, 0.95, 0.6, alpha)
	_fx_parent().add_child(g)
	g.global_position = at + Vector2(0.0, body.position.y)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.18)
	tw.tween_callback(g.queue_free)


func _spawn_slash() -> void:
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(0.5, 0.95, 0.62, 0.85)
	s.core_color = Color(0.92, 1.0, 0.94, 1.0)
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(signf(facing) * 28.0, -16.0)
	s.setup(facing, 0.0, 0.8)
