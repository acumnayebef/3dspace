shader_type spatial;
render_mode unshaded;

uniform vec3 hot_color = vec3(1.0, 0.82, 0.3);
uniform vec3 cool_color = vec3(1.0, 0.4, 0.05);
uniform float star_seed = 0.0;
uniform float granule_scale = 8.0;
uniform float spot_amount = 0.35;
uniform float flare_intensity = 0.25;
uniform float anim_speed = 1.0;

float hash31(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3d(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash31(i);
    float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
    return mix(
        mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
        mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
        f.z
    );
}

void fragment() {
    float phi = UV.x * 6.2831853;
    float theta = UV.y * 3.14159265;
    vec3 pos = vec3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));
    vec3 s_pos = pos + vec3(star_seed * 13.7, star_seed * 7.1, star_seed * 23.3);
    float tm = TIME * anim_speed;

    float g1 = noise3d(s_pos * granule_scale + vec3(tm * 0.06, 0.0, 0.0));
    float g2 = noise3d(s_pos * (granule_scale * 2.3) - vec3(0.0, tm * 0.10, tm * 0.05));
    float g3 = noise3d(s_pos * (granule_scale * 4.8) + vec3(tm * 0.14, 0.0, 0.0));
    float plasma = g1 * 0.50 + g2 * 0.32 + g3 * 0.18;

    float cell_ridge = 1.0 - abs(g2 * 2.0 - 1.0);
    float flares = pow(clamp(cell_ridge * g1 * 1.45, 0.0, 1.0), 3.0) * flare_intensity;

    float spot_mask = smoothstep(0.18, 0.42, g1 * 0.72 + g2 * 0.28);
    float spot_factor = mix(1.0, 0.25 + 0.75 * spot_mask, spot_amount);

    float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
    float limb = 0.32 + 0.68 * pow(max(0.0001, ndotv), 0.52);

    vec3 star_col = mix(cool_color * 0.62, hot_color * 1.25, smoothstep(0.22, 0.85, plasma));
    star_col = star_col * spot_factor * limb + hot_color * flares;

    ALBEDO = star_col;
}
