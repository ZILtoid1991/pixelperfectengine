#version 330

// Base vertex shader for PixelPerfectEngine
// Use this for writing your own shader programs

layout(location = 0)in vec3 vert;
layout(location = 1)in vec3 color;
layout(location = 2)in vec2 texPos;

out vec2 texMapping;        // Texture mapping data, by default `texPos` is sent here without modification
out vec3 lightingData;      // Lighting data, can be repurposed for other things

void main() {
    gl_Position = vec4(vert, 1.0);
    texMapping = texPos;
    lightingData = color;
}