module pixelperfectengine.graphics.shaders;

import pixelperfectengine.system.memory;
import pixelperfectengine.graphics.common;
import bindbc.opengl;

public struct GLShader {
	protected struct RefCountEntry {
		GLuint shaderID;
		uint count;
		this (GLuint shaderID) @safe @nogc nothrow pure {
			this.shaderID = shaderID;
			count = 1;
		}
		int opCmp(const RefCountEntry rhs) @safe @nogc nothrow pure const {
			if (shaderID < rhs.shaderID) return -1;
			else if (shaderID == rhs.shaderID) return 0;
			else return 1;
		}
		int opCmp(const GLuint rhs) @safe @nogc nothrow pure const {
			if (shaderID < rhs) return -1;
			else if (shaderID == rhs) return 0;
			else return 1;
		}
	}
	private static RefCountEntry[] refCount;
	private static void refCountIncr(GLuint shaderID) @safe @nogc nothrow {
		sizediff_t index = refCount.searchByI(shaderID);
		if (index != -1) refCount[index].count++;
		else refcount.orderedInsert(RefCountEntry(shaderID));
	}
	private static void refCountDecr(GLuint shaderID) @safe @nogc nothrow {
		import numem;
		sizediff_t index = refCount.searchByI(shaderID);
		if (index != -1) nu_fatal("Reference counter error: reference not found!");
		refCount[index].count--;
		if (!refCount[index].count) {
			glDeleteProgram(shaderID);
			refCount.nogc_remove(index);
		}
	}
	GLuint shaderID;
	this(GLuint shaderID) @trusted @nogc nothrow {
		this.shaderID = shaderID;
		refCountIncr(shaderID);
	}
	this(const(char)[] vertex, const(char)[] fragment) @trusted @nogc {
		import numem;
		GLuint gl_VertexShader = glCreateShader(GL_VERTEX_SHADER);
		char* shaderProgramPtr = cast(char*)vertex.ptr;
		glShaderSource(gl_VertexShader, 1, &shaderProgramPtr, null);
		glCompileShader(gl_VertexShader);
		char[] msg = gl_CheckShaderNOGC(gl_VertexShader);
		// if (msg) nu_fatal(cast(const(char)[])msg);
		GLuint gl_FragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
		shaderProgramPtr = cast(char*)fragment.ptr;
		glShaderSource(gl_FragmentShader, 1, &shaderProgramPtr, null);
		glCompileShader(gl_FragmentShader);
		msg = gl_CheckShaderNOGC(gl_FragmentShader);

		shaderID = glCreateProgram();
		glAttachShader(shaderID, gl_VertexShader);
		glAttachShader(shaderID, gl_FragmentShader);
		glLinkProgram(shaderID);
		msg = gl_CheckProgramNOGC(shaderID);

		glDeleteShader(gl_FragmentShader);
		glDeleteShader(gl_VertexShader);
		refCountIncr();
	}
	this(ref return scope GLShader rhs) @safe @nogc nothrow {
		shaderID = rhs.shaderID;
		refCountIncr();
	}
	~this() @nogc nothrow {
		refCountDecr();
	}
}
