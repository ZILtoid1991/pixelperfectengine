#version 330

// Basic tile shader for PixelPerfectEngine

layout(location = 0)in vec3 vert;
layout(location = 1)in vec4 color;
layout(location = 2)in vec3 texPos;
layout(location = 3)in vec2 lDir;
layout(location = 4)in vec2 palSel;

uniform mat2 transformMatrix;
uniform vec2 transformPoint;

out vec2 texMapping;        // Texture mapping data, by default `texPos` is sent here without modification
out vec4 lightingCol;       // Lighting color
out vec2 lightingDir;       // Lighting direction
out float zVal;

void main() {
    gl_Position = vec4(vert, 1.0);
    texMapping = texPos;
    lightingCol = color;
    lightingDir = lDir;
}
