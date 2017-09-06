module PixelPerfectEngine.system.exc;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, exceptions
 */

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
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}

}

public class TileFormatException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}

}

public class BitmapFormatException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
}

public class ConfigFileException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
}

public class MapFileException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
}