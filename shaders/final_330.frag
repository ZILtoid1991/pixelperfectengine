#version 330

out vec4 fragColor;

in vec4 texMapping;

uniform sampler2D tex;

void main() {
    fragColor = vec4((texMapping.x + 1.0) * 0.5, (texMapping.y + 1.0) * 0.5, 1.0, 1.0);
}