shader_type sky;

uniform sampler2D milky_way_tex : source_color, filter_linear;

float hash31(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.11, 0.23, 0.37));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    vec3 mw = texture(milky_way_tex, SKY_COORDS).rgb;
    vec3 col = vec3(0.004, 0.006, 0.012) + pow(mw, vec3(1.22)) * 1.10;

    // Sharp pinpoint stars overlaid on top of 2K Milky Way
    vec3 cell1 = floor(dir * 310.0);
    float s1 = hash31(cell1);
    if (s1 > 0.9935) {
        float bri = pow((s1 - 0.9935) / 0.0065, 1.6);
        vec3 tint = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.85, 0.65), hash31(cell1 + 7.1));
        col += tint * bri * 1.6;
    }

    vec3 cell2 = floor(dir * 620.0);
    float s2 = hash31(cell2 + 31.4);
    if (s2 > 0.995) {
        col += vec3(0.85, 0.90, 1.0) * ((s2 - 0.995) / 0.005) * 0.70;
    }

    COLOR = col;
}
