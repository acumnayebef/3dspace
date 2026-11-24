shader_type sky;

float hash31(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.11, 0.23, 0.37));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
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

void sky() {
    vec3 dir = normalize(EYEDIR);
    vec3 col = vec3(0.008, 0.011, 0.022);

    // Subtle Milky Way galactic band
    float plane_tilt = abs(dir.y * 0.82 - dir.x * 0.45 + dir.z * 0.35);
    float band = exp(-plane_tilt * plane_tilt * 22.0);
    float dust = noise3d(dir * 6.5) * 0.65 + noise3d(dir * 16.0) * 0.35;
    col += vec3(0.05, 0.08, 0.14) * band * smoothstep(0.25, 0.85, dust);

    // Sharp multi-layer stars
    vec3 cell1 = floor(dir * 260.0);
    float s1 = hash31(cell1);
    if (s1 > 0.992) {
        float bri = (s1 - 0.992) / 0.008;
        vec3 tint = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.85, 0.65), hash31(cell1 + 7.1));
        col += tint * bri * 1.4;
    }

    vec3 cell2 = floor(dir * 520.0);
    float s2 = hash31(cell2 + 31.4);
    if (s2 > 0.994) {
        col += vec3(0.85, 0.90, 1.0) * ((s2 - 0.994) / 0.006) * 0.75;
    }

    COLOR = col;
}
