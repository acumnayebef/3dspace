shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec3 inner_color = vec3(1.0, 0.92, 0.72);
uniform vec3 outer_color = vec3(0.95, 0.34, 0.06);
uniform float spin_speed = 1.4;
uniform float turbulence = 1.0;
uniform float doppler_strength = 0.45;
uniform float inner_radius = 0.28;
uniform float disk_seed = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm2(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise2d(p);
        p = p * 2.05 + vec2(11.3, 7.9);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float r = length(uv);
    if (r < inner_radius || r > 0.98) {
        ALPHA = 0.0;
        ALBEDO = vec3(0.0);
    } else {
        float t = clamp((r - inner_radius) / (0.98 - inner_radius), 0.0, 1.0);
        float ang = atan(uv.y, uv.x);
        float shear = ang + TIME * spin_speed / max(0.24, r);

        float rings = sin(r * 46.0 - shear * 2.0 + disk_seed * 6.0) * 0.5 + 0.5;
        float fil1 = fbm2(vec2(r * 11.0 * turbulence, sin(shear) * 2.5 + cos(shear) * 2.5 + disk_seed));
        float fil2 = fbm2(vec2(r * 22.0 * turbulence, sin(shear * 2.0) * 3.0 - TIME * 0.4 + disk_seed * 2.0));
        float density = (0.35 + 0.65 * fil1) * (0.60 + 0.40 * fil2) * (0.72 + 0.28 * rings);

        float isco_fade = smoothstep(0.0, 0.09, t);
        float outer_fade = pow(max(0.0001, 1.0 - t), 1.65);
        float doppler = clamp(1.0 + cos(ang + disk_seed) * doppler_strength * (1.1 - t * 0.6), 0.32, 1.75);

        vec3 col = mix(inner_color, outer_color, smoothstep(0.04, 0.72, t));
        float alpha = clamp(isco_fade * outer_fade * density * doppler * 1.15, 0.0, 1.0);
        ALBEDO = col * (0.9 + (1.0 - t) * 0.8) * doppler;
        ALPHA = alpha;
    }
}
