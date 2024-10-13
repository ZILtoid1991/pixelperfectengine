#version 120

uniform sampler2D tex;

void main(){
    vec4 texSlmp = texture2D(tex, gl_TexCoord[0].st);
	gl_FragColor = vec4(texSlmp.r, texSlmp.g, texSlmp.b, 1.0);
}