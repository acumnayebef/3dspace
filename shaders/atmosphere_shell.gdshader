shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;

uniform vec3 day_color = vec3(0.24, 0.56, 1.0);
uniform vec3 sunset_color = vec3(0.95, 0.42, 0.15);
uniform vec3 sun_dir_local = vec3(0.6, 0.25, 0.75);
uniform float density = 1.0;

varying vec3 obj_pos;

void vertex() {
    obj_pos = normalize(VERTEX);
}

void fragment() {
    float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
    float rim = pow(clamp(1.0 - ndotv, 0.0, 1.0), 2.8);
    float inner_soft = smoothstep(0.0, 0.22, ndotv);
    float sun_dot = dot(normalize(obj_pos), normalize(sun_dir_local));
    float day = smoothstep(-0.24, 0.42, sun_dot);
    float term = exp(-pow((sun_dot + 0.05) * 4.2, 2.0));
    vec3 col = mix(day_color, sunset_color, clamp(term * 0.85, 0.0, 1.0));
    float a = rim * inner_soft * (0.04 + 0.96 * max(day, term * 0.6)) * density;
    ALBEDO = col * a;
    ALPHA = clamp(a, 0.0, 1.0);
}
