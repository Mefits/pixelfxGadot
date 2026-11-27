shader_type canvas_item;
render_mode unshaded;
uniform sampler2D phase_map : filter_nearest, repeat_disable;
uniform float cycle_phase = 0.0;
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec3 data = texture(phase_map, UV).rgb;
    float harmonic = max(1.0, floor(data.g * 5.0 + 0.5));
    float a = 6.28318530718 * (harmonic * cycle_phase + data.r);
    float wave = 0.5 + 0.5 * sin(a);
    float strength = 0.22 + 0.44 * data.b;
    float brightness = 1.0 - strength * (1.0 - wave);
    COLOR = vec4(base.rgb * brightness, base.a);
}
