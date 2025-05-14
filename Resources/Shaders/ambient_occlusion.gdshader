shader_type canvas_item;

uniform bool enabled = true;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float radius : hint_range(0, 32) = 8.0;
uniform float darken_corners : hint_range(0.0, 1.0) = 0.5;
uniform float corners_only : hint_range(0.0, 1.0) = 0.0;
uniform float falloff : hint_range(0.5, 8.0) = 2.0;
uniform bool pixel_perfect = true;
uniform sampler2D screen_texture : hint_screen_texture;

float screen_edge_mask(vec2 uv) {

	vec2 screen_edge = min(uv, 1.0 - uv);
	return smoothstep(0.0, 0.2, screen_edge.x) * smoothstep(0.0, 0.2, screen_edge.y);
}

float corner_mask(vec2 uv) {
	vec2 center_dist = abs(uv - 0.5) * 2.0;
	float corner_mask = pow(length(center_dist), falloff) * darken_corners;
	return corner_mask;
}

float occlusion(vec2 uv, vec2 pixel_size) {
	if (!enabled) return 0.0;
	
	vec4 center_color = texture(screen_texture, uv);
	float center_lum = dot(center_color.rgb, vec3(0.299, 0.587, 0.114));
	float ao = 0.0;
	
	float samples = 0.0;
	float r = radius * pixel_size.x;
	
	for (float i = 0.0; i < 6.0; i++) {
		float angle = i * (3.14159 * 2.0 / 6.0);
		for (float j = 1.0; j <= 2.0; j++) {
			vec2 offset = vec2(cos(angle), sin(angle)) * r * j * 0.5;
			vec2 sample_uv = uv + offset;
			
			if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
				continue;
			}
			
			vec4 sample_color = texture(screen_texture, sample_uv);
			float sample_lum = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
			
			float lum_diff = max(0.0, center_lum - sample_lum);
			ao += lum_diff * (1.0 / (j * 0.5));
			samples += 1.0;
		}
	}
	
	if (samples > 0.0) {
		ao = ao / samples * intensity;
	}
	
	float corner = corner_mask(uv);
	
	return mix(ao, corner, corners_only);
}

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	
	float ao_amount = occlusion(UV, pixel_size);
	
	vec4 original_color = texture(TEXTURE, UV);
	
	COLOR = original_color * (1.0 - ao_amount);
} 