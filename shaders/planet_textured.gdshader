shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D night_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D clouds_tex : source_color, filter_linear_mipmap, repeat_enable;

uniform int use_night = 0;
uniform int use_clouds = 0;
uniform int is_earth = 0;
uniform float bump_strength = 0.35;
uniform vec3 sun_dir_local = vec3(0.6, 0.25, 0.75);
uniform float atmo_strength = 0.0;
uniform vec3 atmo_color = vec3(0.28, 0.62, 1.0);

varying vec3 obj_pos;

void vertex() {
    obj_pos = normalize(VERTEX);
}

void fragment() {
    vec3 albedo = texture(albedo_tex, UV).rgb;
    float lum0 = dot(albedo, vec3(0.299, 0.587, 0.114));
    float lum_u = dot(texture(albedo_tex, UV + vec2(0.0008, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float lum_v = dot(texture(albedo_tex, UV + vec2(0.0, 0.0012)).rgb, vec3(0.299, 0.587, 0.114));

    float rough = 0.90;
    float spec = 0.35;
    float ocean_mask = 0.0;

    if (is_earth == 1) {
        if (albedo.b > albedo.r * 1.16 && albedo.b > albedo.g * 1.04 && albedo.b < 0.72) {
            ocean_mask = 1.0;
            rough = 0.16;
            spec = 0.85;
            albedo *= 0.88;
        } else {
            rough = 0.92;
        }
    }

    float bump_w = bump_strength * (1.0 - ocean_mask * 0.92);
    float du = (lum_u - lum0) * 14.0 * bump_w;
    float dv = (lum_v - lum0) * 14.0 * bump_w;
    NORMAL = normalize(NORMAL - TANGENT * du - BINORMAL * dv);

    float sun_dot = dot(normalize(obj_pos), normalize(sun_dir_local));
    float night_mask = smoothstep(0.08, -0.20, sun_dot);
    vec3 emissive = vec3(0.0);

    if (use_night == 1 && night_mask > 0.01) {
        vec3 n_col = texture(night_tex, UV).rgb;
        emissive = n_col * night_mask * 2.2;
    }

    if (use_clouds == 1) {
        vec2 c_uv = UV + vec2(TIME * 0.0006, 0.0);
        float cl = texture(clouds_tex, c_uv).r;
        float cl_sh = texture(clouds_tex, c_uv + vec2(0.0035, 0.0015)).r;
        float c_shad = clamp((cl_sh - cl) * 0.9 + cl_sh * 0.25, 0.0, 0.52);
        albedo *= (1.0 - c_shad * (1.0 - cl));
        albedo = mix(albedo, vec3(0.95, 0.96, 0.98), smoothstep(0.18, 0.88, cl) * 0.92);
        emissive *= (1.0 - cl * 0.85);
        rough = mix(rough, 0.95, cl);
        spec = mix(spec, 0.25, cl);
    }

    if (atmo_strength > 0.01) {
        float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
        float fresnel = pow(max(0.0001, 1.0 - ndotv), 3.6);
        float day_lim = smoothstep(-0.14, 0.35, sun_dot);
        float term = exp(-pow((sun_dot + 0.03) * 5.2, 2.0));
        vec3 sunset = vec3(0.95, 0.40, 0.14) * term * 0.28;
        emissive += (atmo_color * day_lim * 0.42 + sunset) * fresnel * atmo_strength;
    }

    ALBEDO = albedo;
    EMISSION = emissive;
    ROUGHNESS = rough;
    SPECULAR = spec;
}
