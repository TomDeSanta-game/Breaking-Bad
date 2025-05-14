shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 1.0;
uniform float focus_distance : hint_range(0.0, 1.0) = 0.5;
uniform float focus_range : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 color = texture(SCREEN_TEXTURE, uv);
    
    if (blur_amount <= 0.0) {
        COLOR = color;
        return;
    }
    
    float depth = focus_distance;
    float blur_factor = abs(depth - focus_distance) / focus_range;
    blur_factor = min(blur_factor, 1.0) * blur_amount;
    
    vec4 blur_color = vec4(0.0);
    float total_weight = 0.0;
    
    for (float x = -4.0; x <= 4.0; x += 1.0) {
        for (float y = -4.0; y <= 4.0; y += 1.0) {
            float weight = 1.0 / (1.0 + x * x + y * y);
            vec2 offset = vec2(x, y) * blur_factor * 0.01;
            blur_color += texture(SCREEN_TEXTURE, uv + offset) * weight;
            total_weight += weight;
        }
    }
    
    blur_color /= total_weight;
    COLOR = mix(color, blur_color, min(blur_factor, 1.0));
} 