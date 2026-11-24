shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec3 inner_color = vec3(1.0, 0.95, 0.84);
uniform vec3 outer_color = vec3(0.78, 0.45, 0.22);
uniform float spin_speed = 1.4;
uniform float doppler_strength = 0.55;
uniform float disk_radius = 5.4;
uniform float disk_seed = 0.0;
uniform float ring_brightness = 1.4;

varying vec3 obj_pos;
varying vec3 cam_obj;

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(17.3, 9.2);
    for (int j = 0; j < 3; j++) {
        v += a * noise2d(p);
        p = p * 2.07 + shift;
        a *= 0.48;
    }
    return v;
}

void vertex() {
    obj_pos = VERTEX;
    cam_obj = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
    vec3 rd = normalize(obj_pos - cam_obj);
    vec3 ro = cam_obj;
    float r_bound = 6.42;

    float cam_r = length(ro);
    if (cam_r > r_bound) {
        float b = dot(ro, rd);
        float c = dot(ro, ro) - r_bound * r_bound;
        float disc = b * b - c;
        if (disc > 0.0) {
            ro += rd * max(0.0, -b - sqrt(disc));
        }
    }

    ro += rd * (hash21(FRAGCOORD.xy) * 0.06);

    vec3 p = ro;
    vec3 accum_col = vec3(0.0);
    float trans = 1.0;
    float min_r = length(p);
    bool hit_horizon = false;

    for (int i = 0; i < 56; i++) {
        float r2 = dot(p, p);
        float r = sqrt(r2);
        if (r < 1.02) {
            hit_horizon = true;
            min_r = min(min_r, r);
            break;
        }
        if (r > 6.55 && dot(p, rd) > 0.0) {
            break;
        }

        float step_len = clamp((r - 0.88) * 0.22, 0.055, 0.34);
        vec3 bend = -p * (1.85 / max(0.35, r2 * r));
        vec3 next_rd = normalize(rd + bend * step_len);
        vec3 p_next = p + rd * step_len;

        vec3 seg = p_next - p;
        float seg_len2 = dot(seg, seg);
        float t_cl = clamp(-dot(p, seg) / max(0.00001, seg_len2), 0.0, 1.0);
        min_r = min(min_r, length(p + seg * t_cl));

        bool crossed = ((p.y > 0.0 && p_next.y <= 0.0) || (p.y <= 0.0 && p_next.y > 0.0));
        if (crossed && trans > 0.02) {
            float denom = max(0.0001, abs(p.y - p_next.y));
            float t_cross = clamp(abs(p.y) / denom, 0.0, 1.0);
            vec3 dp = mix(p, p_next, t_cross);
            float d_r = length(dp.xz);

            if (d_r > 1.48 && d_r < disk_radius) {
                float rt = clamp((d_r - 1.48) / (disk_radius - 1.48), 0.0, 1.0);
                float base_ang = atan(dp.z, dp.x);
                float omega = (TIME * spin_speed) / max(0.65, pow(d_r, 0.85));
                float rot_ang = base_ang + omega;
                float shear = omega * 0.35 + d_r * 2.2;

                vec2 uv_a = vec2(d_r * 3.8 + disk_seed, cos(rot_ang) * d_r * 0.48 + sin(rot_ang) * 0.45);
                vec2 uv_b = vec2(d_r * 7.6 - disk_seed * 0.7, sin(rot_ang * 2.0 + shear * 0.25) * d_r * 0.42);
                float f_coarse = fbm(uv_a);
                float f_fine = fbm(uv_b);
                float lane_blend = smoothstep(0.18, 0.86, f_coarse * 0.65 + f_fine * 0.35);
                float filaments = 0.28 + 0.72 * lane_blend;

                float isco = smoothstep(0.0, 0.09, rt);
                float outer_f = pow(max(0.0001, 1.0 - rt), 1.55);

                vec3 tan_vel = normalize(vec3(-dp.z, 0.0, dp.x) + vec3(0.0001));
                float doppler = clamp(1.0 + dot(tan_vel, -rd) * doppler_strength * (1.1 - rt * 0.55), 0.32, 2.25);

                vec3 disk_c = mix(inner_color, outer_color, smoothstep(0.04, 0.62, rt));
                float d_alpha = clamp(isco * outer_f * filaments * 1.40, 0.0, 0.94);

                accum_col += trans * disk_c * d_alpha * doppler * (1.35 + (1.0 - rt) * 0.8);
                trans *= (1.0 - d_alpha * 0.88);
            }
        }

        p = p_next;
        rd = next_rd;
    }

    float photon_ring = exp(-pow((min_r - 1.04) * 24.0, 2.0)) * ring_brightness;
    float inner_glow = exp(-pow(max(0.0, min_r - 1.05) * 4.5, 2.0)) * 0.16 * ring_brightness;
    if (hit_horizon) {
        photon_ring *= 0.25;
        inner_glow *= 0.2;
    }
    vec3 ring_col = mix(outer_color, inner_color, 0.72) * (photon_ring + inner_glow);
    accum_col += trans * ring_col;

    float final_a = hit_horizon ? 1.0 : clamp((1.0 - trans) + photon_ring * 0.85 + inner_glow, 0.0, 1.0);
    ALBEDO = accum_col;
    ALPHA = final_a;
}
