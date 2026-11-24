shader_type sky;

uniform sampler2D milky_way_tex : source_color, filter_linear;
uniform vec3 zenith_color = vec3(0.06, 0.22, 0.58);
uniform vec3 horizon_color = vec3(0.45, 0.68, 0.92);
uniform vec3 sunset_color = vec3(0.95, 0.48, 0.18);
uniform vec3 sun_dir = vec3(0.6, 0.35, 0.7);
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform float atmo_blend = 0.0;

float hash31(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.11, 0.23, 0.37));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    vec3 mw = texture(milky_way_tex, SKY_COORDS).rgb;
    vec3 space_col = vec3(0.004, 0.006, 0.012) + pow(mw, vec3(1.22)) * 1.10;

    vec3 cell1 = floor(dir * 310.0);
    float s1 = hash31(cell1);
    if (s1 > 0.9935) {
        float bri = pow((s1 - 0.9935) / 0.0065, 1.6);
        vec3 tint = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.85, 0.65), hash31(cell1 + 7.1));
        space_col += tint * bri * 1.6;
    }

    vec3 cell2 = floor(dir * 620.0);
    float s2 = hash31(cell2 + 31.4);
    if (s2 > 0.995) {
        space_col += vec3(0.85, 0.90, 1.0) * ((s2 - 0.995) / 0.005) * 0.70;
    }

    if (atmo_blend > 0.002) {
        vec3 u_n = normalize(up_dir);
        vec3 sd = normalize(sun_dir);
        float elev = dot(dir, u_n);
        float sd_elev = dot(sd, u_n);

        float h_fac = pow(clamp(1.0 - max(0.0, elev), 0.0, 1.0), 2.4);
        float sun_cos = max(0.0, dot(dir, sd));
        float day_sun = smoothstep(-0.18, 0.35, sd_elev);
        float twi = exp(-pow((sd_elev + 0.03) * 4.5, 2.0));

        vec3 sky_grad = mix(zenith_color, horizon_color, h_fac) * (0.06 + 0.94 * day_sun);
        sky_grad = mix(sky_grad, sunset_color * h_fac, twi * 0.65);

        float mie = pow(sun_cos, 12.0) * 0.45 + smoothstep(0.9994, 0.9999, sun_cos) * 4.5;
        sky_grad += mix(sunset_color, vec3(1.0, 0.96, 0.88), day_sun) * mie * smoothstep(-0.08, 0.15, elev);

        float star_fade = clamp(1.0 - atmo_blend * day_sun * 1.25, 0.04, 1.0);
        COLOR = mix(space_col * star_fade, sky_grad, atmo_blend * clamp(0.25 + 0.75 * day_sun, 0.0, 1.0));
    } else {
        COLOR = space_col;
    }
}
