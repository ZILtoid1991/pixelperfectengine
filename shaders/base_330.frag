#version 330

// Basic fragment shader for PixelPerfectEngine
// Use this for writing your own shader programs

out vec4 fragColor;             // Color output

in vec2 texMapping;             // Texture mapping position
in vec4 lightingData;           // Lighting data, can be repurposed for other things
in vec2 lightingDir;
in float zVal;

uniform sampler2D mainTexture;  // Primary texture data
uniform sampler2D palette;      // Palette for indexed colors
uniform sampler2D paletteMipMap;// Palette for indexed mipmaps
uniform vec2 paletteOffset;     // Palette offset in case palette selection is used
// uniform float palLengthMult;    // Palette lenght multiplier

vec4 clut(vec2 position) {
    return texture(palette, vec2(texture(mainTexture, position).r /** palLengthMult*/ + paletteOffset.x, paletteOffset.y));
}

void main() {
    vec4 color = clut(texMapping);
    if (color.a > 0.0) {
        fragColor = color;
    }
}
