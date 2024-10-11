#version 120

uniform sampler2D tex;

void main(){
    vec4 texSlmp = texture2D(tex, gl_TexCoord[0].st);
    //vec4 texSlmp = texture2D(tex, vec2(1.0, 1.0));
	//gl_FragColor = vec4(texSlmp.r, texSlmp.g, texSlmp.b, 1.0);
    gl_FragColor = vec4((gl_TexCoord[0].s + 1.0) * 0.5, (gl_TexCoord[0].t + 1.0) * 0.5, 1.0, 1.0);
    //gl_FragColor = vec4((gl_TexCoord[0].s + 1.0) * 0.5, (gl_TexCoord[0].t + 1.0) * 0.5, texSlmp.b, 1.0);
}