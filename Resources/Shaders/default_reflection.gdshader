shader_type canvas_item;

uniform float reflection_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float refraction : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_modulation : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec2 light_direction = vec2(1.0, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float light_intensity : hint_range(0.0, 2.0) = 1.0;

uniform float time_offset = 0.0;

void fragment() {
    vec2 uv = UV;
    vec4 texture_color = texture(TEXTURE, uv);
    
    vec2 screen_uv = SCREEN_UV;
    screen_uv.x += (uv.x - 0.5) * reflection_intensity * 0.02;
    screen_uv.y += (uv.y - 0.5) * reflection_intensity * 0.02;
    
    vec3 reflection = texture(SCREEN_TEXTURE, screen_uv).rgb;
    
    vec3 final_color = mix(texture_color.rgb, reflection, reflection_intensity * 0.3);
    final_color *= color_modulation.rgb;
    
    vec2 light_vec = normalize(light_direction);
    float light_dot = max(0.0, dot(vec2(0.0, 1.0), light_vec));
    
    vec3 light_contribution = light_color.rgb * light_dot * light_intensity * specular;
    final_color += light_contribution * (1.0 - roughness);
    
    COLOR = vec4(final_color, texture_color.a);
} 