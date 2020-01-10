module PixelPerfectEngine.map.mapdata;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map module
 */
import std.stdio;
import std.file;
import std.conv;
import std.base64;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.system.exc;
import PixelPerfectEngine.system.etc;
import core.stdc.stdlib;
import core.stdc.stdio;
import std.string;

version(Windows){
	import core.sys.windows.windows;
	import std.windows.syserror;
}else{
	import core.stdc.errno;
}

public import PixelPerfectEngine.system.exc;
/**
 * Contains the very basic data for the map binary file (*.mbf).
 */
public struct MapDataHeader{
	public uint flags;		///Currently unused
	//public uint fileLength;	/// fileLength = sizeX * sizeY + MapDataHeader.sizeof;
	public int sizeX;		///width of the map
	public int sizeY;		///Height of the map
	this(int sizeX, int sizeY){
		//this.fileLength = cast(uint)(sizeX * sizeY + MapDataHeader.sizeof);
		this.sizeX = sizeX;
		this.sizeY = sizeY;
	}
}

/**
 * Saves a map to an external file.
 */
public void saveMapFile(MapDataHeader* header, ref MappingElement[] map, string name){
	FILE* outputStream = fopen(toStringz(name), "wb");
	if(outputStream is null){
		import std.conv;
		version(Windows){
			DWORD errorCode = GetLastError();
		}else version(Posix){
			int errorCode = errno;
		}
		throw new FileAccessException("File access error! Error number: " ~ to!string(errorCode));
	}

	fwrite(cast(void*)header, MapDataHeader.sizeof, 1, outputStream);
	fwrite(cast(void*)map.ptr, MappingElement.sizeof, map.length, outputStream);

	fclose(outputStream);
}
///Ditto, but safer.
public void saveMapFile(F = File)(MapDataHeader header, MappingElement[] map, F file) @trusted {
	ubyte[] writeBuf = toStream(header);
	file.rawWrite(writeBuf);
	file.rawWrite(map);
}
/**
 * Loads a map from an external file.
 */
public MappingElement[] loadMapFile(F = File)(F file, ref MapDataHeader header){
	ubyte[] readbuffer;
	MappingElement[] result;
	readbuffer.length = MapDataHeader.sizeof;
	readbuffer = file.rawRead(readbuffer);
	header = reinterpretGet!MapDataHeader(readbuffer);
	result.length = header.sizeX * header.sizeY;
	result = file.rawRead(result);
	return result;
}

/**
 * Loads a map from a BASE64 string.
 */
public MappingElement[] loadMapFromBase64(in char[] input, int length){
	MappingElement[] result;
	result.length = length;
	Base64.decode(input, cast(ubyte[])cast(void[])result);
	return result;
}

/**
 * Saves a map to a BASE64 string.
 */
public char[] saveMapToBase64(in MappingElement[] input){
	char[] result;
	Base64.encode(cast(ubyte[])cast(void[])input, result);
	return result;
}
