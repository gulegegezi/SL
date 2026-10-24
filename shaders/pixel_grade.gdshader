shader_type canvas_item;
render_mode unshaded;
// Original compatibility-renderer treatment, inspired by 3D pixel illustration.
// Apply only inside the scene viewport, never to dialogue or buttons.
uniform sampler2D scene_color : hint_screen_texture, filter_nearest, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.65;
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
void fragment() {
    vec2 texel = SCREEN_PIXEL_SIZE;
    vec3 c = texture(scene_color, SCREEN_UV).rgb;
    vec3 left = texture(scene_color, SCREEN_UV - vec2(texel.x, 0.0)).rgb;
    vec3 up = texture(scene_color, SCREEN_UV - vec2(0.0, texel.y)).rgb;
    vec3 right = texture(scene_color, SCREEN_UV + vec2(texel.x, 0.0)).rgb;
    vec3 down = texture(scene_color, SCREEN_UV + vec2(0.0, texel.y)).rgb;
    float light = luminance(c);
    // Gentle value steps preserve facial features and the authored material hues.
    float band = floor(light * 9.0 + 0.5) / 9.0;
    vec3 graded = c * (mix(light, band, 0.38) / max(light, 0.015));
    graded += vec3(-0.012, 0.008, 0.024) * (1.0 - smoothstep(0.08, 0.48, light));
    graded += vec3(0.025, 0.008, -0.018) * smoothstep(0.50, 0.95, light);
    float edge = max(max(luminance(left), luminance(up)), max(luminance(right), luminance(down))) - light;
    graded *= 1.0 - smoothstep(0.13, 0.38, edge) * 0.22;
    vec3 halo = max((left + up + right + down) * 0.25 - vec3(0.72), vec3(0.0));
    graded += halo * vec3(0.10, 0.075, 0.035);
    COLOR = vec4(clamp(mix(c, graded, strength), 0.0, 1.0), 1.0);
}
