shader_type canvas_item;

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    
    float vignette = smoothstep(0.8, 0.35 * vignette_intensity, dist);
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    COLOR = mix(color, vignette_color, (1.0 - vignette) * vignette_opacity);
} 