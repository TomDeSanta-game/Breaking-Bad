shader_type canvas_item;

uniform float aberration_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 aberration_center = vec2(0.5, 0.5);

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = aberration_center;
    vec2 dir = uv - center;
    float dist = length(dir);
    
    vec2 offset = dir * aberration_amount * 0.02;
    
    vec4 r = texture(SCREEN_TEXTURE, uv - offset);
    vec4 g = texture(SCREEN_TEXTURE, uv);
    vec4 b = texture(SCREEN_TEXTURE, uv + offset);
    
    COLOR = vec4(r.r, g.g, b.b, 1.0);
} 