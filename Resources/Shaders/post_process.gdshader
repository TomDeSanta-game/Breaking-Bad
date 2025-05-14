shader_type canvas_item;

uniform bool vignette_enabled = true;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool grain_enabled = true;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.1;
uniform float grain_size : hint_range(1.0, 10.0) = 1.0;
uniform float grain_speed : hint_range(0.0, 10.0) = 1.0;
uniform bool aberration_enabled = true;
uniform float aberration_amount : hint_range(0.0, 5.0) = 0.5;
uniform bool heat_distortion_enabled = true;
uniform sampler2D heat_noise : hint_default_black;
uniform float heat_distortion_amount : hint_range(0.0, 0.1) = 0.0005;
uniform float heat_distortion_speed : hint_range(0.0, 1.0) = 0.1;
uniform vec2 heat_center = vec2(0.5, 0.5);
uniform float heat_radius : hint_range(0.0, 1.0) = 0.6;
uniform bool dof_enabled = false;
uniform float dof_focus_distance : hint_range(0.0, 1.0) = 0.5;
uniform float dof_blur_amount : hint_range(0.0, 1.0) = 0.0;
uniform float depth_blend : hint_range(0.0, 1.0) = 0.5;
uniform float depth_range : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform bool outline_enabled = false;
uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_threshold : hint_range(0.0, 1.0) = 0.1;
uniform bool palette_shift_enabled = false;
uniform vec4 palette_shadow : source_color = vec4(0.05, 0.05, 0.1, 1.0);
uniform vec4 palette_midtone : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 palette_highlight : source_color = vec4(0.9, 0.9, 0.8, 1.0);
uniform float palette_shift_amount : hint_range(0.0, 1.0) = 0.5;
uniform bool bloom_enabled = false;
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.7;
uniform bool dithering_enabled = false;
uniform float dithering_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float dithering_scale : hint_range(1.0, 10.0) = 1.0;
uniform bool crt_enabled = false;
uniform float crt_curvature : hint_range(0.0, 1.0) = 0.1;
uniform float crt_scanline_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float crt_brightness : hint_range(0.5, 1.5) = 1.2;
uniform bool contrast_enabled = false;
uniform float contrast_amount : hint_range(0.0, 2.0) = 1.1;
const float PI = 3.14159265359;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 chromatic_aberration(sampler2D tex, vec2 uv) {
    if (!aberration_enabled) return texture(tex, uv).rgb;
    
    float aberration = aberration_amount * 0.001;
    
    vec3 color;
    color.r = texture(tex, vec2(uv.x + aberration, uv.y)).r;
    color.g = texture(tex, uv).g;
    color.b = texture(tex, vec2(uv.x - aberration, uv.y)).b;
    
    return color;
}

float vignette(vec2 uv, float intensity, float opacity) {
    vec2 center = uv - vec2(0.5);
    float len = length(center);
    float vig = smoothstep(0.8, intensity * 0.799, len * (opacity + 0.3));
    return vig;
}

vec3 apply_film_grain(vec3 color, vec2 uv, float time, float amount, float grain_size) {
    vec2 grain_uv = uv * grain_size;
    float grain = random(grain_uv + vec2(time * grain_speed));
    grain = (grain - 0.5) * amount;
    return color + vec3(grain);
}

vec2 apply_heat_distortion(vec2 uv, float time) {
    if (!heat_distortion_enabled) return uv;
    
    float distance_from_center = distance(uv, heat_center);
    float heat_factor = 1.0 - smoothstep(0.0, heat_radius, distance_from_center);
    
    vec2 noise_uv = uv + time * heat_distortion_speed * 0.1;
    vec2 noise_value = texture(heat_noise, noise_uv).rg * 2.0 - 1.0;
    
    return uv + noise_value * heat_distortion_amount * heat_factor;
}

vec4 apply_depth_of_field(sampler2D tex, vec2 uv) {
    if (!dof_enabled || dof_blur_amount <= 0.0) return texture(tex, uv);
    
    vec2 center = vec2(0.5);
    float dist = distance(uv, center);
    
    float blur_factor = abs(dist - dof_focus_distance) * dof_blur_amount * 20.0;
    blur_factor = clamp(blur_factor, 0.0, 1.0);
    
    if (blur_factor <= 0.01) return texture(tex, uv);
    
    const int samples = 6;
    const float pi2 = 6.28318530718;
    
    vec4 blurred_color = vec4(0.0);
    float total_weight = 0.0;
    
    for (int i = 0; i < samples; i++) {
        float angle = float(i) * pi2 / float(samples);
        float weight = 1.0 / float(samples);
        
        vec2 offset = vec2(cos(angle), sin(angle)) * blur_factor * 0.02;
        blurred_color += texture(tex, uv + offset) * weight;
        total_weight += weight;
    }
    
    return blurred_color / total_weight;
}

vec3 apply_palette_shift(vec3 color) {
    if (!palette_shift_enabled) return color;
    
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    
    vec3 shifted;
    if (lum < 0.33) {
        shifted = mix(color, palette_shadow.rgb, palette_shift_amount);
    } else if (lum < 0.66) {
        shifted = mix(color, palette_midtone.rgb, palette_shift_amount);
    } else {
        shifted = mix(color, palette_highlight.rgb, palette_shift_amount);
    }
    
    return shifted;
}

vec4 apply_outline(sampler2D tex, vec2 uv) {
    if (!outline_enabled) return texture(tex, uv);
    
    vec4 original = texture(tex, uv);
    
    if (original.a < 0.1) return original;
    
    float pixel_size = 1.0 / float(textureSize(tex, 0).x);
    
    vec4 up = texture(tex, uv + vec2(0.0, pixel_size * outline_thickness));
    vec4 down = texture(tex, uv + vec2(0.0, -pixel_size * outline_thickness));
    vec4 left = texture(tex, uv + vec2(-pixel_size * outline_thickness, 0.0));
    vec4 right = texture(tex, uv + vec2(pixel_size * outline_thickness, 0.0));
    
    float edge = 0.0;
    edge += abs(length(original.rgb) - length(up.rgb));
    edge += abs(length(original.rgb) - length(down.rgb));
    edge += abs(length(original.rgb) - length(left.rgb));
    edge += abs(length(original.rgb) - length(right.rgb));
    
    if (edge > outline_threshold && original.a > 0.5) {
        return mix(original, outline_color, edge * outline_color.a);
    }
    
    return original;
}

vec3 apply_bloom(sampler2D tex, vec2 uv) {
    if (!bloom_enabled) return texture(tex, uv).rgb;
    
    vec3 original = texture(tex, uv).rgb;
    
    float brightness = dot(original, vec3(0.299, 0.587, 0.114));
    
    if (brightness < bloom_threshold) return original;
    
    const int samples = 8;
    const float pi2 = 6.28318530718;
    
    vec3 bloom_color = vec3(0.0);
    
    for (int i = 0; i < samples; i++) {
        float angle = float(i) * pi2 / float(samples);
        float radius = 0.01;
        vec2 offset = vec2(cos(angle), sin(angle)) * radius;
        bloom_color += texture(tex, uv + offset).rgb;
    }
    
    bloom_color /= float(samples);
    
    float bloom_factor = smoothstep(bloom_threshold, 1.0, brightness);
    return mix(original, original + bloom_color * bloom_intensity, bloom_factor);
}

vec3 apply_dithering(vec3 color, vec2 uv) {
    if (!dithering_enabled) return color;
    
    const int bayer_matrix[16] = int[16](
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5
    );
    
    vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));
    vec2 pixel_pos = uv * screen_size / dithering_scale;
    int x = int(mod(pixel_pos.x, 4.0));
    int y = int(mod(pixel_pos.y, 4.0));
    
    float bayer_value = float(bayer_matrix[y * 4 + x]) / 16.0;
    
    color = floor(color * 4.0 + bayer_value * dithering_intensity) / 4.0;
    
    return color;
}

vec2 apply_crt_distortion(vec2 uv) {
    if (!crt_enabled) return uv;
    
    vec2 cc = uv - 0.5;
    float dist = dot(cc, cc) * crt_curvature;
    return uv + cc * (1.0 + dist) * dist;
}

vec3 apply_crt_effect(vec3 color, vec2 uv) {
    if (!crt_enabled) return color;
    
    float scanline = sin(uv.y * textureSize(SCREEN_TEXTURE, 0).y * 0.5) * 0.5 + 0.5;
    color = mix(color, color * (0.8 + 0.2 * scanline), crt_scanline_intensity);
    
    color *= crt_brightness;
    
    return color;
}

vec3 apply_contrast(vec3 color) {
    if (!contrast_enabled) return color;
    
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    
    color = mix(vec3(luminance), color, contrast_amount);
    
    return color;
}

vec3 temperature_adjust(vec3 color, float temp_value) {
    vec3 warm = vec3(1.0, 0.8, 0.6); 
    vec3 cool = vec3(0.6, 0.8, 1.0); 
    
    if (temp_value > 0.0) {
        return color * mix(vec3(1.0), warm, temp_value);
    } else {
        return color * mix(vec3(1.0), cool, -temp_value);
    }
}

vec3 apply_overlay(vec3 base, vec4 overlay, int mode) {
    vec3 result = base;
    float alpha = overlay.a;
    
    if (mode == 0) { 
        result = mix(base, overlay.rgb, alpha);
    } else if (mode == 1) { 
        result = mix(base, base * overlay.rgb, alpha);
    } else if (mode == 2) { 
        result = mix(base, 1.0 - (1.0 - base) * (1.0 - overlay.rgb), alpha);
    } else if (mode == 3) { 
        vec3 a = 2.0 * base * overlay.rgb;
        vec3 b = 1.0 - 2.0 * (1.0 - base) * (1.0 - overlay.rgb);
        vec3 overlay_result = vec3(
            base.r < 0.5 ? a.r : b.r,
            base.g < 0.5 ? a.g : b.g,
            base.b < 0.5 ? a.b : b.b
        );
        result = mix(base, overlay_result, alpha);
    } else if (mode == 4) { 
        vec3 soft_light = vec3(
            base.r < 0.5 ? (2.0 * base.r * overlay.r + base.r * base.r * (1.0 - 2.0 * overlay.r)) : (sqrt(base.r) * (2.0 * overlay.r - 1.0) + 2.0 * base.r * (1.0 - overlay.r)),
            base.g < 0.5 ? (2.0 * base.g * overlay.g + base.g * base.g * (1.0 - 2.0 * overlay.g)) : (sqrt(base.g) * (2.0 * overlay.g - 1.0) + 2.0 * base.g * (1.0 - overlay.g)),
            base.b < 0.5 ? (2.0 * base.b * overlay.b + base.b * base.b * (1.0 - 2.0 * overlay.b)) : (sqrt(base.b) * (2.0 * overlay.b - 1.0) + 2.0 * base.b * (1.0 - overlay.b))
        );
        result = mix(base, soft_light, alpha);
    }
    
    return result;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    uv = apply_crt_distortion(uv);
    
    uv = apply_heat_distortion(uv, TIME);
    
    vec3 color = chromatic_aberration(SCREEN_TEXTURE, uv);
    
    vec4 outlined = apply_outline(SCREEN_TEXTURE, uv);
    color = mix(color, outlined.rgb, outlined.a * float(outline_enabled));
    
    color = apply_bloom(SCREEN_TEXTURE, uv);
    
    color = apply_palette_shift(color);
    
    if (grain_enabled) {
        color = apply_film_grain(color, uv, TIME, grain_amount, grain_size);
    }
    
    color = apply_dithering(color, uv);
    
    color = apply_crt_effect(color, uv);
    
    color = apply_contrast(color);
    
    color = temperature_adjust(color, temperature);
    
    if (vignette_enabled) {
        float vig = vignette(uv, vignette_intensity, vignette_opacity);
        color = mix(color, vignette_color.rgb, vig * vignette_color.a);
    }
    
    float depth = texture(screen_texture, uv).r;
    float depth_effect = smoothstep(depth_range, 1.0, depth);
    color = mix(color, color * (1.0 - depth_effect * depth_blend), depth_blend);
    
    COLOR = vec4(color, 1.0);
} 