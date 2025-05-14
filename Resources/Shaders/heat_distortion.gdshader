shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 distortion_speed = vec2(0.1, 0.05);
uniform sampler2D noise_texture;

void fragment() {
    vec2 uv = SCREEN_UV;
    float time = TIME;
    
    vec2 noise_uv = UV + distortion_speed * time;
    float noise = texture(noise_texture, noise_uv).r * 2.0 - 1.0;
    
    vec2 distortion = vec2(noise, noise) * intensity * 0.02;
    COLOR = texture(SCREEN_TEXTURE, uv + distortion);
} 