shader_type canvas_item;

uniform float reflection_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.7;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float refraction : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color_modulation : source_color = vec4(0.9, 0.95, 1.0, 1.0);

uniform vec2 light_direction = vec2(1.0, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform float light_intensity : hint_range(0.0, 2.0) = 1.0;

uniform float time_offset = 0.0;
uniform vec2 reflection_offset = vec2(0.0, 0.0);

float fresnel(float amount, vec3 normal, vec3 view) {
    return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void fragment() {
    vec2 uv = UV;
    vec4 texture_color = texture(TEXTURE, uv);
    
    vec2 normal = vec2(0.0, 1.0);
    if (roughness > 0.0) {
        float noise_time = time_offset * 0.2;
        float noise_x = sin(uv.x * 25.0 + noise_time * 1.5) * sin(uv.y * 15.0 + noise_time) * roughness * 0.2;
        float noise_y = cos(uv.x * 20.0 + noise_time * 1.3) * cos(uv.y * 30.0 + noise_time * 0.7) * roughness * 0.2;
        normal = normalize(normal + vec2(noise_x, noise_y));
    }
    
    vec2 screen_uv = SCREEN_UV;
    screen_uv += normal * refraction * 0.02;
    
    vec2 reflection_dir = reflect(vec2(0.0, -1.0), normal);
    vec2 reflection_uv = SCREEN_UV + reflection_dir * 0.1 * reflection_intensity + reflection_offset;
    
    vec3 reflection = texture(SCREEN_TEXTURE, reflection_uv).rgb;
    vec3 refraction = texture(SCREEN_TEXTURE, screen_uv).rgb;
    
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    float fresnel_factor = fresnel(3.0 + metallic * 5.0, vec3(normal, 0.0), view_dir);
    
    float edge_detect = pow(1.0 - abs(dot(normal, vec2(0.0, 1.0))), 2.0);
    
    float specular_intensity = pow(max(0.0, dot(reflection_dir, normalize(light_direction))), 10.0 - roughness * 9.0) * specular;
    
    float reflection_factor = mix(reflection_intensity * 0.5, reflection_intensity, fresnel_factor);
    reflection_factor = mix(reflection_factor, 1.0, edge_detect);
    
    vec3 final_color = mix(refraction, reflection, reflection_factor) * color_modulation.rgb;
    final_color += light_color.rgb * specular_intensity * light_intensity;
    
    COLOR = vec4(final_color, texture_color.a);
} 