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
uniform vec4 paletteOffset;     // Palette offset in case palette selection is used
// uniform float palLengthMult;    // Palette lenght multiplier

void main() {
    vec4 color = texelFetch(mainTexture, ivec2(texMapping.x, texMapping.y), 0);
    color.a *= lightingCol.a;
    fragColor = color;
}
