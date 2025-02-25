module pixelperfectengine.system.exc;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, exceptions
 */

import numem : NuException, nogc_delete;
import pixelperfectengine.system.memory;

/*
 * NOTE: Rework exception system with local classes where they will be thrown from.
 */
/**
 * Base class for all exception thrown by this library.
 */
public class PPEException : Exception {
	///
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
	{
		super(msg, file, line, nextInChain);
	}
	///
	@nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line, nextInChain);
	}
}
/**
 * Exception for live allocated messages.
 */
public class PPEException_nogc : Exception {
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
	~this() {
		msg.nogc_free();
	}
	void free() @nogc @safe nothrow {
		nogc_delete(this);
	}
}

public class AudioInitializationException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}

}

public class GraphicsInitializationException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}

}

public class VideoModeException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}

}

//public class VideoException

public class FileAccessException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}

}

public class TileFormatException : PPEException {
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}

}

public class BitmapFormatException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}
}

public class ConfigFileException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}
}

public class MapFileException : PPEException {
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}
}

public class MapFormatException : PPEException {
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}
}

public class SpriteLayerException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}
}

public class SpritePriorityException : SpriteLayerException{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) @safe pure @nogc {
		super(msg, file, line, next);
	}
}
