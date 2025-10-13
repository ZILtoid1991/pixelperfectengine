/*
 * PixelPerfectEngine - Shader management module
 *
 * Copyright 2015 - 2025
 * Licensed under the Boost Software License
 * Authors:
 *   László Szerémi
 */

module pixelperfectengine.graphics.shaders;

import pixelperfectengine.system.memory;
import pixelperfectengine.graphics.common;
import pixelperfectengine.system.exc;
import bindbc.opengl;

public class ShaderException : PPEException_nogc {
	@nogc @safe public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
}
/**
 * Implements a reference counted OpenGL shader program, created from a vertex and a fragment shader.
 * See manual on default shader implementations!
 */
public struct GLShader {

	GLuint shaderID;
	this(GLuint shaderID) @trusted @nogc nothrow {
		this.shaderID = shaderID;
		// if (shaderID) refCountIncr(shaderID);
	}
	this(const(char)[] vertex, const(char)[] fragment) @trusted @nogc {
		import numem;
		GLuint gl_VertexShader = glCreateShader(GL_VERTEX_SHADER);
		char* shaderProgramPtr = cast(char*)vertex.ptr;
		glShaderSource(gl_VertexShader, 1, &shaderProgramPtr, null);
		glCompileShader(gl_VertexShader);
		char[] msg = gl_CheckShaderNOGC(gl_VertexShader);
		if (msg) throw nogc_new!ShaderException(cast(string)msg);
		GLuint gl_FragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
		shaderProgramPtr = cast(char*)fragment.ptr;
		glShaderSource(gl_FragmentShader, 1, &shaderProgramPtr, null);
		glCompileShader(gl_FragmentShader);
		msg = gl_CheckShaderNOGC(gl_FragmentShader);
		if (msg) throw nogc_new!ShaderException(cast(string)msg);
		shaderID = glCreateProgram();
		glAttachShader(shaderID, gl_VertexShader);
		glAttachShader(shaderID, gl_FragmentShader);
		glLinkProgram(shaderID);
		msg = gl_CheckProgramNOGC(shaderID);
		if (msg) throw nogc_new!ShaderException(cast(string)msg);
		glDeleteShader(gl_FragmentShader);
		glDeleteShader(gl_VertexShader);
		// refCountIncr(shaderID);
	}

	// ~this() @safe @nogc nothrow {
	// 	if (shaderID) refCountDecr(shaderID);
	// }
	void use() @trusted @nogc nothrow {
		glUseProgram(shaderID);
	}
	void free() @trusted @nogc nothrow {
		glDeleteProgram(shaderID);
	}
	int getUniformLocation(const(char)* name) @trusted @nogc nothrow {
		return glGetUniformLocation(shaderID, name);
	}
	uint getUniformBlockIndex(const(char)* name) @trusted @nogc nothrow {
		return glGetUniformBlockIndex(shaderID, name);
	}
	void uniformBlockBinding(uint uniformBlockIndex, uint uniformBlockBinding) @trusted @nogc nothrow {
		glUniformBlockBinding(shaderID, uniformBlockIndex, uniformBlockBinding);
	}
	alias this = shaderID;
}
