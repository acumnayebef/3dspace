shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float intensity = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.5);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void fragment() {
    float n = noise2(vec2(UV.x * 8.0, UV.y * 14.0 - TIME * 12.0)) * 0.65
            + noise2(vec2(UV.x * 16.0, UV.y * 28.0 - TIME * 22.0)) * 0.35;
    float edge = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.4) * smoothstep(0.0, 0.25, UV.y);
    float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
    float rim = 0.45 + 0.55 * pow(max(0.0001, 1.0 - ndotv), 1.8);
    vec3 fire_c = mix(vec3(1.0, 0.28, 0.04), vec3(1.0, 0.86, 0.55), clamp(n * 1.2 * (1.0 - UV.y), 0.0, 1.0));
    float a = clamp(edge * rim * (0.45 + 0.55 * n) * intensity, 0.0, 1.0);
    ALBEDO = fire_c * a * 1.8;
    ALPHA = a;
}
