shader_type canvas_item;
render_mode unshaded;
uniform float wind = 0.0;
void fragment() {
    // Roots remain fixed. The upper tips bend gradually, within transparent padding.
    float h = clamp((0.90 - UV.y) / 0.90, 0.0, 1.0);
    vec2 uv = UV - vec2(0.075 * wind * h * h, 0.0);
    if (uv.x < 0.0 || uv.x > 1.0) {
        COLOR = vec4(0.0);
    } else {
        COLOR = texture(TEXTURE, uv);
    }
}
