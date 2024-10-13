#version 120

layout(location = 0)in vec3 vert;
layout(location = 1)in vec3 color;
layout(location = 2)in vec2 texPos;

void main() {
	gl_Position = ftransform();
	gl_TexCoord[0] = texPos;
}