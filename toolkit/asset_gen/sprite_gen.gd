extends SceneTree

## 오프라인 픽셀아트 생성기 (개발 도구 — 게임 실행에는 필요 없다).
## 캐릭터 시트, 방 배경, 소품 PNG를 코드로 그려 assets/temporary/ 아래에 저장한다.
## 결과물은 커밋되어 있으므로 아트를 다시 뽑을 때만 실행한다:
##   Godot --headless --path . --script res://toolkit/asset_gen/sprite_gen.gd
## 같은 seed를 쓰므로 다시 실행해도 같은 그림이 나온다.
## 모든 아트는 "1 아트 픽셀 = 화면 2px" 밀도로 그리고, 씬에서 scale 2로 쓴다.

const OUT := "res://assets/temporary/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7
	for dir in ["characters/player", "characters/grunt", "characters/duelist", "characters/watcher", "environment", "effects"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + dir))
	_gen_player()
	_gen_grunt()
	_gen_duelist()
	_gen_room()
	_gen_props()
	_gen_effects()   # 맨 뒤에 둔다 — rng 소비 순서가 바뀌면 기존 그림이 달라진다
	_gen_watcher()   # 새 생성기는 항상 이 아래에 추가한다 (같은 이유)
	print("[sprite_gen] done")
	quit()


# ═══════════════════════════════ 공용 헬퍼 ═══════════════════════════════
func _new(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _c(r: int, g: int, b: int, a: int = 255) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a / 255.0)


func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _px(img: Image, x: int, y: int) -> Color:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		return img.get_pixel(x, y)
	return Color(0, 0, 0, 0)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, xx, yy, c)


func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_put(img, x, y, c)


func _poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var minp := pts[0]
	var maxp := pts[0]
	for p in pts:
		minp = minp.min(p)
		maxp = maxp.max(p)
	for y in range(floori(minp.y), ceili(maxp.y) + 1):
		for x in range(floori(minp.x), ceili(maxp.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				_put(img, x, y, c)


func _line(img: Image, a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var steps := int(maxf(a.distance_to(b) * 2.0, 1.0))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		_ellipse(img, p.x, p.y, width * 0.5, width * 0.5, c)


## 투명 픽셀 중 불투명 픽셀과 4방향으로 맞닿은 곳에 외곽선을 찍는다.
func _outline(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var marks: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := _px(img, x + d.x, y + d.y)
				if n.a > 0.0 and not n.is_equal_approx(c):
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixel(m.x, m.y, c)


## 좌상단 광원: 위/왼쪽이 비어 있는 가장자리는 밝게, 아래/오른쪽이 비어 있는 가장자리는 어둡게.
func _shade_edges(img: Image, light: float, dark: float, skip: Array = []) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := src.get_pixel(x, y)
			if c.a <= 0.0 or _in_colors(c, skip):
				continue
			if _px(src, x - 1, y).a <= 0.0 or _px(src, x, y - 1).a <= 0.0:
				img.set_pixel(x, y, c.lightened(light))
			elif _px(src, x + 1, y).a <= 0.0 or _px(src, x, y + 1).a <= 0.0:
				img.set_pixel(x, y, c.darkened(dark))


func _in_colors(c: Color, list: Array) -> bool:
	for k in list:
		if c.is_equal_approx(k):
			return true
	return false


func _sheet(frames: Array[Image]) -> Image:
	var fw := frames[0].get_width()
	var fh := frames[0].get_height()
	var sheet := _new(fw * frames.size(), fh)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	return sheet


func _from_ascii(rows: Array, pal: Dictionary, pad: int = 0) -> Image:
	var w: int = 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := _new(w + pad * 2, rows.size() + pad * 2)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x + pad, y + pad, pal[ch])
	return img


func _save(img: Image, path: String) -> void:
	var err := img.save_png(OUT + path)
	print("  saved ", path, " ", img.get_size(), " err=", err)


# ═══════════════════════════════ 플레이어 (검은 고양이) ═══════════════════════════════
# 원본 일러스트(Voider Player01.png)를 28px 격자로 다운샘플한 뒤 손으로 다듬은 도트.
# 검은 손에서 분리해 따로(player_sword.png) 그려, 휘두르는 애니메이션을 만든다.
# 다리(38~39행)와 망토 꼬리(31행 이하, 9열 이하)는 프레임마다 코드로 움직인다.
const CAT := [
	"............#.........................",
	"............#.........#...............",
	"............##........##..............",
	"............###......###..............",
	"............####.....###..............",
	"............#####....####.............",
	"............######..#####.............",
	"............##############............",
	"............##############............",
	"............##############............",
	"............##############............",
	"............###############...........",
	"...........#################..........",
	"...........#################..........",
	"...........#################..........",
	"...........#################..........",
	"...........#########WY####Y#..........",
	"...........########YYYY###Y#..........",
	"...........#########yYy#####..........",
	"...........#############O###..........",
	"...........P################..........",
	"..........PPPPPP###########...........",
	"..........pppppppppppPP#PPP...........",
	"..........PPPPPPPPPPPPPPPPPP..........",
	"..........dddPPPPPPPPPPPPPP...........",
	"..........PPPPddddPPPPPPPPd...........",
	"..........PPPPPPPPPPPPPPPPP...........",
	"..........PPdddddPPPPPPPPPd...........",
	".........PPPPPPPPPd#PPPPPPP...........",
	"........PPPPPPPPPP####PP#PP...........",
	".......PPPPPPPP###########............",
	"..PPPPPPPPPdd#############............",
	".PPPPPPPddddd#############............",
	"PPPPPPdddddddd############............",
	"..PPPddddddddd##########..............",
	".PPPddddddddd###########..............",
	".PP..ddddddddd#########d..............",
	".P....ddd..dddd########...............",
	"......................................",
	"......................................",
]


func _gen_player() -> void:
	var pal := {
		"#": _c(20, 17, 28), "P": _c(124, 58, 130), "p": _c(160, 88, 166), "d": _c(66, 26, 72),
		"Y": _c(255, 206, 44), "y": _c(214, 140, 22), "W": _c(255, 250, 222), "O": _c(244, 150, 72),
	}
	var rim := _c(66, 58, 94)
	var outline := _c(9, 7, 14)
	# 프레임: [다리 L 오프셋, 다리 R 오프셋, 망토 꼬리 dy, 눈 감음]
	var specs := [
		[Vector2i(0, 0), Vector2i(0, 0), 0, false],     # 0 idle
		[Vector2i(1, -1), Vector2i(-1, 0), -1, false],  # 1 run
		[Vector2i(0, 0), Vector2i(0, 0), 0, false],     # 2 run (passing)
		[Vector2i(-1, 0), Vector2i(1, -1), -1, false],  # 3 run
		[Vector2i(0, 0), Vector2i(0, 0), 0, false],     # 4 run (passing)
		[Vector2i(1, -1), Vector2i(0, -1), 1, false],   # 5 jump (다리 접기, 망토 아래로)
		[Vector2i(-1, 0), Vector2i(1, 0), -2, false],   # 6 fall (다리 벌림, 망토 위로)
		[Vector2i(0, 0), Vector2i(1, 0), -1, true],     # 7 hurt
		[Vector2i(-2, -1), Vector2i(1, 0), -2, false],  # 8 dash / lunge
	]
	var frames: Array[Image] = []
	for s in specs:
		var grid: Array = []
		for r in CAT:
			var chars: Array = []
			for ch in (r as String):
				chars.append(ch)
			grid.append(chars)
		# 망토 꼬리 흔들기
		var cape_dy: int = s[2]
		if cape_dy != 0:
			var moved: Array = []
			for y in range(31, 38):
				for x in range(0, 10):
					if grid[y][x] != ".":
						moved.append([x, y, grid[y][x]])
						grid[y][x] = "."
			for m in moved:
				var ny: int = clampi(m[1] + cape_dy, 0, 39)
				grid[ny][m[0]] = m[2]
		# 다리 (3x2 두 개)
		var legs := [[15, s[0]], [20, s[1]]]
		for leg in legs:
			var off: Vector2i = leg[1]
			for ly in 2:
				for lx in 3:
					grid[38 + ly + off.y][leg[0] + lx + off.x] = "#"
		# 피격: 눈을 질끈 감는다
		if s[3]:
			for y in range(16, 19):
				for x in range(18, 28):
					if grid[y][x] in ["Y", "y", "W"]:
						grid[y][x] = "#"
			for x in range(19, 23):
				grid[17][x] = "y"
			grid[17][26] = "y"
		var rows: Array = []
		for g in grid:
			rows.append("".join(g))
		var img := _from_ascii(rows, pal, 1)
		# 좌상단 테두리 빛 — 어두운 배경에서도 검은 실루엣이 읽히게
		var src := img.duplicate() as Image
		for y in img.get_height():
			for x in img.get_width():
				if src.get_pixel(x, y).is_equal_approx(pal["#"]):
					if _px(src, x - 1, y).a <= 0.0 or _px(src, x, y - 1).a <= 0.0:
						img.set_pixel(x, y, rim)
		_outline(img, outline)
		frames.append(img)
	_save(_sheet(frames), "characters/player/player_body.png")

	# 검 (오른쪽을 향함, 손잡이 (1,2)가 회전축)
	var sword := _from_ascii([
		"...g................",
		"kk.gLLLLLLLLLLLLLL..",
		"kkkgSSSSSSSSSSSSSSSW",
		"kk.gssssssssssssss..",
		"...g................",
	], {
		"k": _c(30, 22, 40), "g": _c(96, 80, 122), "L": _c(214, 196, 236),
		"S": _c(132, 110, 160), "s": _c(58, 46, 78), "W": _c(255, 255, 255),
	}, 1)
	_outline(sword, outline)
	_save(sword, "characters/player/player_sword.png")


# ═══════════════════════════════ 잡몹 (공허 임프) ═══════════════════════════════
func _gen_grunt() -> void:
	var specs := [
		{},                                                                   # 0 idle a
		{"sx": 1.05, "sy": 0.94, "dy": 0.6},                                  # 1 idle b
		{"f1": Vector2(1, -1), "f2": Vector2(-1, 0), "dy": -0.6},             # 2 walk
		{"f1": Vector2(0, 0), "f2": Vector2(0, 0)},                           # 3 walk
		{"f1": Vector2(-1, 0), "f2": Vector2(1, -1), "dy": -0.6},             # 4 walk
		{"f1": Vector2(0, 0), "f2": Vector2(0, 0)},                           # 5 walk
		{"sx": 1.14, "sy": 0.84, "dy": 1.2, "eyes": "angry"},                 # 6 windup (웅크림)
		{"sx": 1.18, "sy": 0.9, "dx": 1.5, "eyes": "angry", "mouth": "open",
				"f1": Vector2(-2, 0), "f2": Vector2(1, -1)},                  # 7 lunge (물기)
		{"sx": 0.92, "sy": 1.06, "eyes": "x", "mouth": "small"},              # 8 hurt
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_grunt_frame(s))
	_save(_sheet(frames), "characters/grunt/grunt.png")


func _grunt_frame(p: Dictionary) -> Image:
	var img := _new(30, 26)
	var base := _c(44, 30, 64)
	var top := _c(70, 48, 98)
	var dark := _c(26, 17, 40)
	var horn := _c(150, 112, 170)
	var horn_d := _c(92, 64, 112)
	var foot := _c(22, 14, 32)
	var eye := _c(255, 214, 60)
	var eye_d := _c(232, 128, 30)
	var mouth := _c(70, 10, 28)
	var tooth := _c(240, 232, 214)
	var sx: float = p.get("sx", 1.0)
	var sy: float = p.get("sy", 1.0)
	var cx: float = 15.0 + p.get("dx", 0.0)
	var ground := 24.0
	var rx := 9.5 * sx
	var ry := 7.6 * sy
	var cy: float = ground - 1.5 - ry + p.get("dy", 0.0)
	var f1: Vector2 = p.get("f1", Vector2.ZERO)
	var f2: Vector2 = p.get("f2", Vector2.ZERO)

	# 뿔 (몸 뒤에)
	_poly(img, PackedVector2Array([Vector2(cx - 6, cy - ry + 3), Vector2(cx - 10, cy - ry - 4),
			Vector2(cx - 7.5, cy - ry - 0.5), Vector2(cx - 2.5, cy - ry + 1.5)]), horn_d)
	_poly(img, PackedVector2Array([Vector2(cx + 3, cy - ry + 1.5), Vector2(cx + 8, cy - ry - 4),
			Vector2(cx + 7, cy - ry + 0.5), Vector2(cx + 7, cy - ry + 3)]), horn)
	# 발
	_ellipse(img, cx - 4 + f1.x, ground - 1.0 + f1.y, 2.6, 1.7, foot)
	_ellipse(img, cx + 4 + f2.x, ground - 1.0 + f2.y, 2.6, 1.7, foot)
	# 몸통 (위는 밝고 아래는 어둡게)
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var c := base
			if ny < -0.5 + nx * 0.2:
				c = top
			elif ny > 0.45:
				c = dark
			_put(img, x, y, c)
	# 등줄기 가시
	for i in 3:
		var bx := cx - 6.0 + i * 3.0
		var by := cy - ry * sqrt(maxf(1.0 - pow((bx - cx) / rx, 2.0), 0.0))
		_put(img, int(bx), int(by) - 1, top.lightened(0.15))
	# 눈 (오른쪽을 본다)
	var ex := int(cx + 1.0)
	var ey := int(cy - 1.0)
	match p.get("eyes", "open"):
		"x":
			for e in [ex, ex + 5]:
				_put(img, e - 1, ey - 1, eye); _put(img, e + 1, ey - 1, eye)
				_put(img, e, ey, eye)
				_put(img, e - 1, ey + 1, eye); _put(img, e + 1, ey + 1, eye)
		"angry":
			for e in [ex, ex + 5]:
				_rect(img, e - 1, ey, 3, 2, eye)
				_put(img, e - 1, ey + 1, eye_d); _put(img, e + 1, ey + 1, eye_d)
			_put(img, ex - 1, ey - 1, dark); _put(img, ex, ey - 1, dark)
			_put(img, ex + 5, ey - 1, dark); _put(img, ex + 6, ey - 1, dark)
			_put(img, ex + 1, ey, dark); _put(img, ex + 4, ey, dark)
		_:
			for e in [ex, ex + 5]:
				_rect(img, e - 1, ey - 1, 2, 3, eye)
				_put(img, e - 1, ey + 1, eye_d); _put(img, e, ey + 1, eye_d)
				_put(img, e - 1, ey - 1, Color(1, 1, 0.9))
	# 입
	var my := int(cy + 3.0)
	match p.get("mouth", "closed"):
		"open":
			_rect(img, ex - 1, my - 1, 8, 4, mouth)
			for i in 4:
				_put(img, ex - 1 + i * 2, my - 1, tooth)
				_put(img, ex + i * 2, my + 2, tooth)
		"small":
			_rect(img, ex + 1, my, 3, 2, mouth)
		_:
			for i in 5:
				_put(img, ex + i, my + (1 if i % 2 == 0 else 0), dark)
	_shade_edges(img, 0.18, 0.2, [eye, eye_d, tooth])
	_outline(img, _c(8, 5, 14))
	return img


# ═══════════════════════════════ 듀얼리스트 (망토 검사) ═══════════════════════════════
## 손(칼 회전축) 위치는 duelist.gd의 HAND 표와 맞춘다 (crouch/lean에 따라 이동).
func _gen_duelist() -> void:
	var specs := [
		{},                                                     # 0 idle a
		{"breath": 1, "flutter": 1.0},                          # 1 idle b
		{"stride": 3.0, "bob": -1, "flutter": 1.5},             # 2 walk
		{"stride": 0.0, "flutter": 0.5},                        # 3 walk
		{"stride": -3.0, "bob": -1, "flutter": 1.5},            # 4 walk
		{"stride": 0.0, "flutter": 0.5},                        # 5 walk
		{"crouch": 3, "lean": -2.5, "stride": 3.5, "flutter": 0.0},          # 6 windup (몸을 낮추고 뒤로 젖힘)
		{"crouch": 2, "lean": 4.0, "stride": 6.0, "flutter": 3.0},           # 7 strike (앞으로 내딛음)
		{"crouch": 1, "lean": -4.0, "stride": -2.0, "flutter": 2.0, "eye": 0.35},  # 8 stagger
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_duelist_frame(s))
	_save(_sheet(frames), "characters/duelist/duelist.png")

	var blade := _from_ascii([
		"...g..........................",
		"hhhgBBBBBBBBBBBBBBBBBBBBBBBB..",
		"hhhgSSSSSSSSSSSSSSSSSSSSSSSSSE",
		"hhhgssssssssssssssssssssssss..",
		"...g..........................",
	], {
		"h": _c(70, 22, 36), "g": _c(186, 146, 70), "B": _c(240, 242, 255),
		"S": _c(178, 182, 202), "s": _c(96, 100, 122), "E": _c(255, 255, 255),
	}, 1)
	_outline(blade, _c(10, 5, 10))
	_save(blade, "characters/duelist/duelist_blade.png")


func _duelist_frame(p: Dictionary) -> Image:
	var img := _new(36, 44)
	var cloak := _c(58, 22, 38)
	var cloak_d := _c(36, 13, 24)
	var trim := _c(150, 30, 48)
	var hood := _c(46, 18, 32)
	var face := _c(8, 4, 10)
	var leg := _c(26, 14, 22)
	var boot := _c(40, 24, 32)
	var scarf := _c(170, 36, 52)
	var eye_on: float = p.get("eye", 1.0)
	var eye := Color(1.0, 0.2, 0.26).lerp(_c(80, 20, 30), 1.0 - eye_on)
	var crouch: float = p.get("crouch", 0) + p.get("breath", 0) * 0.5
	var lean: float = p.get("lean", 0.0)
	var stride: float = p.get("stride", 0.0)
	var flutter: float = p.get("flutter", 0.0)
	var bob: float = p.get("bob", 0)
	var ground := 42.0
	var cx := 17.0
	var hip_y := 30.0 + crouch + bob
	# 기울임: 엉덩이 위쪽 점일수록 lean만큼 앞으로 민다.
	var sh := func(v: Vector2) -> Vector2:
		var y := v.y + crouch + bob
		var t := clampf((hip_y - y) / 26.0, 0.0, 1.0)
		return Vector2(v.x + lean * t, y)

	# 스카프 꼬리 (가장 뒤)
	var n: Vector2 = sh.call(Vector2(cx - 4, 14))
	_poly(img, PackedVector2Array([n, n + Vector2(-8 - flutter, 1 - flutter),
			n + Vector2(-10 - flutter * 1.5, 1.5 - flutter * 0.6), n + Vector2(-5, 3), n + Vector2(1, 2.5)]), scarf)
	_poly(img, PackedVector2Array([n + Vector2(0, 2), n + Vector2(-6 - flutter, 4 - flutter * 0.4),
			n + Vector2(-7 - flutter, 5.5 - flutter * 0.3), n + Vector2(1, 4)]), scarf.darkened(0.3))
	# 다리
	var back_foot := Vector2(cx - 2 - stride, ground - 1)
	var front_foot := Vector2(cx + 3 + stride, ground - 1)
	_line(img, Vector2(cx - 1, hip_y), back_foot, 3.2, leg.darkened(0.25))
	_line(img, Vector2(cx + 2, hip_y), front_foot, 3.2, leg)
	_rect(img, int(back_foot.x) - 2, int(ground) - 2, 5, 2, boot.darkened(0.25))
	_rect(img, int(front_foot.x) - 1, int(ground) - 2, 5, 2, boot)
	# 망토 몸통 (밑단은 너덜너덜)
	var body := PackedVector2Array()
	body.append(sh.call(Vector2(cx - 6, 13)))
	body.append(sh.call(Vector2(cx + 5, 13)))
	body.append(sh.call(Vector2(cx + 7, 22)))
	var hem := [Vector2(cx + 8, 33), Vector2(cx + 6, 31), Vector2(cx + 4, 34), Vector2(cx + 1, 31),
			Vector2(cx - 2, 34), Vector2(cx - 5, 31), Vector2(cx - 8 - flutter, 34 - flutter * 0.5),
			Vector2(cx - 8 - flutter * 0.5, 28)]
	for h in hem:
		body.append(sh.call(h))
	body.append(sh.call(Vector2(cx - 8, 20)))
	_poly(img, body, cloak)
	# 망토 뒤쪽 그늘
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.is_equal_approx(cloak):
				var front: Vector2 = sh.call(Vector2(cx, y - crouch - bob))
				if x < front.x - 3:
					img.set_pixel(x, y, cloak_d)
	# 앞섶 장식선
	for y in range(15, 31):
		var a: Vector2 = sh.call(Vector2(cx + 3, y))
		_put(img, int(a.x), int(a.y), trim)
	# 두건
	var hc: Vector2 = sh.call(Vector2(cx + 1, 8))
	_ellipse(img, hc.x, hc.y, 6.2, 6.6, hood)
	_poly(img, PackedVector2Array([hc + Vector2(-5, -3), hc + Vector2(-9, -7), hc + Vector2(-2, -6)]), hood)
	# 얼굴 그림자 + 붉은 외눈
	_ellipse(img, hc.x + 2.2, hc.y + 1.0, 3.6, 3.8, face)
	_rect(img, int(hc.x + 2.5), int(hc.y + 0.5), 2, 1, eye)
	if eye_on > 0.6:
		_put(img, int(hc.x + 3.5), int(hc.y + 0.5), Color(1, 0.75, 0.75))
	# 어깨 망토 (두건 아래 짧은 케이프)
	var s0: Vector2 = sh.call(Vector2(cx - 7, 14))
	var s1: Vector2 = sh.call(Vector2(cx + 6, 14))
	_poly(img, PackedVector2Array([s0 + Vector2(1, -1), s1 + Vector2(-1, -1), s1 + Vector2(1, 4),
			s0 + Vector2(-1, 5)]), trim.darkened(0.35))
	_shade_edges(img, 0.22, 0.25, [eye, face, Color(1, 0.75, 0.75)])
	_outline(img, _c(8, 3, 8))
	return img


# ═══════════════════════════════ 방 (달빛 성소) ═══════════════════════════════
# 월드 좌표 ↔ 셀: 셀 1개 = 2px. 뒷벽은 x[-1000,1000], y[-800,0] 영역.
const WALL_W := 1000
const WALL_H := 400
const WINDOWS := [290, 500, 710]          # 창문 중심 셀 x (월드 -420, 0, 420)
const PILLARS := [185, 395, 605, 815]     # 기둥 중심 셀 x (월드 ±630, ±210)


func _gen_room() -> void:
	_gen_backwall()
	_gen_sky()
	_gen_floor()
	_gen_side_wall()
	_gen_ledge()


func _stone(base: Color, var_amt: float) -> Color:
	var v := rng.randf_range(-var_amt, var_amt)
	var h := rng.randf_range(-0.01, 0.01)
	return Color(base.r + v + h, base.g + v, base.b + v - h)


func _brick_field(img: Image, x0: int, y0: int, w: int, h: int, row_h: int, wmin: int, wmax: int,
		base: Color, mortar: Color, crack_chance: float) -> void:
	var y := y0
	while y < y0 + h:
		var x := x0 - rng.randi_range(0, wmax)
		while x < x0 + w:
			var bw := rng.randi_range(wmin, wmax)
			_brick(img, x, y, bw, row_h, _stone(base, 0.018), mortar, crack_chance, Rect2i(x0, y0, w, h))
			x += bw
		y += row_h


func _brick(img: Image, x: int, y: int, w: int, h: int, c: Color, mortar: Color, crack_chance: float,
		clip: Rect2i) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if not clip.has_point(Vector2i(xx, yy)):
				continue
			var col := c
			if yy == y or xx == x:
				col = mortar
			elif yy == y + 1:
				col = c.lightened(0.12)
			elif xx == x + 1:
				col = c.lightened(0.05)
			elif yy == y + h - 1 or xx == x + w - 1:
				col = c.darkened(0.18)
			else:
				var nv := rng.randf_range(-0.012, 0.012)
				col = Color(c.r + nv, c.g + nv, c.b + nv)
				if rng.randf() < 0.03:
					col = col.darkened(0.12)
			_put(img, xx, yy, col)
	# 깨진 모서리
	if rng.randf() < 0.12 and clip.has_point(Vector2i(x + 1, y + 1)):
		_rect(img, x + 1, y + 1, 2, 2, mortar)
	# 금
	if rng.randf() < crack_chance:
		var p := Vector2i(x + rng.randi_range(3, maxi(w - 4, 4)), y + 2)
		for i in rng.randi_range(4, 9):
			if clip.has_point(p) and p.x > x + 1 and p.x < x + w - 1 and p.y < y + h - 1:
				_put(img, p.x, p.y, c.darkened(0.35))
			p += Vector2i(rng.randi_range(-1, 1), 1)


func _window_hole(x: int, y: int, wx: int) -> bool:
	var half := 28
	if x < wx - half or x > wx + half - 1:
		return false
	if y >= 150 and y <= 270:
		return true
	if y < 150:
		return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(wx, 150)) <= half
	return false


func _gen_backwall() -> void:
	var img := _new(WALL_W, WALL_H)
	var mortar := _c(22, 22, 34)
	_brick_field(img, 0, 0, WALL_W, WALL_H, 12, 18, 32, _c(48, 50, 72), mortar, 0.07)

	# 아치형 천장(기둥 사이) — 아치 위는 어두운 볼트, 아치 띠는 밝은 돌
	var spans := [[0, PILLARS[0] - 14]]
	for i in PILLARS.size() - 1:
		spans.append([PILLARS[i] + 14, PILLARS[i + 1] - 14])
	spans.append([PILLARS[-1] + 14, WALL_W])
	for sp in spans:
		var a: int = sp[0]
		var b: int = sp[1]
		var mid := (a + b) * 0.5
		var half := (b - a) * 0.5
		for x in range(a, b):
			var t := (x + 0.5 - mid) / half
			var ya := 96.0 - 58.0 * sqrt(maxf(1.0 - t * t, 0.0))
			for y in range(0, 100):
				var c := img.get_pixel(x, y)
				if y < ya:
					img.set_pixel(x, y, c.darkened(0.45))
				elif y < ya + 5.0:
					var seg := int((atan2(y - 96.0, x - mid) + PI) * 18.0)
					var band := _c(78, 80, 108) if seg % 2 == 0 else _c(70, 72, 98)
					if y < ya + 1.0:
						band = band.lightened(0.18)
					elif y >= ya + 4.0:
						band = band.darkened(0.3)
					img.set_pixel(x, y, band)

	# 기둥 윗부분(아치 사이 천장)도 볼트 그늘에 묻는다
	for px in PILLARS:
		for x in range(px - 14, px + 14):
			for y in range(0, 84):
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.4))

	# 창문 (구멍 + 돌 틀 + 창살 + 창턱)
	for wx in WINDOWS:
		for y in range(110, 285):
			for x in range(wx - 36, wx + 36):
				if _window_hole(x, y, wx):
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var near := false
				for d in range(1, 5):
					if _window_hole(x - d, y, wx) or _window_hole(x + d, y, wx) or _window_hole(x, y + d, wx) \
							or _window_hole(x, y - d, wx):
						near = true
						break
				if near:
					var fc := _c(86, 88, 116)
					if _window_hole(x + 1, y, wx) or _window_hole(x, y + 1, wx):
						fc = fc.lightened(0.15)
					img.set_pixel(x, y, fc)
		# 창살
		for bx in [wx - 10, wx + 9]:
			for y in range(118, 271):
				if _window_hole(bx, y, wx):
					_put(img, bx, y, _c(16, 16, 24))
					_put(img, bx + 1, y, _c(40, 40, 54))
		for x in range(wx - 28, wx + 28):
			for y in [205, 206]:
				if _window_hole(x, y, wx):
					_put(img, x, y, _c(16, 16, 24) if y == 206 else _c(40, 40, 54))
		# 창턱
		_rect(img, wx - 34, 271, 68, 2, _c(110, 112, 140))
		_rect(img, wx - 34, 273, 68, 4, _c(70, 72, 96))
		_rect(img, wx - 33, 277, 66, 1, _c(30, 30, 44))

	# 기둥
	for px in PILLARS:
		for y in range(92, 392):
			for u in 28:
				var x: int = px - 14 + u
				var k := 1.0 - pow((u - 9.0) / 19.0, 2.0)
				var c := _c(54, 56, 80).lightened(k * 0.22)
				if u % 6 == 0:
					c = c.darkened(0.2)
				elif u % 6 == 1:
					c = c.lightened(0.06)
				if u >= 25:
					c = c.darkened(0.35)
				if (y - 92) % 40 == 0:
					c = c.darkened(0.15)
				img.set_pixel(x, y, c)
		# 주두(위)와 주춧돌(아래)
		for i in 3:
			var w := 36 - i * 3
			_rect(img, px - w / 2, 84 + i * 3, w, 3, _c(84, 86, 114).darkened(i * 0.08))
			_rect(img, px - w / 2, 84 + i * 3, w, 1, _c(110, 112, 142))
		for i in 3:
			var w := 30 + i * 3
			_rect(img, px - w / 2, 383 + i * 3, w, 3, _c(72, 74, 100).darkened(i * 0.06))
			_rect(img, px - w / 2, 383 + i * 3, w, 1, _c(100, 102, 132))

	# 걸레받이
	_rect(img, 0, 392, WALL_W, 8, _c(36, 36, 52))
	_rect(img, 0, 392, WALL_W, 1, _c(70, 72, 96))

	# 조명: 창문의 달빛(푸른 빛) + 천장/바닥 그늘
	for y in WALL_H:
		for x in WALL_W:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var moon := 0.0
			for wx in WINDOWS:
				var d := Vector2(x, y).distance_to(Vector2(wx, 220))
				moon += exp(-pow(d / 150.0, 2.0)) * 0.9
				var d2 := Vector2(x, y).distance_to(Vector2(wx + 70, 390))
				moon += exp(-pow(d2 / 110.0, 2.0)) * 0.35
			var shade := 0.72 + moon * 0.38
			if y < 100:
				shade *= lerpf(0.55, 1.0, y / 100.0)
			if y > 360:
				shade *= lerpf(1.0, 0.82, (y - 360) / 40.0)
			c = Color(c.r * shade, c.g * shade, c.b * shade)
			c = c.lerp(Color(0.55, 0.65, 0.95), clampf(moon * 0.12, 0.0, 0.25))
			img.set_pixel(x, y, c)
	_save(img, "environment/room_backwall.png")


func _gen_sky() -> void:
	# 1400x520px (월드 x[-700,700], y[-640,-120]) — 창문 너머로만 보인다.
	var w := 700
	var h := 260
	var img := _new(w, h)
	for y in h:
		var t := float(y) / h
		var c := Color(0.035, 0.045, 0.11).lerp(Color(0.17, 0.15, 0.32), pow(t, 1.3))
		for x in w:
			img.set_pixel(x, y, c)
	# 구름 띠
	for band in [[70, 0.06], [118, 0.05], [150, 0.07], [200, 0.05]]:
		var by: int = band[0]
		for x in w:
			var thick := 3.0 + 3.0 * sin(x * 0.031 + by) + 2.0 * sin(x * 0.07 + by * 0.3)
			for y in range(by, by + int(maxf(thick, 0.0))):
				if y < h:
					img.set_pixel(x, y, img.get_pixel(x, y).lightened(band[1]))
	# 별
	for i in 320:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, int(h * 0.8))
		var b := rng.randf_range(0.35, 1.0)
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.85, 0.88, 1.0), b))
		if b > 0.93:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_put(img, x + d.x, y + d.y, img.get_pixel(x, y).lerp(Color(0.8, 0.85, 1), 0.4))
	# 달 (가운데 창문 뒤)
	var mc := Vector2(350, 85)
	var mr := 21.0
	for y in range(int(mc.y - mr) - 1, int(mc.y + mr) + 2):
		for x in range(int(mc.x - mr) - 1, int(mc.x + mr) + 2):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(mc)
			if d > mr:
				continue
			var lit := Vector2(x + 0.5, y + 0.5).distance_to(mc + Vector2(-5, -5)) / (mr * 1.6)
			var c := Color(0.97, 0.96, 1.0).lerp(Color(0.72, 0.74, 0.9), clampf(lit, 0.0, 1.0))
			img.set_pixel(x, y, c)
	for cr in [[Vector2(343, 80), 4.0], [Vector2(357, 92), 3.0], [Vector2(352, 74), 2.0], [Vector2(340, 95), 2.5]]:
		var cc: Vector2 = cr[0]
		var rr: float = cr[1]
		for y in range(int(cc.y - rr), int(cc.y + rr) + 1):
			for x in range(int(cc.x - rr), int(cc.x + rr) + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(cc) <= rr:
					img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.12))
	_save(img, "environment/room_sky.png")


func _gen_floor() -> void:
	# 2000x200px (월드 x[-1000,1000], y[0,200])
	var w := 1000
	var h := 100
	var img := _new(w, h)
	_brick_field(img, 0, 9, w, h - 9, 18, 26, 44, _c(40, 40, 58), _c(16, 16, 24), 0.08)
	# 윗면(원근 느낌의 석판)
	var x := 0
	while x < w:
		var sw := rng.randi_range(30, 52)
		var c := _stone(_c(70, 70, 96), 0.02)
		for yy in range(2, 8):
			for xx in range(x, mini(x + sw, w)):
				var cc := c.darkened((yy - 2) * 0.05)
				if xx == x:
					cc = _c(30, 30, 44)
				_put(img, xx, yy, cc)
		x += sw
	_rect(img, 0, 0, w, 1, _c(150, 150, 186))
	_rect(img, 0, 1, w, 1, _c(104, 104, 136))
	_rect(img, 0, 8, w, 1, _c(14, 14, 22))
	# 아래로 갈수록 어둠 속으로
	for y in range(9, h):
		var k := clampf((y - 9) / 60.0, 0.0, 1.0)
		for xx in w:
			var c := img.get_pixel(xx, y)
			img.set_pixel(xx, y, c.darkened(k * 0.75))
	_save(img, "environment/room_floor.png")


func _gen_side_wall() -> void:
	# 200x840px — 왼쪽 벽 기준(오른쪽 면이 방 안쪽). 오른쪽 벽은 flip_h로 재사용.
	var w := 100
	var h := 420
	var img := _new(w, h)
	_brick_field(img, 0, 0, w, h, 16, 24, 40, _c(30, 30, 44), _c(12, 12, 18), 0.06)
	# 안쪽 모서리 기둥 띠
	for y in h:
		for u in 10:
			var xx := w - 10 + u
			var c := _c(64, 64, 88).lightened(0.12 if u < 2 else 0.0).darkened(u * 0.04)
			if y % 48 == 0:
				c = _c(20, 20, 30)
			img.set_pixel(xx, y, c)
	# 바깥쪽으로 갈수록 어둡게
	for y in h:
		for xx in w - 10:
			var c := img.get_pixel(xx, y)
			img.set_pixel(xx, y, c.darkened(clampf((w - 10 - xx) / 90.0, 0.0, 1.0) * 0.55))
	_save(img, "environment/room_side_wall.png")


func _gen_ledge() -> void:
	# 240x52px 석조 발판 (윗면이 텍스처 맨 위 = 충돌 윗면)
	var w := 120
	var h := 26
	var img := _new(w, h)
	_brick_field(img, 0, 5, w, 9, 9, 16, 26, _c(52, 52, 74), _c(20, 20, 30), 0.05)
	_rect(img, 0, 0, w, 1, _c(160, 160, 194))
	_rect(img, 0, 1, w, 1, _c(112, 112, 144))
	_rect(img, 0, 2, w, 3, _c(80, 80, 108))
	_rect(img, 0, 14, w, 1, _c(18, 18, 28))
	# 받침돌
	for cx in [18, 101]:
		for y in range(15, h):
			var half := int(lerpf(8.0, 2.0, (y - 15) / float(h - 15)))
			for xx in range(cx - half, cx + half):
				var c := _c(46, 46, 66).darkened((y - 15) * 0.03)
				if xx == cx - half:
					c = c.lightened(0.1)
				_put(img, xx, y, c)
	_save(img, "environment/ledge.png")


# ═══════════════════════════════ 소품 ═══════════════════════════════
func _gen_props() -> void:
	_gen_brazier()
	_gen_banner()
	_gen_chain()


func _gen_brazier() -> void:
	var iron := _c(42, 36, 52)
	var iron_l := _c(96, 86, 112)
	var coal := _c(255, 140, 50)
	var img := _new(24, 28)
	# 그릇
	for y in range(0, 8):
		var half := int(lerpf(11.0, 6.0, y / 7.0))
		for x in range(12 - half, 12 + half):
			_put(img, x, y, iron if y > 1 else iron_l)
	for x in range(2, 22):
		if x % 2 == 0:
			_put(img, x, 0, coal)
	_rect(img, 3, 3, 18, 1, iron_l.darkened(0.2))
	# 기둥 + 받침
	_rect(img, 10, 8, 4, 13, iron)
	_rect(img, 10, 8, 1, 13, iron_l)
	_rect(img, 8, 12, 8, 2, iron_l.darkened(0.15))
	_poly(img, PackedVector2Array([Vector2(12, 20), Vector2(20, 27), Vector2(17, 27), Vector2(12, 23),
			Vector2(7, 27), Vector2(4, 27)]), iron)
	_outline(img, _c(8, 6, 12))
	_save(img, "environment/brazier.png")

	# 불꽃 4프레임 (16x24)
	var frames: Array[Image] = []
	for f in 4:
		var fl := _new(16, 24)
		for y in 24:
			for x in 16:
				var hgt := 1.0 - y / 23.0                      # 0 바닥 → 1 꼭대기
				var sway := sin(hgt * 4.0 + f * 1.57) * 2.0 * hgt
				var width := 6.5 * pow(maxf(1.0 - hgt, 0.0), 0.55) * (0.9 + 0.1 * sin(f * 2.1 + hgt * 9.0))
				var dx := absf(x + 0.5 - (8.0 + sway))
				var dens := 1.0 - dx / maxf(width, 0.01)
				dens -= 0.18 * sin(x * 1.7 + y * 0.9 + f * 2.3)
				if dens <= 0.0:
					continue
				var c := _c(190, 40, 20)
				if dens > 0.75 and hgt < 0.55:
					c = _c(255, 246, 190)
				elif dens > 0.5:
					c = _c(255, 196, 70)
				elif dens > 0.25:
					c = _c(255, 120, 34)
				fl.set_pixel(x, y, c)
		frames.append(fl)
	_save(_sheet(frames), "environment/brazier_flame.png")


func _gen_banner() -> void:
	var w := 24
	var h := 84
	var img := _new(w, h)
	var cloth := _c(96, 40, 110)
	var gold := _c(176, 140, 74)
	# 막대
	_rect(img, 0, 0, w, 3, _c(40, 30, 30))
	_rect(img, 0, 0, w, 1, _c(110, 90, 70))
	for y in range(3, h):
		for x in range(2, w - 2):
			# 제비꼬리 밑단
			if y > h - 12 and absf(x + 0.5 - w * 0.5) < (y - (h - 12)) * 0.9:
				continue
			var fold := sin(x * 0.75) * 0.08
			var c := cloth.lightened(maxf(fold, 0.0)).darkened(maxf(-fold, 0.0) + (y / float(h)) * 0.25)
			if x == 2 or x == w - 3:
				c = gold
			_put(img, x, y, c)
	_rect(img, 2, 5, w - 4, 1, gold)
	# 문장: 초승달 + 고양이 눈
	var mc := Vector2(12, 32)
	for y in range(22, 44):
		for x in range(2, 22):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(mc) <= 7.5 and p.distance_to(mc + Vector2(3, -2)) > 6.0:
				_put(img, x, y, _c(240, 214, 130))
	_rect(img, 13, 31, 3, 2, _c(255, 206, 44))
	_outline(img, _c(16, 8, 20))
	_save(img, "environment/banner.png")


func _gen_chain() -> void:
	var w := 7
	var h := 220
	var img := _new(w, h)
	var iron := _c(38, 34, 48)
	var iron_l := _c(84, 78, 100)
	var y := 0
	var i := 0
	while y < h:
		if i % 2 == 0:
			_rect(img, 1, y, 5, 8, iron)
			_rect(img, 2, y + 2, 3, 4, Color(0, 0, 0, 0))
			_rect(img, 1, y, 1, 8, iron_l)
		else:
			_rect(img, 3, y, 2, 8, iron)
			_rect(img, 3, y, 1, 8, iron_l)
		y += 6
		i += 1
	_save(img, "environment/chain.png")


# ═══════════════════════════════ 이펙트 ═══════════════════════════════
func _gen_effects() -> void:
	_gen_void_orb()


## 장풍(공허 구체) — 4프레임 회전 시트. 지름 38 아트 픽셀 = 화면 76px (플레이어 키).
## 팔 두 개짜리 소용돌이라 45°씩 4프레임이면 반 바퀴 = 이음매 없이 반복된다.
func _gen_void_orb() -> void:
	var frames: Array[Image] = []
	for f in 4:
		frames.append(_void_orb_frame(f))
	_save(_sheet(frames), "effects/void_orb.png")


func _void_orb_frame(f: int) -> Image:
	var size := 40
	var img := _new(size, size)
	var cx := size * 0.5
	var cy := size * 0.5
	var r := 19.0
	var outline := _c(30, 10, 52)
	var rim := _c(196, 150, 255)
	var deep := _c(74, 32, 128)
	var mid := _c(112, 58, 184)
	var arm := _c(156, 100, 232)
	var arm_hot := _c(206, 168, 255)
	var core := _c(222, 196, 255)
	var hot := _c(255, 248, 255)
	var spin := f * PI / 4.0
	for y in size:
		for x in size:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				continue
			var c := deep if d > r * 0.62 else mid
			if d > r - 1.2:
				c = outline
			elif d > r - 2.6:
				c = rim
			else:
				# 소용돌이 팔: 각도 + 반지름에 따라 휘어진다
				var a := atan2(dy, dx)
				var w := sin(2.0 * (a - spin) + d * 0.34)
				if d > r * 0.28:
					if w > 0.82:
						c = arm_hot
					elif w > 0.45:
						c = arm
				if d < 7.6:
					c = core
				if d < 4.2:
					c = hot
			img.set_pixel(x, y, c)
	# 테두리 안쪽에서 반짝이는 점 몇 개 (프레임마다 다르게)
	for i in 5:
		var a := rng.randf() * TAU
		var dd := rng.randf_range(r * 0.5, r - 3.0)
		_put(img, int(cx + cos(a) * dd), int(cy + sin(a) * dd), hot)
	return img


# ═══════════════════════════════ 감시자 (공중 원거리 중간 보스 — 공허의 감시자) ═══════════════════════════════
## 잡몹보다 한 급 위의 위엄: 금장 테두리 갑각, 금빛 가시 왕관 + 떠 있는 후광, 두 쌍의 칼날깃 날개,
## 큰 외눈 주위의 작은 눈 넷, 아래로 늘어진 척추 꼬리와 보석. 프레임 순서는 watcher.gd의 Frame enum과 맞춘다.
## 캔버스 72x60, 큰 눈의 중심 = (36, 27) → 씬에서 Body를 (0, 6)에 두면 눈이 루트 원점에 온다.
func _gen_watcher() -> void:
	var specs := [
		{"wing": 0},                              # 0 idle a (날개 위)
		{"wing": 1, "dy": 1},                     # 1 idle b (날개 아래)
		{"wing": 0, "eye": "aim"},                # 2 조준 (눈을 가늘게, 붉게)
		{"wing": 1, "eye": "wide", "dx": -1},     # 3 발사 반동
		{"wing": 2, "eye": "charge"},             # 4 카유공 충전 (날개 활짝, 온몸의 눈이 빛남)
		{"wing": 1, "eye": "x", "dy": 1},         # 5 피격
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_watcher_frame(s))
	_save(_sheet(frames), "characters/watcher/watcher.png")


func _watcher_frame(p: Dictionary) -> Image:
	var img := _new(72, 60)
	var shell := _c(52, 32, 76)
	var shell_top := _c(82, 54, 112)
	var shell_dark := _c(28, 16, 42)
	var socket := _c(18, 8, 24)
	var wing := _c(54, 24, 80)
	var wing_edge := _c(112, 72, 156)
	var gold := _c(226, 176, 72)
	var gold_d := _c(150, 98, 40)
	var bone := _c(198, 176, 150)
	var gem := _c(236, 70, 90)
	var sclera := _c(236, 226, 204)
	var iris := _c(255, 206, 60)
	var iris_d := _c(222, 120, 30)
	var pupil := _c(20, 8, 24)
	var hot := _c(255, 244, 196)
	var eye_mode: String = p.get("eye", "open")
	var cx: float = 36.0 + p.get("dx", 0.0)
	var cy: float = 27.0 + p.get("dy", 0.0)
	var w: int = p.get("wing", 0)

	# ── 척추 꼬리 + 보석 (가장 뒤)
	var sway := 1.0 if w == 1 else -1.0
	var prev := Vector2(cx, cy + 10.0)
	for k in 6:
		var q := Vector2(cx + sin(k * 0.9) * 1.2 * sway, cy + 12.0 + k * 2.4)
		_line(img, prev, q, 2.0, bone.darkened(0.25))
		_ellipse(img, q.x, q.y, 2.0 - k * 0.18, 1.3, bone)
		prev = q
	_poly(img, PackedVector2Array([prev + Vector2(0, 1), prev + Vector2(2.5, 4), prev + Vector2(0, 8), prev + Vector2(-2.5, 4)]), gem)
	_put(img, int(prev.x), int(prev.y + 3), Color(1, 0.8, 0.85))
	# 옆 촉수 (금 고리)
	for side in [-1.0, 1.0]:
		var a := Vector2(cx + side * 7.0, cy + 8.0)
		var b := Vector2(cx + side * 9.5 - sway * side, cy + 19.0)
		var c := Vector2(cx + side * 8.0 + sway * 0.5, cy + 26.0)
		_line(img, a, b, 1.6, shell_dark)
		_line(img, b, c, 1.1, shell_dark)
		_put(img, int(b.x), int(b.y), gold)
		_put(img, int(b.x) + 1, int(b.y), gold_d)

	# ── 날개: 위 3장(큰 칼날깃) + 아래 2장(작은 깃)
	var upper := [[-58.0, -34.0, -10.0], [-24.0, -4.0, 16.0], [-44.0, -20.0, 4.0]]
	var lower := [[24.0, 44.0], [36.0, 58.0], [28.0, 50.0]]
	var lens := [21.0, 24.0, 17.0]
	for side in [-1.0, 1.0]:
		for i in 2:
			_feather(img, Vector2(cx + side * 9.0, cy + 4.0), lower[w][i], 11.0 - i * 2.0, side, wing, wing_edge, gold, 2.2)
		for i in 3:
			_feather(img, Vector2(cx + side * 10.0, cy - 3.0 + i * 1.5), upper[w][i], lens[i], side, wing, wing_edge, gold, 3.2)

	# ── 후광 (떠 있는 금빛 고리) + 가시 왕관
	for y in range(int(cy - 26), int(cy - 15)):
		for x in range(int(cx - 13), int(cx + 14)):
			var nx := (x + 0.5 - cx) / 11.0
			var ny := (y + 0.5 - (cy - 20.5)) / 3.0
			var d := nx * nx + ny * ny
			if d <= 1.0 and d >= 0.45:
				_put(img, x, y, gold if ny < 0.0 else gold_d)
	var spikes := [[0.0, 11.0], [-24.0, 8.5], [24.0, 8.5], [-46.0, 6.0], [46.0, 6.0]]
	for sp in spikes:
		var ang := deg_to_rad(-90.0 + float(sp[0]))
		var dir := Vector2.from_angle(ang)
		var root := Vector2(cx, cy) + dir * 9.5
		var n := dir.orthogonal()
		_poly(img, PackedVector2Array([root + n * 1.8, root + dir * float(sp[1]), root - n * 1.8]), gold)
		_line(img, root + n * 0.8, root + dir * (float(sp[1]) - 1.5), 0.8, gold_d)

	# ── 갑각 몸통 (위는 밝고 아래는 어둡게)
	var rx := 12.0
	var ry := 11.0
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var c := shell
			if ny < -0.45 + nx * 0.2:
				c = shell_top
			elif ny > 0.5:
				c = shell_dark
			_put(img, x, y, c)
	# 갑각 판 이음새
	for side in [-1.0, 1.0]:
		_line(img, Vector2(cx + side * 9.5, cy - 6.0), Vector2(cx + side * 11.0, cy + 3.0), 0.8, shell_dark)
	_line(img, Vector2(cx - 4.0, cy + 9.0), Vector2(cx + 4.0, cy + 9.0), 0.8, shell_dark)
	# 금장 테두리 (눈구멍 둘레)
	for y in range(int(cy - 9), int(cy + 10)):
		for x in range(int(cx - 10), int(cx + 11)):
			var nx := (x + 0.5 - cx) / 8.6
			var ny := (y + 0.5 - cy) / 7.4
			var d := nx * nx + ny * ny
			if d <= 1.0 and d >= 0.66:
				_put(img, x, y, gold if ny < 0.15 else gold_d)
	_ellipse(img, cx, cy, 6.8, 5.6, socket)

	# ── 작은 눈 넷
	var small_col := _c(255, 110, 80) if eye_mode == "aim" else (hot if eye_mode == "charge" else _c(214, 90, 70))
	if eye_mode == "x":
		small_col = shell_dark
	for se in [Vector2(-9, -6), Vector2(9, -6), Vector2(-10, 4), Vector2(10, 4)]:
		_rect(img, int(cx + se.x) - 1, int(cy + se.y), 2, 1, small_col)

	# ── 큰 외눈
	var ex := cx
	var ey := cy
	match eye_mode:
		"aim":
			_ellipse(img, ex, ey, 6.0, 2.0, sclera)
			_rect(img, int(ex) - 2, int(ey) - 1, 5, 2, _c(255, 90, 56))
			_rect(img, int(ex) - 7, int(ey) - 3, 14, 1, gold_d)
		"wide":
			_ellipse(img, ex, ey, 6.4, 5.4, sclera)
			_ellipse(img, ex + 0.5, ey, 2.8, 2.8, iris)
			_rect(img, int(ex), int(ey), 1, 1, pupil)
		"charge":
			_ellipse(img, ex, ey, 6.4, 5.4, _c(255, 228, 150))
			_ellipse(img, ex, ey, 4.2, 3.6, hot)
			_ellipse(img, ex, ey, 2.0, 2.0, Color(1, 1, 1))
		"x":
			for k in range(-4, 5):
				_put(img, int(ex) + k, int(ey) + k, iris)
				_put(img, int(ex) + k, int(ey) - k, iris)
		_:
			_ellipse(img, ex, ey, 6.0, 4.8, sclera)
			_ellipse(img, ex + 0.5, ey, 3.6, 4.0, iris)
			_ellipse(img, ex + 1.0, ey + 1.5, 2.2, 1.5, iris_d)
			_rect(img, int(ex), int(ey) - 3, 1, 6, pupil)
			_put(img, int(ex) - 2, int(ey) - 2, Color(1, 1, 0.94))
			_put(img, int(ex) - 1, int(ey) - 3, Color(1, 1, 0.94))
	_shade_edges(img, 0.16, 0.22, [sclera, iris, iris_d, pupil, gold, gold_d, gem, hot, small_col, socket,
			_c(255, 228, 150), _c(255, 90, 56), Color(1, 1, 1), Color(1, 1, 0.94)])
	_outline(img, _c(8, 4, 14))
	return img


## 칼날깃 하나: root에서 angle_deg 방향(오른쪽 기준, side로 좌우 반전)으로 뻗는 날 모양 깃. 끝은 금빛.
func _feather(img: Image, root: Vector2, angle_deg: float, length: float, side: float,
		body: Color, edge: Color, tip: Color, width: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	dir.x *= side
	var n := dir.orthogonal()
	var end := root + dir * length
	var pts := PackedVector2Array([root + n * width * 0.6, root + dir * length * 0.55 + n * width,
			end, root + dir * length * 0.5 - n * width * 0.5, root - n * width * 0.4])
	_poly(img, pts, body)
	_line(img, root + n * width * 0.4, end, 0.9, edge)
	_line(img, root + dir * (length - 3.0), end, 1.2, tip)
