#version 330

// Basic tile shader for PixelPerfectEngine

out vec4 fragColor;             // Color output

in vec3 texMapping;             // Texture mapping position
in vec4 lightingData;           // Lighting data, can be repurposed for other things
in vec2 lightingDir;
in vec2 paletteSel;
in float zVal;

uniform sampler2D mainTexture;  // Primary texture data
uniform sampler2D palette;      // Palette for indexed colors
uniform sampler2D paletteMipMap;// Palette for indexed mipmaps

vec4 clut(vec3 position) {
    return texture(palette, vec2(texture(mainTexture, position).r + paletteOffset.x, paletteOffset.y));
}

void main() {
    vec4 color = clut(texMapping);
    if (color.a <= 0.01) discard;
    fragColor = color;
}
