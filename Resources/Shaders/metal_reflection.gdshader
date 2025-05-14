shader_type canvas_item;

uniform float reflection_intensity : hint_range(0.0, 1.0) = 0.7;
uniform float specular : hint_range(0.0, 1.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
uniform float refraction : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_modulation : source_color = vec4(0.9, 0.9, 1.0, 1.0);

uniform vec2 light_direction = vec2(1.0, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform float light_intensity : hint_range(0.0, 2.0) = 1.0;

uniform float time_offset = 0.0;
uniform vec2 reflection_offset = vec2(0.0, 0.0);

const float PI = 3.14159265359;

float ggx(float NoH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NoH2 = NoH * NoH;
    float numerator = a2;
    float denominator = NoH2 * (a2 - 1.0) + 1.0;
    denominator = denominator * denominator;
    return numerator / denominator;
}

float schlick_fresnel(float cos_theta) {
    return pow(1.0 - cos_theta, 5.0);
}

void fragment() {
    vec2 uv = UV;
    vec4 texture_color = texture(TEXTURE, uv);
    
    vec2 normal = vec2(0.0, 1.0);
    if (roughness > 0.0) {
        float noise_time = time_offset * 0.1;
        float noise_x = sin(uv.x * 15.0 + noise_time) * sin(uv.y * 10.0 + noise_time) * roughness * 0.2;
        float noise_y = cos(uv.x * 10.0 + noise_time) * cos(uv.y * 15.0 + noise_time) * roughness * 0.2;
        normal = normalize(normal + vec2(noise_x, noise_y));
    }
    
    vec2 view_dir = normalize(vec2(0.5, 0.5) - uv);
    vec2 reflection_dir = reflect(-view_dir, normal);
    
    vec2 half_vec = normalize(view_dir + normalize(light_direction));
    float n_dot_l = max(0.0, dot(normal, normalize(light_direction)));
    float n_dot_v = max(0.0, dot(normal, view_dir));
    float n_dot_h = max(0.0, dot(normal, half_vec));
    float v_dot_h = max(0.0, dot(view_dir, half_vec));
    
    float specular_distribution = ggx(n_dot_h, roughness);
    float fresnel = schlick_fresnel(v_dot_h) * metallic + (1.0 - metallic) * 0.04;
    
    vec2 screen_uv = SCREEN_UV + reflection_dir * 0.05 * reflection_intensity + reflection_offset;
    vec3 reflection = texture(SCREEN_TEXTURE, screen_uv).rgb;
    
    reflection *= texture_color.rgb * color_modulation.rgb;
    
    vec3 specular_color = light_color.rgb * specular_distribution * fresnel * n_dot_l * light_intensity * specular;
    
    float reflection_factor = mix(reflection_intensity * 0.5, reflection_intensity, fresnel);
    vec3 diffuse = texture_color.rgb * n_dot_l * light_color.rgb * (1.0 - metallic) * light_intensity;
    vec3 ambient = texture_color.rgb * 0.2;
    
    vec3 final_color = ambient + diffuse + specular_color + reflection * reflection_factor;
    final_color *= color_modulation.rgb;
    
    COLOR = vec4(final_color, texture_color.a);
} 