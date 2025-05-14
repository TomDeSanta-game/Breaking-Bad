shader_type canvas_item;

uniform float grain_amount : hint_range(0.0, 1.0) = 0.05;
uniform float grain_size : hint_range(1.0, 10.0) = 1.0;
uniform float fps : hint_range(1.0, 30.0) = 12.0;
uniform float contrast : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    float t = floor(TIME * fps) / fps;
    vec2 grain_uv = SCREEN_UV * grain_size;
    
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
    float grain = random(grain_uv + t);
    grain = mix(1.0 - grain_amount, 1.0 + grain_amount, grain);
    
    vec3 source = color.rgb;
    vec3 grain_color = source * grain;
    
    source = mix(source, grain_color, contrast);
    COLOR = vec4(source, color.a);
} 