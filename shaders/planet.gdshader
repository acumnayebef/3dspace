shader_type spatial;

uniform vec3 sun_dir_local = vec3(0.6, 0.25, 0.75);
uniform int planet_mode = 4; // 1=habitable, 2=mars, 3=gas, 4=cratered rocky, 5=icy, 6=shrouded venus/titan
uniform vec3 color_primary = vec3(0.5, 0.5, 0.5);
uniform vec3 color_secondary = vec3(0.2, 0.2, 0.2);
uniform vec3 atmo_color = vec3(0.32, 0.62, 1.0);
uniform int has_cities = 0;
uniform float planet_seed = 0.0;
uniform float has_red_spot = 0.0;
uniform float atmo_strength = 0.0;
uniform float cloud_amount = 0.0;
uniform float bump_strength = 0.45;

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

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise3d(p);
        p = p * 2.07 + vec3(13.1, 7.4, 19.7);
        a *= 0.49;
    }
    return v;
}

float fbm_fast(vec3 p) {
    float v = 0.5 * noise3d(p);
    v += 0.25 * noise3d(p * 2.13 + vec3(7.1, 13.7, 3.9));
    v += 0.125 * noise3d(p * 4.41 + vec3(19.3, 5.2, 11.4));
    return v;
}

float ridged_fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        float n = 1.0 - abs(noise3d(p) * 2.0 - 1.0);
        v += a * n * n;
        p = p * 2.13 + vec3(7.7, 17.3, 11.9);
        a *= 0.5;
    }
    return v;
}

float crater_layer(vec3 p) {
    vec3 cell = floor(p);
    vec3 frac = fract(p) - 0.5;
    float seed = hash31(cell);
    vec3 jit = (vec3(hash31(cell + 3.1), hash31(cell + 7.7), hash31(cell + 13.3)) - 0.5) * 0.45;
    float d = length(frac - jit);
    float rad = 0.22 + seed * 0.20;
    float bowl = smoothstep(rad, 0.0, d) * -0.45;
    float rim = exp(-pow((d - rad) * 9.0, 2.0)) * 0.42;
    return (seed > 0.35) ? (bowl + rim) : 0.0;
}

float sample_relief(vec3 spos, float n_macro) {
    if (planet_mode == 1) {
        return max(0.0, n_macro - 0.50) * 1.4 + fbm_fast(spos * 18.0) * 0.45;
    } else if (planet_mode == 2) {
        return n_macro * 0.8 + (1.0 - abs(noise3d(spos * 14.0) * 2.0 - 1.0)) * 0.45 + crater_layer(spos * 11.0) * 0.5;
    } else if (planet_mode == 3 || planet_mode == 6) {
        return fbm_fast(vec3(spos.x * 3.0, spos.y * 14.0, spos.z * 3.0)) * 0.18;
    } else if (planet_mode == 5) {
        float cr = 1.0 - abs(fbm_fast(spos * 16.0) * 2.0 - 1.0);
        return n_macro * 0.4 + pow(clamp(cr, 0.0, 1.0), 2.5) * 0.6;
    } else {
        return n_macro * 0.45 + crater_layer(spos * 9.5) * 0.85 + crater_layer(spos * 24.0) * 0.45;
    }
}

void fragment() {
    float phi = UV.x * 6.2831853;
    float theta = UV.y * 3.14159265;
    vec3 pos = vec3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));
    vec3 spos = pos + vec3(planet_seed * 17.3, planet_seed * 9.1, planet_seed * 29.7);

    float warp = fbm_fast(spos * 2.1 + vec3(4.1, 1.7, 8.3)) * 0.28;
    float n = fbm(spos * 3.6 + warp);
    float ridge = ridged_fbm(spos * 10.5);
    float detail = fbm_fast(spos * 32.0);

    vec3 albedo = color_primary;
    vec3 emissive = vec3(0.0);
    float rough = 0.88;
    float spec = 0.35;

    float sun_dot = dot(normalize(pos), normalize(sun_dir_local));
    float night_mask = smoothstep(0.06, -0.22, sun_dot);

    if (planet_mode == 1) {
        float elev = n + warp * 0.35;
        float lat = abs(pos.y);

        if (lat + detail * 0.10 > 0.84) {
            albedo = vec3(0.90, 0.93, 0.96);
            rough = 0.58;
        } else if (elev < 0.50) {
            float depth = clamp(elev / 0.50, 0.0, 1.0);
            albedo = mix(vec3(0.008, 0.032, 0.11), vec3(0.025, 0.16, 0.34), pow(max(0.0001, depth), 2.0));
            rough = 0.14;
            spec = 0.85;
        } else {
            float h = clamp((elev - 0.50) / 0.42, 0.0, 1.0);
            vec3 forest = vec3(0.06, 0.15, 0.07);
            vec3 steppe = vec3(0.24, 0.27, 0.14);
            vec3 desert = vec3(0.48, 0.39, 0.26);
            vec3 rock = vec3(0.28, 0.26, 0.24);
            vec3 snow = vec3(0.88, 0.90, 0.93);

            float arid = smoothstep(0.08, 0.32, abs(lat - 0.27)) * smoothstep(0.2, 0.8, detail);
            vec3 low_col = mix(desert, mix(steppe, forest, detail), arid);
            albedo = mix(low_col, rock, smoothstep(0.32, 0.68, h + ridge * 0.18));
            albedo = mix(albedo, snow, smoothstep(0.76, 0.94, h + ridge * 0.22));
            rough = 0.92;

            if (has_cities == 1 && h < 0.28 && lat < 0.68 && night_mask > 0.01) {
                float city_cluster = fbm_fast(pos * 24.0);
                float lights = hash31(floor(pos * 260.0));
                if (city_cluster > 0.54 && lights > 0.84) {
                    emissive = vec3(1.0, 0.72, 0.28) * (lights - 0.84) * 14.0 * night_mask;
                }
            }
        }

        if (cloud_amount > 0.05) {
            vec3 c_warp = vec3(sin(pos.y * 5.0) * 0.42 + TIME * 0.003, cos(pos.x * 5.0) * 0.22, 0.0);
            float cn = fbm(spos * 4.6 + c_warp + vec3(n * 0.8, -n * 0.4, n * 0.6));
            float cn_shadow = fbm((spos + normalize(sun_dir_local) * 0.010) * 4.6 + c_warp + vec3(n * 0.8, -n * 0.4, n * 0.6));
            float clouds = smoothstep(0.56 - cloud_amount * 0.12, 0.78, cn);
            float c_shadow = smoothstep(0.54, 0.78, cn_shadow) * (1.0 - clouds) * 0.50;
            albedo *= (1.0 - c_shadow);
            albedo = mix(albedo, vec3(0.92, 0.94, 0.97), clouds * 0.90);
            emissive *= (1.0 - clouds * 0.85);
            rough = mix(rough, 0.95, clouds);
        }
    } else if (planet_mode == 2) {
        float lat = abs(pos.y);
        float dust_basins = smoothstep(0.24, 0.72, n);
        albedo = mix(color_secondary * 0.85, color_primary * 0.92, dust_basins);
        albedo = mix(albedo, vec3(0.58, 0.30, 0.18), ridge * 0.28);
        albedo *= (0.78 + detail * 0.34);
        if (lat + detail * 0.10 > 0.87) albedo = vec3(0.88, 0.87, 0.85);
    } else if (planet_mode == 3) {
        float turb = (n - 0.5) * 0.16 + (detail - 0.5) * 0.06;
        float y_band = (pos.y + turb) * 18.0 + sin((n - 0.5) * 8.0);
        float stripe = sin(y_band + planet_seed) * 0.5 + 0.5;
        float fine_band = sin(y_band * 2.4 + detail * 3.0) * 0.5 + 0.5;
        albedo = mix(color_secondary, color_primary, smoothstep(0.14, 0.86, stripe * 0.75 + fine_band * 0.25));
        albedo *= (0.85 + detail * 0.24);
        if (has_red_spot > 0.5) {
            vec2 spot_d = vec2((UV.x - 0.32) * 5.2, (pos.y + 0.34) * 9.5);
            float r2 = dot(spot_d, spot_d);
            if (r2 < 1.0) {
                float swirl = sin(r2 * 14.0 - atan(spot_d.y, spot_d.x) * 2.0) * 0.15 + 0.85;
                albedo = mix(albedo, vec3(0.78, 0.26, 0.14) * swirl, smoothstep(1.0, 0.25, r2));
            }
        }
        rough = 0.68;
    } else if (planet_mode == 6) {
        float swirl = fbm(spos * 3.2 + vec3(TIME * 0.002 + sin(pos.y * 6.0) * 0.6, pos.y * 4.5, 0.0));
        float band = sin((pos.y + (swirl - 0.5) * 0.35) * 10.0) * 0.5 + 0.5;
        albedo = mix(color_secondary, color_primary, smoothstep(0.15, 0.85, swirl * 0.65 + band * 0.35));
        rough = 0.72;
    } else if (planet_mode == 5) {
        float crev = abs(detail * 2.0 - 1.0);
        albedo = mix(color_secondary, color_primary, smoothstep(0.25, 0.78, n));
        albedo = mix(albedo, vec3(0.22, 0.42, 0.64), smoothstep(0.60, 0.94, 1.0 - crev) * 0.55);
        rough = 0.45;
    } else {
        float maria = smoothstep(0.38, 0.58, n);
        float c1 = crater_layer(spos * 9.5);
        float c2 = crater_layer(spos * 24.0);
        albedo = mix(color_secondary * 0.78, color_primary * 0.95, maria);
        albedo *= clamp(0.84 + ridge * 0.26 + (c1 + c2 * 0.5) * 0.45 + (detail - 0.5) * 0.18, 0.45, 1.25);
        rough = 0.94;
    }

    // Procedural bump/normal relief from tangent-space height gradient
    vec3 obj_t = normalize(vec3(-sin(phi), 0.0, cos(phi)));
    vec3 obj_b = normalize(cross(pos, obj_t));
    float eps = 0.0045;
    float h0 = sample_relief(spos, n);
    float dhu = (sample_relief(spos + obj_t * eps, n) - h0) / eps;
    float dhv = (sample_relief(spos + obj_b * eps, n) - h0) / eps;
    NORMAL = normalize(NORMAL - TANGENT * (dhu * bump_strength * 0.012) - BINORMAL * (dhv * bump_strength * 0.012));

    // Realistic Rayleigh / sunset terminator & atmospheric limb glow
    if (atmo_strength > 0.01) {
        float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
        float fresnel = pow(max(0.0001, 1.0 - ndotv), 3.4);
        float term_band = exp(-pow((sun_dot + 0.04) * 5.0, 2.0));
        vec3 sunset = vec3(0.95, 0.42, 0.16) * term_band * 0.28 * atmo_strength;
        emissive += (atmo_color * smoothstep(-0.12, 0.40, sun_dot) * fresnel * 0.55 * atmo_strength) + sunset * fresnel;
    }

    ALBEDO = albedo;
    EMISSION = emissive;
    ROUGHNESS = rough;
    SPECULAR = spec;
}
