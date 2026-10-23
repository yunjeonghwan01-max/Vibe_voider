class_name GroundImpact
extends Node2D

## 지형이 깨지는 연출 (_draw — 외부 이미지 없음). 보스 착지·내려찍기·벽 충돌, 등장 때의 발판 금과 천장 부스러기.
## 쓰는 쪽이 add_child + 위치 지정 뒤 하나를 부른다:
##   crack_ground(strength, persist)   이 노드의 y=0이 바닥 윗면. 방사형 균열(처음엔 보랏빛으로 타오름) + 튀는 돌조각 + 흙먼지
##   crack_wall(dir, strength)         벽면(x=0)에 거미줄 금 + 떨어지는 조각. dir = 벽 안쪽 방향(-1/1)
##   crack_ledge(width, floor_y)       발판 윗면을 따라 잔금 + 아래(floor_y = 바닥까지의 거리)로 떨어지는 조각
##   rain_rubble(area, duration)       area 윗변에서 돌 부스러기가 떨어져 area 아랫변(바닥)에서 부서진다
## 균열은 persist초 동안 남았다가 서서히 사라진다. 다 끝나면 스스로 사라진다.

const GRAVITY := 1700.0
const CRACK_DARK := Color(0.05, 0.02, 0.08, 1.0)
const CRACK_EDGE := Color(0.62, 0.6, 0.76, 0.55)
const CRACK_GLOW := Color(0.75, 0.45, 1.0, 1.0)
const STONES := [Color(0.36, 0.34, 0.47), Color(0.27, 0.25, 0.36), Color(0.46, 0.44, 0.58), Color(0.2, 0.18, 0.27)]

var _cracks: Array = []        # [PackedVector2Array, 굵기]
var _chunks: Array = []        # Dictionary: p, v, size, rot, spin, col, floor_y, bounced, life
var _puffs: Array = []         # Dictionary: p, v, r, grow, life, max, col
var _t: float = 0.0
var _persist: float = 0.0
var _glow_time: float = 0.45
var _rain_area: Rect2 = Rect2()
var _rain_left: float = 0.0
var _rain_acc: float = 0.0
var _rain_rate: float = 0.0


func crack_ground(strength: float, persist: float) -> void:
	_persist = persist
	var branches := 4 + int(strength * 5.0)
	for i in branches:
		var side := -1.0 if i % 2 == 0 else 1.0
		# 바닥 표면을 따라 옆으로 뻗거나(얕은 각) 바닥 면 아래로 파고든다(깊은 각)
		var ang := deg_to_rad(randf_range(4.0, 70.0))
		var dir := Vector2(cos(ang) * side, sin(ang))
		_add_crack(Vector2(randf_range(-8.0, 8.0), 1.0), dir, randf_range(50.0, 120.0) * (0.6 + strength), 3.5, 2)
	# 표면이 패인 자국
	for i in int(6 + strength * 8.0):
		_spawn_chunk(Vector2(randf_range(-30.0, 30.0) * (0.5 + strength), -2.0),
				Vector2(randf_range(-260.0, 260.0) * (0.6 + strength * 0.6), randf_range(-520.0, -180.0) * (0.7 + strength * 0.5)),
				randf_range(3.0, 7.5) * (0.8 + strength * 0.4), 0.0)
	for i in int(5 + strength * 6.0):
		var s := -1.0 if i % 2 == 0 else 1.0
		_spawn_puff(Vector2(randf_range(-20.0, 20.0), -10.0), Vector2(s * randf_range(60.0, 220.0) * (0.6 + strength), randf_range(-60.0, -10.0)),
				randf_range(14.0, 26.0) * (0.7 + strength * 0.5), randf_range(0.6, 1.1))


func crack_wall(dir: float, strength: float) -> void:
	_persist = 5.0
	for i in 4 + int(strength * 3.0):
		var ang := deg_to_rad(randf_range(-80.0, 80.0))
		_add_crack(Vector2(0.0, randf_range(-20.0, 20.0)), Vector2(cos(ang) * dir * 0.25, sin(ang)).normalized(),
				randf_range(40.0, 90.0) * (0.6 + strength), 3.0, 1)
	for i in 6:
		_spawn_chunk(Vector2(dir * 4.0, randf_range(-40.0, 30.0)), Vector2(dir * randf_range(80.0, 260.0), randf_range(-220.0, 0.0)),
				randf_range(3.0, 6.0), 80.0)
	for i in 4:
		_spawn_puff(Vector2(dir * 6.0, randf_range(-30.0, 30.0)), Vector2(dir * randf_range(40.0, 120.0), randf_range(-30.0, 30.0)),
				randf_range(12.0, 20.0), randf_range(0.5, 0.8))


func crack_ledge(width: float, floor_y: float) -> void:
	_persist = 9.0
	_glow_time = 0.0
	for i in 5:
		var x := randf_range(-width * 0.45, width * 0.45)
		_add_crack(Vector2(x, 0.0), Vector2(randf_range(-0.5, 0.5), 1.0).normalized(), randf_range(10.0, 18.0), 2.0, 0)
	for i in 4:
		_spawn_chunk(Vector2(randf_range(-width * 0.4, width * 0.4), 14.0), Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 30.0)),
				randf_range(3.0, 5.5), floor_y)
	_spawn_puff(Vector2(0.0, 12.0), Vector2(0.0, 20.0), width * 0.18, 0.7)


func rain_rubble(area: Rect2, duration: float) -> void:
	_rain_area = area
	_rain_left = duration
	_rain_rate = area.size.x / 32.0          # 초당 조각 수
	_persist = 0.0
	_glow_time = 0.0


# ─────────────────────────── 내부 ───────────────────────────
func _add_crack(start: Vector2, dir: Vector2, length: float, width: float, depth: int) -> void:
	var pts := PackedVector2Array([start])
	var p := start
	var d := dir
	var walked := 0.0
	while walked < length:
		var step := randf_range(6.0, 12.0)
		d = d.rotated(randf_range(-0.55, 0.55)).lerp(dir, 0.35).normalized()
		if d.y < -0.05:
			d.y = absf(d.y)                  # 바닥 위(공중)로 금이 올라가지 않게
		p += d * step
		walked += step
		pts.append(p)
		if depth > 0 and randf() < 0.18:
			_add_crack(p, d.rotated(randf_range(-1.0, 1.0)), (length - walked) * 0.55, width * 0.6, depth - 1)
	if pts.size() >= 2:
		_cracks.append([pts, width])


func _spawn_chunk(p: Vector2, v: Vector2, size: float, floor_y: float) -> void:
	_chunks.append({"p": p, "v": v, "size": size, "rot": randf() * TAU, "spin": randf_range(-12.0, 12.0),
			"col": STONES.pick_random(), "floor_y": floor_y, "bounced": false, "life": randf_range(0.9, 1.6)})


func _spawn_puff(p: Vector2, v: Vector2, r: float, life: float) -> void:
	_puffs.append({"p": p, "v": v, "r": r, "life": life, "max": life, "col": Color(0.62, 0.6, 0.74)})


func _process(delta: float) -> void:
	_t += delta
	if _rain_left > 0.0:
		_rain_left -= delta
		_rain_acc += delta * _rain_rate
		while _rain_acc >= 1.0:
			_rain_acc -= 1.0
			var x := randf_range(_rain_area.position.x, _rain_area.end.x)
			var y := _rain_area.position.y + randf_range(0.0, _rain_area.size.y * 0.35)   # 일부는 화면 안에서 떨어지기 시작
			_spawn_chunk(Vector2(x, y), Vector2(randf_range(-30.0, 30.0), randf_range(0.0, 160.0)),
					randf_range(3.0, 8.5), _rain_area.end.y)
			if randf() < 0.45:
				_spawn_puff(Vector2(x, y), Vector2(0.0, 140.0), randf_range(10.0, 18.0), 1.0)

	for c in _chunks:
		var v: Vector2 = c["v"]
		var p: Vector2 = c["p"]
		var floor_y: float = c["floor_y"]
		v.y += GRAVITY * delta
		p += v * delta
		c["rot"] = float(c["rot"]) + float(c["spin"]) * delta
		if p.y >= floor_y and v.y > 0.0:
			p.y = floor_y
			if not c["bounced"] and float(c["size"]) > 3.5:
				c["bounced"] = true
				v = Vector2(v.x * 0.45, -v.y * 0.3)
				c["spin"] = float(c["spin"]) * 0.5
			else:
				v = Vector2.ZERO
				c["spin"] = 0.0
		if v == Vector2.ZERO:
			c["life"] = float(c["life"]) - delta
		c["v"] = v
		c["p"] = p
	_chunks = _chunks.filter(func(c): return c["life"] > 0.0)

	for f in _puffs:
		f["life"] = float(f["life"]) - delta
		f["p"] = (f["p"] as Vector2) + (f["v"] as Vector2) * delta
		f["v"] = (f["v"] as Vector2) * exp(-3.0 * delta)
		f["r"] = float(f["r"]) + 18.0 * delta
	_puffs = _puffs.filter(func(f): return f["life"] > 0.0)

	if _t >= _persist and _chunks.is_empty() and _puffs.is_empty() and _rain_left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# 균열: 처음엔 보랏빛으로 타오르다 어두운 금으로 식고, 끝에 가서 서서히 사라진다
	var alpha := 1.0 if _persist <= 0.0 else clampf((_persist - _t) / minf(1.5, _persist), 0.0, 1.0)
	var heat := 0.0 if _glow_time <= 0.0 else clampf(1.0 - _t / _glow_time, 0.0, 1.0)
	if alpha > 0.0:
		for cr in _cracks:
			var pts: PackedVector2Array = cr[0]
			var w: float = cr[1]
			if heat > 0.0:
				draw_polyline(pts, Color(CRACK_GLOW.r, CRACK_GLOW.g, CRACK_GLOW.b, 0.5 * heat * alpha), w + 4.0 * heat)
			var edge := pts.duplicate()
			for i in edge.size():
				edge[i] += Vector2(0.0, 1.5)
			draw_polyline(edge, Color(CRACK_EDGE.r, CRACK_EDGE.g, CRACK_EDGE.b, CRACK_EDGE.a * alpha), maxf(w * 0.4, 1.0))
			draw_polyline(pts, Color(CRACK_DARK.r, CRACK_DARK.g, CRACK_DARK.b, alpha).lerp(Color(1.0, 0.85, 1.0, alpha), heat * 0.6), w)

	for f in _puffs:
		var k: float = float(f["life"]) / float(f["max"])
		var col: Color = f["col"]
		var fp: Vector2 = f["p"]
		var r: float = f["r"]
		draw_circle(fp, r, Color(col.r, col.g, col.b, 0.32 * k))
		draw_circle(fp + Vector2(-r * 0.3, -r * 0.2), r * 0.6, Color(col.r, col.g, col.b, 0.22 * k))

	for c in _chunks:
		var a := clampf(float(c["life"]) / 0.4, 0.0, 1.0)
		var s: float = c["size"]
		var cp: Vector2 = c["p"]
		var pts := PackedVector2Array()
		for i in 5:
			var ang: float = float(c["rot"]) + i * TAU / 5.0
			pts.append(cp + Vector2.from_angle(ang) * s * (0.7 + 0.3 * float((i * 7) % 3) / 2.0))
		var col: Color = c["col"]
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, a))
		draw_line(pts[0], pts[1], Color(col.r + 0.15, col.g + 0.15, col.b + 0.18, a), 1.0)
