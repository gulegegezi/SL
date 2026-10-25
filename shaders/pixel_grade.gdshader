shader_type canvas_item;
render_mode unshaded;
// HD-2D 后处理：倾斜移轴景深 + 泛光 + 冷暖分级 + 暗角 + 底部薄雾。
// 参考：《八方旅人》的移轴景深与聚光、《风来之国》的暖灯冷影、《旅行青蛙》的低对比柔光。
// 只作用在分镜的场景视口上，对话框与按钮不经过这里。

uniform sampler2D scene_color : hint_screen_texture, filter_nearest, repeat_disable;

uniform float strength : hint_range(0.0, 1.0) = 0.72;      // 总强度
uniform float dof_strength : hint_range(0.0, 1.0) = 0.55;  // 移轴虚化
uniform float focus_center : hint_range(0.0, 1.0) = 0.56;  // 清晰带中心（0=顶 1=底）
uniform float focus_width : hint_range(0.02, 0.6) = 0.22;  // 清晰带半宽
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.32; // 泛光
uniform float bloom_threshold : hint_range(0.3, 1.0) = 0.66;
uniform float vignette : hint_range(0.0, 1.0) = 0.30;      // 暗角
uniform float warm_cast : hint_range(-1.0, 1.0) = 0.30;    // 正=偏暖 负=偏冷
uniform float haze : hint_range(0.0, 1.0) = 0.10;          // 底部薄雾
uniform vec3 haze_color : source_color = vec3(0.145, 0.247, 0.286);

float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// 8 点环形采样，半径以视口像素计：小分辨率下也够用
vec3 ring_blur(vec2 uv, float radius, vec2 texel) {
	vec2 t = texel * radius;
	vec3 sum = texture(scene_color, uv).rgb * 0.24;
	sum += texture(scene_color, uv + vec2( t.x,  0.0)).rgb * 0.11;
	sum += texture(scene_color, uv + vec2(-t.x,  0.0)).rgb * 0.11;
	sum += texture(scene_color, uv + vec2( 0.0,  t.y)).rgb * 0.11;
	sum += texture(scene_color, uv + vec2( 0.0, -t.y)).rgb * 0.11;
	sum += texture(scene_color, uv + vec2( t.x,  t.y)).rgb * 0.08;
	sum += texture(scene_color, uv + vec2(-t.x,  t.y)).rgb * 0.08;
	sum += texture(scene_color, uv + vec2( t.x, -t.y)).rgb * 0.08;
	sum += texture(scene_color, uv + vec2(-t.x, -t.y)).rgb * 0.08;
	return sum;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 t = SCREEN_PIXEL_SIZE;
	vec3 c = texture(scene_color, uv).rgb;
	float light = luminance(c);

	// ---- 倾斜移轴：离清晰带越远越虚（八方旅人的地台式景深）----
	float dist = abs(uv.y - focus_center) / max(focus_width, 0.001);
	float blur_amount = smoothstep(0.55, 1.65, dist) * dof_strength;
	vec3 color = c;
	if (blur_amount > 0.002) {
		// 越远越虚：半径随偏离量增长，别只做固定 1.35px（那在 250px 视口里几乎看不见）
		color = mix(c, ring_blur(uv, 1.2 + 1.9 * blur_amount, t), blur_amount);
	}

	// ---- 泛光：亮部单独提出来再模糊一圈（暖灯的溢光）----
	vec3 bright = max(color - vec3(bloom_threshold), vec3(0.0));
	float bright_lum = luminance(bright);
	vec3 bloom = ring_blur(uv, 2.6, t) * vec3(1.0, 0.92, 0.78);
	color += bloom * bloom_strength * smoothstep(0.0, 0.25, bright_lum);

	// ---- 明暗分级 + 冷暖分离：阴影偏青，亮部偏琥珀 ----
	float lum2 = luminance(color);
	float band = floor(lum2 * 9.0 + 0.5) / 9.0;
	vec3 graded = color * (mix(lum2, band, 0.32) / max(lum2, 0.015));
	float shadow_w = 1.0 - smoothstep(0.06, 0.46, lum2);
	float light_w = smoothstep(0.48, 0.96, lum2);
	graded += vec3(-0.014, 0.006, 0.026) * shadow_w * (1.0 - warm_cast * 0.5);
	graded += vec3(0.030, 0.014, -0.020) * light_w * (0.5 + warm_cast);

	// ---- 边缘压暗：让方块场景多一层「看得见的轮廓」----
	float n = max(max(luminance(texture(scene_color, uv + vec2(t.x, 0.0)).rgb),
	                  luminance(texture(scene_color, uv + vec2(-t.x, 0.0)).rgb)),
	              max(luminance(texture(scene_color, uv + vec2(0.0, t.y)).rgb),
	                  luminance(texture(scene_color, uv + vec2(0.0, -t.y)).rgb)));
	graded *= 1.0 - smoothstep(0.10, 0.34, n - lum2) * 0.18;

	// ---- 底部薄雾：远近分层 ----
	float haze_w = smoothstep(0.55, 1.05, uv.y) * haze;
	graded = mix(graded, haze_color, haze_w);

	// ---- 暗角：低对比柔光（旅行青蛙的温和边缘）----
	vec2 q = uv - vec2(0.5);
	float vig = 1.0 - dot(q, q) * (1.15 * vignette);
	graded *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(clamp(mix(c, graded, strength), 0.0, 1.0), 1.0);
}
