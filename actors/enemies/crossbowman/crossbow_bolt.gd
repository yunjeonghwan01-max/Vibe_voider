class_name CrossbowBolt
extends WatcherNeedle

## 석궁병의 은빛 볼트 — 수평으로 곧게 날아가는 실제 투사체 (PRCI 대상).
## 비행·충돌·피격·튕겨내기는 WatcherNeedle을 그대로 쓴다: "deflectable" 그룹, 플레이어에게 deflect_range 안으로
## 다가오는 짧은 순간에만 금빛으로 빛나고(is_deflectable), 그때 반격 키를 누르면 Player가 deflect()로 지운다.
## (Player는 튕겨낼 대상을 WatcherNeedle 타입으로 찾으므로, 상속해서 기존 PRCI 경로를 그대로 탄다.)
## 수치는 스폰하는 석궁병이 add_child 전에 채운다 (crossbowman_tuning.cfg) — 이 씬에는 수치 파일이 없다.

const SHAFT_BACK := -18.0
const HEAD_TIP := 14.0


func _draw() -> void:
	# 뒤로 끌리는 옅은 잔광 → 초록 깃 → 은빛 몸대 → 뾰족한 촉
	draw_line(Vector2(SHAFT_BACK - 26.0, 0.0), Vector2(SHAFT_BACK, 0.0), Color(0.85, 0.95, 1.0, 0.18), 3.0)
	if _glint:
		var pop := 1.0 + 0.5 * maxf(1.0 - _glint_t * 25.0, 0.0)
		draw_circle(Vector2(4.0, 0.0), 15.0 * pop, Color(1.0, 0.93, 0.58, 0.28))
		draw_arc(Vector2(4.0, 0.0), 11.0 * pop, 0.0, TAU, 24, Color(1.0, 0.93, 0.58, 0.85), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(SHAFT_BACK, 0.0), Vector2(SHAFT_BACK - 5.0, -4.0),
			Vector2(SHAFT_BACK + 5.0, 0.0), Vector2(SHAFT_BACK - 5.0, 4.0)]), Color(0.3, 0.62, 0.42))
	draw_line(Vector2(SHAFT_BACK, 0.0), Vector2(7.0, 0.0), Color(0.08, 0.08, 0.1), 4.0)
	draw_line(Vector2(SHAFT_BACK, 0.0), Vector2(7.0, 0.0), Color(0.78, 0.82, 0.88), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(6.0, -4.0), Vector2(HEAD_TIP, 0.0), Vector2(6.0, 4.0)]), Color(0.92, 0.95, 1.0))
	draw_line(Vector2(6.0, 0.0), Vector2(HEAD_TIP, 0.0), Color(0.62, 0.66, 0.74), 1.0)
