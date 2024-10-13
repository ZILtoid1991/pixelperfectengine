#version 330

out vec4 fragColor;

in vec2 texMapping;

uniform sampler2D texture1;

void main() {
    vec4 texSlmp = texture(texture1, texMapping);
    fragColor = vec4(texSlmp.r, texSlmp.g, texSlmp.b, 1.0);
}