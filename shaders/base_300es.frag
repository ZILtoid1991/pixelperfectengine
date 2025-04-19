#version 300 es

// Basic fragment shader for PixelPerfectEngine
// Use this for writing your own shader programs

precision mediump float;

out vec4 fragColor;             // Color output

in vec2 texMapping;             // Texture mapping position
in vec4 lightingCol;            // Lighting data, can be repurposed for other things
in vec2 lightingDir;
in float zVal;

uniform sampler2D mainTexture;  // Primary texture data
uniform sampler2D palette;      // Palette for indexed colors
uniform sampler2D paletteMipMap;// Palette for indexed mipmaps
uniform vec2 paletteOffset;     // Palette offset in case palette selection is used
// uniform float palLengthMult;    // Palette lenght multiplier

vec4 clut(vec2 position) {
    return texture(palette, vec2(texelFetch(mainTexture, ivec2(position.x, position.y), 0).r + paletteOffset.x, paletteOffset.y));
}

void main() {
    vec4 color = clut(texMapping);
    color.a *= lightingCol.a;
    fragColor = color;
}
