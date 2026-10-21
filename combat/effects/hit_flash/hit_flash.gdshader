shader_type canvas_item;

// 액터 Visual 전체를 한 색으로 덮는 번쩍임 (피격 / 반짝임 / 경직 표시).
// 아주 어두운 픽셀아트는 modulate를 키워도 밝아지지 않으므로 색을 섞어서(mix) 칠한다.
// Visual 노드에 이 머티리얼을 두고 자식 Sprite2D는 use_parent_material로 공유한다.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
