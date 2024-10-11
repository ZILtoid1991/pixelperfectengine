#version 330

layout(location = 0)in vec3 vert;
layout(location = 1)in vec2 texPos;
uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

out vec4 texMapping;

void main() {
    gl_Position = projection * view * model * vec4(vert, 1.0);
    //texMapping = gl_Position;
    texMapping = vec4(-1.0, -1.0, -1.0, -1.0);
}