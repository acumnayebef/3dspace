shader_type spatial;
render_mode unshaded;

uniform vec3 ring_color = vec3(1.0, 0.72, 0.35);
uniform float ring_sharpness = 9.0;
uniform float ring_intensity = 3.2;
uniform float asymmetry = 0.35;
uniform float lensed_halo = 0.25;

void fragment() {
    float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
    float rim = max(0.0001, 1.0 - ndotv);
    float photon_ring = pow(rim, ring_sharpness) * ring_intensity;
    float halo = pow(rim, 3.2) * lensed_halo;
    float beam = clamp(1.0 + NORMAL.x * asymmetry - NORMAL.y * (asymmetry * 0.35), 0.45, 1.75);
    ALBEDO = ring_color * (photon_ring * beam + halo);
}
