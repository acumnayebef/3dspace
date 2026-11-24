shader_type spatial;
render_mode cull_disabled;

uniform sampler2D ring_tex : source_color, filter_linear_mipmap;
uniform vec3 sun_dir_local = vec3(0.6, 0.25, 0.75);
uniform float ring_scale = 4.6;

varying vec3 planet_space_pos;

void vertex() {
    // Quad is rotated -90 deg on X in planet space: (x, y, 0) -> (x, 0, -y)
    planet_space_pos = vec3(VERTEX.x, 0.0, -VERTEX.y) * ring_scale;
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float r = length(uv);
    if (r < 0.42 || r > 0.98) {
        ALPHA = 0.0;
        ALBEDO = vec3(0.0);
    } else {
        float u = clamp((r - 0.42) / 0.56, 0.0, 1.0);
        vec4 t = texture(ring_tex, vec2(u, 0.5));
        float lum = dot(t.rgb, vec3(0.333));
        float a = clamp(max(t.a, lum), 0.0, 1.0);

        // Realistic planet shadow cast across the night-side rings
        vec3 s = normalize(sun_dir_local);
        float proj = dot(planet_space_pos, s);
        float shadow = 1.0;
        if (proj < 0.0) {
            float perp = length(planet_space_pos - s * proj);
            shadow = mix(0.06, 1.0, smoothstep(0.96, 1.03, perp));
        }

        ALBEDO = t.rgb * shadow;
        ALPHA = a * 0.92;
        ROUGHNESS = 0.85;
    }
}
