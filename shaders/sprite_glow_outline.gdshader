shader_type canvas_item;
render_mode blend_mix;

uniform vec4 glow_color : source_color = vec4(1.0, 0.2, 0.25, 1.0);
uniform float glow_thickness : hint_range(0.0, 10.0) = 2.5;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    vec2 size = TEXTURE_PIXEL_SIZE * glow_thickness;
    
    // Sample surrounding neighbors across 2 rings to get a soft, radiant outline
    float a = 0.0;
    // Ring 1 (1.0x radius)
    a += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
    a += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    a += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
    a += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
    a += texture(TEXTURE, UV + vec2(-size.x * 0.7071, -size.y * 0.7071)).a;
    a += texture(TEXTURE, UV + vec2(size.x * 0.7071, -size.y * 0.7071)).a;
    a += texture(TEXTURE, UV + vec2(-size.x * 0.7071, size.y * 0.7071)).a;
    a += texture(TEXTURE, UV + vec2(size.x * 0.7071, size.y * 0.7071)).a;
    
    // Ring 2 (1.8x radius)
    vec2 size2 = size * 1.8;
    a += texture(TEXTURE, UV + vec2(0.0, -size2.y)).a * 0.5;
    a += texture(TEXTURE, UV + vec2(0.0, size2.y)).a * 0.5;
    a += texture(TEXTURE, UV + vec2(-size2.x, 0.0)).a * 0.5;
    a += texture(TEXTURE, UV + vec2(size2.x, 0.0)).a * 0.5;
    
    // Outline mask: only draw outside the opaque pixels of the sprite
    float outline = clamp(a / 3.0, 0.0, 1.0) * (1.0 - col.a);
    
    vec4 glow = glow_color * outline * intensity;
    COLOR = col + glow;
}
