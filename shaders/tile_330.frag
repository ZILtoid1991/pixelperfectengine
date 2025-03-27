#version 330 core

// Basic tile shader for PixelPerfectEngine

out vec4 fragColor;             // Color output

in uvec3 texMapping;             // Texture mapping position
in vec4 lightingData;           // Lighting data, can be repurposed for other things
in vec2 lightingDir;
in vec2 paletteSel;
in float zVal;

uniform sampler3D mainTexture;  // Primary texture data
uniform sampler2D palette;      // Palette for indexed colors
uniform sampler2D paletteMipMap;// Palette for indexed mipmaps

vec4 clut(uvec3 position, vec2 paletteOffset) {
    float i = texelFetch(mainTexture, position).r;
    return texture(palette, vec2(i + paletteOffset.x, paletteOffset.y));
}

void main() {
    vec4 color = clut(texMapping, paletteSel);
    if (color.a <= 0.01) discard;
    fragColor = color;
}
