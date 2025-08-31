#version 330

// Basic vertex shader for PixelPerfectEngine
// Use this for writing your own shader programs

layout(location = 0)in ivec2 vert;
layout(location = 1)in uvec2 texPos;
layout(location = 2)in uvec4 color;
layout(location = 3)in ivec2 lDir;

out vec2 texMapping;        // Texture mapping data, by default `texPos` is sent here without modification
out vec4 lightingCol;       // Lighting color
out vec2 lightingDir;       // Lighting direction

uniform vec2 stepSizes;
uniform mat2 transformMatrix;
uniform vec2 transformPoint;

void main() {
    vec2 fvert = (vec2(vert.xy) - transformPoint) * transformMatrix + transformPoint;
    gl_Position = vec4(fvert * stepSizes + vec2(-1.0, 1.0), 0.0, 1.0);
    texMapping = texPos;
    lightingCol = color * vec4(1.0 / 255, 1.0 / 255,  1.0 / 255, 1.0 / 255);
    lightingDir = lDir * vec2(1.0 / 32767, 1.0 / 32767);
}
