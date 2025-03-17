#version 330

// Basic tile shader for PixelPerfectEngine

vec4 clut(vec2 position) {
    return texture(palette, vec2(texture(mainTexture, position).r + paletteOffset.x, paletteOffset.y));
}
