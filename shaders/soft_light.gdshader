shader_type spatial;
// 柔光片：地面光池 / 窗光柱共用一个着色器，按 UV 算衰减，不依赖贴图。
// 用加法混合，黑色等于不添加；用着色器算的原因见 docs/environment-hd2d.md。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.2;
uniform int shape : hint_range(0, 1) = 0;   // 0 = 径向（光池），1 = 竖直线性（光柱）
uniform float softness : hint_range(0.1, 1.0) = 0.45;

void fragment() {
	float falloff = 0.0;
	if (shape == 0) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		falloff = smoothstep(1.0, softness, r);
	} else {
		falloff = smoothstep(1.0, 0.0, UV.y) * smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	}
	ALBEDO = tint.rgb * intensity * falloff;
	ALPHA = 1.0;
}
