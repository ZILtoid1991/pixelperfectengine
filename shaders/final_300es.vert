#version 300 es

layout(location = 0)in vec3 vert;
layout(location = 1)in vec3 color;
layout(location = 2)in vec2 texPos;

out vec2 texMapping;

void main() {
    gl_Position = vec4(vert, 1.0);
    texMapping = texPos;
}
