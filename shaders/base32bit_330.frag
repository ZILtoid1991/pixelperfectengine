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

void main() {
    vec4 color = texelFetch(mainTexture, ivec2(texMapping.x, texMapping.y), 0);
    color.a *= lightingData.a;
    fragColor = color;
}
