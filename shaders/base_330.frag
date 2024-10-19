#version 330

// Base fragment shader for PixelPerfectEngine
// Use this for writing your own shader programs

out vec4 fragColor;             // Color output

in vec2 texMapping;             // Texture mapping position
in vec3 lightingData;           // Lighting data, can be repurposed for other things

uniform sampler2D mainTexture;  // Primary texture data
uniform sampler2D palette;      // Palette for indexed 
uniform vec2 paletteOffset;     // Palette offset in case palette selection is used
uniform float palLengthMult;    // Palette lenght multiplier in case it's needed

vec4 clut(vec2 position) {
    return texture(palette, vec2(texture(mainTexture, position).r * palLengthMult + paletteOffset.x, paletteOffset.y));
}

void main() {

}