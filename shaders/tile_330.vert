#version 330 core

// Basic tile shader for PixelPerfectEngine

layout(location = 0)in uvec2 vert;
layout(location = 1)in uint palSel;
layout(location = 2)in uint texPos;
layout(location = 3)in ivec4 color;
layout(location = 4)in ivec2 lDir;

uniform mat2 transformMatrix;
uniform vec2 transformPoint;
uniform vec2 bias;
uniform vec2 tileSize;


out vec3 texMapping;       // Texture mapping data, by default `texPos` is sent here without modification
out vec4 lightingData;      // Lighting color
out vec2 lightingDir;       // Lighting direction
out vec2 paletteSel;

void main() {
//     vec2 fvert = vec2(vert.xy) * tileSize - bias + vec2(-1.0, 1.0) - transformPoint;
//     gl_Position = vec4(fvert * transformMatrix + transformPoint, 0.0, 1.0);
    vec2 fvert = ((vec2(vert.xy) - transformPoint) * transformMatrix + transformPoint) * tileSize - bias + vec2(-1.0, 1.0);
    gl_Position = vec4(fvert, 0.0, 1.0);
    texMapping.x = uint(texPos) & uint(0x0FFF);
    texMapping.y = (texPos>>12) & uint(0x0FFF);
    texMapping.z = texPos>>24;
    lightingData = color * vec4(1.0 / 255, 1.0 / 255,  1.0 / 255, 1.0 / 255);
    lightingDir = lDir;
    paletteSel = vec2((palSel & uint(0xFF)) * (1.0 / 255), (palSel>>8) * (1.0 / 255));
}
