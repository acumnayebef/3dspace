shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

const float TAU_F = 6.2831853;

varying float cam_dist_v;

float wave_height(vec2 uv, float t, float med_w, float fine_w) {
    float w1 = sin(dot(uv, vec2(14.0, 9.0)) * TAU_F + t * 0.85);
    float w2 = sin(dot(uv, vec2(-11.0, 17.0)) * TAU_F - t * 1.10) * 0.75;
    float w3 = sin(dot(uv, vec2(48.0, -37.0)) * TAU_F + t * 1.95) * 0.32 * med_w;
    float w4 = sin(dot(uv, vec2(-43.0, 61.0)) * TAU_F - t * 2.30) * 0.28 * med_w;
    float w5 = sin(dot(uv, vec2(165.0, 120.0)) * TAU_F + t * 3.40) * 0.14 * fine_w;
    float w6 = sin(dot(uv, vec2(-190.0, 145.0)) * TAU_F - t * 3.80) * 0.12 * fine_w;
    return w1 + w2 + w3 + w4 + w5 + w6;
}

void vertex() {
    cam_dist_v = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
    float med_w = smoothstep(22000.0, 900.0, cam_dist_v);
    float fine_w = smoothstep(3200.0, 120.0, cam_dist_v);

    float eps = mix(0.0022, 0.00045, fine_w);
    float h0 = wave_height(UV, TIME, med_w, fine_w);
    float hu = wave_height(UV + vec2(eps, 0.0), TIME, med_w, fine_w);
    float hv = wave_height(UV + vec2(0.0, eps), TIME, med_w, fine_w);

    float slope_scale = mix(0.055, 0.14, fine_w);
    float du = clamp(((hu - h0) / eps) * 0.0014 * slope_scale * 22.0, -0.45, 0.45);
    float dv = clamp(((hv - h0) / eps) * 0.0014 * slope_scale * 22.0, -0.45, 0.45);

    if (dot(TANGENT, TANGENT) > 0.01 && dot(BINORMAL, BINORMAL) > 0.01) {
        NORMAL = normalize(NORMAL - TANGENT * du - BINORMAL * dv);
    }

    float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
    float fresnel = pow(max(0.0001, 1.0 - ndotv), 3.2);

    float crest = smoothstep(1.05, 2.25, h0) * mix(0.25, 1.0, med_w);
    vec3 deep_col = vec3(0.014, 0.085, 0.21);
    vec3 shallow_col = vec3(0.045, 0.24, 0.42);
    vec3 sky_refl = vec3(0.38, 0.64, 0.88);
    vec3 foam_col = vec3(0.84, 0.91, 0.96);

    vec3 water_col = mix(deep_col, shallow_col, clamp(0.42 + h0 * 0.16, 0.0, 1.0));
    water_col = mix(water_col, sky_refl, fresnel * 0.62);
    water_col = mix(water_col, foam_col, crest * 0.26);

    ALBEDO = water_col;
    ROUGHNESS = mix(0.14, 0.36, crest * 0.45);
    SPECULAR = 0.82;
    METALLIC = 0.08;
    ALPHA = mix(0.92, 0.99, fresnel * 0.6 + crest * 0.2);
}
