shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;

// Basic pass-through shader
void fragment() {
    COLOR = texture(screen_texture, SCREEN_UV);
} 