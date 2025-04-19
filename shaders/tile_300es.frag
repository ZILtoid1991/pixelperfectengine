#version 300 es

// Basic tile shader for PixelPerfectEngine

precision mediump float;
precision lowp sampler2D;
precision lowp sampler2DArray;

out vec4 fragColor;             // Color output

in vec3 texMapping;             // Texture mapping position
in vec4 lightingData;           // Lighting data, can be repurposed for other things
in vec2 lightingDir;
in vec2 paletteSel;
in float zVal;

uniform sampler2DArray mainTexture;  // Primary texture data
uniform sampler2D palette;      // Palette for indexed colors
uniform sampler2D paletteMipMap;// Palette for indexed mipmaps

vec4 clut(vec3 position, vec2 paletteOffset) {
    float i = texelFetch(mainTexture, ivec3(position.x, position.y, position.z), 0).r;
    return texture(palette, vec2(i + paletteOffset.x, paletteOffset.y));
}

void main() {
    vec4 color = clut(texMapping, paletteSel);
    color.a *= lightingData.a;
    fragColor = color;
}
