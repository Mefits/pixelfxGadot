shader_type canvas_item;
render_mode unshaded;
uniform sampler2D surface_map : filter_nearest, repeat_disable;
uniform int light_count = 0;
uniform vec4 light_geom[8];
uniform vec4 light_rgb[8];
void fragment() {
    vec4 albedo = texture(TEXTURE, UV);
    // Preserve the original texture and alpha exactly outside the light contribution.
    vec3 added = vec3(0.0);
    if (albedo.a > 0.0 && light_count > 0) {
        vec4 face = texture(surface_map, UV);
        vec3 n = normalize(face.rgb * 2.0 - 1.0);
        vec2 p = (floor(UV / TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE * vec2(640.0,360.0);
        float value = max(albedo.r,max(albedo.g,albedo.b));
        for (int i = 0; i < 8; i++) {
            if (i >= light_count) { break; }
            vec4 l = light_geom[i];
            vec2 delta = l.xy - p;
            float falloff = max(0.0,1.0-length(delta)/max(1.0,l.z));
            vec3 direction = normalize(vec3(delta,26.0));
            float diffuse = 0.22 + 0.78 * max(0.0,dot(n,direction));
            // PixelFX radial glow falloff; preserve differences between stone facets.
            float strength = falloff * falloff * l.w * diffuse * face.a;
            added += light_rgb[i].rgb * strength * (0.22 + 0.9 * value);
        }
    }
    // Bounded additive reflected light, not a screen-space bloom.
    COLOR = vec4(albedo.rgb + min(added,vec3(0.78))*(1.0-albedo.rgb),albedo.a);
}
